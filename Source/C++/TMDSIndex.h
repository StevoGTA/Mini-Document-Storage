//----------------------------------------------------------------------------------------------------------------------
//	TMDSIndex.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"
#include "CppToolboxAssert.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSIndex

template <typename T> class TMDSIndex : public CEquatable {
	// KeysInfo
	public:
		struct KeysInfo {
			// Methods
													// Lifecycle methods
													KeysInfo(const TArray<CString>& keys, const T& id) :
														mKeys(keys), mID(id)
														{}

													// Instance methods
						const	TArray<CString>&	getKeys() const
														{ return mKeys; }
						const	T&					getID() const
														{ return mID; }

				static			T					getID(CArray::ItemRef item, void* userData)
														{ return ((KeysInfo*) item)->mID; }

			// Properties
			private:
				TArray<CString>	mKeys;
				T				mID;
		};

	// UpdateResults
	public:
		struct UpdateResults {
											// Lifecycle methods
											UpdateResults(const OV<TArray<KeysInfo> >& keysInfos,
													const OV<UInt32>& lastRevision) :
												mKeysInfos(keysInfos), mLastRevision(lastRevision)
												{}

											// Instance methods
			const	OV<TArray<KeysInfo> >&	getKeysInfos() const
												{ return mKeysInfos; }
			const	OV<UInt32>&				getLastRevision() const
												{ return mLastRevision; }

			// Properties
			private:
				OV<TArray<KeysInfo> >	mKeysInfos;
				OV<UInt32>				mLastRevision;
		};

	// Methods
	public:
								// Lifecycle methods
								TMDSIndex(const CString& name, const CString& documentType,
										const OV<TArray<CString> >& relevantProperties,
										const CMDSDocument::KeysPerformer& documentKeysPerformer,
										const CDictionary& keysInfo, UInt32 lastRevision) :
									mName(name), mDocumentType(documentType),
											mRelevantProperties(
													relevantProperties.hasValue() ?
															OV<TSet<CString> >(TNSet<CString>(*relevantProperties)) :
															OV<TSet<CString> >()),
											mDocumentKeysPerformer(documentKeysPerformer), mKeysInfo(keysInfo),
											mLastRevision(lastRevision)
									{
										// Must have no entry or at least 1 item
										AssertFailIf(relevantProperties.hasValue() && relevantProperties->isEmpty());
									}

								// CEquatable methods
				bool			operator==(const CEquatable& other) const
									{ return mName == ((const TMDSIndex<T>&) other).mName; }

								// Instance methods
		const	CString&		getName() const
									{ return mName; }
		const	CString&		getDocumentType() const
									{ return mDocumentType; }
				UInt32			getLastRevision() const
									{ return mLastRevision; }

				UpdateResults	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
									{
										// Compose results
										TNArray<KeysInfo>	keysInfos;
										OV<UInt32>			lastRevision;
										for (typename TArray<TMDSUpdateInfo<T> >::Iterator iterator =
														updateInfos.getIterator();
												iterator; iterator++) {
											// Check if there is something to do
											if (!mRelevantProperties.hasValue() ||
													!iterator->getChangedProperties().hasValue() ||
													(mRelevantProperties->intersects(
															*iterator->getChangedProperties()))) {
												// Update keys info
												keysInfos +=
														KeysInfo(
																mDocumentKeysPerformer.perform(mDocumentType,
																		iterator->getDocument(), mKeysInfo),
																iterator->getID());
											}

											// Update last revision
											mLastRevision = std::max<UInt32>(mLastRevision, iterator->getRevision());
											lastRevision.setValue(mLastRevision);
										}

										return UpdateResults(
												!keysInfos.isEmpty() ? OV<TArray<KeysInfo> >(keysInfos) :
														OV<TArray<KeysInfo> >(),
												lastRevision);
									}

	// Properties
	private:
		CString						mName;
		CString						mDocumentType;
		
		OV<TSet<CString> >			mRelevantProperties;
		CMDSDocument::KeysPerformer	mDocumentKeysPerformer;
		CDictionary					mKeysInfo;

		UInt32						mLastRevision;
};
