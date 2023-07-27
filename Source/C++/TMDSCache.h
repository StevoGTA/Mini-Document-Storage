//----------------------------------------------------------------------------------------------------------------------
//	TMDSCache.h			©2023 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSCache

template <typename T> class TMDSCache : public CEquatable {
	// UpdateResults
	public:
		struct UpdateResults {
															// Lifecycle methods
															UpdateResults(
																	const OV<TDictionary<TDictionary<SValue> > >
																			infosByID,
																	const OV<UInt32>& lastRevision) :
																mInfosByID(infosByID), mLastRevision(lastRevision)
																{}
															UpdateResults(const UpdateResults& other) :
																mInfosByID(other.mInfosByID),
																		mLastRevision(other.mLastRevision)
																{}

															// Instance methods
			const	OV<TDictionary<TDictionary<SValue> > >&	getInfosByID() const
																{ return mInfosByID; }
			const	OV<UInt32>&								getLastRevision() const
																{ return mLastRevision; }

			// Properties
			private:
				OV<TDictionary<TDictionary<SValue> > >	mInfosByID;
				OV<UInt32>								mLastRevision;
		};

	// ValueInfo
	public:
		struct ValueInfo {
											// Lifecycle methods
											ValueInfo(const SMDSValueInfo& valueInfo,
													CMDSDocument::ValueProc documentValueProc) :
												mValueInfo(valueInfo), mDocumentValueProc(documentValueProc)
												{}
											ValueInfo(const ValueInfo& other) :
												mValueInfo(other.mValueInfo),
														mDocumentValueProc(other.mDocumentValueProc)
												{}

											// Instance methods
			const	SMDSValueInfo&			getValueInfo() const
												{ return mValueInfo; }
					CMDSDocument::ValueProc	getDocumentValueProc() const
												{ return mDocumentValueProc; }

											// Class methods
			static	bool					compareName(const ValueInfo& valueInfo, CString* name)
												{ return valueInfo.mValueInfo.getName() == *name; }

			// Properties
			private:
				SMDSValueInfo			mValueInfo;
				CMDSDocument::ValueProc	mDocumentValueProc;

		};

	// Methods
	public:
						// Lifecycle methods
						TMDSCache(const CString& name, const CString& documentType,
								const TArray<CString>& relevantProperties, const TArray<ValueInfo>& valueInfos,
								UInt32 lastRevision) :
							mName(name), mDocumentType(documentType), mRelevantProperties(relevantProperties),
									mValueInfos(valueInfos),
									mLastRevision(lastRevision)
							{}

						// CEquatable methods
		bool			operator==(const CEquatable& other) const
							{ return mName == ((const TMDSCache&) other).mName; }

						// Instance methods
		bool			hasValueInfo(const CString& valueName) const
							{ return mValueInfos.getFirst(ValueInfo::compareName, &valueName).hasReference(); }

		UpdateResults	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
							{
								// Compose results
								TNDictionary<TDictionary<SValue> >	infosByID;
								OV<UInt32>							lastRevision;
								for (TIteratorD<TMDSUpdateInfo<T> > updateInfoIterator = updateInfos.getIterator();
										updateInfoIterator.hasValue(); updateInfoIterator.advance()) {
									// Check if there is something to do
									if (!updateInfoIterator->mChangedProperties.hasValue() ||
											(mRelevantProperties.intersects(*updateInfoIterator->mChangedProperties))) {
										// Collect value infos
										TNDictionary<SValue>	valuesByName;
										for (TIteratorD<ValueInfo> valueInfoIterator = mValueInfos.getIterator();
												valueInfoIterator.hasValue(); valueInfoIterator.advance()) {
											// Add entry for this ValueInfo
											const	CString&	valueName = valueInfoIterator->getValueInfo().getName();
											valuesByName.set(valueName,
													valueInfoIterator->getDocumentValueProc(mDocumentType,
															updateInfoIterator->getDocument(), valueName));
										}

										// Update
										infosByID.set(updateInfoIterator->getID(), valuesByName);
									}

									// Update last revision
									mLastRevision = std::max<UInt32>(mLastRevision, updateInfoIterator->mRevision);
									lastRevision.setValue(mLastRevision);
								}

								return UpdateResults(
										!infosByID.isEmpty() ?
												OV<TDictionary<TDictionary<SValue> > >(infosByID) :
												OV<TDictionary<TDictionary<SValue> > >(),
										lastRevision);
							}

	// Properties
	private:
		CString				mName;
		CString				mDocumentType;
		TNSet<CString>		mRelevantProperties;

		TArray<ValueInfo>	mValueInfos;

		UInt32				mLastRevision;
};
