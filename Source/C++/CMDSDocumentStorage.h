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

	// DocumentIsIncludedPerformerInfo
	public:
		class DocumentIsIncludedPerformerInfo {
			// Methods
			public:
													// Lifecycle methods
													DocumentIsIncludedPerformerInfo(
															CMDSDocument::IsIncludedPerformer
																	documentIsIncludedPerformer,
															bool checkRelevantProperties) :
														mDocumentIsIncludedPerformer(documentIsIncludedPerformer),
																mCheckRelevantProperties(checkRelevantProperties)
														{}
													DocumentIsIncludedPerformerInfo(
															const DocumentIsIncludedPerformerInfo& other) :
														mDocumentIsIncludedPerformer(
																		other.mDocumentIsIncludedPerformer),
																mCheckRelevantProperties(other.mCheckRelevantProperties)
														{}

													// Instance methods
				CMDSDocument::IsIncludedPerformer	getDocumentIsIncludedPerformer() const
														{ return mDocumentIsIncludedPerformer; }
				bool								getCheckRelevantProperties() const
														{ return mCheckRelevantProperties; }

			// Properties
			private:
				CMDSDocument::IsIncludedPerformer	mDocumentIsIncludedPerformer;
				bool								mCheckRelevantProperties;
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
	typedef	TVResult<CMDSDocument::AttachmentInfoByID>			DocumentAttachmentInfoByIDResult;
	typedef	TArray<CMDSDocument::ChangedInfo>					DocumentChangedInfos;
	typedef	TVResult<TArray<CMDSDocument::CreateResultInfo> >	DocumentCreateResultInfosResult;
	typedef	CMDSDocument::IsIncludedPerformer					DocumentIsIncludedPerformer;
	typedef	CMDSDocument::KeysPerformer							DocumentKeysPerformer;
	typedef	CMDSDocument::ValueInfo								DocumentValueInfo;
	typedef	TVResult<TArray<I<CMDSDocument> > >					DocumentsResult;
	typedef	TVResult<TDictionary<I<CMDSDocument> > >			IndexDocumentMapResult;

	// Classes
	private:
		class Internals;

	// Methods
	public:
															// Lifecycle methods
		virtual												~CMDSDocumentStorage();

															// Instance methods
				const	CString&							getID() const;

		virtual			OV<SError>							associationRegister(const CString& name,
																	const CString& fromDocumentType,
																	const CString& toDocumentType) = 0;
		virtual			AssociationItemsResult				associationGet(const CString& name) const = 0;
		virtual			OV<SError>							associationIterateFrom(const CString& name,
																	const CString& fromDocumentID,
																	const CString& toDocumentType,
																	CMDSDocument::Proc proc, void* procUserData) const
																	= 0;
		virtual			OV<SError>							associationIterateTo(const CString& name,
																	const CString& fromDocumentType,
																	const CString& toDocumentID,
																	CMDSDocument::Proc proc, void* procUserData) const
																	= 0;
		virtual			TVResult<SValue>					associationGetValues(const CString& name,
																	CMDSAssociation::GetValueAction action,
																	const TArray<CString>& fromDocumentIDs,
																	const CString& cacheName,
																	const TArray<CString>& cachedValueNames) const = 0;
		virtual			OV<SError>							associationUpdate(const CString& name,
																	const TArray<CMDSAssociation::Update>& updates) = 0;

		virtual			OV<SError>							cacheRegister(const CString& name,
																	const CString& documentType,
																	const TArray<CString>& relevantProperties,
																	const TArray<CacheValueInfo>& cacheValueInfos) = 0;

		virtual			OV<SError>							collectionRegister(const CString& name,
																	const CString& documentType,
																	const TArray<CString>& relevantProperties,
																	bool isUpToDate, const CDictionary& isIncludedInfo,
																	const DocumentIsIncludedPerformer&
																			documentIsIncludedPerformer,
																	bool checkRelevantProperties) = 0;
		virtual			TVResult<UInt32>					collectionGetDocumentCount(const CString& name) const = 0;
		virtual			OV<SError>							collectionIterate(const CString& name,
																	const CString& documentType,
																	CMDSDocument::Proc proc, void* procUserData) const
																	= 0;

		virtual			DocumentCreateResultInfosResult		documentCreate(
																	const CMDSDocument::InfoForNew& documentInfoForNew,
																	const TArray<CMDSDocument::CreateInfo>&
																			documentCreateInfos) = 0;
		virtual			TVResult<UInt32>					documentGetCount(const CString& documentType) const = 0;
		virtual			OV<SError>							documentIterate(const CMDSDocument::Info& documentInfo,
																	const TArray<CString>& documentIDs,
																	CMDSDocument::Proc proc, void* procUserData) const
																	= 0;
		virtual			OV<SError>							documentIterate(const CMDSDocument::Info& documentInfo,
																	bool activeOnly,
																	CMDSDocument::Proc proc, void* procUserData) const
																	= 0;

		virtual			UniversalTime						documentCreationUniversalTime(
																	const I<CMDSDocument>& document) const = 0;
		virtual			UniversalTime						documentModificationUniversalTime(
																	const I<CMDSDocument>& document) const = 0;

		virtual			OV<SValue>							documentValue(const CString& property,
																	const I<CMDSDocument>& document) const = 0;
		virtual			OV<CData>							documentData(const CString& property,
																	const I<CMDSDocument>& document) const = 0;
		virtual			OV<UniversalTime>					documentUniversalTime(const CString& property,
																	const I<CMDSDocument>& document) const = 0;
		virtual			void								documentSet(const CString& property,
																	const OV<SValue>& value,
																	const I<CMDSDocument>& document,
 																	SetValueKind setValueKind =
 																			kSetValueKindNothingSpecial) = 0;

		virtual			DocumentAttachmentInfoResult		documentAttachmentAdd(const CString& documentType,
																	const CString& documentID, const CDictionary& info,
																	const CData& content) = 0;
		virtual			DocumentAttachmentInfoByIDResult	documentAttachmentInfoByID(const CString& documentType,
																	const CString& documentID) = 0;
		virtual			TVResult<CData>						documentAttachmentContent(const CString& documentType,
																	const CString& documentID,
																	const CString& attachmentID) = 0;
		virtual			TVResult<OV<UInt32> >				documentAttachmentUpdate(const CString& documentType,
																	const CString& documentID,
																	const CString& attachmentID,
																	const CDictionary& updatedInfo,
																	const CData& updatedContent) = 0;
		virtual			OV<SError>							documentAttachmentRemove(const CString& documentType,
																	const CString& documentID,
																	const CString& attachmentID) = 0;

		virtual			OV<SError>							documentRemove(const I<CMDSDocument>& document) = 0;

		virtual			OV<SError>							indexRegister(const CString& name,
																	const CString& documentType,
																	const TArray<CString>& relevantProperties,
																	const CDictionary& keysInfo,
																	const DocumentKeysPerformer& documentKeysPerformer)
																	= 0;
		virtual			OV<SError>							indexIterate(const CString& name,
																	const CString& documentType,
																	const TArray<CString>& keys,
																	CMDSDocument::KeyProc documentKeyProc,
																	void* documentKeyProcUserData) const = 0;

		virtual			TVResult<TDictionary<CString> >		infoGet(const TArray<CString>& keys) const = 0;
		virtual			OV<SError>							infoSet(const TDictionary<CString>& info) = 0;
		virtual			OV<SError>							infoRemove(const TArray<CString>& keys) = 0;

		virtual			TVResult<TDictionary<CString> >		internalGet(const TArray<CString>& keys) const = 0;
		virtual			OV<SError>							internalSet(const TDictionary<CString>& info) = 0;

		virtual			OV<SError>							batch(BatchProc batchProc, void* userData) = 0;

						OV<SError>							associationRegister(const CString& fromDocumentType,
																	const CString& toDocumentType)
																{ return associationRegister(
																		associationName(fromDocumentType,
																				toDocumentType),
																		fromDocumentType, toDocumentType); }
						OV<SError>							associationRegister(
																	const CMDSDocument::Info& fromDocumentInfo,
																	const CMDSDocument::Info& toDocumentInfo)
																{ return associationRegister(
																		fromDocumentInfo.getDocumentType(),
																		toDocumentInfo.getDocumentType()); }
						OV<SError>							associationUpdateAdd(const I<CMDSDocument>& fromDocument,
																	const I<CMDSDocument>& toDocument)
																{ return associationUpdate(
																		associationName(fromDocument->getDocumentType(),
																				toDocument->getDocumentType()),
																		TNArray<CMDSAssociation::Update>(
																				CMDSAssociation::Update::add(
																						fromDocument->getID(),
																						toDocument->getID()))); }
						OV<SError>							associationUpdateRemove(const I<CMDSDocument>& fromDocument,
																	const I<CMDSDocument>& toDocument)
																{ return associationUpdate(
																		associationName(fromDocument->getDocumentType(),
																				toDocument->getDocumentType()),
																		TNArray<CMDSAssociation::Update>(
																				CMDSAssociation::Update::remove(
																						fromDocument->getID(),
																						toDocument->getID()))); }
						DocumentsResult						associationGetDocumentsFrom(
																	const I<CMDSDocument>& fromDocument,
																	const CMDSDocument::Info& toDocumentInfo);
						DocumentsResult						associationGetDocumentsTo(
																	const CMDSDocument::Info& fromDocumentInfo,
																	const I<CMDSDocument>& toDocument);
						TVResult<TArray<CDictionary> >		associationGetDetailValues(const CString& name,
																	const TArray<CString>& fromDocumentIDs,
																	const CString& cacheName,
																	const TArray<CString>& cachedValueNames) const;
						TVResult<CDictionary>				associationGetSumValues(const CString& name,
																	const TArray<CString>& fromDocumentIDs,
																	const CString& cacheName,
																	const TArray<CString>& cachedValueNames) const;

						OV<SError>							collectionRegister(const CString& name,
																	const CString& documentType,
																	const TArray<CString>& relevantProperties,
																	bool isUpToDate, const CDictionary& isIncludedInfo,
																	const CString& isIncludedSelector,
																	bool checkRelevantProperties);

						DocumentCreateResultInfosResult		documentCreate(const CString& documentType,
																	const TArray<CMDSDocument::CreateInfo>&
																			documentCreateInfos);
						TVResult<I<CMDSDocument> >			documentCreate(
																	const CMDSDocument::InfoForNew& documentInfoForNew);
						DocumentAttachmentInfoResult		documentAttachmentAdd(const CString& documentType,
																	const CString& documentID, const CString& type,
																	const CDictionary& info, const CData& content);

						OV<SError>							indexRegister(const CString& name,
																	const CString& documentType,
																	const TArray<CString>& relevantProperties,
																	const CDictionary& keysInfo,
																	const CString& keysSelector)
																{ return indexRegister(name, documentType,
																		relevantProperties, keysInfo,
																		documentKeysPerformer(keysSelector)); }
						IndexDocumentMapResult				indexDocumentMap(const CString& name,
																	const CString& documentType,
																	const TArray<CString>& keys);

															// Instance methods
						void								registerDocumentCreateInfo(
																	const CMDSDocument::Info& documentInfo);
				const	CMDSDocument::Info&					documentCreateInfo(const CString& documentType) const;

						void								registerDocumentChangedInfos(
																	const CMDSDocument::Info& documentInfo,
																	const CMDSDocument::ChangedInfo&
																			documentChangedInfo);
						DocumentChangedInfos				documentChangedInfos(const CString& documentType) const;

						void								registerDocumentIsIncludedPerformerInfos(
																	const TArray<DocumentIsIncludedPerformerInfo>&
																			documentIsIncludedPerformerInfos);
				const	DocumentIsIncludedPerformerInfo&	documentIsIncludedPerformerInfo(const CString& selector)
																	const;

						void								registerDocumentKeysPerformers(
																	const TArray<DocumentKeysPerformer>&
																			documentKeysPerformers);
				const	DocumentKeysPerformer&				documentKeysPerformer(const CString& selector) const;

						void								registerValueInfos(
																	const TArray<DocumentValueInfo>&
																			documentValueInfos);
				const	DocumentValueInfo&					documentValueInfo(const CString& selector) const;

						OV<SValue>							ephemeralValue(const CString& key) const;
						void								storeEphemeral(const CString& key, const OV<SValue>& value);

															// Class methods
		static			SError								getInvalidCountError(UInt32 count);
		static			SError								getInvalidDocumentTypeError(const CString& documentType);
		static			SError								getInvalidStartIndexError(UInt32 startIndex);

		static			SError								getMissingFromIndexError(const CString& key);

		static			SError								getUnknownAssociationError(const CString& name);

		static			SError								getUnknownAttachmentIDError(const CString& attachmentID);

		static			SError								getUnknownCacheError(const CString& name);
		static			SError								getUnknownCacheValueName(const CString& valueName);
		static			SError								getUnknownCacheValueSelector(const CString& selector);

		static			SError								getUnknownCollectionError(const CString& name);

		static			SError								getUnknownDocumentIDError(const CString& documentID);
		static			SError								getUnknownDocumentTypeError(const CString& documentType);

		static			SError								getUnknownIndexError(const CString& name);

		static			SError								getIllegalInBatchError();

	protected:
															// Lifecycle methods
															CMDSDocumentStorage();

															// Subclass methods
						void								notifyDocumentChanged(const I<CMDSDocument>& document,
																	CMDSDocument::ChangeKind documentChangeKind) const;

	private:
															// Instance methods
						CString								associationName(const CString& fromDocumentType,
																	const CString& toDocumentType)
																{ return fromDocumentType + CString(OSSTR("To")) +
																		toDocumentType.capitalizingFirstLetter(); }

	// Properties
	private:
		Internals*	mInternals;
};
