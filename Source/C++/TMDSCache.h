//----------------------------------------------------------------------------------------------------------------------
//	TMDSCache.h			©2023 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: SMDSCacheValueInfo

struct SMDSCacheValueInfo {
	// Methods
	public:
											// Lifecycle methods
											SMDSCacheValueInfo(const SMDSValueInfo& valueInfo,
													const CMDSDocument::ValueInfo& documentValueInfo) :
												mValueInfo(valueInfo), mDocumentValueInfo(documentValueInfo)
												{}
											SMDSCacheValueInfo(const SMDSCacheValueInfo& other) :
												mValueInfo(other.mValueInfo),
														mDocumentValueInfo(other.mDocumentValueInfo)
												{}

											// Instance methods
		const	SMDSValueInfo&				getValueInfo() const
												{ return mValueInfo; }
		const	CMDSDocument::ValueInfo&	getDocumentValueInfo() const
												{ return mDocumentValueInfo; }

											// Class methods
		static	bool						compareName(const SMDSCacheValueInfo& valueInfo, CString* name)
												{ return valueInfo.mValueInfo.getName() == *name; }

	// Properties
	private:
		SMDSValueInfo			mValueInfo;
		CMDSDocument::ValueInfo	mDocumentValueInfo;
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: - TMDSCache

template <typename T> class TMDSCache : public CEquatable {
	// UpdateResults
	public:
		struct UpdateResults {
													// Lifecycle methods
													UpdateResults(const OV<TDictionary<CDictionary> > infosByID,
															const OV<UInt32>& lastRevision) :
														mInfosByID(infosByID), mLastRevision(lastRevision)
														{}
													UpdateResults(const UpdateResults& other) :
														mInfosByID(other.mInfosByID), mLastRevision(other.mLastRevision)
														{}

													// Instance methods
			const	OV<TDictionary<CDictionary> >&	getInfosByID() const
														{ return mInfosByID; }
			const	OV<UInt32>&						getLastRevision() const
														{ return mLastRevision; }

			// Properties
			private:
				OV<TDictionary<CDictionary> >	mInfosByID;
				OV<UInt32>						mLastRevision;
		};

	// Methods
	public:
								// Lifecycle methods
								TMDSCache(const CString& name, const CString& documentType,
										const TArray<CString>& relevantProperties,
										const TArray<SMDSCacheValueInfo>& valueInfos, UInt32 lastRevision) :
									mName(name), mDocumentType(documentType), mRelevantProperties(relevantProperties),
											mValueInfos(valueInfos),
											mLastRevision(lastRevision)
									{}

								// CEquatable methods
				bool			operator==(const CEquatable& other) const
									{ return mName == ((const TMDSCache&) other).mName; }

								// Instance methods
		const	CString&		getName() const
									{ return mName; }
				bool			hasValueInfo(const CString& valueName) const
									{ return mValueInfos.getFirst(
											(TArray<SMDSCacheValueInfo>::IsMatchProc) SMDSCacheValueInfo::compareName,
											(void*) &valueName).hasReference(); }

				UpdateResults	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
									{
										// Compose results
										TNDictionary<CDictionary>	infosByID;
										OV<UInt32>					lastRevision;
										for (TIteratorD<TMDSUpdateInfo<T> > updateInfoIterator =
														updateInfos.getIterator();
												updateInfoIterator.hasValue(); updateInfoIterator.advance()) {
											// Check if there is something to do
											if (!updateInfoIterator->getChangedProperties().hasValue() ||
													(mRelevantProperties.intersects(
															*updateInfoIterator->getChangedProperties()))) {
												// Collect value infos
												CDictionary	valuesByName;
												for (TIteratorD<SMDSCacheValueInfo> valueInfoIterator =
																mValueInfos.getIterator();
														valueInfoIterator.hasValue(); valueInfoIterator.advance()) {
													// Add entry for this ValueInfo
													const	CString&	valueName =
																				valueInfoIterator->getValueInfo()
																						.getName();
													valuesByName.set(valueName,
															valueInfoIterator->getDocumentValueInfo().perform(
																	mDocumentType, updateInfoIterator->getDocument(),
																	valueName));
												}

												// Update
												infosByID.set(updateInfoIterator->getID(), valuesByName);
											}

											// Update last revision
											mLastRevision =
													std::max<UInt32>(mLastRevision, updateInfoIterator->getRevision());
											lastRevision.setValue(mLastRevision);
										}

										return UpdateResults(
												!infosByID.isEmpty() ?
														OV<TDictionary<CDictionary> >(infosByID) :
														OV<TDictionary<CDictionary> >(),
												lastRevision);
									}

	// Properties
	private:
		CString						mName;
		CString						mDocumentType;
		TNSet<CString>				mRelevantProperties;

		TArray<SMDSCacheValueInfo>	mValueInfos;

		UInt32						mLastRevision;
};
