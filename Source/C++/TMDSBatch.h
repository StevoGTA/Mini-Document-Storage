//----------------------------------------------------------------------------------------------------------------------
//	TMDSBatch.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CUUID.h"
#include "SMDSAssociation.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: EMDSBatchResult
enum EMDSBatchResult {
	kMDSBatchResultCommit,
	kMDSBatchResultCancel,
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: - TMDSBatch

template <typename DB> class TMDSBatch {
	// AddAttachmentInfo
	public:
		struct AddAttachmentInfo {
			// Methods
			public:
													// Lifecycle methods
													AddAttachmentInfo(const CDictionary& info, const CData& content) :
														mID(CUUID().getBase64String()), mRevision(1), mInfo(info),
																mContent(content)
														{}
													AddAttachmentInfo(const AddAttachmentInfo& other) :
														mID(other.mID), mRevision(other.mRevision), mInfo(other.mInfo),
																mContent(other.mContent)
														{}

													// Instance methods
			const	CString&						getID() const
														{ return mID; }
					UInt32							getRevision() const
														{ return mRevision; }
			const	CDictionary&					getInfo() const
														{ return mInfo; }
			const	CData&							getContent() const
														{ return mContent; }

					CMDSDocument::AttachmentInfo	getDocumentAttachmentInfo() const
														{ return CMDSDocument::AttachmentInfo(mID, mRevision, mInfo); }

			// Properties
			private:
				CString		mID;
				UInt32		mRevision;
				CDictionary	mInfo;
				CData		mContent;
		};

	// UpdateAttachmentInfo
	public:
		struct UpdateAttachmentInfo {
			// Methods
			public:
													// Lifecycle methods
													UpdateAttachmentInfo(const CString& id, UInt32 currentRevision,
															const CDictionary& info, const CData& content) :
														mID(id), mCurrentRevision(currentRevision), mInfo(info),
																mContent(content)
														{}
													UpdateAttachmentInfo(const AddAttachmentInfo& other) :
														mID(other.mID), mCurrentRevision(other.mCurrentRevision),
																mInfo(other.mInfo), mContent(other.mContent)
														{}

													// Instance methods
			const	CString&						getID() const
														{ return mID; }
					UInt32							getCurrentRevision() const
														{ return mCurrentRevision; }
			const	CDictionary&					getInfo() const
														{ return mInfo; }
			const	CData&							getContent() const
														{ return mContent; }

					CMDSDocument::AttachmentInfo	getDocumentAttachmentInfo() const
														{ return CMDSDocument::AttachmentInfo(mID, mCurrentRevision,
																mInfo); }

			// Properties
			private:
				CString		mID;
				UInt32		mCurrentRevision;
				CDictionary	mInfo;
				CData		mContent;
		};

	// DocumentInfo
	public:
		struct DocumentInfo {
			// Types
			typedef	CMDSDocument::AttachmentInfo	AttachmentInfo;
			typedef	CMDSDocument::AttachmentInfoMap	AttachmentInfoMap;

										// Lifecycle methods
										DocumentInfo(const CString& documentType, const OR<DB>& documentBacking,
												UniversalTime creationUniversalTime,
												UniversalTime modificationUniversalTime,
												const OV<CDictionary>& initialPropertyMap) :
											mDocumentType(documentType), mDocumentBacking(documentBacking),
													mCreationUniversalTime(creationUniversalTime),
													mModificationUniversalTime(modificationUniversalTime),
													mRemoved(false),
													mInitialPropertyMap(initialPropertyMap)
											{}

										// Instance methods
//			const	CString&			getDocumentType() const
//											{ return mDocumentType; }
//			const	CString&			getDocumentID() const
//											{ return mDocumentID; }
//			const	OI<DB>				getReference() const
//											{ return mReference; }
//
//					UniversalTime		getCreationUniversalTime() const
//											{ return mCreationUniversalTime; }
//					UniversalTime		getModificationUniversalTime() const
//											{ return mModificationUniversalTime; }
//			const	CDictionary&		getUpdatedPropertyMap() const
//											{ return mUpdatedPropertyMap; }
//			const	TSet<CString>&		getRemovedProperties() const
//											{ return mRemovedProperties; }
//
//					bool				isRemoved() const
//											{ return mRemoved; }


					OV<SValue>			getValue(const CString& property)
											{
												// Check for document removed
												if (mRemoved || mRemovedProperties.contains(property))
													// Removed
													return OV<SValue>();
												else if (mUpdatedPropertyMap.contains(property))
													// Have updated property
													return OV<SValue>(mUpdatedPropertyMap.getValue(property));
												else if (mInitialPropertyMap.hasValue())
													// Try initial property map
													return OV<SValue>(mInitialPropertyMap->getValue(property));
												else
													// Sorry
													return OV<SValue>();
											}
					void				set(const CString& property, const OV<SValue>& value)
											{
												// Write
												if (value.hasValue()) {
													// Have value
													mUpdatedPropertyMap.set(property, *value);
													mRemovedProperties -= property;
												} else {
													// Remove value
													mUpdatedPropertyMap.remove(property);
													mRemovedProperties += property;
												}

												// Modified
												mModificationUniversalTime = SUniversalTime::getCurrent();
											}

					AttachmentInfoMap	getUpdatedDocumentAttachmentInfoMap(
												const CMDSDocument::AttachmentInfoMap& initialDocumentAttachmentInfoMap)
												const
											{
												// Start with initial
												TNDictionary<CMDSDocument::AttachmentInfo>
														updatedDocumentAttachmentInfoMap(
																initialDocumentAttachmentInfoMap);

												// Process adds
												TSet<CString>	keys = mAddAttachmentInfosByID.getKeys();
												for (TIteratorS<CString> iterator = keys.getIterator();
														iterator.hasValue(); iterator.advance())
													// Process add
													updatedDocumentAttachmentInfoMap.set(*iterator,
															mAddAttachmentInfosByID[*iterator]);

												// Process updates
												keys = mUpdateAttachmentInfosByID.getKeys();
												for (TIteratorS<CString> iterator = keys.getIterator();
														iterator.hasValue(); iterator.advance())
													// Process update
													updatedDocumentAttachmentInfoMap.set(*iterator,
															mUpdateAttachmentInfosByID[*iterator]);

												// Process removes
												updatedDocumentAttachmentInfoMap.remove(mRemovedAttachmentIDs);

												return updatedDocumentAttachmentInfoMap;
											}
					OV<CData>			getAttachmentContent(const CString& id) const
											{
												// Check adds
												if (mAddAttachmentInfosByID.contains(id))
													// Have add
													return OV<CData>(mAddAttachmentInfosByID[id]->getContent());
												else if (mUpdateAttachmentInfosByID.contains(id))
													// Have update
													return OV<CData>(mUpdateAttachmentInfosByID[id]->getContent());
												else
													// Nope
													return OV<CData>();
											}
					AttachmentInfo		attachmentAdd(const CDictionary& info, const CData& content)
											{
												// Setup
												AddAttachmentInfo	addAttachmentInfo(info, content);

												// Add info
												mAddAttachmentInfosByID.set(addAttachmentInfo.getID(),
														addAttachmentInfo);

												// Modified
												mModificationUniversalTime = SUniversalTime::getCurrent();

												return addAttachmentInfo;
											}
					void				attachmentUpdate(const CString& id, UInt32 currentRevision,
												const CDictionary& info, const CData& content)
											{
												// Add info
												mUpdateAttachmentInfosByID.set(id,
														UpdateAttachmentInfo(id, currentRevision, info, content));

												// Modified
												mModificationUniversalTime = SUniversalTime::getCurrent();
											}
					void				attachmentRemove(const CString& id)
											{
												// Add it
												mRemovedAttachmentIDs.insert(id);

												// Modified
												mModificationUniversalTime = SUniversalTime::getCurrent();
											}

					void				remove()
											{
												// Removed
												mRemoved = true;

												// Modified
												mModificationUniversalTime = SUniversalTime::getCurrent();
											}

			// Properties
			private:
				const	CString&							mDocumentType;
						OR<DB>								mDocumentBacking;
						UniversalTime						mCreationUniversalTime;

						CDictionary							mUpdatedPropertyMap;
						TNSet<CString>						mRemovedProperties;
						UniversalTime						mModificationUniversalTime;
						TNDictionary<AddAttachmentInfo>		mAddAttachmentInfosByID;
						TNDictionary<UpdateAttachmentInfo>	mUpdateAttachmentInfosByID;
						TNSet<CString>						mRemovedAttachmentIDs;

						bool								mRemoved;

						OV<CDictionary>						mInitialPropertyMap;
		};

	// Methods
	public:
												// Lifecycle methods
												TMDSBatch() {}

												// Instance methods
		void									associationNoteUpdated(const CString& name,
														const TArray<SMDSAssociation::Update>& updates)
													{ mAssociationUpdatesByAssociationName.add(name, updates); }
		TSet<CString>							associationGetUpdatedNames() const
													{ return mAssociationUpdatesByAssociationName.getKeys(); }
		TArray<SMDSAssociation::Update>			associationGetUpdates(const CString& name) const
													{ return mAssociationUpdatesByAssociationName[name]; }
		TArray<SMDSAssociation::Item>			getAssocationItems(const CString& name,
														const TArray<SMDSAssociation::Item>& initialAssociationItems)
														const
													{
														// Start with initial
														TNArray<SMDSAssociation::Item>	associationItemsUpdated(
																								initialAssociationItems);

														// Check if have updates
														if (mAssociationUpdatesByAssociationName.contains(name)) {
															// Get updates
															TArray<SMDSAssociation::Update>	associationUpdates =
																									mAssociationUpdatesByAssociationName[name];
															for (TIteratorD<SMDSAssociation::Update> iterator =
																			associationUpdates.getIterator();
																	iterator.hasValue(); iterator.advance()) {
																// Check update
																if (iterator->getAction() ==
																		SMDSAssociation::Update::kActionAdd)
																	// Add
																	associationItemsUpdated.add(iterator->getItem());
																else
																	// Remove
																	associationItemsUpdated.remove(iterator->getItem());
															}
														}

														return associationItemsUpdated;
													}
		TArray<SMDSAssociation::Update>			getAssociationUpdates(const CString& name) const
													{ return mAssociationUpdatesByAssociationName.contains(name) ?
															mAssociationUpdatesByAssociationName[name] :
															TNArray<SMDSAssociation::Update>(); }

		DocumentInfo&							documentAdd(const CString& documentType, const CString& documentID,
														const OV<DB>& documentBacking,
														UniversalTime creationUniversalTime,
														UniversalTime modificationUniversalTime,
														const CDictionary& initialPropertyMap)
													{
														// Setup
														DocumentInfo	documentInfo(documentType, documentBacking,
																				creationUniversalTime,
																				modificationUniversalTime,
																				initialPropertyMap);

														// Store
														mDocumentInfosByDocumentID.set(documentID, documentInfo);

														return mDocumentInfosByDocumentID[documentID];
													}
		OR<DocumentInfo>						documentInfoGet(const CString& documentID) const
													{ return mDocumentInfosByDocumentID.contains(documentID) ?
															mDocumentInfosByDocumentID[documentID] :
															OR<DocumentInfo>(); }
		TDictionary<TDictionary<DocumentInfo> >	documentGetInfosByDocumentType()
													{
														// Setup
														TDictionary<TDictionary<DocumentInfo> >	info;

														// Iterate changes
														TSet<CString>	documentIDs =
																				mDocumentInfosByDocumentID.getKeys();
														for (TIteratorS<CString> iterator = documentIDs.getIterator();
																iterator.hasValue(); iterator.advance()) {
															// Update
															DocumentInfo&	documentInfo =
																					*mDocumentInfosByDocumentID[
																							*iterator];
															if (!info.contains(documentInfo.getDocumentType()))
																// Create dictionary
																info.set(documentInfo.getDocumentType(),
																		TNDictionary<DocumentInfo>());
															info[documentInfo.getDocumentType()]->set(*iterator,
																	documentInfo);
														}

														return info;
													}

	// Properties
	private:
		TNDictionary<DocumentInfo>					mDocumentInfosByDocumentID;
		TNArrayDictionary<SMDSAssociation::Update>	mAssociationUpdatesByAssociationName;
};
