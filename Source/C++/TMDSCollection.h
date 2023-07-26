//----------------------------------------------------------------------------------------------------------------------
//	TMDSCollection.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSCollection

template <typename T, typename U> class TMDSCollection {
	// UpdateResults
	public:
		template <typename V> struct UpdateResults {
			// Lifecycle methods
			UpdateResults(const OV<V>& includedIDs, const OV<V>& notIncludedIDs, const OV<UInt32>& lastRevision) :
				mIncludedIDs(includedIDs), mNotIncludedIDs(notIncludedIDs), mLastRevision(lastRevision)
				{}
			UpdateResults(const UpdateResults& other) :
				mIncludedIDs(other.mIncludedIDs), mNotIncludedIDs(other.mNotIncludedIDs),
						mLastRevision(other.mLastRevision)
				{}

			// Properties
			OV<V>		mIncludedIDs;
			OV<V>		mNotIncludedIDs;
			OV<UInt32>	mLastRevision;
		};

	// Methods
	public:
									// Lifecycle methods
									TMDSCollection(const CString& name, const CString& documentType,
											const TArray<CString>& relevantProperties,
											CMDSDocument::IsIncludedProc isIncludedProc, void* isIncludedProcUserData,
											const CDictionary& isIncludedInfo, UInt32 lastRevision) :
										mName(name), mDocumentType(documentType),
												mRelevantProperties(relevantProperties),
												mLastRevision(lastRevision),
												mIsIncludedProc(isIncludedProc),
												mIsIncludedProcUserData(isIncludedProcUserData),
												mIsIncludedInfo(isIncludedInfo)
										{}

									// Instance methods
		const	CString&			getName() const
										{ return mName; }
		const	CString&			getDocumentType() const
										{ return mDocumentType; }
				UInt32				getLastRevision() const
										{ return mLastRevision; }

				UpdateResults<U>	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
										{
											// Compose results
											U			includedIDs;
											U			notIncludedIDs;
											OV<UInt32>	lastRevision;
											for (TIteratorD<TMDSUpdateInfo<T> > iterator = updateInfos.getIterator();
													iterator.hasValue(); iterator.advance()) {
												// Check if there is something to do
												if (!iterator->mChangedProperties.hasValue() ||
														(mRelevantProperties.intersects(
																*iterator->mChangedProperties))) {
													// Query
													if (mIsIncludedProc(iterator->mDocument, mIsIncludedProcUserData,
															mIsIncludedInfo))
														// Included
														includedIDs += iterator->mID;
													else
														// Not included
														notIncludedIDs += iterator->mID;
												}

												// Update last revision
												mLastRevision = std::max<UInt32>(mLastRevision, iterator->mRevision);
												lastRevision.setValue(mLastRevision);
											}

											return UpdateResults<U>(
													!includedIDs.isEmpty() ? OV<U>(includedIDs) : OV<U>(),
													!notIncludedIDs.isEmpty() ? OV<U>(notIncludedIDs) : OV<U>(),
													lastRevision);
										}

	// Properties
	private:
				CString							mName;
		const	CString&						mDocumentType;
				TNSet<CString>					mRelevantProperties;

				UInt32							mLastRevision;

				CMDSDocument::IsIncludedProc	mIsIncludedProc;
				void*							mIsIncludedProcUserData;
				CDictionary						mIsIncludedInfo;
};
