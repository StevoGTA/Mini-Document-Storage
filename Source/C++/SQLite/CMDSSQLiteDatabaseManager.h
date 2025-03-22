//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDatabaseManager.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSAssociation.h"
#include "CMDSSQLiteDocumentBacking.h"
#include "CSQLiteDatabase.h"
#include "TMDSCache.h"
#include "TMDSIndex.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSSQLiteDatabaseManager

class CMDSSQLiteDatabaseManager {
	// AssociationInfo
	public:
		struct AssociationInfo {
				// Methods
				public:
									// Lifecycle methods
									AssociationInfo(const CString& fromDocumentType, const CString& toDocumentType) :
										mFromDocumentType(fromDocumentType), mToDocumentType(toDocumentType)
										{}
									AssociationInfo(const AssociationInfo& other) :
										mFromDocumentType(other.mFromDocumentType),
												mToDocumentType(other.mToDocumentType)
										{}

									// Instance methods
				const	CString&	getFromDocumentType() const
										{ return mFromDocumentType; }
				const	CString&	getToDocumentType() const
										{ return mToDocumentType; }

			// Properties
			private:
				CString	mFromDocumentType;
				CString	mToDocumentType;
		};

	// CacheValueInfo
	public:
		struct CacheValueInfo {
			// Methods
			public:
									// Lifecycle methods
									CacheValueInfo(const CString& name, const CString& valueType,
											const CString& selector) :
										mName(name), mValueType(valueType), mSelector(selector)
										{}
									CacheValueInfo(const CDictionary& info) :
										mName(info.getString(CString(OSSTR("name")))),
												mValueType(info.getString(CString(OSSTR("valueType")))),
												mSelector(info.getString(CString(OSSTR("selector"))))
										{}
									CacheValueInfo(const CacheValueInfo& other) :
										mName(other.mName), mValueType(other.mValueType), mSelector(other.mSelector)
										{}

									// Instance methods
				const	CString&	getName() const
										{ return mName; }
				const	CString&	getValueType() const
										{ return mValueType; }
				const	CString&	getSelector() const
										{ return mSelector; }

						CDictionary	getInfo() const
										{
											// Setup
											CDictionary	info;
											info.set(CString(OSSTR("name")), mName);
											info.set(CString(OSSTR("valueType")), mValueType);
											info.set(CString(OSSTR("selector")), mSelector);

											return info;
										}

			// Properties
			private:
				CString	mName;
				CString	mValueType;

				CString	mSelector;
		};
		typedef	TArray<CacheValueInfo>	CacheValueInfos;

	// CacheInfo
	public:
		struct CacheInfo {
			public:
											CacheInfo(const CString& documentType,
													const TArray<CString>& relevantProperites,
													const CacheValueInfos& cacheValueInfos, UInt32 lastRevision) :
												mDocumentType(documentType), mRelevantProperties(relevantProperites),
														mCacheValueInfos(cacheValueInfos), mLastRevision(lastRevision)
												{}
											CacheInfo(const CacheInfo& other) :
												mDocumentType(other.mDocumentType),
														mRelevantProperties(other.mRelevantProperties),
														mCacheValueInfos(other.mCacheValueInfos),
														mLastRevision(other.mLastRevision)
												{}

				const	CString&			getDocumentType() const
												{ return mDocumentType; }
				const	TArray<CString>&	getRelevantProperties() const
												{ return mRelevantProperties; }
				const	CacheValueInfos&	getCacheValueInfos() const
												{ return mCacheValueInfos; }
						UInt32				getLastRevision() const
												{ return mLastRevision; }

			private:
				CString			mDocumentType;
				TArray<CString>	mRelevantProperties;
				CacheValueInfos	mCacheValueInfos;
				UInt32			mLastRevision;
		};

	// CollectionInfo
	public:
		struct CollectionInfo {
			public:
											CollectionInfo(const CString& documentType,
													const TArray<CString>& relevantProperites,
													const CString& isIncludedSelector,
													const CDictionary& isIncludedSelectorInfo, UInt32 lastRevision) :
												mDocumentType(documentType), mRelevantProperties(relevantProperites),
														mIsIncludedSelector(isIncludedSelector),
														mIsIncludedSelectorInfo(isIncludedSelectorInfo),
														mLastRevision(lastRevision)
												{}
											CollectionInfo(const CollectionInfo& other) :
												mDocumentType(other.mDocumentType),
														mRelevantProperties(other.mRelevantProperties),
														mIsIncludedSelector(other.mIsIncludedSelector),
														mIsIncludedSelectorInfo(other.mIsIncludedSelectorInfo),
														mLastRevision(other.mLastRevision)
												{}

