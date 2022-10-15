//----------------------------------------------------------------------------------------------------------------------
//	CMDSEphemeral.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSEphemeral.h"

#include "CThread.h"
#include "CUUID.h"
#include "SError.h"
#include "TLockingDictionary.h"
#include "TMDSBatchInfo.h"
#include "TMDSCollection.h"
#include "TMDSIndex.h"

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

typedef	TMDSBatchInfo<CDictionary>								CMDSEphemeralBatchInfo;
typedef	CMDSEphemeralBatchInfo::DocumentInfo<CDictionary>		CMDSEphemeralBatchDocumentInfo;

typedef	TMDSCollection<CString, TNArray<CString> >				CMDSEphemeralCollection;
typedef	CMDSEphemeralCollection::UpdateInfo<TNArray<CString> >	CMDSEphemeralCollectionUpdateInfo;

typedef	TMDSIndex<CString>										CMDSEphemeralIndex;
typedef	CMDSEphemeralIndex::UpdateInfo<CString>					CMDSEphemeralIndexUpdateInfo;

typedef	TMDSUpdateInfo<CString>									CMDSEphemeralUpdateInfo;

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

		static	OV<TSet<CString> >			updateCollectionValues(const OR<TSet<CString> >& currentValues,
													const CMDSEphemeralCollectionUpdateInfo* updateInfo);
		static	OV<TSet<CString> >			removeCollectionValues(const OR<TSet<CString> >& currentValues,
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

				TNLockingDictionary<CMDSEphemeralBatchInfo>				mBatchInfoMap;

				TNDictionary<CMDSEphemeralDocumentBacking>				mDocumentBackingByIDMap;
				TNLockingArrayDictionary<CMDSDocument::ChangedProcInfo>	mDocumentChangedProcInfosMap;
				TNDictionary<TSet<CString> >							mDocumentIDsByTypeMap;
				TNLockingDictionary<CMDSDocument::Info>					mDocumentInfoMap;
				TNLockingDictionary<TNumber<UInt32> >					mDocumentLastRevisionMap;
				CReadPreferringLock										mDocumentMapsLock;
				TNLockingDictionary<CDictionary>						mDocumentsBeingCreatedPropertyMapMap;

/*
	Name:
->		Pairs of (from, to)
			-or-
		From
			array of to
*/
TNLockingArrayDictionary<AssociationPair>	mAssocationMap;

				TNLockingDictionary<CMDSEphemeralCollection>			mCollectionsByNameMap;
				TNLockingArrayDictionary<CMDSEphemeralCollection>		mCollectionsByDocumentTypeMap;
				TNLockingDictionary<TSet<CString> >						mCollectionValuesMap;

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
	const	OR<TNumber<UInt32> >	currentRevision = mDocumentLastRevisionMap[documentType];
			UInt32					nextRevision = currentRevision.hasReference() ? **currentRevision + 1 : 1;

	// Store
	mDocumentLastRevisionMap.set(documentType, TNumber<UInt32>(nextRevision));

	return nextRevision;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeralInternals::updateCollections(const CString& documentType,
		const TArray<CMDSEphemeralUpdateInfo>& updateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve collections for this document type
	OR<TArray<CMDSEphemeralCollection> >	collections = mCollectionsByDocumentTypeMap.get(documentType);
	if (!collections.hasReference()) return;

	// Iterate collections
	for (TIteratorD<CMDSEphemeralCollection> iterator = collections->getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Query update info
		CMDSEphemeralCollectionUpdateInfo	updateInfo = iterator->update(updateInfos);

		// Update storage
		mCollectionValuesMap.update(iterator->getName(),
				(TNLockingDictionary<TSet<CString> >::UpdateProc) updateCollectionValues, &updateInfo);
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
				(TNLockingDictionary<TSet<CString> >::UpdateProc) CMDSEphemeralInternals::removeCollectionValues,
				(TSet<CString>*) &removedDocumentIDs);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeralInternals::updateIndexes(const CString& documentType,
		const TArray<CMDSEphemeralUpdateInfo>& updateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve indexes for this document type
	OR<TArray<CMDSEphemeralIndex> >	indexes = mIndexesByDocumentTypeMap.get(documentType);
	if (!indexes.hasReference()) return;

	// Iterate indexes
	for (TIteratorD<CMDSEphemeralIndex> iterator = indexes->getIterator(); iterator.hasValue(); iterator.advance()) {
		// Query update info
		CMDSEphemeralIndexUpdateInfo	updateInfo = iterator->update(updateInfos);
		if (updateInfo.mKeysInfos.isEmpty()) continue;

		// Update storage
		TSet<CString>	documentIDs(updateInfo.mKeysInfos, (CString (*)(CArray::ItemRef)) getValueFromKeysInfo);
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
	OR<TArray<CMDSDocument::ChangedProcInfo> >	array = mDocumentChangedProcInfosMap.get(documentType);
	if (array.hasReference())
		// Iterate all proc infos
		for (TIteratorD<CMDSDocument::ChangedProcInfo> iterator = array->getIterator(); iterator.hasValue();
				iterator.advance())
			// Call proc
			iterator->notify(document, changeKind);
}

// MARK: Class methods

//----------------------------------------------------------------------------------------------------------------------
OV<TSet<CString> > CMDSEphemeralInternals::updateCollectionValues(const OR<TSet<CString> >& currentValues,
		const CMDSEphemeralCollectionUpdateInfo* updateInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if have current values
	TSet<CString>	updatedValues;
	if (currentValues.hasReference())
		// Have current values
		updatedValues = currentValues->removeFrom(updateInfo->mNotIncludedValues)
			.addFrom(updateInfo->mIncludedValues);
	else
		// Don't have current values
		updatedValues = TSet<CString>(updateInfo->mIncludedValues);

	return !updatedValues.isEmpty() ? OV<TSet<CString> >(updatedValues) : OV<TSet<CString> >();
}

//----------------------------------------------------------------------------------------------------------------------
OV<TSet<CString> > CMDSEphemeralInternals::removeCollectionValues(const OR<TSet<CString> >& currentValues,
		const TSet<CString>* documentIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if have current values
	TSet<CString>	updatedValues;
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
			TSet<CString>						removedDocumentIDs;

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
					TSet<CString>	changedProperties =
											batchDocumentInfo.getUpdatedPropertyMap().getKeys()
												.addFrom(batchDocumentInfo.getRemovedProperties());
					updateInfos +=
							CMDSEphemeralUpdateInfo(*document, existingDocumentBacking->mRevision, documentID,
									changedProperties);

					// Call document changed procs
					internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kUpdated);
				}
			} else {
				// Add document
				CMDSEphemeralDocumentBacking	documentBacking(internals->getNextRevision(documentType),
														batchDocumentInfo.getCreationUniversalTime(),
														batchDocumentInfo.getModificationUniversalTime(),
														batchDocumentInfo.getUpdatedPropertyMap());
				internals->mDocumentBackingByIDMap.set(documentID, documentBacking);

				OR<TSet<CString> >	set = internals->mDocumentIDsByTypeMap.get(documentType);
				if (set.hasReference())
					set->add(documentID);
				else
					internals->mDocumentIDsByTypeMap.set(documentType, TSet<CString>(documentID));

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
					internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kUpdated);
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
					internals->notifyDocumentChanged(documentType, *document, CMDSDocument::kRemoved);
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
	const	OR<CMDSEphemeralBatchInfo>	batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
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
		CDictionary	propertyMap = *mInternals->mDocumentsBeingCreatedPropertyMapMap.get(documentID);
		mInternals->mDocumentsBeingCreatedPropertyMapMap.remove(documentID);

		// Add document
		CMDSEphemeralDocumentBacking	documentBacking(mInternals->getNextRevision(infoForNew.getDocumentType()),
												universalTime, universalTime, propertyMap);

		// Update maps
		mInternals->mDocumentMapsLock.lockForWriting();

		mInternals->mDocumentBackingByIDMap.set(documentID, documentBacking);

		OR<TSet<CString> >	set = mInternals->mDocumentIDsByTypeMap.get(infoForNew.getDocumentType());
		if (set.hasReference())
			// Already have a document for this type
			set->add(documentID);
		else
			// First document for this type
			mInternals->mDocumentIDsByTypeMap.set(infoForNew.getDocumentType(), TSet<CString>(documentID));

		mInternals->mDocumentMapsLock.unlockForWriting();

		// Update collections and indexes
		CMDSEphemeralUpdateInfo	updateInfo(*document, documentBacking.mRevision, documentID);
		mInternals->updateCollections(infoForNew.getDocumentType(), TSArray<CMDSEphemeralUpdateInfo>(updateInfo));
		mInternals->updateIndexes(infoForNew.getDocumentType(), TSArray<CMDSEphemeralUpdateInfo>(updateInfo));

		// Call document changed procs
		mInternals->notifyDocumentChanged(infoForNew.getDocumentType(), *document, CMDSDocument::kCreated);

		return I<CMDSDocument>(document);
	}
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
	const	OR<CMDSEphemeralBatchInfo>			batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo =
														batchInfo.hasReference() ?
																batchInfo->getDocumentInfo(document.getID()) :
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
	const	OR<CMDSEphemeralBatchInfo>			batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo =
														batchInfo.hasReference() ?
																batchInfo->getDocumentInfo(document.getID()) :
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
	const	OR<CMDSEphemeralBatchInfo>			batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo =
														batchInfo.hasReference() ?
																batchInfo->getDocumentInfo(document.getID()) :
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
	const	OR<CMDSEphemeralBatchInfo>	batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	if (batchInfo.hasReference()) {
		// In batch
		const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo = batchInfo->getDocumentInfo(documentID);
		if (batchDocumentInfo.hasReference())
			// Have document in batch
			batchDocumentInfo->set(property, value);
		else {
			// Don't have document in batch
			UniversalTime	universalTime = SUniversalTime::getCurrent();
			batchInfo->addDocument(documentType, documentID, OI<CDictionary>(CDictionary()), universalTime,
					universalTime,
					(CMDSEphemeralBatchInfo::DocumentPropertyValueProc)
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
		mInternals->notifyDocumentChanged(documentType, document, CMDSDocument::kUpdated);
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
	const	OR<CMDSEphemeralBatchInfo>	batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	if (batchInfo.hasReference()) {
		// In batch
		const	OR<CMDSEphemeralBatchDocumentInfo>	batchDocumentInfo = batchInfo->getDocumentInfo(documentID);
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
		mInternals->mDocumentMapsLock.lockForWriting();
		const	OR<CMDSEphemeralDocumentBacking>	documentBacking = mInternals->mDocumentBackingByIDMap[documentID];
		if (documentBacking.hasReference())
			// Reset active
			documentBacking->mActive = false;
		mInternals->mDocumentMapsLock.unlockForWriting();

		// Remove from collections and indexes
		TSet<CString>	documentIDs(documentID);
		mInternals->updateCollections(documentIDs);
		mInternals->updateIndexes(documentIDs);

		// Call document changed procs
		mInternals->notifyDocumentChanged(documentType, document, CMDSDocument::kRemoved);
	}
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterate(const CMDSDocument::Info& documentInfo, CMDSDocument::Proc proc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect document IDs
	mInternals->mDocumentMapsLock.lockForReading();
	const	OR<TSet<CString> >	documentIDs = mInternals->mDocumentIDsByTypeMap[documentInfo.getDocumentType()];
			TSet<CString>		filteredDocumentIDs(
										documentIDs.hasReference() ? *documentIDs : TSet<CString>(),
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
	CMDSEphemeralBatchInfo	batchInfo;

	// Store
	mInternals->mBatchInfoMap.set(CThread::getCurrentRefAsString(), batchInfo);

	// Call proc
	BatchResult	batchResult = batchProc(userData);

	// Remove
	mInternals->mBatchInfoMap.remove(CThread::getCurrentRefAsString());

	// Check result
	if (batchResult == kCommit)
		// Iterate all document changes
		batchInfo.iterate((CMDSEphemeralBatchDocumentInfo::MapProc) CMDSEphemeralInternals::batchMap, mInternals);
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
	for (TIteratorD<AssociationUpdate> iterator = updates.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Check action
		if (iterator->mAction == AssociationUpdate::kAdd)
			// Add
			mInternals->mAssocationMap.add(name,
					CMDSEphemeralInternals::AssociationPair(iterator->mFromDocument.getID(),
							iterator->mToDocument.getID()));
//		else
//			// Remove
	}
}

////----------------------------------------------------------------------------------------------------------------------
//void CMDSEphemeral::iterateAssociationFrom(const CString& name, const CMDSDocument& fromDocument,
//		CMDSDocument::Proc proc, void* userData) const
////----------------------------------------------------------------------------------------------------------------------
//{
//	AssertFailUnimplemented();
//}
//
//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterateAssociationTo(const CString& name, const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument& toDocument, CMDSDocument::Proc proc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve association pairs
	OR<TArray<CMDSEphemeralInternals::AssociationPair> >	associationPairs = mInternals->mAssocationMap.get(name);
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
	// Ensure this collectino has not already been registered
	if (mInternals->mCollectionsByNameMap.contains(name)) return;

	// Create collection
	CMDSEphemeralCollection	collection(name, documentInfo.getDocumentType(), relevantProperties, 0, isIncludedProc,
									userData);

	// Add to maps
	mInternals->mCollectionsByNameMap.set(name, collection);
	mInternals->mCollectionsByDocumentTypeMap.add(documentInfo.getDocumentType(), collection);

	// Update creation proc map
	mInternals->mDocumentInfoMap.set(documentInfo.getDocumentType(), documentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSEphemeral::getCollectionDocumentCount(const CString& name) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get values
	const	OR<TSet<CString> >	values = mInternals->mCollectionValuesMap[name];

	return values.hasReference() ? values->getCount() : 0;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSEphemeral::iterateCollection(const CString& name, const CMDSDocument::Info& documentInfo,
		CMDSDocument::Proc proc, void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get values
	const	OR<TSet<CString> >	values = mInternals->mCollectionValuesMap[name];
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
