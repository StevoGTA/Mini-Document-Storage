//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDatabaseManager.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CMDSSQLiteDocumentBacking.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Types



//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDatabaseManager

class CMDSSQLiteDatabaseManager {
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


	// Classes
	private:
		class	Internals;

	// Methods
	public:
										// Lifecycle methods

										// Instance methods
				DocumentCreateInfo				documentCreate(const CString& documentType, const CString& documentID,
														const OV<UniversalTime>& creationUniversalTime,
														const OV<UniversalTime>& modificationUniversalTime,
														const CDictionary& propertyMap);
				DocumentUpdateInfo				documentUpdate(const CString& documentType, SInt64 id,
														const CDictionary& propertyMap);

				DocumentAttachmentInfo			documentAttachmentAdd(const CString& documentType, SInt64 id,
														const CDictionary& info, const CData& content);
				CData							documentAttachmentContent(const CString& documentType, SInt64 id,
														const CString& attachmentID);
				DocumentAttachmentInfo			documentAttachmentUpdate(const CString& documentType, SInt64 id,
														const CString& attachmentID, const CDictionary& updatedInfo,
														const CData& updatedContent);
				DocumentAttachmentRemoveInfo	documentAttachmentRemove(const CString& documentType, SInt64 id,
														const CString& attachmentID);


										// Class methods

	// Properties
	private:
		Internals*	mInternals;
};
