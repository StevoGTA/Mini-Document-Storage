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
// MARK: CMDSEphemeral::Internals
class CMDSEphemeral::Internals {
	// Types
	public:
		typedef	TMDSBatch<CDictionary>							Batch;

		typedef	TMDSCache<CString>								Cache;
		typedef	TNDictionary<CDictionary>						CacheValueMap;

		typedef	TMDSCollection<CString, TNArray<CString> >		Collection;

		typedef	TNDictionary<CMDSDocument::AttachmentInfo>		DocumentAttachmentInfoDictionary;

		typedef	TMDSIndex<CString>								Index;

		typedef	TMDSUpdateInfo<CString>							UpdateInfo;
		typedef	TArray<UpdateInfo>								UpdateInfos;

	// AttachmentContentInfo
	private:
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
		const	CString&						getDocumentID() const
													{ return mDocumentID; }
				UInt32							getRevision() const
													{ return mRevision; }
				bool							isActive() const
													{ return mActive; }

				CMDSDocument::RevisionInfo		getDocumentRevisionInfo() const
													{ return CMDSDocument::RevisionInfo(mDocumentID, mRevision); }
				CMDSDocument::FullInfo			getDocumentFullInfo() const
													{
														// Setup
														DocumentAttachmentInfoDictionary	documentAttachmentInfoMap;
														TSet<CString>						attachmentIDs =
																									mAttachmentContentInfoByAttachmentID
																											.getKeys();
														for (TIteratorS<CString> iterator = attachmentIDs.getIterator();
																iterator.hasValue(); iterator.advance())
															// Update
															documentAttachmentInfoMap.set(*iterator,
																	mAttachmentContentInfoByAttachmentID[*iterator]->
																			getDocumentAttachmentInfo());

														return CMDSDocument::FullInfo(mDocumentID, mRevision, mActive,
																mCreationUniversalTime, mModificationUniversalTime,
																mPropertyMap, documentAttachmentInfoMap);
													}

