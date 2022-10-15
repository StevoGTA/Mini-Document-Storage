//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLite.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSSQLite.h"

#include "CMDSSQLiteDatabaseManager.h"
#include "CMDSSQLiteDocumentBacking.h"
#include "CThread.h"
#include "CUUID.h"
#include "TBatchQueue.h"
#include "TLockingDictionary.h"
#include "TMDSDocumentBackingCache.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Types

typedef	TMDSBatchInfo<CMDSSQLiteDocumentBacking>						CMDSSQLiteBatchInfo;
typedef	CMDSSQLiteBatchInfo::DocumentInfo<CMDSSQLiteDocumentBacking>	CMDSSQLiteBatchDocumentInfo;

typedef	CMDSSQLiteCollection::UpdateInfo<TNumberArray<SInt64> >			CMDSSQLiteCollectionUpdateInfo;

typedef	TMDSDocumentBackingCache<CMDSSQLiteDocumentBacking>				CMDSSQLiteDocumentBackingCache;
typedef	CMDSDocument::BackingInfo<CMDSSQLiteDocumentBacking>			CMDSSQLiteDocumentBackingInfo;

typedef	TMDSUpdateInfo<SInt64>											CMDSSQLiteUpdateInfo;
typedef	TMDSBringUpToDateInfo<SInt64>									CMDSSQLiteBringUpToDateInfo;

typedef	CMDSSQLiteDatabaseManager::ExistingDocumentInfo					ExistingDocumentInfo;

typedef	TBatchQueue<CMDSSQLiteUpdateInfo>								CMDSSQLiteUpdateInfoBatchQueue;

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - Procs

typedef	void	(*CMDSSQLiteDocumentBackingInfoProc)(const CMDSSQLiteDocumentBackingInfo& documentBackingInfo,
						void* userData);
typedef	void	(*CMDSSQLiteKeyDocumentBackingInfoProc)(const CString& key,
						const CMDSSQLiteDocumentBackingInfo& documentBackingInfo, void* userData);
typedef	void	(*CMDSSQLiteResultsRowDocumentBackingInfoProc)(const CMDSSQLiteDocumentBackingInfo& documentBackingInfo,
						const CSQLiteResultsRow& resultsRow, void* userData);


//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteInternals

class CMDSSQLiteInternals {
	// BatchInfo
	public:
		struct BatchInfo {
			// Lifecycle methods
			BatchInfo(CMDSSQLiteInternals& internals, CMDSSQLiteBatchInfo& batchInfo) :
				mInternals(internals), mBatchInfo(batchInfo)
				{}

			// Properties
			CMDSSQLiteInternals&	mInternals;
			CMDSSQLiteBatchInfo&	mBatchInfo;
		};

	// CollectionIndexBringUpToDateInfo
	struct CollectionIndexBringUpToDateInfo {
		// Lifecycle methods
		CollectionIndexBringUpToDateInfo(CMDSSQLite& mdsSQLite, const OR<CMDSSQLiteBatchInfo>& batchInfo,
				const CMDSDocument::Info& documentInfo) :
			mMDSSQLite(mdsSQLite), mBatchInfo(batchInfo), mDocumentInfo(documentInfo)
			{}

		// Properties
				CMDSSQLite&								mMDSSQLite;
		const	OR<CMDSSQLiteBatchInfo>&				mBatchInfo;
		const	CMDSDocument::Info&						mDocumentInfo;

				TNArray<CMDSSQLiteBringUpToDateInfo>	mBringUpToDateInfos;
				TNArray<I<CMDSDocument> >				mDocuments;
	};

	// CollectionIndexUpdateInfo
	struct CollectionIndexUpdateInfo {
		// Lifecycle methods
		CollectionIndexUpdateInfo(const CString& documentType, CMDSSQLiteInternals& internals) :
			mDocumentType(documentType), mInternals(internals)
			{}

		// Properties
		const	CString&				mDocumentType;
				CMDSSQLiteInternals&	mInternals;
	};

	// ProcessExistingDocumentInfoInfo
	public:
		struct ProcessExistingDocumentInfoInfo {
					// Lifecycle methods
					ProcessExistingDocumentInfoInfo(CMDSSQLiteDocumentBackingCache& documentBackingCache,
							CMDSSQLiteDocumentBackingInfoProc documentBackingInfoProc, void* userData) :
						mDocumentBackingCache(documentBackingCache), mDocumentBackingInfoProc(documentBackingInfoProc),
								mKeyDocumentBackingInfoProc(nil), mResultsRowDocumentBackingInfoProc(nil),
								mUserData(userData)
						{}
					ProcessExistingDocumentInfoInfo(CMDSSQLiteDocumentBackingCache& documentBackingCache,
							CMDSSQLiteKeyDocumentBackingInfoProc keyDocumentBackingInfoProc, void* userData) :
						mDocumentBackingCache(documentBackingCache), mDocumentBackingInfoProc(nil),
								mKeyDocumentBackingInfoProc(keyDocumentBackingInfoProc),
								mResultsRowDocumentBackingInfoProc(nil), mUserData(userData)
						{}

					ProcessExistingDocumentInfoInfo(CMDSSQLiteDocumentBackingCache& documentBackingCache,
							CMDSSQLiteResultsRowDocumentBackingInfoProc resultsRowDocumentBackingInfoProc,
							void* userData) :
						mDocumentBackingCache(documentBackingCache), mDocumentBackingInfoProc(nil),
								mKeyDocumentBackingInfoProc(nil),
								mResultsRowDocumentBackingInfoProc(resultsRowDocumentBackingInfoProc),
								mUserData(userData)
						{}
					ProcessExistingDocumentInfoInfo(CMDSSQLiteDocumentBackingCache& documentBackingCache,
							CollectionIndexBringUpToDateInfo& collectionIndexBringUpToDateInfo) :
						mDocumentBackingCache(documentBackingCache),
								mDocumentBackingInfoProc(
										(CMDSSQLiteDocumentBackingInfoProc) collectionIndexBringUpToDate),
								mKeyDocumentBackingInfoProc(nil), mResultsRowDocumentBackingInfoProc(nil),
								mUserData(&collectionIndexBringUpToDateInfo)
						{}

