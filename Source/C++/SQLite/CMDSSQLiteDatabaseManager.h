//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDatabaseManager.h			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#pragma once

#include "TMDSBatchInfo.h"
#include "TMDSCollection.h"
#include "TMDSIndex.h"
#include "CMDSSQLiteDocumentBacking.h"
#include "CSQLiteDatabase.h"

//----------------------------------------------------------------------------------------------------------------------
// MARK: Types

typedef	TMDSCollection<SInt64, TNumberArray<SInt64> >	CMDSSQLiteCollection;

typedef	TMDSIndex<SInt64>								CMDSSQLiteIndex;
typedef	CMDSSQLiteIndex::KeysInfo<SInt64>				CMDSSQLiteIndexKeysInfo;
typedef	TMArray<CMDSSQLiteIndexKeysInfo>				CMDSSQLiteIndexKeysInfos;
typedef	CMDSSQLiteIndex::UpdateInfo<SInt64>				CMDSSQLiteIndexUpdateInfo;

//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDatabaseManager

class CMDSSQLiteDatabaseManagerInternals;
class CMDSSQLiteDatabaseManager {
	// NewDocumentInfo
	public:
		struct NewDocumentInfo {
			// Lifecycle methods
			NewDocumentInfo(SInt64 id, UInt32 revision, UniversalTime creationUniversalTime,
					UniversalTime modificationUniversalTime) :
				mID(id), mRevision(revision), mCreationUniversalTime(creationUniversalTime),
						mModificationUniversalTime(modificationUniversalTime)
				{}

			// Properties
			SInt64			mID;
			UInt32			mRevision;
			UniversalTime	mCreationUniversalTime;
			UniversalTime	mModificationUniversalTime;
		};

	// ExistingDocumentInfo
	public:
		struct ExistingDocumentInfo {
			// Lifecycle methods
			ExistingDocumentInfo(SInt64 id, const CMDSDocument::RevisionInfo& documentRevisionInfo, bool active) :
				mID(id), mDocumentRevisionInfo(documentRevisionInfo), mActive(active)
				{}

			// Properties
			SInt64						mID;
			CMDSDocument::RevisionInfo	mDocumentRevisionInfo;
			bool						mActive;
		};

	// UpdateInfo
	public:
		struct UpdateInfo {
			// Lifecycle methods
			UpdateInfo(UInt32 revision, UniversalTime modificationUniversalTime) :
				mRevision(revision), mModificationUniversalTime(modificationUniversalTime)
				{}

			// Properties
			UInt32			mRevision;
			UniversalTime	mModificationUniversalTime;
		};

	// Types
	public:
		typedef	CMDSDocument::BackingInfo<CMDSSQLiteDocumentBacking>	DocumentBackingInfo;

	// Procs
	public:
		typedef	void	(*BatchProc)(void* userData);
		typedef	void	(*ExistingDocumentInfoProc)(const ExistingDocumentInfo& existingDocumentInfo,
								const CSQLiteResultsRow& resultsRow, void* userData);

	// Methods
	public:
										// Lifecycle methods
										CMDSSQLiteDatabaseManager(CSQLiteDatabase& database);
										~CMDSSQLiteDatabaseManager();

										// Instance methods
				OV<UInt32>				getUInt32(const CString& key) const;
				OI<CString>				getString(const CString& key) const;
				void					set(const CString& key, const OI<SValue>& value);

				void					note(const CString& documentType);
				void					batch(BatchProc batchProc, void* userData);

				NewDocumentInfo			newDocument(const CString& documentType, const CString& documentID,
												OV<UniversalTime> creationUniversalTime,
												OV<UniversalTime> modificationUniversalTime,
												const CDictionary& propertyMap);
				void					iterate(const CString& documentType, const CSQLiteInnerJoin& innerJoin,
												const CSQLiteWhere& where,
												ExistingDocumentInfoProc existingDocumentInfoProc, void* userData);
				void					iterate(const CString& documentType, const CSQLiteInnerJoin& innerJoin,
												ExistingDocumentInfoProc existingDocumentInfoProc, void* userData);
				UpdateInfo				updateDocument(const CString& documentType, SInt64 id,
												const CDictionary& propertyMap);
				void					removeDocument(const CString& documentType, SInt64 id);

				UInt32					registerCollection(const CString& documentType, const CString& name,
												UInt32 version, bool isUpToDate);
				UInt32					getCollectionDocumentCount(const CString& name);
				void					updateCollection(const CString& name, const TNumberArray<SInt64>& includedIDs,
												const TNumberArray<SInt64>& notIncludedIDs, UInt32 lastRevision);

				UInt32					registerIndex(const CString& documentType, const CString& name, UInt32 version,
												bool isUpToDate);
				void					updateIndex(const CString& name, const CMDSSQLiteIndexKeysInfos& keysInfos,
												const TNumberArray<SInt64>& removedIDs, UInt32 lastRevision);

				CSQLiteInnerJoin		getInnerJoin(const CString& documentType);
				CSQLiteInnerJoin		getInnerJoinForCollection(const CString& documentType,
												const CString& collectionName);
				CSQLiteInnerJoin		getInnerJoinForIndex(const CString& documentType, const CString& indexName);

				CSQLiteWhere			getWhere(bool active);
				CSQLiteWhere			getWhereForDocumentIDs(const TArray<CString>& documentIDs);
				CSQLiteWhere			getWhere(UInt32 revision, const CString& comparison = CString(OSSTR(">")),
												bool includeInactive = false);
				CSQLiteWhere			getWhereForIndexKeys(const TArray<CString>& keys);

										// Class methods
		static	DocumentBackingInfo		getDocumentBackingInfo(const ExistingDocumentInfo& existingDocumentInfo,
												const CSQLiteResultsRow& resultsRow);
		static	CString					getIndexContentsKey(const CSQLiteResultsRow& resultsRow);

	// Properties
	private:
		CMDSSQLiteDatabaseManagerInternals*	mInternals;
};
