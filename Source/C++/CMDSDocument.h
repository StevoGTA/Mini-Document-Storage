//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocument.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CDictionary.h"
#include "CHashing.h"
#include "TimeAndDate.h"
#include "TWrappers.h"

class CMDSDocumentStorage;

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocument

class CMDSDocument : public CHashable {
	// ChangeKind
	public:
		enum ChangeKind {
			kChangeKindCreated,
			kChangeKindUpdated,
			kChangeKindRemoved,
		};

	// AttachmentInfo
	public:
		struct AttachmentInfo {
			// Methods
			public:
										// Lifecycle methods
										AttachmentInfo(const CString& id, UInt32 revision, const CDictionary& info) :
											mID(id), mRevision(revision), mInfo(info)
											{}
										AttachmentInfo(const AttachmentInfo& other) :
											mID(other.mID), mRevision(other.mRevision), mInfo(other.mInfo)
											{}

										// Instance methods
				const	CString&		getID() const
											{ return mID; }
						UInt32			getRevision() const
											{ return mRevision; }
				const	CDictionary&	getInfo() const
											{ return mInfo; }
				const	CString&		getType() const
											{ return mInfo.getString(CString(OSSTR("type"))); }

			// Properties
			private:
				CString		mID;
				UInt32		mRevision;
				CDictionary	mInfo;
		};

	// AttachmentInfoMap
	public:
		typedef	TDictionary<AttachmentInfo>	AttachmentInfoMap;

	// RevisionInfo
	public:
		struct RevisionInfo {
									// Lifecycle Methods
									RevisionInfo(const CString& documentID, UInt32 revision) :
										mDocumentID(documentID), mRevision(revision)
										{}
									RevisionInfo(const RevisionInfo& other) :
										mDocumentID(other.mDocumentID), mRevision(other.mRevision)
										{}

									// Instance methods
				const	CString&	getDocumentID() const
										{ return mDocumentID; }
						UInt32		getRevision() const
										{ return mRevision; }

			// Properties
			private:
				CString	mDocumentID;
				UInt32	mRevision;
		};

	// OverviewInfo
	public:
		struct OverviewInfo {
										// Lifecycle methods
										OverviewInfo(const CString& documentID, UInt32 revision,
												UniversalTime creationUniversalTime,
												UniversalTime modificationUniversalTime) :
											mDocumentID(documentID), mRevision(revision),
													mCreationUniversalTime(creationUniversalTime),
													mModificationUniversalTime(modificationUniversalTime)
											{}
										OverviewInfo(const OverviewInfo& other) :
											mDocumentID(other.mDocumentID), mRevision(other.mRevision),
													mCreationUniversalTime(other.mCreationUniversalTime),
													mModificationUniversalTime(other.mModificationUniversalTime)
											{}

										// Instance methods
				const	CString&		getDocumentID() const
											{ return mDocumentID; }
						UInt32			getRevision() const
											{ return mRevision; }
						UniversalTime	getCreationUniversalTime() const
											{ return mCreationUniversalTime; }
						UniversalTime	getModificationUniversalTime() const
											{ return mModificationUniversalTime; }

			// Properties
			private:
				CString			mDocumentID;
				UInt32			mRevision;
				UniversalTime	mCreationUniversalTime;
				UniversalTime	mModificationUniversalTime;
		};

	// FullInfo
	public:
		struct FullInfo {
											// Lifecycle methods
											FullInfo(const CString& documentID, UInt32 revision, bool active,
													UniversalTime creationUniversalTime,
													UniversalTime modificationUniversalTime,
													const CDictionary& propertyMap,
													const AttachmentInfoMap& attachmentInfoMap) :
												mDocumentID(documentID), mRevision(revision), mActive(active),
														mCreationUniversalTime(creationUniversalTime),
														mModificationUniversalTime(modificationUniversalTime),
														mPropertyMap(propertyMap),
														mAttachmentInfoMap(attachmentInfoMap)
												{}
											FullInfo(const FullInfo& other) :
												mDocumentID(other.mDocumentID), mRevision(other.mRevision),
														mActive(other.mActive),
														mCreationUniversalTime(other.mCreationUniversalTime),
														mModificationUniversalTime(other.mModificationUniversalTime),
														mPropertyMap(other.mPropertyMap),
														mAttachmentInfoMap(other.mAttachmentInfoMap)
											{}

