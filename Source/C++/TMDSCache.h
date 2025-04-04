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

template <typename T, typename U> class TMDSCache : public CEquatable {
	// UpdateResults
	public:
		struct UpdateResults {
								// Lifecycle methods
								UpdateResults(const OV<U> valueInfoByID, const OV<UInt32>& lastRevision) :
									mValueInfoByID(valueInfoByID), mLastRevision(lastRevision)
									{}
								UpdateResults(const UpdateResults& other) :
									mValueInfoByID(other.mValueInfoByID), mLastRevision(other.mLastRevision)
									{}

								// Instance methods
			const	OV<U>&		getValueInfoByID() const
									{ return mValueInfoByID; }
			const	OV<UInt32>&	getLastRevision() const
									{ return mLastRevision; }

			// Properties
			private:
				OV<U>		mValueInfoByID;
				OV<UInt32>	mLastRevision;
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
		const	CString&		getDocumentType() const
									{ return mDocumentType; }

				bool			hasValueInfo(const CString& valueName) const
									{ return mValueInfos.getFirst(
											(TArray<SMDSCacheValueInfo>::IsMatchProc) SMDSCacheValueInfo::compareName,
											(void*) &valueName).hasReference(); }

				UpdateResults	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
									{
										// Compose results
										U			valueInfoByID;
										OV<UInt32>	lastRevision;
										for (TIteratorD<TMDSUpdateInfo<T> > updateInfoIterator =
														updateInfos.getIterator();
												updateInfoIterator.hasValue(); updateInfoIterator.advance()) {
											// Check if there is something to do
											if (!updateInfoIterator->getChangedProperties().hasValue() ||
													(mRelevantProperties.intersects(
															*updateInfoIterator->getChangedProperties()))) {
												// Collect value infos
												CDictionary	valueByName;
												for (TIteratorD<SMDSCacheValueInfo> valueInfoIterator =
																mValueInfos.getIterator();
														valueInfoIterator.hasValue(); valueInfoIterator.advance()) {
													// Add entry for this ValueInfo
													const	CString&	valueName =
																				valueInfoIterator->getValueInfo()
																						.getName();
													valueByName.set(valueName,
															valueInfoIterator->getDocumentValueInfo().perform(
																	mDocumentType, updateInfoIterator->getDocument(),
																	valueName));
												}

												// Update
												valueInfoByID.set(updateInfoIterator->getID(), valueByName);
											}

											// Update last revision
											mLastRevision =
													std::max<UInt32>(mLastRevision, updateInfoIterator->getRevision());
											lastRevision.setValue(mLastRevision);
										}

										return UpdateResults(!valueInfoByID.isEmpty() ? OV<U>(valueInfoByID) : OV<U>(),
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
