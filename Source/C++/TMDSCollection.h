//----------------------------------------------------------------------------------------------------------------------
//	TMDSCollection.h			©2007 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSCollection

template <typename T, typename U> class TMDSCollection {
	// UpdateInfo
	public:
		template <typename V> struct UpdateInfo {
			// Lifecycle methods
			UpdateInfo(const V& includedValues, const V& notIncludedValues, UInt32 lastRevision) :
				mIncludedValues(includedValues), mNotIncludedValues(notIncludedValues), mLastRevision(lastRevision)
				{}
			UpdateInfo(const UpdateInfo& other) :
				mIncludedValues(other.mIncludedValues), mNotIncludedValues(other.mNotIncludedValues),
						mLastRevision(other.mLastRevision)
				{}

			// Properties
			V		mIncludedValues;
			V		mNotIncludedValues;
			UInt32	mLastRevision;
		};

	// Methods
	public:
								// Lifecycle methods
								TMDSCollection(const CString& name, const CString& documentType,
										const TArray<CString>& relevantProperties, UInt32 lastRevision,
										CMDSDocument::IsIncludedProc isIncludedProc, void* isIncludedProcUserData) :
									mName(name), mDocumentType(documentType), mRelevantProperties(relevantProperties),
											mLastRevision(lastRevision),
											mIsIncludedProc(isIncludedProc),
											mIsIncludedProcUserData(isIncludedProcUserData)
									{}

								// Instance methods
		const	CString&		getName() const
									{ return mName; }
		const	CString&		getDocumentType() const
									{ return mDocumentType; }
				UInt32			getLastRevision() const
									{ return mLastRevision; }

				UpdateInfo<U>	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
									{
										// Compose results
										U	includedValues;
										U	notIncludedValues;
										for (TIteratorD<TMDSUpdateInfo<T> > iterator = updateInfos.getIterator();
												iterator.hasValue(); iterator.advance()) {
											// Check if there is something to do
											if (!iterator->mChangedProperties.hasInstance() ||
													(mRelevantProperties.intersects(*iterator->mChangedProperties))) {
												// Query
												if (mIsIncludedProc(iterator->mDocument, mIsIncludedProcUserData))
													// Included
													includedValues += iterator->mValue;
												else
													// Not included
													notIncludedValues += iterator->mValue;
											}

											// Update last revision
											mLastRevision = std::max<UInt32>(mLastRevision, iterator->mRevision);
										}

										return UpdateInfo<U>(includedValues, notIncludedValues, mLastRevision);
									}
				UpdateInfo<U>	bringUpToDate(const TArray<TMDSBringUpToDateInfo<T> >& bringUpToDateInfos)
									{
										// Compose results
										U	includedValues;
										U	notIncludedValues;
										for (TIteratorD<TMDSBringUpToDateInfo<T> > iterator =
														bringUpToDateInfos.getIterator();
												iterator.hasValue(); iterator.advance()) {
											// Query
											if (mIsIncludedProc(iterator->mDocument, mIsIncludedProcUserData))
												// Included
												includedValues += iterator->mValue;
											else
												// Not included
												notIncludedValues += iterator->mValue;

											// Update last revision
											mLastRevision = std::max<UInt32>(mLastRevision, iterator->mRevision);
										}

										return UpdateInfo<U>(includedValues, notIncludedValues, mLastRevision);
									}

	// Properties
	private:
				CString							mName;
		const	CString&						mDocumentType;
				TSet<CString>					mRelevantProperties;
				UInt32							mLastRevision;

				CMDSDocument::IsIncludedProc	mIsIncludedProc;
				void*							mIsIncludedProcUserData;
};