											// Instance methods
				const	CString&			getDocumentID() const
												{ return mDocumentID; }
						UInt32				getRevision() const
												{ return mRevision; }
						bool				getActive() const
												{ return mActive; }
						UniversalTime		getCreationUniversalTime() const
												{ return mCreationUniversalTime; }
						UniversalTime		getModificationUniversalTime() const
												{ return mModificationUniversalTime; }
				const	CDictionary&		getPropertyMap() const
												{ return mPropertyMap; }
				const	AttachmentInfoMap&	getAttachmentInfoMap() const
												{ return mAttachmentInfoMap; }

			// Properties
			private:
				CString				mDocumentID;
				UInt32				mRevision;
				bool				mActive;
				UniversalTime		mCreationUniversalTime;
				UniversalTime		mModificationUniversalTime;
				CDictionary			mPropertyMap;
				AttachmentInfoMap	mAttachmentInfoMap;
		};

	// CreateInfo
	public:
		struct CreateInfo {
											// Lifecycle methods
											CreateInfo(const CString& documentID, UniversalTime creationUniversalTime,
													UniversalTime modificationUniversalTime,
													const CDictionary& propertyMap) :
												mDocumentID(documentID), mCreationUniversalTime(creationUniversalTime),
														mModificationUniversalTime(modificationUniversalTime),
														mPropertyMap(propertyMap)
												{}
											CreateInfo(const CreateInfo& other) :
												mDocumentID(other.mDocumentID),
														mCreationUniversalTime(other.mCreationUniversalTime),
														mModificationUniversalTime(other.mModificationUniversalTime),
														mPropertyMap(other.mPropertyMap)
												{}

											// Instance methods
				const	OV<CString>&		getDocumentID() const
												{ return mDocumentID; }
				const	OV<UniversalTime>&	getCreationUniversalTime() const
												{ return mCreationUniversalTime; }
				const	OV<UniversalTime>&	getModificationUniversalTime() const
												{ return mModificationUniversalTime; }
				const	CDictionary&		getPropertyMap() const
												{ return mPropertyMap; }

			// Properties
			private:
				OV<CString>			mDocumentID;
				OV<UniversalTime>	mCreationUniversalTime;
				OV<UniversalTime>	mModificationUniversalTime;
				CDictionary			mPropertyMap;
		};

	// CreateResultInfo
	public:
		struct CreateResultInfo {
											// Lifecycle methods
											CreateResultInfo(const I<CMDSDocument>& document,
													const OV<OverviewInfo>& overviewInfo) :
												mDocument(document), mOverviewInfo(overviewInfo)
												{}
											CreateResultInfo(const CreateResultInfo& other) :
												mDocument(other.mDocument), mOverviewInfo(other.mOverviewInfo)
												{}

											// Instance methods
				const	I<CMDSDocument>		getDocument() const
												{ return mDocument; }
				const	OV<OverviewInfo>	getOverviewInfo() const
												{ return mOverviewInfo; }
			// Properties
			private:
				I<CMDSDocument>		mDocument;
				OV<OverviewInfo>	mOverviewInfo;
		};

	// UpdateInfo
	public:
		struct UpdateInfo {
										// Lifecycle methods
										UpdateInfo(const CString& documentID, const CDictionary& updated,
												const TSet<CString>& removed, bool active) :
											mDocumentID(documentID), mUpdated(updated), mRemoved(removed),
													mActive(active)
											{}

										// Instance methods
				const	CString&		getDocumentID() const
											{ return mDocumentID; }
				const	CDictionary&	getUpdated() const
											{ return mUpdated; }
				const	TNSet<CString>&	getRemoved() const
											{ return mRemoved; }
						bool			getActive() const
											{ return mActive; }

			// Properties
			private:
				CString			mDocumentID;
				CDictionary		mUpdated;
				TNSet<CString>	mRemoved;
				bool			mActive;
		};

	// ChangedInfo
	public:
		struct ChangedInfo {
			// Procs
			public:
				typedef	void	(*Proc)(const CMDSDocument& document, ChangeKind changeKind, void* userData);

			// Methods
			public:
						// Lifecycle methods
						ChangedInfo(Proc proc, void* userData) : mProc(proc), mUserData(userData) {}
						ChangedInfo(const ChangedInfo& other) : mProc(other.mProc), mUserData(other.mUserData) {}

						// Instance methods
				void	notify(const CMDSDocument& document, ChangeKind changeKind) const
							{ mProc(document, changeKind, mUserData); }
			// Properties
			private:
				Proc	mProc;
				void*	mUserData;

		};

