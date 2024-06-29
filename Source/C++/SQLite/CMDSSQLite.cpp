//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLite.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSSQLite.h"

#include "CMDSSQLiteDatabaseManager.h"
#include "CMDSSQLiteDocumentBacking.h"
#include "CThread.h"
#include "TBatchQueue.h"
#include "TLockingDictionary.h"
#include "TMDSBatch.h"
#include "TMDSCache.h"
#include "TMDSCollection.h"
#include "TMDSDocumentBackingCache.h"
#include "TMDSIndex.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Types

typedef	CMDSSQLiteDatabaseManager::AssociationInfo			DMAssociationInfo;
typedef	CMDSSQLiteDatabaseManager::CacheInfo				DMCacheInfo;
typedef	CMDSSQLiteDatabaseManager::CacheValueInfo			DMCacheValueInfo;
typedef	CMDSSQLiteDatabaseManager::CollectionInfo			DMCollectionInfo;
typedef	CMDSSQLiteDatabaseManager::DocumentContentInfo		DMDocumentContentInfo;
typedef	CMDSSQLiteDatabaseManager::DocumentInfo				DMDocumentInfo;
typedef	CMDSSQLiteDatabaseManager::IDArray					DMIDArray;
typedef	CMDSSQLiteDatabaseManager::IndexInfo				DMIndexInfo;
typedef	CMDSSQLiteDatabaseManager::ValueInfoByID			DMValueInfoByID;

typedef	TMDSBatch<I<CMDSSQLiteDocumentBacking> >			MDSBatch;
typedef	MDSBatch::DocumentInfo								MDSBatchDocumentInfo;
typedef	TNDictionary<MDSBatchDocumentInfo>					MDSBatchDocumentInfoByDocumentID;
typedef	TDictionary<MDSBatchDocumentInfoByDocumentID>		MDSBatchDocumentInfoByDocumentIDByDocumentType;
typedef	TMDSCache<SInt64, DMValueInfoByID>					MDSCache;
typedef	TMDSCollection<SInt64, DMIDArray >					MDSCollection;
typedef	TVResult<I<CMDSSQLiteDocumentBacking> >				MDSDocumentBackingResult;
typedef	TNDictionary<CMDSDocument::UpdateInfo>				MDSDocumentUpdateByDocumentID;
typedef	TMDSIndex<SInt64>									MDSIndex;
typedef	TMDSUpdateInfo<SInt64>								MDSUpdateInfo;
typedef	TBatchQueue<MDSUpdateInfo, TNArray<MDSUpdateInfo> >	MDSUpdateInfoBatchQueue;
typedef	TBatchQueue<SInt64, TNumberArray<SInt64> >			MDSRemoveBatchQueue;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLite::Internals

class CMDSSQLite::Internals {
	public:
		struct BatchInfo {
			public:
									BatchInfo(Internals& internals, const MDSBatch& batch) :
										mInternals(internals), mBatch(batch)
										{}

						Internals&	getInternals() const
										{ return mInternals; }
				const	MDSBatch&	getBatch() const
										{ return mBatch; }

			private:
						Internals&	mInternals;
				const	MDSBatch&	mBatch;
		};

	public:
		struct DocumentCreateInfo {
															DocumentCreateInfo(Internals& internals,
																	const CMDSDocument::InfoForNew& documentInfoForNew,
																	const TArray<CMDSDocument::CreateInfo>&
																			documentCreateInfos,
																	TNArray<CMDSDocument::CreateResultInfo>&
																			documentCreateResultInfos) :
																mInternals(internals),
																		mDocumentInfoForNew(documentInfoForNew),
																		mDocumentCreateInfos(documentCreateInfos),
																		mDocumentCreateResultInfos(
																				documentCreateResultInfos)
																{}

						Internals&							getInternals() const
																{ return mInternals; }
				const	CMDSDocument::InfoForNew&			getDocumentInfoForNew() const
																{ return mDocumentInfoForNew; }
				const	TArray<CMDSDocument::CreateInfo>&	getDocumentCreateInfos() const
																{ return mDocumentCreateInfos; }

						void								add(const CMDSDocument::CreateResultInfo&
																	documentCreateResultInfo)
																{ mDocumentCreateResultInfos +=
																		documentCreateResultInfo; }

			private:
						Internals&									mInternals;
				const	CMDSDocument::InfoForNew&					mDocumentInfoForNew;
				const	TArray<CMDSDocument::CreateInfo>&			mDocumentCreateInfos;
						TNArray<CMDSDocument::CreateResultInfo>&	mDocumentCreateResultInfos;
		};

	public:
		struct DocumentBackingDocumentIDsIterateInfo {
			public:
						DocumentBackingDocumentIDsIterateInfo(const CMDSDocument::Info& documentInfo,
								CMDSDocumentStorage& documentStorage, TNArray<CString>& documentIDs,
								CMDSDocument::Proc proc, void* procUserData) :
							mDocumentIDs(documentIDs),
									mDocumentInfo(documentInfo), mDocumentStorage(documentStorage), mProc(proc),
									mProcUserData(procUserData)
							{}
						DocumentBackingDocumentIDsIterateInfo(TNArray<CMDSDocument::FullInfo>& documentFullInfos,
								TNArray<CString>& documentIDs) :
							mDocumentIDs(documentIDs),
									mProc(nil), mProcUserData(nil), mDocumentFullInfos(documentFullInfos)
							{}

				void	process(const I<CMDSSQLiteDocumentBacking>& documentBacking) const
							{
								// Check how to process
								if (mProc != nil)
									// Call proc
									mProc(mDocumentInfo->create(documentBacking->getDocumentID(), *mDocumentStorage),
											mProcUserData);
								else
									// Add to array
									mDocumentFullInfos->add(documentBacking->getDocumentFullInfo());

								// Update
								mDocumentIDs -= documentBacking->getDocumentID();
							}

			private:
				TNArray<CString>&						mDocumentIDs;

				OR<const CMDSDocument::Info>					mDocumentInfo;
				OR<CMDSDocumentStorage>					mDocumentStorage;
				CMDSDocument::Proc						mProc;
				void*									mProcUserData;

				OR<TNArray<CMDSDocument::FullInfo> >	mDocumentFullInfos;
		};

	public:
		struct DocumentBackingSinceRevisionIterateInfo {
						DocumentBackingSinceRevisionIterateInfo(const CMDSDocument::Info& documentInfo,
								CMDSDocumentStorage& documentStorage, CMDSDocument::Proc proc, void* procUserData) :
							mDocumentInfo(documentInfo), mDocumentStorage(documentStorage), mProc(proc),
									mProcUserData(procUserData)
							{}

				void	process(const CString& documentID) const
							{ mProc(mDocumentInfo.create(documentID, mDocumentStorage), mProcUserData); }

			private:
				const	CMDSDocument::Info&		mDocumentInfo;
						CMDSDocumentStorage&	mDocumentStorage;
						CMDSDocument::Proc		mProc;
						void*					mProcUserData;
		};

	public:
		struct DocumentUpdateInfo {
			public:
															DocumentUpdateInfo(Internals& internals,
																	const CString& documentType,
																	const TArray<CMDSDocument::UpdateInfo>&
																			documentUpdateInfos,
																	TNArray<CMDSDocument::FullInfo>&
																			documentFullInfos) :
																mInternals(internals), mDocumentType(documentType),
																		mDocumentUpdateInfos(documentUpdateInfos),
																		mDocumentFullInfos(documentFullInfos)
																{}

						Internals&							getInternals() const
																{ return mInternals; }
				const	CString&							getDocumentType() const
																{ return mDocumentType; }
				const	TArray<CMDSDocument::UpdateInfo>&	getDocumentUpdateInfos() const
																{ return mDocumentUpdateInfos; }
						TNArray<CMDSDocument::FullInfo>&	getDocumentFullInfos() const
																{ return mDocumentFullInfos; }

			private:
						Internals&							mInternals;
				const	CString&							mDocumentType;
				const	TArray<CMDSDocument::UpdateInfo>&	mDocumentUpdateInfos;
						TNArray<CMDSDocument::FullInfo>&	mDocumentFullInfos;
		};

	public:
		struct UpdatesInfo {

												UpdatesInfo(const TArray<MDSUpdateInfo>& updateInfos,
														const DMIDArray& removedIDs) :
													mUpdateInfos(updateInfos), mRemovedIDs(removedIDs)
													{}
												UpdatesInfo(const TArray<MDSUpdateInfo>& updateInfos) :
													mUpdateInfos(updateInfos), mRemovedIDs(TNumberArray<SInt64>())
													{}
												UpdatesInfo(const DMIDArray& removedIDs) :
													mUpdateInfos(TNArray<MDSUpdateInfo>()), mRemovedIDs(removedIDs)
													{}
												UpdatesInfo(const UpdatesInfo& other) :
													mUpdateInfos(other.mUpdateInfos), mRemovedIDs(other.mRemovedIDs)
													{}

				const	TArray<MDSUpdateInfo>&	getUpdateInfos() const
													{ return mUpdateInfos; }
				const	DMIDArray&				getRemovedIDs() const
													{ return mRemovedIDs; }

			private:
				TArray<MDSUpdateInfo>	mUpdateInfos;
				DMIDArray				mRemovedIDs;
		};

	private:
		struct Info {
			public:
									Info(Internals& internals, const CString& documentType) :
										mInternals(internals), mDocumentType(documentType)
										{}

						Internals&	getInternals() const
										{ return mInternals; }
				const	CString&	getDocumentType() const
										{ return mDocumentType; }

			private:
						Internals&	mInternals;
				const	CString&	mDocumentType;
		};

	private:
		struct KeyAndDocumentInfo {
										KeyAndDocumentInfo(const CString& key, const DMDocumentInfo& documentInfo) :
											mKey(key), mDocumentInfo(documentInfo)
											{}
										KeyAndDocumentInfo(const KeyAndDocumentInfo& other) :
											mKey(other.mKey), mDocumentInfo(other.mDocumentInfo)
											{}

				const	CString&		getKey() const
											{ return mKey; }
				const	DMDocumentInfo&	getDocumentInfo() const
											{ return mDocumentInfo; }

			private:
				CString			mKey;
				DMDocumentInfo	mDocumentInfo;
		};

	private:
		struct ProcessDocumentUpdateInfo {
			public:
													ProcessDocumentUpdateInfo(Internals& internals,
															const CString& documentType,
															TNArray<CMDSDocument::FullInfo>& documentFullInfos,
															const MDSDocumentUpdateByDocumentID&
																	documentUpdateByDocumentID,
															MDSUpdateInfoBatchQueue& updateInfoBatchQueue,
															MDSRemoveBatchQueue& removeBatchQueue) :
														mInternals(internals), mDocumentType(documentType),
																mDocumentInfo(
																		mInternals.mDocumentStorage.documentCreateInfo(
																				mDocumentType)),
																mDocumentFullInfos(documentFullInfos),
																mDocumentUpdateInfoByDocumentID(
																		documentUpdateByDocumentID),
																mUpdateInfoBatchQueue(updateInfoBatchQueue),
																mRemoveBatchQueue(removeBatchQueue)
														{}

						Internals&					getInternals() const
														{ return mInternals; }
				const	CString&					getDocumentType() const
														{ return mDocumentType; }
				const	CMDSDocument::UpdateInfo&	getDocumentUpdateInfo(const CString& documentID) const
														{ return *mDocumentUpdateInfoByDocumentID[documentID]; }

						I<CMDSDocument>				documentCreate(const CString& documentID)
														{ return mDocumentInfo.create(documentID,
																mInternals.mDocumentStorage); }
						void						update(const I<CMDSDocument>& document, UInt32 revision, SInt64 id,
															const TSet<CString> changedProperties)
														{ mUpdateInfoBatchQueue.add(
																MDSUpdateInfo(document, revision, id,
																		changedProperties)); }
						void						remove(SInt64 id)
														{ mRemoveBatchQueue.add(id); }
						void						add(const CMDSDocument::FullInfo& documentFullInfo)
														{ mDocumentFullInfos += documentFullInfo; }

			private:
						Internals&							mInternals;
				const	CString&							mDocumentType;
				const	CMDSDocument::Info&					mDocumentInfo;
						TNArray<CMDSDocument::FullInfo>&	mDocumentFullInfos;
				const	MDSDocumentUpdateByDocumentID&		mDocumentUpdateInfoByDocumentID;
						MDSUpdateInfoBatchQueue&			mUpdateInfoBatchQueue;
						MDSRemoveBatchQueue&				mRemoveBatchQueue;
		};

	private:
		struct UpdatesInfoBuilder {

