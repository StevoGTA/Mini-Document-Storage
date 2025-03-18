//----------------------------------------------------------------------------------------------------------------------
//	CMDSSQLiteDatabaseManager.cpp			©2021 Stevo Brock	All rights reserved.
//----------------------------------------------------------------------------------------------------------------------

#include "CMDSSQLiteDatabaseManager.h"

#include "CJSON.h"
#include "CMDSDocumentStorage.h"
#include "CThread.h"
#include "TLockingDictionary.h"
#include "TMDSCollection.h"

/*
	See https://docs.google.com/document/d/1zgMAzYLemHA05F_FR4QZP_dn51cYcVfKMcUfai60FXE for overview

	Summary:
		Associations table
			Columns:
		Association-{ASSOCIATIONNAME}
			Columns:

		Caches table
			Columns:
		Cache-{CACHENAME}
			Columns:

		Collections table
			Columns: name, version, lastRevision
		Collection-{COLLECTIONNAME}
			Columns: id

		Documents table
			Columns: type, lastRevision
		{DOCUMENTTYPE}s
			Columns: id, documentID, revision
		{DOCUMENTTYPE}Contents
			Columns: id, creationDate, modificationDate, json
		{DOCUMENTTYPE}Attachments
			Columns:

		Indexes table
			Columns: name, version, lastRevision
		Index-{INDEXNAME}
			Columns: key, id

		Info table
			Columns: key, value

		Internal table
			Columns: key, value

		Internals table
			Columns: key, value
*/

//----------------------------------------------------------------------------------------------------------------------
// MARK: Local types

typedef	CMDSDocument::RevisionInfo						DocumentRevisionInfo;
typedef	CMDSDocument::AttachmentInfoByID				DocumentAttachmentInfoByID;

typedef	CMDSSQLiteDatabaseManager::AssociationInfo		AssociationInfo;

typedef	CMDSSQLiteDatabaseManager::CacheValueInfo		CacheValueInfo;
typedef	CMDSSQLiteDatabaseManager::CacheValueInfos		CacheValueInfos;
typedef	CMDSSQLiteDatabaseManager::CacheInfo			CacheInfo;

typedef	CMDSSQLiteDatabaseManager::CollectionInfo		CollectionInfo;

typedef	CSQLiteTable::TableColumnAndValue				TableColumnAndValue;

typedef	TArray<SSQLiteValue>							SQLiteValues;

typedef	TNKeyConvertibleDictionary<SInt64, CDictionary>	ValueInfoByID;
typedef	CMDSSQLiteDatabaseManager::IDArray				IDArray;

typedef	TVResult<TArray<TableColumnAndValue> >			TableColumnAndValuesResult;

typedef	TMDSIndex<SInt64>								Index;
typedef	Index::KeysInfo									IndexKeysInfo;
typedef	CMDSSQLiteDatabaseManager::IndexInfo			IndexInfo;

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CInfoTable

class CInfoTable {
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database)
									{ return database.getTable(CString(OSSTR("Info")),
											CSQLiteTable::kOptionsWithoutRowID,
											TSArray<CSQLiteTableColumn>(mTableColumns, 2)); }
		static	OV<UInt32>		getUInt32(const CString& key, CSQLiteTable& table)
									{
										// Retrieve value
										OV<CString>	string;
										table.select(TSArray<CSQLiteTableColumn>(mValueTableColumn),
												CSQLiteWhere(mKeyTableColumn, SSQLiteValue(key)),
												(CSQLiteResultsRow::Proc) getInfoString, &string);

										return string.hasValue() ? OV<UInt32>(string->getUInt32()) : OV<UInt32>();
									}
		static	OV<CString>		getString(const CString& key, CSQLiteTable& table)
									{
										// Retrieve value
										OV<CString>	string;
										table.select(TSArray<CSQLiteTableColumn>(mValueTableColumn),
												CSQLiteWhere(mKeyTableColumn, SSQLiteValue(key)),
												(CSQLiteResultsRow::Proc) getInfoString, &string);

										return string;
									}
		static	void			set(const CString& key, const OV<CString>& string, CSQLiteTable& table)
									{
										// Check if storing or removing
										if (string.hasValue()) {
											// Storing
											TableColumnAndValue	tableColumnAndValues[] =
																		{
																			TableColumnAndValue(mKeyTableColumn, key),
																			TableColumnAndValue(mValueTableColumn,
																					*string),
																		};
											table.insertOrReplaceRow(
													TSARRAY_FROM_C_ARRAY(TableColumnAndValue, tableColumnAndValues));
										} else
											// Removing
											table.deleteRows(mKeyTableColumn, SSQLiteValue(key));
									}

	private:
		static	OV<SError>		getInfoString(const CSQLiteResultsRow& resultsRow, OV<CString>* string)
									{
										// Process results
										*string = resultsRow.getText(mValueTableColumn);

										return OV<SError>();
									}

	private:
		static	CSQLiteTableColumn	mKeyTableColumn;
		static	CSQLiteTableColumn	mValueTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CInfoTable::mKeyTableColumn(CString(OSSTR("key")), CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kOptionsPrimaryKey | CSQLiteTableColumn::kOptionsUnique |
											CSQLiteTableColumn::kOptionsNotNull));
