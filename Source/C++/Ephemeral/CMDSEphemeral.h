//----------------------------------------------------------------------------------------------------------------------
//	CMDSEphemeral.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocumentStorageServer.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSEphemeral

class CMDSEphemeral : public CMDSDocumentStorageServer {
	// Classes
	private:
		class Internals;

	// Methods
	public:
													// Lifecycle methods
													CMDSEphemeral();
													~CMDSEphemeral();

													// CMDSDocumentStorage methods
		OV<SError>									associationRegister(const CString& name,
															const CString& fromDocumentType,
															const CString& toDocumentType);
		AssociationItemsResult						associationGet(const CString& name) const;
		OV<SError>									associationIterateFrom(const CString& name,
															const CString& fromDocumentID,
															const CString& toDocumentType, CMDSDocument::Proc proc,
															void* procUserData) const;
		OV<SError>									associationIterateTo(const CString& name,
															const CString& fromDocumentType,
															const CString& toDocumentID, CMDSDocument::Proc proc,
															void* procUserData) const;
		TVResult<SValue>							associationGetValues(const CString& name,
															CMDSAssociation::GetValueAction action,
															const TArray<CString>& fromDocumentIDs,
															const CString& cacheName,
															const TArray<CString>& cachedValueNames) const;
		OV<SError>									associationUpdate(const CString& name,
															const TArray<CMDSAssociation::Update>& updates);

