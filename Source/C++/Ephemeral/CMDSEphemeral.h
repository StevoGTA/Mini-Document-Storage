//----------------------------------------------------------------------------------------------------------------------
//	CMDSEphemeral.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocumentStorage.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSEphemeral

class CMDSEphemeralInternals;
class CMDSEphemeral : public CMDSDocumentStorage {
	// Methods
	public:
										// Lifecycle methods
										CMDSEphemeral();
										~CMDSEphemeral();

										// CMDSDocumentStorage methods
		const	CString&				getID() const;

				TDictionary<CString>	getInfo(const TArray<CString>& keys) const;
				void					set(const TDictionary<CString>& info);
				void					remove(const TArray<CString>& keys);

				I<CMDSDocument>			newDocument(const CMDSDocument::InfoForNew& infoForNew);

				OI<CMDSDocument>		getDocument(const CString& documentID, const CMDSDocument::Info& documentInfo)
												const;

				UniversalTime			getCreationUniversalTime(const CMDSDocument& document) const;
				UniversalTime			getModificationUniversalTime(const CMDSDocument& document) const;

				OI<CDictionary::Value>	getValue(const CString& property, const CMDSDocument& document) const;
				OI<CData>				getData(const CString& property, const CMDSDocument& document) const;
				OV<UniversalTime>		getUniversalTime(const CString& property, const CMDSDocument& document) const;
				void					set(const CString& property, const OI<CDictionary::Value>& value,
												const CMDSDocument& document,
												SetValueInfo setValueInfo = kNothingSpecial);

				void					remove(const CMDSDocument& document);

				void					iterate(const CMDSDocument::Info& documentInfo, CMDSDocument::Proc proc,
												void* userData) const;
				void					iterate(const CMDSDocument::Info& documentInfo,
												const TArray<CString>& documentIDs, CMDSDocument::Proc proc,
												void* userData) const;

				void					batch(BatchProc batchProc, void* userData);

				void					registerAssociation(const CString& name,
												const CMDSDocument::Info& fromDocumentInfo,
												const CMDSDocument::Info& toDocumenInfo);
				void					updateAssociation(const CString& name,
												const TArray<AssociationUpdate>& updates);
				void					iterateAssociationFrom(const CString& name, const CMDSDocument& fromDocument,
												CMDSDocument::Proc proc, void* userData) const;
				void					iterateAssociationTo(const CString& name, const CMDSDocument& toDocument,
												CMDSDocument::Proc proc, void* userData) const;

				CDictionary::Value		retrieveAssociationValue(const CString& name, const CString& fromDocumentType,
												const CMDSDocument& toDocument, const CString& summedCachedValueName);

				void					registerCache(const CString& name, const CMDSDocument::Info& documentInfo,
												UInt32 version, const TArray<CString>& relevantProperties,
												const TArray<CacheValueInfo>& cacheValueInfos);

				void					registerCollection(const CString& name, const CMDSDocument::Info& documentInfo,
												UInt32 version, const TArray<CString>& relevantProperties,
												bool isUpToDate, const CString& isIncludedSelector,
												const CDictionary& isIncludedSelectorInfo,
												CMDSDocument::IsIncludedProc isIncludedProc, void* userData);
				UInt32					queryCollectionDocumentCount(const CString& name) const;
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

	// Properties
	private:
		CMDSEphemeralInternals*	mInternals;
};