											UpdatesInfoBuilder(CMDSDocumentStorage& documentStorage,
													const CMDSDocument::Info& documentInfo,
													const OR<I<MDSBatch> >& batch) :
												mDocumentStorage(documentStorage), mDocumentInfo(documentInfo),
														mBatch(batch)
												{}

				const	OR<I<MDSBatch> >&	getBatch() const
												{ return mBatch; }

						void				addUpdateInfo(const I<CMDSSQLiteDocumentBacking>& documentBacking)
												{ mUpdateInfos +=
														MDSUpdateInfo(
																mDocumentInfo.create(documentBacking->getDocumentID(),
																		mDocumentStorage),
																documentBacking->getRevision(),
																documentBacking->getID()); }
						void				noteRemoved(const I<CMDSSQLiteDocumentBacking>& documentBacking)
												{ mRemovedIDs += documentBacking->getID(); }

						UpdatesInfo			getUpdatesInfo() const
												{ return UpdatesInfo(mUpdateInfos, mRemovedIDs); }

			private:
						CMDSDocumentStorage&	mDocumentStorage;
				const	CMDSDocument::Info&		mDocumentInfo;
						OR<I<MDSBatch> >		mBatch;

						TNArray<MDSUpdateInfo>	mUpdateInfos;
						DMIDArray				mRemovedIDs;
		};

	public:
											Internals(CMDSDocumentStorage& documentStorage, const CFolder& folder,
													const CString& name) :
												mDocumentStorage(documentStorage), mDatabaseManager(folder, name)
												{}

				OV<I<CMDSAssociation> >		associationGet(const CString& name)
												{
													// Check if have loaded
													const	OR<I<CMDSAssociation> >	association =
																							mAssociationByName[name];
													if (association.hasReference())
														// Have loaded
														return OV<I<CMDSAssociation> >(*association);

													// Check if have stored
													OV<DMAssociationInfo>	associationInfo =
																					mDatabaseManager.associationInfo(
																							name);
													if (associationInfo.hasValue()) {
														// Have stored
														I<CMDSAssociation>	association(
																					new CMDSAssociation(name,
																							associationInfo->
																									getFromDocumentType(),
																							associationInfo->
																									getToDocumentType()));
														mAssociationByName.set(name, association);

														return OV<I<CMDSAssociation> >(association);
													}

													return OV<I<CMDSAssociation> >();
												}
				OV<SError>					associationIterateFrom(const I<CMDSAssociation>& association,
													const CString& fromDocumentID, UInt32 startIndex,
													const OV<UInt32>& count,
													CMDSSQLiteDocumentBacking::KeyProc documentBackingKeyProc,
													void* userData)
												{
													// Setup
													OV<SError>	error;

													// Collect KeyAndDocumentInfos
													TNArray<KeyAndDocumentInfo>	keyAndDocumentInfos;
													error =
															mDatabaseManager
																	.associationIterateDocumentInfosFrom(
																			association->getName(), fromDocumentID,
																			association->getFromDocumentType(),
																			association->getToDocumentType(), startIndex,
																			count,
																			DMDocumentInfo::ProcInfo(
																					(DMDocumentInfo::ProcInfo::Proc)
																							addDocumentInfoToKeyAndDocumentInfoArray,
																					&keyAndDocumentInfos));
													ReturnErrorIfError(error);

													// Iterate document backings
													documentBackingsIterate(association->getToDocumentType(),
															keyAndDocumentInfos, documentBackingKeyProc, userData);

													return OV<SError>();
												}
				OV<SError>					associationIterateTo(const I<CMDSAssociation>& association,
													const CString& toDocumentID, UInt32 startIndex,
													const OV<UInt32>& count,
													CMDSSQLiteDocumentBacking::KeyProc documentBackingKeyProc,
													void* userData)
												{
													// Setup
													OV<SError>	error;

													// Collect KeyAndDocumentInfos
													TNArray<KeyAndDocumentInfo>	keyAndDocumentInfos;
													error =
															mDatabaseManager
																	.associationIterateDocumentInfosTo(
																			association->getName(), toDocumentID,
																			association->getToDocumentType(),
																			association->getFromDocumentType(), startIndex,
																			count,
																			DMDocumentInfo::ProcInfo(
																					(DMDocumentInfo::ProcInfo::Proc)
																							addDocumentInfoToKeyAndDocumentInfoArray,
																					&keyAndDocumentInfos));
													ReturnErrorIfError(error);

													// Iterate document backings
													documentBackingsIterate(association->getToDocumentType(),
															keyAndDocumentInfos, documentBackingKeyProc, userData);

													return OV<SError>();
												}

				OV<I<MDSCache> >			cacheGet(const CString& name)
												{
													// Check if have loaded
													const	OR<I<MDSCache> >	cache = mCacheByName[name];
													if (cache.hasReference())
														// Have loaded
														return OV<I<MDSCache> >(*cache);

													// Check if have stored
													OV<DMCacheInfo>	cacheInfo = mDatabaseManager.cacheInfo(name);
													if (cacheInfo.hasValue()) {
														// Have stored
														TNArray<SMDSCacheValueInfo>	cacheValueInfos;
														for (TIteratorD<DMCacheValueInfo> iterator =
																		cacheInfo->getCacheValueInfos().getIterator();
																iterator.hasValue(); iterator.advance())
															// Add
															cacheValueInfos +=
																	SMDSCacheValueInfo(
																			SMDSValueInfo(iterator->getName(),
																					iterator->getValueType()),
																			mDocumentStorage.documentValueInfo(
																					iterator->getSelector()));

														I<MDSCache>	cache(
																			new MDSCache(name,
																					cacheInfo->getDocumentType(),
																					cacheInfo->getRelevantProperties(),
																					cacheValueInfos,
																					cacheInfo->getLastRevision()));
														mCacheByName.set(name, cache);

														return OV<I<MDSCache> >(cache);
													}

													return OV<I<MDSCache> >();
												}
				void						cacheUpdate(const I<MDSCache>& cache, const UpdatesInfo& updatesInfo)
												{
													// Update Cache
													MDSCache::UpdateResults	cacheUpdateResults =
																					cache->update(
																							updatesInfo
																									.getUpdateInfos());

													// Check if have updates
													if (cacheUpdateResults.getValueInfoByID().hasValue() ||
															!updatesInfo.getRemovedIDs().isEmpty())
														// Update database
														mDatabaseManager.cacheUpdate(cache->getName(),
																cacheUpdateResults.getValueInfoByID(),
																updatesInfo.getRemovedIDs(),
																cacheUpdateResults.getLastRevision());
												}

				OV<I<MDSCollection> >		collectionGet(const CString& name)
												{
													// Check if have loaded
													const	OR<I<MDSCollection> >	collection =
																							mCollectionByName[name];
													if (collection.hasReference())
														// Have loaded
														return OV<I<MDSCollection> >(*collection);

													// Check if have stored
													OV<DMCollectionInfo>	collectionInfo =
																					mDatabaseManager.collectionInfo(
																							name);
													if (collectionInfo.hasValue()) {
														// Have stored
														I<MDSCollection>	collection(
																					new MDSCollection(name,
																							collectionInfo->
																									getDocumentType(),
																							collectionInfo->
																									getRelevantProperties(),
																							mDocumentStorage
																									.documentIsIncludedPerformer(
																											collectionInfo->
																													getIsIncludedSelector()),
																							collectionInfo->
																									getIsIncludedSelectorInfo(),
																							collectionInfo->
																									getLastRevision()));
														mCollectionByName.set(name, collection);

														return OV<I<MDSCollection> >(collection);
													}

													return OV<I<MDSCollection> >();
												}
				void						collectionIterate(const CString& name, const CString& documentType,
													UInt32 startIndex, const OV<UInt32>& count,
													CMDSSQLiteDocumentBacking::KeyProc documentBackingKeyProc,
													void* userData)
												{
													// Collect KeyAndDocumentInfos
													TNArray<KeyAndDocumentInfo>	keyAndDocumentInfos;
													mDatabaseManager.collectionIterateDocumentInfos(name, documentType,
															startIndex, count,
															DMDocumentInfo::ProcInfo(
																	(DMDocumentInfo::ProcInfo::Proc)
																			addDocumentInfoToKeyAndDocumentInfoArray,
																	&keyAndDocumentInfos));

													// Iterate document backings
													documentBackingsIterate(documentType, keyAndDocumentInfos,
															documentBackingKeyProc, userData);
												}
				void						collectionUpdate(const I<MDSCollection>& collection,
													const UpdatesInfo& updatesInfo)
												{
													// Update Collection
													MDSCollection::UpdateResults	collectionUpdateResults =
																							collection->update(
																									updatesInfo
																											.getUpdateInfos());

													// Check if have updates
													if (collectionUpdateResults.getIncludedIDs().hasValue() ||
															collectionUpdateResults.getNotIncludedIDs().hasValue() ||
															!updatesInfo.getRemovedIDs().isEmpty())
														// Update database
														mDatabaseManager.collectionUpdate(collection->getName(),
																collectionUpdateResults.getIncludedIDs(),
																OV<DMIDArray >(
																		DMIDArray(
																				collectionUpdateResults
																								.getNotIncludedIDs()
																								.getValue(DMIDArray()) +
																						updatesInfo.getRemovedIDs())),
																collectionUpdateResults.getLastRevision());
												}

				MDSDocumentBackingResult	documentBackingGet(const CString& documentType, const CString& documentID)
												{
													// Try to retrieve from cache
													OR<I<CMDSSQLiteDocumentBacking> >	documentBacking =
																								mDocumentBackingByDocumentID[
																										documentID];
													if (documentBacking.hasReference())
														return MDSDocumentBackingResult(*documentBacking);

													// Try to retrieve from database
													OV<I<CMDSSQLiteDocumentBacking> >	documentBackingValue;
													documentBackingsIterate(documentType, TSArray<CString>(documentID),
															(CMDSSQLiteDocumentBacking::KeyProc) storeDocumentBacking,
															&documentBackingValue);

													// Check results
													if (!documentBackingValue.hasValue())
														return MDSDocumentBackingResult(
																mDocumentStorage.getUnknownDocumentIDError(documentID));

													// Update cache
													mDocumentBackingByDocumentID.add(
															TSArray<I<CMDSSQLiteDocumentBacking> >(
																	*documentBackingValue));

													return MDSDocumentBackingResult(*documentBackingValue);
												}
				void						documentBackingsIterate(const CString& documentType,
													const TArray<CString>& documentIDs,
													CMDSSQLiteDocumentBacking::KeyProc documentBackingKeyProc,
													void* userData)
												{
													// Collect KeyAndDocumentInfos
													TNArray<KeyAndDocumentInfo>	keyAndDocumentInfos;
													mDatabaseManager.documentInfoIterate(documentType, documentIDs,
															DMDocumentInfo::ProcInfo(
																	(DMDocumentInfo::ProcInfo::Proc)
																			addDocumentInfoToKeyAndDocumentInfoArray,
																	&keyAndDocumentInfos));

													// Iterate document backings
													documentBackingsIterate(documentType, keyAndDocumentInfos,
															documentBackingKeyProc, userData);
												}
				void						documentBackingsIterate(const CString& documentType, UInt32 sinceRevision,
													const OV<UInt32>& count, bool activeOnly,
													CMDSSQLiteDocumentBacking::KeyProc documentBackingKeyProc,
													void* userData)
												{
													// Collect KeyAndDocumentInfos
													TNArray<KeyAndDocumentInfo>	keyAndDocumentInfos;
													mDatabaseManager.documentInfoIterate(documentType, sinceRevision,
															count, activeOnly,
															DMDocumentInfo::ProcInfo(
																	(DMDocumentInfo::ProcInfo::Proc)
																			addDocumentInfoToKeyAndDocumentInfoArray,
																	&keyAndDocumentInfos));

													// Iterate document backings
													documentBackingsIterate(documentType, keyAndDocumentInfos,
															documentBackingKeyProc, userData);
												}
				void						documentBackingsIterate(const CString& documentType,
													const TArray<KeyAndDocumentInfo>& keyAndDocumentInfos,
													CMDSSQLiteDocumentBacking::KeyProc documentBackingKeyProc,
													void* userData)
												{
													// Iterate infos
													TNArray<KeyAndDocumentInfo>	keyAndDocumentInfosNotFound;
													TNArray<DMDocumentInfo>		documentInfosNotFound;
													for (TIteratorD<KeyAndDocumentInfo> iterator =
																	keyAndDocumentInfos.getIterator();
															iterator.hasValue(); iterator.advance()) {
														// Check cache
														const	CString&							documentID =
																											iterator->
																													getDocumentInfo()
																													.getDocumentID();
														const	OR<I<CMDSSQLiteDocumentBacking> >	documentBacking =
																											mDocumentBackingByDocumentID[
																													documentID];
														if (documentBacking.hasReference())
															// Have in cache
															documentBackingKeyProc(iterator->getKey(), *documentBacking,
																	userData);
														else {
															// Don't have in cache
															keyAndDocumentInfosNotFound += *iterator;
															documentInfosNotFound += iterator->getDocumentInfo();
														}
													}

													// Collect DocumentContentInfos
													TNKeyConvertibleDictionary<SInt64, DMDocumentContentInfo>
															documentContentInfoByID;
													mDatabaseManager.documentContentInfoIterate(documentType,
															documentInfosNotFound,
															DMDocumentContentInfo::ProcInfo(
																	(DMDocumentContentInfo::ProcInfo::Proc)
																			addDocumentContentInfoToDictionary,
																	&documentContentInfoByID));

													// Iterate infos not found
													for (TIteratorD<KeyAndDocumentInfo> iterator =
																	keyAndDocumentInfosNotFound.getIterator();
															iterator.hasValue(); iterator.advance()) {
														// Get DocumentContentInfo
														const	DMDocumentInfo&				documentInfo =
																									iterator->
																											getDocumentInfo();
																SInt64						id = documentInfo.getID();
														const	DMDocumentContentInfo		documentContentInfo =
																									*documentContentInfoByID[
																											id];

														// Load attachment info map
														CMDSDocument::AttachmentInfoByID	documentAttachmentInfoByID =
																									mDatabaseManager
																											.documentAttachmentInfoByID(
																													documentType,
																													id);

														// Create document backing
														I<CMDSSQLiteDocumentBacking>		documentBacking(
																									new CMDSSQLiteDocumentBacking(
																											id,
																											documentInfo
																													.getDocumentID(),
																											documentInfo
																													.getRevision(),
																											documentInfo
																													.isActive(),
																											documentContentInfo
																													.getCreationUniversalTime(),
																											documentContentInfo
																													.getModificationUniversalTime(),
																											documentContentInfo
																													.getPropertyMap(),
																											documentAttachmentInfoByID));
														mDocumentBackingByDocumentID.add(
																TSArray<I<CMDSSQLiteDocumentBacking> >(documentBacking));

														// Call proc
														documentBackingKeyProc(iterator->getKey(), documentBacking,
																userData);
													}
												}

