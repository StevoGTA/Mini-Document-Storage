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
			public:
											// Lifecycle methods
											DocumentIDsInfo(const TArray<CString>& foundDocumentIDs,
													const TArray<CString>& notFoundDocumentIDs) :
												mFoundDocumentIDs(foundDocumentIDs),
														mNotFoundDocumentIDs(notFoundDocumentIDs)
												{}
											DocumentIDsInfo(const DocumentIDsInfo& other) :
												mFoundDocumentIDs(other.mFoundDocumentIDs),
														mNotFoundDocumentIDs(other.mNotFoundDocumentIDs)
												{}

											// Instance methods
				const	TArray<CString>&	getFoundDocumentIDs() const
												{ return mFoundDocumentIDs; }
				const	TArray<CString>&	getNotFoundDocumentIDs() const
												{ return mNotFoundDocumentIDs; }

			// Properties
			private:
				TArray<CString>	mFoundDocumentIDs;
				TArray<CString>	mNotFoundDocumentIDs;
		};

	// DocumentBackingsInfo
	public:
		struct DocumentBackingsInfo {
			// Methods
			public:
											// Lifecycle methods
											DocumentBackingsInfo(const TArray<T>& foundDocumentBackings,
													const TArray<CString>& notFoundDocumentIDs) :
												mFoundDocumentBackings(foundDocumentBackings),
														mNotFoundDocumentIDs(notFoundDocumentIDs)
												{}
											DocumentBackingsInfo(const DocumentBackingsInfo& other) :
												mFoundDocumentBackings(other.mFoundDocumentBackings),
														mNotFoundDocumentIDs(other.mNotFoundDocumentIDs)
												{}

											// Instance methods
				const	TArray<T>&			getFoundDocumentBackings() const
												{ return mFoundDocumentBackings; }
				const	TArray<CString>&	getNotFoundDocumentIDs() const
												{ return mNotFoundDocumentIDs; }
			// Properties
			private:
				TArray<T>		mFoundDocumentBackings;
				TArray<CString>	mNotFoundDocumentIDs;
		};

	// Reference
	private:
		class Reference {
			// Methods
			public:
						// Lifecycle methods
						Reference(const T& documentBacking) :
							mDocumentBacking(documentBacking),
									mLastReferencedUniversalTime(SUniversalTime::getCurrent())
							{}

						// Instance methods
				void	noteWasReferenced()
							{ mLastReferencedUniversalTime = SUniversalTime::getCurrent(); }
				T&		getDocumentBacking()
							{ return mDocumentBacking; }

			// Properties
			private:
				T				mDocumentBacking;
				UniversalTime	mLastReferencedUniversalTime;
		};

	// Methods:
	public:
										// Lifecycle methods
										TMDSDocumentBackingCache(UInt32 limit = 1000000) : mLimit(limit) {}

										// Instance methods
				void					add(const TArray<T>& documentBackings)
											{
												// Setup
												mLock.lockForWriting();

												// Iterate all backing infos
												for (typename TArray<T>::Iterator iterator =
																documentBackings.getIterator();
														iterator; iterator++)
													// Store
													mReferenceByDocumentID.set((*iterator)->getDocumentID(),
															Reference(*iterator));

												// Done
												mLock.unlockForWriting();
											}
		const	OR<T>					getDocumentBacking(const CString& documentID) const
											{
												// Setup
												mLock.lockForReading();

												// Retrieve
												const	OR<Reference>	reference = mReferenceByDocumentID[documentID];
												if (reference.hasReference())
													// Note was referenced
													reference->noteWasReferenced();

												// Done
												mLock.unlockForReading();

												return reference.hasReference() ?
														OR<T>(reference->getDocumentBacking()) : OR<T>();
											}
				DocumentIDsInfo			queryDocumentIDs(const TArray<CString>& documentIDs)
											{
												// Setup
												TNArray<CString>	foundDocumentIDs;
												TNArray<CString>	notFoundDocumentIDs;

												mLock.lockForReading();

												// Iterate document IDs
												for (TArray<CString>::Iterator iterator = documentIDs.getIterator();
														iterator; iterator++) {
													// Look up reference for this document ID
													const	OR<T>	reference = mReferenceByDocumentID[*iterator];
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
				DocumentBackingsInfo	queryDocumentBackings(const TArray<CString>& documentIDs)
											{
												// Setup
												TNArray<T>			foundDocumentBackings;
												TNArray<CString>	notFoundDocumentIDs;

												mLock.lockForReading();

												// Iterate document IDs
												for (TArray<CString>::Iterator iterator = documentIDs.getIterator();
														iterator; iterator++) {
													// Look up reference for this document ID
													const	OR<T>	reference = mReferenceByDocumentID[*iterator];
													if (reference.hasReference()) {
														// Found
														foundDocumentBackings += reference->getDocumentBacking();
														reference->noteWasReferenced();
													} else
														// Not found
														notFoundDocumentIDs += *iterator;
												}

												// Done
												mLock.unlockForReading();

												return DocumentBackingsInfo(foundDocumentBackings, notFoundDocumentIDs);
											}
				void					remove(const TArray<CString>& documentIDs)
											{
												// Setup
												mLock.lockForWriting();

												// Iterate document IDs
												for (TArray<CString>::Iterator iterator = documentIDs.getIterator();
														iterator; iterator++)
													// Remove from storage
													mReferenceByDocumentID.remove(*iterator);

												// Done
												mLock.unlockForWriting();
											}

		const	OR<T>					operator[](const CString& documentID) const
											{ return getDocumentBacking(documentID); }

	// Properties:
	private:
		CReadPreferringLock		mLock;
		TNDictionary<Reference>	mReferenceByDocumentID;
		UInt32					mLimit;
};
