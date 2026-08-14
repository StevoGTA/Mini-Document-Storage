//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocumentStorage.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSDocumentStorage.h"

#include "TLockingDictionary.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocumentStorage::Internals

class CMDSDocumentStorage::Internals {
	public:
		class GenericDocument : public CMDSDocument {
			public:
												GenericDocument(const CString& id,
														CMDSDocumentStorage& documentStorage) :
													CMDSDocument(id, documentStorage)
													{}

						const	Info&			getInfo() const
													{ return mInfo; }

								I<CMDSDocument>	makeI() const
													{ return I<CMDSDocument>(
															new GenericDocument(getID(), getDocumentStorage())); }

				static			I<CMDSDocument>	create(const CString& id, CMDSDocumentStorage& documentStorage)
													{ return I<CMDSDocument>(
															new GenericDocument(id, documentStorage)); }


			public:
				static	Info	mInfo;
		};

	public:
		class InfoForNewAdapter : public CMDSDocument::InfoForNew {
			public:
										// Lifecycle methods
										InfoForNewAdapter(const CString& documentType) :
											CMDSDocument::InfoForNew(),
													mDocumentType(documentType)
											{}

										// Instance mehtods
				const	CString&		getDocumentType() const
											{ return mDocumentType; }
						I<CMDSDocument>	create(const CString& id, CMDSDocumentStorage& documentStorage) const
											{ return I<CMDSDocument>(new GenericDocument(id, documentStorage)); }

				CString	mDocumentType;
		};

	public:
						Internals()
							{}

		static	void	updateDocumentMap(const CString& key, const I<CMDSDocument>& document,
								TNDictionary<I<CMDSDocument> >* documentMap)
							{ documentMap->set(key, document); }

		TNDictionary<CMDSDocument::Info>									mDocumentCreateInfoByDocumentType;
		TNLockingArrayDictionary<CMDSDocument::CreatedCallback>				mDocumentCreatedCallbackByDocumentType;
		TNLockingArrayDictionary<CMDSDocument::UpdatedCallback>				mDocumentUpdatedCallbackByDocumentType;
		TNLockingArrayDictionary<CMDSDocument::RemovedCallback>				mDocumentRemovedCallbackByDocumentType;
		TNLockingArrayDictionary<CMDSDocument::AttachmentCreatedCallback>	mDocumentAttachmentCreatedCallbackByDocumentType;
		TNLockingArrayDictionary<CMDSDocument::AttachmentUpdatedCallback>	mDocumentAttachmentUpdatedCallbackByDocumentType;
		TNLockingArrayDictionary<CMDSDocument::AttachmentRemovedCallback>	mDocumentAttachmentRemovedCallbackByDocumentType;
		TNDictionary<DocumentIsIncludedPerformerInfo>						mDocumentIsIncludedPerformerInfoBySelector;
		TNDictionary<CMDSDocument::KeysPerformer>							mDocumentKeysPerformerBySelector;
		TNDictionary<CMDSDocument::ValueInfo>								mDocumentValueInfoBySelector;
		TNDictionary<SValue>												mEphemeralValueByKey;
};

