//----------------------------------------------------------------------------------------------------------------------
//	CMDSEphemeral.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSEphemeral.h"

#include "CThread.h"
#include "CUUID.h"
#include "SError.h"
#include "TLockingDictionary.h"
#include "TMDSBatch.h"
#include "TMDSCache.h"
#include "TMDSCollection.h"
#include "TMDSIndex.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Types

typedef	TMDSCache<CString, TNDictionary<CDictionary> >	MDSCache;
typedef	TNDictionary<CDictionary>						MDSCacheValueMap;

typedef	TMDSCollection<CString, TNArray<CString> >		MDSCollection;

typedef	TNDictionary<CMDSDocument::AttachmentInfo>		MDSDocumentAttachmentInfoByID;

typedef	TMDSIndex<CString>								MDSIndex;

typedef	TMDSUpdateInfo<CString>							MDSUpdateInfo;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSEphemeral::Internals
class CMDSEphemeral::Internals {
	// AttachmentContentInfo
	public:
		struct AttachmentContentInfo {
			// Methods
			public:
														// Lifecycle methods
														AttachmentContentInfo(
																const CMDSDocument::AttachmentInfo&
																		documentAttachmentInfo,
																const CData& content) :
															mDocumentAttachmentInfo(documentAttachmentInfo),
																	mContent(content)
															{}
														AttachmentContentInfo(const AttachmentContentInfo& other) :
															mDocumentAttachmentInfo(other.mDocumentAttachmentInfo),
																	mContent(other.mContent)
															{}

														// Instance methods
				const	CMDSDocument::AttachmentInfo&	getDocumentAttachmentInfo() const
															{ return mDocumentAttachmentInfo; }
				const	CData&							getContent() const
															{ return mContent; }
			// Properties
			private:
				CMDSDocument::AttachmentInfo	mDocumentAttachmentInfo;
				CData							mContent;
		};

	// DocumentBacking
	public:
		class DocumentBacking {
			// Methods
			public:

													// Lifecycle methods
													DocumentBacking(const CString& documentID, UInt32 revision,
															UniversalTime creationUniversalTime,
															UniversalTime modificationUniversalTime,
															const CDictionary& propertyMap) :
														mDocumentID(documentID), mRevision(revision),
																mCreationUniversalTime(creationUniversalTime),
																mModificationUniversalTime(modificationUniversalTime),
																mPropertyMap(propertyMap)
														{}

													// Instance methods
		const	CString&							getDocumentID() const
														{ return mDocumentID; }
				UniversalTime						getCreationUniversalTime() const
														{ return mCreationUniversalTime; }
				UniversalTime						getModificationUniversalTime() const
														{ return mModificationUniversalTime; }

				UInt32								getRevision() const
														{ return mRevision; }
				bool								isActive() const
														{ return mActive; }
				void								setActive(bool active)
														{ mActive = active; }
				CDictionary&						getPropertyMap()
														{ return mPropertyMap; }
				CMDSDocument::AttachmentInfoByID	getDocumentAttachmentInfoByID() const
														{
															// Setup
															TNDictionary<CMDSDocument::AttachmentInfo>
																	documentAttachmentInfoByID;
															TSet<CString>
																	keys = mAttachmentContentInfoByAttachmentID
																			.getKeys();
															for (TIteratorS<CString> iterator = keys.getIterator();
																	iterator.hasValue(); iterator.advance())
																// Copy
																documentAttachmentInfoByID.set(*iterator,
																		mAttachmentContentInfoByAttachmentID[
																						*iterator]->
																				getDocumentAttachmentInfo());

															return documentAttachmentInfoByID;
														}

				CMDSDocument::RevisionInfo			getDocumentRevisionInfo() const
														{ return CMDSDocument::RevisionInfo(mDocumentID, mRevision); }
				CMDSDocument::FullInfo				getDocumentFullInfo() const
														{
															// Setup
															MDSDocumentAttachmentInfoByID	documentAttachmentInfoByID;
															TSet<CString>					attachmentIDs =
																									mAttachmentContentInfoByAttachmentID
																											.getKeys();
															for (TIteratorS<CString> iterator =
																			attachmentIDs.getIterator();
																	iterator.hasValue(); iterator.advance())
																// Update
																documentAttachmentInfoByID.set(*iterator,
																		mAttachmentContentInfoByAttachmentID[
																						*iterator]->
																				getDocumentAttachmentInfo());

															return CMDSDocument::FullInfo(mDocumentID, mRevision,
																	mActive, mCreationUniversalTime,
																	mModificationUniversalTime, mPropertyMap,
																	documentAttachmentInfoByID);
														}

				void								update(UInt32 revision, const OV<CDictionary>& updatedPropertyMap,
															const OV<TSet<CString> >& removedProperties)
														{
															// Update
															mRevision = revision;
															mModificationUniversalTime = SUniversalTime::getCurrent();
															if (updatedPropertyMap.hasValue())
																// Update property map
																mPropertyMap += *updatedPropertyMap;
															if (removedProperties.hasValue())
																// Update property map
																mPropertyMap.remove(*removedProperties);
														}
				CMDSDocument::AttachmentInfo		attachmentAdd(const CString& attachmentID, UInt32 documentRevision,
															const CDictionary& attachmentInfo,
															const CData& attachmentContent)
														{
															// Setup
															CMDSDocument::AttachmentInfo	documentAttachmentInfo(
																									attachmentID, 1,
																									attachmentInfo);

															// Add
															mAttachmentContentInfoByAttachmentID.set(attachmentID,
																	AttachmentContentInfo(documentAttachmentInfo,
																			attachmentContent));

															// Update
															mRevision = documentRevision;
															mModificationUniversalTime = SUniversalTime::getCurrent();

															return documentAttachmentInfo;
														}
				OR<AttachmentContentInfo>			getAttachmentContentInfo(const CString& attachmentID)
														{ return mAttachmentContentInfoByAttachmentID.get(attachmentID); }
				UInt32								attachmentUpdate(UInt32 revision, const CString& attachmentID,
															const CDictionary& updatedInfo, const CData& updatedContent)
														{
															// Setup
															UInt32	attachmentRevision =
																			mAttachmentContentInfoByAttachmentID.get(
																					attachmentID)->
																							getDocumentAttachmentInfo()
																									.getRevision() + 1;

															// Update
															mAttachmentContentInfoByAttachmentID.set(attachmentID,
																	AttachmentContentInfo(
																			CMDSDocument::AttachmentInfo(attachmentID,
																					attachmentRevision, updatedInfo),
																			updatedContent));

															// Update
															mRevision = revision;
															mModificationUniversalTime = SUniversalTime::getCurrent();

															return revision;
														}
				void								attachmentRemove(UInt32 revision, const CString& attachmentID)
														{
															// Remove
															mAttachmentContentInfoByAttachmentID.remove(attachmentID);

															// Update
															mRevision = revision;
															mModificationUniversalTime = SUniversalTime::getCurrent();
														}

													// Class methods
		static	bool								compareRevision(const I<DocumentBacking>& documentBacking1,
															const I<DocumentBacking>& documentBacking2, void* userData)
														{ return documentBacking1->getRevision() <
																documentBacking2->getRevision(); }

			// Properties
			private:
				CString								mDocumentID;
				UniversalTime						mCreationUniversalTime;

				UInt32								mRevision;
				bool								mActive;
				UniversalTime						mModificationUniversalTime;
				CDictionary							mPropertyMap;
				TNDictionary<AttachmentContentInfo>	mAttachmentContentInfoByAttachmentID;
		};

	// More Types
	public:
		typedef	TMDSBatch<I<DocumentBacking> >				Batch;
		typedef	Batch::DocumentInfo							BatchDocumentInfo;
		typedef	TNDictionary<BatchDocumentInfo>				BatchDocumentInfoByDocumentID;
		typedef	TDictionary<BatchDocumentInfoByDocumentID>	BatchDocumentInfoByDocumentIDByDocumentType;
		typedef	TArray<I<DocumentBacking> >					DocumentBackings;
		typedef	TVResult<DocumentBackings>					DocumentBackingsResult;

	// Methods
	public:
												// Lifecycle methods
												Internals(CMDSDocumentStorage& documentStorage) :
													mDocumentStorage(documentStorage)
													{}

