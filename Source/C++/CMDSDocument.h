//----------------------------------------------------------------------------------------------------------------------
//	CMDSDocument.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "CDictionary.h"
#include "CHashing.h"
#include "TimeAndDate.h"
#include "TWrappers.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: CMDSDocument

class CMDSDocumentStorage;

class CMDSDocumentInternals;
class CMDSDocument : public CHashable {
	// ChangeKind
	public:
		enum ChangeKind {
			kCreated,
			kUpdated,
			kRemoved,
		};

	// BackingInfo
	public:
		template <typename T> struct BackingInfo {
			// Lifecycle Methods
			BackingInfo(const CString& documentID, const T& documentBacking) :
				mDocumentID(documentID), mDocumentBacking(documentBacking)
				{}

			// Properties
			CString	mDocumentID;
			T		mDocumentBacking;
		};

	// RevisionInfo
	public:
		struct RevisionInfo {
			// Lifecycle Methods
			RevisionInfo(const CString& documentID, UInt32 revision) : mDocumentID(documentID), mRevision(revision) {}
			RevisionInfo(const RevisionInfo& other) : mDocumentID(other.mDocumentID), mRevision(other.mRevision) {}

			// Properties
			CString	mDocumentID;
			UInt32	mRevision;
		};

	// FullInfo
	public:
		struct FullInfo {
			// Lifecycle methods
			FullInfo(const CString& documentID, UInt32 revision, bool active, UniversalTime creationUniversalTime,
					UniversalTime modificationUniversalTime, const CDictionary& propertyMap) :
				mDocumentID(documentID), mRevision(revision), mActive(active),
						mCreationUniversalTime(creationUniversalTime),
						mModificationUniversalTime(modificationUniversalTime), mPropertyMap(propertyMap)
				{}

			// Properties
			CString			mDocumentID;
			UInt32			mRevision;
			bool			mActive;
			UniversalTime	mCreationUniversalTime;
			UniversalTime	mModificationUniversalTime;
			CDictionary		mPropertyMap;
		};

	// CreateInfo
	public:
		struct CreateInfo {
			// Lifecycle methods
			CreateInfo(const CString& documentID, UniversalTime creationUniversalTime,
					UniversalTime modificationUniversalTime, const CDictionary& propertyMap) :
				mDocumentID(documentID), mCreationUniversalTime(creationUniversalTime),
						mModificationUniversalTime(modificationUniversalTime), mPropertyMap(propertyMap)
				{}
			CreateInfo(const CString& documentID, const CDictionary& propertyMap) :
				mDocumentID(documentID), mPropertyMap(propertyMap)
				{}

			// Properties
			CString				mDocumentID;
			OV<UniversalTime>	mCreationUniversalTime;
			OV<UniversalTime>	mModificationUniversalTime;
			CDictionary			mPropertyMap;
		};

	// UpdateInfo
	public:
		struct UpdateInfo {
			// Lifecycle methods
			UpdateInfo(const CString& documentID, bool active, const CDictionary& updated,
					const TSet<CString>& removed) :
				mDocumentID(documentID), mActive(active), mUpdated(updated), mRemoved(removed)
				{}

			// Properties
			CString			mDocumentID;
			bool			mActive;
			CDictionary		mUpdated;
			TNSet<CString>	mRemoved;
		};

	// Procs
	public:
		typedef	CMDSDocument*	(*CreateProc)(const CString& id, CMDSDocumentStorage& documentStorage);
		typedef	void			(*Proc)(CMDSDocument& document, void* userData);
		typedef	void			(*ChangedProc)(const CMDSDocument& document, ChangeKind changeKind, void* userData);
		typedef	bool			(*IsIncludedProc)(const CMDSDocument& document, void* userData,
										const CDictionary& info);
		typedef	TArray<CString>	(*KeysProc)(const CMDSDocument& document, void* userData);
		typedef	void			(*KeyProc)(const CString& key, const CMDSDocument& document, void* userData);

	// ChangedProcInfo
	public:
		struct ChangedProcInfo {
					// Lifecycle methods
					ChangedProcInfo(ChangedProc changedProc, void* userData) :
						mChangedProc(changedProc), mUserData(userData)
						{}
					ChangedProcInfo(const ChangedProcInfo& other) :
						mChangedProc(other.mChangedProc), mUserData(other.mUserData)
						{}

					// Instance methods
			void	notify(const CMDSDocument& document, ChangeKind changeKind)
						{ mChangedProc(document, changeKind, mUserData); }

			// Properties
			private:
				ChangedProc	mChangedProc;
				void*		mUserData;
		};

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
					CMDSDocument*	create(const CString& id, CMDSDocumentStorage& documentStorage) const
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
				virtual			CMDSDocument*	create(const CString& id, CMDSDocumentStorage& documentStorage) const
														= 0;

			protected:
												// Lifecycle methods
												InfoForNew() {}
		};

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
		virtual			CMDSDocument*					copy() const = 0;
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

						void							registerAssociation(const Info& associatedDocumentInfo);
						void							associate(const CMDSDocument& document);
						void							unassociate(const CMDSDocument& document);

						void							remove(const CString& property) const;

						void							remove() const;

	protected:
														// Lifecycle methods
														CMDSDocument(const CString& id,
																CMDSDocumentStorage& documentStorage);

	// Properties
	private:
		CMDSDocumentInternals*	mInternals;
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: - TMDSUpdateInfo

template <typename T> struct TMDSUpdateInfo {
	// Lifecycle methods
	TMDSUpdateInfo(const CMDSDocument& document, UInt32 revision, T id,
			const TSet<CString> changedProperties) :
		mDocument(document), mRevision(revision), mID(id),
				mChangedProperties(OV<TSet<CString> >(changedProperties))
		{}
	TMDSUpdateInfo(const CMDSDocument& document, UInt32 revision, T id) :
		mDocument(document), mRevision(revision), mID(id), mChangedProperties(OV<TSet<CString> >())
		{}

	// Properties
	const	CMDSDocument&		mDocument;
			UInt32				mRevision;
			T					mID;
			OV<TSet<CString> >	mChangedProperties;
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: - TMDSBringUpToDateInfo

template <typename T> struct TMDSBringUpToDateInfo {
	// Lifecycle methods
	TMDSBringUpToDateInfo(const CMDSDocument& document, UInt32 revision, T value) :
		mDocument(document), mRevision(revision), mValue(value)
		{}

	// Properties
	const	CMDSDocument&	mDocument;
			UInt32			mRevision;
			T				mValue;
};