	// IsIncludedPerformer
	public:
		struct IsIncludedPerformer {
			// Procs
			public:
				typedef	bool	(*Proc)(const CString& documentType, const CMDSDocument& document,
										const CDictionary& info, void* userData);

			// Methods
			public:
									// Lifecycle methods
									IsIncludedPerformer(const CString& selector, Proc proc, void* userData) :
										mSelector(selector), mProc(proc), mUserData(userData)
										{}
									IsIncludedPerformer(const IsIncludedPerformer& other) :
										mSelector(other.mSelector), mProc(other.mProc), mUserData(other.mUserData)
										{}

									// Instance methods
				const	CString&	getSelector() const
										{ return mSelector; }
						void		perform(const CString& documentType, const CMDSDocument& document,
											const CDictionary& info) const
										{ mProc(documentType, document, info, mUserData); }

			// Properties
			private:
				CString	mSelector;
				Proc	mProc;
				void*	mUserData;
		};

	// KeysPerformer
	public:
		struct KeysPerformer {
			// Procs
			public:
				typedef	TArray<CString>	(*Proc)(const CString& documentType, const CMDSDocument& document,
												const CDictionary& info, void* userData);

			// Methods
			public:
										// Lfiecycle methods
										KeysPerformer(const CString& selector, Proc proc, void* userData) :
											mSelector(selector), mProc(proc), mUserData(userData)
											{}
										KeysPerformer(const KeysPerformer& other) :
											mSelector(other.mSelector), mProc(other.mProc), mUserData(other.mUserData)
											{}

										// Instance methods
				const	CString&		getSelector() const
											{ return mSelector; }
						TArray<CString>	perform(const CString& documentType, CMDSDocument& document,
												const CDictionary& info) const
											{ return mProc(documentType, document, info, mUserData); }


			// Properties
			private:
				CString	mSelector;
				Proc	mProc;
				void*	mUserData;
		};

	// ValueInfo
	public:
		struct ValueInfo {
			// Procs
			public:
				typedef	SValue	(*Proc)(const CString& documentType, const CMDSDocument& document,
										const CString& property, void* userData);

			// Methods
			public:
									// Lfiecycle methods
									ValueInfo(const CString& selector, Proc proc, void* userData) :
										mSelector(selector), mProc(proc), mUserData(userData)
										{}
									ValueInfo(const ValueInfo& other) :
										mSelector(other.mSelector), mProc(other.mProc), mUserData(other.mUserData)
										{}

									// Instance methods
				const	CString&	getSelector() const
											{ return mSelector; }
						SValue		perform(const CString& documentType, const CMDSDocument& document,
											const CString& property) const
										{ return mProc(documentType, document, property, mUserData); }

			// Properties
			private:
				CString	mSelector;
				Proc	mProc;
				void*	mUserData;
		};

	// Backing
	public:
		class Backing {
			// Methods
			public:
											// Lifecycle methods
				virtual						~Backing() {}

											// Instance methods
						const	CString&	getDocumentID() const
												{ return mDocumentID; }

			protected:
											// Lifecycle methods
											Backing(const CString& documentID) : mDocumentID(documentID) {}

			// Properties
			private:
				CString	mDocumentID;
		};


	// Procs
	public:
		typedef	I<CMDSDocument>	(*CreateProc)(const CString& id, CMDSDocumentStorage& documentStorage);
		typedef	void			(*KeyProc)(const CString& key, const CMDSDocument& document, void* userData);
		typedef	void			(*Proc)(CMDSDocument& document, void* userData);

	// Infos
	public:
		struct Info {
									// Lifecycle methods
									Info(const CString& documentType, CreateProc createProc) :
										mDocumentType(documentType), mCreateProc(createProc)
										{}
									Info(const Info& other) :
										mDocumentType(other.mDocumentType), mCreateProc(other.mCreateProc)
										{}

									// Instance methods
			const	CString&		getDocumentType() const
										{ return mDocumentType; }
					I<CMDSDocument>	create(const CString& id, CMDSDocumentStorage& documentStorage) const
										{ return mCreateProc(id, documentStorage); }

			// Properties
			private:
				CString		mDocumentType;
				CreateProc	mCreateProc;
		};

		class InfoForNew {
			public:
												// Lifecycle methods
				virtual							~InfoForNew() {}