												// Instance methods
				TArray<CMDSAssociation::Item>	associationGetItems(const CString& name) const
													{
														// Get association items
														mDocumentMapsLock.lockForReading();
														TNArray<CMDSAssociation::Item>	associationItems;
														if (mAssociationItemsByName.contains(name))
															associationItems = *mAssociationItemsByName.get(name);
														mDocumentMapsLock.unlockForReading();

														// Check for batch
														OR<I<Batch> >	batch =
																				mBatchByThreadRef[
																						CThread::
																								getCurrentRefAsString()];
														if (batch.hasReference())
															// Apply batch changes
															associationItems =
																	(*batch)->associationItemsApplyingChanges(name,
																			associationItems);

														return associationItems;
													}
				void							cacheUpdate(const I<MDSCache>& cache,
														const TArray<MDSUpdateInfo>& updateInfos)
													{
														// Update Cache
																MDSCache::UpdateResults			cacheUpdateResults =
																										cache->update(
																												updateInfos);
														const	OV<TNDictionary<CDictionary> >&	valueInfoByID =
																										cacheUpdateResults
																												.getValueInfoByID();

														// Check if have updates
														if (valueInfoByID.hasValue())
															// Update storage
															mCacheValuesByName.update(cache->getName(),
																	(TNLockingDictionary<MDSCacheValueMap>::UpdateProc)
																			updateCacheValueMapWithUpdateInfosByID,
																	(void*) &(*valueInfoByID));
													}
				void							collectionUpdate(const I<MDSCollection>& collection,
														const TArray<MDSUpdateInfo>& updateInfos)
													{
														// Update Collection
														MDSCollection::UpdateResults	collectionUpdateResults =
																								collection->update(
																										updateInfos);

														// Check if have updates
														if (collectionUpdateResults.getIncludedIDs().hasValue() ||
																collectionUpdateResults.getNotIncludedIDs().hasValue())
															// Update storage
															mCollectionValuesByName.update(collection->getName(),
																	(TNLockingDictionary<TNArray<CString> >::UpdateProc)
																			collectionUpdateFromUpdateResults,
																	&collectionUpdateResults);
													}
		static	OV<TNArray<CString> >			collectionUpdateFromUpdateResults(
														const OR<TNArray<CString> >& currentValue,
														MDSCollection::UpdateResults* collectionUpdateResults)
													{
														// Setup
														TNSet<CString>	notIncludedIDs(
																				collectionUpdateResults->
																								getNotIncludedIDs()
																								.hasValue() ?
																						*collectionUpdateResults->
																								getNotIncludedIDs() :
																						TNArray<CString>());

														// Compose updated values
														TNArray<CString>	updatedValues;
														if (currentValue.hasReference())
															// Start with current values, and then filtered
															updatedValues =
																	currentValue->filtered(
																			(TNArray<CString>::IsMatchProc)
																					TSet<CString>::doesNotContainItem,
																			&notIncludedIDs);

														if (collectionUpdateResults->getIncludedIDs().hasValue())
															// Add included IDs
															updatedValues += *collectionUpdateResults->getIncludedIDs();

														return !updatedValues.isEmpty() ?
																OV<TNArray<CString> >(updatedValues) :
																OV<TNArray<CString> >();
													}
				DocumentBackingsResult			documentBackingsGet(const CString& documentType, UInt32 sinceRevision,
														const OV<UInt32>& count = OV<UInt32>(), bool activeOnly = false)
													{
														// Setup
														TNArray<I<DocumentBacking> >	documentBackings;

														// Perform under lock
														mDocumentMapsLock.lockForReading();
														bool	isKnownDocumentType =
																		mDocumentIDsByDocumentType.contains(
																				documentType);
														if (isKnownDocumentType) {
															// Collect DocumentBackings
															TSet<CString>&	documentIDs =
																					*mDocumentIDsByDocumentType.get(
																							documentType);
															for (TIteratorS<CString> iterator =
																			documentIDs.getIterator();
																	iterator.hasValue(); iterator.advance()) {
																// Get DocumentBacking
																I<DocumentBacking>&	documentBacking =
																							*mDocumentBackingByDocumentID
																									.get(*iterator);

																// Check
																if ((documentBacking->getRevision() > sinceRevision) &&
																		(!activeOnly || documentBacking->isActive()))
																	// Passes
																	documentBackings += documentBacking;
															}
														}
														mDocumentMapsLock.unlockForReading();

														if (!isKnownDocumentType)
															// Document type not found
															return TVResult<DocumentBackings>(
																	mDocumentStorage.getUnknownDocumentTypeError(
																			documentType));
														else if (!count.hasValue())
															// No count
															return TVResult<DocumentBackings>(documentBackings);
														else {
															// Sort by revision
															documentBackings.sort(
																	DocumentBacking::compareRevision, nil);

															return TVResult<DocumentBackings>(
																	documentBackings.popFirst(*count));
														}
													}
				DocumentBackingsResult			documentBackingsGet(const CString& documentType,
														const TArray<CString>& documentIDs)
													{
														// Validate
														mDocumentMapsLock.lockForReading();
														bool	isKnownDocumentType =
																		mDocumentIDsByDocumentType.contains(
																				documentType);
														mDocumentMapsLock.unlockForReading();

														if (!isKnownDocumentType)
															// Unknown document type
															return DocumentBackingsResult(
																	mDocumentStorage.getUnknownDocumentTypeError(
																			documentType));

														// Retrieve document backings
														TNArray<I<DocumentBacking> >	documentBackings;
														OV<SError>						error;
														mDocumentMapsLock.lockForReading();
														for (TIteratorD<CString> iterator = documentIDs.getIterator();
																iterator.hasValue(); iterator.advance()) {
															// Validate
															const OR<I<DocumentBacking> >	documentBacking =
																									mDocumentBackingByDocumentID.get(*iterator);
															if (!documentBacking.hasReference()) {
																// Document ID not found
																error.setValue(
																		mDocumentStorage.getUnknownDocumentIDError(
																				*iterator));
																break;
															}

															// Add to array
															documentBackings += *documentBacking;
														}
														mDocumentMapsLock.unlockForReading();

														return !error.hasValue() ?
																DocumentBackingsResult(documentBackings) :
																DocumentBackingsResult(*error);
													}
				void							indexUpdate(const I<MDSIndex>& index,
														const TArray<MDSUpdateInfo>& updateInfos)
													{
														// Update Index
														MDSIndex::UpdateResults	indexUpdateResults =
																						index->update(updateInfos);

														// Check if have updates
														if (indexUpdateResults.getKeysInfos().hasValue())
															// Update storage
															mIndexValuesByName.update(index->getName(),
																	(TNLockingDictionary<TDictionary<CString> >::
																					UpdateProc)
																			indexUpdateFromUpdateResults,
																	&indexUpdateResults);
													}
		static	OV<TNDictionary<CString> >		indexUpdateFromUpdateResults(
														const OR<TNDictionary<CString> >& currentValue,
														MDSIndex::UpdateResults* indexUpdateResults)
													{
														// Setup
														TNArray<CString>		documentIDsArray(
																						*indexUpdateResults->
																								getKeysInfos(),
																						MDSIndex::KeysInfo::getID);
														TNSet<CString>			documentIDs(documentIDsArray);

														TNDictionary<CString>	updatedValueInfo =
																						currentValue.hasReference() ?
																								*currentValue :
																								TNDictionary<CString>();

														// Filter out document IDs included in update
														TSet<CString>	keys = updatedValueInfo.getKeys();
														for (TIteratorS<CString> iterator = keys.getIterator();
																iterator.hasValue(); iterator.advance()) {
															// Check if have new value(s) for documentID for this key
															if (documentIDs.contains(*updatedValueInfo.get(*iterator)))
																// Yes, remove
																updatedValueInfo.remove(*iterator);
														}

														// Add/Update keys => document IDs
														for (TIteratorD<MDSIndex::KeysInfo> keysInfoIterator =
																		indexUpdateResults->getKeysInfos()->
																				getIterator();
																keysInfoIterator.hasValue(); keysInfoIterator.advance())
															// Iterate keys
															for (TIteratorD<CString> keyIterator =
																			keysInfoIterator->getKeys().getIterator();
																	keyIterator.hasValue(); keyIterator.advance())
																// Add key => document ID
																updatedValueInfo.set(*keyIterator,
																		keysInfoIterator->getID());

														return !updatedValueInfo.isEmpty() ?
																OV<TNDictionary<CString> >(updatedValueInfo) :
																OV<TNDictionary<CString> >();
													}

				void							process(const CString& documentID,
														const BatchDocumentInfo& batchDocumentInfo,
														DocumentBacking& documentBacking,
														const TSet<CString>& changedProperties,
														const CMDSDocument::Info& documentInfo,
														TNArray<MDSUpdateInfo>& updateInfos,
														const CMDSDocumentStorage::DocumentChangedInfos&
																documentChangedInfos,
														CMDSDocument::ChangeKind documentChangeKind)
													{
														// Process attachments
														for (TIteratorS<CString> iterator =
																		batchDocumentInfo.getRemovedAttachmentIDs()
																				.getIterator();
																iterator.hasValue(); iterator.advance())
															// Remove attachment
															documentBacking.attachmentRemove(
																	documentBacking.getRevision(), *iterator);

														const	TDictionary<Batch::AddAttachmentInfo>&
																		addAttachmentInfosByID =
																				batchDocumentInfo
																						.getAddAttachmentInfosByID();
																TSet<CString>
																		attachmentIDs =
																				addAttachmentInfosByID.getKeys();
														for (TIteratorS<CString> iterator = attachmentIDs.getIterator();
																iterator.hasValue(); iterator.advance()) {
															// Add attachment
															const	Batch::AddAttachmentInfo&	batchAddAttachmentInfo =
																										*addAttachmentInfosByID[*iterator];
															documentBacking.attachmentAdd(
																	batchAddAttachmentInfo.getID(),
																	documentBacking.getRevision(),
																	batchAddAttachmentInfo.getInfo(),
																	batchAddAttachmentInfo.getContent());
														}

														const	TDictionary<Batch::UpdateAttachmentInfo>&
																		updateAttachmentInfosByID =
																				batchDocumentInfo
																						.getUpdateAttachmentInfosByID();
														attachmentIDs = updateAttachmentInfosByID.getKeys();
														for (TIteratorS<CString> iterator = attachmentIDs.getIterator();
																iterator.hasValue(); iterator.advance()) {
															// Update attachment
															const	Batch::UpdateAttachmentInfo&
																			batchUpdateAttachmentInfo =
																					*updateAttachmentInfosByID[
																							*iterator];
															documentBacking.attachmentUpdate(
																	documentBacking.getRevision(),
																	batchUpdateAttachmentInfo.getID(),
																	batchUpdateAttachmentInfo.getInfo(),
																	batchUpdateAttachmentInfo.getContent());
														}

														// Create document
														I<CMDSDocument>	document =
																				documentInfo.create(documentID,
																						mDocumentStorage);

														// Note update info
														updateInfos +=
																MDSUpdateInfo(document, documentBacking.getRevision(),
																		documentID, changedProperties);

														// Call document changed procs
														for (TIteratorD<CMDSDocument::ChangedInfo> iterator =
																		documentChangedInfos.getIterator();
																iterator.hasValue(); iterator.advance())
															// Call proc
															iterator->notify(document, documentChangeKind);
													}

				UInt32							nextRevision(const CString& documentType)
													{
														// Compose next revision
														mDocumentLastRevisionByDocumentTypeLock.lock();
														UInt32	nextRevision =
																		mDocumentLastRevisionByDocumentType
																				.getUInt32(documentType, 0) + 1;
														mDocumentLastRevisionByDocumentType.set(documentType,
																nextRevision);
														mDocumentLastRevisionByDocumentTypeLock.unlock();

														return nextRevision;
													}
				TArray<MDSUpdateInfo>			updateInfosGet(const CString& documentType,
														const CMDSDocument::Info& documentInfo, UInt32 sinceRevision)
													{
														// Setup
														DocumentBackingsResult	documentBackingsResult =
																						documentBackingsGet(
																								documentType,
																								sinceRevision);
														if (documentBackingsResult.hasError())
															// Error
															return TNArray<MDSUpdateInfo>();

														// Iterate results
														TNArray<MDSUpdateInfo>	updateInfos;
														for (TIteratorD<I<DocumentBacking> > iterator =
																		documentBackingsResult.getValue().getIterator();
																iterator.hasValue(); iterator.advance())
															// Add UpdateInfo
															updateInfos +=
																	MDSUpdateInfo(
																			documentInfo.create(
																					(*iterator)->getDocumentID(),
																					mDocumentStorage),
																			(*iterator)->getRevision(),
																			(*iterator)->getDocumentID());

														return updateInfos;
													}
				void							update(const CString& documentType,
														const TArray<MDSUpdateInfo>& updateInfos)
													{
														// Update caches
														const	OR<TNArray<I<MDSCache> > >	caches =
																									mCachesByDocumentType
																											.get(documentType);
														if (caches.hasReference())
															// Update
															for (TIteratorD<I<MDSCache> > iterator =
																			caches->getIterator();
																	iterator.hasValue(); iterator.advance())
																// Update
																cacheUpdate(*iterator, updateInfos);

														// Update collections
														const	OR<TNArray<I<MDSCollection> > > collections =
																										mCollectionsByDocumentType
																												.get(documentType);
														if (collections.hasReference())
															// Update
															for (TIteratorD<I<MDSCollection> > iterator =
																			collections->getIterator();
																	iterator.hasValue(); iterator.advance())
																// Update
																collectionUpdate(*iterator, updateInfos);

														// Update indexes
														const	OR<TNArray<I<MDSIndex> > > indexes =
																									mIndexesByDocumentType
																											.get(documentType);
														if (indexes.hasReference())
															// Update
															for (TIteratorD<I<MDSIndex> > iterator =
																			indexes->getIterator();
																	iterator.hasValue(); iterator.advance())
																// Update
																indexUpdate(*iterator, updateInfos);
													}
				void							noteRemoved(const TSet<CString>& documentIDs)
													{
														// Update caches
														const	TSet<CString>&	cacheNames =
																						mCacheValuesByName.getKeys();
														for (TIteratorS<CString> iterator = cacheNames.getIterator();
																iterator.hasValue(); iterator.advance())
															// Update storage
															mCacheValuesByName.update(*iterator,
																	(TNLockingDictionary<MDSCacheValueMap>::UpdateProc)
																			updateCacheValueMapWithRemovedDocumentIDs,
																	(void*) &documentIDs);

														// Update collections
														const	TSet<CString>&	collectionNames =
																						mCollectionValuesByName
																								.getKeys();
														for (TIteratorS<CString> iterator =
																		collectionNames.getIterator();
																iterator.hasValue(); iterator.advance())
															// Update storage
															mCollectionValuesByName.update(*iterator,
																	(TNLockingDictionary<TNArray<CString> >::UpdateProc)
																			updateCollectionValuesWithRemovedDocumentIDs,
																	(void*) &documentIDs);

														// Update indexes
														const	TSet<CString>	indexNames =
																						mIndexValuesByName.getKeys();
														for (TIteratorS<CString> iterator = indexNames.getIterator();
																iterator.hasValue(); iterator.advance())
															// Update storage
															mIndexValuesByName.update(*iterator,
																	(TNLockingDictionary<TDictionary<CString> >::
																					UpdateProc)
																			updateIndexValuesWithRemovedDocumentIDs,
																	(void*) &documentIDs);
													}

