//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocumentStorage.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "SMDSAssociation.h"
#include "TMDSBatch.h"
#include "TMDSCache.h"
#include "TResult.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocumentStorage

class CMDSDocumentStorage {
	// SetValueKind
	public:
		enum SetValueKind {
			kSetValueKindNothingSpecial,
			kSetValueKindUniversalTime,
		};


	// Procs
	public:
		typedef	TVResult<EMDSBatchResult>	(*BatchProc)(void* userData);

	// Types
	typedef	TVResult<TArray<SMDSAssociation::Item> >			AssociationItemsResult;
	typedef	TVResult<CMDSDocument::AttachmentInfo>				DocumentAttachmentInfoResult;
	typedef	TVResult<CMDSDocument::AttachmentInfoMap>			DocumentAttachmentInfoMapResult;
	typedef	TVResult<TArray<CMDSDocument::CreateResultInfo> >	DocumentCreateResultInfosResult;
	typedef	TArray<CMDSDocument::ChangedInfo>					DocumentChangedInfos;
	typedef	OR<CMDSDocument::IsIncludedPerformer>				DocumentIsIncludedPerformer;
	typedef	OR<CMDSDocument::KeysPerformer>						DocumentKeysPerformer;
	typedef	OR<CMDSDocument::ValueInfo>							DocumentValueInfo;

	// Classes
	private:
		class Internals;

	// Methods
	public:
														// Lifecycle methods
		virtual											~CMDSDocumentStorage() {}

														// Instance methods
				const	CString&						getID() const;

		virtual			OV<SError>						associationRegister(const CString& name,
																const CString& fromDocumentType,
																const CString& toDocumentType) = 0;
		virtual			AssociationItemsResult			associationGet(const CString& name) const = 0;
		virtual			OV<SError>						associationIterateFrom(const CString& name,
															const CString& fromDocumentID,
															const CString& toDocumentType,
															CMDSDocument::Proc proc, void* procUserData) const = 0;
		virtual			OV<SError>						associationIterateTo(const CString& name,
															const CString& toDocumentID,
															const CString& fromDocumentType,
															CMDSDocument::Proc proc, void* procUserData) const = 0;
		virtual			TVResult<CDictionary>			associationGetIntegerValues(const CString& name,
																SMDSAssociation::GetIntegerValueAction action,
																const TArray<CString>& fromDocumentIDs,
																const CString& cacheName,
																const TArray<CString>& cachedValueNames) const = 0;
		virtual			OV<SError>						associationUpdate(const CString& name,
																const TArray<SMDSAssociation::Update>& updates) = 0;

		virtual			OV<SError>						cacheRegister(const CString& name,
																const CString& documentType,
																const TArray<CString>& relevantProperties,
																const TArray<SMDSCacheValueInfo>& valueInfos) = 0;

		virtual			OV<SError>						collectionRegister(const CString& name,
																const CString& documentType,
																const TArray<CString>& relevantProperties,
																bool isUpToDate, const CDictionary& isIncludedInfo,
																const CMDSDocument::IsIncludedPerformer&
																		documentIsIncludedPerformer) = 0;
		virtual			TVResult<UInt32>				collectionGetDocumentCount(const CString& name) const = 0;
		virtual			OV<SError>						collectionIterate(const CString& name,
																const CString& documentType,
																CMDSDocument::Proc proc, void* procUserData) const = 0;

		virtual			DocumentCreateResultInfosResult	documentCreate(const CString& documentType,
																const TArray<CMDSDocument::CreateInfo>&
																		documentCreateInfos,
																CMDSDocument::CreateProc proc) = 0;
		virtual			TVResult<UInt32>				documentGetCount(const CString& documentType) const = 0;
		virtual			OV<SError>						documentIterate(const CMDSDocument::Info& documentInfo,
																const TArray<CString>& documentIDs,
																CMDSDocument::Proc proc, void* procUserData) const = 0;
		virtual			OV<SError>						documentIterate(const CMDSDocument::Info& documentInfo,
																bool activeOnly,
																CMDSDocument::Proc proc, void* procUserData) const = 0;

		virtual			UniversalTime					documentCreationUniversalTime(const CMDSDocument& document)
																const = 0;
		virtual			UniversalTime					documentModificationUniversalTime(const CMDSDocument& document)
																const = 0;

		virtual			OV<SValue>						documentValue(const CString& property,
																const CMDSDocument& document) const = 0;
		virtual			OV<CData>						documentData(const CString& property,
																const CMDSDocument& document) const = 0;
		virtual			OV<UniversalTime>				documentUniversalTime(const CString& property,
																const CMDSDocument& document) const = 0;
		virtual			void							documentSet(const CString& property, const OV<SValue>& value,
																const CMDSDocument& document,
 																SetValueKind setValueKind = kSetValueKindNothingSpecial)
 																= 0;

		virtual			DocumentAttachmentInfoResult	documentAttachmentAdd(const CString& documentType,
																const CString& documentID, const CDictionary& info,
																const CData& content) = 0;
		virtual			DocumentAttachmentInfoMapResult	documentAttachmentInfoMap(const CString& documentType,
																const CString& documentID) = 0;
		virtual			TVResult<CData>					documentAttachmentContent(const CString& documentType,
																const CString& documentID, const CString& attachmentID)
																= 0;
		virtual			TVResult<UInt32>				documentAttachmentUpdate(const CString& documentType,
																const CString& documentID,
																const CDictionary& updatedInfo,
																const CData& updatedContent) = 0;
		virtual			OV<SError>						documentAttachmentRemove(const CString& documentType,
																const CString& documentID, const CString& attachmentID)
																= 0;

		virtual			OV<SError>						documentRemove(const CMDSDocument& document) = 0;

		virtual			OV<SError>						indexRegister(const CString& name,
																const CString& documentType,
																const TArray<CString>& relevantProperties,
																const CDictionary& keysInfo,
																const CMDSDocument::KeysPerformer&
																		documentKeysPerformer);
		virtual			void							indexIterate(const CString& name,
																const CString& documentType,
																const TArray<CString>& keys,
																CMDSDocument::KeyProc keyProc, void* keyProcUserData)
																const = 0;

		virtual			TVResult<TDictionary<CString> >	infoGet(const TArray<CString>& keys) const = 0;
		virtual			OV<SError>						infoSet(const TDictionary<CString>& info) = 0;
		virtual			OV<SError>						remove(const TArray<CString>& keys) = 0;

		virtual			TVResult<TDictionary<CString> >	internalGet(const TArray<CString>& keys) const = 0;
		virtual			OV<SError>						internalSet(const TDictionary<CString>& info) = 0;

		virtual			OV<SError>						batch(BatchProc batchProc, void* userData) = 0;

//															const CMDSDocument::Info& toDocumentInfo,
//															const CMDSDocument& toDocument,
//															const CMDSDocument& toDocument,

	private:
														// Instance methods
						CString							associationName(const CString& fromDocumentType,
																const CString& toDocumentType)
															{ return fromDocumentType + CString(OSSTR("To")) +
																	toDocumentType.capitalizingFirstLetter(); }
//															const TArray<CString>& relevantProperties,
//															const CMDSDocument::Info& documentInfo,
//															const TArray<CString>& relevantProperties,

		protected:
														// Lifecycle methods
														CMDSDocumentStorage();

	// Properties
	private:
		Internals*	mInternals;
};
