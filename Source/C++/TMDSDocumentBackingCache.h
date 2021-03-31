//----------------------------------------------------------------------------------------------------------------------
//	TMDSDocumentBackingCache.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSDocumentBackingCache

template <typename T> class TMDSDocumentBackingCache {
	// DocumentIDsInfo
	public:
		struct DocumentIDsInfo {
			// Methods
			DocumentIDsInfo(const TArray<CString>& foundDocumentIDs, const TArray<CString>& notFoundDocumentIDs) :
				mFoundDocumentIDs(foundDocumentIDs), mNotFoundDocumentIDs(notFoundDocumentIDs)
				{}
			DocumentIDsInfo(const DocumentIDsInfo& other) :
				mFoundDocumentIDs(other.mFoundDocumentIDs), mNotFoundDocumentIDs(other.mNotFoundDocumentIDs)
				{}

			// Properties
			TArray<CString>	mFoundDocumentIDs;
			TArray<CString>	mNotFoundDocumentIDs;
		};

	// DocumentBackingsInfo
	public:
		struct DocumentBackingsInfo {
			// Methods
			DocumentBackingsInfo(const TArray<CMDSDocument::BackingInfo<T> >& foundDocumentBackingInfos,
					const TArray<CString>& notFoundDocumentIDs) :
				mFoundDocumentBackingInfos(foundDocumentBackingInfos), mNotFoundDocumentIDs(notFoundDocumentIDs)
				{}
			DocumentBackingsInfo(const DocumentBackingsInfo& other) :
				mFoundDocumentBackingInfos(other.mFoundDocumentBackingInfos),
						mNotFoundDocumentIDs(other.mNotFoundDocumentIDs)
				{}

			// Properties
			TArray<CMDSDocument::BackingInfo<T> >	mFoundDocumentBackingInfos;
			TArray<CString>							mNotFoundDocumentIDs;
		};

	// Reference
	private:
		template <typename U> class Reference {
			// Methods
			public:
						// Lifecycle methods
						Reference(const CMDSDocument::BackingInfo<U>& documentBackingInfo) :
							mDocumentBackingInfo(documentBackingInfo),
									mLastReferencedUniversalTime(SUniversalTime::getCurrent())
							{}

						// Instance methods
				void	noteWasReferenced()
							{ mLastReferencedUniversalTime = SUniversalTime::getCurrent(); }
				OR<U>	getDocumentBacking()
							{ return OR<U>(mDocumentBackingInfo.mDocumentBacking); }

			// Properties
			private:
				CMDSDocument::BackingInfo<U>	mDocumentBackingInfo;
				UniversalTime					mLastReferencedUniversalTime;
		};

	// Methods:
	public:
										// Lifecycle methods
										TMDSDocumentBackingCache(UInt32 limit = 1000000) : mLimit(limit) {}
//										~TMDSDocumentBackingCache()
//											{ if (mTimer.hasInstance()) mTimer.invalidate(); }

										// Instance methods
				void					add(const CMDSDocument::BackingInfo<T>& documentBackingInfo)
											{
												// Setup
												mLock.lockForWriting();

												// Store
												mReferenceMap.set(documentBackingInfo.mDocumentID,
														Reference<T>(documentBackingInfo));

												// Reset pruning timer if needed
												resetPruningTimerIfNeeded();

												// Done
												mLock.unlockForWriting();
											}
				void					add(const TArray<CMDSDocument::BackingInfo<T> >& documentBackingInfos)
											{
												// Setup
												mLock.lockForWriting();

												// Iterate all backing infos
												for (TIteratorD<CMDSDocument::BackingInfo<T> > iterator =
																documentBackingInfos.getIterator();
														iterator.hasValue(); iterator.advance())
													// Store
													mReferenceMap.set(iterator->mDocumentID, Reference<T>(*iterator));

												// Reset pruning timer if needed
												resetPruningTimerIfNeeded();

												// Done
												mLock.unlockForWriting();
											}
				OR<T>					getDocumentBacking(const CString& documentID)
											{
												// Setup
												mLock.lockForReading();

												// Retrieve
												OR<Reference<T> >	reference = mReferenceMap[documentID];
												if (reference.hasReference())
													// Note was referenced
													reference->noteWasReferenced();

												// Done
												mLock.unlockForReading();

												return reference.hasReference() ?
														reference->getDocumentBacking() : OR<T>();
											}
				DocumentIDsInfo			getDocumentIDsInfo(const TArray<CString>& documentIDs)
											{
												// Setup
												TNArray<CString>	foundDocumentIDs;
												TNArray<CString>	notFoundDocumentIDs;

												mLock.lockForReading();

												// Iterate document IDs
												for (TIteratorD<CString> iterator = documentIDs.getIterator();
														iterator.hasValue(); iterator.advance()) {
													// Look up reference for this document ID
													OR<Reference<T> >	reference = mReferenceMap[*iterator];
													if (reference.hasReference()) {
														// Found
														foundDocumentIDs += *iterator;
														reference->noteWasReferenced();
													} else
														// Not found
														notFoundDocumentIDs += *iterator;
												}

												// Done
												mLock.unlockForReading();

												return DocumentIDsInfo(foundDocumentIDs, notFoundDocumentIDs);
											}
				DocumentBackingsInfo	getDocumentBackingsInfo(const TArray<CString>& documentIDs)
											{
												// Setup
												TNArray<CMDSDocument::BackingInfo<T> >	foundDocumentInfos;
												TNArray<CString>						notFoundDocumentIDs;

												mLock.lockForReading();

												// Iterate document IDs
												for (TIteratorD<CString> iterator = documentIDs.getIterator();
														iterator.hasValue(); iterator.advance()) {
													// Look up reference for this document ID
													OR<Reference<T> >	reference = mReferenceMap[*iterator];
													if (reference.hasReference()) {
														// Found
														foundDocumentInfos += reference->mDocumentBackingInfo;
														reference->noteWasReferenced();
													} else
														// Not found
														notFoundDocumentIDs += *iterator;
												}

												// Done
												mLock.unlockForReading();

												return DocumentBackingsInfo(foundDocumentInfos, notFoundDocumentIDs);
											}
				void					remove(const TArray<CString>& documentIDs)
											{
												// Setup
												mLock.lockForWriting();

												// Iterate document IDs
												for (TIteratorD<CString> iterator = documentIDs.getIterator();
														iterator.hasValue(); iterator.advance())
													// Remove from storage
													mReferenceMap.remove(*iterator);

												// Reset pruning timer if needed
												resetPruningTimerIfNeeded();

												// Done
												mLock.unlockForWriting();
											}

	private:
										// Instance methods
				void					resetPruningTimerIfNeeded()
											{
												// Invalidate existing timer
//												if (mTimer.hasInstance()) mTimer.invalidate();

//												// Check if need to prune
//												if (mReferenceMap.getKeyCount() > mLimit)
//													// Need to prune
//													mTimer = OI<CTimer>(CTimer(5.0, timerProc));
											}
				void					prune()
											{
												// Setup
												mLock.lockForWriting();

												// Only need to consider things if we have moved past the document limit
												SInt32	countToRemove = mReferenceMap.getKeyCount() - mLimit;
												if (countToRemove > 0) {
													// Iterate all references
// Currently broken in Swift.  Waiting until is fixed there to implement here.
//													UniversalTime	earliestReferencedUniversalTime =
//																			SUniversalTime::getDistantFuture();
//													for (TIteratorS<Reference<T> > iterator =
//																	mReferenceMap.getIterator();
//															iterator.hasValue(); iterator.advance()) {
//														// Compare date
//														if (iterator->mLastReferencedUniversalTime <
//																earliestReferencedUniversalTime) {
//															// Update references to remove
//
//														}
//													}
												}

												// Done
												mLock.unlockForWriting();
											}

										// Class methods
		static	void					timerProc(TMDSDocumentBackingCache<T>& documentBackingCache)
											{ documentBackingCache.prune(); }

	// Properties:
	private:
		CReadPreferringLock			mLock;
//		OI<CTimer>					mTimer;
		TNDictionary<Reference<T> >	mReferenceMap;
		UInt32						mLimit;
};