CSQLiteTableColumn	CInfoTable::mValueTableColumn(CString(OSSTR("value")), CSQLiteTableColumn::kKindText,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CInfoTable::mTableColumns[] = {mKeyTableColumn, mValueTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CInternalsTable

class CInternalsTable {
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database)
									{ return database.getTable(CString(OSSTR("Internals")),
											CSQLiteTable::kOptionsWithoutRowID,
											TSArray<CSQLiteTableColumn>(mTableColumns, 2)); }
		static	OV<UInt32>		getVersion(const CSQLiteTable& table, const CSQLiteTable& internalsTable)
									{
										// Query
										OV<UInt32>	version;
										internalsTable.select(TSArray<CSQLiteTableColumn>(mValueTableColumn),
												CSQLiteWhere(mKeyTableColumn,
														SSQLiteValue(table.getName() + CString(OSSTR("TableVersion")))),
												(CSQLiteResultsRow::Proc) getVersion_, &version);

										return version;
									}
		static	void			set(UInt32 version, const CSQLiteTable& table, CSQLiteTable& internalsTable)
									{
										// Update
										TableColumnAndValue	tableColumnAndValues[] =
																	{
																		TableColumnAndValue(mKeyTableColumn,
																				table.getName() +
																						CString(OSSTR("TableVersion"))),
																		TableColumnAndValue(mValueTableColumn,
																				version),
																	};
										internalsTable.insertOrReplaceRow(
												TSARRAY_FROM_C_ARRAY(TableColumnAndValue, tableColumnAndValues));
									}

	private:
		static	OV<SError>		getVersion_(const CSQLiteResultsRow& resultsRow, OV<UInt32>* version)
									{
										// Process results
										version->setValue(resultsRow.getText(mValueTableColumn)->getUInt32());

										return OV<SError>();
									}

	private:
		static	CSQLiteTableColumn	mKeyTableColumn;
		static	CSQLiteTableColumn	mValueTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CInternalsTable::mKeyTableColumn(CString(OSSTR("key")), CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kOptionsPrimaryKey | CSQLiteTableColumn::kOptionsUnique |
											CSQLiteTableColumn::kOptionsNotNull));
CSQLiteTableColumn	CInternalsTable::mValueTableColumn(CString(OSSTR("value")), CSQLiteTableColumn::kKindText,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CInternalsTable::mTableColumns[] = {mKeyTableColumn, mValueTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CAssociationsTable

class CAssociationsTable {
	public:
		typedef	CMDSSQLiteDatabaseManager::AssociationInfo	Info;

		static	CSQLiteTable	in(CSQLiteDatabase& database, CSQLiteTable& internalsTable)
									{
										// Create table
										CSQLiteTable	table =
																database.getTable(CString(OSSTR("Associations")),
																		TSArray<CSQLiteTableColumn>(mTableColumns, 3));

										// Check if need to create
										OV<UInt32>	version = CInternalsTable::getVersion(table, internalsTable);
										if (!version.hasValue()) {
											// Create
											table.create();

											// Store version
											CInternalsTable::set(1, table, internalsTable);
										}

										return table;
									}
		static	OV<Info>		getInfo(const CString& name, CSQLiteTable& table)
									{
										// Query
										OV<Info>	info;
										table.select(CSQLiteWhere(mNameTableColumn, SSQLiteValue(name)),
												(CSQLiteResultsRow::Proc) processGetInfoResultsRow, &info);

										return info;
									}
		static	void			addOrUpdate(const CString& name, const CString& fromDocumentType,
										const CString& toDocumentType, CSQLiteTable& table)
									{
										// Insert or replace
										TableColumnAndValue	tableColumnAndValues[] =
																	{
																		TableColumnAndValue(mNameTableColumn, name),
																		TableColumnAndValue(mFromTypeTableColumn,
																				fromDocumentType),
																		TableColumnAndValue(mToTypeTableColumn,
																				toDocumentType),
																	};
										table.insertOrReplaceRow(
												TSARRAY_FROM_C_ARRAY(TableColumnAndValue, tableColumnAndValues));
									}
		static	OV<SError>		processGetInfoResultsRow(const CSQLiteResultsRow& resultsRow, OV<Info>* info)
									{
										// Process values
										info->setValue(
												Info(*resultsRow.getText(mFromTypeTableColumn),
														*resultsRow.getText(mToTypeTableColumn)));

										return OV<SError>();
									}

	private:
		static	CSQLiteTableColumn	mNameTableColumn;
		static	CSQLiteTableColumn	mFromTypeTableColumn;
		static	CSQLiteTableColumn	mToTypeTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CAssociationsTable::mNameTableColumn(CString(OSSTR("name")), CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kOptionsNotNull | CSQLiteTableColumn::kOptionsUnique));
CSQLiteTableColumn	CAssociationsTable::mFromTypeTableColumn(CString(OSSTR("fromType")), CSQLiteTableColumn::kKindText,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CAssociationsTable::mToTypeTableColumn(CString(OSSTR("toType")), CSQLiteTableColumn::kKindText,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CAssociationsTable::mTableColumns[] = {mNameTableColumn, mFromTypeTableColumn, mToTypeTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CAssociationContentsTable
class CAssociationContentsTable {
	public:
		struct Item {
			public:
									Item(SInt64 fromID, SInt64 toID) : mFromID(fromID), mToID(toID) {}
									Item(const Item& other) : mFromID(other.mFromID), mToID(other.mToID) {}

						SInt64		getFromID() const
										{ return mFromID; }
						SInt64		getToID() const
										{ return mToID; }

				static	OV<SError>	process(const CSQLiteResultsRow& resultsRow, TNArray<Item>* items)
										{
											// Process values
											(*items) +=
													Item(*resultsRow.getInteger(mFromIDTableColumn),
															*resultsRow.getInteger(mToIDTableColumn));

											return OV<SError>();
										}
				static	IDArray		getFromIDs(const TArray<Item>& items)
										{ return TNumberSet<SInt64>(items,
														(TNumberSet<SInt64>::ArrayMapProc) getFromIDFromItem)
												.getNumberArray(); }
				static	IDArray		getToIDs(const TArray<Item>& items)
										{ return TNumberSet<SInt64>(items,
														(TNumberSet<SInt64>::ArrayMapProc) getToIDFromItem)
												.getNumberArray(); }
				static	SInt64		getFromIDFromItem(const Item* item)
										{ return item->mFromID; }
				static	SInt64		getToIDFromItem(const Item* item)
										{ return item->mToID; }

			private:
				SInt64	mFromID;
				SInt64	mToID;
		};

	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const CString& name, CSQLiteTable& internalsTable)
									{
										// Create table
										CSQLiteTable	table =
																database.getTable(
																		CString(OSSTR("Association-")) + name,
																		TSArray<CSQLiteTableColumn>(mTableColumns, 2));

										// Check if need to create
										OV<UInt32>	version = CInternalsTable::getVersion(table, internalsTable);
										if (!version.hasValue()) {
											// Create
											table.create();

											// Store version
											CInternalsTable::set(1, table, internalsTable);
										}

										return table;
									}
		static	UInt32			countFrom(SInt64 fromID, const CSQLiteTable& table)
									{ return table.count(CSQLiteWhere(mFromIDTableColumn, SSQLiteValue(fromID))); }
		static	UInt32			countTo(SInt64 toID, const CSQLiteTable& table)
									{ return table.count(CSQLiteWhere(mToIDTableColumn, SSQLiteValue(toID))); }
		static	TArray<Item>	get(const CSQLiteWhere& where, const CSQLiteTable& table)
									{
										// Iterate all rows
										TNArray<Item>	items;
										table.select(where, (CSQLiteResultsRow::Proc) Item::process, &items);

										return items;
									}
		static	TArray<Item>	get(const CSQLiteTable& table)
									{
										// Iterate all rows
										TNArray<Item>	items;
										table.select((CSQLiteResultsRow::Proc) Item::process, &items);

										return items;
									}
		static	void			add(const TArray<Item>& items, CSQLiteTable& table)
									{
										// Iterate items
										for (TIteratorD<Item> iterator = items.getIterator(); iterator.hasValue();
												iterator.advance()) {
											// Insert
											TableColumnAndValue	tableColumnAndValues[] =
																		{
																			TableColumnAndValue(mFromIDTableColumn,
																					iterator->getFromID()),
																			TableColumnAndValue(mToIDTableColumn,
																					iterator->getToID()),
																		};
											table.insertOrReplaceRow(
													TSARRAY_FROM_C_ARRAY(TableColumnAndValue, tableColumnAndValues));
										}
									}
		static	void			remove(const TArray<Item>& items, CSQLiteTable& table)
									{
										// Iterate items
										for (TIteratorD<Item> iterator = items.getIterator(); iterator.hasValue();
												iterator.advance())
											// Delete
											table.deleteRow(
													CSQLiteWhere(mFromIDTableColumn,
																	SSQLiteValue(iterator->getFromID()))
															.addAnd(mToIDTableColumn,
																	SSQLiteValue(iterator->getToID())));
									}

	public:
		static	CSQLiteTableColumn	mFromIDTableColumn;
		static	CSQLiteTableColumn	mToIDTableColumn;

	private:
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CAssociationContentsTable::mFromIDTableColumn(CString(OSSTR("fromID")),
							CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsNone);
CSQLiteTableColumn	CAssociationContentsTable::mToIDTableColumn(CString(OSSTR("toID")), CSQLiteTableColumn::kKindInteger,
							CSQLiteTableColumn::kOptionsNone);
CSQLiteTableColumn	CAssociationContentsTable::mTableColumns[] = {mFromIDTableColumn, mToIDTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CCachesTable
class CCachesTable {
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, CSQLiteTable& internalsTable)
									{
										// Create table
										CSQLiteTable	table =
																database.getTable(CString(OSSTR("Caches")),
																		TSArray<CSQLiteTableColumn>(mTableColumns, 5));

										// Check if need to create
										OV<UInt32>	version = CInternalsTable::getVersion(table, internalsTable);
										if (!version.hasValue()) {
											// Create
											table.create();

											// Store version
											CInternalsTable::set(1, table, internalsTable);
										}

										return table;
									}
		static	OV<CacheInfo>	getInfo(const CString& name, CSQLiteTable& table)
									{
										// Query
										CSQLiteTableColumn	tableColumns[] =
																	{ mTypeTableColumn,
																			mRelevantPropertiesTableColumn,
																			mInfoTableColumn,
																			mLastRevisionTableColumn };
										OV<CacheInfo>		cacheInfo;
										table.select(TSARRAY_FROM_C_ARRAY(CSQLiteTableColumn, tableColumns),
												CSQLiteWhere(mNameTableColumn, SSQLiteValue(name)),
												(CSQLiteResultsRow::Proc) processCacheInfoResultsRow, &cacheInfo);

										return cacheInfo;
									}
		static	void			addOrUpdate(const CString& name, const CString& documentType,
										const TArray<CString>& relevantProperties,
										const CacheValueInfos& cacheValueInfos, CSQLiteTable& table)
									{
										// Setup
										TNArray<CDictionary>	infos;
										for (TIteratorD<CacheValueInfo> iterator = cacheValueInfos.getIterator();
												iterator.hasValue(); iterator.advance())
											// Add info
											infos += iterator->getInfo();

										// Insert or replace
										TableColumnAndValue	tableColumnAndValues[] =
																	{
																		TableColumnAndValue(mNameTableColumn, name),
																		TableColumnAndValue(mTypeTableColumn,
																				documentType),
																		TableColumnAndValue(
																				mRelevantPropertiesTableColumn,
																				CString(relevantProperties,
																						CString::mComma)),
																		TableColumnAndValue(mInfoTableColumn,
																				*CJSON::dataFrom(infos)),
																		TableColumnAndValue(mLastRevisionTableColumn,
																				(UInt32) 0),
																	};
										table.insertOrReplaceRow(
												TSARRAY_FROM_C_ARRAY(TableColumnAndValue, tableColumnAndValues));
									}
		static	void			update(const CString& name, UInt32 lastRevision, CSQLiteTable& table)
									{
										// Update
										TableColumnAndValue	tableColumnAndValues[] =
																	{
																		TableColumnAndValue(mLastRevisionTableColumn,
																				lastRevision),
																	};
										table.update(
												TSARRAY_FROM_C_ARRAY(TableColumnAndValue, tableColumnAndValues),
												CSQLiteWhere(mNameTableColumn, SSQLiteValue(name)));
									}

		static	OV<SError>		processCacheInfoResultsRow(const CSQLiteResultsRow& resultsRow,
										OV<CacheInfo>* cacheInfo)
									{
										// Get info
										TArray<CString>		relevantProperties =
																	TNArray<CString>(
																			resultsRow.getText(
																					mRelevantPropertiesTableColumn)->
																					components(CString::mComma))
																					.filtered(CString::isNotEmpty);

										TArray<CDictionary>	infos =
																	*CJSON::arrayOfDictionariesFrom(
																			*resultsRow.getBlob(mInfoTableColumn));

										TNArray<CacheValueInfo>	cacheValueInfos;
										for (TIteratorD<CDictionary> iterator = infos.getIterator();
												iterator.hasValue(); iterator.advance())
											// Add Cache Value Info
											cacheValueInfos += CacheValueInfo(*iterator);

										// Set current info
										cacheInfo->setValue(
												CacheInfo(*resultsRow.getText(mTypeTableColumn),
														relevantProperties, cacheValueInfos,
														*resultsRow.getUInt32(mLastRevisionTableColumn)));

										return OV<SError>();
									}

	private:
		static	CSQLiteTableColumn	mNameTableColumn;
		static	CSQLiteTableColumn	mTypeTableColumn;
		static	CSQLiteTableColumn	mRelevantPropertiesTableColumn;
		static	CSQLiteTableColumn	mInfoTableColumn;
		static	CSQLiteTableColumn	mLastRevisionTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CCachesTable::mNameTableColumn(CString(OSSTR("name")), CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kOptionsNotNull | CSQLiteTableColumn::kOptionsUnique));
CSQLiteTableColumn	CCachesTable::mTypeTableColumn(CString(OSSTR("type")), CSQLiteTableColumn::kKindText,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCachesTable::mRelevantPropertiesTableColumn(CString(OSSTR("relevantProperties")),
							CSQLiteTableColumn::kKindText, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCachesTable::mInfoTableColumn(CString(OSSTR("info")), CSQLiteTableColumn::kKindBlob,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCachesTable::mLastRevisionTableColumn(CString(OSSTR("lastRevision")),
							CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCachesTable::mTableColumns[] =
							{mNameTableColumn, mTypeTableColumn, mRelevantPropertiesTableColumn, mInfoTableColumn,
									mLastRevisionTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CCacheContentsTable

class CCacheContentsTable {
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const CString& name,
										const CacheValueInfos& cacheValueInfos, CSQLiteTable& internalsTable)
									{
										// Setup
										TNArray<CSQLiteTableColumn>	tableColumns(mIDTableColumn);
										for (TIteratorD<CacheValueInfo> iterator = cacheValueInfos.getIterator();
												iterator.hasValue(); iterator.advance())
											// Add table column
											tableColumns +=
													CSQLiteTableColumn(iterator->getName(),
															CSQLiteTableColumn::kKindInteger,
															CSQLiteTableColumn::kOptionsNotNull);

										// Create table
										CSQLiteTable	table =
																database.getTable(CString(OSSTR("Cache-")) + name,
																		CSQLiteTable::kOptionsWithoutRowID,
																		tableColumns);

										// Check if need to create
										OV<UInt32>	version = CInternalsTable::getVersion(table, internalsTable);
										if (!version.hasValue()) {
											// Create
											table.create();

											// Store version
											CInternalsTable::set(1, table, internalsTable);
										}

										return table;
									}
		static	void			update(const CMDSSQLiteDatabaseManager::ValueInfoByID& valueInfoByID,
										const IDArray& removedIDs, CSQLiteTable& table)
									{
										// Update
										if (!removedIDs.isEmpty())
											// Remove IDs
											table.deleteRows(mIDTableColumn, SSQLiteValue::valuesFrom(removedIDs));

										TSet<CString>	keys = valueInfoByID.getKeys();
										for (TIteratorS<CString> keyIterator = keys.getIterator();
												keyIterator.hasValue(); keyIterator.advance()) {
											// Setup
													SInt64			id = keyIterator->getSInt64();
											const	CDictionary&	valueInfo = *valueInfoByID[id];

											// Compose table columns
											TNArray<TableColumnAndValue>	tableColumnAndValues;
											tableColumnAndValues += TableColumnAndValue(mIDTableColumn, id);

											TSet<CString>	valueInfoKeys = valueInfo.getKeys();
											for (TIteratorS<CString> valueInfoKeyIterator = valueInfoKeys.getIterator();
													valueInfoKeyIterator.hasValue(); valueInfoKeyIterator.advance())
												// Setup
												tableColumnAndValues +=
														TableColumnAndValue(table.getTableColumn(*valueInfoKeyIterator),
																*valueInfo[*valueInfoKeyIterator]);

											// Insert or replace row for this id
											table.insertOrReplaceRow(tableColumnAndValues);
										}
									}

	public:
		static	CSQLiteTableColumn	mIDTableColumn;
};

CSQLiteTableColumn	CCacheContentsTable::mIDTableColumn(CString(OSSTR("id")), CSQLiteTableColumn::kKindInteger,
							CSQLiteTableColumn::kOptionsPrimaryKey);

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CCollectionsTable

class CCollectionsTable {
	// Methods
	public:
		static	CSQLiteTable				in(CSQLiteDatabase& database, CSQLiteTable& internalsTable,
													CSQLiteTable& infoTable)
												{
													// Create table
													CSQLiteTable	table =
																			database.getTable(
																					CString(OSSTR("Collections")),
																					TSArray<CSQLiteTableColumn>(
																							mTableColumns, 6));

													// Check if need to create/migrate
													OV<UInt32>	version =
																		CInternalsTable::getVersion(table,
																				internalsTable);
													if (!version.hasValue())
														version =
																CInfoTable::getUInt32(CString(OSSTR("version")),
																		infoTable);

													if (!version.hasValue()) {
														// Create
														table.create();

														// Store version
														CInternalsTable::set(2, table, internalsTable);
													} else if (*version == 1) {
														// Migrate to version 2
														table.migrate((CSQLiteTable::ResultsRowMigrationProc) migrate);

														// Store version
														CInternalsTable::set(2, table, internalsTable);
													}

													return table;
												}
		static	OV<CollectionInfo>			getInfo(const CString& name, CSQLiteTable& table)
												{
													// Query
													CSQLiteTableColumn	tableColumns[] =
																				{ mTypeTableColumn,
																						mRelevantPropertiesTableColumn,
																						mIsIncludedSelectorTableColumn,
																						mIsIncludedSelectorInfoTableColumn,
																						mLastRevisionTableColumn };
													OV<CollectionInfo>	collectionInfo;
													table.select(TSARRAY_FROM_C_ARRAY(CSQLiteTableColumn, tableColumns),
															CSQLiteWhere(mNameTableColumn, SSQLiteValue(name)),
															(CSQLiteResultsRow::Proc) processCollectionInfoResultsRow,
															&collectionInfo);

													return collectionInfo;
												}
		static	void						addOrUpdate(const CString& name, const CString& documentType,
													const TArray<CString>& relevantProperties,
													const CString& isIncludedSelector,
													const CDictionary& isIncludedSelectorInfo, UInt32 lastRevision,
													CSQLiteTable& table)
												{
													// Insert or replace
													TableColumnAndValue	tableColumnAndValues[] =
																				{
																					TableColumnAndValue(
																							mNameTableColumn, name),
																					TableColumnAndValue(
																							mTypeTableColumn,
																							documentType),
																					TableColumnAndValue(
																							mRelevantPropertiesTableColumn,
																							CString(relevantProperties,
																									CString::mComma)),
																					TableColumnAndValue(
																							mIsIncludedSelectorTableColumn,
																							isIncludedSelector),
																					TableColumnAndValue(
																							mIsIncludedSelectorInfoTableColumn,
																							*CJSON::dataFrom(
																									isIncludedSelectorInfo)),
																					TableColumnAndValue(
																							mLastRevisionTableColumn,
																							lastRevision),
																				};
													table.insertOrReplaceRow(
															TSARRAY_FROM_C_ARRAY(TableColumnAndValue,
																	tableColumnAndValues));
												}
		static	void						update(const CString& name, UInt32 lastRevision, CSQLiteTable& table)
												{ table.update(
														TableColumnAndValue(mLastRevisionTableColumn, lastRevision),
														CSQLiteWhere(mNameTableColumn, SSQLiteValue(name))); }

		static	OV<SError>					processCollectionInfoResultsRow(const CSQLiteResultsRow& resultsRow,
													OV<CollectionInfo>* collectionInfo)
												{
													// Setup
													TNArray<CString>	relevantProperties =
																				resultsRow.getText(
																								mRelevantPropertiesTableColumn)->
																						components(CString::mComma);
													relevantProperties =
															relevantProperties.filtered(CString::isNotEmpty);

													// Process results
													collectionInfo->setValue(
															CollectionInfo(*resultsRow.getText(mTypeTableColumn),
																	relevantProperties,
																	*resultsRow.getText(
																			mIsIncludedSelectorTableColumn),
																	*CJSON::dictionaryFrom(
																			*resultsRow.getBlob(
																					mIsIncludedSelectorInfoTableColumn)),
																	*resultsRow.getUInt32(
																			mLastRevisionTableColumn)));

													return OV<SError>();
												}

	private:
		static	TableColumnAndValuesResult	migrate(const CSQLiteResultsRow& resultsRow, void* userData)
												{
													// Setup
													CString	name = *resultsRow.getText(mNameTableColumn);
													UInt32	version = *resultsRow.getUInt32(mVersionTableColumn);
													UInt32	lastRevision =
																	*resultsRow.getUInt32(mLastRevisionTableColumn);

													CDictionary	isIncludedSelectorInfo;
													isIncludedSelectorInfo.set(mVersionTableColumn.getName(), version);

													TNArray<TableColumnAndValue>	tableColumnAndValues;
													tableColumnAndValues += TableColumnAndValue(mNameTableColumn, name);
													tableColumnAndValues +=
															TableColumnAndValue(mTypeTableColumn, CString::mEmpty);
													tableColumnAndValues +=
															TableColumnAndValue(mRelevantPropertiesTableColumn,
																	CString::mEmpty);
													tableColumnAndValues +=
															TableColumnAndValue(mIsIncludedSelectorTableColumn,
																	CString::mEmpty);
													tableColumnAndValues +=
															TableColumnAndValue(
																	mIsIncludedSelectorInfoTableColumn,
																	*CJSON::dataFrom(isIncludedSelectorInfo));
													tableColumnAndValues +=
															TableColumnAndValue(mLastRevisionTableColumn, lastRevision);

													return TableColumnAndValuesResult(tableColumnAndValues);
												}

	// Properties
	private:
		static	CSQLiteTableColumn	mNameTableColumn;
		static	CSQLiteTableColumn	mTypeTableColumn;
		static	CSQLiteTableColumn	mRelevantPropertiesTableColumn;
		static	CSQLiteTableColumn	mIsIncludedSelectorTableColumn;
		static	CSQLiteTableColumn	mIsIncludedSelectorInfoTableColumn;
		static	CSQLiteTableColumn	mLastRevisionTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];

		static	CSQLiteTableColumn	mVersionTableColumn;
};

CSQLiteTableColumn	CCollectionsTable::mNameTableColumn(CString(OSSTR("name")), CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kOptionsNotNull | CSQLiteTableColumn::kOptionsUnique));
CSQLiteTableColumn	CCollectionsTable::mTypeTableColumn(CString(OSSTR("type")), CSQLiteTableColumn::kKindText,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCollectionsTable::mRelevantPropertiesTableColumn(CString(OSSTR("relevantProperties")),
							CSQLiteTableColumn::kKindText, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCollectionsTable::mIsIncludedSelectorTableColumn(CString(OSSTR("isIncludedSelector")),
							CSQLiteTableColumn::kKindText, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCollectionsTable::mIsIncludedSelectorInfoTableColumn(CString(OSSTR("isIncludedSelectorInfo")),
							CSQLiteTableColumn::kKindBlob, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCollectionsTable::mLastRevisionTableColumn(CString(OSSTR("lastRevision")),
							CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CCollectionsTable::mTableColumns[] =
							{mNameTableColumn, mTypeTableColumn, mRelevantPropertiesTableColumn,
									mIsIncludedSelectorTableColumn, mIsIncludedSelectorInfoTableColumn,
									mLastRevisionTableColumn};

CSQLiteTableColumn	CCollectionsTable::mVersionTableColumn(CString(OSSTR("version")), CSQLiteTableColumn::kKindInteger,
							CSQLiteTableColumn::kOptionsNotNull);

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CCollectionContentsTable

class CCollectionContentsTable {
	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const CString& name, CSQLiteTable& internalsTable)
									{
										// Setup
										CSQLiteTable	table =
																database.getTable(CString(OSSTR("Collection-")) + name,
																		CSQLiteTable::kOptionsWithoutRowID,
																		TSArray<CSQLiteTableColumn>(mTableColumns, 1));

										// Check if need to create
										if (!CInternalsTable::getVersion(table, internalsTable).hasValue()) {
											// Create
											table.create();

											// Store version
											CInternalsTable::set(1, table, internalsTable);
										}

										return table;
									}
		static	void			update(const IDArray& includedIDs, const IDArray& notIncludedIDs, CSQLiteTable& table)
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
	public:
		static	CSQLiteTableColumn	mIDTableColumn;

	private:
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CCollectionContentsTable::mIDTableColumn(CString(OSSTR("id")), CSQLiteTableColumn::kKindInteger,
							CSQLiteTableColumn::kOptionsPrimaryKey);
CSQLiteTableColumn	CCollectionContentsTable::mTableColumns[] = {mIDTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CDocumentsTable

class CDocumentsTable {
	public:
		struct Info {
			public:
										Info(const CString& documentType, UInt32 lastRevision) :
											mDocumentType(documentType), mLastRevision(lastRevision)
											{}
										Info(const CSQLiteResultsRow& resultsRow) :
											mDocumentType(*resultsRow.getText(mTypeTableColumn)),
													mLastRevision(*resultsRow.getUInt32(mLastRevisionTableColumn))
											{}
										Info(const Info& other) :
											mDocumentType(other.mDocumentType), mLastRevision(other.mLastRevision)
											{}

					const	CString&	getDocumentType() const
											{ return mDocumentType; }
							UInt32		getLastRevision() const
											{ return mLastRevision; }

			private:
				CString	mDocumentType;
				UInt32	mLastRevision;
		};

	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, CSQLiteTable& internalsTable)
									{
										// Create table
										CSQLiteTable	table =
																database.getTable(CString(OSSTR("Documents")),
																		TSArray<CSQLiteTableColumn>(mTableColumns, 2));

										// Check if need to create
										OV<UInt32>	version = CInternalsTable::getVersion(table, internalsTable);
										if (!version.hasValue()) {
											// Create
											table.create();

											// Store version
											CInternalsTable::set(1, table, internalsTable);
										}

										return table;
									}
		static	void			set(UInt32 lastRevision, const CString& documentType, CSQLiteTable& table)
									{
										// Setup
										TNArray<TableColumnAndValue>	tableColumnAndValues;
										tableColumnAndValues += TableColumnAndValue(mTypeTableColumn, documentType);
										tableColumnAndValues +=
												TableColumnAndValue(mLastRevisionTableColumn, lastRevision);

										// Insert or replace row
										table.insertOrReplaceRow(tableColumnAndValues);
									}

	private:
		static	CSQLiteTableColumn	mTypeTableColumn;
		static	CSQLiteTableColumn	mLastRevisionTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CDocumentsTable::mTypeTableColumn(CString(OSSTR("type")), CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options) (CSQLiteTableColumn::kOptionsNotNull | CSQLiteTableColumn::kOptionsUnique));
CSQLiteTableColumn	CDocumentsTable::mLastRevisionTableColumn(CString(OSSTR("lastRevision")),
							CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CDocumentsTable::mTableColumns[] = {mTypeTableColumn, mLastRevisionTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CDocumentTypeInfoTable

class CDocumentTypeInfoTable {
	// Types
	public:
		typedef	TNKeyConvertibleDictionary<SInt64, CString>					DocumentIDByID;
		typedef	TNKeyConvertibleDictionary<SInt64, DocumentRevisionInfo>	DocumentRevisionInfoByIDInfo;
		typedef	CMDSSQLiteDatabaseManager::DocumentInfo						DocumentInfo;

	private:
		struct SIDResult {
			public:
											SIDResult() {}

						const	OV<SInt64>	getValue() const
												{ return mValue; }

				static			OV<SError>	process(const CSQLiteResultsRow& resultsRow, SIDResult* idResult)
												{
													// Store value
													idResult->mValue = resultsRow.getInteger(mIDTableColumn);

													return OV<SError>();
												}

			private:
				OV<SInt64>	mValue;
		};

		struct SIDByDocumentIDResult {
			public:
												SIDByDocumentIDResult() {}

						const	CDictionary&	getValue() const
													{ return mValue; }

				static			OV<SError>		process(const CSQLiteResultsRow& resultsRow,
														SIDByDocumentIDResult* idByDocumentIDResult)
													{
														// Update map
														idByDocumentIDResult->mValue.set(
																*resultsRow.getText(mDocumentIDTableColumn),
																*resultsRow.getInteger(mIDTableColumn));

														return OV<SError>();
													}

			private:
				CDictionary	mValue;
		};

		struct SDocumentIDByIDResult {
			public:
												SDocumentIDByIDResult() {}

						const	DocumentIDByID&	getValue() const
													{ return mValue; }

				static			OV<SError>		process(const CSQLiteResultsRow& resultsRow,
														SDocumentIDByIDResult* documentIDByIDResult)
													{
														// Update map
														documentIDByIDResult->mValue.set(
																*resultsRow.getInteger(mIDTableColumn),
																*resultsRow.getText(mDocumentIDTableColumn));

														return OV<SError>();
													}

			private:
				DocumentIDByID	mValue;
		};

		struct SDocumentRevisionInfoByIDInfoResult {
			public:
																SDocumentRevisionInfoByIDInfoResult() {}

						const	DocumentRevisionInfoByIDInfo&	getValue() const
																	{ return mValue; }

				static			OV<SError>						process(const CSQLiteResultsRow& resultsRow,
																		SDocumentRevisionInfoByIDInfoResult*
																				documentRevisionInfoByIDInfoResult)
																	{
																		// Update map
																		documentRevisionInfoByIDInfoResult->mValue.set(
																				*resultsRow.getInteger(mIDTableColumn),
																				DocumentRevisionInfo(
																						*resultsRow.getText(
																								mDocumentIDTableColumn),
																						*resultsRow.getUInt32(
																								mRevisionTableColumn)));

																		return OV<SError>();
																	}

			private:
				DocumentRevisionInfoByIDInfo	mValue;
		};

	public:
		static	TArray<CSQLiteTableColumn>		tableColumns()
													{ return TSArray<CSQLiteTableColumn>(mTableColumns, 4); }
		static	CSQLiteTable					in(CSQLiteDatabase& database, const CString& nameRoot,
														CSQLiteTable& internalsTable)
													{
														// Create table
														CSQLiteTable	table =
																				database.getTable(
																						nameRoot + CString(OSSTR("s")),
																						tableColumns());

														// Check if need to create
														OV<UInt32>	version =
																			CInternalsTable::getVersion(table,
																					internalsTable);
														if (!version.hasValue()) {
															// Create
															table.create();

															// Store version
															CInternalsTable::set(1, table, internalsTable);
														}

														return table;
													}
		static	OV<SInt64>						getID(const CString& documentID, const CSQLiteTable& table)
													{
														// Retrieve id
														SIDResult	idResult;
														table.select(
																TSArray<CSQLiteTableColumn>(mIDTableColumn),
																CSQLiteWhere(mDocumentIDTableColumn,
																		SSQLiteValue(documentID)),
																		(CSQLiteResultsRow::Proc) SIDResult::process,
																		&idResult);

														return idResult.getValue();
													}
		static	CDictionary						getIDByDocumentID(const TNArray<CString>& documentIDs,
														const CSQLiteTable& table)
													{
														// Retrieve id map
														SIDByDocumentIDResult	idByDocumentIDResult;
														table.select(
																TSArray<CSQLiteTableColumn>(mIDDocumentIDTableColumns,
																		2),
																CSQLiteWhere(mDocumentIDTableColumn,
																		SSQLiteValue::valuesFrom(documentIDs)),
																(CSQLiteResultsRow::Proc)
																		SIDByDocumentIDResult::process,
																&idByDocumentIDResult);

														return idByDocumentIDResult.getValue();
													}
		static	DocumentIDByID					getDocumentIDByID(const IDArray& ids, const CSQLiteTable& table)
													{
														// Retrieve documentID map
														SDocumentIDByIDResult	documentIDByIDResult;
														table.select(
																TSArray<CSQLiteTableColumn>(mIDDocumentIDTableColumns,
																		2),
																CSQLiteWhere(mIDTableColumn,
																		SSQLiteValue::valuesFrom(ids)),
																(CSQLiteResultsRow::Proc)
																		SDocumentIDByIDResult::process,
																&documentIDByIDResult);

														return documentIDByIDResult.getValue();
													}
		static	DocumentIDByID					getDocumentIDByID(const TArray<CString>& documentIDs,
														const CSQLiteTable& table)
													{
														// Retrieve documentID map
														SDocumentIDByIDResult	documentIDByIDResult;
														table.select(
																TSArray<CSQLiteTableColumn>(mIDDocumentIDTableColumns,
																		2),
																CSQLiteWhere(mDocumentIDTableColumn,
																		SSQLiteValue::valuesFrom(documentIDs)),
																(CSQLiteResultsRow::Proc)
																		SDocumentIDByIDResult::process,
																&documentIDByIDResult);

														return documentIDByIDResult.getValue();
													}
		static	DocumentRevisionInfoByIDInfo	getDocumentRevisionInfoByIDInfo(const IDArray& ids,
														const CSQLiteTable& table)
													{
														// Retrieve document revision map
														SDocumentRevisionInfoByIDInfoResult
																documentRevisionInfoByIDInfoResult;
														table.select(
																TSArray<CSQLiteTableColumn>(
																		mIDDocumentIDRevisionTableColumns, 3),
																CSQLiteWhere(mIDTableColumn,
																		SSQLiteValue::valuesFrom(ids)),
																(CSQLiteResultsRow::Proc)
																		SDocumentIDByIDResult::process,
																&documentRevisionInfoByIDInfoResult);

														return documentRevisionInfoByIDInfoResult.getValue();
													}
		static	DocumentInfo					getDocumentInfo(const CSQLiteResultsRow& resultsRow)
													{ return DocumentInfo(*resultsRow.getInteger(mIDTableColumn),
															*resultsRow.getText(mDocumentIDTableColumn),
															*resultsRow.getUInt32(mRevisionTableColumn),
															*resultsRow.getUInt32(mActiveTableColumn) == 1); }
		static	SInt64							add(const CString& documentID, UInt32 revision, CSQLiteTable& table)
													{
														// Insert
														TNArray<TableColumnAndValue>	tableColumnAndValues;
														tableColumnAndValues +=
																TableColumnAndValue(mDocumentIDTableColumn, documentID);
														tableColumnAndValues +=
																TableColumnAndValue(mRevisionTableColumn, revision);
														tableColumnAndValues +=
																TableColumnAndValue(mActiveTableColumn, (UInt32) 1);

														return table.insertRow(tableColumnAndValues);
													}
		static	void							update(SInt64 id, UInt32 revision, CSQLiteTable& table)
													{ table.update(TableColumnAndValue(mRevisionTableColumn, revision),
																CSQLiteWhere(mIDTableColumn, SSQLiteValue(id))); }
		static	void							remove(SInt64 id, CSQLiteTable& table)
													{ table.update(TableColumnAndValue(mActiveTableColumn, (UInt32) 0),
																CSQLiteWhere(mIDTableColumn, SSQLiteValue(id))); }

		static	OV<SError>						callDocumentInfoProcInfo(const CSQLiteResultsRow& resultsRow,
														DocumentInfo::ProcInfo* documentInfoProcInfo)
													{ return documentInfoProcInfo->call(getDocumentInfo(resultsRow)); }

	public:
		static	const	CSQLiteTableColumn	mIDTableColumn;
		static	const	CSQLiteTableColumn	mDocumentIDTableColumn;
		static	const	CSQLiteTableColumn	mRevisionTableColumn;
		static	const	CSQLiteTableColumn	mActiveTableColumn;
		static	const	CSQLiteTableColumn	mTableColumns[];

	private:
		static	const	CSQLiteTableColumn	mIDDocumentIDTableColumns[];
		static	const	CSQLiteTableColumn	mIDDocumentIDRevisionTableColumns[];
};

const	CSQLiteTableColumn	CDocumentTypeInfoTable::mIDTableColumn(CString(OSSTR("id")),
									CSQLiteTableColumn::kKindInteger,
									(CSQLiteTableColumn::Options)
											(CSQLiteTableColumn::kOptionsPrimaryKey |
													CSQLiteTableColumn::kOptionsAutoIncrement));
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mDocumentIDTableColumn(CString(OSSTR("documentID")),
									CSQLiteTableColumn::kKindText,
											(CSQLiteTableColumn::Options)
													(CSQLiteTableColumn::kOptionsNotNull |
															CSQLiteTableColumn::kOptionsUnique));
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mRevisionTableColumn(CString(OSSTR("revision")),
									CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsNotNull);
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mActiveTableColumn(CString(OSSTR("active")),
									CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsNotNull);
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mTableColumns[] =
									{mIDTableColumn, mDocumentIDTableColumn, mRevisionTableColumn,
											mActiveTableColumn};
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mIDDocumentIDTableColumns[] =
									{mIDTableColumn, mDocumentIDTableColumn};
const	CSQLiteTableColumn	CDocumentTypeInfoTable::mIDDocumentIDRevisionTableColumns[] =
									{mIDTableColumn, mDocumentIDTableColumn, mRevisionTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CDocumentTypeContentsTable

class CDocumentTypeContentsTable {
	// Types
	public:
		typedef	CMDSSQLiteDatabaseManager::DocumentContentInfo	DocumentContentInfo;

	public:
		static	CSQLiteTable		in(CSQLiteDatabase& database, const CString& nameRoot,
											const CSQLiteTable& infoTable, CSQLiteTable& internalsTable)
										{
											// Create table
											CSQLiteTableColumn::Reference	tableColumnReference(mIDTableColumn,
																					infoTable,
																					CDocumentTypeInfoTable::
																							mIDTableColumn);
											CSQLiteTable					table =
																					database.getTable(
																							nameRoot +
																									CString(OSSTR("Contents")),
																							TSArray<CSQLiteTableColumn>(
																									mTableColumns, 4),
																							TNArray<CSQLiteTableColumn::
																											Reference>(
																									tableColumnReference));

											// Check if need to create
											OV<UInt32>	version =
																CInternalsTable::getVersion(table,
																		internalsTable);
											if (!version.hasValue()) {
												// Create
												table.create();

												// Store version
												CInternalsTable::set(1, table, internalsTable);
											}

											return table;
										}
		static	DocumentContentInfo	getDocumentContentInfo(const CSQLiteResultsRow& resultsRow)
										{ return DocumentContentInfo(*resultsRow.getInteger(mIDTableColumn),
												*SGregorianDate::getFrom(*resultsRow.getText(mCreationDateTableColumn)),
												*SGregorianDate::getFrom(
														*resultsRow.getText(mModificationDateTableColumn)),
												*CJSON::dictionaryFrom(*resultsRow.getBlob(mJSONTableColumn))); }
		static	void				add(SInt64 id, UniversalTime creationUniversalTime,
											UniversalTime modificationUniversalTime, const CDictionary& propertyMap,
											CSQLiteTable& table)
										{
											// Insert
											TNArray<TableColumnAndValue>	tableColumnAndValues;
											tableColumnAndValues += TableColumnAndValue(mIDTableColumn, id);
											tableColumnAndValues +=
													TableColumnAndValue(mCreationDateTableColumn,
															SGregorianDate(creationUniversalTime).getString());
											tableColumnAndValues +=
													TableColumnAndValue(mModificationDateTableColumn,
															SGregorianDate(modificationUniversalTime).getString());
											tableColumnAndValues +=
													TableColumnAndValue(mJSONTableColumn,
															*CJSON::dataFrom(propertyMap));

											table.insertRow(tableColumnAndValues);
										}
		static	void				update(SInt64 id, UniversalTime modificationUniversalTime,
											const CDictionary& propertyMap, CSQLiteTable& table)
										{
											// Update
											TNArray<TableColumnAndValue>	tableColumnAndValues;
											tableColumnAndValues +=
													TableColumnAndValue(mModificationDateTableColumn,
															SGregorianDate(modificationUniversalTime).getString());
											tableColumnAndValues +=
													TableColumnAndValue(mJSONTableColumn,
															*CJSON::dataFrom(propertyMap));

											table.update(tableColumnAndValues,
													CSQLiteWhere(mIDTableColumn, SSQLiteValue(id)));
										}
		static	void				update(SInt64 id, UniversalTime modificationUniversalTime, CSQLiteTable& table)
										{
											// Update
											TNArray<TableColumnAndValue>	tableColumnAndValues;
											tableColumnAndValues +=
													TableColumnAndValue(mModificationDateTableColumn,
															SGregorianDate(modificationUniversalTime).getString());

											table.update(tableColumnAndValues,
													CSQLiteWhere(mIDTableColumn, SSQLiteValue(id)));
										}
		static	void				remove(SInt64 id, CSQLiteTable& table)
										{
											// Update
											TNArray<TableColumnAndValue>	tableColumnAndValues;
											tableColumnAndValues +=
													TableColumnAndValue(mModificationDateTableColumn,
															SGregorianDate().getString());
											tableColumnAndValues +=
													TableColumnAndValue(mJSONTableColumn,
															*CJSON::dataFrom(CDictionary()));

											table.update(tableColumnAndValues,
													CSQLiteWhere(mIDTableColumn, SSQLiteValue(id)));
										}

		static	OV<SError>			callDocumentContentInfoProcInfo(const CSQLiteResultsRow& resultsRow,
											DocumentContentInfo::ProcInfo* documentContentInfoProcInfo)
										{ return documentContentInfoProcInfo->call(getDocumentContentInfo(
												resultsRow)); }

	private:
		static	CSQLiteTableColumn	mIDTableColumn;
		static	CSQLiteTableColumn	mCreationDateTableColumn;
		static	CSQLiteTableColumn	mModificationDateTableColumn;
		static	CSQLiteTableColumn	mJSONTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CDocumentTypeContentsTable::mIDTableColumn(CString(OSSTR("id")), CSQLiteTableColumn::kKindInteger,
							CSQLiteTableColumn::kOptionsPrimaryKey);
CSQLiteTableColumn	CDocumentTypeContentsTable::mCreationDateTableColumn(CString(OSSTR("creationDate")),
							CSQLiteTableColumn::kKindText, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CDocumentTypeContentsTable::mModificationDateTableColumn(CString(OSSTR("modificationDate")),
							CSQLiteTableColumn::kKindText, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CDocumentTypeContentsTable::mJSONTableColumn(CString(OSSTR("json")), CSQLiteTableColumn::kKindBlob,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CDocumentTypeContentsTable::mTableColumns[] =
							{mIDTableColumn, mCreationDateTableColumn, mModificationDateTableColumn,
									mJSONTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CDocumentTypeAttachmentsTable

class CDocumentTypeAttachmentsTable {
	public:
	public:
		static	CSQLiteTable				in(CSQLiteDatabase& database, const CString& nameRoot,
													const CSQLiteTable& infoTable, CSQLiteTable& internalsTable)
												{
													// Create table
													CSQLiteTable	table =
																			database.getTable(
																					nameRoot +
																							CString(OSSTR("Attachments")),
																					TSArray<CSQLiteTableColumn>(
																							mTableColumns, 5));

													// Check if need to create
													OV<UInt32>	version =
																		CInternalsTable::getVersion(table,
																				internalsTable);
													if (!version.hasValue()) {
														// Create
														table.create();

														// Store version
														CInternalsTable::set(1, table, internalsTable);
													}

													return table;
												}
		static	UInt32						add(SInt64 id, const CString& attachmentID, const CDictionary& info,
													const CData& content, CSQLiteTable& table)
												{
													// Insert
													TNArray<TableColumnAndValue>	tableColumnAndValues;
													tableColumnAndValues += TableColumnAndValue(mIDTableColumn, id);
													tableColumnAndValues +=
															TableColumnAndValue(mAttachmentIDTableColumn, attachmentID);
													tableColumnAndValues +=
															TableColumnAndValue(mRevisionTableColumn, (UInt32) 1);
													tableColumnAndValues +=
															TableColumnAndValue(mInfoTableColumn,
																	*CJSON::dataFrom(info));
													tableColumnAndValues +=
															TableColumnAndValue(mContentTableColumn, content);

													table.insertRow(tableColumnAndValues);

													return 1;
												}
		static	DocumentAttachmentInfoByID	getDocumentAttachmentInfoByID(SInt64 id, const CSQLiteTable& table)
												{
													// Setup
													TNDictionary<CMDSDocument::AttachmentInfo>
															documentAttachmentInfoByID;

													// Get info
													CSQLiteTableColumn	tableColumns[] =
																				{ mAttachmentIDTableColumn,
																						mRevisionTableColumn,
																						mInfoTableColumn };
													table.select(TSARRAY_FROM_C_ARRAY(CSQLiteTableColumn, tableColumns),
															CSQLiteWhere(mIDTableColumn, SSQLiteValue(id)),
															(CSQLiteResultsRow::Proc) updateDocumentAttachmentInfoByID,
															&documentAttachmentInfoByID);

													return documentAttachmentInfoByID;
												}
		static	OV<SError>					getContent(const CSQLiteResultsRow& resultsRow, OV<CData>* data)
												{ data->setValue(*resultsRow.getBlob(mContentTableColumn));
														return OV<SError>(); }
		static	UInt32						update(SInt64 id, const CString& attachmentID,
													const CDictionary& updatedInfo, const CData& updatedContent,
													CSQLiteTable& table)
												{
													// Setup
													CSQLiteWhere	where(mAttachmentIDTableColumn,
																			SSQLiteValue(attachmentID));

													// Get current revision
													UInt32	revision;
													table.select(TSArray<CSQLiteTableColumn>(mRevisionTableColumn),
															where, (CSQLiteResultsRow::Proc) getRevision, &revision);

													// Update
													TNArray<TableColumnAndValue>	tableColumnAndValues;
													tableColumnAndValues +=
															TableColumnAndValue(mRevisionTableColumn, revision + 1);
													tableColumnAndValues +=
															TableColumnAndValue(mInfoTableColumn,
																	*CJSON::dataFrom(updatedInfo));
													tableColumnAndValues +=
															TableColumnAndValue(mContentTableColumn, updatedContent);

													table.update(tableColumnAndValues, where);

													return revision + 1;
												}
		static	void						remove(SInt64 id, const CString& attachmentID, CSQLiteTable& table)
												{ table.deleteRows(mAttachmentIDTableColumn,
														SSQLiteValue(attachmentID)); }
		static	void						remove(SInt64 id, CSQLiteTable& table)
												{ table.deleteRows(mIDTableColumn, SSQLiteValue(id)); }

	private:
		static	OV<SError>					updateDocumentAttachmentInfoByID(const CSQLiteResultsRow& resultsRow,
													TNDictionary<CMDSDocument::AttachmentInfo>*
															documentAttachmentInfoByID)
												{
													// Setup
													CString	attachmentID =
																	*resultsRow.getText(mAttachmentIDTableColumn);

													// Process values
													documentAttachmentInfoByID->set(attachmentID,
															CMDSDocument::AttachmentInfo(attachmentID,
																	*resultsRow.getUInt32(mRevisionTableColumn),
																	*CJSON::dictionaryFrom(
																			*resultsRow.getBlob(mInfoTableColumn))));

													return OV<SError>();
												}
		static	OV<SError>					getRevision(const CSQLiteResultsRow& resultsRow, UInt32* revision)
												{
													// Process values
													*revision = *resultsRow.getUInt32(mRevisionTableColumn);

													return OV<SError>();
												}

	public:
		static	CSQLiteTableColumn	mAttachmentIDTableColumn;
		static	CSQLiteTableColumn	mContentTableColumn;

	private:
		static	CSQLiteTableColumn	mIDTableColumn;
		static	CSQLiteTableColumn	mRevisionTableColumn;
		static	CSQLiteTableColumn	mInfoTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CDocumentTypeAttachmentsTable::mIDTableColumn(CString(OSSTR("id")),
							CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsPrimaryKey);
CSQLiteTableColumn	CDocumentTypeAttachmentsTable::mAttachmentIDTableColumn(CString(OSSTR("attachmentID")),
							CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kOptionsNotNull | CSQLiteTableColumn::kOptionsUnique));
CSQLiteTableColumn	CDocumentTypeAttachmentsTable::mRevisionTableColumn(CString(OSSTR("revision")),
							CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CDocumentTypeAttachmentsTable::mInfoTableColumn(CString(OSSTR("info")),
							CSQLiteTableColumn::kKindBlob, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CDocumentTypeAttachmentsTable::mContentTableColumn(CString(OSSTR("content")),
							CSQLiteTableColumn::kKindBlob, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CDocumentTypeAttachmentsTable::mTableColumns[] =
							{mIDTableColumn, mAttachmentIDTableColumn, mRevisionTableColumn, mInfoTableColumn,
									mContentTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CIndexesTable

class CIndexesTable {
	// Methods
	public:
		static	CSQLiteTable				in(CSQLiteDatabase& database, CSQLiteTable& internalsTable,
													CSQLiteTable& infoTable)
												{
													// Create table
													CSQLiteTable	table =
																			database.getTable(
																					CString(OSSTR("Indexes")),
																					TSArray<CSQLiteTableColumn>(
																							mTableColumns, 6));

													// Check if need to create/migrate
													OV<UInt32>	version =
																		CInternalsTable::getVersion(table,
																				internalsTable);
													if (!version.hasValue())
														version =
																CInfoTable::getUInt32(CString(OSSTR("version")),
																		infoTable);

													if (!version.hasValue()) {
														// Create
														table.create();

														// Store version
														CInternalsTable::set(2, table, internalsTable);
													} else if (*version == 1) {
														// Migrate to version 2
														table.migrate((CSQLiteTable::ResultsRowMigrationProc) migrate);

														// Store version
														CInternalsTable::set(2, table, internalsTable);
													}

													return table;
												}
		static	OV<IndexInfo>				getInfo(const CString& name, CSQLiteTable& table)
												{
													// Query
													CSQLiteTableColumn	tableColumns[] =
																				{ mTypeTableColumn,
																						mRelevantPropertiesTableColumn,
																						mKeysSelectorTableColumn,
																						mKeysSelectorInfoTableColumn,
																						mLastRevisionTableColumn };
													OV<IndexInfo>		indexInfo;
													table.select(TSARRAY_FROM_C_ARRAY(CSQLiteTableColumn, tableColumns),
															CSQLiteWhere(mNameTableColumn, SSQLiteValue(name)),
															(CSQLiteResultsRow::Proc) processIndexInfoResultsRow,
															&indexInfo);

													return indexInfo;
												}
		static	void						addOrUpdate(const CString& name, const CString& documentType,
													const TArray<CString>& relevantProperties,
													const CString& keysSelector, const CDictionary& keysSelectorInfo,
													UInt32 lastRevision, CSQLiteTable& table)
												{
													// Insert or replace
													TableColumnAndValue	tableColumnAndValues[] =
																				{
																					TableColumnAndValue(
																							mNameTableColumn, name),
																					TableColumnAndValue(
																							mTypeTableColumn,
																							documentType),
																					TableColumnAndValue(
																							mRelevantPropertiesTableColumn,
																							CString(relevantProperties,
																									CString::mComma)),
																					TableColumnAndValue(
																							mKeysSelectorTableColumn,
																							keysSelector),
																					TableColumnAndValue(
																							mKeysSelectorInfoTableColumn,
																							*CJSON::dataFrom(
																									keysSelectorInfo)),
																					TableColumnAndValue(
																							mLastRevisionTableColumn,
																							lastRevision),
																				};
													table.insertOrReplaceRow(
															TSARRAY_FROM_C_ARRAY(TableColumnAndValue,
																	tableColumnAndValues));
												}
		static	void						update(const CString& name, UInt32 lastRevision, CSQLiteTable& table)
												{ table.update(
														TableColumnAndValue(mLastRevisionTableColumn, lastRevision),
														CSQLiteWhere(mNameTableColumn, SSQLiteValue(name))); }

				static			OV<SError>	processIndexInfoResultsRow(const CSQLiteResultsRow& resultsRow,
													OV<IndexInfo>* indexInfo)
												{
													// Setup
													TNArray<CString>	relevantProperties =
																				resultsRow.getText(
																								mRelevantPropertiesTableColumn)->
																						components(CString::mComma);
													relevantProperties =
															relevantProperties.filtered(CString::isNotEmpty);

													// Process results
													indexInfo->setValue(
															IndexInfo(*resultsRow.getText(mTypeTableColumn),
																	relevantProperties,
																	*resultsRow.getText(
																			mKeysSelectorTableColumn),
																	*CJSON::dictionaryFrom(
																			*resultsRow.getBlob(
																					mKeysSelectorInfoTableColumn)),
																	*resultsRow.getUInt32(
																			mLastRevisionTableColumn)));

													return OV<SError>();
												}

	private:
		static	TableColumnAndValuesResult	migrate(const CSQLiteResultsRow& resultsRow, void* userData)
												{
													// Setup
													CString	name = *resultsRow.getText(mNameTableColumn);
													UInt32	version = *resultsRow.getUInt32(mVersionTableColumn);
													UInt32	lastRevision =
																	*resultsRow.getUInt32(mLastRevisionTableColumn);

													CDictionary	keysSelectorInfo;
													keysSelectorInfo.set(mVersionTableColumn.getName(), version);

													TNArray<TableColumnAndValue>	tableColumnAndValues;
													tableColumnAndValues += TableColumnAndValue(mNameTableColumn, name);
													tableColumnAndValues +=
															TableColumnAndValue(mTypeTableColumn, CString::mEmpty);
													tableColumnAndValues +=
															TableColumnAndValue(mRelevantPropertiesTableColumn,
																	CString::mEmpty);
													tableColumnAndValues +=
															TableColumnAndValue(mKeysSelectorTableColumn,
																	CString::mEmpty);
													tableColumnAndValues +=
															TableColumnAndValue(
																	mKeysSelectorInfoTableColumn,
																	*CJSON::dataFrom(keysSelectorInfo));
													tableColumnAndValues +=
															TableColumnAndValue(mLastRevisionTableColumn, lastRevision);

													return TableColumnAndValuesResult(tableColumnAndValues);
												}

	// Properties
	private:
		static	CSQLiteTableColumn	mNameTableColumn;
		static	CSQLiteTableColumn	mTypeTableColumn;
		static	CSQLiteTableColumn	mRelevantPropertiesTableColumn;
		static	CSQLiteTableColumn	mKeysSelectorTableColumn;
		static	CSQLiteTableColumn	mKeysSelectorInfoTableColumn;
		static	CSQLiteTableColumn	mLastRevisionTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];

		static	CSQLiteTableColumn	mVersionTableColumn;
};

CSQLiteTableColumn	CIndexesTable::mNameTableColumn(CString(OSSTR("name")), CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kOptionsNotNull | CSQLiteTableColumn::kOptionsUnique));
CSQLiteTableColumn	CIndexesTable::mTypeTableColumn(CString(OSSTR("type")), CSQLiteTableColumn::kKindText,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CIndexesTable::mRelevantPropertiesTableColumn(CString(OSSTR("relevantProperties")),
							CSQLiteTableColumn::kKindText, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CIndexesTable::mKeysSelectorTableColumn(CString(OSSTR("keysSelector")),
							CSQLiteTableColumn::kKindText, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CIndexesTable::mKeysSelectorInfoTableColumn(CString(OSSTR("keysSelectorInfo")),
							CSQLiteTableColumn::kKindBlob, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CIndexesTable::mLastRevisionTableColumn(CString(OSSTR("lastRevision")),
							CSQLiteTableColumn::kKindInteger, CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CIndexesTable::mTableColumns[] =
							{mNameTableColumn, mTypeTableColumn, mRelevantPropertiesTableColumn,
									mKeysSelectorTableColumn, mKeysSelectorInfoTableColumn, mLastRevisionTableColumn};

CSQLiteTableColumn	CIndexesTable::mVersionTableColumn(CString(OSSTR("version")), CSQLiteTableColumn::kKindInteger,
							CSQLiteTableColumn::kOptionsNotNull);

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CIndexContentsTable

class CIndexContentsTable {
	// Types
	public:
		typedef	CMDSSQLiteDatabaseManager::DocumentInfo	DocumentInfo;

	// Methods
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database, const CString& name, CSQLiteTable& internalsTable)
									{
										// Setup
										CSQLiteTable	table =
																database.getTable(CString(OSSTR("Index-")) + name,
																		CSQLiteTable::kOptionsWithoutRowID,
																		TSArray<CSQLiteTableColumn>(mTableColumns, 2));

										// Check if need to create
										if (!CInternalsTable::getVersion(table, internalsTable).hasValue()) {
											// Create
											table.create();

											// Store version
											CInternalsTable::set(1, table, internalsTable);
										}

										return table;
									}
		static	CString			getKey(const CSQLiteResultsRow& resultsRow)
									{ return *resultsRow.getText(mKeyTableColumn); }

		static	void			update(const IDArray& includedIDs, const IDArray& notIncludedIDs, CSQLiteTable& table)
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

		static	void			update(const TArray<IndexKeysInfo>& indexKeysInfos, const IDArray& removedIDs,
										CSQLiteTable& table)
									{
										// Setup
										TNArray<SSQLiteValue>	idsToRemove(SSQLiteValue::valuesFrom(removedIDs));
										for (TIteratorD<IndexKeysInfo> iterator = indexKeysInfos.getIterator();
												iterator.hasValue(); iterator.advance())
											// Add value
											idsToRemove += SSQLiteValue(iterator->getID());

										// Update
										if (!idsToRemove.isEmpty())
											// Delete
											table.deleteRows(mIDTableColumn, idsToRemove);
										for (TIteratorD<IndexKeysInfo> indexKeysInfoIterator =
														indexKeysInfos.getIterator();
												indexKeysInfoIterator.hasValue(); indexKeysInfoIterator.advance())
											// Insert new keys
											for (TIteratorD<CString> keyIterator =
															indexKeysInfoIterator->getKeys().getIterator();
													keyIterator.hasValue(); keyIterator.advance()) {
												// Insert this key
												TableColumnAndValue	tableColumnAndValues[] =
																			{
																				TableColumnAndValue(mKeyTableColumn,
																						*keyIterator),
																				TableColumnAndValue(mIDTableColumn,
																						indexKeysInfoIterator->getID()),
																			};
												table.insertRow(
														TSARRAY_FROM_C_ARRAY(TableColumnAndValue,
																tableColumnAndValues));
											}
									}

		static	OV<SError>		callDocumentInfoKeyProcInfo(const CSQLiteResultsRow& resultsRow,
										DocumentInfo::KeyProcInfo* documentInfoKeyProcInfo)
									{ return documentInfoKeyProcInfo->call(*resultsRow.getText(mKeyTableColumn),
											CDocumentTypeInfoTable::getDocumentInfo(resultsRow)); }

	// Properties
	public:
		static	const	CSQLiteTableColumn	mKeyTableColumn;
		static	const	CSQLiteTableColumn	mIDTableColumn;

	private:
		static	const	CSQLiteTableColumn	mTableColumns[];
};

const	CSQLiteTableColumn	CIndexContentsTable::mKeyTableColumn(CString(OSSTR("key")), CSQLiteTableColumn::kKindText,
									CSQLiteTableColumn::kOptionsPrimaryKey);
const	CSQLiteTableColumn	CIndexContentsTable::mIDTableColumn(CString(OSSTR("id")), CSQLiteTableColumn::kKindInteger,
									CSQLiteTableColumn::kOptionsNotNull);
const	CSQLiteTableColumn	CIndexContentsTable::mTableColumns[] = {mKeyTableColumn, mIDTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CInternalTable

class CInternalTable {
	public:
		static	CSQLiteTable	in(CSQLiteDatabase& database)
									{ return database.getTable(CString(OSSTR("Internal")),
											CSQLiteTable::kOptionsWithoutRowID,
											TSArray<CSQLiteTableColumn>(mTableColumns, 2)); }
		static	OV<CString>		getString(const CString& key, const CSQLiteTable& table)
									{
										// Query
										OV<CString>	value;
										table.select(TSArray<CSQLiteTableColumn>(mValueTableColumn),
												CSQLiteWhere(mKeyTableColumn, SSQLiteValue(key)),
												(CSQLiteResultsRow::Proc) getString_, &value);

										return value;
									}
		static	void			set(const CString& key, const OV<CString>& string, CSQLiteTable& table)
									{
										// Check if storing or removing
										if (string.hasValue()) {
											// Storing
											TableColumnAndValue	tableColumnAndValues[] =
																		{
																			TableColumnAndValue(mKeyTableColumn, key),
																			TableColumnAndValue(mValueTableColumn,
																					*string),
																		};
											table.insertOrReplaceRow(
													TSARRAY_FROM_C_ARRAY(TableColumnAndValue, tableColumnAndValues));
										} else
											// Removing
											table.deleteRows(mKeyTableColumn, SSQLiteValue(key));
									}

	private:
		static	OV<SError>		getString_(const CSQLiteResultsRow& resultsRow, OV<CString>* version)
									{
										// Process results
										version->setValue(resultsRow.getText(mValueTableColumn));

										return OV<SError>();
									}

	private:
		static	CSQLiteTableColumn	mKeyTableColumn;
		static	CSQLiteTableColumn	mValueTableColumn;
		static	CSQLiteTableColumn	mTableColumns[];
};

CSQLiteTableColumn	CInternalTable::mKeyTableColumn(CString(OSSTR("key")), CSQLiteTableColumn::kKindText,
							(CSQLiteTableColumn::Options)
									(CSQLiteTableColumn::kOptionsPrimaryKey | CSQLiteTableColumn::kOptionsUnique |
											CSQLiteTableColumn::kOptionsNotNull));
CSQLiteTableColumn	CInternalTable::mValueTableColumn(CString(OSSTR("value")), CSQLiteTableColumn::kKindText,
							CSQLiteTableColumn::kOptionsNotNull);
CSQLiteTableColumn	CInternalTable::mTableColumns[] = {mKeyTableColumn, mValueTableColumn};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDatabaseManager::Internals

class CMDSSQLiteDatabaseManager::Internals {
	public:
		// CacheUpdateInfo
		struct CacheUpdateInfo {
										CacheUpdateInfo(const OV<ValueInfoByID>& valueInfoByID,
												const IDArray& removedIDs, const OV<UInt32>& lastRevision) :
											mValueInfoByID(valueInfoByID.hasValue() ? *valueInfoByID : ValueInfoByID()),
													mRemovedIDs(removedIDs),
													mLastRevision(lastRevision)
											{}
										CacheUpdateInfo(const CacheUpdateInfo& other) :
											mValueInfoByID(other.mValueInfoByID), mRemovedIDs(other.mRemovedIDs),
													mLastRevision(other.mLastRevision)
											{}

				const	ValueInfoByID&	getValueInfoByID() const
											{ return mValueInfoByID; }
				const	IDArray&		getRemovedIDs() const
											{ return mRemovedIDs; }
				const	OV<UInt32>&		getLastRevision() const
											{ return mLastRevision; }

						void			update(const OV<ValueInfoByID>& valueInfoByID, const IDArray& removedIDs,
												const OV<UInt32>& lastRevision)
											{
												// Update
												if (valueInfoByID.hasValue())
													// Update
													mValueInfoByID += *valueInfoByID;
												mRemovedIDs += removedIDs;
												mLastRevision = lastRevision;
											}

			private:
				ValueInfoByID	mValueInfoByID;
				IDArray			mRemovedIDs;
				OV<UInt32>		mLastRevision;
		};

		// CollectionUpdateInfo
		struct CollectionUpdateInfo {
									CollectionUpdateInfo(const OV<IDArray >& includedIDs,
											const OV<IDArray >& notIncludedIDs, const OV<UInt32>& lastRevision) :
										mIncludedIDs(includedIDs.hasValue() ? *includedIDs : IDArray()),
												mNotIncludedIDs(
														notIncludedIDs.hasValue() ? *notIncludedIDs : IDArray()),
												mLastRevision(lastRevision)
										{}
									CollectionUpdateInfo(const CollectionUpdateInfo& other) :
										mIncludedIDs(other.mIncludedIDs), mNotIncludedIDs(other.mNotIncludedIDs),
												mLastRevision(other.mLastRevision)
									{}

				const	IDArray&	getIncludedIDs() const
										{ return mIncludedIDs; }
				const	IDArray&	getNotIncludedIDs() const
										{ return mNotIncludedIDs; }
				const	OV<UInt32>&	getLastRevision() const
										{ return mLastRevision; }

						void		update(const OV<IDArray >& includedIDs,
											const OV<IDArray >& notIncludedIDs, const OV<UInt32>& lastRevision)
										{
											// Update
											if (includedIDs.hasValue())
												// Update
												mIncludedIDs += *includedIDs;
											if (notIncludedIDs.hasValue())
												// Update
												mNotIncludedIDs += *notIncludedIDs;
											mLastRevision = lastRevision;
										}

			private:
				IDArray		mIncludedIDs;
				IDArray		mNotIncludedIDs;
				OV<UInt32>	mLastRevision;
		};

		// DocumentTables
		struct DocumentTables {
								DocumentTables(const CSQLiteTable& infoTable, const CSQLiteTable& contentsTable,
										const CSQLiteTable& attachmentsTable) :
									mInfoTable(infoTable), mContentsTable(contentsTable),
											mAttachmentsTable(attachmentsTable)
									{}
								DocumentTables(const DocumentTables& other) :
									mInfoTable(other.mInfoTable), mContentsTable(other.mContentsTable),
											mAttachmentsTable(other.mAttachmentsTable)
									{}

				CSQLiteTable&	getInfoTable()
									{ return mInfoTable; }
				CSQLiteTable&	getContentsTable()
									{ return mContentsTable; }
				CSQLiteTable&	getAttachmentsTable()
									{ return mAttachmentsTable; }

			private:
				CSQLiteTable	mInfoTable;
				CSQLiteTable	mContentsTable;
				CSQLiteTable	mAttachmentsTable;
		};

		// IndexUpdateInfo
		struct IndexUpdateInfo {
			public:
												IndexUpdateInfo(const OV<TArray<IndexKeysInfo> >& indexKeysInfos,
														const OV<IDArray >& removedIDs,
														const OV<UInt32>& lastRevision) :
													mIndexKeysInfos(
																	indexKeysInfos.hasValue() ?
																			*indexKeysInfos : TNArray<IndexKeysInfo>()),
															mRemovedIDs(
																	removedIDs.hasValue() ? *removedIDs : IDArray()),
															mLastRevision(lastRevision)
													{}
												IndexUpdateInfo(const IndexUpdateInfo& other) :
													mIndexKeysInfos(other.mIndexKeysInfos),
															mRemovedIDs(other.mRemovedIDs),
															mLastRevision(other.mLastRevision)
													{}

				const	TNArray<IndexKeysInfo>&	getIndexKeysInfos() const
													{ return mIndexKeysInfos; }
				const	IDArray&				getRemovedIDs() const
													{ return mRemovedIDs; }
				const	OV<UInt32>&				getLastRevision() const
													{ return mLastRevision; }

						void					update(const OV<TArray<IndexKeysInfo> >& indexKeysInfos,
														const OV<IDArray >& removedIDs, const OV<UInt32>& lastRevision)
													{
														// Update
														if (indexKeysInfos.hasValue())
															// Update
															mIndexKeysInfos += *indexKeysInfos;
														if (removedIDs.hasValue())
															// Update
															mRemovedIDs += *removedIDs;
														mLastRevision = lastRevision;
													}

			private:
				TNArray<IndexKeysInfo>	mIndexKeysInfos;
				IDArray					mRemovedIDs;
				OV<UInt32>				mLastRevision;
		};

		// BatchInfo
		struct BatchInfo {
															BatchInfo() {}
															BatchInfo(const BatchInfo& other) :
																mDocumentLastRevisionTypesNeedingWrite(
																		other.mDocumentLastRevisionTypesNeedingWrite),
																		mCacheUpdateInfoByName(
																				other.mCacheUpdateInfoByName),
																		mCollectionUpdateInfoByName(
																				other.mCollectionUpdateInfoByName),
																		mIndexUpdateInfoByName(
																				other.mIndexUpdateInfoByName)
																{}

						void								noteDocumentTypeNeedingLastRevisionWrite(
																	const CString& documentType)
																{ mDocumentLastRevisionTypesNeedingWrite +=
																		documentType; }
						void								noteCacheUpdate(const CString& name,
																	const OV<ValueInfoByID>& valueInfoByID,
																	const IDArray& removedIDs,
																	const OV<UInt32>& lastRevision)
																{
																	// Retrieve existing CacheUpdateInfo
																	OR<Internals::CacheUpdateInfo>	cacheUpdateInfo =
																											mCacheUpdateInfoByName[
																													name];
																	if (cacheUpdateInfo.hasReference())
																		// Update existing
																		cacheUpdateInfo->update(valueInfoByID,
																				removedIDs, lastRevision);
																	else
																		// Add
																		mCacheUpdateInfoByName.set(name,
																				Internals::CacheUpdateInfo(
																						valueInfoByID, removedIDs,
																						lastRevision));
																}
						void								noteCollectionUpdate(const CString& name,
																	const OV<IDArray >& includedIDs,
																	const OV<IDArray >& notIncludedIDs,
																	const OV<UInt32>& lastRevision)
																{
																	// Retrieve existing CollectionUpdateInfo
																	OR<Internals::CollectionUpdateInfo>	collectionUpdateInfo =
																												mCollectionUpdateInfoByName[
																														name];
																	if (collectionUpdateInfo.hasReference())
																		// Update existing
																		collectionUpdateInfo->update(includedIDs,
																				notIncludedIDs, lastRevision);
																	else
																		// Add
																		mCollectionUpdateInfoByName.set(name,
																				Internals::CollectionUpdateInfo(
																						includedIDs, notIncludedIDs,
																						lastRevision));
																}
						void								noteIndexUpdate(const CString& name,
																	const OV<TArray<IndexKeysInfo> >& indexKeysInfos,
																	const OV<IDArray >& removedIDs,
																	const OV<UInt32>& lastRevision)
																{
																	// Retrieve existing IndexUpdateInfo
																	OR<Internals::IndexUpdateInfo>	indexUpdateInfo =
																											mIndexUpdateInfoByName[
																													name];
																	if (indexUpdateInfo.hasReference())
																		// Update existing
																		indexUpdateInfo->update(indexKeysInfos,
																				removedIDs, lastRevision);
																	else
																		// Add
																		mIndexUpdateInfoByName.set(name,
																				Internals::IndexUpdateInfo(
																						indexKeysInfos, removedIDs,
																						lastRevision));
																}

				const	TSet<CString>&						getDocumentLastRevisionTypesNeedingWrite() const
																{ return mDocumentLastRevisionTypesNeedingWrite; }
				const 	TDictionary<CacheUpdateInfo>&		getCacheUpdateInfoByName() const
																{ return mCacheUpdateInfoByName; }
				const 	TDictionary<CollectionUpdateInfo>&	getCollectionUpdateInfoByName() const
																{ return mCollectionUpdateInfoByName; }
				const 	TDictionary<IndexUpdateInfo>&		getIndexUpdateInfoByName() const
																{ return mIndexUpdateInfoByName; }

			// Properties
			private:
				TNSet<CString>						mDocumentLastRevisionTypesNeedingWrite;
				TNDictionary<CacheUpdateInfo>		mCacheUpdateInfoByName;
				TNDictionary<CollectionUpdateInfo>	mCollectionUpdateInfoByName;
				TNDictionary<IndexUpdateInfo>		mIndexUpdateInfoByName;
		};

		// AssociationDetailInfo
		struct AssociationDetailInfo {
			public:
												AssociationDetailInfo(const TArray<CString>& cachedValueNames,
														const TDictionary<CSQLiteTableColumn>& cacheTableColumnByName) :
													mCachedValueNames(cachedValueNames),
															mCacheTableColumnByName(cacheTableColumnByName)
													{}

				const	TArray<CString>&		getCachedValueName() const
													{ return mCachedValueNames; }
				const	CSQLiteTableColumn&		getCacheTableColumn(const CString& name) const
													{ return *mCacheTableColumnByName[name]; }

						void					addResult(const CDictionary& result)
													{ mResults += result; }
				const	TArray<CDictionary>&	getResults() const
													{ return mResults; }

						void					addToID(SInt64 toID)
													{ mToIDs.insert(toID); }
				const	TNumberSet<SInt64>&		getToIDs() const
													{ return mToIDs; }

			private:
				const	TArray<CString>&					mCachedValueNames;
				const	TDictionary<CSQLiteTableColumn>&	mCacheTableColumnByName;
						TNArray<CDictionary>				mResults;
						TNumberSet<SInt64>					mToIDs;
		};

	public:
									Internals(const CFolder& folder, const CString& name) :
										mDatabase(folder, name),
												mInternalsTable(CInternalsTable::in(mDatabase)),
												mAssociationsTable(CAssociationsTable::in(mDatabase, mInternalsTable)),
												mCachesTable(CCachesTable::in(mDatabase, mInternalsTable)),
												mCollectionsTable(
														CCollectionsTable::in(mDatabase, mInternalsTable, mInfoTable)),
												mDocumentsTable(CDocumentsTable::in(mDatabase, mInternalsTable)),
												mIndexesTable(
														CIndexesTable::in(mDatabase, mInternalsTable, mInfoTable)),
												mInfoTable(CInfoTable::in(mDatabase)),
												mInternalTable(CInternalTable::in(mDatabase))
										{
											// Finalize setup
											CInfoTable::set(CString(OSSTR("version")), OV<CString>(), mInfoTable);

											mDocumentsTable.select((CSQLiteResultsRow::Proc) storeDocumentLastRevision,
													this);
										}

				DocumentTables&		getDocumentTables(const CString& documentType)
										{
											// Check for already having tables
											if (!mDocumentTablesByDocumentType.contains(documentType)) {
												// Setup tables
												CString			nameRoot =
																		documentType.getSubString(0, 1).uppercased() +
																				documentType.getSubString(1);
												CSQLiteTable	infoTable =
																		CDocumentTypeInfoTable::in(mDatabase, nameRoot,
																				mInternalsTable);
												CSQLiteTable	contentsTable =
																		CDocumentTypeContentsTable::in(mDatabase,
																				nameRoot, mInfoTable, mInternalsTable);
												CSQLiteTable	attachmentsTable =
																		CDocumentTypeAttachmentsTable::in(mDatabase,
																				nameRoot, mInfoTable, mInternalsTable);

												// Store
												mDocumentTablesByDocumentType.set(documentType,
														DocumentTables(infoTable, contentsTable, attachmentsTable));
											}

											return *mDocumentTablesByDocumentType.get(documentType);
										}
				UInt32				getNextRevision(const CString& documentType)
										{
											// Compose next revision
											const	OR<TNumber<UInt32> >	currentRevision =
																					mDocumentLastRevisionByDocumentType
																							.get(documentType);
													UInt32					nextRevision =
																					currentRevision.hasReference() ?
																							**currentRevision + 1 : 1;

											// Check for batch
											const	OR<BatchInfo>	batchInfo =
																			mBatchInfoByThreadRef[
																					CThread::getCurrentRef()];
											if (batchInfo.hasReference())
												// Update batchinfo
												batchInfo->noteDocumentTypeNeedingLastRevisionWrite(documentType);
											else
												// Update
												CDocumentsTable::set(nextRevision, documentType, mDocumentsTable);

											// Store
											mDocumentLastRevisionByDocumentType.set(documentType,
													TNumber<UInt32>(nextRevision));

											return nextRevision;
										}

		static	void				cacheUpdate(const CString& name, const OV<ValueInfoByID>& valueInfoByID,
											const IDArray& removedIDs, const OV<UInt32>& lastRevision,
											Internals* internals)
										{
											// Update tables
											if (lastRevision.hasValue())
												// Update Caches table
												CCachesTable::update(name, *lastRevision, internals->mCachesTable);
											if (valueInfoByID.hasValue() || !removedIDs.isEmpty())
												// Update Cache contents table
												CCacheContentsTable::update(
														valueInfoByID.hasValue() ? *valueInfoByID : ValueInfoByID(),
														removedIDs, *internals->mCacheTablesByName[name]);
										}
		static	void				collectionUpdate(const CString& name, const OV<IDArray >& includedIDs,
											const OV<IDArray >& notIncludedIDs, const OV<UInt32>& lastRevision,
											Internals* internals)
										{
											// Update tables
											if (lastRevision.hasValue())
												// Update Collections table
												CCollectionsTable::update(name, *lastRevision,
														internals->mCollectionsTable);
											if (includedIDs.hasValue() || notIncludedIDs.hasValue())
												// Update Collection contents table
												CCollectionContentsTable::update(
														includedIDs.hasValue() ? *includedIDs : IDArray(),
														notIncludedIDs.hasValue() ? *notIncludedIDs : IDArray(),
														*internals->mCollectionTablesByName[name]);
										}
		static	void				indexUpdate(const CString& name, const OV<TArray<IndexKeysInfo> >& indexKeysInfos,
											const OV<IDArray >& removedIDs, const OV<UInt32>& lastRevision,
											Internals* internals)
										{
											// Update tables
											if (lastRevision.hasValue())
												// Update Indexes table
												CIndexesTable::update(name, *lastRevision,
														internals->mIndexesTable);
											if (indexKeysInfos.hasValue() || removedIDs.hasValue())
												// Update Index contents table
												CIndexContentsTable::update(
														indexKeysInfos.hasValue() ?
																*indexKeysInfos : TNArray<IndexKeysInfo>(),
														removedIDs.hasValue() ? *removedIDs : IDArray(),
														*internals->mIndexTablesByName[name]);
										}

		static	OV<SError>			processAssociationDetailResultsRow(const CSQLiteResultsRow& resultsRow,
											AssociationDetailInfo* associationDetailInfo)
										{
											// Setup
											SInt64	toID =
															*resultsRow.getInteger(
																	CAssociationContentsTable::mToIDTableColumn);

											CDictionary	info;
											info.set(CString(OSSTR("fromID")),
													*resultsRow.getInteger(
															CAssociationContentsTable::mFromIDTableColumn));
											info.set(CString(OSSTR("toID")), toID);

											for (TIteratorD<CString> iterator =
															associationDetailInfo->getCachedValueName().getIterator();
													iterator.hasValue(); iterator.advance()) {
												// Get CSQLiteTableColumn
												const	CSQLiteTableColumn& tableColumn =
																					associationDetailInfo->
																							getCacheTableColumn(
																									*iterator);
												switch (tableColumn.getKind()) {
													case CSQLiteTableColumn::kKindInteger:
														// Integer
														info.set(*iterator, *resultsRow.getInteger(tableColumn));
														break;

													case CSQLiteTableColumn::kKindReal:
														// Real
														info.set(*iterator, *resultsRow.getReal(tableColumn));
														break;

													case CSQLiteTableColumn::kKindText:
														// Text
														info.set(*iterator, *resultsRow.getText(tableColumn));
														break;

													case CSQLiteTableColumn::kKindBlob:
														// Blob
														info.set(*iterator, *resultsRow.getBlob(tableColumn));
														break;

													default:
														break;
												}
											}

 											associationDetailInfo->addResult(info);
											associationDetailInfo->addToID(toID);

											return OV<SError>();
										}
	private:
		static	OV<SError>			storeDocumentLastRevision(const CSQLiteResultsRow& resultsRow, Internals* internals)
										{
											// Setup
											CDocumentsTable::Info	documentsTableInfo(resultsRow);

											// Update dictionary
											internals->mDocumentLastRevisionByDocumentType.set(
													documentsTableInfo.getDocumentType(),
													TNumber<UInt32>(documentsTableInfo.getLastRevision()));

											return OV<SError>();
										}

	public:
		CSQLiteDatabase 						mDatabase;

		TNLockingDictionary<BatchInfo>			mBatchInfoByThreadRef;

		CSQLiteTable							mInternalsTable;

		CSQLiteTable							mAssociationsTable;
		TNLockingDictionary<CSQLiteTable>		mAssociationTablesByName;

		CSQLiteTable							mCachesTable;
		TNLockingDictionary<CSQLiteTable>		mCacheTablesByName;

		CSQLiteTable							mCollectionsTable;
		TNLockingDictionary<CSQLiteTable>		mCollectionTablesByName;

		CSQLiteTable							mDocumentsTable;
		TNLockingDictionary<DocumentTables>		mDocumentTablesByDocumentType;
		TNLockingDictionary<TNumber<UInt32> >	mDocumentLastRevisionByDocumentType;

		CSQLiteTable							mIndexesTable;
		TNLockingDictionary<CSQLiteTable>		mIndexTablesByName;

		CSQLiteTable							mInfoTable;

		CSQLiteTable							mInternalTable;
};

//----------------------------------------------------------------------------------------------------------------------
//----------------------------------------------------------------------------------------------------------------------
// MARK: - CMDSSQLiteDatabaseManager

// MARK: Lifecycle methods

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::CMDSSQLiteDatabaseManager(const CFolder& folder, const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	mInternals = new Internals(folder, name);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::~CMDSSQLiteDatabaseManager()
//----------------------------------------------------------------------------------------------------------------------
{
	Delete(mInternals);
}

// MARK: Instance methods

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::getVariableNumberLimit() const
//----------------------------------------------------------------------------------------------------------------------
{
	return mInternals->mInfoTable.getVariableNumberLimit();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::associationRegister(const CString& name, const CString& fromDocumentType,
		const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Register
	CAssociationsTable::addOrUpdate(name, fromDocumentType, toDocumentType, mInternals->mAssociationsTable);

	// Create contents table
	mInternals->mAssociationTablesByName.set(name,
			CAssociationContentsTable::in(mInternals->mDatabase, name, mInternals->mInternalsTable));
}

//----------------------------------------------------------------------------------------------------------------------
OV<AssociationInfo> CMDSSQLiteDatabaseManager::associationInfo(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get info
	OV<AssociationInfo>	associationInfo = CAssociationsTable::getInfo(name, mInternals->mAssociationsTable);
	if (associationInfo.hasValue()) {
		// Found
		CSQLiteTable	associationContentsTable =
								CAssociationContentsTable::in(mInternals->mDatabase, name, mInternals->mInternalsTable);
		mInternals->mAssociationTablesByName.set(name, associationContentsTable);
	}

	return associationInfo;
}

//----------------------------------------------------------------------------------------------------------------------
TArray<CMDSAssociation::Item> CMDSSQLiteDatabaseManager::associationGet(const CString& name,
		const CString& fromDocumentType, const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	fromDocumentTables = mInternals->getDocumentTables(fromDocumentType);
	Internals::DocumentTables&	toDocumentTables = mInternals->getDocumentTables(toDocumentType);
	CSQLiteTable&				associationContentsTable = *mInternals->mAssociationTablesByName.get(name);

	// Get all items
	TArray<CAssociationContentsTable::Item>	items = CAssociationContentsTable::get(associationContentsTable);
	CDocumentTypeInfoTable::DocumentIDByID	fromDocumentIDByID =
													CDocumentTypeInfoTable::getDocumentIDByID(
															CAssociationContentsTable::Item::getFromIDs(items),
															fromDocumentTables.getInfoTable());

	CDocumentTypeInfoTable::DocumentIDByID	toDocumentIDByID =
													CDocumentTypeInfoTable::getDocumentIDByID(
															CAssociationContentsTable::Item::getToIDs(items),
															toDocumentTables.getInfoTable());

	// Prepare result
	TNArray<CMDSAssociation::Item>	associationItems;
	for (TIteratorD<CAssociationContentsTable::Item> iterator = items.getIterator(); iterator.hasValue();
			iterator.advance())
		// Add association item
		associationItems +=
				CMDSAssociation::Item(*fromDocumentIDByID[iterator->getFromID()],
						*toDocumentIDByID[iterator->getToID()]);

	return associationItems;
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSAssociation::Item> > CMDSSQLiteDatabaseManager::associationGetFrom(const CString& name,
		const CString& fromDocumentID, const CString& fromDocumentType, const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	fromDocumentTables = mInternals->getDocumentTables(fromDocumentType);
	OV<SInt64>					fromID =
										CDocumentTypeInfoTable::getID(fromDocumentID,
												fromDocumentTables.getInfoTable());
	if (!fromID.hasValue())
		return TVResult<TArray<CMDSAssociation::Item> >(CMDSDocumentStorage::getUnknownDocumentIDError(fromDocumentID));

	Internals::DocumentTables&	toDocumentTables = mInternals->getDocumentTables(toDocumentType);
	CSQLiteTable&				associationContentsTable = *mInternals->mAssociationTablesByName.get(name);

	// Get items
	TArray<CAssociationContentsTable::Item>	items =
													CAssociationContentsTable::get(
															CSQLiteWhere(CAssociationContentsTable::mFromIDTableColumn,
																	SSQLiteValue(*fromID)),
															associationContentsTable);
	CDocumentTypeInfoTable::DocumentIDByID	toDocumentIDByID =
													CDocumentTypeInfoTable::getDocumentIDByID(
															CAssociationContentsTable::Item::getToIDs(items),
															toDocumentTables.getInfoTable());

	// Prepare result
	TNArray<CMDSAssociation::Item>	associationItems;
	for (TIteratorD<CAssociationContentsTable::Item> iterator = items.getIterator(); iterator.hasValue();
			iterator.advance())
		// Add association item
		associationItems += CMDSAssociation::Item(fromDocumentID, *toDocumentIDByID[iterator->getToID()]);

	return TVResult<TArray<CMDSAssociation::Item> >(associationItems);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<TArray<CMDSAssociation::Item> > CMDSSQLiteDatabaseManager::associationGetTo(const CString& name,
		const CString& fromDocumentType, const CString& toDocumentID, const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	fromDocumentTables = mInternals->getDocumentTables(fromDocumentType);

	Internals::DocumentTables&	toDocumentTables = mInternals->getDocumentTables(toDocumentType);
	OV<SInt64>					toID = CDocumentTypeInfoTable::getID(toDocumentID, toDocumentTables.getInfoTable());
	if (!toID.hasValue())
		return TVResult<TArray<CMDSAssociation::Item> >(CMDSDocumentStorage::getUnknownDocumentIDError(toDocumentID));

	CSQLiteTable&				associationContentsTable = *mInternals->mAssociationTablesByName.get(name);

	// Get items
	TArray<CAssociationContentsTable::Item>	items =
													CAssociationContentsTable::get(
															CSQLiteWhere(CAssociationContentsTable::mToIDTableColumn,
																	SSQLiteValue(*toID)),
															associationContentsTable);
	CDocumentTypeInfoTable::DocumentIDByID	fromDocumentIDByID =
													CDocumentTypeInfoTable::getDocumentIDByID(
															CAssociationContentsTable::Item::getFromIDs(items),
															fromDocumentTables.getInfoTable());

	// Prepare result
	TNArray<CMDSAssociation::Item>	associationItems;
	for (TIteratorD<CAssociationContentsTable::Item> iterator = items.getIterator(); iterator.hasValue();
			iterator.advance())
		// Add association item
		associationItems += CMDSAssociation::Item(*fromDocumentIDByID[iterator->getFromID()], toDocumentID);

	return TVResult<TArray<CMDSAssociation::Item> >(associationItems);
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt32> CMDSSQLiteDatabaseManager::associationGetCountFrom(const CString& name, const CString& fromDocumentID,
		const CString& fromDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(fromDocumentType);
	CSQLiteTable&				associationContentsTable = *mInternals->mAssociationTablesByName.get(name);

	// Get id
	OV<SInt64>	id = CDocumentTypeInfoTable::getID(fromDocumentID, documentTables.getInfoTable());
	if (!id.hasValue())
		return OV<UInt32>();

	return OV<UInt32>(CAssociationContentsTable::countFrom(*id, associationContentsTable));
}

//----------------------------------------------------------------------------------------------------------------------
OV<UInt32> CMDSSQLiteDatabaseManager::associationGetCountTo(const CString& name, const CString& toDocumentID,
		const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(toDocumentType);
	CSQLiteTable&				associationContentsTable = *mInternals->mAssociationTablesByName.get(name);

	// Get id
	OV<SInt64>	id = CDocumentTypeInfoTable::getID(toDocumentID, documentTables.getInfoTable());
	if (!id.hasValue())
		return OV<UInt32>();

	return OV<UInt32>(CAssociationContentsTable::countTo(*id, associationContentsTable));
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLiteDatabaseManager::associationIterateDocumentInfosFrom(const CString& name,
		const CString& fromDocumentID, const CString& fromDocumentType, const CString& toDocumentType,
		UInt32 startIndex, const OV<UInt32>& count, const DocumentInfo::ProcInfo& documentInfoProcInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	fromDocumentTables = mInternals->getDocumentTables(fromDocumentType);
	OV<SInt64>					fromID =
										CDocumentTypeInfoTable::getID(fromDocumentID,
												fromDocumentTables.getInfoTable());
	if (!fromID.hasValue())
		return OV<SError>(CMDSDocumentStorage::getUnknownDocumentIDError(fromDocumentID));

	Internals::DocumentTables&	toDocumentTables = mInternals->getDocumentTables(toDocumentType);
	CSQLiteTable&				associationContentsTable = *mInternals->mAssociationTablesByName.get(name);

	// Iterate rows
	associationContentsTable.select(CDocumentTypeInfoTable::tableColumns(),
			CSQLiteInnerJoin(associationContentsTable, CAssociationContentsTable::mToIDTableColumn,
					toDocumentTables.getInfoTable(), CDocumentTypeInfoTable::mIDTableColumn),
			CSQLiteWhere(CAssociationContentsTable::mFromIDTableColumn, SSQLiteValue(*fromID)),
			CSQLiteOrderBy(CAssociationContentsTable::mToIDTableColumn), CSQLiteLimit(count, startIndex),
			(CSQLiteResultsRow::Proc) CDocumentTypeInfoTable::callDocumentInfoProcInfo, (void*) &documentInfoProcInfo);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
OV<SError> CMDSSQLiteDatabaseManager::associationIterateDocumentInfosTo(const CString& name,
		const CString& toDocumentID, const CString& toDocumentType, const CString& fromDocumentType, UInt32 startIndex,
		const OV<UInt32>& count, const DocumentInfo::ProcInfo& documentInfoProcInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	toDocumentTables = mInternals->getDocumentTables(toDocumentType);
	OV<SInt64>					toID = CDocumentTypeInfoTable::getID(toDocumentID, toDocumentTables.getInfoTable());
	if (!toID.hasValue())
		return OV<SError>(CMDSDocumentStorage::getUnknownDocumentIDError(toDocumentID));

	Internals::DocumentTables&	fromDocumentTables = mInternals->getDocumentTables(fromDocumentType);
	CSQLiteTable&				associationContentsTable = *mInternals->mAssociationTablesByName.get(name);

	// Iterate rows
	associationContentsTable.select(CDocumentTypeInfoTable::tableColumns(),
			CSQLiteInnerJoin(associationContentsTable, CAssociationContentsTable::mFromIDTableColumn,
					fromDocumentTables.getInfoTable(), CDocumentTypeInfoTable::mIDTableColumn),
			CSQLiteWhere(CAssociationContentsTable::mToIDTableColumn, SSQLiteValue(*toID)),
			CSQLiteOrderBy(CAssociationContentsTable::mFromIDTableColumn), CSQLiteLimit(count, startIndex),
			(CSQLiteResultsRow::Proc) CDocumentTypeInfoTable::callDocumentInfoProcInfo, (void*) &documentInfoProcInfo);

	return OV<SError>();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::associationUpdate(const CString& name, const TArray<CMDSAssociation::Update>& updates,
		const CString& fromDocumentType, const CString& toDocumentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	fromDocumentTables = mInternals->getDocumentTables(fromDocumentType);
	CDictionary					fromIDByDocumentID =
										CDocumentTypeInfoTable::getIDByDocumentID(
												CMDSAssociation::Update::getFromDocumentIDsArray(updates),
												fromDocumentTables.getInfoTable());

	Internals::DocumentTables&	toDocumentTables = mInternals->getDocumentTables(toDocumentType);
	CDictionary					toIDByDocumentID =
										CDocumentTypeInfoTable::getIDByDocumentID(
												CMDSAssociation::Update::getToDocumentIDsArray(updates),
												toDocumentTables.getInfoTable());

	CSQLiteTable&				associationContentsTable = *mInternals->mAssociationTablesByName.get(name);

	// Update Association
	TNArray<CAssociationContentsTable::Item>	addAssociationContentsTableItems;
	TNArray<CAssociationContentsTable::Item>	removeAssociationContentsTableItems;
	for (TIteratorD<CMDSAssociation::Update> iterator = updates.getIterator(); iterator.hasValue(); iterator.advance())
		// Check update action
		if (iterator->getAction() == CMDSAssociation::Update::kActionAdd)
			// Add
			addAssociationContentsTableItems +=
					CAssociationContentsTable::Item(
							fromIDByDocumentID.getSInt64(iterator->getItem().getFromDocumentID()),
							toIDByDocumentID.getSInt64(iterator->getItem().getToDocumentID()));
		else
			// Remove
			removeAssociationContentsTableItems +=
					CAssociationContentsTable::Item(
							fromIDByDocumentID.getSInt64(iterator->getItem().getFromDocumentID()),
							toIDByDocumentID.getSInt64(iterator->getItem().getToDocumentID()));
	CAssociationContentsTable::remove(removeAssociationContentsTableItems, associationContentsTable);
	CAssociationContentsTable::add(addAssociationContentsTableItems, associationContentsTable);
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<SValue> CMDSSQLiteDatabaseManager::associationDetail(const I<CMDSAssociation>& association,
		const TArray<CString>& fromDocumentIDs, const I<TMDSCache<SInt64, ValueInfoByID>>& cache,
		const TArray<CString>& cachedValueNames)
//----------------------------------------------------------------------------------------------------------------------
{
	// Preflight
	Internals::DocumentTables&				fromDocumentTables =
													mInternals->getDocumentTables(association->getFromDocumentType());
	CDocumentTypeInfoTable::DocumentIDByID	fromDocumentIDByID =
													CDocumentTypeInfoTable::getDocumentIDByID(fromDocumentIDs,
															fromDocumentTables.getInfoTable());
	if (fromDocumentIDByID.getKeyCount() < fromDocumentIDs.getCount()) {
		// Did not resolve all documentIDs
				TNSet<CString>	notFoundFromDocumentIDs =
										TNSet<CString>(fromDocumentIDs).getDifference(fromDocumentIDByID.getValues());
		const	CString&		documentID = *notFoundFromDocumentIDs.getAny();

		return TVResult<SValue>(CMDSDocumentStorage::getUnknownDocumentIDError(documentID));
	}

	// Setup
	CSQLiteTable&				associationContentsTable =
										*mInternals->mAssociationTablesByName.get(association->getName());

	CSQLiteTable&				cacheContentsTable = *mInternals->mCacheTablesByName.get(cache->getName());
	TArray<CSQLiteTableColumn>	cacheContentsTableColumns = cacheContentsTable.getTableColumns(cachedValueNames);

	TNDictionary<CSQLiteTableColumn>	cacheContentsTableColumnByName;
	for (TIteratorD<CSQLiteTableColumn> iterator = cacheContentsTableColumns.getIterator(); iterator.hasValue();
			iterator.advance())
		// Add table column
		cacheContentsTableColumnByName.set(iterator->getName(), *iterator);

	Internals::DocumentTables&	toDocumentTables = mInternals->getDocumentTables(association->getToDocumentType());

	TNArray<CSQLiteTableColumn>	tableColumns;
	tableColumns += CAssociationContentsTable::mFromIDTableColumn;
	tableColumns += CAssociationContentsTable::mToIDTableColumn;
	tableColumns += cacheContentsTableColumns;

	Internals::AssociationDetailInfo	associationDetailsInfo(cachedValueNames, cacheContentsTableColumnByName);
	associationContentsTable.select(tableColumns,
			CSQLiteInnerJoin(associationContentsTable, CAssociationContentsTable::mToIDTableColumn, cacheContentsTable,
					CCacheContentsTable::mIDTableColumn),
			CSQLiteWhere(CAssociationContentsTable::mFromIDTableColumn,
					SSQLiteValue::valuesFrom(fromDocumentIDByID.getKeys())),
			(CSQLiteResultsRow::Proc) Internals::processAssociationDetailResultsRow, &associationDetailsInfo);

	CDocumentTypeInfoTable::DocumentIDByID	toDocumentIDByID =
													CDocumentTypeInfoTable::getDocumentIDByID(
															associationDetailsInfo.getToIDs().getNumberArray(),
															toDocumentTables.getInfoTable());

	TNArray<CDictionary>	finalizedResults;
	for (TIteratorD<CDictionary> iterator = associationDetailsInfo.getResults().getIterator(); iterator.hasValue();
			iterator.advance()) {
		// Make copy
		CDictionary	info(*iterator);
		info.set(CString(OSSTR("fromID")), *fromDocumentIDByID[info.getSInt64(CString(OSSTR("fromID")))]);
		info.set(CString(OSSTR("toID")), *toDocumentIDByID[info.getSInt64(CString(OSSTR("toID")))]);
		finalizedResults += info;
	}

	return TVResult<SValue>(SValue(finalizedResults));
}

//----------------------------------------------------------------------------------------------------------------------
TVResult<SValue> CMDSSQLiteDatabaseManager::associationSum(const I<CMDSAssociation>& association,
		const TArray<CString>& fromDocumentIDs, const I<TMDSCache<SInt64, ValueInfoByID>>& cache,
		const TArray<CString>& cachedValueNames)
//----------------------------------------------------------------------------------------------------------------------
{
	// Preflight
	Internals::DocumentTables&	fromDocumentTables = mInternals->getDocumentTables(association->getFromDocumentType());

	TNArray<SSQLiteValue>		fromIDs;
	for (TIteratorD<CString> iterator = fromDocumentIDs.getIterator(); iterator.hasValue(); iterator.advance()) {
		// Get fromID
		OV<SInt64>	fromID = CDocumentTypeInfoTable::getID(*iterator, fromDocumentTables.getInfoTable());
		if (!fromID.hasValue())
			// Did not resolve all documentIDs
			return TVResult<SValue>(CMDSDocumentStorage::getUnknownDocumentIDError(*iterator));
		fromIDs += SSQLiteValue(*fromID);
	}

	// Setup
	CSQLiteTable&				associationContentsTable =
										*mInternals->mAssociationTablesByName.get(association->getName());

	CSQLiteTable&				cacheContentsTable = *mInternals->mCacheTablesByName.get(cache->getName());
	TArray<CSQLiteTableColumn>	cacheContentsTableColumns = cacheContentsTable.getTableColumns(cachedValueNames);

	// Sum
	TVResult<CDictionary>	info =
									associationContentsTable.sum(cacheContentsTableColumns,
											CSQLiteInnerJoin(associationContentsTable,
													CAssociationContentsTable::mToIDTableColumn, cacheContentsTable,
													CCacheContentsTable::mIDTableColumn),
											CSQLiteWhere(CAssociationContentsTable::mFromIDTableColumn, fromIDs),
											true);
	ReturnValueIfResultError(info, TVResult<SValue>(info.getError()));

	return TVResult<SValue>(SValue(*info));
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::cacheRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, const CacheValueInfos& cacheValueInfos)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get current info
	OV<CacheInfo>	currentInfo = CCachesTable::getInfo(name, mInternals->mCachesTable);

	// Setup table
	CSQLiteTable	cacheContentsTable =
							CCacheContentsTable::in(mInternals->mDatabase, name, cacheValueInfos,
									mInternals->mInternalsTable);
	mInternals->mCacheTablesByName.set(name, cacheContentsTable);

	// Compose next steps
	UInt32	lastRevision;
	bool	updateMasterTable;
	if (!currentInfo.hasValue()) {
		// New
		lastRevision = 0;
		updateMasterTable = true;
	} else if ((relevantProperties != currentInfo->getRelevantProperties()) ||
			(cacheValueInfos != currentInfo->getCacheValueInfos())) {
		// Info has changed
		lastRevision = 0;
		updateMasterTable = true;
	} else {
		// No change
		lastRevision = currentInfo->getLastRevision();
		updateMasterTable = false;
	}

	// Check if need to update the master table
	if (updateMasterTable) {
		// New or updated
		CCachesTable::addOrUpdate(name, documentType, relevantProperties, cacheValueInfos, mInternals->mCachesTable);

		// Update table
		if (currentInfo.hasValue())	cacheContentsTable.drop();
		cacheContentsTable.create();
	}

	return lastRevision;
}

//----------------------------------------------------------------------------------------------------------------------
OV<CacheInfo> CMDSSQLiteDatabaseManager::cacheInfo(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get info
	OV<CacheInfo>	cacheInfo = CCachesTable::getInfo(name, mInternals->mCachesTable);
	if (cacheInfo.hasValue()) {
		// Found
		CSQLiteTable	cacheContentsTable =
								CCacheContentsTable::in(mInternals->mDatabase, name, cacheInfo->getCacheValueInfos(),
										mInternals->mInternalsTable);
		mInternals->mCacheTablesByName.set(name, cacheContentsTable);
	}

	return cacheInfo;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::cacheUpdate(const CString& name, const OV<ValueInfoByID>& valueInfoByID,
		const IDArray& removedIDs, const OV<UInt32>& lastRevision)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if in batch
	const	OR<Internals::BatchInfo>	batchInfo = mInternals->mBatchInfoByThreadRef[CThread::getCurrentRef()];
	if (batchInfo.hasReference())
		// Update batch info
		batchInfo->noteCacheUpdate(name, valueInfoByID, removedIDs, lastRevision);
	else
		// Update
		Internals::cacheUpdate(name, valueInfoByID, removedIDs, lastRevision, mInternals);
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::collectionRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, const CString& isIncludedSelector,
		const CDictionary& isIncludedSelectorInfo, bool isUpToDate)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get current info
	OV<CollectionInfo>	currentInfo = CCollectionsTable::getInfo(name, mInternals->mCollectionsTable);

	// Setup table
	CSQLiteTable	collectionContentsTable =
							CCollectionContentsTable::in(mInternals->mDatabase, name, mInternals->mInternalsTable);
	mInternals->mCollectionTablesByName.set(name, collectionContentsTable);

	// Compose next steps
	UInt32	lastRevision;
	bool	updateMasterTable;
	if (!currentInfo.hasValue()) {
		// New
		if (isUpToDate) {
			// Up-to-date
			const	OR<TNumber<UInt32> >	currentRevision =
													mInternals->mDocumentLastRevisionByDocumentType.get(documentType);
			lastRevision = currentRevision.hasReference() ? **currentRevision : 0;
		} else
			// Not up-to-date
			lastRevision = 0;
		updateMasterTable = true;
	} else if ((relevantProperties != currentInfo->getRelevantProperties()) ||
			(isIncludedSelector != currentInfo->getIsIncludedSelector()) ||
			(isIncludedSelectorInfo != currentInfo->getIsIncludedSelectorInfo())) {
		// Info has changed
		lastRevision = 0;
		updateMasterTable = true;
	} else {
		// No change
		lastRevision = currentInfo->getLastRevision();
		updateMasterTable = false;
	}

	// Check if need to update the master table
	if (updateMasterTable) {
		// New or updated
		CCollectionsTable::addOrUpdate(name, documentType, relevantProperties, isIncludedSelector,
				isIncludedSelectorInfo, lastRevision, mInternals->mCollectionsTable);

		// Update table
		if (currentInfo.hasValue())	collectionContentsTable.drop();
		collectionContentsTable.create();
	}

	return lastRevision;
}

//----------------------------------------------------------------------------------------------------------------------
OV<CollectionInfo> CMDSSQLiteDatabaseManager::collectionInfo(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get info
	OV<CollectionInfo>	collectionInfo = CCollectionsTable::getInfo(name, mInternals->mCollectionsTable);
	if (collectionInfo.hasValue()) {
		// Found
		CSQLiteTable	collectionContentsTable =
								CCollectionContentsTable::in(mInternals->mDatabase, name, mInternals->mInternalsTable);
		mInternals->mCollectionTablesByName.set(name, collectionContentsTable);
	}

	return collectionInfo;
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::collectionGetDocumentCount(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return count
	return mInternals->mCollectionTablesByName.get(name)->count();
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::collectionIterateDocumentInfos(const CString& name, const CString& documentType,
		UInt32 startIndex, const OV<UInt32>& count, const DocumentInfo::ProcInfo& documentInfoProcInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);
	CSQLiteTable&				collectionContentsTable = *mInternals->mCollectionTablesByName.get(name);

	// Iterate rows
	collectionContentsTable.select(
			CSQLiteInnerJoin(collectionContentsTable, CCollectionContentsTable::mIDTableColumn,
					documentTables.getInfoTable()),
			CSQLiteOrderBy(CCollectionContentsTable::mIDTableColumn), CSQLiteLimit(count, startIndex),
			(CSQLiteResultsRow::Proc) CDocumentTypeInfoTable::callDocumentInfoProcInfo, (void*) &documentInfoProcInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::collectionUpdate(const CString& name, const OV<IDArray >& includedIDs,
		const OV<IDArray >& notIncludedIDs, const OV<UInt32>& lastRevision)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if in batch
	const	OR<Internals::BatchInfo>	batchInfo = mInternals->mBatchInfoByThreadRef[CThread::getCurrentRef()];
	if (batchInfo.hasReference())
		// Update batch info
		batchInfo->noteCollectionUpdate(name, includedIDs, notIncludedIDs, lastRevision);
	else
		// Update
		Internals::collectionUpdate(name, includedIDs, notIncludedIDs, lastRevision, mInternals);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::DocumentCreateInfo CMDSSQLiteDatabaseManager::documentCreate(const CString& documentType,
		const CString& documentID, const OV<UniversalTime>& creationUniversalTime,
		const OV<UniversalTime>& modificationUniversalTime, const CDictionary& propertyMap)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	UInt32						revision = mInternals->getNextRevision(documentType);
	UniversalTime				creationUniversalTimeUse =
										creationUniversalTime.hasValue() ?
												*creationUniversalTime : SUniversalTime::getCurrent();
	UniversalTime				modificationUniversalTimeUse =
										modificationUniversalTime.hasValue() ?
												*modificationUniversalTime : creationUniversalTimeUse;
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Add to database
	SInt64	id = CDocumentTypeInfoTable::add(documentID, revision, documentTables.getInfoTable());
	CDocumentTypeContentsTable::add(id, creationUniversalTimeUse, modificationUniversalTimeUse, propertyMap,
			documentTables.getContentsTable());

	return DocumentCreateInfo(id, revision, creationUniversalTimeUse, modificationUniversalTimeUse);
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::documentCount(const CString& documentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return count
	return mInternals->getDocumentTables(documentType).getInfoTable().count();
}

//----------------------------------------------------------------------------------------------------------------------
bool CMDSSQLiteDatabaseManager::documentTypeIsKnown(const CString& documentType)
//----------------------------------------------------------------------------------------------------------------------
{
	// Return if found
	return mInternals->mDocumentLastRevisionByDocumentType.contains(documentType);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::documentInfoIterate(const CString& documentType, const TArray<CString>& documentIDs,
		const DocumentInfo::ProcInfo& documentInfoProcInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Iterate rows
	documentTables.getInfoTable().select(
			CSQLiteWhere(CDocumentTypeInfoTable::mDocumentIDTableColumn, SSQLiteValue::valuesFrom(documentIDs)),
			(CSQLiteResultsRow::Proc) CDocumentTypeInfoTable::callDocumentInfoProcInfo, (void*) &documentInfoProcInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::documentContentInfoIterate(const CString& documentType,
		const TArray<DocumentInfo>& documentInfos, const DocumentContentInfo::ProcInfo& documentContentInfoProcInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Iterate rows
	documentTables.getContentsTable().select(
			CSQLiteWhere(CDocumentTypeInfoTable::mIDTableColumn,
					SSQLiteValue::valuesFrom(IDArray(documentInfos,
							(IDArray::MapProc) DocumentInfo::getIDFromDocumentInfo))),
			(CSQLiteResultsRow::Proc) CDocumentTypeContentsTable::callDocumentContentInfoProcInfo,
					(void*) &documentContentInfoProcInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::documentInfoIterate(const CString& documentType, UInt32 sinceRevision,
		const OV<UInt32>& count, bool activeOnly, const DocumentInfo::ProcInfo& documentInfoProcInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Iterate rows
	documentTables.getInfoTable().select(
			activeOnly ?
					CSQLiteWhere(CDocumentTypeInfoTable::mRevisionTableColumn, CString(OSSTR(">")), sinceRevision)
							.addAnd(CDocumentTypeInfoTable::mActiveTableColumn, SSQLiteValue((UInt32) 1)) :
					CSQLiteWhere(CDocumentTypeInfoTable::mRevisionTableColumn, CString(OSSTR(">")), sinceRevision),
			CSQLiteOrderBy(CDocumentTypeInfoTable::mRevisionTableColumn), CSQLiteLimit(count),
			(CSQLiteResultsRow::Proc) CDocumentTypeInfoTable::callDocumentInfoProcInfo, (void*) &documentInfoProcInfo);
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::DocumentUpdateInfo CMDSSQLiteDatabaseManager::documentUpdate(const CString& documentType,
		SInt64 id, const CDictionary& propertyMap)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	UInt32						revision = mInternals->getNextRevision(documentType);
	UniversalTime				modificationUniversalTime = SUniversalTime::getCurrent();
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Update
	CDocumentTypeInfoTable::update(id, revision, documentTables.getInfoTable());
	CDocumentTypeContentsTable::update(id, modificationUniversalTime, propertyMap, documentTables.getContentsTable());

	return DocumentUpdateInfo(revision, modificationUniversalTime);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::documentRemove(const CString& documentType, SInt64 id)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Remove
	CDocumentTypeInfoTable::remove(id, documentTables.getInfoTable());
	CDocumentTypeContentsTable::remove(id, documentTables.getContentsTable());
	CDocumentTypeAttachmentsTable::remove(id, documentTables.getAttachmentsTable());
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::DocumentAttachmentInfo CMDSSQLiteDatabaseManager::documentAttachmentAdd(
		const CString& documentType, SInt64 id, const CDictionary& info, const CData& content)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	UInt32						revision = mInternals->getNextRevision(documentType);
	UniversalTime				modificationUniversalTime = SUniversalTime::getCurrent();
	CString						attachmentID = CUUID().getBase64String();
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Add attachment
	CDocumentTypeInfoTable::update(id, revision, documentTables.getInfoTable());
	CDocumentTypeContentsTable::update(id, modificationUniversalTime, documentTables.getContentsTable());
	UInt32	attachmentRevision =
					CDocumentTypeAttachmentsTable::add(id, attachmentID, info, content,
							documentTables.getAttachmentsTable());

	return DocumentAttachmentInfo(revision, modificationUniversalTime,
			CMDSDocument::AttachmentInfo(attachmentID, attachmentRevision, info));
}

//----------------------------------------------------------------------------------------------------------------------
CMDSDocument::AttachmentInfoByID CMDSSQLiteDatabaseManager::documentAttachmentInfoByID(const CString& documentType,
		SInt64 id)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	return CDocumentTypeAttachmentsTable::getDocumentAttachmentInfoByID(id, documentTables.getAttachmentsTable());
}

//----------------------------------------------------------------------------------------------------------------------
CData CMDSSQLiteDatabaseManager::documentAttachmentContent(const CString& documentType, SInt64 id,
		const CString& attachmentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Retrieve content
	OV<CData>	content;
	documentTables.getAttachmentsTable().select(
			TSArray<CSQLiteTableColumn>(CDocumentTypeAttachmentsTable::mContentTableColumn),
			CSQLiteWhere(CDocumentTypeAttachmentsTable::mAttachmentIDTableColumn, attachmentID),
			(CSQLiteResultsRow::Proc) CDocumentTypeAttachmentsTable::getContent, &content);

	return *content;
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::DocumentAttachmentInfo CMDSSQLiteDatabaseManager::documentAttachmentUpdate(
		const CString& documentType, SInt64 id, const CString& attachmentID, const CDictionary& updatedInfo,
		const CData& updatedContent)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	UInt32						revision = mInternals->getNextRevision(documentType);
	UniversalTime				modificationUniversalTime = SUniversalTime::getCurrent();
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Update attachment
	CDocumentTypeInfoTable::update(id, revision, documentTables.getInfoTable());
	CDocumentTypeContentsTable::update(id, modificationUniversalTime, documentTables.getContentsTable());
	UInt32	attachmentRevision =
					CDocumentTypeAttachmentsTable::update(id, attachmentID, updatedInfo, updatedContent,
							documentTables.getAttachmentsTable());

	return DocumentAttachmentInfo(revision, modificationUniversalTime,
			CMDSDocument::AttachmentInfo(attachmentID, attachmentRevision, updatedInfo));
}

//----------------------------------------------------------------------------------------------------------------------
CMDSSQLiteDatabaseManager::DocumentAttachmentRemoveInfo CMDSSQLiteDatabaseManager::documentAttachmentRemove(
		const CString& documentType, SInt64 id, const CString& attachmentID)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	UInt32						revision = mInternals->getNextRevision(documentType);
	UniversalTime				modificationUniversalTime = SUniversalTime::getCurrent();
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);

	// Remove attachment
	CDocumentTypeInfoTable::update(id, revision, documentTables.getInfoTable());
	CDocumentTypeContentsTable::update(id, modificationUniversalTime, documentTables.getContentsTable());
	CDocumentTypeAttachmentsTable::remove(id, attachmentID, documentTables.getAttachmentsTable());

	return DocumentAttachmentRemoveInfo(revision, modificationUniversalTime);
}

//----------------------------------------------------------------------------------------------------------------------
UInt32 CMDSSQLiteDatabaseManager::indexRegister(const CString& name, const CString& documentType,
		const TArray<CString>& relevantProperties, const CString& keysSelector, const CDictionary& keysSelectorInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get current info
	OV<IndexInfo>	currentInfo = CIndexesTable::getInfo(name, mInternals->mIndexesTable);

	// Setup table
	CSQLiteTable	indexContentsTable =
							CIndexContentsTable::in(mInternals->mDatabase, name, mInternals->mInternalsTable);
	mInternals->mIndexTablesByName.set(name, indexContentsTable);

	// Compose next steps
	UInt32	lastRevision;
	bool	updateMasterTable;
	if (!currentInfo.hasValue()) {
		// New
		lastRevision = 0;
		updateMasterTable = true;
	} else if ((relevantProperties != currentInfo->getRelevantProperties()) ||
			(keysSelector != currentInfo->getKeysSelector()) ||
			(keysSelectorInfo != currentInfo->getKeysSelectorInfo())) {
		// Info has changed
		lastRevision = 0;
		updateMasterTable = true;
	} else {
		// No change
		lastRevision = currentInfo->getLastRevision();
		updateMasterTable = false;
	}

	// Check if need to update the master table
	if (updateMasterTable) {
		// New or updated
		CIndexesTable::addOrUpdate(name, documentType, relevantProperties, keysSelector,
				keysSelectorInfo, lastRevision, mInternals->mIndexesTable);

		// Update table
		if (currentInfo.hasValue())	indexContentsTable.drop();
		indexContentsTable.create();
	}

	return lastRevision;
}

//----------------------------------------------------------------------------------------------------------------------
OV<IndexInfo> CMDSSQLiteDatabaseManager::indexInfo(const CString& name)
//----------------------------------------------------------------------------------------------------------------------
{
	// Get info
	OV<IndexInfo>	indexInfo = CIndexesTable::getInfo(name, mInternals->mIndexesTable);
	if (indexInfo.hasValue()) {
		// Found
		CSQLiteTable	indexContentsTable =
								CIndexContentsTable::in(mInternals->mDatabase, name, mInternals->mInternalsTable);
		mInternals->mIndexTablesByName.set(name, indexContentsTable);
	}

	return indexInfo;
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::indexIterateDocumentInfos(const CString& name, const CString& documentType,
		const TArray<CString>& keys, const DocumentInfo::KeyProcInfo& documentInfoKeyProcInfo)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	Internals::DocumentTables&	documentTables = mInternals->getDocumentTables(documentType);
	CSQLiteTable&				indexContentsTable = *mInternals->mIndexTablesByName.get(name);

	// Iterate rows
	indexContentsTable.select(
			CSQLiteInnerJoin(indexContentsTable, CIndexContentsTable::mIDTableColumn,
					documentTables.getInfoTable()),
			CSQLiteWhere(CIndexContentsTable::mKeyTableColumn, SSQLiteValue::valuesFrom(keys)),
			(CSQLiteResultsRow::Proc) CIndexContentsTable::callDocumentInfoKeyProcInfo,
			(void*) &documentInfoKeyProcInfo);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::indexUpdate(const CString& name, const OV<TArray<IndexKeysInfo> >& indexKeysInfos,
		const OV<IDArray >& removedIDs, const OV<UInt32>& lastRevision)
//----------------------------------------------------------------------------------------------------------------------
{
	// Check if in batch
	const	OR<Internals::BatchInfo>	batchInfo = mInternals->mBatchInfoByThreadRef[CThread::getCurrentRef()];
	if (batchInfo.hasReference())
		// Update batch info
		batchInfo->noteIndexUpdate(name, indexKeysInfos, removedIDs, lastRevision);
	else
		// Update
		Internals::indexUpdate(name, indexKeysInfos, removedIDs, lastRevision, mInternals);
}

//----------------------------------------------------------------------------------------------------------------------
OV<CString> CMDSSQLiteDatabaseManager::infoString(const CString& key)
//----------------------------------------------------------------------------------------------------------------------
{
	return CInfoTable::getString(key, mInternals->mInfoTable);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::infoSet(const CString& key, const OV<CString>& string)
//----------------------------------------------------------------------------------------------------------------------
{
	CInfoTable::set(key, string, mInternals->mInfoTable);
}

//----------------------------------------------------------------------------------------------------------------------
OV<CString> CMDSSQLiteDatabaseManager::internalString(const CString& key)
//----------------------------------------------------------------------------------------------------------------------
{
	return CInternalTable::getString(key, mInternals->mInternalTable);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::internalSet(const CString& key, const OV<CString>& string)
//----------------------------------------------------------------------------------------------------------------------
{
	CInternalTable::set(key, string, mInternals->mInternalTable);
}

//----------------------------------------------------------------------------------------------------------------------
void CMDSSQLiteDatabaseManager::batch(BatchProc batchProc, void* userData)
//----------------------------------------------------------------------------------------------------------------------
{
	// Setup
	mInternals->mBatchInfoByThreadRef.set(CThread::getCurrentRefAsString(), Internals::BatchInfo());

	// Call proc
	batchProc(userData);

	// Commit changes
	Internals::BatchInfo	batchInfo = *mInternals->mBatchInfoByThreadRef.get(CThread::getCurrentRefAsString());
	mInternals->mBatchInfoByThreadRef.remove(CThread::getCurrentRefAsString());

	for (TIteratorS<CString> iterator = batchInfo.getDocumentLastRevisionTypesNeedingWrite().getIterator();
			iterator.hasValue(); iterator.advance())
		// Update
		CDocumentsTable::set(**mInternals->mDocumentLastRevisionByDocumentType.get(*iterator), *iterator,
				mInternals->mDocumentsTable);
	for (TIteratorS<CDictionary::Item> iterator = batchInfo.getCacheUpdateInfoByName().getIterator();
			iterator.hasValue(); iterator.advance()) {
		// Setup
		const	Internals::CacheUpdateInfo&	cacheUpdateInfo =
															*((Internals::CacheUpdateInfo*)
																	iterator->mValue.getOpaque());

		// Update cache
		Internals::cacheUpdate(iterator->mKey, cacheUpdateInfo.getValueInfoByID(),
				cacheUpdateInfo.getRemovedIDs(), cacheUpdateInfo.getLastRevision(), mInternals);
	}
	for (TIteratorS<CDictionary::Item> iterator = batchInfo.getCollectionUpdateInfoByName().getIterator();
			iterator.hasValue(); iterator.advance()) {
		// Setup
		const	Internals::CollectionUpdateInfo&	collectionUpdateInfo =
															*((Internals::CollectionUpdateInfo*)
																	iterator->mValue.getOpaque());

		// Update collection
		Internals::collectionUpdate(iterator->mKey, collectionUpdateInfo.getIncludedIDs(),
				collectionUpdateInfo.getNotIncludedIDs(), collectionUpdateInfo.getLastRevision(), mInternals);
	}
	for (TIteratorS<CDictionary::Item> iterator = batchInfo.getIndexUpdateInfoByName().getIterator();
			iterator.hasValue(); iterator.advance()) {
		// Setup
		const	Internals::IndexUpdateInfo&	indexUpdateInfo =
													*((Internals::IndexUpdateInfo*) iterator->mValue.getOpaque());

		// Update index
		Internals::indexUpdate(iterator->mKey, indexUpdateInfo.getIndexKeysInfos(), indexUpdateInfo.getRemovedIDs(),
				indexUpdateInfo.getLastRevision(), mInternals);
	}
}