												// Instance methods
				virtual	const	CString&		getDocumentType() const = 0;
				virtual			I<CMDSDocument>	create(const CString& id, CMDSDocumentStorage& documentStorage) const
														= 0;

			protected:
												// Lifecycle methods
												InfoForNew() {}
		};

	// Classes
	private:
		class Internals;

	// Methods
	public:
														// Lifecycle methods
														CMDSDocument(const CMDSDocument& other);
		virtual											~CMDSDocument();

														// CEquatable methods
						bool							operator==(const CEquatable& other) const
															{ return getID() == ((CMDSDocument&) other).getID(); }

														// CHashable methods
						void							hashInto(CHasher& hasher) const
															{ getID().hashInto(hasher); }

														// Instance methods
		virtual			I<CMDSDocument>					copy() const = 0;
		virtual	const	Info&							getInfo() const = 0;

				const	CString&						getDocumentType() const
															{ return getInfo().getDocumentType(); }
				const	CString&						getID() const;
						CMDSDocumentStorage&			getDocumentStorage() const;

						UniversalTime					getCreationUniversalTime() const;
						UniversalTime					getModificationUniversalTime() const;

						OV<TArray<CString> >			getArrayOfStrings(const CString& property) const;
						void							set(const CString& property, const TArray<CString>& value)
																const;
						OV<TArray<CDictionary> >		getArrayOfDictionaries(const CString& property) const;
						void							set(const CString& property, const TArray<CDictionary>& value)
																const;

						OV<bool>						getBool(const CString& property) const;
						OV<bool>						set(const CString& property, bool value) const;

						OV<CData>						getData(const CString& property) const;
						OV<CData>						set(const CString& property, const CData& value) const;

						OV<CDictionary>					getDictionary(const CString& property) const;
						OV<CDictionary>					set(const CString& property, const CDictionary& value) const;

						OV<Float32>						getFloat32(const CString& property) const;
						OV<Float32>						set(const CString& property, Float32 value) const;

						OV<Float64>						getFloat64(const CString& property) const;
						OV<Float64>						set(const CString& property, Float64 value) const;

						OV<SInt32>						getSInt32(const CString& property) const;
						OV<SInt32>						set(const CString& property, SInt32 value) const;

						OV<SInt64>						getSInt64(const CString& property) const;
						OV<SInt64>						set(const CString& property, SInt64 value) const;

						OV<CString>						getString(const CString& property) const;
						OV<CString>						set(const CString& property, const CString& value) const;

						OV<UInt8>						getUInt8(const CString& property) const;
						OV<UInt8>						set(const CString& property, UInt8 value) const;
						OV<UInt8>						set(const CString& property, const OV<UInt8>& value) const;

						OV<UInt16>						getUInt16(const CString& property) const;
						OV<UInt16>						set(const CString& property, UInt16 value) const;

						OV<UInt32>						getUInt32(const CString& property) const;
						OV<UInt32>						set(const CString& property, UInt32 value) const;

						OV<UInt64>						getUInt64(const CString& property) const;
						OV<UInt64>						set(const CString& property, UInt64 value) const;

						OV<UniversalTime>				getUniversalTime(const CString& property) const;
						OV<UniversalTime>				setUniversalTime(const CString& property, UniversalTime value)
																const;

//						OI<CMDSDocument>				getDocument(const CString& property,
//																const CMDSDocument::Info& info) const;
//						void							set(const CString& property, const CMDSDocument& document)
//																const;

						OV<TArray<CMDSDocument> >		getDocuments(const CString& property,
																const CMDSDocument::Info& info) const;
						void							set(const CString& property,
																const TArray<CMDSDocument>& documents) const;

//						OV<TDictionary<CMDSDocument> >	getDocumentMap(const CString& property,
//																const CMDSDocument::Info& info) const;
//						void							set(const CString& property,
//																const TDictionary<CMDSDocument> documentMap) const;

						void							remove(const CString& property) const;