												// Class methods
		static	OV<MDSCacheValueMap>			updateCacheValueMapWithRemovedDocumentIDs(
														const OR<MDSCacheValueMap>& currentCacheValueMap,
														TSet<CString>* documentIDs)
													{
														// Filter document ids
														MDSCacheValueMap	filteredCacheValueMap =
																				MDSCacheValueMap(*currentCacheValueMap)
																						.filtered(
																								(MDSCacheValueMap::
																												KeyIsMatchProc)
																										TSet<CString>::
																												doesNotContainItem,
																								documentIDs);

														return (!filteredCacheValueMap.isEmpty()) ?
																OV<MDSCacheValueMap>(filteredCacheValueMap) :
																OV<MDSCacheValueMap>();
													}
		static	OV<MDSCacheValueMap>			updateCacheValueMapWithUpdateInfosByID(
														const OR<MDSCacheValueMap>& currentCacheValueMap,
														TDictionary<CDictionary>* infosByID)
													{
														// Setup
																MDSCacheValueMap	cacheValueMap =
																							currentCacheValueMap
																											.hasReference() ?
																									MDSCacheValueMap(
																											*currentCacheValueMap) :
																									MDSCacheValueMap();
														const	TSet<CString>&	keys = infosByID->getKeys();

														// Iterate keys
														for (TIteratorS<CString> iterator = keys.getIterator();
																iterator.hasValue(); iterator.advance())
															// Update
															cacheValueMap.set(*iterator, *(*infosByID)[*iterator]);

														return !cacheValueMap.isEmpty() ?
																OV<MDSCacheValueMap>(cacheValueMap) :
																OV<MDSCacheValueMap>();
													}

		static	OV<TNArray<CString> >			updateCollectionValuesWithRemovedDocumentIDs(
														const OR<TNArray<CString> >& currentDocumentIDs,
														TSet<CString>* documentIDs)
													{
														// Filter document ids
														TNArray<CString>	filteredDocumentIDs =
																					currentDocumentIDs->filtered(
																							(TNArray<CString>::
																											IsMatchProc)
																									TSet<CString>::
																											doesNotContainItem,
																							documentIDs);

														return (!filteredDocumentIDs.isEmpty()) ?
																OV<TNArray<CString> >(filteredDocumentIDs) :
																OV<TNArray<CString> >();
													}

		static	OV<TDictionary<CString> >		updateIndexValuesWithRemovedDocumentIDs(
														const OR<TDictionary<CString> >& currentIndexValues,
														TSet<CString>* documentIDs)
													{
														// Filter document ids
														TNDictionary<CString>	filteredDictionary =
																						TNDictionary<CString>(*currentIndexValues)
																								.filtered(
																										(TNDictionary<CString>::KeyIsMatchProc)
																												TSet<CString>::
																														doesNotContainItem,
																										documentIDs);

														return (!filteredDictionary.isEmpty()) ?
																OV<TDictionary<CString> >(filteredDictionary) :
																OV<TDictionary<CString> >();
													}

	// Properties
	public:
		CMDSDocumentStorage&							mDocumentStorage;

		TNLockingDictionary<I<CMDSAssociation> >		mAssociationByName;
		TNLockingArrayDictionary<CMDSAssociation::Item>	mAssociationItemsByName;

		TNLockingDictionary<I<Batch> >					mBatchByThreadRef;

		TNLockingDictionary<I<MDSCache> >				mCacheByName;
		TNLockingArrayDictionary<I<MDSCache> >			mCachesByDocumentType;
		TNLockingDictionary<MDSCacheValueMap>			mCacheValuesByName;

		TNLockingDictionary<I<MDSCollection> >			mCollectionByName;
		TNLockingArrayDictionary<I<MDSCollection> >		mCollectionsByDocumentType;
		TNLockingDictionary<TNArray<CString> >			mCollectionValuesByName;

		TNDictionary<I<DocumentBacking> >				mDocumentBackingByDocumentID;
		TNSetDictionary<CString>						mDocumentIDsByDocumentType;
		CReadPreferringLock								mDocumentMapsLock;
		CDictionary										mDocumentLastRevisionByDocumentType;
		CLock											mDocumentLastRevisionByDocumentTypeLock;
		TNLockingDictionary<CDictionary>				mDocumentsBeingCreatedPropertyMapByDocumentID;

		TNLockingDictionary<I<MDSIndex> >				mIndexByName;
		TNLockingArrayDictionary<I<MDSIndex> >			mIndexesByDocumentType;
		TNLockingDictionary<TDictionary<CString> >		mIndexValuesByName;

