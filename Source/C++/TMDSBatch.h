//----------------------------------------------------------------------------------------------------------------------
//	TMDSBatch.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSAssociation.h"
#include "CUUID.h"

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
			typedef	CMDSDocument::AttachmentInfo		AttachmentInfo;
			typedef	CMDSDocument::AttachmentInfoByID	AttachmentInfoByID;

														// Lifecycle methods
														DocumentInfo(const CString& documentType,
																const R<DB>& documentBacking) :
															mDocumentType(documentType),
																	mDocumentBacking(*documentBacking),
																	mCreationUniversalTime(
																			(*documentBacking)->
																					getCreationUniversalTime()),
																	mModificationUniversalTime(
																			SUniversalTime::getCurrent()),
																	mRemoved(false),
																	mInitialPropertyMap(
																			(*documentBacking)->getPropertyMap())
															{}
														DocumentInfo(const CString& documentType,
																UniversalTime creationUniversalTime,
																UniversalTime modificationUniversalTime,
																const OV<CDictionary>& initialPropertyMap) :
															mDocumentType(documentType),
																	mCreationUniversalTime(creationUniversalTime),
																	mModificationUniversalTime(
																			modificationUniversalTime),
																	mRemoved(false),
																	mInitialPropertyMap(initialPropertyMap)
															{}

														// Instance methods
			const	CString&							getDocumentType() const
															{ return mDocumentType; }
			const	OR<DB>&								getDocumentBacking() const
															{ return mDocumentBacking; }

					UniversalTime						getCreationUniversalTime() const
															{ return mCreationUniversalTime; }
					UniversalTime						getModificationUniversalTime() const
															{ return mModificationUniversalTime; }
			const	CDictionary&						getUpdatedPropertyMap() const
															{ return mUpdatedPropertyMap; }
			const	TSet<CString>&						getRemovedProperties() const
															{ return mRemovedProperties; }

					bool								isRemoved() const
															{ return mRemoved; }

					OV<SValue>							getValue(const CString& property)
															{
																// Check for document removed
																if (mRemoved || mRemovedProperties.contains(property))
																	// Removed
																	return OV<SValue>();
																else if (mUpdatedPropertyMap.contains(property))
																	// Have updated property
																	return OV<SValue>(
																			mUpdatedPropertyMap.getValue(property));
																else if (mInitialPropertyMap.hasValue())
																	// Try initial property map
																	return OV<SValue>(
																			mInitialPropertyMap->getValue(property));
																else
																	// Sorry
																	return OV<SValue>();
															}
					void								set(const CString& property, const OV<SValue>& value)
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
																mModificationUniversalTime =
																		SUniversalTime::getCurrent();
															}

					AttachmentInfoByID					getUpdatedDocumentAttachmentInfoByID(
																const CMDSDocument::AttachmentInfoByID&
																		initialDocumentAttachmentInfoByID)
																const
															{
																// Start with initial
																TNDictionary<CMDSDocument::AttachmentInfo>
																		updatedDocumentAttachmentInfoByID(
																				initialDocumentAttachmentInfoByID);

																// Process adds
																TSet<CString>	keys =
																						mAddAttachmentInfosByID
																								.getKeys();
																for (TIteratorS<CString> iterator = keys.getIterator();
																		iterator.hasValue(); iterator.advance())
																	// Process add
																	updatedDocumentAttachmentInfoByID.set(*iterator,
																			mAddAttachmentInfosByID[*iterator]->
																					getDocumentAttachmentInfo());

																// Process updates
																keys = mUpdateAttachmentInfosByID.getKeys();
																for (TIteratorS<CString> iterator = keys.getIterator();
																		iterator.hasValue(); iterator.advance())
																	// Process update
																	updatedDocumentAttachmentInfoByID.set(*iterator,
																			mUpdateAttachmentInfosByID[*iterator]->
																					getDocumentAttachmentInfo());

																// Process removes
																updatedDocumentAttachmentInfoByID.remove(
																		mRemovedAttachmentIDs);

																return updatedDocumentAttachmentInfoByID;
															}
					OV<CData>							getAttachmentContent(const CString& id) const
															{
																// Check adds
																if (mAddAttachmentInfosByID.contains(id))
																	// Have add
																	return OV<CData>(
																			mAddAttachmentInfosByID[id]->getContent());
																else if (mUpdateAttachmentInfosByID.contains(id))
																	// Have update
																	return OV<CData>(
																			mUpdateAttachmentInfosByID[id]->
																					getContent());
																else
																	// Nope
																	return OV<CData>();
															}
					AttachmentInfo						attachmentAdd(const CDictionary& info, const CData& content)
															{
																// Setup
																AddAttachmentInfo	addAttachmentInfo(info, content);

																// Add info
																mAddAttachmentInfosByID.set(addAttachmentInfo.getID(),
																		addAttachmentInfo);

																// Modified
																mModificationUniversalTime =
																		SUniversalTime::getCurrent();

																return addAttachmentInfo.getDocumentAttachmentInfo();
															}
			const	TDictionary<AddAttachmentInfo>&		getAddAttachmentInfosByID() const
															{ return mAddAttachmentInfosByID; }
					void								attachmentUpdate(const CString& id, UInt32 currentRevision,
																const CDictionary& info, const CData& content)
															{
																// Add info
																mUpdateAttachmentInfosByID.set(id,
																		UpdateAttachmentInfo(id, currentRevision, info,
																				content));

																// Modified
																mModificationUniversalTime =
																		SUniversalTime::getCurrent();
															}
			const	TDictionary<UpdateAttachmentInfo>&	getUpdateAttachmentInfosByID() const
															{ return mUpdateAttachmentInfosByID; }
					void								attachmentRemove(const CString& id)
															{
																// Add it
																mRemovedAttachmentIDs.insert(id);

																// Modified
																mModificationUniversalTime =
																		SUniversalTime::getCurrent();
															}
			const	TNSet<CString>&						getRemovedAttachmentIDs() const
															{ return mRemovedAttachmentIDs; }

					void								remove()
															{
																// Removed
																mRemoved = true;

																// Modified
																mModificationUniversalTime =
																		SUniversalTime::getCurrent();
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

		typedef	TNDictionary<DocumentInfo>				DocumentInfoByDocumentID;
		typedef	TDictionary<DocumentInfoByDocumentID>	DocumentInfoByDocumentIDByDocumentType;

	// Methods
	public:
												// Lifecycle methods
												TMDSBatch() {}

												// Instance methods
		void									associationNoteUpdated(const CString& name,
														const TArray<CMDSAssociation::Update>& updates)
													{ mAssociationUpdatesByAssociationName.add(name, updates); }
		TSet<CString>							associationGetUpdatedNames() const
													{ return mAssociationUpdatesByAssociationName.getKeys(); }
		TArray<CMDSAssociation::Update>			associationGetUpdates(const CString& name) const
													{ return *mAssociationUpdatesByAssociationName[name]; }
		TArray<CMDSAssociation::Item>			associationItemsApplyingChanges(const CString& name,
														const TArray<CMDSAssociation::Item>& initialAssociationItems)
														const
													{
														// Start with initial
														TNArray<CMDSAssociation::Item>	associationItemsUpdated(
																								initialAssociationItems);

														// Check if have updates
														if (mAssociationUpdatesByAssociationName.contains(name)) {
															// Get updates
															TArray<CMDSAssociation::Update>	associationUpdates =
																									*mAssociationUpdatesByAssociationName[
																											name];
															for (TIteratorD<CMDSAssociation::Update> iterator =
																			associationUpdates.getIterator();
																	iterator.hasValue(); iterator.advance()) {
																// Check update
																if (iterator->getAction() ==
																		CMDSAssociation::Update::kActionAdd)
																	// Add
																	associationItemsUpdated.add(iterator->getItem());
																else
																	// Remove
																	associationItemsUpdated.remove(iterator->getItem());
															}
														}

														return associationItemsUpdated;
													}

		DocumentInfo&							documentAdd(const CString& documentType, const CString& documentID,
														const OR<DB>& documentBacking,
														UniversalTime creationUniversalTime,
														UniversalTime modificationUniversalTime,
														const OV<CDictionary>& initialPropertyMap)
													{
														// Setup
														DocumentInfo	documentInfo(documentType, documentBacking,
																				creationUniversalTime,
																				modificationUniversalTime,
																				initialPropertyMap);

														// Store
														mDocumentInfoByDocumentID.set(documentID, documentInfo);

														return *mDocumentInfoByDocumentID[documentID];
													}
		DocumentInfo&							documentAdd(const CString& documentType, const R<DB>& documentBacking)
													{
														// Setup
														DocumentInfo	documentInfo(documentType, documentBacking);

														// Store
														mDocumentInfoByDocumentID.set(
																(*documentBacking)->getDocumentID(), documentInfo);

														return *mDocumentInfoByDocumentID[
																(*documentBacking)->getDocumentID()];
													}
		DocumentInfo&							documentAdd(const CString& documentType, const CString& documentID,
														UniversalTime creationUniversalTime,
														UniversalTime modificationUniversalTime,
														const OV<CDictionary>& initialPropertyMap)
													{
														// Setup
														DocumentInfo	documentInfo(documentType,
																				creationUniversalTime,
																				modificationUniversalTime,
																				initialPropertyMap);

														// Store
														mDocumentInfoByDocumentID.set(documentID, documentInfo);

														return *mDocumentInfoByDocumentID[documentID];
													}
		DocumentInfoByDocumentIDByDocumentType	documentGetInfosByDocumentType() const
													{
														// Setup
														TNDictionary<DocumentInfoByDocumentID >	info;

														// Iterate changes
														TSet<CString>	keys = mDocumentInfoByDocumentID.getKeys();
														for (TIteratorS<CString> iterator = keys.getIterator();
																iterator.hasValue(); iterator.advance()) {
															// Update
															DocumentInfo&	documentInfo =
																					*mDocumentInfoByDocumentID[
																							*iterator];
															if (!info.contains(documentInfo.getDocumentType()))
																// Create dictionary
																info.set(documentInfo.getDocumentType(),
																		DocumentInfoByDocumentID());
															info[documentInfo.getDocumentType()]->set(*iterator,
																	documentInfo);
														}

														return info;
													}
		TArray<CString>							documentIDsGet(const CString& documentType) const
													{
														// Setup
														TNArray<CString>	documentIDs;

														// Iterate changes
														TSet<CString>	keys = mDocumentInfoByDocumentID.getKeys();
														for (TIteratorS<CString> iterator = keys.getIterator();
																iterator.hasValue(); iterator.advance()) {
															// Update
															DocumentInfo&	documentInfo =
																					*mDocumentInfoByDocumentID[
																							*iterator];
															if (documentInfo.getDocumentType() == documentType)
																// Add document ID
																documentIDs += *iterator;
														}

														return documentIDs;
													}
		OR<DocumentInfo>						documentInfoGet(const CString& documentID) const
													{ return mDocumentInfoByDocumentID.contains(documentID) ?
															mDocumentInfoByDocumentID[documentID] :
															OR<DocumentInfo>(); }

	// Properties
	private:
		DocumentInfoByDocumentID					mDocumentInfoByDocumentID;
		TNArrayDictionary<CMDSAssociation::Update>	mAssociationUpdatesByAssociationName;
};
