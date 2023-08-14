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
														const CString& fromDocumentID, const CString& toDocumentType,
														CMDSDocument::Proc proc, void* procUserData) const;
		OV<SError>									associationIterateTo(const CString& name,
														const CString& toDocumentID, const CString& fromDocumentType,
														CMDSDocument::Proc proc, void* procUserData) const;
		TVResult<CDictionary>						associationGetIntegerValues(const CString& name,
															CMDSAssociation::GetIntegerValueAction action,
															const TArray<CString>& fromDocumentIDs,
															const CString& cacheName,
															const TArray<CString>& cachedValueNames) const;
		OV<SError>									associationUpdate(const CString& name,
															const TArray<CMDSAssociation::Update>& updates);

		OV<SError>									cacheRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties,
															const TArray<SMDSCacheValueInfo>& valueInfos);

		OV<SError>									collectionRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties, bool isUpToDate,
															const CDictionary& isIncludedInfo,
															const CMDSDocument::IsIncludedPerformer&
																	documentIsIncludedPerformer);
		TVResult<UInt32>							collectionGetDocumentCount(const CString& name) const;
		OV<SError>									collectionIterate(const CString& name, const CString& documentType,
															CMDSDocument::Proc proc, void* procUserData) const;

		DocumentCreateResultInfosResult				documentCreate(const CString& documentType,
															const TArray<CMDSDocument::CreateInfo>& documentCreateInfos,
															const CMDSDocument::InfoForNew& documentInfoForNew);
		TVResult<UInt32>							documentGetCount(const CString& documentType) const;
		OV<SError>									documentIterate(const CMDSDocument::Info& documentInfo,
															const TArray<CString>& documentIDs, CMDSDocument::Proc proc,
															void* procUserData) const;
		OV<SError>									documentIterate(const CMDSDocument::Info& documentInfo,
															bool activeOnly, CMDSDocument::Proc proc,
															void* procUserData) const;

		UniversalTime								documentCreationUniversalTime(const CMDSDocument& document) const;
		UniversalTime								documentModificationUniversalTime(const CMDSDocument& document)
															const;

		OV<SValue>									documentValue(const CString& property, const CMDSDocument& document)
															const;
		OV<CData>									documentData(const CString& property, const CMDSDocument& document)
															const;
		OV<UniversalTime>							documentUniversalTime(const CString& property,
															const CMDSDocument& document) const;
		void										documentSet(const CString& property, const OV<SValue>& value,
															const CMDSDocument& document,
															SetValueKind setValueKind = kSetValueKindNothingSpecial);

		DocumentAttachmentInfoResult				documentAttachmentAdd(const CString& documentType,
															const CString& documentID, const CDictionary& info,
															const CData& content);
		DocumentAttachmentInfoMapResult				documentAttachmentInfoMap(const CString& documentType,
															const CString& documentID);
		TVResult<CData>								documentAttachmentContent(const CString& documentType,
															const CString& documentID, const CString& attachmentID);
		TVResult<UInt32>							documentAttachmentUpdate(const CString& documentType,
															const CString& documentID, const CDictionary& updatedInfo,
															const CData& updatedContent);
		OV<SError>									documentAttachmentRemove(const CString& documentType,
															const CString& documentID, const CString& attachmentID);

		OV<SError>									documentRemove(const CMDSDocument& document);

		OV<SError>									indexRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties,
															const CDictionary& keysInfo,
															const CMDSDocument::KeysPerformer& documentKeysPerformer);
		void										indexIterate(const CString& name, const CString& documentType,
															const TArray<CString>& keys, CMDSDocument::KeyProc keyProc,
															void* keyProcUserData) const;

		TVResult<TDictionary<CString> >				infoGet(const TArray<CString>& keys) const;
		OV<SError>									infoSet(const TDictionary<CString>& info);
		OV<SError>									remove(const TArray<CString>& keys);

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
															const CMDSDocument& document, const CString& property)
															const;
		OV<CString>									documentStringValue(const CString& documentType,
															const CMDSDocument& document, const CString& property)
															const;
		DocumentFullInfosResult						documentUpdate(const CString& documentType,
															const TArray<CMDSDocument::UpdateInfo>&
																	documentUpdateInfos);

		DocumentRevisionInfoDictionaryResult		indexGetDocumentRevisionInfos(const CString& name,
															const TArray<CString>& keys) const;
		DocumentFullInfoDictionaryResult			indexGetDocumentFullInfos(const CString& name,
															const TArray<CString>& keys) const;
				TDictionary<CString>	getInfo(const TArray<CString>& keys) const;
				void					set(const TDictionary<CString>& info);
				void					remove(const TArray<CString>& keys);

				I<CMDSDocument>			newDocument(const CMDSDocument::InfoForNew& infoForNew);

				OV<UInt32>				getDocumentCount(const CMDSDocument::Info& documentInfo) const;
				OI<CMDSDocument>		getDocument(const CString& documentID, const CMDSDocument::Info& documentInfo)
												const;

				UniversalTime			getCreationUniversalTime(const CMDSDocument& document) const;
				UniversalTime			getModificationUniversalTime(const CMDSDocument& document) const;

				OV<SValue>				getValue(const CString& property, const CMDSDocument& document) const;
				OV<CData>				getData(const CString& property, const CMDSDocument& document) const;
				OV<UniversalTime>		getUniversalTime(const CString& property, const CMDSDocument& document) const;
				void					set(const CString& property, const OV<SValue>& value,
												const CMDSDocument& document,
												SetValueInfo setValueInfo = kNothingSpecial);

				void					remove(const CMDSDocument& document);

				void					iterate(const CMDSDocument::Info& documentInfo, CMDSDocument::Proc proc,
												void* userData);
				void					iterate(const CMDSDocument::Info& documentInfo,
												const TArray<CString>& documentIDs, CMDSDocument::Proc proc,
												void* userData);

				void					batch(BatchProc batchProc, void* userData);

				void					registerAssociation(const CString& name,
												const CMDSDocument::Info& fromDocumentInfo,
												const CMDSDocument::Info& toDocumentInfo);
				void					updateAssociation(const CString& name,
												const TArray<AssociationUpdate>& updates);
				void					iterateAssociationFrom(const CString& name, const CMDSDocument& fromDocument,
												const CMDSDocument::Info& toDocumentInfo, CMDSDocument::Proc proc,
												void* userData);
				void					iterateAssociationTo(const CString& name,
												const CMDSDocument::Info& fromDocumentInfo,
												const CMDSDocument& toDocument, CMDSDocument::Proc proc,
												void* userData);