				const	CString&			getDocumentType() const
												{ return mDocumentType; }
				const	TArray<CString>&	getRelevantProperties() const
												{ return mRelevantProperties; }
				const	CString&			getIsIncludedSelector() const
												{ return mIsIncludedSelector; }
				const	CDictionary&		getIsIncludedSelectorInfo() const
												{ return mIsIncludedSelectorInfo; }
						UInt32				getLastRevision() const
												{ return mLastRevision; }

			private:
				CString			mDocumentType;
				TArray<CString>	mRelevantProperties;
				CString			mIsIncludedSelector;
				CDictionary		mIsIncludedSelectorInfo;
				UInt32			mLastRevision;
		};

	// DocumentContentInfo
	public:
		struct DocumentContentInfo {
			// ProcInfo
			public:
				struct ProcInfo {
					// Procs
					typedef	OV<SError>	(*Proc)(const DocumentContentInfo& documentContentInfo, void* userData);

					// Methods
					public:
									// Lifecycle methods
									ProcInfo(Proc proc, void* userData) : mProc(proc), mUserData(userData) {}
									ProcInfo(const ProcInfo& other) : mProc(other.mProc), mUserData(other.mUserData) {}

									// Instance methods
						OV<SError>	call(const DocumentContentInfo& documentContentInfo) const
										{ return mProc(documentContentInfo, mUserData); }

					// Properties
					private:
						Proc	mProc;
						void*	mUserData;
				};

			// Methods
			public:
										// Lifecycle methods
										DocumentContentInfo(SInt64 id, UniversalTime creationUniversalTime,
												UniversalTime modificationUniversalTime,
												const CDictionary& propertyMap) :
											mID(id), mCreationUniversalTime(creationUniversalTime),
													mModificationUniversalTime(modificationUniversalTime),
													mPropertyMap(propertyMap)
											{}
										DocumentContentInfo(SInt64 id, const SGregorianDate& creationDate,
												const SGregorianDate& modificationDate,
												const CDictionary& propertyMap) :
											mID(id), mCreationUniversalTime(creationDate.getUniversalTime()),
													mModificationUniversalTime(modificationDate.getUniversalTime()),
													mPropertyMap(propertyMap)
											{}
										DocumentContentInfo(const DocumentContentInfo& other) :
											mID(other.mID), mCreationUniversalTime(other.mCreationUniversalTime),
													mModificationUniversalTime(other.mModificationUniversalTime),
													mPropertyMap(other.mPropertyMap)
											{}

										// Instance methods
						SInt64			getID() const
											{ return mID; }
						UniversalTime	getCreationUniversalTime() const
											{ return mCreationUniversalTime; }
						UniversalTime	getModificationUniversalTime() const
											{ return mModificationUniversalTime; }
				const	CDictionary&	getPropertyMap() const
											{ return mPropertyMap; }

			// Properties
			private:
				SInt64			mID;
				UniversalTime	mCreationUniversalTime;
				UniversalTime	mModificationUniversalTime;
				CDictionary		mPropertyMap;
		};

	// DocumentCreateInfo
	public:
		struct DocumentCreateInfo {
			// Methods
			public:
								// Lifecycle methods
								DocumentCreateInfo(SInt64 id, UInt32 revision, UniversalTime creationUniversalTime,
										UniversalTime modificationUniversalTime) :
									mID(id), mRevision(revision), mCreationUniversalTime(creationUniversalTime),
											mModificationUniversalTime(modificationUniversalTime)
									{}
								DocumentCreateInfo(const DocumentCreateInfo& other) :
									mID(other.mID), mRevision(other.mRevision), mCreationUniversalTime(other.mCreationUniversalTime),
											mModificationUniversalTime(other.mModificationUniversalTime)
									{}

								// Instance methods
				SInt64			getID() const
									{ return mID; }
				UInt32			getRevision() const
									{ return mRevision; }
				UniversalTime	getCreationUniversalTime() const
									{ return mCreationUniversalTime; }
				UniversalTime	getModificationUniversalTime() const
									{ return mModificationUniversalTime; }

			// Properties
			private:
				SInt64			mID;
				UInt32			mRevision;
				UniversalTime	mCreationUniversalTime;
				UniversalTime	mModificationUniversalTime;
		};

	// DocumentInfo
	public:
		struct DocumentInfo {
			// KeyProcInfo
			public:
				struct KeyProcInfo {
					// Procs
					typedef	OV<SError>	(*Proc)(const CString& key, const DocumentInfo& documentInfo, void* userData);

