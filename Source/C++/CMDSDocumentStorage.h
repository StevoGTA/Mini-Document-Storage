//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocumentStorage.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"
#include "SMDSValue.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocumentStorage

class CMDSDocumentStorage {
	// Set Value info
	public:
		enum SetValueInfo {
			kNothingSpecial,
			kUniversalTime,
		};

	// Batch Result
	public:
		enum BatchResult {
			kCommit,
			kCancel,
		};

	// Association Update
	public:
		struct AssociationUpdate {
			// Action
			enum Action {
				kAdd,
				kRemove,
			};

			// Lifecycle methods
			AssociationUpdate(Action action, const CMDSDocument& fromDocument, const CMDSDocument& toDocument) :
				mAction(action), mFromDocument(fromDocument), mToDocument(toDocument)
				{}

			// Properties
					Action			mAction;
			const	CMDSDocument&	mFromDocument;
			const	CMDSDocument&	mToDocument;
		};

	// CacheValueInfo
	public:
		struct CacheValueInfo {
			// Value type
			enum ValueType {
				kSInt64,
			};

			// Properties
			CString	mName;
			ValueType	mValueType;
			CString		mSelector;
//			???			mProc;
			void*		mUserData;
		};

	// Procs
	public:
		typedef	BatchResult	(*BatchProc)(void* userData);

	// Methods
	public:
													// Instance methods
		virtual	const	CString&					getID() const = 0;

		virtual			TDictionary<CString>		getInfo(const TArray<CString>& keys) const = 0;
						OR<CString>					getString(const CString& key) const
														{ return getInfo(TSArray<CString>(key))[key]; }
		virtual			void						set(const TDictionary<CString>& info) = 0;
		virtual			void						remove(const TArray<CString>& keys) = 0;

		virtual			I<CMDSDocument>				newDocument(const CMDSDocument::InfoForNew& infoForNew) = 0;

		virtual			OI<CMDSDocument>			getDocument(const CString& documentID,
															const CMDSDocument::Info& documentInfo) const = 0;

		virtual			UniversalTime				getCreationUniversalTime(const CMDSDocument& document) const = 0;
		virtual			UniversalTime				getModificationUniversalTime(const CMDSDocument& document) const
															= 0;

		virtual			OV<SValue>					getValue(const CString& property, const CMDSDocument& document)
															const = 0;
		virtual			OV<CData>					getData(const CString& property, const CMDSDocument& document) const
															= 0;
		virtual			OV<UniversalTime>			getUniversalTime(const CString& property,
															const CMDSDocument& document) const = 0;
		virtual			void						set(const CString& property, const OV<SValue>& value,
															const CMDSDocument& document,
 															SetValueInfo setValueInfo = kNothingSpecial) = 0;

		virtual			void						remove(const CMDSDocument& document) = 0;

		virtual			void						iterate(const CMDSDocument::Info& documentInfo,
															CMDSDocument::Proc proc, void* userData) = 0;
		virtual			void						iterate(const CMDSDocument::Info& documentInfo,
															const TArray<CString>& documentIDs,
															CMDSDocument::Proc proc, void* userData) = 0;
						TArray<CMDSDocument>		getDocuments(const CMDSDocument::Info& documentInfo) const;
						TArray<CMDSDocument>		getDocuments(const CMDSDocument::Info& documentInfo,
															const TArray<CString>& documentIDs);

		virtual			void						batch(BatchProc batchProc, void* userData) = 0;

