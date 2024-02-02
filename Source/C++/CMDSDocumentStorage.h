//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocumentStorage.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSAssociation.h"
#include "TMDSBatch.h"
#include "TMDSCache.h"
#include "TResult.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocumentStorage

class CMDSDocumentStorage {
	// CacheValueInfo
	public:
		struct CacheValueInfo {
			// Methods
			public:
										// Lifecycle methods
										CacheValueInfo(const SMDSValueInfo& valueInfo, const CString& selector) :
											mValueInfo(valueInfo), mSelector(selector)
											{}
										CacheValueInfo(const CacheValueInfo& other) :
											mValueInfo(other.mValueInfo), mSelector(other.mSelector)
											{}

										// Instance methods
				const	SMDSValueInfo&	getValueInfo() const
											{ return mValueInfo; }
				const	CString&		getSelector() const
											{ return mSelector; }
			// Properties
			private:
				SMDSValueInfo	mValueInfo;
				CString			mSelector;
		};

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
	typedef	TVResult<TArray<CMDSAssociation::Item> >			AssociationItemsResult;
	typedef	TVResult<CMDSDocument::AttachmentInfo>				DocumentAttachmentInfoResult;
	typedef	TVResult<CMDSDocument::AttachmentInfoMap>			DocumentAttachmentInfoMapResult;
	typedef	TArray<CMDSDocument::ChangedInfo>					DocumentChangedInfos;
	typedef	TVResult<TArray<CMDSDocument::CreateResultInfo> >	DocumentCreateResultInfosResult;
	typedef	OR<CMDSDocument::IsIncludedPerformer>				DocumentIsIncludedPerformer;
	typedef	OR<CMDSDocument::KeysPerformer>						DocumentKeysPerformer;
	typedef	OR<CMDSDocument::ValueInfo>							DocumentValueInfo;
	typedef	TVResult<TArray<I<CMDSDocument> > >					DocumentsResult;

	// Classes
	private:
		class Internals;