				OV<I<MDSIndex> >			indexGet(const CString& name)
												{
													// Check if have loaded
													const	OR<I<MDSIndex> >	index = mIndexByName[name];
													if (index.hasReference())
														// Have loaded
														return OV<I<MDSIndex> >(*index);

													// Check if have stored
													OV<DMIndexInfo>	indexInfo = mDatabaseManager.indexInfo(name);
													if (indexInfo.hasValue()) {
														// Have stored
														I<MDSIndex>	index(
																			new MDSIndex(name,
																					indexInfo->getDocumentType(),
																					indexInfo->getRelevantProperties(),
																					mDocumentStorage
																							.documentKeysPerformer(
																							indexInfo->
																									getKeysSelector()),
																					indexInfo->getKeysSelectorInfo(),
																					indexInfo->getLastRevision()));
														mIndexByName.set(name, index);

														return OV<I<MDSIndex> >(index);
													}

													return OV<I<MDSIndex> >();
												}
				void						indexIterate(const CString& name, const CString& documentType,
													const TArray<CString>& keys,
													CMDSSQLiteDocumentBacking::KeyProc documentBackingKeyProc,
													void* userData)
												{
													// Collect KeyAndDocumentInfos
													TNArray<KeyAndDocumentInfo>	keyAndDocumentInfos;
													mDatabaseManager.indexIterateDocumentInfos(name, documentType, keys,
															DMDocumentInfo::KeyProcInfo(
																	(DMDocumentInfo::KeyProcInfo::Proc)
																			addKeyAndDocumentInfoToArray,
																	&keyAndDocumentInfos));

													// Iterate document backings
													documentBackingsIterate(documentType, keyAndDocumentInfos,
															documentBackingKeyProc, userData);
												}
				void						indexUpdate(const I<MDSIndex>& index, const UpdatesInfo& updatesInfo)
												{
													// Update Index
													MDSIndex::UpdateResults	indexUpdateResults =
																					index->update(
																							updatesInfo
																									.getUpdateInfos());

													// Check if have updates
													if (indexUpdateResults.getKeysInfos().hasValue() ||
															!updatesInfo.getRemovedIDs().isEmpty())
														// Update database
														mDatabaseManager.indexUpdate(index->getName(),
																indexUpdateResults.getKeysInfos(),
																updatesInfo.getRemovedIDs(),
																indexUpdateResults.getLastRevision());
												}

				UpdatesInfo					getUpdatesInfo(const CString& documentType, UInt32 sinceRevision)
												{
													// Collect update infos
													UpdatesInfoBuilder	updatesInfoBuilder(mDocumentStorage,
																				mDocumentStorage.documentCreateInfo(
																						documentType),
																				mBatchByThreadRef[
																						CThread::
																								getCurrentRefAsString()]);
													documentBackingsIterate(documentType, sinceRevision, OV<UInt32>(),
															false,
															(CMDSSQLiteDocumentBacking::KeyProc)
																	processDocumentInfoForGetUpdatesInfo,
															&updatesInfoBuilder);

													return updatesInfoBuilder.getUpdatesInfo();
												}

				void						update(const CString& documentType, const UpdatesInfo& updatesInfo)
												{
													// Get caches
													const	OR<TNArray<I<MDSCache> > >	caches =
																								mCachesByDocumentType[
																										documentType];
													if (caches.hasReference())
														// Iterate caches
														for (TIteratorD<I<MDSCache> > iterator = caches->getIterator();
																iterator.hasValue(); iterator.advance())
															// Update cache
															cacheUpdate(*iterator, updatesInfo);

													// Get collections
													const	OR<TNArray<I<MDSCollection> > >	collections =
																									mCollectionsByDocumentType[
																											documentType];
													if (collections.hasReference())
														// Iterate collections
														for (TIteratorD<I<MDSCollection> > iterator =
																		collections->getIterator();
																iterator.hasValue(); iterator.advance())
															// Update collection
															collectionUpdate(*iterator, updatesInfo);

													// Get indexes
													const	OR<TNArray<I<MDSIndex> > >	indexes =
																								mIndexesByDocumentType[
																										documentType];
													if (indexes.hasReference())
														// Iterate indexes
														for (TIteratorD<I<MDSIndex> > iterator = indexes->getIterator();
																iterator.hasValue(); iterator.advance())
															// Update index
															indexUpdate(*iterator, updatesInfo);
												}

				void						process(const CString& documentID,
													const MDSBatchDocumentInfo& batchDocumentInfo,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													const TSet<CString>& changedProperties,
													const CMDSDocument::Info& documentInfo,
													MDSUpdateInfoBatchQueue& updateInfoBatchQueue,
													const CMDSDocumentStorage::DocumentChangedInfos&
															documentChangedInfos,
													CMDSDocument::ChangeKind documentChangeKind)
												{
													// Create document
													I<CMDSDocument>	document =
																			documentInfo.create(documentID,
																					mDocumentStorage);

													// Add updates to BatchQueue
													updateInfoBatchQueue.add(
															MDSUpdateInfo(document, documentBacking->getRevision(),
																	documentBacking->getID(), changedProperties));

													// Process attachments
													for (TIteratorS<CString> iterator =
																	batchDocumentInfo
																			.getRemovedAttachmentIDs()
																			.getIterator();
															iterator.hasValue(); iterator.advance())
														// Remove attachment
														documentBacking->attachmentRemove(
																batchDocumentInfo.getDocumentType(), *iterator,
																mDatabaseManager);

													const	TDictionary<MDSBatch::AddAttachmentInfo>&
																	addAttachmentInfosByID =
																			batchDocumentInfo
																					.getAddAttachmentInfosByID();
															TSet<CString>
																	attachmentIDs = addAttachmentInfosByID.getKeys();
													for (TIteratorS<CString> iterator = attachmentIDs.getIterator();
															iterator.hasValue(); iterator.advance()) {
														// Add attachment
														const	MDSBatch::AddAttachmentInfo&	batchAddAttachmentInfo =
																										*addAttachmentInfosByID[
																												*iterator];
														documentBacking->attachmentAdd(
																batchDocumentInfo.getDocumentType(),
																batchAddAttachmentInfo.getInfo(),
																batchAddAttachmentInfo.getContent(), mDatabaseManager);
													}

													const	TDictionary<MDSBatch::UpdateAttachmentInfo>&
																	updateAttachmentInfosByID =
																			batchDocumentInfo
																					.getUpdateAttachmentInfosByID();
													attachmentIDs = updateAttachmentInfosByID.getKeys();
													for (TIteratorS<CString> iterator = attachmentIDs.getIterator();
															iterator.hasValue(); iterator.advance()) {
														// Update attachment
														const	MDSBatch::UpdateAttachmentInfo&
																		batchUpdateAttachmentInfo =
																				*updateAttachmentInfosByID[*iterator];
														documentBacking->attachmentUpdate(
																batchDocumentInfo.getDocumentType(),
																batchUpdateAttachmentInfo.getID(),
																batchUpdateAttachmentInfo.getInfo(),
																batchUpdateAttachmentInfo.getContent(),
																mDatabaseManager);
													}

													// Call document changed procs
													for (TIteratorD<CMDSDocument::ChangedInfo> iterator =
																	documentChangedInfos.getIterator();
															iterator.hasValue(); iterator.advance())
														// Call proc
														iterator->notify(document, documentChangeKind);
												}

		static	void						addDocumentInfoToDocumentFullInfoArray(const CString& key,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													TNArray<CMDSDocument::FullInfo>* documentFullInfos)
												{ (*documentFullInfos) += documentBacking->getDocumentFullInfo(); }
		static	void						addDocumentIDToDocumentIDDictionary(const CString& key,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													CDictionary* documentIDByKey)
												{ documentIDByKey->set(key, documentBacking->getDocumentID()); }
		static	void						addDocumentInfoToDocumentFullInfoDictionary(const CString& key,
														const I<CMDSSQLiteDocumentBacking>& documentBacking,
												TNDictionary<CMDSDocument::FullInfo>* documentFullInfoByKey)
												{ documentFullInfoByKey->set(key,
														documentBacking->getDocumentFullInfo()); }
		static	OV<SError>					addDocumentInfoToDocumentRevisionInfoArray(
													const DMDocumentInfo& documentInfo,
													TNArray<CMDSDocument::RevisionInfo>* documentRevisionInfos)
												{
													// Add
													(*documentRevisionInfos) += documentInfo.getDocumentRevisionInfo();

													return OV<SError>();
												}
		static	OV<SError>					addDocumentInfoToDocumentRevisionInfoDictionary(const CString& key,
													const DMDocumentInfo& documentInfo,
													TNDictionary<CMDSDocument::RevisionInfo>* documentRevisionInfoByKey)
												{
													// Add
													documentRevisionInfoByKey->set(key,
															CMDSDocument::RevisionInfo(documentInfo.getDocumentID(),
																	documentInfo.getRevision()));

													return OV<SError>();
												}
		static	OV<SError>					addDocumentInfoToKeyAndDocumentInfoArray(const DMDocumentInfo& documentInfo,
													TNArray<KeyAndDocumentInfo>* keyAndDocumentInfos)
												{
													// Add
													(*keyAndDocumentInfos) +=
															KeyAndDocumentInfo(CString::mEmpty, documentInfo);

													return OV<SError>();
												}
		static	OV<SError>					addKeyAndDocumentInfoToArray(const CString& key,
													const DMDocumentInfo& documentInfo,
													TNArray<KeyAndDocumentInfo>* keyAndDocumentInfos)
												{
													// Add
													(*keyAndDocumentInfos) += KeyAndDocumentInfo(key, documentInfo);

													return OV<SError>();
												}
		static	OV<SError>					addDocumentContentInfoToDictionary(
													const DMDocumentContentInfo& documentContentInfo,
													TNKeyConvertibleDictionary<SInt64, DMDocumentContentInfo>*
															documentContentInfoByID)
												{
													// Add
													documentContentInfoByID->set(documentContentInfo.getID(),
															documentContentInfo);

													return OV<SError>();
												}
		static	void						addDocumentIDToArray(const CString& key,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													TNArray<CString>* documentIDs)
												{ documentIDs->add(documentBacking->getDocumentID()); }

