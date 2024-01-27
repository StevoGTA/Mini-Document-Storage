//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocumentStorage.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSDocumentStorage.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CGenericDocument

class CGenericDocument : public CMDSDocument {
	// InfoForNew
	public:
		class InfoForNew : public CMDSDocument::InfoForNew {
			public:
										// Lifecycle methods
										InfoForNew() : CMDSDocument::InfoForNew() {}

										// Instance mehtods
				const	CString&		getDocumentType() const
											{ return mDocumentType; }
						I<CMDSDocument>	create(const CString& id, CMDSDocumentStorage& documentStorage) const
											{ return I<CMDSDocument>(new CGenericDocument(id, documentStorage)); }
		};

	// Methods
	public:
										// CMDSDocument methods
				const	Info&			getInfo() const
											{ return mInfo; }

										// Class methods
		static			I<CMDSDocument>	create(const CString& id, CMDSDocumentStorage& documentStorage)
											{ return I<CMDSDocument>(new CGenericDocument(id, documentStorage)); }

	private:
										// Lifecycle methods
										CGenericDocument(const CString& id, CMDSDocumentStorage& documentStorage) :
											CMDSDocument(id, documentStorage)
											{}

	// Properties
	public:
		static	CString	mDocumentType;
		static	Info	mInfo;
};

CString				CGenericDocument::mDocumentType(OSSTR("generic"));
CMDSDocument::Info	CGenericDocument::mInfo(mDocumentType, CGenericDocument::create);

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSDocumentStorage::Internals

class CMDSDocumentStorage::Internals {
	public:
		Internals()
			{}