				void							update(UInt32 revision, const OV<CDictionary>& updatedPropertyMap,
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
				CMDSDocument::AttachmentInfo	attachmentAdd(UInt32 revision, const CDictionary& info,
														const CData& content)
													{
														// Setup
														CString							attachmentID =
																								CUUID().getBase64String();
														CMDSDocument::AttachmentInfo	documentAttachmentInfo(
																								attachmentID, 1, info);

														// Add
														mAttachmentContentInfoByAttachmentID.set(attachmentID,
																AttachmentContentInfo(documentAttachmentInfo, content));

														// Update
														mRevision = revision;
														mModificationUniversalTime = SUniversalTime::getCurrent();

														return documentAttachmentInfo;
													}
				UInt32							attachmentUpdate(UInt32 revision, const CString& attachmentID,
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
				void							attachmentRemove(UInt32 revision, const CString& attachmentID)
													{
														// Remove
														mAttachmentContentInfoByAttachmentID.remove(attachmentID);

														// Update
														mRevision = revision;
														mModificationUniversalTime = SUniversalTime::getCurrent();
													}

												// Class methods
		static	bool							compareRevision(const I<DocumentBacking>& documentBacking1,
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
		typedef	TArray<I<DocumentBacking> >	DocumentBackings;
		typedef	TVResult<DocumentBackings>	DocumentBackingsResult;

	// Methods
	public:
												// Lifecycle methods
												Internals(CMDSDocumentStorage& documentStorage) :
													mDocumentStorage(documentStorage)
													{}

												// Instance methods
				TArray<CMDSAssociation::Item>	getAssociationItems(const CString& name) const
													{
														// Get association items
														mDocumentMapsLock.lockForReading();
														TArray<CMDSAssociation::Item>	associationItems =
																								*mAssociationItemsByName.get(
																										name);
														mDocumentMapsLock.unlockForReading();

														// Check for batch
														OR<I<Batch> >	batch = mBatchByThreadRef.get(CThread::getCurrentRef());
														if (batch.hasReference())
															// Apply batch changes
															associationItems =
																	(*batch)->getAssocationItems(name, associationItems);

														return associationItems;
													}
				void							cacheUpdate(const I<Cache>& cache,
														const TArray<UpdateInfo>& updateInfos)
													{
														// Update Cache
																Cache::UpdateResults			cacheUpdateResults =
																										cache->update(
																												updateInfos);
														const	OV<TDictionary<CDictionary> >&	infosByID =
																										cacheUpdateResults
																												.getInfosByID();

														// Check if have updates
														if (infosByID.hasValue()) {
															// Update storage
															mCacheValuesByName.update(cache->getName(),
																	(TNLockingDictionary<CacheValueMap>::UpdateProc)
																			updateCacheValueMap,
																	(void*) &(*infosByID));
														}
													}
				void							collectionUpdate(const I<Collection>& collection,
														const TArray<UpdateInfo>& updateInfos)
													{
													}
				DocumentBackingsResult			getDocumentBackings(const CString& documentType, UInt32 sinceRevision,
														const OV<UInt32>& count = OV<UInt32>(), bool activeOnly = false)
													{
														// Setup
														TNArray<I<DocumentBacking> >	documentBackings;

														// Perform under lock
														mDocumentMapsLock.lockForReading();
														bool	documentTypeFound =
																		mDocumentIDsByType.contains(documentType);
														if (documentTypeFound) {
															// Collect DocumentBackings
															TSet<CString>	documentIDs =
																					*mDocumentIDsByType.get(
																							documentType);
															for (TIteratorS<CString> iterator =
																			documentIDs.getIterator();
																	iterator.hasValue(); iterator.advance()) {
																// Get DocumentBacking
																I<DocumentBacking>	documentBacking =
																							*mDocumentBackingByDocumentID.get(
																									*iterator);

																// Check
																if ((documentBacking->getRevision() > sinceRevision) &&
																		(!activeOnly || documentBacking->isActive()))
																	// Passes
																	documentBackings += documentBacking;
															}
														}
														mDocumentMapsLock.unlockForReading();

														if (!documentTypeFound)
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
				void							indexUpdate(const I<Index>& index,
														const TArray<UpdateInfo>& updateInfos)
													{
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
				UpdateInfos						getUpdateInfos(const CString& documentType,
														const CMDSDocument::Info& documentInfo, UInt32 sinceRevision)
													{
														// Setup
														DocumentBackingsResult	documentBackingsResult =
																						getDocumentBackings(
																								documentType,
																								sinceRevision);
														if (documentBackingsResult.hasError())
															// Error
															return TNArray<UpdateInfo>();

														// Iterate results
														TNArray<UpdateInfo>	updateInfos;
														for (TIteratorD<I<DocumentBacking> > iterator =
																		documentBackingsResult.getValue().getIterator();
																iterator.hasValue(); iterator.advance())
															// Add UpdateInfo
															updateInfos +=
																	UpdateInfo(
																			documentInfo.create(
																					(*iterator)->getDocumentID(),
																					mDocumentStorage),
																			(*iterator)->getRevision(),
																			(*iterator)->getDocumentID());

														return updateInfos;
													}
				void							update(const CString& documentType, const UpdateInfos& updateInfos)
													{
														// Update caches
														const	OR<TNArray<I<Cache> > >	caches =
																								mCachesByDocumentType
																										.get(documentType);
														if (caches.hasReference())
															// Update
															for (TIteratorD<I<Cache> > iterator = caches->getIterator();
																	iterator.hasValue(); iterator.advance())
																// Update
																cacheUpdate(*iterator, updateInfos);

														// Update collections
														const	OR<TNArray<I<Collection> > > collections =
																									mCollectionsByDocumentType
																											.get(documentType);
														if (collections.hasReference())
															// Update
															for (TIteratorD<I<Collection> > iterator =
																			collections->getIterator();
																	iterator.hasValue(); iterator.advance())
																// Update
																collectionUpdate(*iterator, updateInfos);

														// Update indexes
														const	OR<TNArray<I<Index> > > indexes =
																								mIndexesByDocumentType
																										.get(documentType);
														if (indexes.hasReference())
															// Update
															for (TIteratorD<I<Index> > iterator =
																			indexes->getIterator();
																	iterator.hasValue(); iterator.advance())
																// Update
																indexUpdate(*iterator, updateInfos);
													}

												// Class methods
		static	OV<CacheValueMap >				updateCacheValueMap(const OR<CacheValueMap >& currentCacheValueMap,
														TDictionary<CDictionary>* infosByID)
													{
														// Setup
																CacheValueMap	cacheValueMap =
																						currentCacheValueMap.hasReference() ?
																								CacheValueMap(
																										*currentCacheValueMap) :
																								CacheValueMap();
														const	TSet<CString>&	keys = infosByID->getKeys();

														// Iterate keys
														for (TIteratorS<CString> iterator = keys.getIterator();
																iterator.hasValue(); iterator.advance())
															// Update
															cacheValueMap.set(*iterator,
																	infosByID->getDictionary(*iterator));

														return !cacheValueMap.isEmpty() ?
																OV<CacheValueMap>(cacheValueMap) : OV<CacheValueMap>();
													}

	// Properties
	public:
		CMDSDocumentStorage&							mDocumentStorage;

		TNLockingDictionary<I<CMDSAssociation> >		mAssociationByName;
		TNLockingArrayDictionary<CMDSAssociation::Item>	mAssociationItemsByName;

		TNLockingDictionary<I<Batch> >					mBatchByThreadRef;

		TNLockingDictionary<I<Cache> >					mCacheByName;
		TNLockingArrayDictionary<I<Cache> >				mCachesByDocumentType;
		TNLockingDictionary<CacheValueMap>				mCacheValuesByName;

		TNLockingDictionary<I<Collection> >				mCollectionByName;
		TNLockingArrayDictionary<I<Collection> >		mCollectionsByDocumentType;
		TNLockingDictionary<TNArray<CString> >			mCollectionValuesByName;

		TNDictionary<I<DocumentBacking> >				mDocumentBackingByDocumentID;
		TNSetDictionary<CString>						mDocumentIDsByType;
		CReadPreferringLock								mDocumentMapsLock;
		TNDictionary<UInt32>							mDocumentLastRevisionByDocumentType;
		CLock											mDocumentLastRevisionByDocumentTypeLock;
		TNLockingDictionary<CDictionary>				mDocumentsBeingCreatedPropertyMapByDocumentID;

		TNLockingDictionary<I<Index> >					mIndexByName;
		TNLockingArrayDictionary<I<Index> >				mIndexesByDocumentType;
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
	// Validate
	if (!mInternals->mDocumentIDsByType.contains(fromDocumentType))
		return OV<SError>(getUnknownDocumentTypeError(fromDocumentType));
	if (!mInternals->mDocumentIDsByType.contains(toDocumentType))
		return OV<SError>(getUnknownDocumentTypeError(toDocumentType));

	// Check if have association already
	if (!mInternals->mAssociationByName.get(name).hasReference()) {
		// Create
		mInternals->mAssociationByName.set(name,
				I<CMDSAssociation>(new CMDSAssociation(name, fromDocumentType, toDocumentType)));
		mInternals->mAssociationItemsByName.set(name, TNArray<CMDSAssociation::Item>());
	}

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSAssociation::Item> > CMDSEphemeral::associationGet(const CString& name) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return TVResult<TArray<CMDSAssociation::Item> >(getUnknownAssociationError(name));

	return TVResult<TArray<CMDSAssociation::Item> >(mInternals->getAssociationItems(name));
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
			TArray<CMDSAssociation::Item>	associationItems = mInternals->getAssociationItems(name);
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
OV<SError> CMDSEphemeral::associationIterateTo(const CString& name, const CString& toDocumentID,
		const CString& fromDocumentType, CMDSDocument::Proc proc, void* procUserData) const
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

	if ((*association)->getToDocumentType() != fromDocumentType)
		return OV<SError>(getInvalidDocumentTypeError(fromDocumentType));

	// Get association items
	const	CMDSDocument::Info&				documentInfo = documentCreateInfo(fromDocumentType);
			TArray<CMDSAssociation::Item>	associationItems = mInternals->getAssociationItems(name);
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
TVResult<CDictionary> CMDSEphemeral::associationGetIntegerValues(const CString& name,
		CMDSAssociation::GetIntegerValueAction action, const TArray<CString>& fromDocumentIDs, const CString& cacheName,
		const TArray<CString>& cachedValueNames) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return TVResult<CDictionary>(getUnknownAssociationError(name));

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
		return TVResult<CDictionary>(*error);

	OR<I<Internals::Cache> >	cache = mInternals->mCacheByName.get(cacheName);
	if (!cache.hasReference())
		return TVResult<CDictionary>(getUnknownCacheError(cacheName));

	for (TIteratorD<CString> iterator = cachedValueNames.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check if have info for this cachedValueName
		if (!(*cache)->hasValueInfo(*iterator))
			return TVResult<CDictionary>(getUnknownCacheValueName(*iterator));
	}

	// Setup
	TNSet<CString>	fromDocumentIDsUse(fromDocumentIDs);

	// Get association items
	TArray<CMDSAssociation::Item>	associationItems = mInternals->getAssociationItems(name);

	// Process association items
	TDictionary<CDictionary>	cacheValueInfos = *mInternals->mCacheValuesByName.get(cacheName);
	CDictionary					results;
	for (TIteratorD<CMDSAssociation::Item> iterator = associationItems.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check fromDocumentID
		if (fromDocumentIDsUse.contains(iterator->getFromDocumentID())) {
			// Get value and sum
			CDictionary	valueInfos = *cacheValueInfos.get(iterator->getToDocumentID());

			// Iterate cachedValueNames
			for (TIteratorD<CString> iterator = cachedValueNames.getIterator(); iterator.hasValue(); iterator.advance())
				// Update results
				results.set(*iterator, results.getSInt64(*iterator) + valueInfos.getSInt64(*iterator));
		}
	}

	return TVResult<CDictionary>(results);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::associationUpdate(const CString& name, const TArray<CMDSAssociation::Update>& updates)
//----------------------------------------------------------------------------------------------------------------------
{
	// Validate
	if (!mInternals->mAssociationByName.contains(name))
		return OV<SError>(getUnknownAssociationError(name));

	// Check if have updates
	if (updates.isEmpty())
		return OV<SError>();

	// Check for batch
	OR<I<Internals::Batch> >	batch = mInternals->mBatchByThreadRef.get(CThread::getCurrentRef());
	if (batch.hasReference())
		// In batch
		(*batch)->associationNoteUpdated(name, updates);
	else
		// Not in batch
		for (TIteratorD<CMDSAssociation::Update> iterator = updates.getIterator(); iterator.hasValue();
				iterator.advance())
			// Check Add or Remove
			if (iterator->getAction() == CMDSAssociation::Update::kActionAdd)
				// Add
				mInternals->mAssociationItemsByName.add(name, iterator->getItem());
			else
				// Remove
				mInternals->mAssociationItemsByName.remove(name, iterator->getItem());

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeral::cacheRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, const TArray<SMDSCacheValueInfo>& valueInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove current cache if found
	if (mInternals->mCacheByName.contains(name))
		// Remove
		mInternals->mCacheByName.remove(name);

	// Create or re-create
	I<Internals::Cache>	cache(new Internals::Cache(name, documentType, relevantProperties, valueInfos, 0));

	// Add to maps
	mInternals->mCacheByName.set(name, cache);
	mInternals->mCachesByDocumentType.add(documentType, cache);

	// Bring up to date
	mInternals->cacheUpdate(cache, mInternals->getUpdateInfos(documentType, documentCreateInfo(documentType), 0));

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSEphemeralDocumentBacking

class CMDSEphemeralDocumentBacking {
	public:
				CMDSEphemeralDocumentBacking(UInt32 revision, UniversalTime creationUniversalTime,
						UniversalTime modificationUniversalTime, const CDictionary& propertyMap) :
					mCreationUniversalTime(creationUniversalTime), mRevision(revision),
							mModificationUniversalTime(modificationUniversalTime), mPropertyMap(propertyMap),
							mActive(true)
					{}

		void	update(UInt32 revision, const CDictionary& updatedPropertyMap, const TSet<CString>& removedProperties)
					{
						// Update
						mRevision = revision;
						mModificationUniversalTime = SUniversalTime::getCurrent();
						mPropertyMap += updatedPropertyMap;
						mPropertyMap.remove(removedProperties);
					}

		UInt32			mRevision;
		UniversalTime	mCreationUniversalTime;
		UniversalTime	mModificationUniversalTime;
		CDictionary		mPropertyMap;
		bool			mActive;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - Types

typedef	TMDSBatch<CDictionary>										CMDSEphemeralBatch;
typedef	CMDSEphemeralBatch::DocumentInfo							CMDSEphemeralBatchDocumentInfo;

typedef	TMDSCollection<CString, TNArray<CString> >					CMDSEphemeralCollection;
typedef	CMDSEphemeralCollection::UpdateResults<TNArray<CString> >	CMDSEphemeralCollectionUpdateResults;

typedef	TMDSIndex<CString>											CMDSEphemeralIndex;
typedef	CMDSEphemeralIndex::UpdateInfo<CString>						CMDSEphemeralIndexUpdateInfo;

typedef	TMDSUpdateInfo<CString>										CMDSEphemeralUpdateInfo;

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSEphemeralInternals

class CMDSEphemeralInternals {
	public:
		// Types
		struct UpdateIndexValuesInfo {
			// Lifecycle methods
			UpdateIndexValuesInfo(const CMDSEphemeralIndexUpdateInfo& updateInfo, const TSet<CString>& documentIDs) :
				mUpdateInfo(updateInfo), mDocumentIDs(documentIDs)
				{}

			// Properties
			const	CMDSEphemeralIndexUpdateInfo&	mUpdateInfo;
			const	TSet<CString>&					mDocumentIDs;
		};

struct AssociationPair {
	// Lifecycle methods
	AssociationPair(const CString& fromDocumentID, const CString& toDocumentID) :
		mFromDocumentID(fromDocumentID), mToDocumentID(toDocumentID)
		{}
	AssociationPair(const AssociationPair& other) :
		mFromDocumentID(other.mFromDocumentID), mToDocumentID(other.mToDocumentID)
		{}

	// Properties
	CString	mFromDocumentID;
	CString	mToDocumentID;
};

											// Methods
											CMDSEphemeralInternals(const CMDSEphemeral& mdsEphemeral) :
												mMDSEphemeral(mdsEphemeral), mID(CUUID().getBase64String())
												{}

				UInt32						getNextRevision(const CString& documentType);

				void						updateCollections(const CString& documentType,
													const TArray<CMDSEphemeralUpdateInfo>& updateInfos);
				void						updateCollections(const TSet<CString>& removedDocumentIDs);

				void						updateIndexes(const CString& documentType,
													const TArray<CMDSEphemeralUpdateInfo>& updateInfos);
				void						updateIndexes(const TSet<CString>& removedDocumentIDs);

				void						notifyDocumentChanged(const CString& documentType,
													const CMDSDocument& document, CMDSDocument::ChangeKind changeKind);

		static	OV<TSet<CString> >			updateCollectionValues(const OR<TNSet<CString> >& currentValues,
													const CMDSEphemeralCollectionUpdateResults* updateResults);
		static	OV<TSet<CString> >			removeCollectionValues(const OR<TNSet<CString> >& currentValues,
													const TSet<CString>* documentIDs);
		static	OV<TDictionary<CString> >	updateIndexValues(const OR<TDictionary<CString> >& currentValue,
													const UpdateIndexValuesInfo* updateIndexValuesInfo);
		static	OV<TDictionary<CString> >	removeIndexValues(const OR<TDictionary<CString> >& currentValue,
													const TSet<CString>* documentIDs);
		static	CString						getValueFromKeysInfo(CMDSEphemeralIndex::KeysInfo<CString>* keysInfo);
		static	bool						isItemNotInSet(const CDictionary::Item& item, const TSet<CString>* strings);
		static	bool						isDocumentActive(const CString& documentID,
													const TNDictionary<CMDSEphemeralDocumentBacking>*
															documentBackingByIDMap);
		static	const	OV<SValue>			getDocumentBackingPropertyValue(const CString& documentID,
													const CString& property, CMDSEphemeralInternals* internals);
		static	OV<SError>					batchMap(const CString& documentType,
													const TDictionary<CMDSEphemeralBatchDocumentInfo >&
															documentInfosMap,
													CMDSEphemeralInternals* internals);

		const	CMDSEphemeral&											mMDSEphemeral;

				CString													mID;
				TNDictionary<CString>									mInfo;

				TNLockingDictionary<CMDSEphemeralBatch>					mBatchMap;

				TNDictionary<CMDSEphemeralDocumentBacking>				mDocumentBackingByIDMap;
				TNLockingArrayDictionary<CMDSDocument::ChangedProcInfo>	mDocumentChangedProcInfosMap;
				TNDictionary<TNSet<CString> >							mDocumentIDsByTypeMap;
				TNLockingDictionary<CMDSDocument::Info>					mDocumentInfoMap;
				CDictionary												mDocumentLastRevisionByDocumentType;
				CLock													mDocumentLastRevisionByDocumentTypeLock;
				CReadPreferringLock										mDocumentMapsLock;
				TNLockingDictionary<CDictionary>						mDocumentsBeingCreatedPropertyMapMap;

/*
	Name:
->		Pairs of (from, to)
			-or-
		From
			array of to
*/
TNArrayDictionary<AssociationPair>	mAssociationMap;
CLock								mAssociationMapLock;

				TNLockingDictionary<CMDSEphemeralCollection>			mCollectionsByNameMap;
				TNLockingArrayDictionary<CMDSEphemeralCollection>		mCollectionsByDocumentTypeMap;
				TNLockingDictionary<TNSet<CString> >					mCollectionValuesMap;

				TNLockingDictionary<CMDSEphemeralIndex>					mIndexesByNameMap;
				TNLockingArrayDictionary<CMDSEphemeralIndex>			mIndexesByDocumentTypeMap;
				TNLockingDictionary<TDictionary<CString> >				mIndexValuesMap;
};

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSEphemeralInternals::getNextRevision(const CString& documentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Compose next revision
	mDocumentLastRevisionByDocumentTypeLock.lock();
	UInt32	nextRevision = mDocumentLastRevisionByDocumentType.getUInt32(documentType, 0) + 1;
	mDocumentLastRevisionByDocumentType.set(documentType, nextRevision);
	mDocumentLastRevisionByDocumentTypeLock.unlock();

	return nextRevision;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeralInternals::updateCollections(const CString& documentType,
		const TArray<CMDSEphemeralUpdateInfo>& updateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve collections for this document type
	OR<TNArray<CMDSEphemeralCollection> >	collections = mCollectionsByDocumentTypeMap[documentType];
	if (!collections.hasReference()) return;

	// Iterate collections
	for (TIteratorD<CMDSEphemeralCollection> iterator = collections->getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Query update info
		CMDSEphemeralCollectionUpdateResults	updateResults = iterator->update(updateInfos);

		// Update storage
		mCollectionValuesMap.update(iterator->getName(),
				(TNLockingDictionary<TNSet<CString> >::UpdateProc) updateCollectionValues, &updateResults);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeralInternals::updateCollections(const TSet<CString>& removedDocumentIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate collection names
	TSet<CString>	collectionNames = mCollectionValuesMap.getKeys();
	for (TIteratorS<CString> iterator = collectionNames.getIterator(); iterator.hasValue(); iterator.advance())
		// Remove documents from this collection
		mCollectionValuesMap.update(*iterator,
				(TNLockingDictionary<TNSet<CString> >::UpdateProc) CMDSEphemeralInternals::removeCollectionValues,
				(TSet<CString>*) &removedDocumentIDs);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeralInternals::updateIndexes(const CString& documentType,
		const TArray<CMDSEphemeralUpdateInfo>& updateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve indexes for this document type
	OR<TNArray<CMDSEphemeralIndex> >	indexes = mIndexesByDocumentTypeMap.get(documentType);
	if (!indexes.hasReference()) return;

	// Iterate indexes
	for (TIteratorD<CMDSEphemeralIndex> iterator = indexes->getIterator(); iterator.hasValue(); iterator.advance()) {
		// Query update info
		CMDSEphemeralIndexUpdateInfo	updateInfo = iterator->update(updateInfos);
		if (updateInfo.mKeysInfos.isEmpty()) continue;

		// Update storage
		TNSet<CString>	documentIDs(updateInfo.mKeysInfos, (CString (*)(CArray::ItemRef)) getValueFromKeysInfo);
		UpdateIndexValuesInfo	updateIndexValueInfos(updateInfo, documentIDs);
		mIndexValuesMap.update(documentType, (TNLockingDictionary<TDictionary<CString> >::UpdateProc) updateIndexValues,
				&updateIndexValueInfos);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeralInternals::updateIndexes(const TSet<CString>& removedDocumentIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate index names
	TSet<CString>	indexNames = mIndexValuesMap.getKeys();
	for (TIteratorS<CString> iterator = indexNames.getIterator(); iterator.hasValue(); iterator.advance())
		// Remove document from this index
		mIndexValuesMap.update(*iterator,
				(TNLockingDictionary<TDictionary<CString> >::UpdateProc) CMDSEphemeralInternals::removeIndexValues,
				(TSet<CString>*) &removedDocumentIDs);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeralInternals::notifyDocumentChanged(const CString& documentType, const CMDSDocument& document,
		CMDSDocument::ChangeKind changeKind)
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve proc info array
	OR<TNArray<CMDSDocument::ChangedProcInfo> >	array = mDocumentChangedProcInfosMap.get(documentType);
	if (array.hasReference())
		// Iterate all proc infos
		for (TIteratorD<CMDSDocument::ChangedProcInfo> iterator = array->getIterator(); iterator.hasValue();
				iterator.advance())
			// Call proc
			iterator->notify(document, changeKind);
}

// MARK: Class methods

//----------------------------------------------------------------------------------------------------------------------
OV<TSet<CString> > CMDSEphemeralInternals::updateCollectionValues(const OR<TNSet<CString> >& currentValues,
		const CMDSEphemeralCollectionUpdateResults* updateResults)
//----------------------------------------------------------------------------------------------------------------------
{
//	// Check if have current values
//	TNSet<CString>	updatedValues;
//	if (currentValues.hasReference())
//		// Have current values
//		updatedValues =
//				currentValues->removeFrom(updateResults->mNotIncludedIDs).insertFrom(updateResults->mIncludedIDs);
//	else
//		// Don't have current values
//		updatedValues = TNSet<CString>(updateResults->mIncludedIDs);
//
//	return !updatedValues.isEmpty() ? OV<TSet<CString> >(updatedValues) : OV<TSet<CString> >();
return OV<TSet<CString> >();
}

//----------------------------------------------------------------------------------------------------------------------
OV<TSet<CString> > CMDSEphemeralInternals::removeCollectionValues(const OR<TNSet<CString> >& currentValues,
		const TSet<CString>* documentIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if have current values
	TNSet<CString>	updatedValues;
	if (currentValues.hasReference())
		// Have current values
		updatedValues = currentValues->removeFrom(*documentIDs);

	return !updatedValues.isEmpty() ? OV<TSet<CString> >(updatedValues) : OV<TSet<CString> >();
}

//----------------------------------------------------------------------------------------------------------------------
OV<TDictionary<CString> > CMDSEphemeralInternals::updateIndexValues(const OR<TDictionary<CString> >& currentValue,
		const UpdateIndexValuesInfo* updateIndexValuesInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Filter out document IDs not included in update
	TNDictionary<CString>	updatedValues(currentValue.hasReference() ? *currentValue : TNDictionary<CString>(),
									(CDictionary::Item::IncludeProc) isItemNotInSet,
									(void*) &updateIndexValuesInfo->mDocumentIDs);

	// Add/Update keys => document IDs
	for (TIteratorD<CMDSEphemeralIndex::KeysInfo<CString> > keysInfoIterator =
					updateIndexValuesInfo->mUpdateInfo.mKeysInfos.getIterator();
			keysInfoIterator.hasValue(); keysInfoIterator.advance()) {
		// Iterate all keys
		for (TIteratorD<CString> keyIterator = keysInfoIterator->mKeys.getIterator(); keyIterator.hasValue();
				keyIterator.advance())
			// Update dictionary
			updatedValues.set(*keyIterator, keysInfoIterator->mValue);
	}

	return !updatedValues.isEmpty() ? OV<TDictionary<CString> >(updatedValues) : OV<TDictionary<CString> >();
}

//----------------------------------------------------------------------------------------------------------------------
OV<TDictionary<CString> > CMDSEphemeralInternals::removeIndexValues(const OR<TDictionary<CString> >& currentValue,
		const TSet<CString>* documentIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Filter out document ID
	TNDictionary<CString>	updatedValues(currentValue.hasReference() ? *currentValue : TNDictionary<CString>(),
									(CDictionary::Item::IncludeProc) isItemNotInSet, (void*) documentIDs);

	return !updatedValues.isEmpty() ? OV<TDictionary<CString> >(updatedValues) : OV<TDictionary<CString> >();
}

//----------------------------------------------------------------------------------------------------------------------
CString CMDSEphemeralInternals::getValueFromKeysInfo(CMDSEphemeralIndex::KeysInfo<CString>* keysInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	return keysInfo->mValue;
}

//----------------------------------------------------------------------------------------------------------------------
bool CMDSEphemeralInternals::isItemNotInSet(const CDictionary::Item& item, const TSet<CString>* strings)
//----------------------------------------------------------------------------------------------------------------------
{
	return !strings->contains(item.mValue.getString());
}

//----------------------------------------------------------------------------------------------------------------------
bool CMDSEphemeralInternals::isDocumentActive(const CString& documentID,
		const TNDictionary<CMDSEphemeralDocumentBacking>* documentBackingByIDMap)
//----------------------------------------------------------------------------------------------------------------------
{
	return (*documentBackingByIDMap)[documentID]->mActive;
}

//----------------------------------------------------------------------------------------------------------------------
const OV<SValue> CMDSEphemeralInternals::getDocumentBackingPropertyValue(const CString& documentID,
		const CString& property, CMDSEphemeralInternals* internals)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	internals->mDocumentMapsLock.lockForReading();
	const	OR<CMDSEphemeralDocumentBacking>	documentBacking = internals->mDocumentBackingByIDMap[documentID];
	const	OV<SValue>							value =
														documentBacking.hasReference() ?
																OV<SValue>(
																		documentBacking->mPropertyMap.getValue(
																				property)) :
																OV<SValue>();
	internals->mDocumentMapsLock.unlockForReading();

	return value;
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSEphemeralInternals::batchMap(const CString& documentType,
		const TDictionary<CMDSEphemeralBatchDocumentInfo >& documentInfosMap, CMDSEphemeralInternals* internals)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<CMDSDocument::Info>&				documentInfo = internals->mDocumentInfoMap[documentType];
			TNArray<I<CMDSDocument> >			documents;
			TNArray<CMDSEphemeralUpdateInfo>	updateInfos;
			TNSet<CString>						removedDocumentIDs;

	// Prepare for write
	internals->mDocumentMapsLock.lockForWriting();

	// Update documents
	for (TIteratorS<CDictionary::Item> iterator = documentInfosMap.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Setup
		const	CString&							documentID = iterator->mKey;
		const	CMDSEphemeralBatchDocumentInfo&		batchDocumentInfo =
															*((CMDSEphemeralBatchDocumentInfo*)
																	iterator->mValue.getOpaque());
		const	OR<CMDSEphemeralDocumentBacking>&	existingDocumentBacking =
															internals->mDocumentBackingByIDMap[documentID];

		// Check removed
		if (!batchDocumentInfo.isRemoved()) {
			// Add/update document
			if (existingDocumentBacking.hasReference()) {
				// Update document backing
				existingDocumentBacking->update(internals->getNextRevision(documentType),
						batchDocumentInfo.getUpdatedPropertyMap(), batchDocumentInfo.getRemovedProperties());

				// Check if we have document info
				if (documentInfo.hasReference()) {
					// Create document
					CMDSDocument*	document =
											documentInfo->create(documentID,
													*((CMDSEphemeral*) &internals->mMDSEphemeral));
					documents += I<CMDSDocument>(document);

					// Update collections and indexes
					TNSet<CString>	changedProperties = batchDocumentInfo.getUpdatedPropertyMap().getKeys();
					changedProperties.insertFrom(batchDocumentInfo.getRemovedProperties());
					updateInfos +=
							CMDSEphemeralUpdateInfo(*document, existingDocumentBacking->mRevision, documentID,
									changedProperties);

					// Call document changed procs
					internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kChangeKindUpdated);
				}
			} else {
				// Add document
				CMDSEphemeralDocumentBacking	documentBacking(internals->getNextRevision(documentType),
														batchDocumentInfo.getCreationUniversalTime(),
														batchDocumentInfo.getModificationUniversalTime(),
														batchDocumentInfo.getUpdatedPropertyMap());
				internals->mDocumentBackingByIDMap.set(documentID, documentBacking);

				OR<TNSet<CString> >	set = internals->mDocumentIDsByTypeMap.get(documentType);
				if (set.hasReference())
					set->insert(documentID);
				else
					internals->mDocumentIDsByTypeMap.set(documentType, TNSet<CString>(documentID));

				// Check if we have document info
				if (documentInfo.hasReference()) {
					// Create document
					CMDSDocument*	document =
											documentInfo->create(documentID,
													*((CMDSDocumentStorage*) &internals->mMDSEphemeral));
					documents += I<CMDSDocument>(document);

					// Update collections and indexes
					updateInfos += CMDSEphemeralUpdateInfo(*document, documentBacking.mRevision, documentID);

					// Call document changed procs
					internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kChangeKindUpdated);
				}
			}
		} else {
			// Remove document
			removedDocumentIDs += documentID;

			// Check if have existing document backing
			if (existingDocumentBacking.hasReference()) {
				// Update document backing
				existingDocumentBacking->mActive = false;

				// Check if we have document info
				if (documentInfo.hasReference()) {
					// Create document
					CMDSDocument*	document =
											documentInfo->create(documentID,
													*((CMDSDocumentStorage*) &internals->mMDSEphemeral));
					documents += I<CMDSDocument>(document);

					// Call document changed procs
					internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kChangeKindRemoved);
				}
			}
		}
	}

	// Done
	internals->mDocumentMapsLock.unlockForWriting();

	// Update collections and indexes
	internals->updateCollections(removedDocumentIDs);
	internals->updateCollections(documentType, updateInfos);
	internals->updateIndexes(removedDocumentIDs);
	internals->updateIndexes(documentType, updateInfos);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSEphemeral

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSEphemeral::CMDSEphemeral()
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = new CMDSEphemeralInternals(*this);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSEphemeral::~CMDSEphemeral()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: CMDSDocumentStorage methods

//----------------------------------------------------------------------------------------------------------------------
const CString& CMDSEphemeral::getID() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mID;
}

//----------------------------------------------------------------------------------------------------------------------
TDictionary<CString> CMDSEphemeral::getInfo(const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	TNDictionary<CString>	info;
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.advance(); iterator.hasValue()) {
		// Check if have key
		if (mInternals->mInfo.contains(*iterator))
			// Have key
			info.set(*iterator, mInternals->mInfo.getString(*iterator));
	}

	return info;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::set(const TDictionary<CString>& info)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate all info
	for (TIteratorS<CDictionary::Item> iterator = info.getIterator(); iterator.hasValue(); iterator.advance())
		// Update
		mInternals->mInfo.set(iterator->mKey, iterator->mValue.getString());
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::remove(const TArray<CString>& keys)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate all keys
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.advance(); iterator.hasValue())
		// Remove
		mInternals->mInfo.remove(*iterator);
}

//----------------------------------------------------------------------------------------------------------------------
I<CMDSDocument> CMDSEphemeral::newDocument(const CMDSDocument::InfoForNew& infoForNew)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CString			documentID = CUUID().getBase64String();
	UniversalTime	universalTime = SUniversalTime::getCurrent();

	// Check for batch
	const	OR<CMDSEphemeralBatch>	batch = mInternals->mBatchMap[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		batch->addDocument(infoForNew.getDocumentType(), documentID, universalTime, universalTime);

		return I<CMDSDocument>(infoForNew.create(documentID, *this));
	} else {
		// Will be creating document
		mInternals->mDocumentsBeingCreatedPropertyMapMap.set(documentID, CDictionary());

		// Create
		CMDSDocument*	document = infoForNew.create(documentID, *this);

		// Remove property map
		CDictionary	propertyMap = *mInternals->mDocumentsBeingCreatedPropertyMapMap.get(documentID);
		mInternals->mDocumentsBeingCreatedPropertyMapMap.remove(documentID);

		// Add document
		CMDSEphemeralDocumentBacking	documentBacking(mInternals->getNextRevision(infoForNew.getDocumentType()),
												universalTime, universalTime, propertyMap);

		// Update maps
		mInternals->mDocumentMapsLock.lockForWriting();

		mInternals->mDocumentBackingByIDMap.set(documentID, documentBacking);

		OR<TNSet<CString> >	set = mInternals->mDocumentIDsByTypeMap.get(infoForNew.getDocumentType());
		if (set.hasReference())
			// Already have a document for this type
			set->insert(documentID);
		else
			// First document for this type
			mInternals->mDocumentIDsByTypeMap.set(infoForNew.getDocumentType(), TNSet<CString>(documentID));

		mInternals->mDocumentMapsLock.unlockForWriting();

		// Update collections and indexes
		CMDSEphemeralUpdateInfo	updateInfo(*document, documentBacking.mRevision, documentID);
		mInternals->updateCollections(infoForNew.getDocumentType(), TSArray<CMDSEphemeralUpdateInfo>(updateInfo));
		mInternals->updateIndexes(infoForNew.getDocumentType(), TSArray<CMDSEphemeralUpdateInfo>(updateInfo));

		// Call document changed procs
		mInternals->notifyDocumentChanged(infoForNew.getDocumentType(), *document, CMDSDocument::kChangeKindCreated);

		return I<CMDSDocument>(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt32> CMDSEphemeral::getDocumentCount(const CMDSDocument::Info& documentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect document IDs
	mInternals->mDocumentMapsLock.lockForReading();
	const	OR<TNSet<CString> >	documentIDs = mInternals->mDocumentIDsByTypeMap[documentInfo.getDocumentType()];
			OV<UInt32>			documentCount =
										documentIDs.hasReference() ? OV<UInt32>(documentIDs->getCount()) : OV<UInt32>();
	mInternals->mDocumentMapsLock.unlockForReading();

	return documentCount;
}

//----------------------------------------------------------------------------------------------------------------------
OI<CMDSDocument> CMDSEphemeral::getDocument(const CString& documentID, const CMDSDocument::Info& documentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	return OI<CMDSDocument>(documentInfo.create(documentID, (CMDSDocumentStorage&) *this));
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSEphemeral::getCreationUniversalTime(const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<CMDSEphemeralBatch>				batch = mInternals->mBatchMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo =
														batch.hasReference() ?
																batch->getDocumentInfo(document.getID()) :
																OR<CMDSEphemeralBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getCreationUniversalTime();
	else if (mInternals->mDocumentsBeingCreatedPropertyMapMap[document.getID()].hasReference())
		// Being created
		return SUniversalTime::getCurrent();
	else {
		// "Idle"
		mInternals->mDocumentMapsLock.lockForReading();
		const	OR<CMDSEphemeralDocumentBacking>	documentBacking =
															mInternals->mDocumentBackingByIDMap[document.getID()];
				UniversalTime						universalTime =
															documentBacking.hasReference() ?
																	documentBacking->mCreationUniversalTime :
																	SUniversalTime::getCurrent();
		mInternals->mDocumentMapsLock.unlockForReading();

		return universalTime;
	}
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSEphemeral::getModificationUniversalTime(const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<CMDSEphemeralBatch>				batch = mInternals->mBatchMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo =
														batch.hasReference() ?
																batch->getDocumentInfo(document.getID()) :
																OR<CMDSEphemeralBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getModificationUniversalTime();
	else if (mInternals->mDocumentsBeingCreatedPropertyMapMap[document.getID()].hasReference())
		// Being created
		return SUniversalTime::getCurrent();
	else {
		// "Idle"
		mInternals->mDocumentMapsLock.lockForReading();
		const	OR<CMDSEphemeralDocumentBacking>	documentBacking =
															mInternals->mDocumentBackingByIDMap[document.getID()];
				UniversalTime						universalTime =
															documentBacking.hasReference() ?
																	documentBacking->mModificationUniversalTime :
																	SUniversalTime::getCurrent();
		mInternals->mDocumentMapsLock.unlockForReading();

		return universalTime;
	}
}

//----------------------------------------------------------------------------------------------------------------------
OV<SValue> CMDSEphemeral::getValue(const CString& property, const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<CMDSEphemeralBatch>				batch = mInternals->mBatchMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo =
														batch.hasReference() ?
																batch->getDocumentInfo(document.getID()) :
																OR<CMDSEphemeralBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// In batch
		return batchDocumentInfo->getValue(property);

	// Check if being created
	const	OR<CDictionary>	propertyMap = mInternals->mDocumentsBeingCreatedPropertyMapMap[document.getID()];
	if (propertyMap.hasReference())
		// Being created
		return propertyMap->contains(property) ? OV<SValue>(propertyMap->getValue(property)) : OV<SValue>();

	// "Idle"
	mInternals->mDocumentMapsLock.lockForReading();
	const	OR<CMDSEphemeralDocumentBacking>	documentBacking =
														mInternals->mDocumentBackingByIDMap[document.getID()];
			OV<SValue>							value =
														(documentBacking.hasReference() &&
																	documentBacking->mPropertyMap.contains(property)) ?
																OV<SValue>(
																		documentBacking->mPropertyMap.getValue(
																				property)) :
																OV<SValue>();
	mInternals->mDocumentMapsLock.unlockForReading();

	return value;
}

//----------------------------------------------------------------------------------------------------------------------
OV<CData> CMDSEphemeral::getData(const CString& property, const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = getValue(property, document);

	return value.hasValue() ? OV<CData>(value->getData()) : OV<CData>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<UniversalTime> CMDSEphemeral::getUniversalTime(const CString& property, const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = getValue(property, document);

	return value.hasValue() ? OV<UniversalTime>(value->getFloat64()) : OV<UniversalTime>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::set(const CString& property, const OV<SValue>& value, const CMDSDocument& document,
		SetValueInfo setValueInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	CString&	documentType = document.getDocumentType();
	const	CString&	documentID = document.getID();

	// Check for batch
	const	OR<CMDSEphemeralBatch>	batch = mInternals->mBatchMap[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo = batch->getDocumentInfo(documentID);
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->set(property, value);
		else {
			// Don't have document in batch
			UniversalTime	universalTime = SUniversalTime::getCurrent();
			batch->addDocument(documentType, documentID, OI<CDictionary>(CDictionary()), universalTime,
					universalTime,
					(CMDSEphemeralBatch::DocumentPropertyValueProc)
							CMDSEphemeralInternals::getDocumentBackingPropertyValue, mInternals)
				.set(property, value);
		}

		return;
	}

	// Check if being created
	const	OR<CDictionary>	propertyMap = mInternals->mDocumentsBeingCreatedPropertyMapMap[documentID];
	if (propertyMap.hasReference())
		// Being created
		propertyMap->set(property, value);
	else {
		// Update document
		mInternals->mDocumentMapsLock.lockForWriting();
		const	OR<CMDSEphemeralDocumentBacking>	documentBacking = mInternals->mDocumentBackingByIDMap[documentID];
		documentBacking->mPropertyMap.set(property, value);
		mInternals->mDocumentMapsLock.unlockForWriting();

		// Update collections and indexes
		CMDSEphemeralUpdateInfo	updateInfo(document, documentBacking->mRevision, documentID);
		mInternals->updateCollections(documentType, TSArray<CMDSEphemeralUpdateInfo>(updateInfo));
		mInternals->updateIndexes(documentType, TSArray<CMDSEphemeralUpdateInfo>(updateInfo));

		// Call document changed procs
		mInternals->notifyDocumentChanged(documentType, document, CMDSDocument::kChangeKindUpdated);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::remove(const CMDSDocument& document)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	CString&	documentType = document.getDocumentType();
	const	CString&	documentID = document.getID();

	// Check for batch
	const	OR<CMDSEphemeralBatch>	batch = mInternals->mBatchMap[CThread::getCurrentRefAsString()];
	if (batch.hasReference()) {
		// In batch
		const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo = batch->getDocumentInfo(documentID);
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->remove();
		else {
			// Don't have document in batch
			UniversalTime	universalTime = SUniversalTime::getCurrent();
			batch->addDocument(documentType, documentID, universalTime, universalTime).remove();
		}
	} else {
		// Not in batch
		mInternals->mDocumentMapsLock.lockForWriting();
		const	OR<CMDSEphemeralDocumentBacking>	documentBacking = mInternals->mDocumentBackingByIDMap[documentID];
		if (documentBacking.hasReference())
			// Reset active
			documentBacking->mActive = false;
		mInternals->mDocumentMapsLock.unlockForWriting();

		// Remove from collections and indexes
		TNSet<CString>	documentIDs(documentID);
		mInternals->updateCollections(documentIDs);
		mInternals->updateIndexes(documentIDs);

		// Call document changed procs
		mInternals->notifyDocumentChanged(documentType, document, CMDSDocument::kChangeKindRemoved);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterate(const CMDSDocument::Info& documentInfo, CMDSDocument::Proc proc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect document IDs
	mInternals->mDocumentMapsLock.lockForReading();
	const	OR<TNSet<CString> >	documentIDs = mInternals->mDocumentIDsByTypeMap[documentInfo.getDocumentType()];
			TNSet<CString>		filteredDocumentIDs(
										documentIDs.hasReference() ? *documentIDs : TNSet<CString>(),
												(TSet<CString>::IsIncludedProc)
														CMDSEphemeralInternals::isDocumentActive,
										&mInternals->mDocumentBackingByIDMap);
	mInternals->mDocumentMapsLock.unlockForReading();

	// Iterate document IDs
	for (TIteratorS<CString> iterator = filteredDocumentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Create document
		CMDSDocument*	document = documentInfo.create(*iterator, *((CMDSDocumentStorage*) this));

		// Call proc
		proc(*document, userData);

		// Cleanup
		Delete(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterate(const CMDSDocument::Info& documentInfo, const TArray<CString>& documentIDs,
		CMDSDocument::Proc proc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate document IDs
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Create document
		CMDSDocument*	document = documentInfo.create(*iterator, *this);

		// Call proc
		proc(*document, userData);

		// Cleanup
		Delete(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::batch(BatchProc batchProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CMDSEphemeralBatch	batch;

	// Store
	mInternals->mBatchMap.set(CThread::getCurrentRefAsString(), batch);

	// Call proc
	BatchResult	batchResult = batchProc(userData);

	// Remove
	mInternals->mBatchMap.remove(CThread::getCurrentRefAsString());

	// Check result
	if (batchResult == kCommit)
		// Iterate all document changes
		batch.iterate((CMDSEphemeralBatchDocumentInfo::MapProc) CMDSEphemeralInternals::batchMap, mInternals);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::registerAssociation(const CString& name, const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument::Info& toDocumenInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Ensure this association has not already been registered
//	if (mInternals->mAssocationMap.contains(name)) return;

	// Create assocation
// ???
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::updateAssociation(const CString& name, const TArray<AssociationUpdate>& updates)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate updates
	mInternals->mAssociationMapLock.lock();
	for (TIteratorD<AssociationUpdate> iterator = updates.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check action
		if (iterator->mAction == AssociationUpdate::kAdd)
			// Add
			mInternals->mAssociationMap.add(name,
					CMDSEphemeralInternals::AssociationPair(iterator->mFromDocument.getID(),
							iterator->mToDocument.getID()));
//		else
//			// Remove
	}
	mInternals->mAssociationMapLock.unlock();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterateAssociationFrom(const CString& name, const CMDSDocument& fromDocument,
		const CMDSDocument::Info& toDocumentInfo, CMDSDocument::Proc proc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve association pairs
	mInternals->mAssociationMapLock.lock();
	OR<TNArray<CMDSEphemeralInternals::AssociationPair> >	associationPairs = mInternals->mAssociationMap.get(name);
	if (associationPairs.hasReference()) {
		// Iterate results
		for (TIteratorD<CMDSEphemeralInternals::AssociationPair> iterator = associationPairs->getIterator();
				iterator.hasValue(); iterator.advance()) {
			// Check document ID
			if (iterator->mFromDocumentID == fromDocument.getID()) {
				// Create
				CMDSDocument*	document = toDocumentInfo.create(iterator->mToDocumentID, *this);

				// Call proc
				proc(*document, userData);

				// Cleanup
				Delete(document);
			}
		}
	}
	mInternals->mAssociationMapLock.unlock();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterateAssociationTo(const CString& name, const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument& toDocument, CMDSDocument::Proc proc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve association pairs
	mInternals->mAssociationMapLock.lock();
	OR<TNArray<CMDSEphemeralInternals::AssociationPair> >	associationPairs = mInternals->mAssociationMap.get(name);
	if (associationPairs.hasReference()) {
		// Iterate results
		for (TIteratorD<CMDSEphemeralInternals::AssociationPair> iterator = associationPairs->getIterator();
				iterator.hasValue(); iterator.advance()) {
			// Check document ID
			if (iterator->mToDocumentID == toDocument.getID()) {
				// Create
				CMDSDocument*	document = fromDocumentInfo.create(iterator->mFromDocumentID, *this);

				// Call proc
				proc(*document, userData);

				// Cleanup
				Delete(document);
			}
		}
	}
	mInternals->mAssociationMapLock.unlock();
}

////----------------------------------------------------------------------------------------------------------------------
//SValue CMDSEphemeral::retrieveAssociationValue(const CString& name, const CString& fromDocumentType,
//		const CMDSDocument& toDocument, const CString& summedCachedValueName)
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//
//	return SValue(false);
//}
//
////----------------------------------------------------------------------------------------------------------------------
//void CMDSEphemeral::registerCache(const CString& name, const CMDSDocument::Info& documentInfo, UInt32 version,
//		const TArray<CString>& relevantProperties, const TArray<CacheValueInfo>& cacheValueInfos)
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::registerCollection(const CString& name, const CMDSDocument::Info& documentInfo, UInt32 version,
		const TArray<CString>& relevantProperties, bool isUpToDate, const CString& isIncludedSelector,
		const CDictionary& isIncludedSelectorInfo, CMDSDocument::IsIncludedProc isIncludedProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
//	// Ensure this collectino has not already been registered
//	if (mInternals->mCollectionsByNameMap.contains(name)) return;
//
//	// Create collection
//	CMDSEphemeralCollection	collection(name, documentInfo.getDocumentType(), relevantProperties, isIncludedProc,
//									userData, userData, isIncludedSelectorInfo, 0);
//
//	// Add to maps
//	mInternals->mCollectionsByNameMap.set(name, collection);
//	mInternals->mCollectionsByDocumentTypeMap.add(documentInfo.getDocumentType(), collection);
//
//	// Update creation proc map
//	mInternals->mDocumentInfoMap.set(documentInfo.getDocumentType(), documentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSEphemeral::getCollectionDocumentCount(const CString& name) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get values
	const	OR<TNSet<CString> >	values = mInternals->mCollectionValuesMap[name];

	return values.hasReference() ? values->getCount() : 0;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterateCollection(const CString& name, const CMDSDocument::Info& documentInfo,
		CMDSDocument::Proc proc, void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get values
	const	OR<TNSet<CString> >	values = mInternals->mCollectionValuesMap[name];
	if (!values.hasReference()) return;

	// Iterate values
	for (TIteratorS<CString> iterator = values->getIterator(); iterator.hasValue(); iterator.advance()) {
		// Create doc
		CMDSDocument*	document = documentInfo.create(*iterator, *((CMDSDocumentStorage*) this));

		// Call proc
		proc(*document, userData);

		// Cleanup
		Delete(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::registerIndex(const CString& name, const CMDSDocument::Info& documentInfo, UInt32 version,
		const TArray<CString>& relevantProperties, bool isUpToDate, const CString& keysSelector,
		const CDictionary& keysSelectorInfo, CMDSDocument::KeysProc keysProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Ensure this index has not already been registered
	if (mInternals->mIndexesByNameMap.contains(name)) return;

	// Create index
	CMDSEphemeralIndex	index(name, documentInfo.getDocumentType(), relevantProperties, 0, keysProc, userData);

	// Add to maps
	mInternals->mIndexesByNameMap.set(name, index);
	mInternals->mIndexesByDocumentTypeMap.add(documentInfo.getDocumentType(), index);

	// Update creation proc map
	mInternals->mDocumentInfoMap.set(documentInfo.getDocumentType(), documentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterateIndex(const CString& name, const TArray<CString>& keys,
		const CMDSDocument::Info& documentInfo, CMDSDocument::KeyProc keyProc, void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get values
	const	OR<TDictionary<CString> >	values = mInternals->mIndexValuesMap[name];
	if (!values.hasReference()) return;

	// Iterate keys
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Retrieve documentID
		const	OR<CString>	documentID = (*values)[*iterator];
		if (documentID.hasReference()) {
			// Create doc
			CMDSDocument*	document = documentInfo.create(*iterator, *((CMDSDocumentStorage*) this));

			// Call proc
			keyProc(*iterator, *document, userData);

			// Cleanup
			Delete(document);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::registerDocumentChangedProc(const CString& documentType, CMDSDocument::ChangedProc changedProc,
		void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentChangedProcInfosMap.add(documentType, CMDSDocument::ChangedProcInfo(changedProc, userData));
}
