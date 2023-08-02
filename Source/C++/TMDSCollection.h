//----------------------------------------------------------------------------------------------------------------------
//	TMDSCollection.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSCollection

template <typename T, typename AT> class TMDSCollection : public CEquatable {
	// UpdateResults
	public:
		struct UpdateResults {
									// Lifecycle methods
									UpdateResults(const OV<AT>& includedIDs, const OV<AT>&notIncludedIDs,
											const OV<UInt32>& lastRevision) :
										mIncludedIDs(includedIDs), mNotIncludedIDs(notIncludedIDs),
												mLastRevision(lastRevision)
										{}
									UpdateResults(const UpdateResults& other) :
										mIncludedIDs(other.mIncludedIDs), mNotIncludedIDs(other.mNotIncludedIDs),
												mLastRevision(other.mLastRevision)
										{}

								// Instance methods
			const	OV<AT>&		getIncludedIDs() const
									{ return mIncludedIDs; }
			const	OV<AT>&		getNotIncludedIDs() const
									{ return mNotIncludedIDs; }
			const	OV<UInt32>&	getLastRevision() const
									{ return mLastRevision; }

			// Properties
			private:
				OV<AT>		mIncludedIDs;
				OV<AT>		mNotIncludedIDs;
				OV<UInt32>	mLastRevision;
		};

	// Methods
	public:
								// Lifecycle methods
								TMDSCollection(const CString& name, const CString& documentType,
										const TArray<CString>& relevantProperties,
										const CMDSDocument::IsIncludedPerformer& documentIsIncludedPerformer,
										const CDictionary& isIncludedInfo, UInt32 lastRevision) :
									mName(name), mDocumentType(documentType),
											mRelevantProperties(relevantProperties),
											mDocumentIsIncludedPerformer(documentIsIncludedPerformer),
											mIsIncludedInfo(isIncludedInfo),
											mLastRevision(lastRevision)
									{}

								// CEquatable methods
				bool			operator==(const CEquatable& other) const
									{ return mName == ((const TMDSCollection<T, AT>&) other).mName; }

								// Instance methods
		const	CString&		getName() const
									{ return mName; }
		const	CString&		getDocumentType() const
									{ return mDocumentType; }

				UpdateResults	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
										{
											// Compose results
											AT			includedIDs;
											AT			notIncludedIDs;
											OV<UInt32>	lastRevision;
											for (TIteratorD<TMDSUpdateInfo<T> > iterator = updateInfos.getIterator();
													iterator.hasValue(); iterator.advance()) {
												// Check if there is something to do
												if (!iterator->mChangedProperties.hasValue() ||
														(mRelevantProperties.intersects(
																*iterator->mChangedProperties))) {
													// Query
													if (mDocumentIsIncludedPerformer.perform(mDocumentType,
															iterator->mDocument, mIsIncludedInfo))
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

											return UpdateResults(
													!includedIDs.isEmpty() ? OV<AT>(includedIDs) : OV<AT>(),
													!notIncludedIDs.isEmpty() ? OV<AT>(notIncludedIDs) : OV<AT>(),
													lastRevision);
										}

	// Properties
	private:
		CString								mName;
		CString								mDocumentType;

		TNSet<CString>						mRelevantProperties;
		CMDSDocument::IsIncludedPerformer	mDocumentIsIncludedPerformer;
		CDictionary							mIsIncludedInfo;

		UInt32								mLastRevision;
};