CMDSDocument::Info	CMDSDocumentStorage::Internals::GenericDocument::mInfo(CString(OSSTR("generic")), create);

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSDocumentStorage

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::CMDSDocumentStorage()
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = new Internals();
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::~CMDSDocumentStorage()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<I<CMDSDocument> > > CMDSDocumentStorage::associationGetDocumentsFrom(
		const CMDSDocument& fromDocument, const CMDSDocument::Info& toDocumentInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Register
	registerDocumentCreateInfo(toDocumentInfo);

	// Setup
	CMDSDocument::Collector	documentCollector(toDocumentInfo);

	// Iterate documents
	OV<SError>	error =
						associationIterateFrom(
								associationName(fromDocument.getDocumentType(), toDocumentInfo.getDocumentType()),
								fromDocument.getID(), toDocumentInfo.getDocumentType(),
								(CMDSDocument::Proc) CMDSDocument::Collector::addDocument, &documentCollector);

	return error.hasValue() ?
			TVResult<TArray<I<CMDSDocument> > >(*error) :
			TVResult<TArray<I<CMDSDocument> > >(documentCollector.getDocuments());
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<I<CMDSDocument> > > CMDSDocumentStorage::associationGetDocumentsTo(
		const CMDSDocument::Info& fromDocumentInfo, const CMDSDocument& toDocument)
//----------------------------------------------------------------------------------------------------------------------
{
	// Register
	registerDocumentCreateInfo(fromDocumentInfo);

	// Setup
	CMDSDocument::Collector	documentCollector(fromDocumentInfo);

	// Iterate documents
	OV<SError>	error =
						associationIterateTo(
								associationName(fromDocumentInfo.getDocumentType(), toDocument.getDocumentType()),
								fromDocumentInfo.getDocumentType(), toDocument.getID(),
								(CMDSDocument::Proc) CMDSDocument::Collector::addDocument, &documentCollector);

	return error.hasValue() ?
			TVResult<TArray<I<CMDSDocument> > >(*error) :
			TVResult<TArray<I<CMDSDocument> > >(documentCollector.getDocuments());
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CDictionary> > CMDSDocumentStorage::associationGetDetailValues(const CString& name,
		const TArray<CString>& fromDocumentIDs, const CString& cacheName, const TArray<CString>& cachedValueNames) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get detail values
	TVResult<SValue>	value =
								associationGetValues(name, CMDSAssociation::kGetValueActionDetail, fromDocumentIDs,
										cacheName, cachedValueNames);
	ReturnValueIfResultError(value, TVResult<TArray<CDictionary> >(value.getError()));

	return TVResult<TArray<CDictionary> >(value->getArrayOfDictionaries());
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<CDictionary> CMDSDocumentStorage::associationGetSumValues(const CString& name,
		const TArray<CString>& fromDocumentIDs, const CString& cacheName, const TArray<CString>& cachedValueNames) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get sum values
	TVResult<SValue>	value =
								associationGetValues(name, CMDSAssociation::kGetValueActionDetail, fromDocumentIDs,
										cacheName, cachedValueNames);
	ReturnValueIfResultError(value, TVResult<CDictionary>(value.getError()));

	return TVResult<CDictionary>(value->getDictionary());
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSDocumentStorage::collectionRegister(const CString& name, const CString& documentType,
		const OV<TArray<CString> >& relevantProperties, bool isUpToDate, const CDictionary& isIncludedInfo,
		const CString& isIncludedSelector)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	DocumentIsIncludedPerformerInfo&	documentIsIncludedPerformerInfo =
														this->documentIsIncludedPerformerInfo(isIncludedSelector);

	return collectionRegister(name, documentType, relevantProperties, isUpToDate, isIncludedInfo,
			documentIsIncludedPerformerInfo.getDocumentIsIncludedPerformer());
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::CreateResultInfo> > CMDSDocumentStorage::documentCreate(const CString& documentType,
		const TArray<CMDSDocument::CreateInfo>& documentCreateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	return documentCreate(Internals::InfoForNewAdapter(documentType), documentCreateInfos);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<I<CMDSDocument> > CMDSDocumentStorage::documentCreate(const CMDSDocument::InfoForNew& documentInfoForNew)
//----------------------------------------------------------------------------------------------------------------------
{
	// Create document
	TVResult<TArray<CMDSDocument::CreateResultInfo> >	documentsCreateResultInfo =
																documentCreate(documentInfoForNew,
																		TNArray<CMDSDocument::CreateInfo>(
																				CMDSDocument::CreateInfo(OV<CString>(),
																						OV<UniversalTime>(),
																						OV<UniversalTime>(),
																						CDictionary())));
	ReturnValueIfResultError(documentsCreateResultInfo,
			TVResult<I<CMDSDocument> >(documentsCreateResultInfo.getError()));

	return TVResult<I<CMDSDocument> >((*documentsCreateResultInfo)[0].getDocument());
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::DocumentAttachmentInfoResult CMDSDocumentStorage::documentAttachmentAdd(
		const CString& documentType, const CString& documentID, const CString& type, const CDictionary& info,
		const CData& content)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CDictionary	infoUse(info);
	infoUse.set(CString(OSSTR("type")), type);

	return documentAttachmentAdd(documentType, documentID, infoUse, content);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TDictionary<I<CMDSDocument> > > CMDSDocumentStorage::indexDocumentMap(const CString& name,
		const CString& documentType, const TArray<CString>& keys)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	TNDictionary<I<CMDSDocument> >	documentMap;

	// Iterate index
	OV<SError>	error =
						indexIterate(name, documentType, keys, (CMDSDocument::KeyProc) Internals::updateDocumentMap,
								&documentMap);
	ReturnValueIfError(error, TVResult<TDictionary<I<CMDSDocument> > >(*error));

	return TVResult<TDictionary<I<CMDSDocument> > >(documentMap);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentCreateInfo(const CMDSDocument::Info& documentInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if already have it
	if (!mInternals->mDocumentCreateInfoByDocumentType.contains(documentInfo.getDocumentType()))
		// Add
		mInternals->mDocumentCreateInfoByDocumentType.set(documentInfo.getDocumentType(), documentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
const CMDSDocument::Info& CMDSDocumentStorage::documentCreateInfo(const CString& documentType) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Get info
	const	OR<CMDSDocument::Info>	documentCreateInfo = mInternals->mDocumentCreateInfoByDocumentType[documentType];

	return documentCreateInfo.hasReference() ? *documentCreateInfo : Internals::GenericDocument::mInfo;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentCreatedCallback(const CMDSDocument::Info& documentInfo,
		const CMDSDocument::CreatedCallback& documentCreatedCallback)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentCreatedCallbackByDocumentType.add(documentInfo.getDocumentType(), documentCreatedCallback);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::DocumentCreatedCallbacks CMDSDocumentStorage::documentCreatedCallbacks(const CString& documentType)
		const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<TNArray<CMDSDocument::CreatedCallback> >	documentCreatedCallbacks =
																mInternals->mDocumentCreatedCallbackByDocumentType
																		.get(documentType);

	return documentCreatedCallbacks.hasReference() ?
			*documentCreatedCallbacks : TNArray<CMDSDocument::CreatedCallback>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentUpdatedCallback(const CMDSDocument::Info& documentInfo,
		const CMDSDocument::UpdatedCallback& documentUpdatedCallback)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentUpdatedCallbackByDocumentType.add(documentInfo.getDocumentType(), documentUpdatedCallback);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::DocumentUpdatedCallbacks CMDSDocumentStorage::documentUpdatedCallbacks(const CString& documentType)
		const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<TNArray<CMDSDocument::UpdatedCallback> >	documentUpdatedCallbacks =
																mInternals->mDocumentUpdatedCallbackByDocumentType
																		.get(documentType);

	return documentUpdatedCallbacks.hasReference() ?
			*documentUpdatedCallbacks : TNArray<CMDSDocument::UpdatedCallback>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentRemovedCallback(const CMDSDocument::Info& documentInfo,
		const CMDSDocument::RemovedCallback& documentRemovedCallback)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentRemovedCallbackByDocumentType.add(documentInfo.getDocumentType(), documentRemovedCallback);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::DocumentRemovedCallbacks CMDSDocumentStorage::documentRemovedCallbacks(const CString& documentType)
		const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<TNArray<CMDSDocument::RemovedCallback> >	documentRemovedCallbacks =
																mInternals->mDocumentRemovedCallbackByDocumentType
																		.get(documentType);

	return documentRemovedCallbacks.hasReference() ?
			*documentRemovedCallbacks : TNArray<CMDSDocument::RemovedCallback>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentAttachmentCreatedCallback(const CMDSDocument::Info& documentInfo,
		const CMDSDocument::AttachmentCreatedCallback& documentAttachmentCreatedCallback)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentAttachmentCreatedCallbackByDocumentType.add(documentInfo.getDocumentType(),
			documentAttachmentCreatedCallback);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::DocumentAttachmentCreatedCallbacks CMDSDocumentStorage::documentAttachmentCreatedCallbacks(
		const CString& documentType) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<TNArray<CMDSDocument::AttachmentCreatedCallback> >	documentAttachmentCreatedCallbacks =
																		mInternals->
																				mDocumentAttachmentCreatedCallbackByDocumentType
																				.get(documentType);

	return documentAttachmentCreatedCallbacks.hasReference() ?
			*documentAttachmentCreatedCallbacks : TNArray<CMDSDocument::AttachmentCreatedCallback>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentAttachmentUpdatedCallback(const CMDSDocument::Info& documentInfo,
		const CMDSDocument::AttachmentUpdatedCallback& documentAttachmentUpdatedCallback)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentAttachmentUpdatedCallbackByDocumentType.add(documentInfo.getDocumentType(),
			documentAttachmentUpdatedCallback);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::DocumentAttachmentUpdatedCallbacks CMDSDocumentStorage::documentAttachmentUpdatedCallbacks(
		const CString& documentType) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<TNArray<CMDSDocument::AttachmentUpdatedCallback> >	documentAttachmentUpdatedCallbacks =
																		mInternals->
																				mDocumentAttachmentUpdatedCallbackByDocumentType
																				.get(documentType);

	return documentAttachmentUpdatedCallbacks.hasReference() ?
			*documentAttachmentUpdatedCallbacks : TNArray<CMDSDocument::AttachmentUpdatedCallback>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentAttachmentRemovedCallback(const CMDSDocument::Info& documentInfo,
		const CMDSDocument::AttachmentRemovedCallback& documentAttachmentRemovedCallback)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentAttachmentRemovedCallbackByDocumentType.add(documentInfo.getDocumentType(),
			documentAttachmentRemovedCallback);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::DocumentAttachmentRemovedCallbacks CMDSDocumentStorage::documentAttachmentRemovedCallbacks(
		const CString& documentType) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<TNArray<CMDSDocument::AttachmentRemovedCallback> >	documentAttachmentRemovedCallbacks =
																			mInternals->
																					mDocumentAttachmentRemovedCallbackByDocumentType
																					.get(documentType);

	return documentAttachmentRemovedCallbacks.hasReference() ?
			*documentAttachmentRemovedCallbacks : TNArray<CMDSDocument::AttachmentRemovedCallback>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentIsIncludedPerformerInfos(
		const TArray<DocumentIsIncludedPerformerInfo>& documentIsIncludedPerformerInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TArray<DocumentIsIncludedPerformerInfo>::Iterator iterator = documentIsIncludedPerformerInfos.getIterator();
			iterator; iterator++)
		// Add
		mInternals->mDocumentIsIncludedPerformerInfoBySelector.set(
				iterator->getDocumentIsIncludedPerformer().getSelector(), *iterator);
}

//----------------------------------------------------------------------------------------------------------------------
const CMDSDocumentStorage::DocumentIsIncludedPerformerInfo& CMDSDocumentStorage::documentIsIncludedPerformerInfo(
		const CString& selector) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve
	const	OR<DocumentIsIncludedPerformerInfo>&	documentIsIncludedPerformerInfo =
															mInternals->mDocumentIsIncludedPerformerInfoBySelector[
																	selector];
	AssertFailIf(!documentIsIncludedPerformerInfo.hasReference());

	return *documentIsIncludedPerformerInfo;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentKeysPerformers(
		const TArray<CMDSDocument::KeysPerformer>& documentKeysPerformers)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TArray<CMDSDocument::KeysPerformer>::Iterator iterator = documentKeysPerformers.getIterator(); iterator;
			iterator++)
		// Add
		mInternals->mDocumentKeysPerformerBySelector.set(iterator->getSelector(), *iterator);
}

//----------------------------------------------------------------------------------------------------------------------
const CMDSDocument::KeysPerformer& CMDSDocumentStorage::documentKeysPerformer(const CString& selector) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve
	const	OR<CMDSDocument::KeysPerformer>	documentKeysPerformer =
													mInternals->mDocumentKeysPerformerBySelector[selector];
	AssertFailIf(!documentKeysPerformer.hasReference());

	return *documentKeysPerformer;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerValueInfos(const TArray<CMDSDocument::ValueInfo>& documentValueInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TArray<CMDSDocument::ValueInfo>::Iterator iterator = documentValueInfos.getIterator(); iterator; iterator++)
		// Add
		mInternals->mDocumentValueInfoBySelector.set(iterator->getSelector(), *iterator);
}

//----------------------------------------------------------------------------------------------------------------------
const CMDSDocument::ValueInfo& CMDSDocumentStorage::documentValueInfo(const CString& selector) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Retrieve
	const	OR<CMDSDocument::ValueInfo>&	documentValueInfo = *mInternals->mDocumentValueInfoBySelector[selector];
	AssertFailIf(!documentValueInfo.hasReference());

	return *documentValueInfo;
}

//----------------------------------------------------------------------------------------------------------------------
OV<SValue> CMDSDocumentStorage::ephemeralValue(const CString& key) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mEphemeralValueByKey.getOValue(key);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::storeEphemeral(const CString& key, const OV<SValue>& value)
//----------------------------------------------------------------------------------------------------------------------
{
	// Store
	mInternals->mEphemeralValueByKey.set(key, value);
}

// MARK: Subclass methods

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::notifyDocumentCreated(const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	DocumentCreatedCallbacks	documentCreatedCallbacks_ = documentCreatedCallbacks(document->getDocumentType());

	// Call document created procs
	for (TArray<CMDSDocument::CreatedCallback>::Iterator iterator = documentCreatedCallbacks_.getIterator(); iterator;
			iterator++)
		// Call proc
		iterator->notify(document);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::notifyDocumentUpdated(const I<CMDSDocument>& document, const TSet<CString>& updatedProperties,
		const TSet<CString>& removedProperties) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	DocumentUpdatedCallbacks	documentUpdatedCallbacks_ = documentUpdatedCallbacks(document->getDocumentType());
	if (documentUpdatedCallbacks_.isEmpty())
		// Nobody listening, so don't compose the union
		return;

	TNSet<CString>	changedProperties = TNSet<CString>(updatedProperties).insertFrom(removedProperties);

	// Call document updated procs
	for (TArray<CMDSDocument::UpdatedCallback>::Iterator iterator = documentUpdatedCallbacks_.getIterator(); iterator;
			iterator++)
		// Call proc
		iterator->notify(document, updatedProperties, removedProperties, changedProperties);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::notifyDocumentRemoved(const I<CMDSDocument>& document) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	DocumentRemovedCallbacks	documentRemovedCallbacks_ = documentRemovedCallbacks(document->getDocumentType());

	// Call document removed procs
	for (TArray<CMDSDocument::RemovedCallback>::Iterator iterator = documentRemovedCallbacks_.getIterator(); iterator;
			iterator++)
		// Call proc
		iterator->notify(document);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::notifyDocumentAttachmentCreated(const I<CMDSDocument>& document,
		const CString& attachmentID, const CMDSDocument::AttachmentInfo& attachmentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	DocumentAttachmentCreatedCallbacks	documentAttachmentCreatedCallbacks_ =
												documentAttachmentCreatedCallbacks(document->getDocumentType());

	// Call document attachment created procs
	for (TArray<CMDSDocument::AttachmentCreatedCallback>::Iterator iterator =
					documentAttachmentCreatedCallbacks_.getIterator();
			iterator; iterator++)
		// Call proc
		iterator->notify(document, attachmentID, attachmentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::notifyDocumentAttachmentUpdated(const I<CMDSDocument>& document,
		const CString& attachmentID, const CMDSDocument::AttachmentInfo& attachmentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	DocumentAttachmentUpdatedCallbacks	documentAttachmentUpdatedCallbacks_ =
												documentAttachmentUpdatedCallbacks(document->getDocumentType());

	// Call document attachment updated procs
	for (TArray<CMDSDocument::AttachmentUpdatedCallback>::Iterator iterator =
					documentAttachmentUpdatedCallbacks_.getIterator();
			iterator; iterator++)
		// Call proc
		iterator->notify(document, attachmentID, attachmentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::notifyDocumentAttachmentRemoved(const I<CMDSDocument>& document,
		const CString& attachmentID) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	DocumentAttachmentRemovedCallbacks	documentAttachmentRemovedCallbacks_ =
											documentAttachmentRemovedCallbacks(document->getDocumentType());

	// Call document attachment removed procs
	for (TArray<CMDSDocument::AttachmentRemovedCallback>::Iterator iterator =
					documentAttachmentRemovedCallbacks_.getIterator();
			iterator; iterator++)
		// Call proc
		iterator->notify(document, attachmentID);
}

// MARK: Class methods

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getInvalidCountError(UInt32 count)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 1, CString(OSSTR("Invalid count: ")) + CString(count));
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getInvalidDocumentTypeError(const CString& documentType)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 2, CString(OSSTR("Invalid documentType: ")) + documentType);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getInvalidStartIndexError(UInt32 startIndex)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 3,
			CString(OSSTR("Invalid startIndex: ")) + CString(startIndex));
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getMissingFromIndexError(const CString& key)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 11, CString(OSSTR("Missing from index: ")) + key);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getMissingValueNamesError()
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 12, CString(OSSTR("Missing valueNames")));
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownAssociationError(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 21, CString(OSSTR("Unknown association: ")) + name);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownAttachmentIDError(const CString& attachmentID)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 31, CString(OSSTR("Unknown attachmentID: ")) + attachmentID);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownCacheError(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 41, CString(OSSTR("Unknown cache: ")) + name);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownCacheValueName(const CString& valueName)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 42, CString(OSSTR("Unknown cache valueName: ")) + valueName);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownCollectionError(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 51, CString(OSSTR("Unknown collection: ")) + name);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownDocumentIDError(const CString& documentID)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 61, CString(OSSTR("Unknown documentID: ")) + documentID);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownDocumentTypeError(const CString& documentType)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 62, CString(OSSTR("Unknown documentType: ")) + documentType);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownIndexError(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 71, CString(OSSTR("Unknown index: ")) + name);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getIllegalInBatchError()
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 81, CString(OSSTR("Illegal in batch")));
}
