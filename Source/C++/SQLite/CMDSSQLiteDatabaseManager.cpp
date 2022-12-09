//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDatabaseManager.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSSQLiteDatabaseManager.h"

#include "CJSON.h"
#include "CThread.h"
#include "TLockingDictionary.h"

/*
	See https://docs.google.com/document/d/1zgMAzYLemHA05F_FR4QZP_dn51cYcVfKMcUfai60FXE/edit for overview

	Summary:
		Info table
			Columns: key, value
		Documents table
			Columns: type, lastRevision
		Collections table
			Columns: name, version, lastRevision
		Indexes table
			Columns: name, version, lastRevision

		{DOCUMENTTYPE}s
			Columns: id, documentID, revision
		{DOCUMENTTYPE}Contents
			Columns: id, creationDate, modificationDate, json

		Collection-{COLLECTIONNAME}
			Columns: id

		Index-{INDEXNAME}
			Columns: key, id
*/

//----------------------------------------------------------------------------------------------------------------------
// MARK: Local types

typedef	CMDSSQLiteCollection::UpdateInfo<TNumberArray<SInt64> >	CMDSSQLiteCollectionUpdateInfo;

typedef	CMDSSQLiteCollectionUpdateInfo							SCollectionUpdateInfo;

typedef	CMDSSQLiteDatabaseManager::DocumentBackingInfo			DocumentBackingInfo;
typedef	CMDSSQLiteDatabaseManager::ExistingDocumentInfo			ExistingDocumentInfo;
typedef	CMDSSQLiteDatabaseManager::ExistingDocumentInfoProc		ExistingDocumentInfoProc;

typedef	CSQLiteTable::TableColumnAndValue						TableColumnAndValue;

typedef	CSQLiteTableColumn::Reference							Reference;

typedef	TMArray<SSQLiteValue>									SSQLiteValuesArray;

struct SIndexUpdateInfo {
	// Lifecycle methods
	SIndexUpdateInfo(const CMDSSQLiteIndexKeysInfos& keysInfos, const TNumberArray<SInt64>& removedIDs,
			UInt32 lastRevision) :
		mKeysInfos(keysInfos), mRemovedIDs(removedIDs), mLastRevision(lastRevision)
		{}
	SIndexUpdateInfo(const SIndexUpdateInfo& other) :
		mKeysInfos(other.mKeysInfos), mRemovedIDs(other.mRemovedIDs), mLastRevision(other.mLastRevision)
		{}

	// Properties
	CMDSSQLiteIndexKeysInfos	mKeysInfos;
	TNumberArray<SInt64>		mRemovedIDs;
	UInt32						mLastRevision;
};

struct SBatchInfo {
	// Lifecycle methods
	SBatchInfo() {}
	SBatchInfo(const SBatchInfo& other) :
		mDocumentLastRevisionTypesNeedingWrite(other.mDocumentLastRevisionTypesNeedingWrite),
				mCollectionInfo(other.mCollectionInfo), mIndexInfo(other.mIndexInfo)
		{}

	// Properties
	TNSet<CString>						mDocumentLastRevisionTypesNeedingWrite;
	TNDictionary<SCollectionUpdateInfo>	mCollectionInfo;
	TNDictionary<SIndexUpdateInfo>		mIndexInfo;
};

//----------------------------------------------------------------------------------------------------------------------
// MARK: - CInfoTable

class CInfoTable {
	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database)
									{ return database.getTable(CString(OSSTR("Info")), CSQLiteTable::kWithoutRowID,
											TSArray<CSQLiteTableColumn>(mTableColumns, 2)); }
		static	OV<UInt32>		getUInt32(const CString& key, CSQLiteTable& table)
									{
										// Retrieve value
										CSQLiteTableColumn	tableColumns[] = { mValueTableColumn };
										OV<CString>			string;
										table.select(tableColumns, 1, CSQLiteWhere(mKeyTableColumn, key),
												(CSQLiteResultsRow::Proc) getInfoString, &string);

										return string.hasInstance() ? OV<UInt32>(string->getUInt32()) : OV<UInt32>();
									}
		static	OV<CString>		getString(const CString& key, CSQLiteTable& table)
									{
										// Retrieve value
										CSQLiteTableColumn	tableColumns[] = { mValueTableColumn };
										OV<CString>			string;
										table.select(tableColumns, 1, CSQLiteWhere(mKeyTableColumn, key),
												(CSQLiteResultsRow::Proc) getInfoString, &string);

										return string;
									}
		static	void			set(const CString& key, const OV<SValue>& value, CSQLiteTable& table)
									{
										// Check if storing or removing
										if (value.hasInstance()) {
											// Storing
											TableColumnAndValue	tableColumnsAndValues[] =
																		{
																			TableColumnAndValue(mKeyTableColumn, key),
																			TableColumnAndValue(mValueTableColumn,
																					value->getString()),
																		};
											table.insertOrReplaceRow(tableColumnsAndValues, 2);
										} else
											// Removing
											table.deleteRows(mKeyTableColumn, SSQLiteValue(value->getString()));
									}

	private:
		static	void			getInfoString(const CSQLiteResultsRow& resultsRow, OV<CString>* string)
									{ *string = resultsRow.getString(mValueTableColumn); }

	// Properties
	private:
		static	CSQLiteTableColumn	mKeyTableColumn;
		static	CSQLiteTableColumn	mValueTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CInfoTable::mKeyTableColumn(CString(OSSTR("key")), CSQLiteTableColumn::kText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kPrimaryKey | CSQLiteTableColumn::kUnique |
											CSQLiteTableColumn::kNotNull));
