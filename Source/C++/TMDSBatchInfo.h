//----------------------------------------------------------------------------------------------------------------------
//	TMDSBatchInfo.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CDictionary.h"
#include "ConcurrencyPrimitives.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSBatchInfo

template <typename T> class TMDSBatchInfo {
	// Procs
	public:
		typedef	const	OI<SValue>	(*DocumentPropertyValueProc)(const CString& documentID, const CString& property,
											void* internals);

	// DocumentInfo
	public:
		template <typename U> struct DocumentInfo {
			// Procs
			typedef	OI<SError>	(*MapProc)(const CString& documentType,
										const TDictionary<DocumentInfo<U> >& documentInfosMap, void* userData);

									// Lifecycle methods
									DocumentInfo(const CString& documentType, const CString& documentID,
											const OI<U>& reference, UniversalTime creationUniversalTime,
											UniversalTime modificationUniversalTime,
											DocumentPropertyValueProc valueProc, void* valueProcUserData) :
										mDocumentType(documentType), mDocumentID(documentID), mReference(reference),
												mCreationUniversalTime(creationUniversalTime),
												mModificationUniversalTime(modificationUniversalTime), mRemoved(false),
												mValueProc(valueProc), mValueProcUserData(valueProcUserData)
										{}

									// Instance methods
			const	CString&		getDocumentType() const
										{ return mDocumentType; }
			const	CString&		getDocumentID() const
										{ return mDocumentID; }
			const	OI<U>			getReference() const
										{ return mReference; }

					UniversalTime	getCreationUniversalTime() const
										{ return mCreationUniversalTime; }
					UniversalTime	getModificationUniversalTime() const
										{ return mModificationUniversalTime; }
					OI<SValue>		getValue(const CString& property)
										{
											// Setup
											OI<SValue>	value;

											// Check for document removed
											if (mRemoved)
												// Document removed
												return value;

											// Check for value
											bool	returnValue = false;
											mLock.lockForReading();
											if (mRemovedProperties.contains(property))
												// Property removed
												returnValue = true;
											else if (mUpdatedPropertyMap.contains(property)) {
												// Property updated
												value = OI<SValue>(mUpdatedPropertyMap.getValue(property));
												returnValue = true;
											}
											mLock.lockForWriting();
											if (returnValue) return value;

											// Call proc
											return mValueProc(mDocumentID, property, mValueProcUserData);
										}
					void			set(const CString& property, const OI<SValue>& value)
										{
											// Write
											mLock.lockForWriting();
											if (value.hasInstance()) {
												// Have value
												mUpdatedPropertyMap.set(property, *value);
												mRemovedProperties -= property;
											} else {
												// Remove value
												mUpdatedPropertyMap.remove(property);
												mRemovedProperties += property;
											}
											mModificationUniversalTime = SUniversalTime::getCurrent();
											mLock.unlockForWriting();
										}
			const	CDictionary&	getUpdatedPropertyMap() const
										{ return mUpdatedPropertyMap; }
			const	TSet<CString>&	getRemovedProperties() const
										{ return mRemovedProperties; }

					bool			isRemoved() const
										{ return mRemoved; }
					void			remove()
										{ mRemoved = true; }

			// Properties
			private:
				const	CString&					mDocumentType;
						CString						mDocumentID;
						OI<U>						mReference;
						UniversalTime				mCreationUniversalTime;
						UniversalTime				mModificationUniversalTime;
						CDictionary					mUpdatedPropertyMap;
						TSet<CString>				mRemovedProperties;
						bool						mRemoved;

						DocumentPropertyValueProc	mValueProc;
						void*						mValueProcUserData;

						CReadPreferringLock			mLock;
		};

	// Methods
	public:
								// Lifecycle methods
								TMDSBatchInfo() {}

								// Instance methods
		DocumentInfo<T>&		addDocument(const CString& documentType, const CString& documentID,
										const OI<T>& reference, UniversalTime creationUniversalTime,
										UniversalTime modificationUniversalTime, DocumentPropertyValueProc valueProc,
										void* userData)
									{
										// Setup
										DocumentInfo<T>	documentInfo(documentType, documentID, reference,
																creationUniversalTime, modificationUniversalTime,
																valueProc, userData);

										// Add to map
										mDocumentInfoMapLock.lockForWriting();
										mDocumentInfoMap.set(documentID, documentInfo);
										OR<DocumentInfo<T> >	documentInfoReference = mDocumentInfoMap[documentID];
										mDocumentInfoMapLock.unlockForWriting();

										return *documentInfoReference;
									}
		DocumentInfo<T>&		addDocument(const CString& documentType, const CString& documentID,
										UniversalTime creationUniversalTime, UniversalTime modificationUniversalTime)
									{ return addDocument(documentType, documentID, OI<T>(), creationUniversalTime,
											modificationUniversalTime, nil, nil); }
		OR<DocumentInfo<T> >	getDocumentInfo(const CString& documentID) const
									{
										// Get document info
										mDocumentInfoMapLock.lockForReading();
										OR<DocumentInfo<T> >	documentInfo = mDocumentInfoMap[documentID];
										mDocumentInfoMapLock.unlockForReading();

										return documentInfo;
									}
		OI<SError>				iterate(typename DocumentInfo<T>::MapProc mapProc, void* userData)
									{
										// Collate
										TNDictionary<TNDictionary<DocumentInfo<T> > >	map;
										mDocumentInfoMapLock.lockForReading();
										for (TIteratorS<CDictionary::Item> iterator = mDocumentInfoMap.getIterator();
												iterator.hasValue(); iterator.advance()) {
											// Setup
											DocumentInfo<T>&	documentInfo =
																	*((DocumentInfo<T>*) iterator->mValue.getOpaque());

											// Add to collated map
											OR<TNDictionary<DocumentInfo<T> > >	documentInfosMap =
																						map[documentInfo
																								.getDocumentType()];
											if (documentInfosMap.hasReference())
												// Add item
												documentInfosMap->set(documentInfo.getDocumentID(), documentInfo);
											else {
												// Add map
												TNDictionary<DocumentInfo<T> >	newDocumentInfosMap;
												newDocumentInfosMap.set(documentInfo.getDocumentID(), documentInfo);
												map.set(documentInfo.getDocumentType(), newDocumentInfosMap);
											}
										}
										mDocumentInfoMapLock.unlockForReading();

										// Iterate all document types
										for (TIteratorS<CDictionary::Item> iterator = map.getIterator();
												iterator.hasValue(); iterator.advance()) {
											// Setup
											TDictionary<DocumentInfo<T> >&	documentInfosMap =
																					*((TDictionary<DocumentInfo<T> >*)
																							iterator->mValue
																									.getOpaque());

											// Call proc
											OI<SError>	error = mapProc(iterator->mKey, documentInfosMap, userData);

											// Check error
											if (error.hasInstance())
												// Return error
												return error;
										}

										return OI<SError>();
									}

	// Properties
	private:
		TNDictionary<DocumentInfo<T> >	mDocumentInfoMap;
		CReadPreferringLock				mDocumentInfoMapLock;
};