					// Methods
					public:
									// Lifecycle methods
									KeyProcInfo(Proc proc, void* userData) : mProc(proc), mUserData(userData) {}
									KeyProcInfo(const KeyProcInfo& other) :
										mProc(other.mProc), mUserData(other.mUserData)
										{}

									// Instance methods
						OV<SError>	call(const CString& key, const DocumentInfo& documentInfo) const
										{ return mProc(key, documentInfo, mUserData); }

					// Properties
					private:
						Proc	mProc;
						void*	mUserData;
				};

			// ProcInfo
			public:
				struct ProcInfo {
					// Procs
					typedef	OV<SError>	(*Proc)(const DocumentInfo& documentInfo, void* userData);

					// Methods
					public:
									// Lifecycle methods
									ProcInfo(Proc proc, void* userData) : mProc(proc), mUserData(userData) {}
									ProcInfo(const ProcInfo& other) : mProc(other.mProc), mUserData(other.mUserData) {}

									// Instance methods
						OV<SError>	call(const DocumentInfo& documentInfo) const
										{ return mProc(documentInfo, mUserData); }

					// Properties
					private:
						Proc	mProc;
						void*	mUserData;
				};

			// Methods
			public:
															// Lifecycle methods
															DocumentInfo(SInt64 id, const CString& documentID,
																	UInt32 revision, bool active) :
																mID(id), mDocumentID(documentID), mRevision(revision),
																		mActive(active)
																{}
															DocumentInfo(const DocumentInfo& other) :
																mID(other.mID), mDocumentID(other.mDocumentID),
																		mRevision(other.mRevision),
																		mActive(other.mActive)
																{}

															// Instance methods
								SInt64						getID() const
																{ return mID; }
						const	CString&					getDocumentID() const
																{ return mDocumentID; }
								UInt32						getRevision() const
																{ return mRevision; }
								bool						isActive() const
																{ return mActive; }

								CMDSDocument::RevisionInfo	getDocumentRevisionInfo() const
																{ return CMDSDocument::RevisionInfo(mDocumentID,
																		mRevision); }

				static			SInt64						getIDFromDocumentInfo(DocumentInfo* documentInfo,
																	void* userData)
																{ return documentInfo->mID; }

			// Properties
			private:
				SInt64	mID;
				CString	mDocumentID;
				UInt32	mRevision;
				bool	mActive;
		};

	// DocumentUpdateInfo
	public:
		struct DocumentUpdateInfo {
			// Methods
			public:
								// Lifecycle methods
								DocumentUpdateInfo(UInt32 revision, UniversalTime modificationUniversalTime) :
									mRevision(revision), mModificationUniversalTime(modificationUniversalTime)
									{}
								DocumentUpdateInfo(const DocumentUpdateInfo& other) :
									mRevision(other.mRevision),
											mModificationUniversalTime(other.mModificationUniversalTime)
									{}

								// Instance methods
				UInt32			getRevision() const
									{ return mRevision; }
				UniversalTime	getModificationUniversalTime() const
									{ return mModificationUniversalTime; }

			// Properties
			private:
				UInt32			mRevision;
				UniversalTime	mModificationUniversalTime;
		};

	// DocumentAttachmentInfo
	public:
		struct DocumentAttachmentInfo {
			// Methods
			public:
														// Lifecycle methods
														DocumentAttachmentInfo(UInt32 revision,
																UniversalTime modificationUniversalTime,
																const CMDSDocument::AttachmentInfo&
																		documentAttachmentInfo) :
															mRevision(revision),
																	mModificationUniversalTime(
																			modificationUniversalTime),
																	mDocumentAttachmentInfo(documentAttachmentInfo)
															{}
														DocumentAttachmentInfo(const DocumentAttachmentInfo& other) :
															mRevision(other.mRevision),
																	mModificationUniversalTime(
																			other.mModificationUniversalTime),
																	mDocumentAttachmentInfo(
																			other.mDocumentAttachmentInfo)
															{}

														// Instance methods
						UInt32							getRevision() const
															{ return mRevision; }
						UniversalTime					getModificationUniversalTime() const
															{ return mModificationUniversalTime; }
				const	CMDSDocument::AttachmentInfo&	getDocumentAttachmentInfo() const
															{ return mDocumentAttachmentInfo; }

			// Properties
			private:
				UInt32							mRevision;
				UniversalTime					mModificationUniversalTime;
				CMDSDocument::AttachmentInfo	mDocumentAttachmentInfo;
		};