		TNLockingDictionary<CString>					mInfoValueByKey;
		TNLockingDictionary<CString>					mInternalValueByKey;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSEphemeral

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSEphemeral::CMDSEphemeral() : CMDSDocumentStorageServer()
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = new Internals(*this);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSEphemeral::~CMDSEphemeral()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: CMDSDocumentStorage methods

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::associationRegister(const CString& name, const CString& fromDocumentType,
		const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if have association already
	if (!mInternals->mAssociationByName.get(name).hasReference())
		// Create
		mInternals->mAssociationByName.set(name,
				I<CMDSAssociation>(new CMDSAssociation(name, fromDocumentType, toDocumentType)));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSAssociation::Item> > CMDSEphemeral::associationGet(const CString& name) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return TVResult<TArray<CMDSAssociation::Item> >(getUnknownAssociationError(name));

	return TVResult<TArray<CMDSAssociation::Item> >(mInternals->associationGetItems(name));
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::associationIterateFrom(const CString& name, const CString& fromDocumentID,
		const CString& toDocumentType, CMDSDocument::Proc proc, void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OR<I<CMDSAssociation> >	association = mInternals->mAssociationByName.get(name);
	if (!association.hasReference())
		return OV<SError>(getUnknownAssociationError(name));

	mInternals->mDocumentMapsLock.lockForReading();
	bool	found = mInternals->mDocumentBackingByDocumentID.contains(fromDocumentID);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!found)
		return OV<SError>(getUnknownDocumentIDError(fromDocumentID));

	if ((*association)->getToDocumentType() != toDocumentType)
		return OV<SError>(getInvalidDocumentTypeError(toDocumentType));

	// Get association items
	const	CMDSDocument::Info&				documentInfo = documentCreateInfo(toDocumentType);
			TArray<CMDSAssociation::Item>	associationItems = mInternals->associationGetItems(name);
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check for docmentID match
		if (iterator->getFromDocumentID() == fromDocumentID)
			// Match
			proc(documentInfo.create(iterator->getToDocumentID(), (CMDSDocumentStorage&) *this), procUserData);
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::associationIterateTo(const CString& name, const CString& fromDocumentType,
		const CString& toDocumentID, CMDSDocument::Proc proc, void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OR<I<CMDSAssociation> >	association = mInternals->mAssociationByName.get(name);
	if (!association.hasReference())
		return OV<SError>(getUnknownAssociationError(name));

	mInternals->mDocumentMapsLock.lockForReading();
	bool	found = mInternals->mDocumentBackingByDocumentID.contains(toDocumentID);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!found)
		return OV<SError>(getUnknownDocumentIDError(toDocumentID));

	if ((*association)->getFromDocumentType() != fromDocumentType)
		return OV<SError>(getInvalidDocumentTypeError(fromDocumentType));

	// Get association items
	const	CMDSDocument::Info&				documentInfo = documentCreateInfo(fromDocumentType);
			TArray<CMDSAssociation::Item>	associationItems = mInternals->associationGetItems(name);
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check for docmentID match
		if (iterator->getToDocumentID() == toDocumentID)
			// Match
			proc(documentInfo.create(iterator->getFromDocumentID(), (CMDSDocumentStorage&) *this), procUserData);
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<SValue> CMDSEphemeral::associationGetValues(const CString& name, CMDSAssociation::GetValueAction action,
		const TArray<CString>& fromDocumentIDs, const CString& cacheName, const TArray<CString>& cachedValueNames) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return TVResult<SValue>(getUnknownAssociationError(name));

	OV<SError>	error;
	mInternals->mDocumentMapsLock.lockForReading();
	for (TIteratorD<CString> iterator = fromDocumentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check if have document with this ID
		if (!mInternals->mDocumentBackingByDocumentID.contains(*iterator)) {
			// Not found
			error.setValue(getUnknownDocumentIDError(*iterator));
			break;
		}
	}
	mInternals->mDocumentMapsLock.unlockForReading();
	if (error.hasValue())
		return TVResult<SValue>(*error);

	OR<I<MDSCache> >	cache = mInternals->mCacheByName.get(cacheName);
	if (!cache.hasReference())
		return TVResult<SValue>(getUnknownCacheError(cacheName));

	for (TIteratorD<CString> iterator = cachedValueNames.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check if have info for this cachedValueName
		if (!(*cache)->hasValueInfo(*iterator))
			return TVResult<SValue>(getUnknownCacheValueName(*iterator));
	}

	// Setup
	TNSet<CString>					fromDocumentIDsUse(fromDocumentIDs);
	TArray<CMDSAssociation::Item>	associationItems = mInternals->associationGetItems(name);
	TDictionary<CDictionary>&		cacheValueInfos = *mInternals->mCacheValuesByName.get(cacheName);

	// Process association items
	switch (action) {
		case CMDSAssociation::kGetValueActionDetail: {
			// Detail
			TNArray<CDictionary>	results;
			for (TIteratorD<CMDSAssociation::Item> associationItemIterator = associationItems.getIterator();
					associationItemIterator.hasValue(); associationItemIterator.advance()) {
				// Check fromDocumentID
				if (fromDocumentIDsUse.contains(associationItemIterator->getFromDocumentID())) {
					// Setup
					CDictionary	result;
					result.set(CString(OSSTR("fromID")), associationItemIterator->getFromDocumentID());
					result.set(CString(OSSTR("toID")), associationItemIterator->getToDocumentID());

					// Iterate cachedValueNames
					CDictionary&	valueInfos = *cacheValueInfos.get(associationItemIterator->getToDocumentID());
					for (TIteratorD<CString> cacheValueNameIterator = cachedValueNames.getIterator();
							cacheValueNameIterator.hasValue(); cacheValueNameIterator.advance())
						// Update result
						result.set(*cacheValueNameIterator, valueInfos[*cacheValueNameIterator]);

					// Add result
					results += result;
				}
			}

			return SValue(results); }

		case CMDSAssociation::kGetValueActionSum: {
			// Sum
			CDictionary	results;
			UInt64		count = 0;
			for (TIteratorD<CMDSAssociation::Item> associationItemIterator = associationItems.getIterator();
					associationItemIterator.hasValue(); associationItemIterator.advance()) {
				// Check fromDocumentID
				if (fromDocumentIDsUse.contains(associationItemIterator->getFromDocumentID())) {
					// Included
					count++;

					// Get value and sum
					CDictionary&	valueInfos = *cacheValueInfos.get(associationItemIterator->getToDocumentID());

					// Iterate cachedValueNames
					for (TIteratorD<CString> cacheValueNameIterator = cachedValueNames.getIterator();
							cacheValueNameIterator.hasValue(); cacheValueNameIterator.advance())
						// Update results
						results.set(*cacheValueNameIterator,
								results.getSInt64(*cacheValueNameIterator) +
										valueInfos.getSInt64(*cacheValueNameIterator));
				}
			}
			results.set(CString(OSSTR("count")), count);

			return SValue(results); }

#if defined(TARGET_OS_WINDOWS)
		default:
			return TVResult<SValue>(SError::mUnimplemented);
#endif
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::associationUpdate(const CString& name, const TArray<CMDSAssociation::Update>& updates)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OR<I<CMDSAssociation> >	association = mInternals->mAssociationByName.get(name);
	if (!association.hasReference())
		return OV<SError>(getUnknownAssociationError(name));

	// Check if have updates
	if (updates.isEmpty())
		return OV<SError>();

	// Setup
	TNSet<CString>	updateFromDocumentIDs(updates,
							(TNSet<CString>::ArrayMapProc) CMDSAssociation::Update::getFromDocumentIDFromItem);
	TNSet<CString>	updateToDocumentIDs(updates,
							(TNSet<CString>::ArrayMapProc) CMDSAssociation::Update::getToDocumentIDFromItem);

	// Check for batch
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		mInternals->mDocumentMapsLock.lockForReading();
		TNSet<CString>	existingFromDocumentIDs =
								mInternals->mDocumentIDsByDocumentType.get((*association)->getFromDocumentType(),
										TNSet<CString>());
		mInternals->mDocumentMapsLock.unlockForReading();
		updateFromDocumentIDs -= existingFromDocumentIDs;
		updateFromDocumentIDs -= (*batch)->documentIDsGet((*association)->getFromDocumentType());
		if (!updateFromDocumentIDs.isEmpty())
			return OV<SError>(getUnknownDocumentIDError(updateFromDocumentIDs.getArray()[0]));

		mInternals->mDocumentMapsLock.lockForReading();
		TNSet<CString>	existingToDocumentIDs =
								mInternals->mDocumentIDsByDocumentType.get((*association)->getToDocumentType(),
										TNSet<CString>());
		mInternals->mDocumentMapsLock.unlockForReading();
		updateToDocumentIDs -= existingToDocumentIDs;
		updateToDocumentIDs -= (*batch)->documentIDsGet((*association)->getToDocumentType());
		if (!updateToDocumentIDs.isEmpty())
			return OV<SError>(getUnknownDocumentIDError(updateToDocumentIDs.getArray()[0]));

		// Update
		(*batch)->associationNoteUpdated(name, updates);
	} else {
		// Not in batch
		mInternals->mDocumentMapsLock.lockForReading();
		TNSet<CString>	existingFromDocumentIDs =
								mInternals->mDocumentIDsByDocumentType.get((*association)->getFromDocumentType(),
										TNSet<CString>());
		mInternals->mDocumentMapsLock.unlockForReading();
		updateFromDocumentIDs -= existingFromDocumentIDs;
		if (!updateFromDocumentIDs.isEmpty())
			return OV<SError>(getUnknownDocumentIDError(updateFromDocumentIDs.getArray()[0]));

		mInternals->mDocumentMapsLock.lockForReading();
		TNSet<CString>	existingToDocumentIDs =
								mInternals->mDocumentIDsByDocumentType.get((*association)->getToDocumentType(),
										TNSet<CString>());
		mInternals->mDocumentMapsLock.unlockForReading();
		updateToDocumentIDs -= existingToDocumentIDs;
		if (!updateToDocumentIDs.isEmpty())
			return OV<SError>(getUnknownDocumentIDError(updateToDocumentIDs.getArray()[0]));

		// Iterate updates
		for (TIteratorD<CMDSAssociation::Update> iterator = updates.getIterator(); iterator.hasValue();
				iterator.advance())
			// Check Add or Remove
			if (iterator->getAction() == CMDSAssociation::Update::kActionAdd)
				// Add
				mInternals->mAssociationItemsByName.add(name, iterator->getItem());
			else
				// Remove
				mInternals->mAssociationItemsByName.remove(name, iterator->getItem());
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::cacheRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, const TArray<CacheValueInfo>& cacheValueInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove current cache if found
	if (mInternals->mCacheByName.contains(name))
		// Remove
		mInternals->mCacheByName.remove(name);

	// Setup
	TNArray<SMDSCacheValueInfo>	_cacheValueInfos;
	for (TIteratorD<CacheValueInfo> iterator = cacheValueInfos.getIterator(); iterator.hasValue(); iterator.advance())
		// Add
		_cacheValueInfos += SMDSCacheValueInfo(iterator->getValueInfo(), documentValueInfo(iterator->getSelector()));

	// Create or re-create
	I<MDSCache>	cache(new MDSCache(name, documentType, relevantProperties, _cacheValueInfos, 0));

	// Add to maps
	mInternals->mCacheByName.set(name, cache);
	mInternals->mCachesByDocumentType.add(documentType, cache);

	// Bring up to date
	mInternals->cacheUpdate(cache, mInternals->updateInfosGet(documentType, documentCreateInfo(documentType), 0));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CDictionary> > CMDSEphemeral::cacheGetValues(const CString& name, const TArray<CString>& valueNames,
		const OV<TArray<CString> >& documentIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	OR<I<MDSCache> >	cache = mInternals->mCacheByName.get(name);
	if (!cache.hasReference())
		return TVResult<TArray<CDictionary> >(getUnknownCacheError(name));

	if (valueNames.isEmpty())
		return TVResult<TArray<CDictionary> >(getMissingValueNamesError());

	for (TIteratorD<CString> iterator = valueNames.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Ensure we have this value name
		if (!(*cache)->hasValueInfo(*iterator))
			return TVResult<TArray<CDictionary> >(getUnknownCacheValueName(*iterator));
	}

	// Setup
	TDictionary<CDictionary>	cacheValuesByDocumentID =
										mInternals->mCacheValuesByName.get((*cache)->getName(),
												TNDictionary<CDictionary>());

	// Check if have documentIDs
	TNArray<CDictionary>	infos;
	if (documentIDs.hasValue()) {
		// Iterate documentIDs
		for (TIteratorD<CString> documentIDIterator = documentIDs->getIterator(); documentIDIterator.hasValue();
				documentIDIterator.advance()) {
			// Get cached values
			const	OR<CDictionary>&	cacheValues = cacheValuesByDocumentID[*documentIDIterator];
			if (cacheValues.hasReference()) {
				// Have documentID
				CDictionary	info;
				info.set(CString(OSSTR("documentID")), *documentIDIterator);

				// Iterate valueNames
				for (TIteratorD<CString> valueNameIterator = valueNames.getIterator(); valueNameIterator.hasValue();
						valueNameIterator.advance())
					// Add value
					info.set(*valueNameIterator, (*cacheValues).getOValue(*valueNameIterator));

				// Add to array
				infos += info;
			} else
				// Don't have documentID
				return TVResult<TArray<CDictionary> >(getUnknownDocumentIDError(*documentIDIterator));
		}
	} else {
		// All documentIDs
		TSet<CString>	documentIDs_ = cacheValuesByDocumentID.getKeys();
		for (TIteratorS<CString> documentIDIterator = documentIDs_.getIterator(); documentIDIterator.hasValue();
				documentIDIterator.advance()) {
			// Get cached values
			const	OR<CDictionary>&	cacheValues = cacheValuesByDocumentID[*documentIDIterator];

			// Have documentID
			CDictionary	info;
			info.set(CString(OSSTR("documentID")), *documentIDIterator);

			// Iterate valueNames
			for (TIteratorD<CString> valueNameIterator = valueNames.getIterator(); valueNameIterator.hasValue();
					valueNameIterator.advance())
				// Add value
				info.set(*valueNameIterator, (*cacheValues).getOValue(*valueNameIterator));

			// Add to array
			infos += info;
		}
	}

	return TVResult<TArray<CDictionary> >(infos);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::collectionRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, bool isUpToDate, const CDictionary& isIncludedInfo,
		const CMDSDocument::IsIncludedPerformer& documentIsIncludedPerformer, bool checkRelevantProperties)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove current collection if found
	OR<I<MDSCollection> >	existingCollection = mInternals->mCollectionByName.get(name);
	if (existingCollection.hasReference())
		// Remove
		mInternals->mCollectionsByDocumentType.remove(documentType, *existingCollection);

	// Create or re-create collection
	UInt32	lastRevision;
	if (isUpToDate) {
		// Get current last revision
		mInternals->mDocumentLastRevisionByDocumentTypeLock.lock();
		lastRevision = mInternals->mDocumentLastRevisionByDocumentType.getUInt32(documentType, 0);
		mInternals->mDocumentLastRevisionByDocumentTypeLock.unlock();
	} else {
		// Start fresh
		mInternals->mCollectionValuesByName.remove(name);
		lastRevision = 0;
	}

	I<MDSCollection>	collection(
								new MDSCollection(name, documentType, relevantProperties, documentIsIncludedPerformer,
										checkRelevantProperties, isIncludedInfo, lastRevision));

	// Add to maps
	mInternals->mCollectionByName.set(name, collection);
	mInternals->mCollectionsByDocumentType.add(documentType, collection);

	// Check if is up to date
	if (!isUpToDate)
		// Bring up to date
		mInternals->collectionUpdate(collection,
				mInternals->updateInfosGet(documentType, documentCreateInfo(documentType), 0));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<UInt32> CMDSEphemeral::collectionGetDocumentCount(const CString& name) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	const	OR<TNArray<CString> >	documentIDs = mInternals->mCollectionValuesByName.get(name);
	if (!documentIDs.hasReference())
		return TVResult<UInt32>(getUnknownCollectionError(name));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return TVResult<UInt32>(getIllegalInBatchError());

	return TVResult<UInt32>(documentIDs->getCount());
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::collectionIterate(const CString& name, const CString& documentType, CMDSDocument::Proc proc,
		void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	const	OR<TNArray<CString> >	documentIDs = mInternals->mCollectionValuesByName.get(name);
	if (!documentIDs.hasReference())
		return OV<SError>(getUnknownCollectionError(name));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return OV<SError>(getIllegalInBatchError());

	// Setup
	const	CMDSDocument::Info&	documentInfo = documentCreateInfo(documentType);

	// Iterate
	for (TIteratorD<CString> iterator = documentIDs->getIterator(); iterator.hasValue(); iterator.advance())
		// Call proc
		proc(documentInfo.create(*iterator, (CMDSDocumentStorage&) *this), procUserData);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::CreateResultInfo> > CMDSEphemeral::documentCreate(
		const CMDSDocument::InfoForNew& documentInfoForNew, const TArray<CMDSDocument::CreateInfo>& documentCreateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	UniversalTime							universalTime = SUniversalTime::getCurrent();
	TNArray<CMDSDocument::CreateResultInfo>	documentCreateResultInfos;

	// Check for batch
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
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
		// Setup
		TNArray<MDSUpdateInfo>	updateInfos;

		// Iterate document create infos
		for (TIteratorD<CMDSDocument::CreateInfo> iterator = documentCreateInfos.getIterator(); iterator.hasValue();
				iterator.advance()) {
			// Setup
			CString	documentID =
							iterator->getDocumentID().hasValue() ?
									*iterator->getDocumentID() : CUUID().getBase64String();

			// Will be creating document
			mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.set(documentID, iterator->getPropertyMap());

			// Create
			I<CMDSDocument>	document = documentInfoForNew.create(documentID, *this);

			// Remove property map
			CDictionary	propertyMap = *mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.get(documentID);
			mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.remove(documentID);

			// Add document
			UInt32							revision = mInternals->nextRevision(documentInfoForNew.getDocumentType());
			UniversalTime					creationUniversalTime =
													iterator->getCreationUniversalTime().getValue(universalTime);
			UniversalTime					modificationUniversalTime =
													iterator->getModificationUniversalTime().getValue(universalTime);
			I<Internals::DocumentBacking>	documentBacking(
													new Internals::DocumentBacking(documentID, revision,
															creationUniversalTime, modificationUniversalTime,
															propertyMap));
			mInternals->mDocumentMapsLock.lockForWriting();
			mInternals->mDocumentBackingByDocumentID.set(documentID, documentBacking);
			mInternals->mDocumentIDsByDocumentType.insert(documentInfoForNew.getDocumentType(), documentID);
			mInternals->mDocumentMapsLock.unlockForWriting();
			documentCreateResultInfos +=
					CMDSDocument::CreateResultInfo(document,
							CMDSDocument::OverviewInfo(documentID, revision, creationUniversalTime,
									modificationUniversalTime));

			// Call document changed procs
			notifyDocumentChanged(document, CMDSDocument::kChangeKindCreated);

			// Add update info
			updateInfos += MDSUpdateInfo(document, revision, documentID, propertyMap.getKeys());
		}

		// Update stuffs
		mInternals->update(documentInfoForNew.getDocumentType(), updateInfos);
	}

	return TVResult<TArray<CMDSDocument::CreateResultInfo> >(documentCreateResultInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<UInt32> CMDSEphemeral::documentGetCount(const CString& documentType) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	mInternals->mDocumentMapsLock.lockForReading();
	const	OR<TNSet<CString> >	documentIDs = mInternals->mDocumentIDsByDocumentType.get(documentType);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!documentIDs.hasReference())
		return TVResult<UInt32>(getUnknownDocumentTypeError(documentType));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return TVResult<UInt32>(getIllegalInBatchError());

	return TVResult<UInt32>(documentIDs->getCount());
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::documentIterate(const CMDSDocument::Info& documentInfo, const TArray<CString>& documentIDs,
		CMDSDocument::Proc proc, void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];

	// Iterate document IDs
	TNArray<CString>	documentIDsForDocumentBackings;
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check what we have currently
		if (batch.hasReference() && (*batch)->documentInfoGet(*iterator).hasReference())
			// Have document in batch
			proc(documentInfo.create(*iterator, (CMDSDocumentStorage&) *this), procUserData);
		else
			// Not in batch
			documentIDsForDocumentBackings += *iterator;
	}

	// Iterate document backings
	Internals::DocumentBackingsResult	documentBackingsResult =
												mInternals->documentBackingsGet(documentInfo.getDocumentType(),
														documentIDsForDocumentBackings);
	ReturnErrorIfResultError(documentBackingsResult);

	for (TIteratorD<I<Internals::DocumentBacking> > iterator = documentBackingsResult->getIterator();
			iterator.hasValue(); iterator.advance())
		// Call proc
		proc(documentInfo.create((*iterator)->getDocumentID(), (CMDSDocumentStorage&) *this), procUserData);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::documentIterate(const CMDSDocument::Info& documentInfo, bool activeOnly,
		CMDSDocument::Proc proc, void* procUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference())
		return OV<SError>(getIllegalInBatchError());

	// Iterate document backings
	Internals::DocumentBackingsResult	documentBackingsResult =
												mInternals->documentBackingsGet(documentInfo.getDocumentType(), 0,
														OV<UInt32>(), activeOnly);
	ReturnErrorIfResultError(documentBackingsResult);

	for (TIteratorD<I<Internals::DocumentBacking> > iterator = documentBackingsResult->getIterator();
			iterator.hasValue(); iterator.advance())
		// Call proc
		proc(documentInfo.create((*iterator)->getDocumentID(), (CMDSDocumentStorage&) *this), procUserData);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSEphemeral::documentCreationUniversalTime(const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<Internals::Batch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<Internals::BatchDocumentInfo>	batchDocumentInfo =
														batch.hasReference() ?
																(*batch)->documentInfoGet(document->getID()) :
																OR<Internals::BatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getCreationUniversalTime();
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(document->getID()))
		// Being created
		return SUniversalTime::getCurrent();
	else {
		// "Idle"
		mInternals->mDocumentMapsLock.lockForReading();
		const	OR<I<Internals::DocumentBacking> >	documentBacking =
															mInternals->mDocumentBackingByDocumentID.get(
																	document->getID());
		mInternals->mDocumentMapsLock.unlockForReading();

		return documentBacking.hasReference() ?
				(*documentBacking)->getCreationUniversalTime() : SUniversalTime::getCurrent();
	}
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSEphemeral::documentModificationUniversalTime(const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<Internals::Batch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<Internals::BatchDocumentInfo>	batchDocumentInfo =
														batch.hasReference() ?
																(*batch)->documentInfoGet(document->getID()) :
																OR<Internals::BatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getModificationUniversalTime();
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(document->getID()))
		// Being created
		return SUniversalTime::getCurrent();
	else {
		// "Idle"
		mInternals->mDocumentMapsLock.lockForReading();
		const	OR<I<Internals::DocumentBacking> >	documentBacking =
															mInternals->mDocumentBackingByDocumentID.get(
																	document->getID());
		mInternals->mDocumentMapsLock.unlockForReading();

		return documentBacking.hasReference() ?
				(*documentBacking)->getModificationUniversalTime() : SUniversalTime::getCurrent();
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<SValue> CMDSEphemeral::documentValue(const CString& property, const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<Internals::Batch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<Internals::BatchDocumentInfo>	batchDocumentInfo =
														batch.hasReference() ?
																(*batch)->documentInfoGet(document->getID()) :
																OR<Internals::BatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getValue(property);
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.contains(document->getID()))
		// Being created
		return mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID[document->getID()]->getOValue(property);
	else {
		// "Idle"
		mInternals->mDocumentMapsLock.lockForReading();
		const	OR<I<Internals::DocumentBacking> >	documentBacking =
															mInternals->mDocumentBackingByDocumentID[document->getID()];
		mInternals->mDocumentMapsLock.unlockForReading();

		return (*documentBacking)->getPropertyMap().getOValue(property);
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<CData> CMDSEphemeral::documentData(const CString& property, const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = documentValue(property, document);

	return (value.hasValue() && (value->getType() == SValue::kTypeData)) ? OV<CData>(value->getData()) : OV<CData>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<UniversalTime> CMDSEphemeral::documentUniversalTime(const CString& property, const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = documentValue(property, document);

	return (value.hasValue() && (value->getType() == SValue::kTypeFloat64)) ?
			OV<UniversalTime>(value->getFloat64()) : OV<UniversalTime>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::documentSet(const CString& property, const OV<SValue>& value, const I<CMDSDocument>& document,
		SetValueKind setValueKind)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	CString&	documentType = document->getDocumentType();

	// Check for batch
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		const	OR<Internals::BatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(document->getID());
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->set(property, value);
		else {
			// Don't have document in batch
			mInternals->mDocumentMapsLock.lockForReading();
			OR<I<Internals::DocumentBacking> >	documentBacking =
														mInternals->mDocumentBackingByDocumentID.get(document->getID());
			mInternals->mDocumentMapsLock.unlockForReading();

			(*batch)->documentAdd(documentType, R<I<Internals::DocumentBacking> >(*documentBacking))
					.set(property, value);
		}
	} else {
		// Check if being created
		const	OR<CDictionary>	propertyMap =
										mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID[document->getID()];
		if (propertyMap.hasReference())
			// Being created
			propertyMap->set(property, value);
		else {
			// "Idle"
			mInternals->mDocumentMapsLock.lockForWriting();
			OR<I<Internals::DocumentBacking> >	documentBacking =
														mInternals->mDocumentBackingByDocumentID.get(document->getID());
			(*documentBacking)->getPropertyMap().set(property, value);
			mInternals->mDocumentMapsLock.unlockForWriting();

			// Update stuffs
			mInternals->update(documentType,
					TSArray<MDSUpdateInfo>(
							MDSUpdateInfo(document, (*documentBacking)->getRevision(), document->getID(),
									TSSet<CString>(property))));

			// Call document changed procs
			notifyDocumentChanged(document, CMDSDocument::kChangeKindUpdated);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocument::AttachmentInfo> CMDSEphemeral::documentAttachmentAdd(const CString& documentType,
		const CString& documentID, const CDictionary& info, const CData& content)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	mInternals->mDocumentMapsLock.lockForReading();
	bool	isKnownDocumentType = mInternals->mDocumentIDsByDocumentType.contains(documentType);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!isKnownDocumentType)
		return TVResult<CMDSDocument::AttachmentInfo>(getUnknownDocumentTypeError(documentType));

	// Check for batch
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		const	OR<Internals::BatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(documentID);
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			return TVResult<CMDSDocument::AttachmentInfo>(batchDocumentInfo->attachmentAdd(info, content));
		else {
			// Don't have document in batch
			mInternals->mDocumentMapsLock.lockForReading();
			OR<I<Internals::DocumentBacking> >	documentBacking =
														mInternals->mDocumentBackingByDocumentID.get(documentID);
			mInternals->mDocumentMapsLock.unlockForReading();
			if (!documentBacking.hasReference())
				return TVResult<CMDSDocument::AttachmentInfo>(getUnknownDocumentIDError(documentID));

			return TVResult<CMDSDocument::AttachmentInfo>(
					(*batch)->documentAdd(documentType, R<I<Internals::DocumentBacking> >(*documentBacking))
							.attachmentAdd(info, content));
		}
	} else {
		// Not in batch
		OV<CMDSDocument::AttachmentInfo>	documentAttachmentInfo;
		mInternals->mDocumentMapsLock.lockForWriting();
		OR<I<Internals::DocumentBacking> >	documentBacking = mInternals->mDocumentBackingByDocumentID.get(documentID);
		if (documentBacking.hasReference())
			// Add attachment
			documentAttachmentInfo.setValue(
					(*documentBacking)->attachmentAdd(CUUID().getBase64String(), mInternals->nextRevision(documentType),
							info, content));
		mInternals->mDocumentMapsLock.unlockForWriting();

		return documentAttachmentInfo.hasValue() ?
				TVResult<CMDSDocument::AttachmentInfo>(*documentAttachmentInfo) :
				TVResult<CMDSDocument::AttachmentInfo>(getUnknownDocumentIDError(documentID));
	}
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocument::AttachmentInfoByID> CMDSEphemeral::documentAttachmentInfoByID(const CString& documentType,
		const CString& documentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	mInternals->mDocumentMapsLock.lockForReading();
	bool	isKnownDocumentType = mInternals->mDocumentIDsByDocumentType.contains(documentType);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!isKnownDocumentType)
		return TVResult<CMDSDocument::AttachmentInfoByID>(getUnknownDocumentTypeError(documentType));

	// Check for batch
	const	OR<I<Internals::Batch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<Internals::BatchDocumentInfo>	batchDocumentInfo =
														batch.hasReference() ?
																(*batch)->documentInfoGet(documentID) :
																OR<Internals::BatchDocumentInfo>();
	if (batchDocumentInfo.hasReference()) {
		// Have document in batch
		mInternals->mDocumentMapsLock.lockForReading();
		CMDSDocument::AttachmentInfoByID	documentAttachmentInfoByID =
													(*mInternals->mDocumentBackingByDocumentID.get(documentID))->
															getDocumentAttachmentInfoByID();
		mInternals->mDocumentMapsLock.unlockForReading();

		return TVResult<CMDSDocument::AttachmentInfoByID>(
				batchDocumentInfo->getUpdatedDocumentAttachmentInfoByID(documentAttachmentInfoByID));
	} else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.get(documentID).hasReference())
		// Creating
		return TVResult<CMDSDocument::AttachmentInfoByID>(TNDictionary<CMDSDocument::AttachmentInfo>());

	// Not in batch, not creating
	mInternals->mDocumentMapsLock.lockForReading();
	OR<I<Internals::DocumentBacking> >	documentBacking = mInternals->mDocumentBackingByDocumentID.get(documentID);
	mInternals->mDocumentMapsLock.unlockForReading();

	return documentBacking.hasReference() ?
			TVResult<CMDSDocument::AttachmentInfoByID>((*documentBacking)->getDocumentAttachmentInfoByID()) :
			TVResult<CMDSDocument::AttachmentInfoByID>(getUnknownDocumentIDError(documentID));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CData> CMDSEphemeral::documentAttachmentContent(const CString& documentType, const CString& documentID,
		const CString& attachmentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	mInternals->mDocumentMapsLock.lockForReading();
	bool	isKnownDocumentType = mInternals->mDocumentIDsByDocumentType.contains(documentType);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!isKnownDocumentType)
		return TVResult<CData>(getUnknownDocumentTypeError(documentType));

	// Check situation
	const	OR<I<Internals::Batch> >			batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
			OR<Internals::BatchDocumentInfo>	batchDocumentInfo =
														batch.hasReference() ?
																(*batch)->documentInfoGet(documentID) :
																OR<Internals::BatchDocumentInfo>();
			OV<CData>							data =
														batchDocumentInfo.hasReference() ?
																batchDocumentInfo->getAttachmentContent(attachmentID) :
																OV<CData>();
	if (data.hasValue())
		// Found
		return TVResult<CData>(*data);
	else if (mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID.get(documentID).hasReference())
		// Creating
		return TVResult<CData>(getUnknownAttachmentIDError(attachmentID));

	// Get non-batch attachment content
	mInternals->mDocumentMapsLock.lockForReading();
	OR<I<Internals::DocumentBacking> >		documentBacking = mInternals->mDocumentBackingByDocumentID.get(documentID);
	OR<Internals::AttachmentContentInfo>	attachmentContentInfo =
													documentBacking.hasReference() ?
															(*documentBacking)->getAttachmentContentInfo(attachmentID) :
															OR<Internals::AttachmentContentInfo>();
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!documentBacking.hasReference())
		return TVResult<CData>(getUnknownDocumentIDError(documentID));
	if (!attachmentContentInfo.hasReference())
		return TVResult<CData>(getUnknownAttachmentIDError(attachmentID));

	return TVResult<CData>(attachmentContentInfo->getContent());
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<OV<UInt32> > CMDSEphemeral::documentAttachmentUpdate(const CString& documentType, const CString& documentID,
		const CString& attachmentID, const CDictionary& updatedInfo, const CData& updatedContent)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	mInternals->mDocumentMapsLock.lockForReading();
	bool								isKnownDocumentType =
												mInternals->mDocumentIDsByDocumentType.contains(documentType);
	OR<I<Internals::DocumentBacking> >	documentBacking = mInternals->mDocumentBackingByDocumentID.get(documentID);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!isKnownDocumentType)
		return TVResult<OV<UInt32> >(getUnknownDocumentTypeError(documentType));
	if (!documentBacking.hasReference())
		return TVResult<OV<UInt32> >(getUnknownDocumentIDError(documentID));

	// Check for batch
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		const	OR<Internals::BatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(documentID);
		if (batchDocumentInfo.hasReference()) {
			// Have document in batch
			CMDSDocument::AttachmentInfoByID 	documentAttachmentInfoByID =
														batchDocumentInfo->getUpdatedDocumentAttachmentInfoByID(
																(*documentBacking)->getDocumentAttachmentInfoByID());
			OR<CMDSDocument::AttachmentInfo>	documentAttachmentInfo = documentAttachmentInfoByID.get(attachmentID);
			if (!documentAttachmentInfo.hasReference())
				return TVResult<OV<UInt32> >(getUnknownAttachmentIDError(attachmentID));

			batchDocumentInfo->attachmentUpdate(attachmentID, documentAttachmentInfo->getRevision(),
					updatedInfo, updatedContent);
		} else {
			// Don't have document in batch
			OR<Internals::AttachmentContentInfo>	attachmentContentInfo =
															(*documentBacking)->getAttachmentContentInfo(attachmentID);
			if (!attachmentContentInfo.hasReference())
				return TVResult<OV<UInt32> >(getUnknownAttachmentIDError(attachmentID));

			(*batch)->documentAdd(documentType, R<I<Internals::DocumentBacking> >(*documentBacking))
					.attachmentUpdate(attachmentID, attachmentContentInfo->getDocumentAttachmentInfo().getRevision(),
							updatedInfo, updatedContent);
		}

		return TVResult<OV<UInt32> >(OV<UInt32>());
	} else {
		// Not in batch
		OR<Internals::AttachmentContentInfo>	attachmentContentInfo =
														(*documentBacking)->getAttachmentContentInfo(attachmentID);
		if (!attachmentContentInfo.hasReference())
			return TVResult<OV<UInt32> >(getUnknownAttachmentIDError(attachmentID));

		mInternals->mDocumentMapsLock.lockForWriting();
		UInt32	revision =
						(*documentBacking)->attachmentUpdate(mInternals->nextRevision(documentType), attachmentID,
								updatedInfo, updatedContent);
		mInternals->mDocumentMapsLock.unlockForWriting();

		return TVResult<OV<UInt32> >(OV<UInt32>(revision));
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::documentAttachmentRemove(const CString& documentType, const CString& documentID,
		const CString& attachmentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	mInternals->mDocumentMapsLock.lockForReading();
	bool								isKnownDocumentType =
												mInternals->mDocumentIDsByDocumentType.contains(documentType);
	OR<I<Internals::DocumentBacking> >	documentBacking = mInternals->mDocumentBackingByDocumentID.get(documentID);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!isKnownDocumentType)
		return OV<SError>(getUnknownDocumentTypeError(documentType));
	if (!documentBacking.hasReference())
		return OV<SError>(getUnknownDocumentIDError(documentID));

	// Check for batch
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		const	OR<Internals::BatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(documentID);
		if (batchDocumentInfo.hasReference()) {
			// Have document in batch
			CMDSDocument::AttachmentInfoByID 	documentAttachmentInfoByID =
														batchDocumentInfo->getUpdatedDocumentAttachmentInfoByID(
																(*documentBacking)->getDocumentAttachmentInfoByID());
			OR<CMDSDocument::AttachmentInfo>	documentAttachmentInfo = documentAttachmentInfoByID.get(attachmentID);
			if (!documentAttachmentInfo.hasReference())
				return OV<SError>(getUnknownAttachmentIDError(attachmentID));

			batchDocumentInfo->attachmentRemove(attachmentID);
		} else {
			// Don't have document in batch
			OR<Internals::AttachmentContentInfo>	attachmentContentInfo =
															(*documentBacking)->getAttachmentContentInfo(attachmentID);
			if (!attachmentContentInfo.hasReference())
				return OV<SError>(getUnknownAttachmentIDError(attachmentID));

			(*batch)->documentAdd(documentType, R<I<Internals::DocumentBacking> >(*documentBacking))
					.attachmentRemove(attachmentID);
		}

		return OV<SError>();
	} else {
		// Not in batch
		OR<Internals::AttachmentContentInfo>	attachmentContentInfo =
														(*documentBacking)->getAttachmentContentInfo(attachmentID);
		if (!attachmentContentInfo.hasReference())
			return OV<SError>(getUnknownAttachmentIDError(attachmentID));

		mInternals->mDocumentMapsLock.lockForWriting();
		(*documentBacking)->attachmentRemove(mInternals->nextRevision(documentType), attachmentID);
		mInternals->mDocumentMapsLock.unlockForWriting();

		return OV<SError>();
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::documentRemove(const I<CMDSDocument>& document)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	CString&	documentType = document->getDocumentType();

	// Check for batch
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		const	OR<Internals::BatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(document->getID());
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->remove();
		else {
			// Don't have document in batch
			mInternals->mDocumentMapsLock.lockForReading();
			OR<I<Internals::DocumentBacking> >	documentBacking =
														mInternals->mDocumentBackingByDocumentID.get(document->getID());
			mInternals->mDocumentMapsLock.unlockForReading();

			(*batch)->documentAdd(documentType, R<I<Internals::DocumentBacking> >(*documentBacking)).remove();
		}
	} else {
		// Not in batch
		mInternals->mDocumentMapsLock.lockForWriting();
		(*mInternals->mDocumentBackingByDocumentID.get(document->getID()))->setActive(false);
		mInternals->mDocumentMapsLock.unlockForWriting();

		// Remove
		mInternals->noteRemoved(TSSet<CString>(document->getID()));

		// Call document changed procs
		notifyDocumentChanged(document, CMDSDocument::ChangeKind::kChangeKindRemoved);
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::indexRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, const CDictionary& keysInfo,
		const CMDSDocument::KeysPerformer& documentKeysPerformer)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove current index if found
	OR<I<MDSIndex> >	existingIndex = mInternals->mIndexByName.get(name);
	if (existingIndex.hasReference())
		// Remove
		mInternals->mIndexesByDocumentType.remove(documentType, *existingIndex);

	// Create or re-create index
	I<MDSIndex>	index(new MDSIndex(name, documentType, relevantProperties, documentKeysPerformer, keysInfo, 0));

	// Add to maps
	mInternals->mIndexByName.set(name, index);
	mInternals->mIndexesByDocumentType.add(documentType, index);

	// Bring up to date
	mInternals->indexUpdate(index, mInternals->updateInfosGet(documentType, documentCreateInfo(documentType), 0));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::indexIterate(const CString& name, const CString& documentType, const TArray<CString>& keys,
		CMDSDocument::KeyProc keyProc, void* keyProcUserData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	const	OR<TDictionary<CString> >	items = mInternals->mIndexValuesByName.get(name);
	if (!items.hasReference())
		return OV<SError>(getUnknownIndexError(name));
	if (mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()].hasReference())
		return OV<SError>(getIllegalInBatchError());

	// Setup
	const	CMDSDocument::Info&	documentInfo = documentCreateInfo(documentType);

	// Iterate keys
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Retrieve documentID
		const	OR<CString>	documentID = items->get(*iterator);
		if (!documentID.hasReference())
			return OV<SError>(getMissingFromIndexError(*iterator));

		// Call proc
		keyProc(*iterator, documentInfo.create(*documentID, (CMDSDocumentStorage&) *this), keyProcUserData);
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<CString> > CMDSEphemeral::infoGet(const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve values
	TNDictionary<CString>	info;
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Get value
		const	OR<CString>	value = mInternals->mInfoValueByKey[*iterator];

		// Check if have value
		if (value.hasReference())
			// Add to info
			info.set(*iterator, *value);
	}

	return TVResult<TDictionary<CString> >(info);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::infoSet(const TDictionary<CString>& info)
//----------------------------------------------------------------------------------------------------------------------
{
	// Merge it in!
	mInternals->mInfoValueByKey += info;

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::infoRemove(const TArray<CString>& keys)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove
	mInternals->mInfoValueByKey.remove(keys);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<CString> > CMDSEphemeral::internalGet(const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve values
	TNDictionary<CString>	info;
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Get value
		const	OR<CString>	value = mInternals->mInternalValueByKey[*iterator];

		// Check if have value
		if (value.hasReference())
			// Add to info
			info.set(*iterator, *value);
	}

	return TVResult<TDictionary<CString> >(info);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::internalSet(const TDictionary<CString>& info)
//----------------------------------------------------------------------------------------------------------------------
{
	// Merge it in!
	mInternals->mInternalValueByKey += info;

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::batch(BatchProc batchProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	I<Internals::Batch>	batch(new Internals::Batch());

	// Store
	mInternals->mBatchByThreadRef.set(CThread::getCurrentRefAsString(), batch);

	// Call proc
	TVResult<EMDSBatchResult>	batchResult = batchProc(userData);

	// Remove
	mInternals->mBatchByThreadRef.remove(CThread::getCurrentRefAsString());

	// Check result
	ReturnErrorIfResultError(batchResult);
	if (*batchResult == kMDSBatchResultCommit) {
		// Iterate all document changes
		Internals::BatchDocumentInfoByDocumentIDByDocumentType	batchDocumentInfoByDocumentType =
																		batch->documentGetInfosByDocumentType();
		TSet<CString>											documentTypes =
																		batchDocumentInfoByDocumentType.getKeys();
		for (TIteratorS<CString> documentTypeIterator = documentTypes.getIterator(); documentTypeIterator.hasValue();
				documentTypeIterator.advance()) {
			// Setup
			const	CMDSDocument::Info&		documentInfo = documentCreateInfo(*documentTypeIterator);
					DocumentChangedInfos	documentChangedInfos = this->documentChangedInfos(*documentTypeIterator);

					TNArray<MDSUpdateInfo>	updateInfos;
					TNSet<CString>			removedDocumentIDs;

			// Update documents
			Internals::BatchDocumentInfoByDocumentID	batchDocumentInfoByDocumentID =
																*batchDocumentInfoByDocumentType.get(
																		*documentTypeIterator);
			TSet<CString>								documentIDs = batchDocumentInfoByDocumentID.getKeys();
			for (TIteratorS<CString> documentIDIterator = documentIDs.getIterator(); documentIDIterator.hasValue();
					documentIDIterator.advance()) {
				// Setup
				const	Internals::BatchDocumentInfo&	batchDocumentInfo =
																*batchDocumentInfoByDocumentID.get(*documentIDIterator);

				// Check removed
				if (!batchDocumentInfo.isRemoved()) {
					// Add/update document
					mInternals->mDocumentMapsLock.lockForWriting();
					OR<I<Internals::DocumentBacking> >	documentBacking =
																mInternals->mDocumentBackingByDocumentID.get(
																		*documentIDIterator);
					if (documentBacking.hasReference()) {
						// Update document backing
						(*documentBacking)->update(mInternals->nextRevision(*documentTypeIterator),
								batchDocumentInfo.getUpdatedPropertyMap(), batchDocumentInfo.getRemovedProperties());

						// Process
						TNSet<CString>	changedProperties =
												TNSet<CString>(batchDocumentInfo.getUpdatedPropertyMap().getKeys())
														.insertFrom(batchDocumentInfo.getRemovedProperties());
						mInternals->process(*documentIDIterator, batchDocumentInfo, **documentBacking,
								changedProperties, documentInfo, updateInfos, documentChangedInfos,
								CMDSDocument::ChangeKind::kChangeKindUpdated);
					} else {
						// Add document
						I<Internals::DocumentBacking>	newDocumentBacking(
																new Internals::DocumentBacking(*documentIDIterator,
																		mInternals->nextRevision(*documentTypeIterator),
																		batchDocumentInfo.getCreationUniversalTime(),
																		batchDocumentInfo
																				.getModificationUniversalTime(),
																		batchDocumentInfo.getUpdatedPropertyMap()));
						mInternals->mDocumentBackingByDocumentID.set(*documentIDIterator, newDocumentBacking);
						mInternals->mDocumentIDsByDocumentType.insert(*documentTypeIterator, *documentIDIterator);

						// Process
						mInternals->process(*documentIDIterator, batchDocumentInfo, *newDocumentBacking,
								batchDocumentInfo.getUpdatedPropertyMap().getKeys(), documentInfo, updateInfos,
								documentChangedInfos, CMDSDocument::ChangeKind::kChangeKindCreated);
					}

					// Unlock
					mInternals->mDocumentMapsLock.unlockForWriting();
				} else {
					// Remove document
					removedDocumentIDs.insert(*documentIDIterator);

					// Lock
					mInternals->mDocumentMapsLock.lockForWriting();

					// Update maps
					(*mInternals->mDocumentBackingByDocumentID.get(*documentIDIterator))->setActive(false);

					// Check if have changed procs
					if (!documentChangedInfos.isEmpty()) {
						// Create document
						I<CMDSDocument>	document = documentInfo.create(*documentIDIterator, *this);

						// Call document changed procs
						for (TIteratorD<CMDSDocument::ChangedInfo> iterator = documentChangedInfos.getIterator();
								iterator.hasValue(); iterator.advance())
							// Call proc
							iterator->notify(document, CMDSDocument::ChangeKind::kChangeKindRemoved);
					}

					// Unlock
					mInternals->mDocumentMapsLock.unlockForWriting();
				}
			}

			// Update stuffs
			mInternals->noteRemoved(removedDocumentIDs);
			mInternals->update(*documentTypeIterator, updateInfos);
		}

		// Iterate all association changes
		TSet<CString>	associationNames = batch->associationGetUpdatedNames();
		for (TIteratorS<CString> associationNameIterator = associationNames.getIterator();
				associationNameIterator.hasValue(); associationNameIterator.advance()) {
			// Iterate updates
			TArray<CMDSAssociation::Update>	associationUpdates = batch->associationGetUpdates(*associationNameIterator);
			for (TIteratorD<CMDSAssociation::Update> associationUpdateIterator = associationUpdates.getIterator();
					associationUpdateIterator.hasValue(); associationUpdateIterator.advance()) {
				// Check action
				if (associationUpdateIterator->getAction() == CMDSAssociation::Update::kActionAdd)
					// Add
					mInternals->mAssociationItemsByName.remove(*associationNameIterator,
							associationUpdateIterator->getItem());
				else
					// Remove
					mInternals->mAssociationItemsByName.add(*associationNameIterator,
							associationUpdateIterator->getItem());
			}
		}
	}

	return OV<SError>();
}

// MARK: CMDSDocumentStorageServer methods

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>
				CMDSEphemeral::associationGetDocumentRevisionInfosFrom(
		const CString& name, const CString& fromDocumentID, UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>(
				getUnknownAssociationError(name));

	mInternals->mDocumentMapsLock.lockForReading();
	bool	found = mInternals->mDocumentBackingByDocumentID.contains(fromDocumentID);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!found)
		return TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>(
				getUnknownDocumentIDError(fromDocumentID));

	// Get document IDs
	TArray<CMDSAssociation::Item>	associationItems = mInternals->associationGetItems(name);
	TNArray<CString>				documentIDs;
	UInt32							toDocumentIDIndex = 0;
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance())
		// Check association item
		if (iterator->getFromDocumentID() == fromDocumentID) {
			// Check index
			if (toDocumentIDIndex >= startIndex)
				// Add documentID
				documentIDs += iterator->getToDocumentID();

			// Update
			if (count.hasValue() && (++toDocumentIDIndex > (startIndex + *count)))
				// Done
				break;
		}

		// Retrieve Document RevisionInfos
		TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
		mInternals->mDocumentMapsLock.lockForReading();
		for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance())
			// Add Document RevisionInfo
			documentRevisionInfos += (*mInternals->mDocumentBackingByDocumentID[*iterator])->getDocumentRevisionInfo();
		mInternals->mDocumentMapsLock.unlockForReading();

		return TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>(
				CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount(documentIDs.getCount(),
						documentRevisionInfos));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>
				CMDSEphemeral::associationGetDocumentRevisionInfosTo(
		const CString& name, const CString& toDocumentID, UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>(
				getUnknownAssociationError(name));

	mInternals->mDocumentMapsLock.lockForReading();
	bool	found = mInternals->mDocumentBackingByDocumentID.contains(toDocumentID);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!found)
		return TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>(
				getUnknownDocumentIDError(toDocumentID));

	// Get document IDs
	TArray<CMDSAssociation::Item>	associationItems = mInternals->associationGetItems(name);
	TNArray<CString>				documentIDs;
	UInt32							fromDocumentIDIndex = 0;
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance())
		// Check association item
		if (iterator->getToDocumentID() == toDocumentID) {
			// Check index
			if (fromDocumentIDIndex >= startIndex)
				// Add documentID
				documentIDs += iterator->getFromDocumentID();

			// Update
			if (count.hasValue() && (++fromDocumentIDIndex > (startIndex + *count)))
				// Done
				break;
		}