		TNDictionary<CMDSDocument::Info>				mDocumentCreateInfoByDocumentType;
		TNArrayDictionary<CMDSDocument::ChangedInfo>	mDocumentChangedInfoByDocumentType;
		TNDictionary<CMDSDocument::IsIncludedPerformer>	mDocumentIsIncludedPerformerBySelector;
		TNDictionary<CMDSDocument::KeysPerformer>		mDocumentKeysPerformerBySelector;
		TNDictionary<CMDSDocument::ValueInfo>			mDocumentValueInfoBySelector;
};

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
TVResult<TArray<I<CMDSDocument> > > CMDSDocumentStorage::associationGetDocumentsFrom(const CMDSDocument& fromDocument,
		const CMDSDocument::Info& toDocumentInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CMDSDocument::Collector	documentCollector(toDocumentInfo);

	// Iterate documents
	OV<SError>				error =
									associationIterateFrom(
											associationName(fromDocument.getDocumentType(),
													toDocumentInfo.getDocumentType()),
											fromDocument.getID(), toDocumentInfo.getDocumentType(),
											(CMDSDocument::Proc) CMDSDocument::Collector::addDocument,
											&documentCollector);

	return error.hasValue() ?
			TVResult<TArray<I<CMDSDocument> > >(*error) :
			TVResult<TArray<I<CMDSDocument> > >(documentCollector.getDocuments());
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSDocument::CreateResultInfo> > CMDSDocumentStorage::documentCreate(const CString& documentType,
		const TArray<CMDSDocument::CreateInfo>& documentCreateInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	return documentCreate(documentType, documentCreateInfos, CGenericDocument::InfoForNew());
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentCreateInfo(const CMDSDocument::Info& documentInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentCreateInfoByDocumentType.set(documentInfo.getDocumentType(), documentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentChangedInfos(const CMDSDocument::Info& documentInfo,
		const CMDSDocument::ChangedInfo& documentChangedInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals->mDocumentChangedInfoByDocumentType.add(documentInfo.getDocumentType(), documentChangedInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentIsIncludedPerformers(
		const TArray<CMDSDocument::IsIncludedPerformer>& documentIsIncludedPerformers)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TIteratorD<CMDSDocument::IsIncludedPerformer> iterator = documentIsIncludedPerformers.getIterator();
			iterator.hasValue(); iterator.advance())
		// Add
		mInternals->mDocumentIsIncludedPerformerBySelector.set(iterator->getSelector(), *iterator);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerDocumentKeysPerformers(
		const TArray<CMDSDocument::KeysPerformer>& documentKeysPerformers)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TIteratorD<CMDSDocument::KeysPerformer> iterator = documentKeysPerformers.getIterator(); iterator.hasValue();
			iterator.advance())
		// Add
		mInternals->mDocumentKeysPerformerBySelector.set(iterator->getSelector(), *iterator);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerValueInfos(const TArray<CMDSDocument::ValueInfo>& documentValueInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate
	for (TIteratorD<CMDSDocument::ValueInfo> iterator = documentValueInfos.getIterator(); iterator.hasValue();
			iterator.advance())
		// Add
		mInternals->mDocumentValueInfoBySelector.set(iterator->getSelector(), *iterator);
}

// MARK: Subclass methods

//----------------------------------------------------------------------------------------------------------------------
const CMDSDocument::Info& CMDSDocumentStorage::documentCreateInfo(const CString& documentType) const
//----------------------------------------------------------------------------------------------------------------------
{
	return *mInternals->mDocumentCreateInfoByDocumentType[documentType];
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocumentStorage::DocumentChangedInfos CMDSDocumentStorage::documentChangedInfos(const CString& documentType) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	const	OR<TNArray<CMDSDocument::ChangedInfo> >	documentChangedInfos =
															mInternals->mDocumentChangedInfoByDocumentType.get(
																	documentType);

	return documentChangedInfos.hasReference() ? *documentChangedInfos : TNArray<CMDSDocument::ChangedInfo>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::notifyDocumentChanged(const CMDSDocument& document,
		CMDSDocument::ChangeKind documentChangeKind) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	DocumentChangedInfos	documentChangedInfos = this->documentChangedInfos(document.getDocumentType());

	// Call document changed procs
	for (TIteratorD<CMDSDocument::ChangedInfo> iterator = documentChangedInfos.getIterator();
			iterator.hasValue(); iterator.advance())
		// Call proc
		iterator->notify(document, documentChangeKind);
}

//----------------------------------------------------------------------------------------------------------------------
OR<CMDSDocument::IsIncludedPerformer> CMDSDocumentStorage::documentIsIncludedPerformer(const CString& selector) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentIsIncludedPerformerBySelector[selector];
}

//----------------------------------------------------------------------------------------------------------------------
OR<CMDSDocument::KeysPerformer> CMDSDocumentStorage::documentKeysPerformer(const CString& selector) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentKeysPerformerBySelector[selector];
}

//----------------------------------------------------------------------------------------------------------------------
OR<CMDSDocument::ValueInfo> CMDSDocumentStorage::documentValueInfo(const CString& selector) const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mDocumentValueInfoBySelector[selector];
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
	return SError(CString(OSSTR("MDSDocumentStorage")), 4, CString(OSSTR("Missing from index: ")) + key);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownAssociationError(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 5, CString(OSSTR("Unknown association: ")) + name);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownAttachmentIDError(const CString& attachmentID)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 6, CString(OSSTR("Unknown attachmentID: ")) + attachmentID);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownCacheError(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 7, CString(OSSTR("Unknown cache: ")) + name);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownCacheValueName(const CString& valueName)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 8, CString(OSSTR("Unknown cache valueName: ")) + valueName);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownCacheValueSelector(const CString& selector)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 9, CString(OSSTR("Invalid value selector: ")) + selector);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownCollectionError(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 10, CString(OSSTR("Unknown collection: ")) + name);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownDocumentIDError(const CString& documentID)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 11, CString(OSSTR("Unknown documentID: ")) + documentID);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownDocumentTypeError(const CString& documentType)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 12, CString(OSSTR("Unknown documentType: ")) + documentType);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getUnknownIndexError(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 13, CString(OSSTR("Unknown index: ")) + name);
}

//----------------------------------------------------------------------------------------------------------------------
SError CMDSDocumentStorage::getIllegalInBatchError()
//----------------------------------------------------------------------------------------------------------------------
{
	return SError(CString(OSSTR("MDSDocumentStorage")), 14, CString(OSSTR("Illegal in batch")));
}