					// Instance methods
			void	perform(const CMDSSQLiteDocumentBackingInfo& documentBackingInfo,
							const CSQLiteResultsRow& resultsRow)
						{
							// Check what proc we have
							if (mDocumentBackingInfoProc != nil)
								// Have document backing info proc
								mDocumentBackingInfoProc(documentBackingInfo, mUserData);
							else if (mKeyDocumentBackingInfoProc != nil)
								// Have key document backing info proc
								mKeyDocumentBackingInfoProc(CMDSSQLiteDatabaseManager::getIndexContentsKey(resultsRow),
										documentBackingInfo, mUserData);
							else
								// Have results row document backing info proc
								mResultsRowDocumentBackingInfoProc(documentBackingInfo, resultsRow, mUserData);
						}

			// Properties
			CMDSSQLiteDocumentBackingCache&				mDocumentBackingCache;
			CMDSSQLiteDocumentBackingInfoProc			mDocumentBackingInfoProc;
			CMDSSQLiteKeyDocumentBackingInfoProc		mKeyDocumentBackingInfoProc;
			CMDSSQLiteResultsRowDocumentBackingInfoProc	mResultsRowDocumentBackingInfoProc;
			void*										mUserData;
		};

	// Methods
	public:
		CMDSSQLiteInternals(const CMDSSQLite& mdsSQLite, CSQLiteDatabase& database) :
			mMDSSQLite(mdsSQLite), mDatabaseManager(database), mID(CUUID().getBase64String()),
					mLogErrorMessageProc(nil), mLogErrorMessageProcUserData(nil)
			{}

						OR<CMDSSQLiteDocumentBacking>	getDocumentBacking(const CString& documentType,
																const CString& documentID);

						void							iterateCollection(const CString& name,
																CMDSSQLiteDocumentBackingInfoProc
																		documentBackingInfoProc,
																void* userData);
						void							updateCollections(const CString& documentType,
																const TArray<CMDSSQLiteUpdateInfo>& updateInfos);
						CMDSSQLiteCollection			bringCollectionUpToDate(const CString& name);
						void							bringUpToDate(CMDSSQLiteCollection& collection);
						void							removeFromCollections(const CString& documentType,
																const TNumberArray<SInt64>& documentBackingIDs);

						void							iterateIndex(const CString& name, const TArray<CString>& keys,
																CMDSSQLiteKeyDocumentBackingInfoProc
																		keyDocumentBackingInfoProc,
																void* userData);
						void							updateIndexes(const CString& documentType,
																const TArray<CMDSSQLiteUpdateInfo>& updateInfos);
						CMDSSQLiteIndex					bringIndexUpToDate(const CString& name);
						void							bringUpToDate(CMDSSQLiteIndex& index);
						void							removeFromIndexes(const CString& documentType,
																const TNumberArray<SInt64>& documentBackingIDs);

						void							notifyDocumentChanged(const CString& documentType,
																const CMDSDocument& document,
																CMDSDocument::ChangeKind changeKind);

		static	const	OV<SValue>						getDocumentBackingPropertyValue(const CString& documentID,
																const CString& property,
																CMDSSQLiteDocumentBacking* documentBacking);
		static			void							processExistingDocumentInfo(
																const ExistingDocumentInfo& existingDocumentInfo,
																const CSQLiteResultsRow& resultsRow,
																ProcessExistingDocumentInfoInfo*
																		processExistingDocumentInfoInfo);
		static			void							addDocumentID(
																const CMDSSQLiteDocumentBackingInfo&
																		documentBackingInfo,
																TMArray<CString>* documentIDs)
															{ (*documentIDs) += documentBackingInfo.mDocumentID; }
		static			void							addDocumentIDWithKey(const CString& key,
																const CMDSSQLiteDocumentBackingInfo&
																		documentBackingInfo,
																TNDictionary<CString>* keyMap)
															{ keyMap->set(key, documentBackingInfo.mDocumentID); }
		static			void							addDocumentIDWithResultsRow(
																const CMDSSQLiteDocumentBackingInfo&
																		documentBackingInfo,
																const CSQLiteResultsRow& resultsRow,
																TMArray<CString>* documentIDs)
															{ (*documentIDs) += documentBackingInfo.mDocumentID; }
		static			void							noteReference(
																const CMDSSQLiteDocumentBackingInfo&
																		documentBackingInfo,
																void* userData)
															{}
		static			void							storeDocumentBackingInfo(
																const CMDSSQLiteDocumentBackingInfo&
																		documentBackingInfo,
																OI<CMDSSQLiteDocumentBackingInfo>*
																		outDocumentBackingInfo)
															{ *outDocumentBackingInfo =
																	OI<CMDSSQLiteDocumentBackingInfo>(
																			documentBackingInfo); }

		static			void							collectionIndexBringUpToDate(
																const CMDSSQLiteDocumentBackingInfo&
																		documentBackingInfo,
																CollectionIndexBringUpToDateInfo*
																		collectionBringUpToDateInfo);
		static			void							updateCollectionsIndexes(
																const TArray<CMDSSQLiteUpdateInfo>& updateInfos,
																CollectionIndexUpdateInfo* collectionIndexUpdateInfo)
															{
																// Update collections and indexes
																collectionIndexUpdateInfo->mInternals
																		.updateCollections(
																				collectionIndexUpdateInfo->
																						mDocumentType,
																				updateInfos);
																collectionIndexUpdateInfo->mInternals
																		.updateIndexes(
																				collectionIndexUpdateInfo->
																						mDocumentType,
																				updateInfos);
															}

		static			void							batch(BatchInfo* batchInfo);
		static			OV<SError>						batchMap(const CString& documentType,
																const TDictionary<CMDSSQLiteBatchDocumentInfo >&
																		documentInfosMap,
																CMDSSQLiteInternals* internals);

		const	CMDSSQLite&												mMDSSQLite;
				CMDSSQLiteDatabaseManager								mDatabaseManager;

				CString													mID;

				TNLockingDictionary<CMDSSQLiteBatchInfo>				mBatchInfoMap;

				CMDSSQLiteDocumentBackingCache							mDocumentBackingCache;
				TNLockingArrayDictionary<CMDSDocument::ChangedProcInfo>	mDocumentChangedProcInfosMap;
				TNLockingDictionary<CMDSDocument::Info>					mDocumentInfoMap;
				TNLockingDictionary<CDictionary>						mDocumentsBeingCreatedPropertyMapMap;

				TNLockingDictionary<CMDSSQLiteCollection>				mCollectionsByNameMap;
				TNLockingArrayDictionary<CMDSSQLiteCollection>			mCollectionsByDocumentTypeMap;

