//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocumentStorage.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSDocumentStorage.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Local procs declaration

static	void	sAddDocumentToArray(CMDSDocument& document, TCArray<CMDSDocument>* documents);
static	void	sAddDocumentToDictionary(const CString& key, const CMDSDocument& document,
						TCDictionary<CMDSDocument>* dictionary);
static	CString	sComposeAssociationName(const CString& fromDocumentType, const CString& toDocumentType);

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSDocumentStorage

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
TArray<CMDSDocument> CMDSDocumentStorage::getDocuments(const CMDSDocument::Info& info) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect documents
	TCArray<CMDSDocument>	documents;
	((CMDSDocumentStorage*) this)->iterate(info, (CMDSDocument::Proc) sAddDocumentToArray, &documents);

	return documents;
}

//----------------------------------------------------------------------------------------------------------------------
TArray<CMDSDocument> CMDSDocumentStorage::getDocuments(const CMDSDocument::Info& info,
		const TArray<CString>& documentIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect documents
	TCArray<CMDSDocument>	documents;
	iterate(info, documentIDs, (CMDSDocument::Proc) sAddDocumentToArray, &documents);

	return documents;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::registerAssociation(const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument::Info& toDocumentInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	registerAssociation(sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocumentInfo.getDocumentType()),
			fromDocumentInfo, toDocumentInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::updateAssociation(const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument::Info& toDocumentInfo, const TArray<AssociationUpdate>& updates)
//----------------------------------------------------------------------------------------------------------------------
{
	updateAssociation(sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocumentInfo.getDocumentType()),
			updates);
}

////----------------------------------------------------------------------------------------------------------------------
//void CMDSDocumentStorage::iterateAssociationFrom(const CMDSDocument& fromDocument,
//		const CMDSDocument::Info& toDocumentInfo, CMDSDocument::Proc proc, void* userData) const
////----------------------------------------------------------------------------------------------------------------------
//{
//	iterateAssociationFrom(sComposeAssociationName(fromDocument.getDocumentType(), toDocumentInfo.getDocumentType()),
//			fromDocument, proc, userData);
//}
//
//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::iterateAssociationTo(const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument& toDocument, CMDSDocument::Proc proc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	iterateAssociationTo(sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocument.getDocumentType()),
			fromDocumentInfo, toDocument, proc, userData);
}

//----------------------------------------------------------------------------------------------------------------------
TArray<CMDSDocument> CMDSDocumentStorage::getDocumentsAssociatedTo(const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument& toDocument)
//----------------------------------------------------------------------------------------------------------------------
{
	// Iterate association
	TCArray<CMDSDocument>	documents;
	iterateAssociationTo(sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocument.getDocumentType()),
			fromDocumentInfo, toDocument, (CMDSDocument::Proc) sAddDocumentToArray, &documents);

	return documents;
}

////----------------------------------------------------------------------------------------------------------------------
//SValue CMDSDocumentStorage::retrieveAssociationValue(const CMDSDocument::Info& fromDocumentInfo,
//		const CMDSDocument& toDocument, const CString& summedCachedValueName)
////----------------------------------------------------------------------------------------------------------------------
//{
//	return retrieveAssociationValue(
//			sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocument.getDocumentType()),
//			fromDocumentInfo.getDocumentType(), toDocument, summedCachedValueName);
//}

//----------------------------------------------------------------------------------------------------------------------
TArray<CMDSDocument> CMDSDocumentStorage::getCollectionDocuments(const CString& name,
		const CMDSDocument::Info& documentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect documents
	TCArray<CMDSDocument>	documents;
	iterateCollection(name, documentInfo, (CMDSDocument::Proc) sAddDocumentToArray, &documents);

	return documents;
}

//----------------------------------------------------------------------------------------------------------------------
TDictionary<CMDSDocument> CMDSDocumentStorage::getIndexDocumentMap(const CString& name, const TArray<CString> keys,
		const CMDSDocument::Info& documentInfo) const
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect documents
	TCDictionary<CMDSDocument>	documentMap;
	iterateIndex(name, keys, documentInfo, (CMDSDocument::KeyProc) sAddDocumentToDictionary, &documentMap);

	return documentMap;
}

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - Local procs definitions

//----------------------------------------------------------------------------------------------------------------------
void sAddDocumentToArray(CMDSDocument& document, TCArray<CMDSDocument>* documents)
//----------------------------------------------------------------------------------------------------------------------
{
	documents->add(document);
}

//----------------------------------------------------------------------------------------------------------------------
void sAddDocumentToDictionary(const CString& key, const CMDSDocument& document, TCDictionary<CMDSDocument>* dictionary)
//----------------------------------------------------------------------------------------------------------------------
{
	dictionary->set(key, document);
}

//----------------------------------------------------------------------------------------------------------------------
CString sComposeAssociationName(const CString& fromDocumentType, const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	return fromDocumentType + CString(OSSTR("To")) +
			toDocumentType.getSubString(0, 1).uppercased() + toDocumentType.getSubString(1);
}
