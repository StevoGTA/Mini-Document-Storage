//----------------------------------------------------------------------------------------------------------------------
//	TMDSIndex.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSIndex

template <typename T> class TMDSIndex : public CEquatable {
	// KeysInfo
	public:
		struct KeysInfo {
											// Lifecycle methods
											KeysInfo(const TArray<CString>& keys, T id) : mKeys(keys), mID(id) {}

											// Instance methods
				const	TArray<CString>&	getKeys() const
												{ return mKeys; }
						T					getID() const
												{ return mID; }

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
										const TArray<CString>& relevantProperties,
										const CMDSDocument::KeysPerformer& documentKeysPerformer,
										const CDictionary& keysInfo, UInt32 lastRevision) :
									mName(name), mDocumentType(documentType),
											mRelevantProperties(relevantProperties),
											mDocumentKeysPerformer(documentKeysPerformer), mKeysInfo(mKeysInfo),
											mLastRevision(lastRevision)
									{}

								// Instance methods
		const	CString&		getName() const
									{ return mName; }
		const	CString&		getDocumentType() const
									{ return mDocumentType; }

				UpdateResults	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
									{
										// Compose results
										TNArray<KeysInfo>	keysInfos;
										OV<UInt32>			lastRevision;
										for (TIteratorD<TMDSUpdateInfo<T> > iterator = updateInfos.getIterator();
												iterator.hasValue(); iterator.advance()) {
											// Check if there is something to do
											if (!iterator->mChangedProperties.hasValue() ||
													(mRelevantProperties.intersects(*iterator->mChangedProperties))) {
												// Update keys info
												keysInfos +=
														KeysInfo(
																mDocumentKeysPerformer(mDocumentType,
																		iterator->mDocument, mKeysInfo),
																iterator->mID);
											}

											// Update last revision
											mLastRevision = std::max<UInt32>(mLastRevision, iterator->mRevision);
											lastRevision.setValue(mLastRevision);
										}

										return UpdateInfo(
												!keysInfos.isEmpty() ? OV<TArray<KeysInfo> >(keysInfos) :
														OV<TArray<KeysInfo> >(),
												lastRevision);
									}

	// Properties
	private:
		CString						mName;
		CString						mDocumentType;
		
		TNSet<CString>				mRelevantProperties;
		CMDSDocument::KeysPerformer	mDocumentKeysPerformer;
		CDictionary					mKeysInfo;

		UInt32						mLastRevision;
};