		virtual			void						registerAssociation(const CString& name,
															const CMDSDocument::Info& fromDocumentInfo,
															const CMDSDocument::Info& toDocumentInfo) = 0;
						void						registerAssociation(const CMDSDocument::Info& fromDocumentInfo,
															const CMDSDocument::Info& toDocumentInfo);
		virtual			void						updateAssociation(const CString& name,
															const TArray<AssociationUpdate>& updates) = 0;
						void						updateAssociation(const CMDSDocument::Info& fromDocumentInfo,
															const CMDSDocument::Info& toDocumentInfo,
															const TArray<AssociationUpdate>& updates);
//		virtual			void						iterateAssociationFrom(const CString& name,
//															const CMDSDocument& fromDocument, CMDSDocument::Proc proc,
//															void* userData) const = 0;
//						void						iterateAssociationFrom(const CMDSDocument& fromDocument,
//															const CMDSDocument::Info& toDocumentInfo,
//															CMDSDocument::Proc proc, void* userData) const;
		virtual			void						iterateAssociationTo(const CString& name,
															const CMDSDocument::Info& fromDocumentInfo,
															const CMDSDocument& toDocument, CMDSDocument::Proc proc,
															void* userData) = 0;
						void						iterateAssociationTo(const CMDSDocument::Info& fromDocumentInfo,
															const CMDSDocument& toDocument, CMDSDocument::Proc proc,
															void* userData);
						TArray<CMDSDocument>		getDocumentsAssociatedTo(const CMDSDocument::Info& fromDocumentInfo,
															const CMDSDocument& toDocument);

//		virtual			SValue						retrieveAssociationValue(const CString& name,
//															const CString& fromDocumentType,
//															const CMDSDocument& toDocument,
//															const CString& summedCachedValueName) = 0;
//						SValue						retrieveAssociationValue(const CMDSDocument::Info& fromDocumentInfo,
//															const CMDSDocument& toDocument,
//															const CString& summedCachedValueName);

//		virtual			void						registerCache(const CString& name,
//															const CMDSDocument::Info& documentInfo, UInt32 version,
//															const TArray<CString>& relevantProperties,
//															const TArray<CacheValueInfo>& cacheValueInfos) = 0;
//						void						registerCache(const CString& name,
//															const CMDSDocument::Info& documentInfo,
//															const TArray<CString>& relevantProperties,
//															const TArray<CacheValueInfo>& cacheValueInfos)
//														{ registerCache(name, documentInfo, 1, relevantProperties,
//																	cacheValueInfos); }

		virtual			void						registerCollection(const CString& name,
															const CMDSDocument::Info& documentInfo, UInt32 version,
															const TArray<CString>& relevantProperties, bool isUpToDate,
															const CString& isIncludedSelector,
															const CDictionary& isIncludedSelectorInfo,
															CMDSDocument::IsIncludedProc isIncludedProc, void* userData)
															= 0;
						void						registerCollection(const CString& name,
															const CMDSDocument::Info& documentInfo,
															const TArray<CString>& relevantProperties,
															CMDSDocument::IsIncludedProc isIncludedProc, void* userData)
														{ registerCollection(name, documentInfo, 1, relevantProperties,
																false, CString::mEmpty, CDictionary::mEmpty,
																isIncludedProc, userData); }
		virtual			UInt32						getCollectionDocumentCount(const CString& name) const = 0;
		virtual			void						iterateCollection(const CString& name,
															const CMDSDocument::Info& documentInfo,
															CMDSDocument::Proc proc, void* userData) const = 0;
						TArray<CMDSDocument>		getCollectionDocuments(const CString& name,
															const CMDSDocument::Info& documentInfo) const;

		virtual			void						registerIndex(const CString& name,
															const CMDSDocument::Info& documentInfo, UInt32 version,
															const TArray<CString>& relevantProperties, bool isUpToDate,
															const CString& keysSelector,
															const CDictionary& keysSelectorInfo,
															CMDSDocument::KeysProc keysProc, void* userData) = 0;
						void						registerIndex(const CString& name,
															const CMDSDocument::Info& documentInfo,
															const TArray<CString>& relevantProperties,
															CMDSDocument::KeysProc keysProc, void* userData)
														{ registerIndex(name, documentInfo, 1, relevantProperties,
																false, CString::mEmpty, CDictionary::mEmpty, keysProc,
																userData); }
		virtual			void						iterateIndex(const CString& name, const TArray<CString>& keys,
															const CMDSDocument::Info& documentInfo,
															CMDSDocument::KeyProc keyProc, void* userData) const = 0;
						TDictionary<CMDSDocument>	getIndexDocumentMap(const CString& name, const TArray<CString> keys,
															const CMDSDocument::Info& documentInfo) const;

		virtual			void						registerDocumentChangedProc(const CString& documentType,
															CMDSDocument::ChangedProc changedProc, void* userData) = 0;

	protected:
													// Lifecycle methods
													CMDSDocumentStorage() {}
		virtual										~CMDSDocumentStorage() {}
};
