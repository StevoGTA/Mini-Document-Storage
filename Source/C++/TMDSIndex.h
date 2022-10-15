//----------------------------------------------------------------------------------------------------------------------
//	TMDSIndex.h			©2007 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSDocument.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: TMDSIndex

template <typename T> class TMDSIndex {
	// KeysInfo
	public:
		template <typename U> struct KeysInfo {
			// Lifecycle methods
			KeysInfo(const TArray<CString>& keys, U value) : mKeys(keys), mValue(value) {}

			// Properties
			TArray<CString>	mKeys;
			U				mValue;
		};

	// UpdateInfo
	public:
		template <typename U> struct UpdateInfo {
			// Lifecycle methods
			UpdateInfo(const TMArray<KeysInfo<U> >& keysInfos, UInt32 lastRevision) :
				mKeysInfos(keysInfos), mLastRevision(lastRevision)
				{}

			// Properties
			TMArray<KeysInfo<U> >	mKeysInfos;
			UInt32					mLastRevision;
		};

	// Methods
	public:
								// Lifecycle methods
								TMDSIndex(const CString& name, const CString& documentType,
										const TArray<CString>& relevantProperties, UInt32 lastRevision,
										CMDSDocument::KeysProc keysProc, void* keysProcUserData) :
									mName(name), mDocumentType(documentType), mRelevantProperties(relevantProperties),
											mLastRevision(lastRevision), mKeysProc(keysProc),
											mKeysProcUserData(keysProcUserData)
									{}

								// Instance methods
		const	CString&		getName() const
									{ return mName; }
		const	CString&		getDocumentType() const
									{ return mDocumentType; }
				UInt32			getLastRevision() const
									{ return mLastRevision; }

				UpdateInfo<T>	update(const TArray<TMDSUpdateInfo<T> >& updateInfos)
									{
										// Compose results
										TNArray<KeysInfo<T> >	keysInfos;
										for (TIteratorD<TMDSUpdateInfo<T> > iterator = updateInfos.getIterator();
												iterator.hasValue(); iterator.advance()) {
											// Check if there is something to do
											if (!iterator->mChangedProperties.hasValue() ||
													(mRelevantProperties.intersects(*iterator->mChangedProperties))) {
												// Update keys info
												keysInfos +=
														KeysInfo<T>(mKeysProc(iterator->mDocument, mKeysProcUserData),
																iterator->mValue);
											}

											// Update last revision
											mLastRevision = std::max<UInt32>(mLastRevision, iterator->mRevision);
										}

										return UpdateInfo<T>(keysInfos, mLastRevision);
									}
				UpdateInfo<T>	bringUpToDate(const TArray<TMDSBringUpToDateInfo<T> >& bringUpToDateInfos)
									{
										// Compose results
										TNArray<KeysInfo<T> >	keysInfos;
										for (TIteratorD<TMDSBringUpToDateInfo<T> > iterator =
														bringUpToDateInfos.getIterator();
												iterator.hasValue(); iterator.advance()) {
											// Update keys info
											keysInfos +=
													KeysInfo<T>(mKeysProc(iterator->mDocument, mKeysProcUserData),
															iterator->mValue);

											// Update last revision
											mLastRevision = std::max<UInt32>(mLastRevision, iterator->mRevision);
										}

										return UpdateInfo<T>(keysInfos, mLastRevision);
									}

	// Properties
	private:
				CString					mName;
		const	CString&				mDocumentType;
				TSet<CString>			mRelevantProperties;
				UInt32					mLastRevision;

				CMDSDocument::KeysProc	mKeysProc;
				void*					mKeysProcUserData;
};
