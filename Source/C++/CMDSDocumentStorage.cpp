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
	iterate(info, (CMDSDocument::Proc) sAddDocumentToArray, &documents);

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
		const CMDSDocument::Info& toDocumenInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	registerAssociation(sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocumenInfo.getDocumentType()),
			fromDocumentInfo, toDocumenInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::updateAssociation(const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument::Info& toDocumenInfo, const TArray<AssociationUpdate>& updates)
//----------------------------------------------------------------------------------------------------------------------
{
	updateAssociation(sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocumenInfo.getDocumentType()),
			updates);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::iterateAssociationFrom(const CMDSDocument& fromDocument,
		const CMDSDocument::Info& toDocumenInfo, CMDSDocument::Proc proc, void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	iterateAssociationFrom(sComposeAssociationName(fromDocument.getDocumentType(), toDocumenInfo.getDocumentType()),
			fromDocument, proc, userData);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSDocumentStorage::iterateAssociationTo(const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument& toDocument, CMDSDocument::Proc proc, void* userData) const
//----------------------------------------------------------------------------------------------------------------------
{
	iterateAssociationTo(sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocument.getDocumentType()),
			toDocument, proc, userData);
}

//----------------------------------------------------------------------------------------------------------------------
SValue CMDSDocumentStorage::retrieveAssociationValue(const CMDSDocument::Info& fromDocumentInfo,
		const CMDSDocument& toDocument, const CString& summedCachedValueName)
//----------------------------------------------------------------------------------------------------------------------
{
	return retrieveAssociationValue(
			sComposeAssociationName(fromDocumentInfo.getDocumentType(), toDocument.getDocumentType()),
			fromDocumentInfo.getDocumentType(), toDocument, summedCachedValueName);
}

//----------------------------------------------------------------------------------------------------------------------
TArray<CMDSDocument> CMDSDocumentStorage::getCollectionDocuments(const CString& name,
		const CMDSDocument::Info& documentInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Collect documents
	TCArray<CMDSDocument>	documents;
	iterateCollection(name, documentInfo, (CMDSDocument::Proc) sAddDocumentToArray, &documents);

	return documents;
}

//----------------------------------------------------------------------------------------------------------------------
TDictionary<CMDSDocument> CMDSDocumentStorage::getIndexDocumentMap(const CString& name, const TArray<CString> keys,
		const CMDSDocument::Info& documentInfo)
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
	return fromDocumentType + CString(OSSTR("To")) + toDocumentType;
}