		static	void						batch(BatchInfo* batchInfo)
												{
													// Setup
															Internals&					internals =
																								batchInfo->getInternals();
															CMDSDocumentStorage&		documentStorage =
																								internals.mDocumentStorage;
															CMDSSQLiteDatabaseManager&	databaseManager =
																								internals.mDatabaseManager;
													const	MDSBatch&					batch = batchInfo->getBatch();

													// Iterate all document changes
													MDSBatchDocumentInfoByDocumentIDByDocumentType	batchDocumentInfoByDocumentType =
																											batch.documentGetInfosByDocumentType();
													TSet<CString>									documentTypes =
																											batchDocumentInfoByDocumentType
																													.getKeys();
													for (TIteratorS<CString> documentTypeIterator =
																	documentTypes.getIterator();
															documentTypeIterator.hasValue(); documentTypeIterator.advance()) {
														// Setup
														const	CMDSDocument::Info&		documentInfo =
																								documentStorage
																										.documentCreateInfo(
																												*documentTypeIterator);
																DocumentChangedInfos	documentChangedInfos =
																								documentStorage
																										.documentChangedInfos(
																												*documentTypeIterator);



																Info					info(internals,
																								*documentTypeIterator);
																MDSUpdateInfoBatchQueue	updateInfoBatchQueue(
																								databaseManager
																										.getVariableNumberLimit(),
																								(MDSUpdateInfoBatchQueue
																												::Proc)
																										processUpdates,
																								&info);
																MDSRemoveBatchQueue		removeBatchQueue(
																								databaseManager
																										.getVariableNumberLimit(),
																								(MDSRemoveBatchQueue
																												::Proc)
																										processRemoves,
																								&info);

														// Update documents
														MDSBatchDocumentInfoByDocumentID	batchDocumentInfoByDocumentID =
																									*batchDocumentInfoByDocumentType
																											.get(
																											*documentTypeIterator);
														TSet<CString>						documentIDs =
																									batchDocumentInfoByDocumentID
																											.getKeys();
														for (TIteratorS<CString> documentIDIterator =
																		documentIDs.getIterator();
																documentIDIterator.hasValue();
																documentIDIterator.advance()) {
															// Setup
															const	MDSBatchDocumentInfo&	batchDocumentInfo =
																									*batchDocumentInfoByDocumentID
																											.get(*documentIDIterator);

															// Check removed
															const	OR<I<CMDSSQLiteDocumentBacking> >&	documentBacking =
																												batchDocumentInfo
																														.getDocumentBacking();
															if (!batchDocumentInfo.isRemoved()) {
																// Add/update document
																if (documentBacking.hasReference()) {
																	// Update document
																	(*documentBacking)->update(*documentTypeIterator,
																			batchDocumentInfo.getUpdatedPropertyMap(),
																			batchDocumentInfo.getRemovedProperties(),
																			databaseManager);

																	// Process
																	TNSet<CString>	changedProperties =
																							TNSet<CString>(
																									batchDocumentInfo
																											.getUpdatedPropertyMap()
																											.getKeys()) +
																									batchDocumentInfo
																											.getRemovedProperties();
																	internals.process(*documentIDIterator,
																			batchDocumentInfo, *documentBacking,
																			changedProperties, documentInfo,
																			updateInfoBatchQueue, documentChangedInfos,
																			CMDSDocument::kChangeKindUpdated);
																} else {
																	// Add document
																	I<CMDSSQLiteDocumentBacking>	newDocumentBacking(
																											new CMDSSQLiteDocumentBacking(
																													*documentTypeIterator,
																													*documentIDIterator,
																													batchDocumentInfo
																															.getCreationUniversalTime(),
																													batchDocumentInfo
																															.getModificationUniversalTime(),
																													batchDocumentInfo
																															.getUpdatedPropertyMap(),
																													databaseManager));
																	internals.mDocumentBackingByDocumentID.add(
																			TSArray<I<CMDSSQLiteDocumentBacking> >(
																					newDocumentBacking));

																	// Process
																	internals.process(*documentIDIterator,
																			batchDocumentInfo, newDocumentBacking,
																			TNSet<CString>(), documentInfo,
																			updateInfoBatchQueue, documentChangedInfos,
																			CMDSDocument::kChangeKindCreated);
																}
															} else if (documentBacking.hasReference()) {
																// Remove document
																databaseManager.documentRemove(*documentTypeIterator,
																		(*documentBacking)->getID());
																internals.mDocumentBackingByDocumentID.remove(
																		TSArray<CString>(
																				(*documentBacking)->getDocumentID()));

																// Add updates to BatchQueue
																removeBatchQueue.add((*documentBacking)->getID());

																// Check if have documentChangedProcs
																if (!documentChangedInfos.isEmpty()) {
																	// Create document
																	I<CMDSDocument>	document =
																							documentInfo.create(
																									*documentIDIterator,
																									documentStorage);

																	// Call document changed procs
																	for (TIteratorD<CMDSDocument::ChangedInfo> iterator =
																					documentChangedInfos.getIterator();
																			iterator.hasValue(); iterator.advance())
																		// Call proc
																		iterator->notify(document,
																				CMDSDocument::kChangeKindRemoved);
																}
															}
														}

														// Finalize updates
														removeBatchQueue.finalize();
														updateInfoBatchQueue.finalize();
													}

													// Iterate all association changes
													TSet<CString>	associationNames =
																			batch.associationGetUpdatedNames();
													for (TIteratorS<CString> associationNameIterator =
																	associationNames.getIterator();
															associationNameIterator.hasValue();
															associationNameIterator.advance()) {
														// Update association
														DMAssociationInfo	associationInfo =
																					*databaseManager
																							.associationInfo(
																									*associationNameIterator);
														databaseManager.associationUpdate(*associationNameIterator,
																batch.associationGetUpdates(*associationNameIterator),
																associationInfo.getFromDocumentType(),
																associationInfo.getToDocumentType());
													}
												}

		static	void						documentUpdate(DocumentUpdateInfo* documentUpdateInfo)
												{
													// Setup
													Internals&						internals =
																							documentUpdateInfo->
																									getInternals();
													CMDSSQLiteDatabaseManager&		databaseManager =
																							internals.mDatabaseManager;

													MDSDocumentUpdateByDocumentID	documentUpdateInfoByDocumentID;
													TNArray<CString>				documentIDs;
													for (TIteratorD<CMDSDocument::UpdateInfo> iterator =
																	documentUpdateInfo->getDocumentUpdateInfos()
																			.getIterator();
															iterator.hasValue(); iterator.advance()) {
														// Update
														documentUpdateInfoByDocumentID.set(iterator->getDocumentID(),
																*iterator);
														documentIDs += iterator->getDocumentID();
													}

													Info						info(internals,
																						documentUpdateInfo->
																								getDocumentType());
													MDSUpdateInfoBatchQueue		updateInfoBatchQueue(
																						databaseManager
																								.getVariableNumberLimit(),
																						(MDSUpdateInfoBatchQueue::Proc)
																								processUpdates,
																						&info);
													MDSRemoveBatchQueue			removeBatchQueue(
																						databaseManager
																								.getVariableNumberLimit(),
																						(MDSRemoveBatchQueue::Proc)
																								processRemoves,
																						&info);
													ProcessDocumentUpdateInfo	processDocumentUpdateInfo(internals,
																						documentUpdateInfo->
																								getDocumentType(),
																						documentUpdateInfo->
																								getDocumentFullInfos(),
																						documentUpdateInfoByDocumentID,
																						updateInfoBatchQueue,
																						removeBatchQueue);

													// Iterate document IDs
													internals.documentBackingsIterate(
															documentUpdateInfo->getDocumentType(), documentIDs,
															(CMDSSQLiteDocumentBacking::KeyProc)
																	processDocumentInfoForDocumentUpdate,
															&processDocumentUpdateInfo);

													// Finalize updates
													updateInfoBatchQueue.finalize();
													updateInfoBatchQueue.finalize();
												}

		static	void						processDocumentBackingForDocumentIDs(const CString& key,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													DocumentBackingDocumentIDsIterateInfo*
															documentBackingDocumentIDsIterateInfo)
												{ documentBackingDocumentIDsIterateInfo->process(
														documentBacking); }
		static	void						processDocumentBackingForSinceRevision(const CString& key,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													DocumentBackingSinceRevisionIterateInfo*
															documentBackingSinceRevisionIterateInfo)
												{ documentBackingSinceRevisionIterateInfo->process(
														documentBacking->getDocumentID()); }
		static	void						processDocumentCreate(DocumentCreateInfo* documentCreateInfo)
												{
													// Setup
													Internals&				internals =
																					documentCreateInfo->getInternals();
													UniversalTime			universalTime =
																					SUniversalTime::getCurrent();
													Info					info(internals,
																					documentCreateInfo->
																							getDocumentInfoForNew()
																							.getDocumentType());
													MDSUpdateInfoBatchQueue	batchQueue(
																					internals.mDatabaseManager
																							.getVariableNumberLimit(),
																					(MDSUpdateInfoBatchQueue::Proc)
																							processUpdates,
																					&info);

													// Iterate document create infos
													for (TIteratorD<CMDSDocument::CreateInfo> iterator =
																	documentCreateInfo->getDocumentCreateInfos()
																			.getIterator();
															iterator.hasValue(); iterator.advance()) {
														// Setup
														CString	documentID =
																		iterator->getDocumentID().hasValue() ?
																				*iterator->getDocumentID() :
																				CUUID().getBase64String();

														// Will be creating document
														internals.mDocumentsBeingCreatedPropertyMapByDocumentID.set(
																documentID, iterator->getPropertyMap());

														// Create
														I<CMDSDocument>	document =
																				documentCreateInfo->
																								getDocumentInfoForNew()
																						.create(documentID,
																								internals
																										.mDocumentStorage);

														// Remove property map
														CDictionary	propertyMap =
																			*internals
																					.mDocumentsBeingCreatedPropertyMapByDocumentID
																					.get(documentID);
														internals.mDocumentsBeingCreatedPropertyMapByDocumentID.remove(
																documentID);

														// Add document
														UniversalTime					creationUniversalTime =
																								iterator->
																										getCreationUniversalTime()
																										.getValue(universalTime);
														UniversalTime					modificationUniversalTime =
																								iterator->
																										getModificationUniversalTime()
																										.getValue(universalTime);
														I<CMDSSQLiteDocumentBacking>	documentBacking(
																								new CMDSSQLiteDocumentBacking(
																										documentCreateInfo->
																												getDocumentInfoForNew()
																												.getDocumentType(),
																										documentID,
																										creationUniversalTime,
																										modificationUniversalTime,
																										iterator->
																												getPropertyMap(),
																										internals
																												.mDatabaseManager));
														internals.mDocumentBackingByDocumentID.add(
																TSArray<I<CMDSSQLiteDocumentBacking> >(documentBacking));
														documentCreateInfo->add(
																CMDSDocument::CreateResultInfo(
																		documentCreateInfo->getDocumentInfoForNew()
																				.create(
																						documentID,
																						internals.mDocumentStorage),
																						CMDSDocument::OverviewInfo(
																								documentID,
																								documentBacking->
																										getRevision(),
																								creationUniversalTime,
																								modificationUniversalTime)));

														// Add update info
														batchQueue.add(
																MDSUpdateInfo(document, documentBacking->getRevision(),
																		documentBacking->getID(),
																		propertyMap.getKeys()));
													}

													// Finalize batch queue
													batchQueue.finalize();
												}
		static	void						processDocumentInfoForDocumentUpdate(const CString& key,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													ProcessDocumentUpdateInfo* processDocumentUpdateInfo)
												{
													// Setup
															Internals&					internals =
																								processDocumentUpdateInfo->
																										getInternals();
													const	CMDSDocument::UpdateInfo&	documentUpdateInfo =
																								processDocumentUpdateInfo->
																										getDocumentUpdateInfo(
																												documentBacking->
																														getDocumentID());

													// Check active
													if (documentUpdateInfo.getActive()) {
														// Update document backing
														documentBacking->update(
																processDocumentUpdateInfo->getDocumentType(),
																documentUpdateInfo.getUpdated(),
																documentUpdateInfo.getRemoved(),
																internals.mDatabaseManager);

														// Add update
														processDocumentUpdateInfo->update(
																processDocumentUpdateInfo->documentCreate(
																		documentBacking->getDocumentID()),
																documentBacking->getRevision(),
																documentBacking->getID(),
																TNSet<CString>(
																		documentUpdateInfo.getUpdated().getKeys()) +
																		documentUpdateInfo.getRemoved());
													} else {
														// Remove document
														internals.mDatabaseManager.documentRemove(
																processDocumentUpdateInfo->getDocumentType(),
																documentBacking->getID());
														internals.mDocumentBackingByDocumentID.remove(
																TSArray<CString>(documentBacking->getDocumentID()));

														// Add remove
														processDocumentUpdateInfo->remove(documentBacking->getID());
													}

													// Add document full info
													processDocumentUpdateInfo->add(
															documentBacking->getDocumentFullInfo());
												}
		static	void						processDocumentInfoForGetUpdatesInfo(const CString& key,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													UpdatesInfoBuilder* updatesInfoBuilder)
												{
													// Query batch info
													bool	removed = false;
													if (updatesInfoBuilder->getBatch().hasReference()) {
														// Have batch
														OR<MDSBatchDocumentInfo>	batchDocumentInfo =
																							(*updatesInfoBuilder->getBatch())->
																											documentInfoGet(
																									documentBacking->
																											getDocumentID());
														if (batchDocumentInfo.hasReference())
															// Have document info
															removed = batchDocumentInfo->isRemoved();
													}

													// Check if processing this document
													if (!removed && documentBacking->getActive())
														// Append info
														updatesInfoBuilder->addUpdateInfo(documentBacking);
													else
														// Removed
														updatesInfoBuilder->noteRemoved(documentBacking);
												}
		static	void						processRemoves(const DMIDArray& removedIDs, Info* info)
												{ info->getInternals().update(info->getDocumentType(),
														UpdatesInfo(removedIDs)); }
		static	void						processUpdates(const TArray<MDSUpdateInfo>& updateInfos, Info* info)
												{ info->getInternals().update(info->getDocumentType(),
														UpdatesInfo(updateInfos)); }
		static	OV<SError>					removeDocumentIDFromSet(const DMDocumentInfo& documentInfo,
													TNSet<CString>* documentIDs)
												{
													// Remove
													documentIDs->remove(documentInfo.getDocumentID());

													return OV<SError>();
												}
		static	void						storeDocumentBacking(const CString& key,
													const I<CMDSSQLiteDocumentBacking>& documentBacking,
													OV<I<CMDSSQLiteDocumentBacking> >* documentBackingValue)
												{ documentBackingValue->setValue(documentBacking); }