		OV<SError>									cacheRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties,
															const TArray<CacheValueInfo>& cacheValueInfos);
		TVResult<TArray<CDictionary> >				cacheGetValues(const CString& name,
															const TArray<CString>& valueNames,
															const OV<TArray<CString> >& documentIDs);

		OV<SError>									collectionRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties, bool isUpToDate,
															const CDictionary& isIncludedInfo,
															const CMDSDocument::IsIncludedPerformer&
																	documentIsIncludedPerformer,
															bool checkRelevantProperties);
		TVResult<UInt32>							collectionGetDocumentCount(const CString& name) const;
		OV<SError>									collectionIterate(const CString& name, const CString& documentType,
															CMDSDocument::Proc proc, void* procUserData) const;

		DocumentCreateResultInfosResult				documentCreate(const CMDSDocument::InfoForNew& documentInfoForNew,
															const TArray<CMDSDocument::CreateInfo>&
																	documentCreateInfos);
		TVResult<UInt32>							documentGetCount(const CString& documentType) const;
		TVResult<UInt32>							documentGetCount(const CMDSDocument::Info& documentInfo) const
														{ return documentGetCount(documentInfo.getDocumentType()); }
		OV<SError>									documentIterate(const CMDSDocument::Info& documentInfo,
															const TArray<CString>& documentIDs, CMDSDocument::Proc proc,
															void* procUserData) const;
		OV<SError>									documentIterate(const CMDSDocument::Info& documentInfo,
															bool activeOnly, CMDSDocument::Proc proc,
															void* procUserData) const;

		UniversalTime								documentCreationUniversalTime(const I<CMDSDocument>& document)
															const;
		UniversalTime								documentModificationUniversalTime(const I<CMDSDocument>& document)
															const;

		OV<SValue>									documentValue(const CString& property,
															const I<CMDSDocument>& document) const;
		OV<CData>									documentData(const CString& property,
															const I<CMDSDocument>& document) const;
		OV<UniversalTime>							documentUniversalTime(const CString& property,
															const I<CMDSDocument>& document) const;
		void										documentSet(const CString& property, const OV<SValue>& value,
															const I<CMDSDocument>& document,
															SetValueKind setValueKind = kSetValueKindNothingSpecial);

		DocumentAttachmentInfoResult				documentAttachmentAdd(const CString& documentType,
															const CString& documentID, const CDictionary& info,
															const CData& content);
		DocumentAttachmentInfoByIDResult			documentAttachmentInfoByID(const CString& documentType,
															const CString& documentID);
		TVResult<CData>								documentAttachmentContent(const CString& documentType,
															const CString& documentID, const CString& attachmentID);
		TVResult<OV<UInt32> >						documentAttachmentUpdate(const CString& documentType,
															const CString& documentID, const CString& attachmentID,
															const CDictionary& updatedInfo,
															const CData& updatedContent);
		OV<SError>									documentAttachmentRemove(const CString& documentType,
															const CString& documentID, const CString& attachmentID);

		OV<SError>									documentRemove(const I<CMDSDocument>& document);

		OV<SError>									indexRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties,
															const CDictionary& keysInfo,
															const CMDSDocument::KeysPerformer& documentKeysPerformer);
		OV<SError>									indexIterate(const CString& name, const CString& documentType,
															const TArray<CString>& keys,
															CMDSDocument::KeyProc documentKeyProc,
															void* documentKeyProcUserData) const;

		TVResult<TDictionary<CString> >				infoGet(const TArray<CString>& keys) const;
		OV<SError>									infoSet(const TDictionary<CString>& info);
		OV<SError>									infoRemove(const TArray<CString>& keys);

		TVResult<TDictionary<CString> >				internalGet(const TArray<CString>& keys) const;
		OV<SError>									internalSet(const TDictionary<CString>& info);

		OV<SError>									batch(BatchProc batchProc, void* userData);

													// CMDSDocumentStorageServer methods
		DocumentRevisionInfosWithTotalCountResult	associationGetDocumentRevisionInfosFrom(const CString& name,
															const CString& fromDocumentID, UInt32 startIndex,
															const OV<UInt32>& count) const;
		DocumentRevisionInfosWithTotalCountResult	associationGetDocumentRevisionInfosTo(const CString& name,
															const CString& toDocumentID, UInt32 startIndex,
															const OV<UInt32>& count) const;
		DocumentFullInfosWithTotalCountResult		associationGetDocumentFullInfosFrom(const CString& name,
															const CString& fromDocumentID, UInt32 startIndex,
															const OV<UInt32>& count) const;
		DocumentFullInfosWithTotalCountResult		associationGetDocumentFullInfosTo(const CString& name,
															const CString& toDocumentID, UInt32 startIndex,
															const OV<UInt32>& count) const;

		OV<SError>									cacheGetStatus(const CString& name) const;

		DocumentRevisionInfosResult					collectionGetDocumentRevisionInfos(const CString& name,
															UInt32 startIndex, const OV<UInt32>& count) const;
		DocumentFullInfosResult						collectionGetDocumentFullInfos(const CString& name,
															UInt32 startIndex, const OV<UInt32>& count) const;

		DocumentRevisionInfosResult					documentRevisionInfos(const CString& documentType,
															const TArray<CString>& documentIDs) const;
		DocumentRevisionInfosResult					documentRevisionInfos(const CString& documentType,
															UInt32 sinceRevision, const OV<UInt32>& count) const;
		DocumentFullInfosResult						documentFullInfos(const CString& documentType,
															const TArray<CString>& documentIDs) const;
		DocumentFullInfosResult						documentFullInfos(const CString& documentType, UInt32 sinceRevision,
															const OV<UInt32>& count) const;

		OV<SInt64>									documentIntegerValue(const CString& documentType,
															const I<CMDSDocument>& document, const CString& property)
															const;
		OV<CString>									documentStringValue(const CString& documentType,
															const I<CMDSDocument>& document, const CString& property)
															const;
		DocumentFullInfosResult						documentUpdate(const CString& documentType,
															const TArray<CMDSDocument::UpdateInfo>&
																	documentUpdateInfos);

		OV<SError>									indexGetStatus(const CString& name) const;
		DocumentRevisionInfoDictionaryResult		indexGetDocumentRevisionInfos(const CString& name,
															const TArray<CString>& keys) const;
		DocumentFullInfoDictionaryResult			indexGetDocumentFullInfos(const CString& name,
															const TArray<CString>& keys) const;

	// Properties
	private:
		Internals*	mInternals;
};