		// Retrieve Document RevisionInfos
		TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
		mInternals->mDocumentMapsLock.lockForReading();
		for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance())
			// Add Document RevisionInfo
			documentRevisionInfos += (*mInternals->mDocumentBackingByDocumentID[*iterator])->getDocumentRevisionInfo();
		mInternals->mDocumentMapsLock.unlockForReading();

		return TVResult<CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount>(
				CMDSDocumentStorageServer::DocumentRevisionInfosWithTotalCount(documentIDs.getCount(),
						documentRevisionInfos));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount> CMDSEphemeral::associationGetDocumentFullInfosFrom(
		const CString& name, const CString& fromDocumentID, UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>(
				getUnknownAssociationError(name));

	mInternals->mDocumentMapsLock.lockForReading();
	bool	found = mInternals->mDocumentBackingByDocumentID.contains(fromDocumentID);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!found)
		return TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>(
				getUnknownDocumentIDError(fromDocumentID));

	// Get document IDs
	TArray<CMDSAssociation::Item>	associationItems = mInternals->associationGetItems(name);
	TNArray<CString>				documentIDs;
	UInt32							toDocumentIDIndex = 0;
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check association item
		if (iterator->getFromDocumentID() == fromDocumentID) {
			// Check index
			if (toDocumentIDIndex >= startIndex)
				// Add documentID
				documentIDs += iterator->getToDocumentID();

			// Update
			if (count.hasValue() && (++toDocumentIDIndex > (startIndex + *count)))
				// Done
				break;
		}
	}

	// Retrieve Document FullInfos
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	mInternals->mDocumentMapsLock.lockForReading();
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance())
		// Add Document FullInfo
		documentFullInfos += (*mInternals->mDocumentBackingByDocumentID[*iterator])->getDocumentFullInfo();
	mInternals->mDocumentMapsLock.unlockForReading();

	return TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>(
			CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount(documentIDs.getCount(),
					documentFullInfos));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount> CMDSEphemeral::associationGetDocumentFullInfosTo(
		const CString& name, const CString& toDocumentID, UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>(
				getUnknownAssociationError(name));

	mInternals->mDocumentMapsLock.lockForReading();
	bool	found = mInternals->mDocumentBackingByDocumentID.contains(toDocumentID);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!found)
		return TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>(
				getUnknownDocumentIDError(toDocumentID));

	// Get document IDs
	TArray<CMDSAssociation::Item>	associationItems = mInternals->associationGetItems(name);
	TNArray<CString>				documentIDs;
	UInt32							fromDocumentIDIndex = 0;
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check association item
		if (iterator->getToDocumentID() == toDocumentID) {
			// Check index
			if (fromDocumentIDIndex >= startIndex)
				// Add documentID
				documentIDs += iterator->getFromDocumentID();

			// Update
			if (count.hasValue() && (++fromDocumentIDIndex > (startIndex + *count)))
				// Done
				break;
		}
	}

	// Retrieve Document FullInfos
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	mInternals->mDocumentMapsLock.lockForReading();
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance())
		// Add Document FullInfo
		documentFullInfos += (*mInternals->mDocumentBackingByDocumentID[*iterator])->getDocumentFullInfo();
	mInternals->mDocumentMapsLock.unlockForReading();

	return TVResult<CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount>(
			CMDSDocumentStorageServer::DocumentFullInfosWithTotalCount(documentIDs.getCount(),
					documentFullInfos));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::RevisionInfo> > CMDSEphemeral::collectionGetDocumentRevisionInfos(const CString& name,
		UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	const	OR<TNArray<CString> >	documentIDs = mInternals->mCollectionValuesByName.get(name);
	if (!documentIDs.hasReference())
		return TVResult<TArray<CMDSDocument::RevisionInfo> >(getUnknownCollectionError(name));

	// Process documentIDs
	TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
	mInternals->mDocumentMapsLock.lockForReading();
	for (TIteratorD<CString> iterator = documentIDs->getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check index
		if (iterator.getIndex() >= startIndex)
			// Add Document RevisionInfo
			documentRevisionInfos +=
					(*mInternals->mDocumentBackingByDocumentID.get(*iterator))->getDocumentRevisionInfo();

		// Check count
		if (count.hasValue() && (iterator.getIndex() > (startIndex + *count)))
			// Done
			break;
	}
	mInternals->mDocumentMapsLock.unlockForReading();

	return TVResult<TArray<CMDSDocument::RevisionInfo> >(documentRevisionInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::FullInfo> > CMDSEphemeral::collectionGetDocumentFullInfos(const CString& name,
		UInt32 startIndex, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	const	OR<TNArray<CString> >	documentIDs = mInternals->mCollectionValuesByName.get(name);
	if (!documentIDs.hasReference())
		return TVResult<TArray<CMDSDocument::FullInfo> >(getUnknownCollectionError(name));

	// Process documentIDs
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	mInternals->mDocumentMapsLock.lockForReading();
	for (TIteratorD<CString> iterator = documentIDs->getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check index
		if (iterator.getIndex() >= startIndex)
			// Add Document FullInfo
			documentFullInfos += (*mInternals->mDocumentBackingByDocumentID.get(*iterator))->getDocumentFullInfo();

		// Check count
		if (count.hasValue() && (iterator.getIndex() > (startIndex + *count)))
			// Done
			break;
	}
	mInternals->mDocumentMapsLock.unlockForReading();

	return TVResult<TArray<CMDSDocument::FullInfo> >(documentFullInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::RevisionInfo> > CMDSEphemeral::documentRevisionInfos(const CString& documentType,
		const TArray<CString>& documentIDs) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get Document Backings
	Internals::DocumentBackingsResult	documentBackingsResult =
												mInternals->documentBackingsGet(documentType, documentIDs);
	ReturnValueIfResultError(documentBackingsResult,
			TVResult<TArray<CMDSDocument::RevisionInfo> >(documentBackingsResult.getError()));

	// Iterate document backings
	TNArray<CMDSDocument::RevisionInfo>	documentRevisionInfos;
	for (TIteratorD<I<Internals::DocumentBacking> > iterator = documentBackingsResult->getIterator();
			iterator.hasValue(); iterator.advance())
		// Add document revision info
		documentRevisionInfos += (*iterator)->getDocumentRevisionInfo();

	return TVResult<TArray<CMDSDocument::RevisionInfo> >(documentRevisionInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::RevisionInfo> > CMDSEphemeral::documentRevisionInfos(const CString& documentType,
		UInt32 sinceRevision, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get Document Backings
	Internals::DocumentBackingsResult	documentBackingsResult =
												mInternals->documentBackingsGet(documentType, sinceRevision, count);
	ReturnValueIfResultError(documentBackingsResult,
			TVResult<TArray<CMDSDocument::RevisionInfo> >(documentBackingsResult.getError()));

	// Iterate document backings
	TNArray<CMDSDocument::RevisionInfo> documentRevisionInfos;
	for (TIteratorD<I<Internals::DocumentBacking> > iterator = documentBackingsResult->getIterator();
			iterator.hasValue(); iterator.advance())
		// Add document revision info
		documentRevisionInfos += (*iterator)->getDocumentRevisionInfo();

	return TVResult<TArray<CMDSDocument::RevisionInfo> >(documentRevisionInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::FullInfo> > CMDSEphemeral::documentFullInfos(const CString& documentType,
		const TArray<CString>& documentIDs) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get Document Backings
	Internals::DocumentBackingsResult	documentBackingsResult =
												mInternals->documentBackingsGet(documentType, documentIDs);
	ReturnValueIfResultError(documentBackingsResult,
			TVResult<TArray<CMDSDocument::FullInfo> >(documentBackingsResult.getError()));

	// Iterate document backings
	TNArray<CMDSDocument::FullInfo>	documentFullInfos;
	for (TIteratorD<I<Internals::DocumentBacking> > iterator = documentBackingsResult->getIterator();
			iterator.hasValue(); iterator.advance())
		// Add document full info
		documentFullInfos += (*iterator)->getDocumentFullInfo();

	return TVResult<TArray<CMDSDocument::FullInfo> >(documentFullInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::FullInfo> > CMDSEphemeral::documentFullInfos(const CString& documentType,
		UInt32 sinceRevision, const OV<UInt32>& count) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get Document Backings
	Internals::DocumentBackingsResult	documentBackingsResult =
												mInternals->documentBackingsGet(documentType, sinceRevision, count);
	ReturnValueIfResultError(documentBackingsResult,
			TVResult<TArray<CMDSDocument::FullInfo> >(documentBackingsResult.getError()));

	// Iterate document backings
	TNArray<CMDSDocument::FullInfo> documentFullInfos;
	for (TIteratorD<I<Internals::DocumentBacking> > iterator = documentBackingsResult->getIterator();
			iterator.hasValue(); iterator.advance())
		// Add document full info
		documentFullInfos += (*iterator)->getDocumentFullInfo();

	return TVResult<TArray<CMDSDocument::FullInfo> >(documentFullInfos);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SInt64> CMDSEphemeral::documentIntegerValue(const CString& documentType, const I<CMDSDocument>& document,
		const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		const	OR<Internals::BatchDocumentInfo>	batchDocumentInfo = (*batch)->documentInfoGet(document->getID());
		if (batchDocumentInfo.hasReference()) {
			// In batch
			OV<SValue>	value = batchDocumentInfo->getValue(property);

			return (value.hasValue() && value->canCoerceToType(SValue::kTypeSInt64)) ?
					OV<SInt64>(value->getSInt64()) : OV<SInt64>();
		}
	}

	// Check if being created
	const	OR<CDictionary>	propertyMap = mInternals->mDocumentsBeingCreatedPropertyMapByDocumentID[document->getID()];
	if (propertyMap.hasReference()) {
		// Being created
		OV<SValue>	value =
							propertyMap->contains(property) ?
									OV<SValue>(propertyMap->getValue(property)) : OV<SValue>();

		return (value.hasValue() && value->canCoerceToType(SValue::kTypeSInt64)) ?
				OV<SInt64>(value->getSInt64()) : OV<SInt64>();
	}

	// "Idle"
	mInternals->mDocumentMapsLock.lockForReading();
	const	OR<I<Internals::DocumentBacking> >	documentBacking =
														mInternals->mDocumentBackingByDocumentID[document->getID()];
			OV<SValue>							value =
														(documentBacking.hasReference() &&
																		(*documentBacking)->getPropertyMap().contains(
																				property)) ?
																OV<SValue>(
																		(*documentBacking)->getPropertyMap().getValue(
																				property)) :
																OV<SValue>();
	mInternals->mDocumentMapsLock.unlockForReading();

	return (value.hasValue() && value->canCoerceToType(SValue::kTypeSInt64)) ?
			OV<SInt64>(value->getSInt64()) : OV<SInt64>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<CString> CMDSEphemeral::documentStringValue(const CString& documentType, const I<CMDSDocument>& document,
		const CString& property) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = documentValue(property, document);

	return (value.hasValue() && (value->getType() == SValue::kTypeString)) ?
			OV<CString>(value->getString()) : OV<CString>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::FullInfo> > CMDSEphemeral::documentUpdate(const CString& documentType,
		const TArray<CMDSDocument::UpdateInfo>& documentUpdateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	mInternals->mDocumentMapsLock.lockForReading();
	bool	isKnownDocumentType = mInternals->mDocumentIDsByDocumentType.contains(documentType);
	mInternals->mDocumentMapsLock.unlockForReading();
	if (!isKnownDocumentType)
		return TVResult<TArray<CMDSDocument::FullInfo> >(getUnknownDocumentTypeError(documentType));

	// Setup
	const	CMDSDocument::Info&				documentInfo = documentCreateInfo(documentType);
			TNArray<MDSUpdateInfo>			updateInfos;
			TNSet<CString>					removedDocumentIDs;
			TNArray<CMDSDocument::FullInfo>	documentFullInfos;

	// Iterate document update infos
	for (TIteratorD<CMDSDocument::UpdateInfo> iterator = documentUpdateInfos.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check active
		if (iterator->getActive()) {
			// Update document
			mInternals->mDocumentMapsLock.lockForWriting();

			// Retrieve existing document backing
			OR<I<Internals::DocumentBacking> >	documentBacking =
														mInternals->mDocumentBackingByDocumentID.get(
																iterator->getDocumentID());
			if (documentBacking.hasReference()) {
				// Update document backing
				(*documentBacking)->update(mInternals->nextRevision(documentType), iterator->getUpdated(),
						iterator->getRemoved());

				// Create document
				I<CMDSDocument>	document = documentInfo.create(iterator->getDocumentID(), *this);

				// Add update info
				updateInfos +=
						MDSUpdateInfo(document, (*documentBacking)->getRevision(), iterator->getDocumentID(),
								TNSet<CString>(iterator->getUpdated().getKeys()).insertFrom(iterator->getRemoved()));

				// Add full info
				documentFullInfos += (*documentBacking)->getDocumentFullInfo();

				// Call document changed procs
				notifyDocumentChanged(document, CMDSDocument::kChangeKindUpdated);
			}

			// Done
			mInternals->mDocumentMapsLock.unlockForWriting();
		} else {
			// Remove document
			removedDocumentIDs += iterator->getDocumentID();

			// Update document backing
			mInternals->mDocumentMapsLock.lockForWriting();

			// Retrieve existing document backing
			OR<I<Internals::DocumentBacking> >	documentBacking =
														mInternals->mDocumentBackingByDocumentID.get(
																iterator->getDocumentID());
			if (documentBacking.hasReference()) {
				// Update active
				(*documentBacking)->setActive(false);

				// Add full info
				documentFullInfos += (*documentBacking)->getDocumentFullInfo();

				// Check if have document changed infos
				if (!documentChangedInfos(documentType).isEmpty()) {
					// Create document
					I<CMDSDocument>	document = documentInfo.create(iterator->getDocumentID(), *this);

					// Call document changed procs
					notifyDocumentChanged(document, CMDSDocument::kChangeKindRemoved);
				}
			}

			// Done
			mInternals->mDocumentMapsLock.unlockForWriting();
		}
	}

	// Update stuffs
	mInternals->noteRemoved(removedDocumentIDs);
	mInternals->update(documentType, updateInfos);

	return TVResult<TArray<CMDSDocument::FullInfo> >(documentFullInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<CMDSDocument::RevisionInfo> > CMDSEphemeral::indexGetDocumentRevisionInfos(const CString& name,
		const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	const	OR<TDictionary<CString> >	items = mInternals->mIndexValuesByName[name];
	if (!items.hasReference())
		return TVResult<TDictionary<CMDSDocument::RevisionInfo> >(getUnknownIndexError(name));

	// Iterate keys
	OV<SError>	error;
	TNDictionary<CMDSDocument::RevisionInfo>	documentRevisionInfos;
	mInternals->mDocumentMapsLock.lockForReading();
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue() && !error.hasValue();
			iterator.advance()) {
		// Get documentID
		const	OR<CString>	documentID = (*items)[*iterator];
		if (documentID.hasReference())
			// Success
			documentRevisionInfos.set(*iterator,
					(*mInternals->mDocumentBackingByDocumentID[*documentID])->getDocumentRevisionInfo());
		else
			// documentID not found
			error.setValue(getMissingFromIndexError(*iterator));
	}
	mInternals->mDocumentMapsLock.unlockForReading();

	return !error.hasValue() ?
			TVResult<TDictionary<CMDSDocument::RevisionInfo> >(documentRevisionInfos) :
			TVResult<TDictionary<CMDSDocument::RevisionInfo> >(*error);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<CMDSDocument::FullInfo> > CMDSEphemeral::indexGetDocumentFullInfos(const CString& name,
		const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	const	OR<TDictionary<CString> >	items = mInternals->mIndexValuesByName[name];
	if (!items.hasReference())
		return TVResult<TDictionary<CMDSDocument::FullInfo> >(getUnknownIndexError(name));

	// Iterate keys
	OV<SError>	error;
	TNDictionary<CMDSDocument::FullInfo>	documentFullInfos;
	mInternals->mDocumentMapsLock.lockForReading();
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue() && !error.hasValue();
			iterator.advance()) {
		// Get documentID
		const	OR<CString>	documentID = (*items)[*iterator];
		if (documentID.hasReference())
			// Success
			documentFullInfos.set(*iterator,
					(*mInternals->mDocumentBackingByDocumentID[*documentID])->getDocumentFullInfo());
		else
			// documentID not found
			error.setValue(getMissingFromIndexError(*iterator));
	}
	mInternals->mDocumentMapsLock.unlockForReading();

	return !error.hasValue() ?
			TVResult<TDictionary<CMDSDocument::FullInfo> >(documentFullInfos) :
			TVResult<TDictionary<CMDSDocument::FullInfo> >(*error);
}