	// DocumentAttachmentRemoveInfo
	public:
		struct DocumentAttachmentRemoveInfo {
			// Methods
			public:
								// Lifecycle methods
								DocumentAttachmentRemoveInfo(UInt32 revision, UniversalTime modificationUniversalTime) :
									mRevision(revision), mModificationUniversalTime(modificationUniversalTime)
									{}
								DocumentAttachmentRemoveInfo(const DocumentAttachmentRemoveInfo& other) :
									mRevision(other.mRevision),
											mModificationUniversalTime(other.mModificationUniversalTime)
									{}

								// Instance methods
				UInt32			getRevision() const
									{ return mRevision; }
				UniversalTime	getModificationUniversalTime() const
									{ return mModificationUniversalTime; }

			// Properties
			private:
				UInt32			mRevision;
				UniversalTime	mModificationUniversalTime;
		};

	// IndexInfo
	public:
		struct IndexInfo {
			public:
													IndexInfo(const CString& documentType,
															const TArray<CString>& relevantProperties,
															const CString& keysSelector,
															const CDictionary& keysSelectorInfo,
															UInt32 lastRevision) :
														mDocumentType(documentType),
																mRelevantProperties(relevantProperties),
																mKeysSelector(keysSelector),
																mKeysSelectorInfo(keysSelectorInfo),
																mLastRevision(lastRevision)
														{}
													IndexInfo(const IndexInfo& other) :
														mDocumentType(other.mDocumentType),
																mRelevantProperties(other.mRelevantProperties),
																mKeysSelector(other.mKeysSelector),
																mKeysSelectorInfo(other.mKeysSelectorInfo),
																mLastRevision(other.mLastRevision)
														{}

						const	CString&			getDocumentType() const
														{ return mDocumentType; }
						const	TArray<CString>&	getRelevantProperties() const
														{ return mRelevantProperties; }
						const	CString&			getKeysSelector() const
														{ return mKeysSelector; }
						const	CDictionary&		getKeysSelectorInfo() const
														{ return mKeysSelectorInfo; }
								UInt32				getLastRevision() const
														{ return mLastRevision; }

			// Properties
			private:
				CString			mDocumentType;
				TArray<CString>	mRelevantProperties;
				CString			mKeysSelector;
				CDictionary		mKeysSelectorInfo;
				UInt32			mLastRevision;
		};

	// Types
	public:
		typedef	TVResult<TArray<CMDSAssociation::Item> >		AssociationItemsResult;

		typedef	void											(*BatchProc)(void* userData);

		typedef	TNumberArray<SInt64>							IDArray;

		typedef	TMDSIndex<SInt64>								Index;
		typedef	Index::KeysInfo									IndexKeysInfo;

		typedef	TNKeyConvertibleDictionary<SInt64, CDictionary>	ValueInfoByID;

	// Classes
	private:
		class	Internals;

	// Methods
	public:
													// Lifecycle methods
													CMDSSQLiteDatabaseManager(const CFolder& folder,
															const CString& name);
													~CMDSSQLiteDatabaseManager();

													// Instance methods
				UInt32								getVariableNumberLimit() const;
				
				void								associationRegister(const CString& name,
															const CString& fromDocumentType,
															const CString& toDocumentType);
				OV<AssociationInfo>					associationInfo(const CString& name);
				TArray<CMDSAssociation::Item>		associationGet(const CString& name, const CString& fromDocumentType,
															const CString& toDocumentType);
				AssociationItemsResult				associationGetFrom(const CString& name,
															const CString& fromDocumentID,
															const CString& fromDocumentType,
															const CString& toDocumentType);
				AssociationItemsResult				associationGetTo(const CString& name,
															const CString& fromDocumentType,
															const CString& toDocumentID, const CString& toDocumentType);
				OV<UInt32>							associationGetCountFrom(const CString& name,
															const CString& fromDocumentID,
															const CString& fromDocumentType);
				OV<UInt32>							associationGetCountTo(const CString& name,
															const CString& toDocumentID, const CString& toDocumentType);
				OV<SError>							associationIterateDocumentInfosFrom(const CString& name,
															const CString& fromDocumentID,
															const CString& fromDocumentType,
															const CString& toDocumentType, UInt32 startIndex,
															const OV<UInt32>& count,
															const DocumentInfo::ProcInfo& documentInfoProcInfo);
				OV<SError>							associationIterateDocumentInfosTo(const CString& name,
															const CString& toDocumentID, const CString& toDocumentType,
															const CString& fromDocumentType, UInt32 startIndex,
															const OV<UInt32>& count,
															const DocumentInfo::ProcInfo& documentInfoProcInfo);
				void								associationUpdate(const CString& name,
															const TArray<CMDSAssociation::Update>& updates,
															const CString& fromDocumentType,
															const CString& toDocumentType);
				TVResult<SValue>					associationDetail(const I<CMDSAssociation>& association,
															const TArray<CString>& fromDocumentIDs,
															const I<TMDSCache<SInt64, ValueInfoByID> >& cache,
															const TArray<CString>& cachedValueNames);
				TVResult<SValue>					associationSum(const I<CMDSAssociation>& association,
															const TArray<CString>& fromDocumentIDs,
															const I<TMDSCache<SInt64, ValueInfoByID> >& cache,
															const TArray<CString>& cachedValueNames);