	public:
		CMDSDocumentStorage&									mDocumentStorage;

		TNLockingDictionary<I<CMDSAssociation> >				mAssociationByName;

		TNLockingDictionary<I<MDSBatch> >						mBatchByThreadRef;

		TNLockingDictionary<I<MDSCache> >						mCacheByName;
		TNLockingArrayDictionary<I<MDSCache> >					mCachesByDocumentType;

		TNLockingDictionary<I<MDSCollection> >					mCollectionByName;
		TNLockingArrayDictionary<I<MDSCollection> >				mCollectionsByDocumentType;

		CMDSSQLiteDatabaseManager								mDatabaseManager;

		TMDSDocumentBackingCache<I<CMDSSQLiteDocumentBacking> >	mDocumentBackingByDocumentID;
		TNLockingDictionary<CDictionary>						mDocumentsBeingCreatedPropertyMapByDocumentID;

		TNLockingDictionary<I<MDSIndex> >						mIndexByName;
		TNLockingArrayDictionary<I<MDSIndex> >					mIndexesByDocumentType;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLite

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLite::CMDSSQLite(const CFolder& folder, const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = new Internals(*this, folder, name);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLite::~CMDSSQLite()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: CMDSDocumentStorage methods

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::associationRegister(const CString& name, const CString& fromDocumentType,
		const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Register
	mInternals->mDatabaseManager.associationRegister(name, fromDocumentType, toDocumentType);

	// Create or re-create association
	I<CMDSAssociation>	association(new CMDSAssociation(name, fromDocumentType, toDocumentType));

	// Add to map
	mInternals->mAssociationByName.set(name, association);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSAssociation::Item> > CMDSSQLite::associationGet(const CString& name) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return TVResult<TArray<CMDSAssociation::Item> >(getUnknownAssociationError(name));

	// Get association items
	TArray<CMDSAssociation::Item>	associationItems =
											mInternals->mDatabaseManager.associationGet(name,
													(*association)->getFromDocumentType(),
													(*association)->getToDocumentType());

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference())
		// Apply batch changes
		associationItems = (*batch)->associationItemsApplyingChanges(name, associationItems);

	return TVResult<TArray<CMDSAssociation::Item> >(associationItems);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::associationIterateFrom(const CString& name, const CString& fromDocumentID,
		const CString& toDocumentType, CMDSDocument::Proc proc, void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return OV<SError>(getUnknownAssociationError(name));

	// Get association items
	TVResult<TArray<CMDSAssociation::Item> >	associationItemsResult =
														mInternals->mDatabaseManager.associationGetFrom(name,
																fromDocumentID, (*association)->getFromDocumentType(),
																toDocumentType);
	ReturnErrorIfResultError(associationItemsResult);
	TArray<CMDSAssociation::Item>	associationItems = *associationItemsResult;

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference())
		// Apply batch changes
		associationItems = (*batch)->associationItemsApplyingChanges(name, associationItems);

	// Iterate document IDs;
	const	CMDSDocument::Info&	documentInfo = documentCreateInfo(toDocumentType);
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check fromDocumentID
		if (iterator->getFromDocumentID() == fromDocumentID)
			// Call proc
			proc(documentInfo.create(iterator->getToDocumentID(), (CMDSDocumentStorage&) *this), procUserData);
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::associationIterateTo(const CString& name, const CString& fromDocumentType,
		const CString& toDocumentID, CMDSDocument::Proc proc, void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return OV<SError>(getUnknownAssociationError(name));

	// Get association items
	TVResult<TArray<CMDSAssociation::Item> >	associationItemsResult =
														mInternals->mDatabaseManager.associationGetTo(name,
																fromDocumentType, toDocumentID,
																(*association)->getToDocumentType());
	ReturnErrorIfResultError(associationItemsResult);
	TArray<CMDSAssociation::Item>	associationItems = *associationItemsResult;

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference())
		// Apply batch changes
		associationItems = (*batch)->associationItemsApplyingChanges(name, associationItems);

	// Iterate document IDs;
	const	CMDSDocument::Info&	documentInfo = documentCreateInfo(fromDocumentType);
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check fromDocumentID
		if (iterator->getToDocumentID() == toDocumentID)
			// Call proc
			proc(documentInfo.create(iterator->getFromDocumentID(), (CMDSDocumentStorage&) *this), procUserData);
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CDictionary> CMDSSQLite::associationGetIntegerValues(const CString& name,
		CMDSAssociation::GetIntegerValueAction action, const TArray<CString>& fromDocumentIDs, const CString& cacheName,
		const TArray<CString>& cachedValueNames) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return TVResult<CDictionary>(getUnknownAssociationError(name));
	OV<I<MDSCache> >	cache = mInternals->cacheGet(cacheName);
	if (!cache.hasValue())
		return TVResult<CDictionary>(getUnknownCacheError(cacheName));
	for (TIteratorD<CString> iterator = cachedValueNames.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check if have info for this cachedValueName
		if (!(*cache)->hasValueInfo(*iterator))
			return TVResult<CDictionary>(getUnknownCacheValueName(*iterator));
	}

	// Setup
	TNArray<CString>	fromDocumentIDsUse(fromDocumentIDs);

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// Get updates
		TArray<CMDSAssociation::Update>	associationUpdates = (*batch)->associationGetUpdates(name);
		for (TIteratorD<CMDSAssociation::Update> iterator = associationUpdates.getIterator(); iterator.hasValue();
				iterator.advance()) {
			// Check action
			if (iterator->getAction() == CMDSAssociation::Update::kActionAdd)
				// Add
				fromDocumentIDsUse += iterator->getItem().getFromDocumentID();
			else
				// Remove
				fromDocumentIDsUse -= iterator->getItem().getFromDocumentID();
		}
	}

	// Check action
	switch (action) {
		case CMDSAssociation::kGetIntegerValueActionSum:
			// Sum
			return mInternals->mDatabaseManager.associationSum(name, fromDocumentIDsUse,
					(*association)->getFromDocumentType(), cacheName, cachedValueNames);
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::associationUpdate(const CString& name, const TArray<CMDSAssociation::Update>& updates)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return OV<SError>(getUnknownAssociationError(name));

	// Check if have updates
	if (updates.isEmpty())
		return OV<SError>();

	// Setup
	TNSet<CString>	updateFromDocumentIDs = CMDSAssociation::Update::getFromDocumentIDsSet(updates);
	mInternals->mDatabaseManager.documentInfoIterate((*association)->getFromDocumentType(),
			updateFromDocumentIDs.getArray(),
			DMDocumentInfo::ProcInfo((DMDocumentInfo::ProcInfo::Proc) Internals::removeDocumentIDFromSet,
					&updateFromDocumentIDs));

	TNSet<CString>	updateToDocumentIDs = CMDSAssociation::Update::getToDocumentIDsSet(updates);
	mInternals->mDatabaseManager.documentInfoIterate((*association)->getToDocumentType(),
			updateToDocumentIDs.getArray(),
			DMDocumentInfo::ProcInfo((DMDocumentInfo::ProcInfo::Proc) Internals::removeDocumentIDFromSet,
					&updateToDocumentIDs));

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		// Ensure all update from documentIDs exist
		updateFromDocumentIDs -= (*batch)->documentIDsGet((*association)->getFromDocumentType());
		if (!updateFromDocumentIDs.isEmpty())
			return OV<SError>(getUnknownDocumentIDError(updateFromDocumentIDs.getArray()[0]));

		// Ensure all update to documentIDs exist
		updateToDocumentIDs -= (*batch)->documentIDsGet((*association)->getToDocumentType());
		if (!updateToDocumentIDs.isEmpty())
			return OV<SError>(getUnknownDocumentIDError(updateToDocumentIDs.getArray()[0]));

		// Update
		(*batch)->associationNoteUpdated(name, updates);
	} else {
		// Not in batch
		if (!updateFromDocumentIDs.isEmpty())
			return OV<SError>(getUnknownDocumentIDError(updateFromDocumentIDs.getArray()[0]));
		if (!updateToDocumentIDs.isEmpty())
			return OV<SError>(getUnknownDocumentIDError(updateToDocumentIDs.getArray()[0]));

		// Update
		mInternals->mDatabaseManager.associationUpdate(name, updates, (*association)->getFromDocumentType(),
				(*association)->getToDocumentType());
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::cacheRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, const TArray<CacheValueInfo>& cacheValueInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove current cache if found
	if (mInternals->mCacheByName.contains(name))
		// Remove
		mInternals->mCacheByName.remove(name);

	// Setup
	TNArray<DMCacheValueInfo>	_cacheValueInfos;
	TNArray<SMDSCacheValueInfo>	__cacheValueInfos;
	for (TIteratorD<CacheValueInfo> iterator = cacheValueInfos.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Add
		_cacheValueInfos +=
				DMCacheValueInfo(iterator->getValueInfo().getName(), iterator->getValueInfo().getValueType(),
						iterator->getSelector());
		__cacheValueInfos +=
				SMDSCacheValueInfo(iterator->getValueInfo(), documentValueInfo(iterator->getSelector()));
	}

	// Register cache
	UInt32	lastRevision =
					mInternals->mDatabaseManager.cacheRegister(name, documentType, relevantProperties,
							_cacheValueInfos);

	// Create or re-create
	I<MDSCache>	cache(new MDSCache(name, documentType, relevantProperties, __cacheValueInfos, lastRevision));

	// Add to maps
	mInternals->mCacheByName.set(name, cache);
	mInternals->mCachesByDocumentType.add(documentType, cache);

	// Bring up to date
	mInternals->cacheUpdate(cache, mInternals->getUpdatesInfo(documentType, lastRevision));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::collectionRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, bool isUpToDate, const CDictionary& isIncludedInfo,
		const CMDSDocument::IsIncludedPerformer& documentIsIncludedPerformer)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove current collection if found
	if (mInternals->mCollectionByName.contains(name))
		// Remove
		mInternals->mCollectionByName.remove(name);

	// Register collection
	UInt32	lastRevision =
					mInternals->mDatabaseManager.collectionRegister(name, documentType, relevantProperties,
							documentIsIncludedPerformer.getSelector(), isIncludedInfo, isUpToDate);

	// Create or re-create collection
	I<MDSCollection>	collection(
								new MDSCollection(name, documentType, relevantProperties, documentIsIncludedPerformer,
										isIncludedInfo, lastRevision));

	// Add to maps
	mInternals->mCollectionByName.set(name, collection);
	mInternals->mCollectionsByDocumentType.add(documentType, collection);

	// Check if is up to date
	if (!isUpToDate)
		// Bring up to date
		mInternals->collectionUpdate(collection, mInternals->getUpdatesInfo(documentType, lastRevision));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<UInt32> CMDSSQLite::collectionGetDocumentCount(const CString& name) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<MDSCollection> >	collection = mInternals->collectionGet(name);
	if (!collection.hasValue())
		return TVResult<UInt32>(getUnknownCollectionError(name));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return TVResult<UInt32>(getIllegalInBatchError());