				TNLockingDictionary<CMDSSQLiteIndex>					mIndexesByNameMap;
				TNLockingArrayDictionary<CMDSSQLiteIndex>				mIndexesByDocumentTypeMap;

				CMDSSQLite::LogErrorMessageProc							mLogErrorMessageProc;
				void*													mLogErrorMessageProcUserData;
};

//----------------------------------------------------------------------------------------------------------------------
OR<CMDSSQLiteDocumentBacking> CMDSSQLiteInternals::getDocumentBacking(const CString& documentType,
		const CString& documentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Try to retrieve stored document
	OR<CMDSSQLiteDocumentBacking>	documentBacking = mDocumentBackingCache.getDocumentBacking(documentID);
	if (documentBacking.hasReference())
		// Have document
		return documentBacking;
	else {
		// Try to retrieve document backing
		OI<CMDSSQLiteDocumentBackingInfo>	documentBackingInfo;
		ProcessExistingDocumentInfoInfo		processExistingDocumentInfoInfo(mDocumentBackingCache,
													(CMDSSQLiteDocumentBackingInfoProc) storeDocumentBackingInfo,
													&documentBackingInfo);
		mDatabaseManager.iterate(documentType, mDatabaseManager.getInnerJoin(documentType),
				mDatabaseManager.getWhereForDocumentIDs(TSArray<CString>(documentID)),
				(CMDSSQLiteDatabaseManager::ExistingDocumentInfoProc) processExistingDocumentInfo,
				&processExistingDocumentInfoInfo);

		// Check results
		if (documentBackingInfo.hasInstance())
			// Update cache
			mDocumentBackingCache.add(*documentBackingInfo);
		else {
			// Not found
			if (mLogErrorMessageProc != nil)
				// Call proc
				mLogErrorMessageProc(
						CString(OSSTR("CMDSSQLite - Cannot find document of type ")) + documentType +
								CString(OSSTR(" with documentID ")) + documentID,
						mLogErrorMessageProcUserData);
		}

		return mDocumentBackingCache.getDocumentBacking(documentID);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::iterateCollection(const CString& name,
		CMDSSQLiteDocumentBackingInfoProc documentBackingInfoProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Bring up to date
	CMDSSQLiteCollection	collection = bringCollectionUpToDate(name);

	// Iterate existing documents
	ProcessExistingDocumentInfoInfo	processExistingDocumentInfoInfo(mDocumentBackingCache, documentBackingInfoProc,
											userData);
	mDatabaseManager.iterate(collection.getDocumentType(),
			mDatabaseManager.getInnerJoinForCollection(collection.getDocumentType(), name),
			(CMDSSQLiteDatabaseManager::ExistingDocumentInfoProc) processExistingDocumentInfo,
			&processExistingDocumentInfoInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::updateCollections(const CString& documentType,
		const TArray<CMDSSQLiteUpdateInfo>& updateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get collections
	const	OR<TArray<CMDSSQLiteCollection> >	collections = mCollectionsByDocumentTypeMap.get(documentType);
	if (!collections.hasReference())
		// No collections for this document type
		return;

	// Setup
	UInt32	minRevision = 0;
	for (TIteratorD<CMDSSQLiteUpdateInfo> iterator = updateInfos.getIterator(); iterator.hasValue(); iterator.advance())
		// Update min revision
		minRevision = std::min(minRevision, iterator->mRevision);

	// Iterate collections
	for (TIteratorD<CMDSSQLiteCollection> iterator = collections->getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Check revision state
		if ((iterator->getLastRevision() + 1) == minRevision) {
			// Update collection
			CMDSSQLiteCollectionUpdateInfo	updateInfo = iterator->update(updateInfos);

			// Update database
			mDatabaseManager.updateCollection(iterator->getName(), updateInfo.mIncludedValues,
					updateInfo.mNotIncludedValues, updateInfo.mLastRevision);
		} else
			// Bring up to date
			bringUpToDate(*iterator);
	}
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteCollection CMDSSQLiteInternals::bringCollectionUpToDate(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<CMDSSQLiteCollection>	collection = mCollectionsByNameMap.get(name);

	// Bring up to date
	bringUpToDate(*collection);

	return *collection;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::bringUpToDate(CMDSSQLiteCollection& collection)
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect infos
	CollectionIndexBringUpToDateInfo		collectionIndexBringUpToDateInfo((CMDSSQLite&) mMDSSQLite,
													mBatchInfoMap[CThread::getCurrentRefAsString()],
													*mDocumentInfoMap[collection.getDocumentType()]);
	ProcessExistingDocumentInfoInfo			processExistingDocumentInfoInfo(mDocumentBackingCache,
													collectionIndexBringUpToDateInfo);
	mDatabaseManager.iterate(collection.getDocumentType(), mDatabaseManager.getInnerJoin(collection.getDocumentType()),
			mDatabaseManager.getWhere(collection.getLastRevision()),
			(CMDSSQLiteDatabaseManager::ExistingDocumentInfoProc) processExistingDocumentInfo,
			&processExistingDocumentInfoInfo);

	// Bring up to date
	CMDSSQLiteCollectionUpdateInfo	updateInfo =
											collection.bringUpToDate(
													collectionIndexBringUpToDateInfo.mBringUpToDateInfos);

	// Update database
	mDatabaseManager.updateCollection(collection.getName(), updateInfo.mIncludedValues, updateInfo.mNotIncludedValues,
			updateInfo.mLastRevision);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::removeFromCollections(const CString& documentType,
		const TNumberArray<SInt64>& documentBackingIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get collections for this document type
	const	OR<TArray<CMDSSQLiteCollection> >	collections = mCollectionsByDocumentTypeMap.get(documentType);
	if (!collections.hasReference())
		// No collections for this document type
		return;

	// Iterate collections
	for (TIteratorD<CMDSSQLiteCollection> iterator = collections->getIterator(); iterator.hasValue();
			iterator.advance())
		// Update collection
		mDatabaseManager.updateCollection(iterator->getName(), TNumberArray<SInt64>(), documentBackingIDs,
				iterator->getLastRevision());
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::iterateIndex(const CString& name, const TArray<CString>& keys,
		CMDSSQLiteKeyDocumentBackingInfoProc keyDocumentBackingInfoProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Bring up to date
	CMDSSQLiteIndex	index = bringIndexUpToDate(name);

	// Iterate existing documents
	ProcessExistingDocumentInfoInfo	processExistingDocumentInfoInfo(mDocumentBackingCache, keyDocumentBackingInfoProc,
											userData);
	mDatabaseManager.iterate(index.getDocumentType(),
			mDatabaseManager.getInnerJoinForIndex(index.getDocumentType(), name),
			mDatabaseManager.getWhereForIndexKeys(keys),
			(CMDSSQLiteDatabaseManager::ExistingDocumentInfoProc) processExistingDocumentInfo,
			&processExistingDocumentInfoInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::updateIndexes(const CString& documentType, const TArray<CMDSSQLiteUpdateInfo>& updateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get indexes
	const	OR<TArray<CMDSSQLiteIndex> >	indexes = mIndexesByDocumentTypeMap.get(documentType);
	if (!indexes.hasReference())
		// No indexes for this document type
		return;

	// Setup
	UInt32	minRevision = 0;
	for (TIteratorD<CMDSSQLiteUpdateInfo> iterator = updateInfos.getIterator(); iterator.hasValue(); iterator.advance())
		// Update min revision
		minRevision = std::min(minRevision, iterator->mRevision);

	// Iterate indexes
	for (TIteratorD<CMDSSQLiteIndex> iterator = indexes->getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check revision state
		if ((iterator->getLastRevision() + 1) == minRevision) {
			// Update index
			CMDSSQLiteIndexUpdateInfo	updateInfo = iterator->update(updateInfos);

			// Update database
			mDatabaseManager.updateIndex(iterator->getName(), updateInfo.mKeysInfos, TNumberArray<SInt64>(),
					updateInfo.mLastRevision);
		} else
			// Bring up to date
			bringUpToDate(*iterator);
	}
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteIndex CMDSSQLiteInternals::bringIndexUpToDate(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<CMDSSQLiteIndex>	index = mIndexesByNameMap.get(name);

	// Bring up to date
	bringUpToDate(*index);

	return *index;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::bringUpToDate(CMDSSQLiteIndex& index)
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect infos
	CollectionIndexBringUpToDateInfo		collectionIndexBringUpToDateInfo((CMDSSQLite&) mMDSSQLite,
													mBatchInfoMap[CThread::getCurrentRefAsString()],
													*mDocumentInfoMap[index.getDocumentType()]);
	ProcessExistingDocumentInfoInfo			processExistingDocumentInfoInfo(mDocumentBackingCache,
													collectionIndexBringUpToDateInfo);
	mDatabaseManager.iterate(index.getDocumentType(), mDatabaseManager.getInnerJoin(index.getDocumentType()),
			mDatabaseManager.getWhere(index.getLastRevision()),
			(CMDSSQLiteDatabaseManager::ExistingDocumentInfoProc) processExistingDocumentInfo,
			&processExistingDocumentInfoInfo);

	// Bring up to date
	CMDSSQLiteIndexUpdateInfo	updateInfo = index.bringUpToDate(collectionIndexBringUpToDateInfo.mBringUpToDateInfos);

	// Update database
	mDatabaseManager.updateIndex(index.getName(), updateInfo.mKeysInfos, TNumberArray<SInt64>(),
			updateInfo.mLastRevision);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::removeFromIndexes(const CString& documentType, const TNumberArray<SInt64>& documentBackingIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get indexes for this document type
	const	OR<TArray<CMDSSQLiteIndex> >	indexes = mIndexesByDocumentTypeMap.get(documentType);
	if (!indexes.hasReference())
		// No indexes for this document type
		return;

	// Iterate indexes
	for (TIteratorD<CMDSSQLiteIndex> iterator = indexes->getIterator(); iterator.hasValue(); iterator.advance())
		// Update index
		mDatabaseManager.updateIndex(iterator->getName(), TNArray<CMDSSQLiteIndexKeysInfo>(), documentBackingIDs,
				iterator->getLastRevision());
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::notifyDocumentChanged(const CString& documentType, const CMDSDocument& document,
		CMDSDocument::ChangeKind changeKind)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get document changed procs for this document type
	const	OR<TArray<CMDSDocument::ChangedProcInfo> >	changedProcInfos =
																mDocumentChangedProcInfosMap.get(documentType);
	if (!changedProcInfos.hasReference())
		// No document changed procs for this document type
		return;

	// Iterate document changed procs
	for (TIteratorD<CMDSDocument::ChangedProcInfo> iterator = changedProcInfos->getIterator(); iterator.hasValue();
			iterator.advance())
		// Notify
		iterator->notify(document, changeKind);
}

//----------------------------------------------------------------------------------------------------------------------
const OV<SValue> CMDSSQLiteInternals::getDocumentBackingPropertyValue(const CString& documentID,
		const CString& property, CMDSSQLiteDocumentBacking* documentBacking)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return value
	return documentBacking->getValue(property);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::processExistingDocumentInfo(const ExistingDocumentInfo& existingDocumentInfo,
		const CSQLiteResultsRow& resultsRow, ProcessExistingDocumentInfoInfo* processExistingDocumentInfoInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Try to retrieve document backing
	OR<CMDSSQLiteDocumentBacking>	documentBacking =
											processExistingDocumentInfoInfo->mDocumentBackingCache.getDocumentBacking(
													existingDocumentInfo.mDocumentRevisionInfo.mDocumentID);
	if (documentBacking.hasReference()) {
		// Have document
		CMDSSQLiteDocumentBackingInfo	documentBackingInfo(existingDocumentInfo.mDocumentRevisionInfo.mDocumentID,
												*documentBacking);

		// Note referenced
		processExistingDocumentInfoInfo->mDocumentBackingCache.add(
				TSArray<CMDSSQLiteDocumentBackingInfo>(documentBackingInfo));

		// Call proc
		processExistingDocumentInfoInfo->perform(documentBackingInfo, resultsRow);
	} else {
		// Read
		CMDSSQLiteDocumentBackingInfo	documentBackingInfo =
												CMDSSQLiteDatabaseManager::getDocumentBackingInfo(existingDocumentInfo,
														resultsRow);

		// Note referenced
		processExistingDocumentInfoInfo->mDocumentBackingCache.add(
				TSArray<CMDSSQLiteDocumentBackingInfo>(documentBackingInfo));

		// Call proc
		processExistingDocumentInfoInfo->perform(documentBackingInfo, resultsRow);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::collectionIndexBringUpToDate(const CMDSSQLiteDocumentBackingInfo& documentBackingInfo,
		CollectionIndexBringUpToDateInfo* collectionIndexBringUpToDateInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Query batch info
	const	OR<CMDSSQLiteBatchDocumentInfo>	batchDocumentInfo =
													collectionIndexBringUpToDateInfo->mBatchInfo.hasReference() ?
															collectionIndexBringUpToDateInfo->mBatchInfo->
																	getDocumentInfo(documentBackingInfo.mDocumentID) :
															OR<CMDSSQLiteBatchDocumentInfo>();

	// Ensure we want to process this document
	if (!batchDocumentInfo.hasReference() || !batchDocumentInfo->isRemoved()) {
		// Create document
		CMDSDocument*	document =
								collectionIndexBringUpToDateInfo->mDocumentInfo.create(documentBackingInfo.mDocumentID,
								collectionIndexBringUpToDateInfo->mMDSSQLite);
		collectionIndexBringUpToDateInfo->mDocuments += I<CMDSDocument>(document);

		// Append info
		collectionIndexBringUpToDateInfo->mBringUpToDateInfos +=
				CMDSSQLiteBringUpToDateInfo(*document, documentBackingInfo.mDocumentBacking.getRevision(),
						documentBackingInfo.mDocumentBacking.getID());
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteInternals::batch(BatchInfo* batchInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate all document changes
	batchInfo->mBatchInfo.iterate((CMDSSQLiteBatchDocumentInfo::MapProc) batchMap, &batchInfo->mInternals);
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLiteInternals::batchMap(const CString& documentType,
		const TDictionary<CMDSSQLiteBatchDocumentInfo >& documentInfosMap, CMDSSQLiteInternals* internals)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<CMDSDocument::Info>&			documentInfo = internals->mDocumentInfoMap[documentType];
			TNArray<I<CMDSDocument> >		documents;

			CollectionIndexUpdateInfo		collectionIndexUpdateInfo(documentType, *internals);
			CMDSSQLiteUpdateInfoBatchQueue	updateBatchQueue(
													(CMDSSQLiteUpdateInfoBatchQueue::Proc) updateCollectionsIndexes,
													&collectionIndexUpdateInfo);
			TNumberArray<SInt64>			removedDocumentBackingIDs;

	// Update documents
	for (TIteratorS<CDictionary::Item> iterator = documentInfosMap.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Setup
		const	CString&						documentID = iterator->mKey;
		const	CMDSSQLiteBatchDocumentInfo&	batchDocumentInfo =
														*((CMDSSQLiteBatchDocumentInfo*) iterator->mValue.getOpaque());
		const	OI<CMDSSQLiteDocumentBacking>	existingDocumentBacking = batchDocumentInfo.getReference();


		// Check removed
		if (!batchDocumentInfo.isRemoved()) {
			// Add/update document
			if (existingDocumentBacking.hasInstance()) {
				// Update document
				existingDocumentBacking->update(documentType, batchDocumentInfo.getUpdatedPropertyMap(),
						batchDocumentInfo.getRemovedProperties(), internals->mDatabaseManager);

				// Check if we have document info
				if (documentInfo.hasReference()) {
					// Create document
					CMDSDocument*	document =
											documentInfo->create(documentID, *((CMDSSQLite*) &internals->mMDSSQLite));
					documents += I<CMDSDocument>(document);

					// Update collections and indexes
					TSet<CString>	changedProperties =
											batchDocumentInfo.getUpdatedPropertyMap().getKeys()
												.addFrom(batchDocumentInfo.getRemovedProperties());
					updateBatchQueue.add(
							CMDSSQLiteUpdateInfo(*document, existingDocumentBacking->getRevision(),
									existingDocumentBacking->getID(), changedProperties));

					// Call document changed procs
					internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kUpdated);
				}
			} else {
				// Add document
				CMDSSQLiteDocumentBacking	documentBacking(documentType, documentID,
													batchDocumentInfo.getCreationUniversalTime(),
													batchDocumentInfo.getModificationUniversalTime(),
													batchDocumentInfo.getUpdatedPropertyMap(),
													internals->mDatabaseManager);
				internals->mDocumentBackingCache.add(CMDSSQLiteDocumentBackingInfo(documentID, documentBacking));

				// Check if we have document info
				if (documentInfo.hasReference()) {
					// Create document
					CMDSDocument*	document =
											documentInfo->create(documentID, *((CMDSSQLite*) &internals->mMDSSQLite));
					documents += I<CMDSDocument>(document);

					// Update collections and indexes
					updateBatchQueue.add(
							CMDSSQLiteUpdateInfo(*document, documentBacking.getRevision(), documentBacking.getID(),
									TSet<CString>()));

					// Call document changed procs
					internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kCreated);
				}
			}
		} else if (existingDocumentBacking.hasInstance()) {
			// Remove document
			internals->mDatabaseManager.removeDocument(documentType, existingDocumentBacking->getID());
			internals->mDocumentBackingCache.remove(TSArray<CString>(documentID));

			// Remove from collections and indexes
			removedDocumentBackingIDs += existingDocumentBacking->getID();

			// Check if we have document info
			if (documentInfo.hasReference()) {
				// Create document
				CMDSDocument*	document =
										documentInfo->create(documentID, *((CMDSSQLite*) &internals->mMDSSQLite));
				documents += I<CMDSDocument>(document);

				// Call document changed procs
				internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kRemoved);
			}
		}
	}

	// Finalize updates
	updateBatchQueue.finalize();
	internals->removeFromCollections(documentType, removedDocumentBackingIDs);
	internals->removeFromIndexes(documentType, removedDocumentBackingIDs);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLite

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLite::CMDSSQLite(const CFolder& folder, const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CSQLiteDatabase	database(folder, name);
	mInternals = new CMDSSQLiteInternals(*this, database);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLite::~CMDSSQLite()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: CMDSDocumentStorage methods

//----------------------------------------------------------------------------------------------------------------------
const CString& CMDSSQLite::getID() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mID;
}

//----------------------------------------------------------------------------------------------------------------------
TDictionary<CString> CMDSSQLite::getInfo(const TArray<CString>& keys) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate all keys
	TNDictionary<CString>	info;
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance())
		// Retrieve this key
		info.set(*iterator, mInternals->mDatabaseManager.getString(*iterator));

	return info;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::set(const TDictionary<CString>& info)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate all items
	for (TIteratorS<CDictionary::Item> iterator = info.getIterator(); iterator.hasValue(); iterator.advance())
		// Set value
		mInternals->mDatabaseManager.set(iterator->mKey, OV<SValue>(iterator->mValue));
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::remove(const TArray<CString>& keys)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate all keys
	for (TIteratorD<CString> iterator = keys.getIterator(); iterator.hasValue(); iterator.advance())
		// Remove value
		mInternals->mDatabaseManager.set(*iterator, OV<SValue>());
}

//----------------------------------------------------------------------------------------------------------------------
I<CMDSDocument> CMDSSQLite::newDocument(const CMDSDocument::InfoForNew& infoForNew)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CString			documentID = CUUID().getBase64String();
	UniversalTime	universalTime = SUniversalTime::getCurrent();

	// Check for batch
	const	OR<CMDSSQLiteBatchInfo>	batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	if (batchInfo.hasReference()) {
		// In batch
		batchInfo->addDocument(infoForNew.getDocumentType(), documentID, universalTime, universalTime);

		return I<CMDSDocument>(infoForNew.create(documentID, *this));
	} else {
		// Will be creating document
		mInternals->mDocumentsBeingCreatedPropertyMapMap.set(documentID, CDictionary());

		// Create
		CMDSDocument*	document = infoForNew.create(documentID, *this);

		// Remove property map
		const	OR<CDictionary>	propertyMap = mInternals->mDocumentsBeingCreatedPropertyMapMap.get(documentID);
		mInternals->mDocumentsBeingCreatedPropertyMapMap.remove(documentID);

		// Add document
		CMDSSQLiteDocumentBacking	documentBacking(infoForNew.getDocumentType(), documentID, universalTime,
											universalTime, *propertyMap, mInternals->mDatabaseManager);
		mInternals->mDocumentBackingCache.add(CMDSSQLiteDocumentBackingInfo(documentID, documentBacking));

		// Update collections and indexes
		CMDSSQLiteUpdateInfo	updateInfo(*document, documentBacking.getRevision(), documentBacking.getID());
		mInternals->updateCollections(infoForNew.getDocumentType(), TSArray<CMDSSQLiteUpdateInfo>(updateInfo));
		mInternals->updateIndexes(infoForNew.getDocumentType(), TSArray<CMDSSQLiteUpdateInfo>(updateInfo));

		// Call document changed procs
		mInternals->notifyDocumentChanged(infoForNew.getDocumentType(), *document, CMDSDocument::kCreated);

		return I<CMDSDocument>(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
OI<CMDSDocument> CMDSSQLite::getDocument(const CString& documentID, const CMDSDocument::Info& documentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<CMDSSQLiteBatchInfo>			batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSSQLiteBatchDocumentInfo>	batchDocumentInfo =
													batchInfo.hasReference() ?
															batchInfo->getDocumentInfo(documentID) :
															OR<CMDSSQLiteBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// Have document in batch
		return OI<CMDSDocument>(documentInfo.create(documentID, (CMDSDocumentStorage&) *this));

	// Check for document backing
	OR<CMDSSQLiteDocumentBacking>	documentBacking =
											mInternals->getDocumentBacking(documentInfo.getDocumentType(), documentID);
	if (documentBacking.hasReference())
		// Have document backing
		return OI<CMDSDocument>(documentInfo.create(documentID, (CMDSDocumentStorage&) *this));
	else
		// Don't have document backing
		return OI<CMDSDocument>();
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSSQLite::getCreationUniversalTime(const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
//	// Check for batch
	const	OR<CMDSSQLiteBatchInfo>			batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSSQLiteBatchDocumentInfo>	batchDocumentInfo =
													batchInfo.hasReference() ?
															batchInfo->getDocumentInfo(document.getID()) :
															OR<CMDSSQLiteBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// Have document in batch
		return batchDocumentInfo->getCreationUniversalTime();
	else if (mInternals->mDocumentsBeingCreatedPropertyMapMap.contains(document.getID()))
		// Being created
		return SUniversalTime::getCurrent();
	else
		// "Idle"
		return mInternals->getDocumentBacking(document.getDocumentType(), document.getID())->getCreationUniversalTime();
}

//----------------------------------------------------------------------------------------------------------------------
UniversalTime CMDSSQLite::getModificationUniversalTime(const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<CMDSSQLiteBatchInfo>			batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSSQLiteBatchDocumentInfo>	batchDocumentInfo =
													batchInfo.hasReference() ?
															batchInfo->getDocumentInfo(document.getID()) :
															OR<CMDSSQLiteBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// Have document in batch
		return batchDocumentInfo->getModificationUniversalTime();
	else if (mInternals->mDocumentsBeingCreatedPropertyMapMap.contains(document.getID()))
		// Being created
		return SUniversalTime::getCurrent();
	else
		// "Idle"
		return mInternals->getDocumentBacking(document.getDocumentType(), document.getID())->
				getModificationUniversalTime();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SValue> CMDSSQLite::getValue(const CString& property, const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Check for batch
	const	OR<CMDSSQLiteBatchInfo>			batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSSQLiteBatchDocumentInfo>	batchDocumentInfo =
													batchInfo.hasReference() ?
															batchInfo->getDocumentInfo(document.getID()) :
															OR<CMDSSQLiteBatchDocumentInfo>();
	if (batchDocumentInfo.hasReference())
		// Have document in batch
		return batchDocumentInfo->getValue(property);

	// Check if being created
	const	OR<CDictionary>	propertyMap = mInternals->mDocumentsBeingCreatedPropertyMapMap[document.getID()];
	if (propertyMap.hasReference())
		// Being created
		return propertyMap->contains(property) ? OV<SValue>(propertyMap->getValue(property)) : OV<SValue>();
	else
		// "Idle"
		return mInternals->getDocumentBacking(document.getDocumentType(), document.getID())->getValue(property);
}

//----------------------------------------------------------------------------------------------------------------------
OV<CData> CMDSSQLite::getData(const CString& property, const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = getValue(property, document);

	return value.hasInstance() ? OV<CData>(CData(value->getString())) : OV<CData>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<UniversalTime> CMDSSQLite::getUniversalTime(const CString& property, const CMDSDocument& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get value
	OV<SValue>	value = getValue(property, document);
	if (!value.hasInstance())
		return OV<UniversalTime>();

	OV<SGregorianDate>	gregorianDate =
								SGregorianDate::getFrom(value->getString(), SGregorianDate::kStringStyleRFC339Extended);
	if (!gregorianDate.hasValue())
		return OV<UniversalTime>();

	return OV<UniversalTime>(gregorianDate->getUniversalTime());
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::set(const CString& property, const OV<SValue>& value, const CMDSDocument& document,
		SetValueInfo setValueInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	CString&	documentType = document.getDocumentType();
	const	CString&	documentID = document.getID();

	// Transform
	OV<SValue>	valueUse;
	if (value.hasInstance() && (value->getType() == SValue::kData))
		// Data
		valueUse = OV<SValue>(value->getData().getBase64String());
	else if (value.hasInstance() && (setValueInfo == kUniversalTime))
		// UniversalTime
		valueUse =
				OV<SValue>(
						SValue(
								SGregorianDate(value->getFloat64())
										.getString(SGregorianDate::kStringStyleRFC339Extended)));
	else
		// Everything else
		valueUse = value;

	// Check for batch
	const	OR<CMDSSQLiteBatchInfo>	batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	if (batchInfo.hasReference()) {
		// In batch
		const	OR<CMDSSQLiteBatchDocumentInfo>	batchDocumentInfo = batchInfo->getDocumentInfo(document.getID());
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->set(property, valueUse);
		else {
			// Don't have document in batch
			OR<CMDSSQLiteDocumentBacking>	documentBacking = mInternals->getDocumentBacking(documentType, documentID);
			UniversalTime					universalTime = SUniversalTime::getCurrent();
			batchInfo->addDocument(documentType, documentID, OI<CMDSSQLiteDocumentBacking>(*documentBacking),
						universalTime, universalTime,
						(CMDSSQLiteBatchInfo::DocumentPropertyValueProc)
								CMDSSQLiteInternals::getDocumentBackingPropertyValue,
						&documentBacking.getReference())
				.set(property, valueUse);
		}
	} else {
		// Check if being created
		const	OR<CDictionary>	propertyMap = mInternals->mDocumentsBeingCreatedPropertyMapMap[documentID];
		if (propertyMap.hasReference())
			// Being created
			propertyMap->set(property, value);
		else {
			// Update document
			OR<CMDSSQLiteDocumentBacking>	documentBacking = mInternals->getDocumentBacking(documentType, documentID);
			documentBacking->set(property, valueUse, documentType, mInternals->mDatabaseManager);

			// Update collections and indexes
			CMDSSQLiteUpdateInfo	updateInfo(document, documentBacking->getRevision(), documentBacking->getID(),
											TSet<CString>(property));
			mInternals->updateCollections(documentType, TSArray<CMDSSQLiteUpdateInfo>(updateInfo));
			mInternals->updateIndexes(documentType, TSArray<CMDSSQLiteUpdateInfo>(updateInfo));

			// Call document changed procs
			mInternals->notifyDocumentChanged(documentType, document, CMDSDocument::kUpdated);
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::remove(const CMDSDocument& document)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	CString&	documentType = document.getDocumentType();
	const	CString&	documentID = document.getID();

	// Check for batch
	const	OR<CMDSSQLiteBatchInfo>	batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	if (batchInfo.hasReference()) {
		// In batch
		const	OR<CMDSSQLiteBatchDocumentInfo>	batchDocumentInfo = batchInfo->getDocumentInfo(documentID);
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->remove();
		else {
			// Don't have document in batch
			UniversalTime	universalTime = SUniversalTime::getCurrent();
			batchInfo->addDocument(documentType, documentID, universalTime, universalTime).remove();
		}
	} else {
		// Not in batch
		OR<CMDSSQLiteDocumentBacking>	documentBacking = mInternals->getDocumentBacking(documentType, documentID);

		// Remove from collections and indexes
		TNumberArray<SInt64>	ids(documentBacking->getID());
		mInternals->removeFromCollections(documentType, ids);
		mInternals->removeFromIndexes(documentType, ids);

		// Remove
		mInternals->mDatabaseManager.removeDocument(documentType, documentBacking->getID());

		// Remove from cache
		mInternals->mDocumentBackingCache.remove(TSArray<CString>(documentID));

		// Call document changed procs
		mInternals->notifyDocumentChanged(documentType, document, CMDSDocument::kRemoved);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::iterate(const CMDSDocument::Info& documentInfo, CMDSDocument::Proc proc, void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate document backing infos to collect document IDs
	TNArray<CString>										documentIDs;
	CMDSSQLiteInternals::ProcessExistingDocumentInfoInfo	processExistingDocumentInfoInfo(
																	mInternals->mDocumentBackingCache,
																	(CMDSSQLiteResultsRowDocumentBackingInfoProc)
																			CMDSSQLiteInternals::
																					addDocumentIDWithResultsRow,
																	&documentIDs);
	mInternals->mDatabaseManager.iterate(documentInfo.getDocumentType(),
			mInternals->mDatabaseManager.getInnerJoin(documentInfo.getDocumentType()),
			mInternals->mDatabaseManager.getWhere(true),
			(CMDSSQLiteDatabaseManager::ExistingDocumentInfoProc) CMDSSQLiteInternals::processExistingDocumentInfo,
			&processExistingDocumentInfoInfo);

	// Iterate document IDs
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Create document
		CMDSDocument*	document = documentInfo.create(*iterator, *((CMDSDocumentStorage*) this));

		// Call proc
		proc(*document, userData);

		// Cleanup
		Delete(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::iterate(const CMDSDocument::Info& documentInfo, const TArray<CString>& documentIDs,
		CMDSDocument::Proc proc, void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate document backing infos to ensure they are in the cache
	CMDSSQLiteInternals::ProcessExistingDocumentInfoInfo	processExistingDocumentInfoInfo(
																	mInternals->mDocumentBackingCache,
																	CMDSSQLiteInternals::noteReference, nil);
	mInternals->mDatabaseManager.iterate(documentInfo.getDocumentType(),
			mInternals->mDatabaseManager.getInnerJoin(documentInfo.getDocumentType()),
			mInternals->mDatabaseManager.getWhereForDocumentIDs(documentIDs),
			(CMDSSQLiteDatabaseManager::ExistingDocumentInfoProc) CMDSSQLiteInternals::processExistingDocumentInfo,
			&processExistingDocumentInfoInfo);

	// Iterate document IDs
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Create document
		CMDSDocument*	document = documentInfo.create(*iterator, *((CMDSDocumentStorage*) this));

		// Call proc
		proc(*document, userData);

		// Cleanup
		Delete(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::batch(BatchProc batchProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CMDSSQLiteBatchInfo	sqliteBatchInfo;

	// Store
	mInternals->mBatchInfoMap.set(CThread::getCurrentRefAsString(), sqliteBatchInfo);

	// Call proc
	BatchResult	batchResult = batchProc(userData);

	// Check result
	if (batchResult == kCommit) {
		// Batch changes
		CMDSSQLiteInternals::BatchInfo	batchInfo(*mInternals, sqliteBatchInfo);
		mInternals->mDatabaseManager.batch((CMDSSQLiteDatabaseManager::BatchProc) CMDSSQLiteInternals::batch,
				&batchInfo);
	}

	// Remove
	mInternals->mBatchInfoMap.remove(CThread::getCurrentRefAsString());
}

////----------------------------------------------------------------------------------------------------------------------
//void CMDSSQLite::registerAssociation(const CString& name, const CMDSDocument::Info& fromDocumentInfo,
//		const CMDSDocument::Info& toDocumenInfo)
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//}
//
////----------------------------------------------------------------------------------------------------------------------
//void CMDSSQLite::updateAssociation(const CString& name, const TArray<AssociationUpdate>& updates)
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//}
//
////----------------------------------------------------------------------------------------------------------------------
//void CMDSSQLite::iterateAssociationFrom(const CString& name, const CMDSDocument& fromDocument, CMDSDocument::Proc proc,
//		void* userData) const
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//}
//
////----------------------------------------------------------------------------------------------------------------------
//void CMDSSQLite::iterateAssociationTo(const CString& name, const CMDSDocument& toDocument, CMDSDocument::Proc proc,
//		void* userData) const
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//}
//
////----------------------------------------------------------------------------------------------------------------------
//SValue CMDSSQLite::retrieveAssociationValue(const CString& name, const CString& fromDocumentType,
//		const CMDSDocument& toDocument, const CString& summedCachedValueName)
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//
//	return SValue(false);
//}
//
////----------------------------------------------------------------------------------------------------------------------
//void CMDSSQLite::registerCache(const CString& name, const CMDSDocument::Info& documentInfo, UInt32 version,
//		const TArray<CString>& relevantProperties, const TArray<CacheValueInfo>& cacheValueInfos)
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::registerCollection(const CString& name, const CMDSDocument::Info& documentInfo, UInt32 version,
		const TArray<CString>& relevantProperties, bool isUpToDate, const CString& isIncludedSelector,
		const CDictionary& isIncludedSelectorInfo, CMDSDocument::IsIncludedProc isIncludedProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Ensure this collection has not already been registered
	if (mInternals->mCollectionsByNameMap.get(name).hasReference())
		// Already registered
		return;

	// Note this document type
	mInternals->mDatabaseManager.note(documentInfo.getDocumentType());

	// Register collection
	UInt32	lastRevision =
					mInternals->mDatabaseManager.registerCollection(documentInfo.getDocumentType(), name, version,
							isUpToDate);

	// Create collection
	CMDSSQLiteCollection	collection(name, documentInfo.getDocumentType(), relevantProperties, lastRevision,
									isIncludedProc, userData);

	// Add to maps
	mInternals->mCollectionsByNameMap.set(name, collection);
	mInternals->mCollectionsByDocumentTypeMap.add(documentInfo.getDocumentType(), collection);

	// Update document info map
	mInternals->mDocumentInfoMap.set(documentInfo.getDocumentType(), documentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLite::getCollectionDocumentCount(const CString& name) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Bring up to date
	mInternals->bringCollectionUpToDate(name);

	return mInternals->mDatabaseManager.getCollectionDocumentCount(name);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::iterateCollection(const CString& name, const CMDSDocument::Info& documentInfo, CMDSDocument::Proc proc,
		void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect documentIDs
	TNArray<CString>	documentIDs;
	mInternals->iterateCollection(name, (CMDSSQLiteDocumentBackingInfoProc) CMDSSQLiteInternals::addDocumentID,
			&documentIDs);

	// Iterate document IDs
	for (TIteratorD<CString> iterator = documentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Create document
		CMDSDocument*	document = documentInfo.create(*iterator, *((CMDSDocumentStorage*) this));

		// Call proc
		proc(*document, userData);

		// Cleanup
		Delete(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::registerIndex(const CString& name, const CMDSDocument::Info& documentInfo, UInt32 version,
		const TArray<CString>& relevantProperties, bool isUpToDate, const CString& keysSelector,
		const CDictionary& keysSelectorInfo, CMDSDocument::KeysProc keysProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Ensure this index has not already been registered
	if (mInternals->mIndexesByNameMap.get(name).hasReference())
		// Already registered
		return;

	// Note this document type
	mInternals->mDatabaseManager.note(documentInfo.getDocumentType());

	// Register index
	UInt32	lastRevision =
					mInternals->mDatabaseManager.registerIndex(documentInfo.getDocumentType(), name, version,
							isUpToDate);

	// Create index
	CMDSSQLiteIndex	index(name, documentInfo.getDocumentType(), relevantProperties, lastRevision, keysProc, userData);

	// Add to maps
	mInternals->mIndexesByNameMap.set(name, index);
	mInternals->mIndexesByDocumentTypeMap.add(documentInfo.getDocumentType(), index);

	// Update document info map
	mInternals->mDocumentInfoMap.set(documentInfo.getDocumentType(), documentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::iterateIndex(const CString& name, const TArray<CString>& keys, const CMDSDocument::Info& documentInfo,
		CMDSDocument::KeyProc keyProc, void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect documentIDs
	TNDictionary<CString>	keyMap;
	mInternals->iterateIndex(name, keys,
			(CMDSSQLiteKeyDocumentBackingInfoProc) CMDSSQLiteInternals::addDocumentIDWithKey, &keyMap);

	// Iterate keyMap
	for (TIteratorS<CDictionary::Item> iterator = keyMap.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Create document
		CMDSDocument*	document =
								documentInfo.create(iterator.getValue().mValue.getString(),
										*((CMDSDocumentStorage*) this));

		// Call proc
		keyProc(iterator.getValue().mKey, *document, userData);

		// Cleanup
		Delete(document);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLite::registerDocumentChangedProc(const CString& documentType, CMDSDocument::ChangedProc changedProc,
		void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Add
	mInternals->mDocumentChangedProcInfosMap.add(documentType, CMDSDocument::ChangedProcInfo(changedProc, userData));
}