				UInt32								cacheRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties,
															const TArray<CacheValueInfo>& cacheValueInfos);
				OV<CacheInfo>						cacheInfo(const CString& name);
				void								cacheUpdate(const CString& name,
															const OV<ValueInfoByID>& valueInfoByID,
															const IDArray& removedIDs, const OV<UInt32>& lastRevision);

				UInt32								collectionRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties,
															const CString& isIncludedSelector,
															const CDictionary& isIncludedSelectorInfo, bool isUpToDate);
				OV<CollectionInfo>					collectionInfo(const CString& name);
				UInt32								collectionGetDocumentCount(const CString& name);
				void								collectionIterateDocumentInfos(const CString& name,
															const CString& documentType, UInt32 startIndex,
															const OV<UInt32>& count,
															const DocumentInfo::ProcInfo& documentInfoProcInfo);
				void								collectionUpdate(const CString& name,
															const OV<IDArray >& includedIDs,
															const OV<IDArray >& notIncludedIDs,
															const OV<UInt32>& lastRevision);

				DocumentCreateInfo					documentCreate(const CString& documentType,
															const CString& documentID,
															const OV<UniversalTime>& creationUniversalTime,
															const OV<UniversalTime>& modificationUniversalTime,
															const CDictionary& propertyMap);
				UInt32								documentCount(const CString& documentType);
				bool								documentTypeIsKnown(const CString& documentType);
				void								documentInfoIterate(const CString& documentType,
															const TArray<CString>& documentIDs,
															const DocumentInfo::ProcInfo& documentInfoProcInfo);
				void								documentContentInfoIterate(const CString& documentType,
															const TArray<DocumentInfo>& documentInfos,
															const DocumentContentInfo::ProcInfo&
																	documentContentInfoProcInfo);
				void								documentInfoIterate(const CString& documentType,
															UInt32 sinceRevision, const OV<UInt32>& count,
															bool activeOnly,
															const DocumentInfo::ProcInfo& documentInfoProcInfo);
				DocumentUpdateInfo					documentUpdate(const CString& documentType, SInt64 id,
															const CDictionary& propertyMap);
				void								documentRemove(const CString& documentType, SInt64 id);
				DocumentAttachmentInfo				documentAttachmentAdd(const CString& documentType, SInt64 id,
														const CDictionary& info, const CData& content);
				CMDSDocument::AttachmentInfoByID	documentAttachmentInfoByID(const CString& documentType, SInt64 id);
				CData								documentAttachmentContent(const CString& documentType, SInt64 id,
															const CString& attachmentID);
				DocumentAttachmentInfo				documentAttachmentUpdate(const CString& documentType, SInt64 id,
															const CString& attachmentID, const CDictionary& updatedInfo,
															const CData& updatedContent);
				DocumentAttachmentRemoveInfo		documentAttachmentRemove(const CString& documentType, SInt64 id,
															const CString& attachmentID);

				UInt32								indexRegister(const CString& name, const CString& documentType,
															const TArray<CString>& relevantProperties,
															const CString& keysSelector,
															const CDictionary& keysSelectorInfo);
				OV<IndexInfo>						indexInfo(const CString& name);
				void								indexIterateDocumentInfos(const CString& name,
															const CString& documentType, const TArray<CString>& keys,
															const DocumentInfo::KeyProcInfo& documentInfoKeyProcInfo);
				void								indexUpdate(const CString& name,
															const OV<TArray<IndexKeysInfo> >& indexKeysInfos,
															const OV<IDArray >& removedIDs,
															const OV<UInt32>& lastRevision);

				OV<CString>							infoString(const CString& key);
				void								infoSet(const CString& key, const OV<CString>& string);

				OV<CString>							internalString(const CString& key);
				void								internalSet(const CString& key, const OV<CString>& string);

				void								batch(BatchProc batchProc, void* userData);

	// Properties
	private:
		Internals*	mInternals;
};