	// Bring up to date
	mInternals->collectionUpdate(*collection, mInternals->getUpdatesInfo((*collection)->getDocumentType(), 0));

	return TVResult<UInt32>(mInternals->mDatabaseManager.collectionGetDocumentCount(name));
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::collectionIterate(const CString& name, const CString& documentType, CMDSDocument::Proc proc,
		void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<MDSCollection> >	collection = mInternals->collectionGet(name);
	if (!collection.hasValue())
		return OV<SError>(getUnknownCollectionError(name));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return OV<SError>(getIllegalInBatchError());

	// Bring up to date
	mInternals->collectionUpdate(*collection, mInternals->getUpdatesInfo((*collection)->getDocumentType(), 0));

	// Collect document IDs
	TNArray<CString>	documentIDs;
	mInternals->collectionIterate(name, documentType, 0, OV<UInt32>(),
			(CMDSSQLiteDocumentBacking::KeyProc) Internals::addDocumentIDToArray, &documentIDs);

	// Setup
	const	CMDSDocument::Info&	documentInfo = documentCreateInfo(documentType);

	// Iterate document IDs
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance())
		// Call proc
		proc(documentInfo.create(*iterator, (CMDSDocumentStorage&) *this), procUserData);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::CreateResultInfo> > CMDSSQLite::documentCreate(
		const CMDSDocument::InfoForNew& documentInfoForNew, const TArray<CMDSDocument::CreateInfo>& documentCreateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	TNArray<CMDSDocument::CreateResultInfo>	documentCreateResultInfos;

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		UniversalTime	universalTime = SUniversalTime::getCurrent();
		for (TIteratorD<CMDSDocument::CreateInfo> iterator = documentCreateInfos.getIterator(); iterator.hasValue();
				iterator.advance()) {
			// Setup
			CString	documentID =
							iterator->getDocumentID().hasValue() ?
									*iterator->getDocumentID() : CUUID().getBase64String();

			// Add document
			(*batch)->documentAdd(documentInfoForNew.getDocumentType(), documentID,
					iterator->getCreationUniversalTime().getValue(universalTime),
					iterator->getModificationUniversalTime().getValue(universalTime),
					OV<CDictionary>(iterator->getPropertyMap()));
			documentCreateResultInfos += CMDSDocument::CreateResultInfo(documentInfoForNew.create(documentID, *this));
		}
	} else {
		// Batch
		Internals::DocumentCreateInfo	documentCreateInfo(*mInternals, documentInfoForNew, documentCreateInfos,
												documentCreateResultInfos);
		mInternals->mDatabaseManager.batch((CMDSSQLiteDatabaseManager::BatchProc) Internals::processDocumentCreate,
				&documentCreateInfo);

		// Call document changed procs
		for (TIteratorD<CMDSDocument::CreateResultInfo> iterator = documentCreateResultInfos.getIterator();
				iterator.hasValue(); iterator.advance())
			// Call proc
			notifyDocumentChanged(iterator->getDocument(), CMDSDocument::kChangeKindCreated);
	}

	return TVResult<TArray<CMDSDocument::CreateResultInfo> >(documentCreateResultInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<UInt32> CMDSSQLite::documentGetCount(const CString& documentType) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<UInt32>(getUnknownDocumentTypeError(documentType));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return TVResult<UInt32>(getIllegalInBatchError());

	return TVResult<UInt32>(mInternals->mDatabaseManager.documentCount(documentType));
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::documentIterate(const CMDSDocument::Info& documentInfo, const TArray<CString>& documentIDs,
		CMDSDocument::Proc proc, void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentInfo.getDocumentType()))
		return OV<SError>(getUnknownDocumentTypeError(documentInfo.getDocumentType()));

	// Setup
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];

	// Iterate initial document IDs
	TNArray<CString>	documentIDsToCache;
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check what we have currently
		if (batch.hasReference() && (*batch)->documentInfoGet(*iterator).hasReference())
			// Have document in batch
			proc(documentInfo.create(*iterator, (CMDSDocumentStorage&) *this), procUserData);
		else if (mInternals->mDocumentBackingByDocumentID.getDocumentBacking(*iterator).hasReference())
			// Have documentBacking in cache
			proc(documentInfo.create(*iterator, (CMDSDocumentStorage&) *this), procUserData);
		else
			// Will need to retrieve from database
			documentIDsToCache += *iterator;
	}

	// Iterate document IDs not found in batch or cache
	Internals::DocumentBackingDocumentIDsIterateInfo	documentBackingDocumentIDsIterateInfo(documentInfo,
																(CMDSDocumentStorage&) *this, documentIDsToCache, proc,
																procUserData);
	mInternals->documentBackingsIterate(documentInfo.getDocumentType(), documentIDsToCache,
			(CMDSSQLiteDocumentBacking::KeyProc) Internals::processDocumentBackingForDocumentIDs,
			&documentBackingDocumentIDsIterateInfo);

	// Check if have any that we didn't find
	if (!documentIDsToCache.isEmpty())
		return OV<SError>(getUnknownDocumentIDError(documentIDsToCache[0]));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::documentIterate(const CMDSDocument::Info& documentInfo, bool activeOnly, CMDSDocument::Proc proc,
		void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentInfo.getDocumentType()))
		return OV<SError>(getUnknownDocumentTypeError(documentInfo.getDocumentType()));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return OV<SError>(getIllegalInBatchError());

	// Iterate document backings
	Internals::DocumentBackingSinceRevisionIterateInfo	documentBackingSinceRevisionIterateInfo(documentInfo,
																(CMDSDocumentStorage&) *this, proc, procUserData);
	mInternals->documentBackingsIterate(documentInfo.getDocumentType(), 0, OV<UInt32>(), activeOnly,
			(CMDSSQLiteDocumentBacking::KeyProc) Internals::processDocumentBackingForSinceRevision,
			&documentBackingSinceRevisionIterateInfo);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSSQLite::documentCreationUniversalTime(const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<MDSBatch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<MDSBatchDocumentInfo>	batchDocumentInfo =
												batch.hasReference() ?
														(*batch)->documentInfoGet(document->getID()) :
														OR<MDSBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getCreationUniversalTime();
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(document->getID()))
		// Being created
		return SUniversalTime::getCurrent();
	else
		// "Idle"
		return (*mInternals->documentBackingGet(document->getDocumentType(), document->getID()))->
				getCreationUniversalTime();
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSSQLite::documentModificationUniversalTime(const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<MDSBatch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<MDSBatchDocumentInfo>	batchDocumentInfo =
												batch.hasReference() ?
														(*batch)->documentInfoGet(document->getID()) :
														OR<MDSBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getModificationUniversalTime();
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(document->getID()))
		// Being created
		return SUniversalTime::getCurrent();
	else
		// "Idle"
		return (*mInternals->documentBackingGet(document->getDocumentType(), document->getID()))->
				getModificationUniversalTime();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SValue> CMDSSQLite::documentValue(const CString& property, const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<MDSBatch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<MDSBatchDocumentInfo>	batchDocumentInfo =
												batch.hasReference() ?
														(*batch)->documentInfoGet(document->getID()) :
														OR<MDSBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getValue(property);
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(document->getID()))
		// Being created
		return mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID[document->getID()]->getOValue(property);
	else
		// "Idle"
		return (*mInternals->documentBackingGet(document->getDocumentType(), document->getID()))->
				getPropertyMap().getOValue(property);
}

//----------------------------------------------------------------------------------------------------------------------
OV<CData> CMDSSQLite::documentData(const CString& property, const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve Base64-encoded string
	OV<SValue>	value = documentValue(property, document);
	if (!value.hasValue())
		return OV<CData>();

	return OV<CData>(CData::fromBase64String(value->getString()));
}