//				SValue					retrieveAssociationValue(const CString& name, const CString& fromDocumentType,
//												const CMDSDocument& toDocument, const CString& summedCachedValueName);

//				void					registerCache(const CString& name, const CMDSDocument::Info& documentInfo,
//												UInt32 version, const TArray<CString>& relevantProperties,
//												const TArray<CacheValueInfo>& cacheValueInfos);

				void					registerCollection(const CString& name, const CMDSDocument::Info& documentInfo,
												UInt32 version, const TArray<CString>& relevantProperties,
												bool isUpToDate, const CString& isIncludedSelector,
												const CDictionary& isIncludedSelectorInfo,
												CMDSDocument::IsIncludedProc isIncludedProc, void* userData);
				UInt32					getCollectionDocumentCount(const CString& name) const;
				void					iterateCollection(const CString& name, const CMDSDocument::Info& documentInfo,
												CMDSDocument::Proc proc, void* userData) const;

				void					registerIndex(const CString& name, const CMDSDocument::Info& documentInfo,
												UInt32 version, const TArray<CString>& relevantProperties,
												bool isUpToDate, const CString& keysSelector,
												const CDictionary& keysSelectorInfo, CMDSDocument::KeysProc keysProc,
												void* userData);
				void					iterateIndex(const CString& name, const TArray<CString>& keys,
												const CMDSDocument::Info& documentInfo, CMDSDocument::KeyProc keyProc,
												void* userData) const;

				void					registerDocumentChangedProc(const CString& documentType,
												CMDSDocument::ChangedProc changedProc, void* userData);

	// Proeprties
	private:
		Internals*	mInternals;
};