						TArray<AttachmentInfo>			getAttachmentInfos(const CString& type) const;
						CData							getAttachmentContent(const AttachmentInfo& attachmentInfo)
																const;
						CString							getAttachmentContentAsString(
																const AttachmentInfo& attachmentInfo) const;
						CDictionary						getAttachmentContentAsDictionary(
																const AttachmentInfo& attachmentInfo) const;
						TArray<CDictionary>				getAttachmentContentAsArrayOfDictionaries(
																const AttachmentInfo& attachmentInfo) const;
						void							addAttachment(const CString& type, const CDictionary& info,
																const CData& content);
						void							addAttachment(const CString& type, const CData& content)
															{ addAttachment(type, CDictionary::mEmpty, content); }
						void							addAttachment(const CString& type, const CDictionary& info,
																const CString& content)
															{ addAttachment(type, info,
																	content.getData(CString::kEncodingUTF8)); }
						void							addAttachment(const CString& type, const CString& content)
															{ addAttachment(type, CDictionary::mEmpty,
																	content.getData(CString::kEncodingUTF8)); }
						void							addAttachment(const CString& type, const CDictionary& info,
																const CDictionary& content);
						void							addAttachment(const CString& type, const CDictionary& content)
															{ addAttachment(type, CDictionary::mEmpty, content); }
						void							addAttachment(const CString& type, const CDictionary& info,
																const TArray<CDictionary>& content);
						void							addAttachment(const CString& type,
																const TArray<CDictionary>& content)
															{ addAttachment(type, CDictionary::mEmpty, content); }
						void							updateAttachment(const AttachmentInfo& attachmentInfo,
																const CDictionary& updatedInfo,
																const CData& updatedContent);
						void							updateAttachment(const AttachmentInfo& attachmentInfo,
																const CData& updatedContent)
															{ updateAttachment(attachmentInfo, CDictionary::mEmpty,
																	updatedContent); }
						void							updateAttachment(const AttachmentInfo& attachmentInfo,
																const CDictionary& updatedInfo,
																const CString& updatedContent);
						void							updateAttachment(const AttachmentInfo& attachmentInfo,
																const CString& updatedContent)
															{ updateAttachment(attachmentInfo, CDictionary::mEmpty,
																	updatedContent); }
						void							updateAttachment(const AttachmentInfo& attachmentInfo,
																const CDictionary& updatedInfo,
																const CDictionary& updatedContent);
						void							updateAttachment(const AttachmentInfo& attachmentInfo,
																const CDictionary& updatedContent)
															{ updateAttachment(attachmentInfo, CDictionary::mEmpty,
																	updatedContent); }
						void							updateAttachment(const AttachmentInfo& attachmentInfo,
																const CDictionary& updatedInfo,
																const TArray<CDictionary>& updatedContent);
						void							updateAttachment(const AttachmentInfo& attachmentInfo,
																const TArray<CDictionary>& updatedContent)
															{ updateAttachment(attachmentInfo, CDictionary::mEmpty,
																	updatedContent); }
						void							remove(const AttachmentInfo& attachmentInfo);

						void							remove() const;

	protected:
														// Lifecycle methods
														CMDSDocument(const CString& id,
																CMDSDocumentStorage& documentStorage);

	// Properties
	private:
		Internals*	mInternals;
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: - TMDSUpdateInfo

template <typename T> struct TMDSUpdateInfo {
									// Lifecycle methods
									TMDSUpdateInfo(const I<CMDSDocument*>& document, UInt32 revision, T id,
											const TSet<CString> changedProperties) :
										mDocument(document), mRevision(revision), mID(id),
												mChangedProperties(OV<TSet<CString> >(changedProperties))
										{}
									TMDSUpdateInfo(const I<CMDSDocument*>& document, UInt32 revision, T id) :
										mDocument(document), mRevision(revision), mID(id),
												mChangedProperties(OV<TSet<CString> >())
										{}

									// Instance methods
		const	I<CMDSDocument*>&	getDocument() const
										{ return mDocument; }
				UInt32				getRevision() const
										{ return mRevision; }
		const	T&					getID() const
										{ return mID; }
		const	OV<TSet<CString> >&	getChangedProperties() const
										{ return mChangedProperties; }

	// Properties
	private:
		I<CMDSDocument*>	mDocument;
		UInt32				mRevision;
		T					mID;
		OV<TSet<CString> >	mChangedProperties;
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: - EMDSValueType
enum EMDSValueType {
	kMDSValueTypeInteger,
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: - SMDSValueInfo
struct SMDSValueInfo {
								// Lifecycle methods
								SMDSValueInfo(const CString& name, EMDSValueType valueType) :
									mName(name), mValueType(valueType)
									{}

								// Instance methods
		const	CString&		getName() const
									{ return mName; }
				EMDSValueType	getValueType() const
									{ return mValueType; }

	// Properties
	private:
		CString			mName;
		EMDSValueType	mValueType;
};