//----------------------------------------------------------------------------------------------------------------------
OV<UniversalTime> CMDSSQLite::documentUniversalTime(const CString& property, const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = documentValue(property, document);
	if (!value.hasValue())
		return OV<UniversalTime>();

	OV<SGregorianDate>	gregorianDate = SGregorianDate::getFrom(value->getString());
	if (!gregorianDate.hasValue())
		return OV<UniversalTime>();

	return OV<UniversalTime>(gregorianDate->getUniversalTime());
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::documentSet(const CString& property, const OV<SValue>& value, const I<CMDSDocument>& document,
		SetValueKind setValueKind)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	CString&	documentType = document->getDocumentType();
	const	CString&	documentID = document->getID();

	// Transform
	OV<SValue>	valueUse;
	if (value.hasValue() && (value->getType() == SValue::kTypeData))
		// Data
		valueUse = OV<SValue>(value->getData().getBase64String());
	else if (value.hasValue() && (setValueKind == kSetValueKindUniversalTime))
		// UniversalTime
		valueUse = OV<SValue>(SValue(SGregorianDate(value->getFloat64()).getString()));
	else
		// Everything else
		valueUse = value;

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		OR<MDSBatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(documentID);
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->set(property, valueUse);
		else {
			// Don't have document in batch
			I<CMDSSQLiteDocumentBacking>	documentBacking =
													mInternals->documentBackingGet(documentType, documentID).getValue();
			(*batch)->documentAdd(documentType, R<I<CMDSSQLiteDocumentBacking> >(documentBacking))
					.set(property, valueUse);
		}
	} else {
		// Check if being created
		const	OR<CDictionary>	propertyMap = mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID[documentID];
		if (propertyMap.hasReference())
			// Being created
			propertyMap->set(property, value);
		else {
			// Update document
			I<CMDSSQLiteDocumentBacking>	documentBacking =
													mInternals->documentBackingGet(documentType, documentID).getValue();
			documentBacking->set(property, valueUse, documentType, mInternals->mDatabaseManager);

			// Update stuffs
			mInternals->update(documentType,
					Internals::UpdatesInfo(
							TSArray<MDSUpdateInfo>(
									MDSUpdateInfo(document, documentBacking->getRevision(), documentBacking->getID(),
											TNSet<CString>(property)))));

			// Call document changed procs
			notifyDocumentChanged(document, CMDSDocument::kChangeKindUpdated);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocument::AttachmentInfo> CMDSSQLite::documentAttachmentAdd(const CString& documentType,
		const CString& documentID, const CDictionary& info, const CData& content)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<CMDSDocument::AttachmentInfo>(getUnknownDocumentTypeError(documentType));

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		OR<MDSBatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(documentID);
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			return TVResult<CMDSDocument::AttachmentInfo>(batchDocumentInfo->attachmentAdd(info, content));
		else {
			// Don't have document in batch
			I<CMDSSQLiteDocumentBacking>	documentBacking =
													mInternals->documentBackingGet(documentType, documentID).getValue();
			return TVResult<CMDSDocument::AttachmentInfo>(
					(*batch)->documentAdd(documentType, R<I<CMDSSQLiteDocumentBacking> >(documentBacking))
							.attachmentAdd(info, content));
		}
	} else {
		// Not in batch
		MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);

		return documentBacking.hasValue() ?
				TVResult<CMDSDocument::AttachmentInfo>(
						(*documentBacking)->attachmentAdd(documentType, info, content, mInternals->mDatabaseManager)) :
				TVResult<CMDSDocument::AttachmentInfo>(getUnknownDocumentIDError(documentID));
	}
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocument::AttachmentInfoByID> CMDSSQLite::documentAttachmentInfoByID(const CString& documentType,
		const CString& documentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<CMDSDocument::AttachmentInfoByID>(getUnknownDocumentTypeError(documentType));

	// Check for batch
	const	OR<I<MDSBatch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<MDSBatchDocumentInfo>	batchDocumentInfo =
												batch.hasReference() ?
														(*batch)->documentInfoGet(documentID) :
														OR<MDSBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference()) {
		// Have document in batch
		const	OR<I<CMDSSQLiteDocumentBacking> >	documentBacking = batchDocumentInfo->getDocumentBacking();

		return TVResult<CMDSDocument::AttachmentInfoByID>(
				batchDocumentInfo->getUpdatedDocumentAttachmentInfoByID(
						documentBacking.hasReference() ?
								(*documentBacking)->getDocumentAttachmentInfoByID() :
								TNDictionary<CMDSDocument::AttachmentInfo>()));
	} else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(documentID))
		// Creating
		return TVResult<CMDSDocument::AttachmentInfoByID>(TNDictionary<CMDSDocument::AttachmentInfo>());
	else {
		// Not in batch
		MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);

		return documentBacking.hasValue() ?
				TVResult<CMDSDocument::AttachmentInfoByID>((*documentBacking)->getDocumentAttachmentInfoByID()) :
				TVResult<CMDSDocument::AttachmentInfoByID>(getUnknownDocumentIDError(documentID));
	}
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CData> CMDSSQLite::documentAttachmentContent(const CString& documentType, const CString& documentID,
		const CString& attachmentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<CData>(getUnknownDocumentTypeError(documentType));

	// Check for batch
	const	OR<I<MDSBatch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<MDSBatchDocumentInfo>	batchDocumentInfo =
												batch.hasReference() ?
														(*batch)->documentInfoGet(documentID) :
														OR<MDSBatchDocumentInfo>();
			OV<CData>					data =
												batchDocumentInfo.hasReference() ?
														batchDocumentInfo->getAttachmentContent(attachmentID) :
														OV<CData>();
	if (data.hasValue())
		// Found
		return TVResult<CData>(*data);
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(documentID))
		// Creating
		return TVResult<CData>(getUnknownAttachmentIDError(attachmentID));

	// Get non-batch attachment content
	MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);
	if (!documentBacking.hasValue())
		return TVResult<CData>(getUnknownDocumentIDError(documentID));
	if (!(*documentBacking)->getDocumentAttachmentInfoByID().contains(attachmentID))
		return TVResult<CData>(getUnknownAttachmentIDError(attachmentID));

	return TVResult<CData>(
			(*documentBacking)->attachmentContent(documentType, attachmentID, mInternals->mDatabaseManager));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<OV<UInt32> > CMDSSQLite::documentAttachmentUpdate(const CString& documentType, const CString& documentID,
		const CString& attachmentID, const CDictionary& updatedInfo, const CData& updatedContent)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<OV<UInt32> >(getUnknownDocumentTypeError(documentType));

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		OR<MDSBatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(documentID);
		if (batchDocumentInfo.hasReference()) {
			// Have document in batch
			const	OR<I<CMDSSQLiteDocumentBacking> >	documentBacking = batchDocumentInfo->getDocumentBacking();
					CMDSDocument::AttachmentInfoByID	documentAttachmentInfoByID =
																batchDocumentInfo->getUpdatedDocumentAttachmentInfoByID(
																		documentBacking.hasReference() ?
																				(*documentBacking)->
																						getDocumentAttachmentInfoByID() :
																				TNDictionary<
																						CMDSDocument::AttachmentInfo>());
			const	OR<CMDSDocument::AttachmentInfo>	documentAttachmentInfo =
																documentAttachmentInfoByID[attachmentID];
			if (!documentAttachmentInfo.hasReference())
				return TVResult<OV<UInt32> >(getUnknownAttachmentIDError(attachmentID));

			batchDocumentInfo->attachmentUpdate(attachmentID, documentAttachmentInfo->getRevision(), updatedInfo,
					updatedContent);
		} else {
			// Don't have document in batch
			MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);
			if (!documentBacking.hasValue())
				return TVResult<OV<UInt32> >(getUnknownDocumentIDError(documentID));

			const	OR<CMDSDocument::AttachmentInfo>	documentAttachmentInfo =
																(*documentBacking)->getDocumentAttachmentInfoByID()
																		[attachmentID];
			if (!documentAttachmentInfo.hasReference())
				return TVResult<OV<UInt32> >(getUnknownAttachmentIDError(attachmentID));

			(*batch)->documentAdd(documentType,
							R<I<CMDSSQLiteDocumentBacking> >(*((I<CMDSSQLiteDocumentBacking>*) &*documentBacking)))
					.attachmentUpdate(attachmentID, documentAttachmentInfo->getRevision(), updatedInfo, updatedContent);
		}

		return TVResult<OV<UInt32> >(OV<UInt32>());
	} else {
		// Not in batch
		MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);
		if (!documentBacking.hasValue())
			return TVResult<OV<UInt32> >(getUnknownDocumentIDError(documentID));

		const	OR<CMDSDocument::AttachmentInfo>	documentAttachmentInfo =
															(*documentBacking)->getDocumentAttachmentInfoByID()
																	[attachmentID];
		if (!documentAttachmentInfo.hasReference())
			return TVResult<OV<UInt32> >(getUnknownAttachmentIDError(attachmentID));

		// Update attachment
		return TVResult<OV<UInt32> >(
				(*documentBacking)->attachmentUpdate(documentType, attachmentID, updatedInfo, updatedContent,
						mInternals->mDatabaseManager));
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::documentAttachmentRemove(const CString& documentType, const CString& documentID,
		const CString& attachmentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return OV<SError>(getUnknownDocumentTypeError(documentType));

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		OR<MDSBatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(documentID);
		if (batchDocumentInfo.hasReference()) {
			// Have document in batch
			const	OR<I<CMDSSQLiteDocumentBacking> >	documentBacking = batchDocumentInfo->getDocumentBacking();
					CMDSDocument::AttachmentInfoByID	documentAttachmentInfoByID =
																batchDocumentInfo->getUpdatedDocumentAttachmentInfoByID(
																		documentBacking.hasReference() ?
																				(*documentBacking)->
																						getDocumentAttachmentInfoByID() :
																				TNDictionary<
																						CMDSDocument::AttachmentInfo>());
			if (!documentAttachmentInfoByID.contains(attachmentID))
				return OV<SError>(getUnknownAttachmentIDError(attachmentID));

			batchDocumentInfo->attachmentRemove(attachmentID);
		} else {
			// Don't have document in batch
			MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);
			if (!documentBacking.hasValue())
				return OV<SError>(getUnknownDocumentIDError(documentID));
			if (!(*documentBacking)->getDocumentAttachmentInfoByID().contains(attachmentID))
				return OV<SError>(getUnknownAttachmentIDError(attachmentID));

			(*batch)->documentAdd(documentType,
							R<I<CMDSSQLiteDocumentBacking> >(*((I<CMDSSQLiteDocumentBacking>*) &*documentBacking)))
					.attachmentRemove(attachmentID);
		}
	} else {
		// Not in batch
		MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);
		if (!documentBacking.hasValue())
			return OV<SError>(getUnknownDocumentIDError(documentID));
		if (!(*documentBacking)->getDocumentAttachmentInfoByID().contains(attachmentID))
			return OV<SError>(getUnknownAttachmentIDError(attachmentID));

		// Remove attachment
		(*documentBacking)->attachmentRemove(documentType, attachmentID, mInternals->mDatabaseManager);
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::documentRemove(const I<CMDSDocument>& document)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	CString&	documentType = document->getDocumentType();
	const	CString&	documentID = document->getID();

	// Check for batch
	const	OR<I<MDSBatch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		OR<MDSBatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(documentID);
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->remove();
		else {
			// Don't have document in batch
			MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);
			(*batch)->documentAdd(documentType,
							R<I<CMDSSQLiteDocumentBacking> >(*((I<CMDSSQLiteDocumentBacking>*) &*documentBacking)))
					.remove();
		}
	} else {
		// Not in batch
		MDSDocumentBackingResult	documentBacking = mInternals->documentBackingGet(documentType, documentID);

		// Remove from stuffs
		mInternals->update(documentType,
				Internals::UpdatesInfo(TNArray<MDSUpdateInfo>(), DMIDArray((*documentBacking)->getID())));

		// Remove
		mInternals->mDatabaseManager.documentRemove(documentType, (*documentBacking)->getID());

		// Remove from cache
		mInternals->mDocumentBackingByDocumentID.remove(TSArray<CString>(documentID));

		// Call document changed procs
		notifyDocumentChanged(document, CMDSDocument::kChangeKindRemoved);
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::indexRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, const CDictionary& keysInfo,
		const CMDSDocument::KeysPerformer& documentKeysPerformer)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove current index if found
	if (mInternals->mIndexByName.contains(name))
		// Remove
		mInternals->mIndexByName.remove(name);

	// Register index
	UInt32	lastRevision =
					mInternals->mDatabaseManager.indexRegister(name, documentType, relevantProperties,
							documentKeysPerformer.getSelector(), keysInfo);

	// Create or re-create index
	I<MDSIndex>	index(
						new MDSIndex(name, documentType, relevantProperties, documentKeysPerformer, keysInfo,
								lastRevision));

	// Add to maps
	mInternals->mIndexByName.set(name, index);
	mInternals->mIndexesByDocumentType.add(documentType, index);

	// Bring up to date
	mInternals->indexUpdate(index, mInternals->getUpdatesInfo(documentType, lastRevision));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::indexIterate(const CString& name, const CString& documentType, const TArray<CString>& keys,
		CMDSDocument::KeyProc documentKeyProc, void* documentKeyProcUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<MDSIndex> >	index = mInternals->indexGet(name);
	if (!index.hasValue())
		return OV<SError>(getUnknownIndexError(name));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return OV<SError>(getIllegalInBatchError());

	// Bring up to date
	mInternals->indexUpdate((*index), mInternals->getUpdatesInfo(documentType, 0));

	// Compose map
	CDictionary	documentIDByKey;
	mInternals->indexIterate(name, documentType, keys,
			(CMDSSQLiteDocumentBacking::KeyProc) Internals::addDocumentIDToDocumentIDDictionary, &documentIDByKey);

	// Iterate map
	const	CMDSDocument::Info&	documentInfo = documentCreateInfo(documentType);
	for (TIteratorS<CDictionary::Item> iterator = documentIDByKey.getIterator(); iterator.hasValue();
			iterator.advance())
		// Call proc
		documentKeyProc(iterator->mKey, documentInfo.create(iterator->mValue.getString(), (CMDSDocumentStorage&) *this),
				documentKeyProcUserData);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<CString> > CMDSSQLite::infoGet(const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect info
	TNDictionary<CString>	info;
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance())
		// Update info
		info.set(*iterator, mInternals->mDatabaseManager.infoString(*iterator));

	return TVResult<TDictionary<CString> >(info);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::infoSet(const TDictionary<CString>& info)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TIteratorS<CDictionary::Item> iterator = info.getIterator(); iterator.hasValue(); iterator.advance())
		// Set
		mInternals->mDatabaseManager.infoSet(iterator->mKey, OV<CString>(*info[iterator->mKey]));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::infoRemove(const TArray<CString>& keys)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance())
		// Remove
		mInternals->mDatabaseManager.infoSet(*iterator, OV<CString>());

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<CString> > CMDSSQLite::internalGet(const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect info
	TNDictionary<CString>	info;
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance())
		// Update info
		info.set(*iterator, mInternals->mDatabaseManager.internalString(*iterator));

	return TVResult<TDictionary<CString> >(info);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::internalSet(const TDictionary<CString>& info)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TIteratorS<CDictionary::Item> iterator = info.getIterator(); iterator.hasValue(); iterator.advance())
		// Set
		mInternals->mDatabaseManager.internalSet(iterator->mKey, OV<CString>(*info[iterator->mKey]));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLite::batch(BatchProc batchProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	I<MDSBatch>	batch(new MDSBatch());

	// Store
	mInternals->mBatchByThreadRef.set(CThread::getCurrentRefAsString(), batch);

	// Call proc
	TVResult<EMDSBatchResult>	batchResult = batchProc(userData);
	ReturnErrorIfResultError(batchResult);

	// Check result
	if (*batchResult == kMDSBatchResultCommit) {
		// Batch changes
		Internals::BatchInfo	batchInfo(*mInternals, *batch);
		mInternals->mDatabaseManager.batch((CMDSSQLiteDatabaseManager::BatchProc) Internals::batch, &batchInfo);
	}

	// Remove
	mInternals->mBatchByThreadRef.remove(CThread::getCurrentRefAsString());

	return OV<SError>();
}