	// Methods
	public:
														// Lifecycle methods
		virtual											~CMDSDocumentStorage();

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
																const CString& fromDocumentType,
																const CString& toDocumentID,
																CMDSDocument::Proc proc, void* procUserData) const = 0;
		virtual			TVResult<CDictionary>			associationGetIntegerValues(const CString& name,
																CMDSAssociation::GetIntegerValueAction action,
																const TArray<CString>& fromDocumentIDs,
																const CString& cacheName,
																const TArray<CString>& cachedValueNames) const = 0;
		virtual			OV<SError>						associationUpdate(const CString& name,
																const TArray<CMDSAssociation::Update>& updates) = 0;

		virtual			OV<SError>						cacheRegister(const CString& name,
																const CString& documentType,
																const TArray<CString>& relevantProperties,
																const TArray<CacheValueInfo>& cacheValueInfos) = 0;

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

		virtual			DocumentCreateResultInfosResult	documentCreate(
																const CMDSDocument::InfoForNew& documentInfoForNew,
																const TArray<CMDSDocument::CreateInfo>&
																		documentCreateInfos) = 0;
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
																const CString& attachmentID,
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
																		documentKeysPerformer) = 0;
		virtual			OV<SError>						indexIterate(const CString& name,
																const CString& documentType,
																const TArray<CString>& keys,
																CMDSDocument::KeyProc keyProc, void* keyProcUserData)
																const = 0;

		virtual			TVResult<TDictionary<CString> >	infoGet(const TArray<CString>& keys) const = 0;
		virtual			OV<SError>						infoSet(const TDictionary<CString>& info) = 0;
		virtual			OV<SError>						infoRemove(const TArray<CString>& keys) = 0;

		virtual			TVResult<TDictionary<CString> >	internalGet(const TArray<CString>& keys) const = 0;
		virtual			OV<SError>						internalSet(const TDictionary<CString>& info) = 0;

		virtual			OV<SError>						batch(BatchProc batchProc, void* userData) = 0;

						OV<SError>						associationRegister(const CString& fromDocumentType,
																const CString& toDocumentType)
															{ return associationRegister(
																	associationName(fromDocumentType, toDocumentType),
																	fromDocumentType, toDocumentType); }
						OV<SError>						associationRegister(const CMDSDocument::Info& fromDocumentInfo,
																const CMDSDocument::Info& toDocumentInfo)
															{ return associationRegister(
																	fromDocumentInfo.getDocumentType(),
																	toDocumentInfo.getDocumentType()); }
						OV<SError>						associationUpdateAdd(const CMDSDocument& fromDocument,
																const CMDSDocument& toDocument)
															{ return associationUpdate(
																	associationName(fromDocument.getDocumentType(),
																			toDocument.getDocumentType()),
																	TNArray<CMDSAssociation::Update>(
																			CMDSAssociation::Update::add(
																					fromDocument.getID(),
																					toDocument.getID()))); }
						OV<SError>						associationUpdateRemove(const CMDSDocument& fromDocument,
																const CMDSDocument& toDocument)
															{ return associationUpdate(
																	associationName(fromDocument.getDocumentType(),
																			toDocument.getDocumentType()),
																	TNArray<CMDSAssociation::Update>(
																			CMDSAssociation::Update::remove(
																					fromDocument.getID(),
																					toDocument.getID()))); }

						DocumentsResult					associationGetDocumentsFrom(const CMDSDocument& fromDocument,
																const CMDSDocument::Info& toDocumentInfo);
						DocumentsResult					associationGetDocumentsTo(
																const CMDSDocument::Info& fromDocumentInfo,
																const CMDSDocument& toDocument);
						OV<SError>						collectionRegister(const CString& name,
																const CString& documentType,
																const TArray<CString>& relevantProperties,
																bool isUpToDate, const CDictionary& isIncludedInfo,
																const CString& isIncludedSelector)
															{ return collectionRegister(name, documentType,
																	relevantProperties, isUpToDate, isIncludedInfo,
																	*documentIsIncludedPerformer(isIncludedSelector)); }

						DocumentCreateResultInfosResult	documentCreate(const CString& documentType,
																const TArray<CMDSDocument::CreateInfo>&
																		documentCreateInfos);
						TVResult<I<CMDSDocument> >		documentCreate(
																const CMDSDocument::InfoForNew& documentInfoForNew);

						OV<SError>						indexRegister(const CString& name,
																const CString& documentType,
																const TArray<CString>& relevantProperties,
																const CDictionary& keysInfo,
																const CString& keysSelector)
															{ return indexRegister(name, documentType,
																	relevantProperties, keysInfo,
																	*documentKeysPerformer(keysSelector)); }

														// Instance methods
						void							registerDocumentCreateInfo(
																const CMDSDocument::Info& documentInfo);
						void							registerDocumentChangedInfos(
																const CMDSDocument::Info& documentInfo,
																const CMDSDocument::ChangedInfo& documentChangedInfo);
						void							registerDocumentIsIncludedPerformers(
																const TArray<CMDSDocument::IsIncludedPerformer>&
																		documentIsIncludedPerformers);
						void							registerDocumentKeysPerformers(
																const TArray<CMDSDocument::KeysPerformer>&
																		documentKeysPerformers);
						void							registerValueInfos(
																const TArray<CMDSDocument::ValueInfo>&
																		documentValueInfos);


														// Class methods
		static			SError							getInvalidCountError(UInt32 count);
		static			SError							getInvalidDocumentTypeError(const CString& documentType);
		static			SError							getInvalidStartIndexError(UInt32 startIndex);

		static			SError							getMissingFromIndexError(const CString& key);

		static			SError							getUnknownAssociationError(const CString& name);

		static			SError							getUnknownAttachmentIDError(const CString& attachmentID);

		static			SError							getUnknownCacheError(const CString& name);
		static			SError							getUnknownCacheValueName(const CString& valueName);
		static			SError							getUnknownCacheValueSelector(const CString& selector);

		static			SError							getUnknownCollectionError(const CString& name);

		static			SError							getUnknownDocumentIDError(const CString& documentID);
		static			SError							getUnknownDocumentTypeError(const CString& documentType);

		static			SError							getUnknownIndexError(const CString& name);

		static			SError							getIllegalInBatchError();

	protected:
														// Lifecycle methods
														CMDSDocumentStorage();

														// Subclass methods
				const	CMDSDocument::Info&				documentCreateInfo(const CString& documentType) const;
						DocumentChangedInfos			documentChangedInfos(const CString& documentType) const;
						void							notifyDocumentChanged(const CMDSDocument& document,
																CMDSDocument::ChangeKind documentChangeKind) const;
						DocumentIsIncludedPerformer		documentIsIncludedPerformer(const CString& selector) const;
						DocumentKeysPerformer			documentKeysPerformer(const CString& selector) const;
						DocumentValueInfo				documentValueInfo(const CString& selector) const;

	private:
														// Instance methods
						CString							associationName(const CString& fromDocumentType,
																const CString& toDocumentType)
															{ return fromDocumentType + CString(OSSTR("To")) +
																	toDocumentType.capitalizingFirstLetter(); }

	// Properties
	private:
		Internals*	mInternals;
};