CSQLiteTableColumn	CInfoTable::mValueTableColumn(CString(OSSTR("value")), CSQLiteTableColumn::kText,
							CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CInfoTable::mTableColumns[] = { mKeyTableColumn, mValueTableColumn };

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CDocumentsTable

class CDocumentsTable {
	// Procs
	public:
		typedef	void	(*Proc)(const CString& documentType, UInt32 lastRevision, void* userData);

	// Types
	struct ProcInfo {
				// Lifecycle methods
				ProcInfo(Proc proc, void* userData) : mProc(proc), mUserData(userData) {}

				// Instance methods
		void	perform(const CString& documentType, UInt32 lastRevision)
					{ mProc(documentType, lastRevision, mUserData); }

		// Properties
		Proc	mProc;
		void*	mUserData;
	};

	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const OV<UInt32>& version)
									{ return database.getTable(CString(OSSTR("Documents")), CSQLiteTable::kNone,
											TSArray<CSQLiteTableColumn>(mTableColumns, 2)); }
		static	void			iterate(const CSQLiteTable& table, Proc proc, void* userData)
									{
										// Iterate
										ProcInfo	procInfo(proc, userData);
										table.select((CSQLiteResultsRow::Proc) processResultsRow, &procInfo);
									}
		static	void			set(UInt32 nextRevision, const CString& documentType, CSQLiteTable& table)
									{
										// Insert or replace row
										TableColumnAndValue	tableColumnAndValues[] =
																	{
																		TableColumnAndValue(mTypeTableColumn,
																				documentType),
																		TableColumnAndValue(mLastRevisionTableColumn,
																				nextRevision),
																	};
										table.insertOrReplaceRow(tableColumnAndValues, 2);
									}

	private:
		static	void			processResultsRow(const CSQLiteResultsRow& resultsRow, ProcInfo* procInfo)
									{
										// Process results
										CString	documentType = *resultsRow.getString(mTypeTableColumn);
										UInt32	lastRevision = *resultsRow.getUInt32(mLastRevisionTableColumn);

										// Call proc
										procInfo->perform(documentType, lastRevision);
									}

	// Properties
	private:
		static	CSQLiteTableColumn	mTypeTableColumn;
		static	CSQLiteTableColumn	mLastRevisionTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CDocumentsTable::mTypeTableColumn(CString(OSSTR("type")), CSQLiteTableColumn::kText,
							(CSQLiteTableColumn::Options) (CSQLiteTableColumn::kNotNull | CSQLiteTableColumn::kUnique));
CSQLiteTableColumn	CDocumentsTable::mLastRevisionTableColumn(CString(OSSTR("lastRevision")),
							CSQLiteTableColumn::kInteger, CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CDocumentsTable::mTableColumns[] = { mTypeTableColumn, mLastRevisionTableColumn };

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CDocumentTypeInfoTable

class CDocumentTypeInfoTable {
	// Types
	struct ProcInfo {
				// Lifecycle methods
				ProcInfo(ExistingDocumentInfoProc existingDocumentInfoProc, void* userData) :
					mExistingDocumentInfoProc(existingDocumentInfoProc), mUserData(userData)
					{}

				// Instance methods
		void	perform(const ExistingDocumentInfo& existingDocumentInfo, const CSQLiteResultsRow& resultsRow)
					{ mExistingDocumentInfoProc(existingDocumentInfo, resultsRow, mUserData); }

		// Properties
		ExistingDocumentInfoProc	mExistingDocumentInfoProc;
		void*						mUserData;
	};

	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const CString& nameRoot, UInt32 version)
									{ return database.getTable(nameRoot + CString(OSSTR("s")), CSQLiteTable::kNone,
											TSArray<CSQLiteTableColumn>(mTableColumns, 4)); }
		static	void			iterate(const CSQLiteTable& table, const CSQLiteInnerJoin& innerJoin,
										const CSQLiteWhere& where, ExistingDocumentInfoProc existingDocumentInfoProc,
										void* userData)
									{
										// Iterate
										ProcInfo	procInfo(existingDocumentInfoProc, userData);
										table.select(innerJoin, where, (CSQLiteResultsRow::Proc) processResultsRow,
												&procInfo);
									}
		static	void			iterate(const CSQLiteTable& table, const CSQLiteInnerJoin& innerJoin,
										ExistingDocumentInfoProc existingDocumentInfoProc, void* userData)
									{
										// Iterate
										ProcInfo	procInfo(existingDocumentInfoProc, userData);
										table.select(innerJoin, (CSQLiteResultsRow::Proc) processResultsRow, &procInfo);
									}
		static	SInt64			add(const CString& documentID, UInt32 revision, CSQLiteTable& table)
									{
										TableColumnAndValue	infoTableColumnAndValues[] =
																	{
																		TableColumnAndValue(mDocumentIDTableColumn,
																				documentID),
																		TableColumnAndValue(mRevisionTableColumn,
																				revision),
																		TableColumnAndValue(mActiveTableColumn,
																				(UInt32) 1),
																	};

										return table.insertRow(infoTableColumnAndValues, 3);
									}
		static	void			update(SInt64 id, UInt32 revision, CSQLiteTable& table)
									{ table.update(TableColumnAndValue(mRevisionTableColumn, revision),
												CSQLiteWhere(mIDTableColumn, SSQLiteValue(id))); }
		static	void			remove(SInt64 id, CSQLiteTable& table)
									{ table.update(TableColumnAndValue(mActiveTableColumn, (UInt32) 0),
												CSQLiteWhere(mIDTableColumn, SSQLiteValue(id))); }

	private:
		static	void			processResultsRow(const CSQLiteResultsRow& resultsRow, ProcInfo* procInfo)
									{
										// Process results
										SInt64	id = *resultsRow.getSInt64(mIDTableColumn);
										CString	documentID = *resultsRow.getString(mDocumentIDTableColumn);
										UInt32	revision = *resultsRow.getUInt32(mRevisionTableColumn);
										bool	active = *resultsRow.getUInt32(mActiveTableColumn) == 1;

										// Call proc
										procInfo->perform(
												ExistingDocumentInfo(id,
														CMDSDocument::RevisionInfo(documentID, revision), active),
												resultsRow);
									}

	// Properties
	public:
		static	const	CSQLiteTableColumn	mIDTableColumn;
		static	const	CSQLiteTableColumn	mDocumentIDTableColumn;
		static	const	CSQLiteTableColumn	mRevisionTableColumn;
		static	const	CSQLiteTableColumn	mActiveTableColumn;

	private:
		static	const	CSQLiteTableColumn	mTableColumns[];
};

const	CSQLiteTableColumn	CDocumentTypeInfoTable::mIDTableColumn(CString(OSSTR("id")), CSQLiteTableColumn::kInteger,
									(CSQLiteTableColumn::Options)
											(CSQLiteTableColumn::kPrimaryKey | CSQLiteTableColumn::kAutoIncrement));
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mDocumentIDTableColumn(CString(OSSTR("documentID")),
									CSQLiteTableColumn::kText,
											(CSQLiteTableColumn::Options)
													(CSQLiteTableColumn::kNotNull | CSQLiteTableColumn::kUnique));
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mRevisionTableColumn(CString(OSSTR("revision")),
									CSQLiteTableColumn::kInteger, CSQLiteTableColumn::kNotNull);
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mActiveTableColumn(CString(OSSTR("active")),
									CSQLiteTableColumn::kInteger, CSQLiteTableColumn::kNotNull);
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mTableColumns[] =
									{ mIDTableColumn, mDocumentIDTableColumn, mRevisionTableColumn,
											mActiveTableColumn };

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CDocumentTypeContentTable

class CDocumentTypeContentTable {
	// Methods
	public:
		static	CSQLiteTable		in(CSQLiteDatabase& database, const CString& nameRoot,
											const CSQLiteTable& infoTable, UInt32 version)
										{
											// Setup
											Reference	reference(mIDTableColumn, infoTable,
																CDocumentTypeInfoTable::mIDTableColumn);

											return database.getTable(nameRoot + CString(OSSTR("Contents")),
													CSQLiteTable::kNone, TSArray<CSQLiteTableColumn>(mTableColumns, 4),
													TSArray<Reference>(reference));
										}
		static	DocumentBackingInfo	getDocumentBackingInfo(const ExistingDocumentInfo& existingDocumentInfo,
											const CSQLiteResultsRow& resultsRow)
										{
											// Process results
													UniversalTime	creationUniversalTime =
																			SGregorianDate::getFrom(
																					*resultsRow.getString(
																							mCreationDateTableColumn),
																					SGregorianDate::
																							kStringStyleRFC339Extended)
																					->getUniversalTime();
													UniversalTime	modificationUniversalTime =
																			SGregorianDate::getFrom(
																					*resultsRow.getString(
																							mModificationDateTableColumn),
																					SGregorianDate::
																							kStringStyleRFC339Extended)
																					->getUniversalTime();
											const	CDictionary&	propertyMap =
																			*CJSON::dictionaryFrom(
																							*resultsRow.getData(
																									mJSONTableColumn));

											return DocumentBackingInfo(
													existingDocumentInfo.mDocumentRevisionInfo.mDocumentID,
													CMDSSQLiteDocumentBacking(existingDocumentInfo.mID,
															existingDocumentInfo.mDocumentRevisionInfo.mRevision,
															creationUniversalTime, modificationUniversalTime,
															propertyMap, existingDocumentInfo.mActive));
										}
		static	void				add(SInt64 id, UniversalTime creationUniversalTime,
											UniversalTime modificationUniversalTime, const CDictionary& propertyMap,
											CSQLiteTable& table)
										{
											// Setup
											const	CData&	data = *CJSON::dataFrom(propertyMap);

											// Insert
											TableColumnAndValue	contentTableColumnAndValues[] =
																		{
																			TableColumnAndValue(mIDTableColumn, id),
																			TableColumnAndValue(
																					mCreationDateTableColumn,
																					SGregorianDate(
																							creationUniversalTime)
																					.getString(
																							SGregorianDate::
																							kStringStyleRFC339Extended)),
																			TableColumnAndValue(
																					mModificationDateTableColumn,
																					SGregorianDate(
																							modificationUniversalTime)
																					.getString(
																							SGregorianDate::
																							kStringStyleRFC339Extended)),
																			TableColumnAndValue(mJSONTableColumn, data),
																		};
											table.insertRow(contentTableColumnAndValues, 4);
										}
		static	void				update(SInt64 id, UniversalTime modificationUniversalTime,
											const CDictionary& propertyMap, CSQLiteTable& table)
										{
											// Setup
											const	CData&	data = *CJSON::dataFrom(propertyMap);

											// Update
											TableColumnAndValue	contentTableColumnAndValues[] =
																		{
																			TableColumnAndValue(
																					mModificationDateTableColumn,
																					SGregorianDate(
																							modificationUniversalTime)
																					.getString(
																							SGregorianDate::
																							kStringStyleRFC339Extended)),
																			TableColumnAndValue(mJSONTableColumn, data),
																		};
											table.update(contentTableColumnAndValues, 2,
													CSQLiteWhere(mIDTableColumn, SSQLiteValue(id)));
										}
		static	void				remove(SInt64 id, CSQLiteTable& table)
										{
											// Setup
											const	CData&	data = *CJSON::dataFrom(CDictionary());

											// Update
											TableColumnAndValue	contentTableColumnAndValues[] =
																		{
																			TableColumnAndValue(
																					mModificationDateTableColumn,
																					SGregorianDate()
																					.getString(
																							SGregorianDate::
																							kStringStyleRFC339Extended)),
																			TableColumnAndValue(mJSONTableColumn, data),
																		};
											table.update(contentTableColumnAndValues, 2,
													CSQLiteWhere(mIDTableColumn, SSQLiteValue(id)));
										}

	// Properties
	private:
		static	CSQLiteTableColumn	mIDTableColumn;
		static	CSQLiteTableColumn	mCreationDateTableColumn;
		static	CSQLiteTableColumn	mModificationDateTableColumn;
		static	CSQLiteTableColumn	mJSONTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CDocumentTypeContentTable::mIDTableColumn(CString(OSSTR("id")), CSQLiteTableColumn::kInteger,
							CSQLiteTableColumn::kPrimaryKey);
CSQLiteTableColumn	CDocumentTypeContentTable::mCreationDateTableColumn(CString(OSSTR("creationDate")),
							CSQLiteTableColumn::kText, CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CDocumentTypeContentTable::mModificationDateTableColumn(CString(OSSTR("modificationDate")),
							CSQLiteTableColumn::kText, CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CDocumentTypeContentTable::mJSONTableColumn(CString(OSSTR("json")), CSQLiteTableColumn::kBlob,
							CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CDocumentTypeContentTable::mTableColumns[] =
							{ mIDTableColumn, mCreationDateTableColumn, mModificationDateTableColumn,
									mJSONTableColumn };

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CCollectionsTable

class CCollectionsTable {
	// CollectionInfo
	public:
		struct CollectionInfo {

			// Properties
			OV<UInt32>	mStoredVersion;
			OV<UInt32>	mStoredLastRevision;
		};

	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const OV<UInt32>& version)
									{ return database.getTable(CString(OSSTR("Collections")), CSQLiteTable::kNone,
											TSArray<CSQLiteTableColumn>(mTableColumns, 3)); }
		static	CollectionInfo	getInfo(const CString& name, CSQLiteTable& table)
									{
										// Setup
										CSQLiteTableColumn	tableColumns[] =
																	{ mVersionTableColumn, mLastRevisionTableColumn };

										// Query
										CollectionInfo	collectionInfo;
										table.select(tableColumns, 2,
												CSQLiteWhere(mNameTableColumn, SSQLiteValue(name)),
												(CSQLiteResultsRow::Proc) getCollectionInfo, &collectionInfo);

										return collectionInfo;
									}
		static	void			update(const CString& name, UInt32 version, UInt32 lastRevision, CSQLiteTable& table)
									{
										// Insert or replace
										TableColumnAndValue	tableColumnAndValues[] =
																	{
																		TableColumnAndValue(mNameTableColumn, name),
																		TableColumnAndValue(mVersionTableColumn,
																				version),
																		TableColumnAndValue(mLastRevisionTableColumn,
																				lastRevision),
																	};
										table.insertOrReplaceRow(tableColumnAndValues, 3);
									}
		static	void			update(const CString& name, UInt32 lastRevision, CSQLiteTable& table)
									{ table.update(TableColumnAndValue(mLastRevisionTableColumn, lastRevision),
												CSQLiteWhere(mNameTableColumn, SSQLiteValue(name))); }

	private:
		static	void			getCollectionInfo(const CSQLiteResultsRow& resultsRow, CollectionInfo* collectionInfo)
									{
										// Process results
										collectionInfo->mStoredVersion = resultsRow.getUInt32(mVersionTableColumn);
										collectionInfo->mStoredLastRevision =
												resultsRow.getUInt32(mLastRevisionTableColumn);
									}

	// Properties
	private:
		static	CSQLiteTableColumn	mNameTableColumn;
		static	CSQLiteTableColumn	mVersionTableColumn;
		static	CSQLiteTableColumn	mLastRevisionTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CCollectionsTable::mNameTableColumn(CString(OSSTR("name")), CSQLiteTableColumn::kText,
							(CSQLiteTableColumn::Options) (CSQLiteTableColumn::kNotNull | CSQLiteTableColumn::kUnique));
CSQLiteTableColumn	CCollectionsTable::mVersionTableColumn(CString(OSSTR("version")), CSQLiteTableColumn::kInteger,
							CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CCollectionsTable::mLastRevisionTableColumn(CString(OSSTR("lastRevision")),
							CSQLiteTableColumn::kInteger, CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CCollectionsTable::mTableColumns[] =
							{ mNameTableColumn, mVersionTableColumn, mLastRevisionTableColumn };

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CCollectionContentsTable

class CCollectionContentsTable {
	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const CString& name, UInt32 version)
									{ return database.getTable(CString(OSSTR("Collection-")) + name,
											CSQLiteTable::kWithoutRowID,
											TSArray<CSQLiteTableColumn>(mTableColumns, 1)); }
		static	void			update(const TNumberArray<SInt64>& includedIDs,
										const TNumberArray<SInt64>& notIncludedIDs, CSQLiteTable& table)
									{
										// Update
										if (!notIncludedIDs.isEmpty())
											// Delete
											table.deleteRows(mIDTableColumn, SSQLiteValue::valuesFrom(notIncludedIDs));
										if (!includedIDs.isEmpty())
											// Update
											table.insertOrReplaceRows(mIDTableColumn,
													SSQLiteValue::valuesFrom(includedIDs));
									}

	// Properties
	private:
		static	CSQLiteTableColumn	mIDTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CCollectionContentsTable::mIDTableColumn(CString(OSSTR("id")), CSQLiteTableColumn::kInteger,
							CSQLiteTableColumn::kPrimaryKey);
CSQLiteTableColumn	CCollectionContentsTable::mTableColumns[] = { mIDTableColumn };

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CIndexesTable

class CIndexesTable {
	// IndexInfo
	public:
		struct IndexInfo {

			// Properties
			OV<UInt32>	mStoredVersion;
			OV<UInt32>	mStoredLastRevision;
		};

	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const OV<UInt32>& version)
									{ return database.getTable(CString(OSSTR("Indexes")), CSQLiteTable::kNone,
											TSArray<CSQLiteTableColumn>(mTableColumns, 3)); }
		static	IndexInfo		getInfo(const CString& name, CSQLiteTable& table)
									{
										// Setup
										CSQLiteTableColumn	tableColumns[] =
																	{ mVersionTableColumn, mLastRevisionTableColumn };

										// Query
										IndexInfo	indexInfo;
										table.select(tableColumns, 2,
												CSQLiteWhere(mNameTableColumn, SSQLiteValue(name)),
												(CSQLiteResultsRow::Proc) getIndexInfo, &indexInfo);

										return indexInfo;
									}
		static	void			update(const CString& name, UInt32 version, UInt32 lastRevision, CSQLiteTable& table)
									{
										// Insert or replace
										TableColumnAndValue	tableColumnAndValues[] =
																	{
																		TableColumnAndValue(mNameTableColumn, name),
																		TableColumnAndValue(mVersionTableColumn,
																				version),
																		TableColumnAndValue(mLastRevisionTableColumn,
																				lastRevision),
																	};
										table.insertOrReplaceRow(tableColumnAndValues, 3);
									}
		static	void			update(const CString& name, UInt32 lastRevision, CSQLiteTable& table)
									{ table.update(TableColumnAndValue(mLastRevisionTableColumn, lastRevision),
												CSQLiteWhere(mNameTableColumn, SSQLiteValue(name))); }

	private:
		static	void			getIndexInfo(const CSQLiteResultsRow& resultsRow, IndexInfo* indexInfo)
									{
										// Process results
										indexInfo->mStoredVersion = resultsRow.getUInt32(mVersionTableColumn);
										indexInfo->mStoredLastRevision = resultsRow.getUInt32(mLastRevisionTableColumn);
									}

	// Properties
	private:
		static	CSQLiteTableColumn	mNameTableColumn;
		static	CSQLiteTableColumn	mVersionTableColumn;
		static	CSQLiteTableColumn	mLastRevisionTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CIndexesTable::mNameTableColumn(CString(OSSTR("name")), CSQLiteTableColumn::kText,
							(CSQLiteTableColumn::Options) (CSQLiteTableColumn::kNotNull | CSQLiteTableColumn::kUnique));
CSQLiteTableColumn	CIndexesTable::mVersionTableColumn(CString(OSSTR("version")), CSQLiteTableColumn::kInteger,
							CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CIndexesTable::mLastRevisionTableColumn(CString(OSSTR("lastRevision")),
							CSQLiteTableColumn::kInteger, CSQLiteTableColumn::kNotNull);
CSQLiteTableColumn	CIndexesTable::mTableColumns[] =
							{ mNameTableColumn, mVersionTableColumn, mLastRevisionTableColumn };

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CIndexContentsTable

class CIndexContentsTable {
	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const CString& name, UInt32 version)
									{ return database.getTable(CString(OSSTR("Index-")) + name,
											CSQLiteTable::kWithoutRowID,
											TSArray<CSQLiteTableColumn>(mTableColumns, 2)); }
		static	CString			getKey(const CSQLiteResultsRow& resultsRow)
									{ return *resultsRow.getString(mKeyTableColumn); }
		static	void			update(const CMDSSQLiteIndexKeysInfos& keysInfos,
										const TNumberArray<SInt64>& removedIDs, CSQLiteTable& table)
									{
										// Setup
										SSQLiteValuesArray	idsToRemove = SSQLiteValue::valuesFrom(removedIDs);
										CArray::ItemCount	count = keysInfos.getCount();
										for (CArray::ItemIndex i = 0; i < count; i++)
											// Add value
											idsToRemove += SSQLiteValue(keysInfos[i].mValue);

										// Update tables
										if (!idsToRemove.isEmpty())
											// Delete
											table.deleteRows(mIDTableColumn, idsToRemove);
										for (TIteratorD<CMDSSQLiteIndexKeysInfo > keysInfosIterator =
														keysInfos.getIterator();
												keysInfosIterator.hasValue(); keysInfosIterator.advance())
											// Insert new keys
											for (TIteratorD<CString> keyIterator =
															keysInfosIterator->mKeys.getIterator();
													keyIterator.hasValue(); keyIterator.advance()) {
												// Insert this key
												TableColumnAndValue	tableColumnAndValues[] =
																			{
																				TableColumnAndValue(mKeyTableColumn,
																						*keyIterator),
																				TableColumnAndValue(mIDTableColumn,
																						keysInfosIterator->mValue),
																			};
												table.insertRow(tableColumnAndValues, 2);
											}
									}

	// Properties
	public:
		static	const	CSQLiteTableColumn	mKeyTableColumn;

	private:
		static	const	CSQLiteTableColumn	mIDTableColumn;
		static	const	CSQLiteTableColumn	mTableColumns[];
};

const	CSQLiteTableColumn	CIndexContentsTable::mKeyTableColumn(CString(OSSTR("key")), CSQLiteTableColumn::kText,
									CSQLiteTableColumn::kPrimaryKey);
const	CSQLiteTableColumn	CIndexContentsTable::mIDTableColumn(CString(OSSTR("id")), CSQLiteTableColumn::kInteger,
									CSQLiteTableColumn::kNotNull);
const	CSQLiteTableColumn	CIndexContentsTable::mTableColumns[] = { mKeyTableColumn, mIDTableColumn };

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDatabaseManagerInternals

class CMDSSQLiteDatabaseManagerInternals {
	public:
		// DocumentTables
		struct DocumentTables {
			// Lifecycle methods
			DocumentTables(const CSQLiteTable& infoTable, const CSQLiteTable& contentTable) :
				mInfoTable(infoTable), mContentTable(contentTable)
				{}

			// Properties
			CSQLiteTable	mInfoTable;
			CSQLiteTable	mContentTable;
		};

	public:
									CMDSSQLiteDatabaseManagerInternals(CSQLiteDatabase& database) :
										mDatabase(database), mInfoTable(CInfoTable::in(database)),
												mDatabaseVersion(CInfoTable::getUInt32(CString(OSSTR("version")),
														mInfoTable)),
												mDocumentsMasterTable(CDocumentsTable::in(database, mDatabaseVersion)),
												mCollectionsMasterTable(
														CCollectionsTable::in(database, mDatabaseVersion)),
												mIndexesMasterTable(CIndexesTable::in(database, mDatabaseVersion))
										{
											// Create tables
											mInfoTable.create();
											mDocumentsMasterTable.create();
											mCollectionsMasterTable.create();
											mIndexesMasterTable.create();

											// Finalize version
											if (!mDatabaseVersion.hasValue()) {
												// Update version
												mDatabaseVersion = OV<UInt32>(1);
												CInfoTable::set(CString(OSSTR("version")),
														OV<SValue>(*mDatabaseVersion), mInfoTable);
											}

											// Finalize setup
											CDocumentsTable::iterate(mDocumentsMasterTable,
													(CDocumentsTable::Proc) setupDocumentsLastRevisionMap,
													&mDocumentLastRevisionMap);
										}

				DocumentTables&		getDocumentTables(const CString& documentType)
										{
											// Check for already having tables
											if (!mDocumentTablesMap.contains(documentType)) {
												// Setup tables
												CString			nameRoot =
																		documentType.getSubString(0, 1).uppercased() +
																				documentType.getSubString(1);
												CSQLiteTable	infoTable =
																		CDocumentTypeInfoTable::in(mDatabase, nameRoot,
																				*mDatabaseVersion);
												CSQLiteTable	contentTable =
																		CDocumentTypeContentTable::in(mDatabase,
																				nameRoot, infoTable, *mDatabaseVersion);

												// Create tables
												infoTable.create();
												contentTable.create();

												// Store
												mDocumentTablesMap.set(documentType,
														DocumentTables(infoTable, contentTable));
											}

											return *mDocumentTablesMap.get(documentType);
										}
				UInt32				getNextRevision(const CString& documentType)
										{
											// Compose next revision
											const	OR<TNumber<UInt32> >	currentRevision =
																					mDocumentLastRevisionMap.get(
																							documentType);
													UInt32					nextRevision =
																					currentRevision.hasReference() ?
																							**currentRevision + 1 : 1;

											// Check for batch
											const	OR<SBatchInfo>	batchInfo =
																			mBatchInfoMap[
																					CThread::getCurrentRefAsString()];
											if (batchInfo.hasReference())
												// In batch
												batchInfo->mDocumentLastRevisionTypesNeedingWrite += documentType;
											else
												// Update
												CDocumentsTable::set(nextRevision, documentType, mDocumentsMasterTable);

											// Store
											mDocumentLastRevisionMap.set(documentType, TNumber<UInt32>(nextRevision));

											return nextRevision;
										}

	private:
		static	void				setupDocumentsLastRevisionMap(const CString& documentType, UInt32 lastRevision,
											TNLockingDictionary<TNumber<UInt32> >* documentLastRevisionMap)
										{ documentLastRevisionMap->set(documentType, TNumber<UInt32>(lastRevision)); }

	public:
		CSQLiteDatabase& 						mDatabase;
		OV<UInt32>								mDatabaseVersion;

		CSQLiteTable							mInfoTable;

		CSQLiteTable							mDocumentsMasterTable;
		TNLockingDictionary<DocumentTables>		mDocumentTablesMap;
		TNLockingDictionary<TNumber<UInt32> >	mDocumentLastRevisionMap;

		CSQLiteTable							mCollectionsMasterTable;
		TNLockingDictionary<CSQLiteTable>		mCollectionTablesMap;

		CSQLiteTable							mIndexesMasterTable;
		TNLockingDictionary<CSQLiteTable>		mIndexTablesMap;

		TNLockingDictionary<SBatchInfo>			mBatchInfoMap;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDatabaseManager

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::CMDSSQLiteDatabaseManager(CSQLiteDatabase& database)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = new CMDSSQLiteDatabaseManagerInternals(database);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::~CMDSSQLiteDatabaseManager()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
OV<UInt32> CMDSSQLiteDatabaseManager::getUInt32(const CString& key) const
//----------------------------------------------------------------------------------------------------------------------
{
	return CInfoTable::getUInt32(key, mInternals->mInfoTable);
}

//----------------------------------------------------------------------------------------------------------------------
OV<CString> CMDSSQLiteDatabaseManager::getString(const CString& key) const
//----------------------------------------------------------------------------------------------------------------------
{
	return CInfoTable::getString(key, mInternals->mInfoTable);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::set(const CString& key, const OV<SValue>& value)
//----------------------------------------------------------------------------------------------------------------------
{
	CInfoTable::set(key, value, mInternals->mInfoTable);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::note(const CString& documentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Ensure we have the document tables for this document type
	mInternals->getDocumentTables(documentType);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::batch(BatchProc batchProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	mInternals->mBatchInfoMap.set(CThread::getCurrentRefAsString(), SBatchInfo());

	// Call proc
	batchProc(userData);

	// Commit changes
	SBatchInfo	batchInfo(*mInternals->mBatchInfoMap.get(CThread::getCurrentRefAsString()));
	mInternals->mBatchInfoMap.remove(CThread::getCurrentRefAsString());

	for (TIteratorS<CString> iterator = batchInfo.mDocumentLastRevisionTypesNeedingWrite.getIterator();
			iterator.hasValue(); iterator.advance())
		// Update
		CDocumentsTable::set(**mInternals->mDocumentLastRevisionMap.get(*iterator), *iterator,
				mInternals->mDocumentsMasterTable);
	for (TIteratorS<CDictionary::Item> iterator = batchInfo.mCollectionInfo.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Setup
		const	SCollectionUpdateInfo&	collectionUpdateInfo =
												*((SCollectionUpdateInfo*) iterator->mValue.getOpaque());

		// Update collection
		updateCollection(iterator->mKey, collectionUpdateInfo.mIncludedValues, collectionUpdateInfo.mNotIncludedValues,
				collectionUpdateInfo.mLastRevision);
	}
	for (TIteratorS<CDictionary::Item> iterator = batchInfo.mIndexInfo.getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Setup
		const	SIndexUpdateInfo&	indexUpdateInfo = *((SIndexUpdateInfo*) iterator->mValue.getOpaque());

		// Update index
		updateIndex(iterator->mKey, indexUpdateInfo.mKeysInfos, indexUpdateInfo.mRemovedIDs,
				indexUpdateInfo.mLastRevision);
	}
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::NewDocumentInfo CMDSSQLiteDatabaseManager::newDocument(const CString& documentType,
		const CString& documentID, OV<UniversalTime> creationUniversalTime, OV<UniversalTime> modificationUniversalTime,
		const CDictionary& propertyMap)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	UInt32			revision = mInternals->getNextRevision(documentType);
	UniversalTime	creationUniversalTimeUse =
							creationUniversalTime.hasValue() ? *creationUniversalTime : SUniversalTime::getCurrent();
	UniversalTime	modificationUniversalTimeUse =
							modificationUniversalTime.hasValue() ?
									*modificationUniversalTime : creationUniversalTimeUse;

	// Add to database
	CMDSSQLiteDatabaseManagerInternals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);
	SInt64												id =
																CDocumentTypeInfoTable::add(documentID, revision,
																		documentTables.mInfoTable);
	CDocumentTypeContentTable::add(id, creationUniversalTimeUse, modificationUniversalTimeUse, propertyMap,
			documentTables.mContentTable);

	return NewDocumentInfo(id, revision, creationUniversalTimeUse, modificationUniversalTimeUse);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::iterate(const CString& documentType, const CSQLiteInnerJoin& innerJoin,
		const CSQLiteWhere& where, ExistingDocumentInfoProc existingDocumentInfoProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CMDSSQLiteDatabaseManagerInternals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Iterate
	CDocumentTypeInfoTable::iterate(documentTables.mInfoTable, innerJoin, where, existingDocumentInfoProc, userData);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::iterate(const CString& documentType, const CSQLiteInnerJoin& innerJoin,
		ExistingDocumentInfoProc existingDocumentInfoProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CMDSSQLiteDatabaseManagerInternals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Iterate
	CDocumentTypeInfoTable::iterate(documentTables.mInfoTable, innerJoin, existingDocumentInfoProc, userData);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::UpdateInfo CMDSSQLiteDatabaseManager::updateDocument(const CString& documentType, SInt64 id,
		const CDictionary& propertyMap)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	UInt32			revision = mInternals->getNextRevision(documentType);
	UniversalTime	modificationUniversalTime = SUniversalTime::getCurrent();

	// Update
	CMDSSQLiteDatabaseManagerInternals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);
	CDocumentTypeInfoTable::update(id, revision, documentTables.mInfoTable);
	CDocumentTypeContentTable::update(id, modificationUniversalTime, propertyMap, documentTables.mContentTable);

	return UpdateInfo(revision, modificationUniversalTime);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::removeDocument(const CString& documentType, SInt64 id)
//----------------------------------------------------------------------------------------------------------------------
{
	// Remove
	CMDSSQLiteDatabaseManagerInternals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);
	CDocumentTypeInfoTable::remove(id, documentTables.mInfoTable);
	CDocumentTypeContentTable::remove(id, documentTables.mContentTable);
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::registerCollection(const CString& documentType, const CString& name, UInt32 version,
		bool isUpToDate)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get current info
	CCollectionsTable::CollectionInfo	collectionInfo =
												CCollectionsTable::getInfo(name, mInternals->mCollectionsMasterTable);

	// Setup table
	CSQLiteTable	table = CCollectionContentsTable::in(mInternals->mDatabase, name, *mInternals->mDatabaseVersion);
	mInternals->mCollectionTablesMap.set(name, table);

	// Compose last revision
	UInt32	lastRevision;
	bool	updateMasterTable;
	if (!collectionInfo.mStoredLastRevision.hasValue()) {
		// New
		OR<TNumber<UInt32> >	currentLastRevision = mInternals->mDocumentLastRevisionMap.get(documentType);
		lastRevision = isUpToDate ? (currentLastRevision.hasReference() ? **currentLastRevision : 0) : 0;
		updateMasterTable = true;
	} else if (version != *collectionInfo.mStoredLastRevision) {
		// Updated version
		lastRevision = 0;
		updateMasterTable = true;
	} else {
		// No change
		lastRevision = *collectionInfo.mStoredLastRevision;
		updateMasterTable = false;
	}

	// Check if need to update the master table
	if (updateMasterTable) {
		// New or updated
		CCollectionsTable::update(name, version, lastRevision, mInternals->mCollectionsMasterTable);

		// Update table
		if (collectionInfo.mStoredLastRevision.hasValue()) table.drop();
		table.create();
	}

	return lastRevision;
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::getCollectionDocumentCount(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mCollectionTablesMap[name]->count();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::updateCollection(const CString& name, const TNumberArray<SInt64>& includedIDs,
		const TNumberArray<SInt64>& notIncludedIDs, UInt32 lastRevision)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if in batch
	const	OR<SBatchInfo>	batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	if (batchInfo.hasReference()) {
		// In batch
		const	OR<SCollectionUpdateInfo>&	collectionUpdateInfo = batchInfo->mCollectionInfo[name];
		if (collectionUpdateInfo.hasReference()) {
			// Already have collection update info
			collectionUpdateInfo->mIncludedValues.addFrom(includedIDs);
			collectionUpdateInfo->mNotIncludedValues.addFrom(notIncludedIDs);
			collectionUpdateInfo->mLastRevision = lastRevision;
		} else
			// Don't have collection update info
			batchInfo->mCollectionInfo.set(name, SCollectionUpdateInfo(includedIDs, notIncludedIDs, lastRevision));
	} else {
		// Update tables
		CCollectionsTable::update(name, lastRevision, mInternals->mCollectionsMasterTable);
		CCollectionContentsTable::update(includedIDs, notIncludedIDs, *mInternals->mCollectionTablesMap[name]);
	}
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::registerIndex(const CString& documentType, const CString& name, UInt32 version,
		bool isUpToDate)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get current info
	CIndexesTable::IndexInfo	indexInfo = CIndexesTable::getInfo(name, mInternals->mIndexesMasterTable);

	// Setup table
	CSQLiteTable	table = CIndexContentsTable::in(mInternals->mDatabase, name, *mInternals->mDatabaseVersion);
	mInternals->mIndexTablesMap.set(name, table);

	// Compose last revision
	UInt32	lastRevision;
	bool	updateMasterTable;
	if (!indexInfo.mStoredLastRevision.hasValue()) {
		// New
		OR<TNumber<UInt32> >	currentLastRevision = mInternals->mDocumentLastRevisionMap.get(documentType);
		lastRevision = isUpToDate ? (currentLastRevision.hasReference() ? **currentLastRevision : 0) : 0;
		updateMasterTable = true;
	} else if (version != *indexInfo.mStoredLastRevision) {
		// Updated version
		lastRevision = 0;
		updateMasterTable = true;
	} else {
		// No change
		lastRevision = *indexInfo.mStoredLastRevision;
		updateMasterTable = false;
	}

	// Check if need to update the master table
	if (updateMasterTable) {
		// New or updated
		CIndexesTable::update(name, version, lastRevision, mInternals->mIndexesMasterTable);

		// Update table
		if (indexInfo.mStoredLastRevision.hasValue()) table.drop();
		table.create();
	}

	return lastRevision;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::updateIndex(const CString& name, const CMDSSQLiteIndexKeysInfos& keysInfos,
		const TNumberArray<SInt64>& removedIDs, UInt32 lastRevision)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if in batch
	const	OR<SBatchInfo>	batchInfo = mInternals->mBatchInfoMap[CThread::getCurrentRefAsString()];
	if (batchInfo.hasReference()) {
		// In batch
		const	OR<SIndexUpdateInfo>&	indexUpdateInfo = batchInfo->mIndexInfo[name];
		if (indexUpdateInfo.hasReference()) {
			// Already have index update info
			indexUpdateInfo->mKeysInfos.addFrom(keysInfos);
			indexUpdateInfo->mRemovedIDs.addFrom(removedIDs);
			indexUpdateInfo->mLastRevision = lastRevision;
		} else
			// Don't have index update info
			batchInfo->mIndexInfo.set(name, SIndexUpdateInfo(keysInfos, removedIDs, lastRevision));
	} else {
		// Update tables
		CIndexesTable::update(name, lastRevision, mInternals->mIndexesMasterTable);
		CIndexContentsTable::update(keysInfos, removedIDs, *mInternals->mIndexTablesMap[name]);
	}
}

//----------------------------------------------------------------------------------------------------------------------
CSQLiteInnerJoin CMDSSQLiteDatabaseManager::getInnerJoin(const CString& documentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CMDSSQLiteDatabaseManagerInternals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	return CSQLiteInnerJoin(documentTables.mInfoTable, CDocumentTypeInfoTable::mIDTableColumn,
			documentTables.mContentTable);
}

//----------------------------------------------------------------------------------------------------------------------
CSQLiteInnerJoin CMDSSQLiteDatabaseManager::getInnerJoinForCollection(const CString& documentType,
		const CString& collectionName)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CMDSSQLiteDatabaseManagerInternals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);
	OR<CSQLiteTable>									collectionContentsTable =
																mInternals->mCollectionTablesMap.get(collectionName);

	return CSQLiteInnerJoin(documentTables.mInfoTable, CDocumentTypeInfoTable::mIDTableColumn,
					documentTables.mContentTable)
			.addAnd(documentTables.mInfoTable, CDocumentTypeInfoTable::mIDTableColumn, *collectionContentsTable);
}

//----------------------------------------------------------------------------------------------------------------------
CSQLiteInnerJoin CMDSSQLiteDatabaseManager::getInnerJoinForIndex(const CString& documentType, const CString& indexName)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	CMDSSQLiteDatabaseManagerInternals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);
	OR<CSQLiteTable>									indexContentsTable = mInternals->mIndexTablesMap.get(indexName);

	return CSQLiteInnerJoin(documentTables.mInfoTable, CDocumentTypeInfoTable::mIDTableColumn,
					documentTables.mContentTable)
			.addAnd(documentTables.mInfoTable, CDocumentTypeInfoTable::mIDTableColumn, *indexContentsTable);
}

//----------------------------------------------------------------------------------------------------------------------
CSQLiteWhere CMDSSQLiteDatabaseManager::getWhere(bool active)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return CSQLiteWhere
	return CSQLiteWhere(CDocumentTypeInfoTable::mActiveTableColumn, SSQLiteValue((UInt32) (active ? 1 : 0)));
}

//----------------------------------------------------------------------------------------------------------------------
CSQLiteWhere CMDSSQLiteDatabaseManager::getWhereForDocumentIDs(const TArray<CString>& documentIDs)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return CSQLiteWhere
	return CSQLiteWhere(CDocumentTypeInfoTable::mDocumentIDTableColumn, SSQLiteValue::valuesFrom(documentIDs));
}

//----------------------------------------------------------------------------------------------------------------------
CSQLiteWhere CMDSSQLiteDatabaseManager::getWhere(UInt32 revision, const CString& comparison, bool includeInactive)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return CSQLiteWhere
	return includeInactive ?
			CSQLiteWhere(CDocumentTypeInfoTable::mRevisionTableColumn, comparison, SSQLiteValue(revision)) :
			CSQLiteWhere(CDocumentTypeInfoTable::mRevisionTableColumn, comparison, SSQLiteValue(revision))
					.addAnd(CDocumentTypeInfoTable::mActiveTableColumn, SSQLiteValue((UInt32) 1));
}

//----------------------------------------------------------------------------------------------------------------------
CSQLiteWhere CMDSSQLiteDatabaseManager::getWhereForIndexKeys(const TArray<CString>& keys)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return CSQLiteWhere
	return CSQLiteWhere(CIndexContentsTable::mKeyTableColumn, SSQLiteValue::valuesFrom(keys));
}

// MARK: Class methods

//----------------------------------------------------------------------------------------------------------------------
DocumentBackingInfo CMDSSQLiteDatabaseManager::getDocumentBackingInfo(const ExistingDocumentInfo& existingDocumentInfo,
		const CSQLiteResultsRow& resultsRow)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return document backing info
	return CDocumentTypeContentTable::getDocumentBackingInfo(existingDocumentInfo, resultsRow);
}

//----------------------------------------------------------------------------------------------------------------------
CString CMDSSQLiteDatabaseManager::getIndexContentsKey(const CSQLiteResultsRow& resultsRow)
//----------------------------------------------------------------------------------------------------------------------
{
	return CIndexContentsTable::getKey(resultsRow);
}