// MARK: CMDSDocumentStorageServer methods

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>
				CMDSSQLite::associationGetDocumentRevisionInfosFrom(
		const CString& name, const CString& fromDocumentID, UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return TVResult<DocumentRevisionInfosWithTotalCount>(getUnknownAssociationError(name));

	// Get count
	OV<UInt32>	totalCount =
						mInternals->mDatabaseManager.associationGetCountFrom(name, fromDocumentID,
								(*association)->getFromDocumentType());
	if (!totalCount.hasValue())
		return TVResult<DocumentRevisionInfosWithTotalCount>(getUnknownDocumentIDError(fromDocumentID));

	// Collect CMDSDocument RevisionInfos
	TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
	OV<SError>							error =
												mInternals->mDatabaseManager.associationIterateDocumentInfosFrom(name,
														fromDocumentID, (*association)->getFromDocumentType(),
														(*association)->getToDocumentType(), startIndex, count,
														DMDocumentInfo::ProcInfo(
																(DMDocumentInfo::ProcInfo::Proc)
																		Internals::
																				addDocumentInfoToDocumentRevisionInfoArray,
																&documentRevisionInfos));
	ReturnValueIfError(error, TVResult<DocumentRevisionInfosWithTotalCount>(*error));

	return TVResult<DocumentRevisionInfosWithTotalCount>(
			DocumentRevisionInfosWithTotalCount(*totalCount, documentRevisionInfos));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>
				CMDSSQLite::associationGetDocumentRevisionInfosTo(
		const CString& name, const CString& toDocumentID, UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return TVResult<DocumentRevisionInfosWithTotalCount>(getUnknownAssociationError(name));

	// Get count
	OV<UInt32>	totalCount =
						mInternals->mDatabaseManager.associationGetCountTo(name, toDocumentID,
								(*association)->getToDocumentType());
	if (!totalCount.hasValue())
		return TVResult<DocumentRevisionInfosWithTotalCount>(getUnknownDocumentIDError(toDocumentID));

	// Collect CMDSDocument RevisionInfos
	TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
	OV<SError>							error =
												mInternals->mDatabaseManager.associationIterateDocumentInfosTo(name,
														toDocumentID, (*association)->getToDocumentType(),
														(*association)->getFromDocumentType(), startIndex, count,
														DMDocumentInfo::ProcInfo(
																(DMDocumentInfo::ProcInfo::Proc)
																		Internals::
																				addDocumentInfoToDocumentRevisionInfoArray,
																&documentRevisionInfos));
	ReturnValueIfError(error, TVResult<DocumentRevisionInfosWithTotalCount>(*error));

	return TVResult<DocumentRevisionInfosWithTotalCount>(
			DocumentRevisionInfosWithTotalCount(*totalCount, documentRevisionInfos));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>
				CMDSSQLite::associationGetDocumentFullInfosFrom(
		const CString& name, const CString& fromDocumentID, UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return TVResult<DocumentFullInfosWithTotalCount>(getUnknownAssociationError(name));

	// Get count
	OV<UInt32>	totalCount =
						mInternals->mDatabaseManager.associationGetCountFrom(name, fromDocumentID,
								(*association)->getFromDocumentType());
	if (!totalCount.hasValue())
		return TVResult<DocumentFullInfosWithTotalCount>(getUnknownDocumentIDError(fromDocumentID));

	// Collect CMDSDocument FullInfos
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	OV<SError>						error =
											mInternals->associationIterateFrom(*association, fromDocumentID, startIndex,
													count,
													(CMDSSQLiteDocumentBacking::KeyProc)
															Internals::addDocumentInfoToDocumentFullInfoArray,
													&documentFullInfos);
	ReturnValueIfError(error, TVResult<DocumentFullInfosWithTotalCount>(*error));

	return TVResult<DocumentFullInfosWithTotalCount>(DocumentFullInfosWithTotalCount(*totalCount, documentFullInfos));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount> CMDSSQLite::associationGetDocumentFullInfosTo(
		const CString& name, const CString& toDocumentID, UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<CMDSAssociation> >	association = mInternals->associationGet(name);
	if (!association.hasValue())
		return TVResult<DocumentFullInfosWithTotalCount>(getUnknownAssociationError(name));

	// Get count
	OV<UInt32>	totalCount =
						mInternals->mDatabaseManager.associationGetCountTo(name, toDocumentID,
								(*association)->getToDocumentType());
	if (!totalCount.hasValue())
		return TVResult<DocumentFullInfosWithTotalCount>(getUnknownDocumentIDError(toDocumentID));

	// Collect CMDSDocument FullInfos
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	OV<SError>						error =
											mInternals->associationIterateTo(*association, toDocumentID, startIndex,
													count,
													(CMDSSQLiteDocumentBacking::KeyProc)
															Internals::addDocumentInfoToDocumentFullInfoArray,
													&documentFullInfos);
	ReturnValueIfError(error, TVResult<DocumentFullInfosWithTotalCount>(*error));

	return TVResult<DocumentFullInfosWithTotalCount>(DocumentFullInfosWithTotalCount(*totalCount, documentFullInfos));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::RevisionInfo> > CMDSSQLite::collectionGetDocumentRevisionInfos(const CString& name,
		UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	OV<I<MDSCollection> >	collection = mInternals->collectionGet(name);

	// Collect CMDSDocument RevisionInfos
	TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
	mInternals->mDatabaseManager.collectionIterateDocumentInfos(name, (*collection)->getDocumentType(), startIndex,
			count,
			DMDocumentInfo::ProcInfo(
					(DMDocumentInfo::ProcInfo::Proc) Internals::addDocumentInfoToDocumentRevisionInfoArray,
					&documentRevisionInfos));

	return TVResult<TArray<CMDSDocument::RevisionInfo> >(documentRevisionInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::FullInfo> > CMDSSQLite::collectionGetDocumentFullInfos(const CString& name,
		UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	OV<I<MDSCollection> >	collection = mInternals->collectionGet(name);

	// Collect CMDSDocument FullInfos
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	mInternals->collectionIterate(name, (*collection)->getDocumentType(), startIndex, count,
			(CMDSSQLiteDocumentBacking::KeyProc) Internals::addDocumentInfoToDocumentFullInfoArray, &documentFullInfos);

	return TVResult<TArray<CMDSDocument::FullInfo> >(documentFullInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::RevisionInfo> > CMDSSQLite::documentRevisionInfos(const CString& documentType,
		const TArray<CString>& documentIDs) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<TArray<CMDSDocument::RevisionInfo> >(getUnknownDocumentTypeError(documentType));

	// Iterate
	TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
	mInternals->mDatabaseManager.documentInfoIterate(documentType, documentIDs,
			DMDocumentInfo::ProcInfo(
					(DMDocumentInfo::ProcInfo::Proc) Internals::addDocumentInfoToDocumentRevisionInfoArray,
					&documentRevisionInfos));

	return TVResult<TArray<CMDSDocument::RevisionInfo> >(documentRevisionInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::RevisionInfo> > CMDSSQLite::documentRevisionInfos(const CString& documentType,
		UInt32 sinceRevision, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<TArray<CMDSDocument::RevisionInfo> >(getUnknownDocumentTypeError(documentType));

	// Iterate
	TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
	mInternals->mDatabaseManager.documentInfoIterate(documentType, sinceRevision, count, false,
			DMDocumentInfo::ProcInfo(
					(DMDocumentInfo::ProcInfo::Proc) Internals::addDocumentInfoToDocumentRevisionInfoArray,
					&documentRevisionInfos));

	return TVResult<TArray<CMDSDocument::RevisionInfo> >(documentRevisionInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::FullInfo> > CMDSSQLite::documentFullInfos(const CString& documentType,
		const TArray<CString>& documentIDs) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<TArray<CMDSDocument::FullInfo> >(getUnknownDocumentTypeError(documentType));

	// Iterate initial document IDs
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	TNArray<CString>				documentIDsToCache;
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check what we have currently
		OR<I<CMDSSQLiteDocumentBacking> >	documentBacking =
													mInternals->mDocumentBackingByDocumentID.getDocumentBacking(
															*iterator);
		if (documentBacking.hasReference())
			// Have Document Backing in cache
			documentFullInfos += (*documentBacking)->getDocumentFullInfo();
		else
			// Will need to retrieve from database
			documentIDsToCache += (*iterator);
	}

	// Iterate documentIDs not found in cache
	Internals::DocumentBackingDocumentIDsIterateInfo	documentBackingDocumentIDsIterateInfo(documentFullInfos,
																documentIDsToCache);
	mInternals->documentBackingsIterate(documentType, documentIDsToCache,
			(CMDSSQLiteDocumentBacking::KeyProc) Internals::processDocumentBackingForDocumentIDs,
			&documentBackingDocumentIDsIterateInfo);

	// Check if have any that we didn't find
	if (!documentIDsToCache.isEmpty())
		return TVResult<TArray<CMDSDocument::FullInfo> >(getUnknownDocumentIDError(documentIDsToCache[0]));

	return TVResult<TArray<CMDSDocument::FullInfo> >(documentFullInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::FullInfo> > CMDSSQLite::documentFullInfos(const CString& documentType,
		UInt32 sinceRevision, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<TArray<CMDSDocument::FullInfo> >(getUnknownDocumentTypeError(documentType));

	// Iterate document backings
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	mInternals->documentBackingsIterate(documentType, sinceRevision, count, false,
			(CMDSSQLiteDocumentBacking::KeyProc) Internals::addDocumentInfoToDocumentFullInfoArray, &documentFullInfos);

	return TVResult<TArray<CMDSDocument::FullInfo> >(documentFullInfos);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt64> CMDSSQLite::documentIntegerValue(const CString& documentType, const I<CMDSDocument>& document,
		const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<MDSBatch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<MDSBatchDocumentInfo>	batchDocumentInfo =
												batch.hasReference() ?
														(*batch)->documentInfoGet(document->getID()) :
														OR<MDSBatchDocumentInfo>();

	// Check for batch
	OV<SValue>	value;
	if (batchDocumentInfo.hasReference())
		// In batch
		value = batchDocumentInfo->getValue(property);
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(document->getID()))
		// Being created
		value = mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID[document->getID()]->getValue(property);
	else
		// "Idle"
		value = (*mInternals->documentBackingGet(documentType, document->getID()))->getValue(property);

	return (value.hasValue() && value->canCoerceToType(SValue::kTypeSInt64)) ?
			OV<SInt64>(value->getSInt64()) : OV<SInt64>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<CString> CMDSSQLite::documentStringValue(const CString& documentType, const I<CMDSDocument>& document,
		const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<MDSBatch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<MDSBatchDocumentInfo>	batchDocumentInfo =
												batch.hasReference() ?
														(*batch)->documentInfoGet(document->getID()) :
														OR<MDSBatchDocumentInfo>();

	// Check for batch
	OV<SValue>	value;
	if (batchDocumentInfo.hasReference())
		// In batch
		value = batchDocumentInfo->getValue(property);
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(document->getID()))
		// Being created
		value = mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID[document->getID()]->getValue(property);
	else
		// "Idle"
		value = (*mInternals->documentBackingGet(documentType, document->getID()))->getValue(property);

	return (value.hasValue() && (value->getType() == SValue::kTypeString)) ?
			OV<CString>(value->getString()) : OV<CString>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::FullInfo> > CMDSSQLite::documentUpdate(const CString& documentType,
		const TArray<CMDSDocument::UpdateInfo>& documentUpdateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mDatabaseManager.documentTypeIsKnown(documentType))
		return TVResult<TArray<CMDSDocument::FullInfo> >(getUnknownDocumentTypeError(documentType));

	// Batch changes
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	Internals::DocumentUpdateInfo	documentUpdateInfo(*mInternals, documentType, documentUpdateInfos,
											documentFullInfos);
	mInternals->mDatabaseManager.batch((CMDSSQLiteDatabaseManager::BatchProc) Internals::documentUpdate,
			&documentUpdateInfo);

	return TVResult<TArray<CMDSDocument::FullInfo> >(documentFullInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<CMDSDocument::RevisionInfo> > CMDSSQLite::indexGetDocumentRevisionInfos(const CString& name,
		const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<MDSIndex> >	index = mInternals->indexGet(name);
	if (!index.hasValue())
		return TVResult<TDictionary<CMDSDocument::RevisionInfo> >(getUnknownIndexError(name));

	// Compose CMDSDocument RevisionInfo map
	TNDictionary<CMDSDocument::RevisionInfo>	documentRevisionInfoByKey;
	mInternals->mDatabaseManager.indexIterateDocumentInfos(name, (*index)->getDocumentType(), keys,
			DMDocumentInfo::KeyProcInfo(
					(DMDocumentInfo::KeyProcInfo::Proc) Internals::addDocumentInfoToDocumentRevisionInfoDictionary,
					&documentRevisionInfoByKey));

	return TVResult<TDictionary<CMDSDocument::RevisionInfo> >(documentRevisionInfoByKey);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<CMDSDocument::FullInfo> > CMDSSQLite::indexGetDocumentFullInfos(const CString& name,
		const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OV<I<MDSIndex> >	index = mInternals->indexGet(name);
	if (!index.hasValue())
		return TVResult<TDictionary<CMDSDocument::FullInfo> >(getUnknownIndexError(name));

	// Compose CMDSDocument FullInfo map
	TNDictionary<CMDSDocument::FullInfo>	documentFullInfoByKey;
	mInternals->indexIterate(name, (*index)->getDocumentType(), keys,
			(CMDSSQLiteDocumentBacking::KeyProc) Internals::addDocumentInfoToDocumentFullInfoDictionary,
			&documentFullInfoByKey);

	return TVResult<TDictionary<CMDSDocument::FullInfo> >(documentFullInfoByKey);
}
