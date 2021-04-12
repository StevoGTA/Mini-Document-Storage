package codes.stevobrock.minidocumentstorage.sqlite

import codes.stevobrock.androidtoolbox.concurrency.LockingHashMap
import codes.stevobrock.androidtoolbox.extensions.dateFromRFC3339Extended
import codes.stevobrock.androidtoolbox.extensions.rfc3339Extended
import codes.stevobrock.androidtoolbox.model.JSONConverter
import codes.stevobrock.androidtoolbox.sqlite.*
import codes.stevobrock.androidtoolbox.sqlite.SQLiteTableColumn.Options
import codes.stevobrock.androidtoolbox.sqlite.SQLiteTableColumn.Kind
import codes.stevobrock.minidocumentstorage.MDSDocument
import codes.stevobrock.minidocumentstorage.MDSIndex
import java.sql.SQLWarning
import java.util.*
import kotlin.collections.HashMap
import kotlin.collections.HashSet

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
class MDSSQLiteDatabaseManager {

	// Types
			data class NewInfo(val id :Long, val revision :Int, val creationDate :Date, val modificationDate :Date)
			data class Info(val id :Long, val documentRevisionInfo :MDSDocument.RevisionInfo, val active :Boolean)

	private	data class DocumentTables(val infoTable :SQLiteTable, val contentTable :SQLiteTable)

	private	data class CollectionUpdateInfo(val includedIDs :List<Long>, val notIncludedIDs :List<Long>,
						val lastRevision :Int)
	private	data class IndexUpdateInfo(val keysInfos : List<MDSIndex.UpdateInfoKeysInfo<Long>>,
						val removedIDs :List<Long>, val lastRevision :Int)

	//------------------------------------------------------------------------------------------------------------------
	private class BatchInfo {

		// Properties
		var	documentLastRevisionTypesNeedingWrite = HashSet<String>()
		var	collectionInfo = HashMap</* collection name */ String, CollectionUpdateInfo>()
		var	indexInfo = HashMap</* index name */ String, IndexUpdateInfo>()
	}

	//------------------------------------------------------------------------------------------------------------------
	private class InfoTable {

		// Companion object
		//--------------------------------------------------------------------------------------------------------------
		companion object {

			// Properties
			val keyTableColumn =
						SQLiteTableColumn("key", Kind.TEXT,
						Options.PRIMARY_KEY or Options.UNIQUE or Options.NOT_NULL)
			val valueTableColumn = SQLiteTableColumn("value", Kind.TEXT, Options.NOT_NULL)
			val	tableColumns = listOf(this.keyTableColumn, this.valueTableColumn)

			// Methods
			//----------------------------------------------------------------------------------------------------------
			fun create(database :SQLiteDatabase) :SQLiteTable {
				// Create table
				val	table = database.table("Info", SQLiteTable.Options.WITHOUT_ROWID, this.tableColumns)
				table.create()

				return table
			}

			//----------------------------------------------------------------------------------------------------------
			fun int(key :String, table :SQLiteTable) :Int? {
				// Reterieve value
				var	value :Int? = null
				table.selectTableColumns(listOf(this.valueTableColumn),
						where = SQLiteWhere(tableColumn = this.keyTableColumn, value = key)) {
					// Process values
					value = it.text(this.valueTableColumn)!!.toIntOrNull()
				}

				return value
			}

			//----------------------------------------------------------------------------------------------------------
			fun string(key :String, table :SQLiteTable) :String? {
				// Retrieve value
				var	value :String? = null
				table.selectTableColumns(listOf(this.valueTableColumn),
						where = SQLiteWhere(tableColumn = this.keyTableColumn, value = key)
				) {
					// Process values
					value = it.text(this.valueTableColumn)
				}

				return value
			}

			//----------------------------------------------------------------------------------------------------------
			fun set(key :String, value :Any?, table :SQLiteTable) {
				// Check if storing or removing
				if (value != null)
					// Storing
					table.insertOrReplaceRow(
							listOf(
									SQLiteTableColumnAndValue(this.keyTableColumn, key),
									SQLiteTableColumnAndValue(this.valueTableColumn, value),
								  ))
				else
					// Removing
					table.deleteRows(this.keyTableColumn, listOf(key))
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private class DocumentsTable {

		// Companion object
		//--------------------------------------------------------------------------------------------------------------
		companion object {

			// Properties
			val	typeTableColumn =
						SQLiteTableColumn("type", Kind.TEXT, Options.NOT_NULL or Options.UNIQUE)
			val	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", Kind.INTEGER, Options.NOT_NULL)
			val	tableColumns = listOf(this.typeTableColumn, this.lastRevisionTableColumn)

			// Methods
			//----------------------------------------------------------------------------------------------------------
			fun create(database :SQLiteDatabase, version :Int?) :SQLiteTable {
				// Create table
				val	table = database.table("Documents", tableColumns = this.tableColumns)
				if (version == null) table.create()

				return table
			}

			//----------------------------------------------------------------------------------------------------------
			fun iterate(table :SQLiteTable, proc :(documentType :String, lastRevision :Int) -> Unit) {
				// Iterate
				table.selectTableColumns() {
					// Process results
					val	documentType = it.text(this.typeTableColumn)!!
					val	lastRevision = it.integer(this.lastRevisionTableColumn)!!

					// Call proc
					proc(documentType, lastRevision)
				}
			}

			//----------------------------------------------------------------------------------------------------------
			fun set(lastRevision :Int, documentType :String, table :SQLiteTable) {
				// Insert or replace row
				table.insertOrReplaceRow(
						listOf(
								SQLiteTableColumnAndValue(this.typeTableColumn, documentType),
								SQLiteTableColumnAndValue(this.lastRevisionTableColumn, lastRevision),
							  ))
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private class DocumentTypeInfoTable {

		// Companion object
		//--------------------------------------------------------------------------------------------------------------
		companion object {

			// Properties
			val	idTableColumn =
						SQLiteTableColumn("id", Kind.INTEGER,
								Options.PRIMARY_KEY or Options.AUTO_INCREMENT)
			val	documentIDTableColumn =
						SQLiteTableColumn("documentID", Kind.TEXT, Options.NOT_NULL or Options.UNIQUE)
			val	revisionTableColumn = SQLiteTableColumn("revision", Kind.INTEGER, Options.NOT_NULL)
			val	activeTableColumn = SQLiteTableColumn("active", Kind.INTEGER, Options.NOT_NULL)
			val	tableColumns =
						listOf(this.idTableColumn, this.documentIDTableColumn, this.revisionTableColumn,
								this.activeTableColumn)

			// Methods
			//----------------------------------------------------------------------------------------------------------
			fun create(database :SQLiteDatabase, nameRoot :String, version :Int) :SQLiteTable {
				// Create table
				val	table = database.table("${nameRoot}s", tableColumns = this.tableColumns)
				table.create()

				return table
			}

			//----------------------------------------------------------------------------------------------------------
			fun info(resultsRow :SQLiteResultsRow) :Info {
				// Process results
				val	id = resultsRow.integer(this.idTableColumn)!!.toLong()
				val	documentID = resultsRow.text(this.documentIDTableColumn)!!
				val	revision = resultsRow.integer(this.revisionTableColumn)!!
				val	active = resultsRow.integer(this.activeTableColumn)!! == 1

				return Info(id, MDSDocument.RevisionInfo(documentID, revision), active)
			}

			//----------------------------------------------------------------------------------------------------------
			fun add(documentID :String, revision :Int, table :SQLiteTable) :Long {
				// Insert
				return table.insertRow(listOf(
												SQLiteTableColumnAndValue(this.documentIDTableColumn, documentID),
												SQLiteTableColumnAndValue(this.revisionTableColumn, revision),
												SQLiteTableColumnAndValue(this.activeTableColumn, 1),
											 ))
			}

			//----------------------------------------------------------------------------------------------------------
			fun update(id :Long, revision :Int, table :SQLiteTable) {
				// Update
				table.update(listOf(SQLiteTableColumnAndValue(this.revisionTableColumn, revision)),
						SQLiteWhere(tableColumn = this.idTableColumn, value = id))
			}

			//----------------------------------------------------------------------------------------------------------
			fun remove(id :Long, table :SQLiteTable) {
				// Update
				table.update(listOf(SQLiteTableColumnAndValue(this.activeTableColumn, 0)),
						SQLiteWhere(tableColumn = this.idTableColumn, value = id)
				)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private class DocumentTypeContentTable {

		// Companion object
		//--------------------------------------------------------------------------------------------------------------
		companion object {

			// Properties
			val	idTableColumn = SQLiteTableColumn("id", Kind.INTEGER, Options.PRIMARY_KEY)
			val	creationDateTableColumn = SQLiteTableColumn("creationDate", Kind.TEXT, Options.NOT_NULL)
			val	modificationDateTableColumn = SQLiteTableColumn("modificationDate", Kind.TEXT, Options.NOT_NULL)
			val	jsonTableColumn = SQLiteTableColumn("json", Kind.BLOB, Options.NOT_NULL)
			val	tableColumns =
							listOf(this.idTableColumn, this.creationDateTableColumn, this.modificationDateTableColumn,
									this.jsonTableColumn)

			// Methods
			//----------------------------------------------------------------------------------------------------------
			fun create(database :SQLiteDatabase, nameRoot :String, infoTable :SQLiteTable, version :Int) :SQLiteTable {
				// Create table
				val	table =
							database.table("${nameRoot}Contents", tableColumns = this.tableColumns,
									references =
											listOf(
													SQLiteTableColumnReference(this.idTableColumn, infoTable,
															DocumentTypeInfoTable.idTableColumn)))
				table.create()

				return table
			}

			//----------------------------------------------------------------------------------------------------------
			fun documentBackingInfo(info :Info, resultsRow :SQLiteResultsRow)
					:MDSDocument.BackingInfo<MDSSQLiteDocumentBacking> {
				// Process results
				val	creationDate = dateFromRFC3339Extended(resultsRow.text(this.creationDateTableColumn)!!)!!
				val	modificationDate = dateFromRFC3339Extended(resultsRow.text(this.modificationDateTableColumn)!!)!!
				val	propertyMap =
							JSONConverter<HashMap<String, Any>>().fromJson(resultsRow.blob(this.jsonTableColumn)!!)

				return MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(info.documentRevisionInfo.documentID,
						MDSSQLiteDocumentBacking(info.id, info.documentRevisionInfo.revision, creationDate,
								modificationDate, propertyMap, info.active))
			}

			//----------------------------------------------------------------------------------------------------------
			fun add(id :Long, creationDate :Date, modificationDate :Date, propertyMap :Map<String, Any>,
					table :SQLiteTable) {
				// Insert
				table.insertRow(
						listOf(
								SQLiteTableColumnAndValue(this.idTableColumn, id),
								SQLiteTableColumnAndValue(this.creationDateTableColumn, creationDate.rfc3339Extended),
								SQLiteTableColumnAndValue(this.modificationDateTableColumn,
										modificationDate.rfc3339Extended),
								SQLiteTableColumnAndValue(this.jsonTableColumn,
										JSONConverter<Map<String, Any>>().toJsonByteArray(propertyMap)),
							  ))
			}

			//----------------------------------------------------------------------------------------------------------
			fun update(id :Long, modificationDate :Date, propertyMap :Map<String, Any>, table :SQLiteTable) {
				// Update
				table.update(
						listOf(
								SQLiteTableColumnAndValue(this.modificationDateTableColumn,
										modificationDate.rfc3339Extended),
								SQLiteTableColumnAndValue(this.jsonTableColumn,
										JSONConverter<Map<String, Any>>().toJsonByteArray(propertyMap)),
							  ),
						SQLiteWhere(tableColumn = this.idTableColumn, value = id))
			}

			//----------------------------------------------------------------------------------------------------------
			fun remove(id :Long, table :SQLiteTable) {
				// Update
				table.update(
						listOf(
								SQLiteTableColumnAndValue(this.modificationDateTableColumn, Date().rfc3339Extended),
								SQLiteTableColumnAndValue(this.jsonTableColumn,
										JSONConverter<Map<String, Any>>().toJsonByteArray(mapOf())),
							  ),
						SQLiteWhere(tableColumn = this.idTableColumn, value = id))
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private class CollectionsTable {

		// Companion object
		//--------------------------------------------------------------------------------------------------------------
		companion object {

			// Properties
			val	nameTableColumn =
						SQLiteTableColumn("name", Kind.TEXT, Options.NOT_NULL or Options.UNIQUE)
			val	versionTableColumn = SQLiteTableColumn("version", Kind.INTEGER, Options.NOT_NULL)
			val	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", Kind.INTEGER, Options.NOT_NULL)
			val	tableColumns = listOf(this.nameTableColumn, this.versionTableColumn, this.lastRevisionTableColumn)

			// Methods
			//----------------------------------------------------------------------------------------------------------
			fun create(database :SQLiteDatabase, version :Int?) :SQLiteTable {
				// Create table
				val	table = database.table("Collections", tableColumns = this.tableColumns)
				if (version == null) table.create()

				return table
			}

			//----------------------------------------------------------------------------------------------------------
			fun info(name :String, table :SQLiteTable) :Pair<Int?, Int?> {
				// Query
				var	version :Int? = null
				var	lastRevision :Int? = null
				table.selectTableColumns(listOf(this.versionTableColumn, this.lastRevisionTableColumn),
						where = SQLiteWhere(tableColumn = this.nameTableColumn, value = name)) {
					// Process results
					version = it.integer(this.versionTableColumn)!!
					lastRevision = it.integer(this.lastRevisionTableColumn)!!
				}

				return Pair(version, lastRevision)
			}

			//----------------------------------------------------------------------------------------------------------
			fun update(name :String, version :Int, lastRevision :Int, table :SQLiteTable) {
				// Insert or replace
				table.insertOrReplaceRow(
						listOf(
								SQLiteTableColumnAndValue(this.nameTableColumn, name),
								SQLiteTableColumnAndValue(this.versionTableColumn, version),
								SQLiteTableColumnAndValue(this.lastRevisionTableColumn, lastRevision),
							  ))
			}

			//----------------------------------------------------------------------------------------------------------
			fun update(name :String, lastRevision :Int, table :SQLiteTable) {
				// Update
				table.update(listOf(SQLiteTableColumnAndValue(this.lastRevisionTableColumn, lastRevision)),
						SQLiteWhere(tableColumn = this.nameTableColumn, value = name))
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private class CollectionContentsTable {

		// Companion object
		//--------------------------------------------------------------------------------------------------------------
		companion object {

			// Properties
			val	idTableColumn = SQLiteTableColumn("id", Kind.INTEGER, Options.PRIMARY_KEY)
			val tableColumns = listOf(this.idTableColumn)

			// Methods
			//----------------------------------------------------------------------------------------------------------
			fun create(database :SQLiteDatabase, name :String, version :Int) :SQLiteTable {
				// Create table
				return database.table("Collection-$name", SQLiteTable.Options.WITHOUT_ROWID, this.tableColumns)
			}

			//----------------------------------------------------------------------------------------------------------
			fun iterate(table :SQLiteTable, documentInfoTable :SQLiteTable, proc :(info :Info) -> Unit) {
				// Select
				table.selectTableColumns(innerJoin = SQLiteInnerJoin(table, this.idTableColumn, documentInfoTable))
					{ proc(DocumentTypeInfoTable.info(it)) }
			}

			//----------------------------------------------------------------------------------------------------------
			fun update(includedIDs :List<Long>, notIncludedIDs :List<Long>, table :SQLiteTable) {
				// Update
				if (notIncludedIDs.isNotEmpty()) table.deleteRows(this.idTableColumn, notIncludedIDs)
				if (includedIDs.isNotEmpty()) table.insertOrReplaceRows(this.idTableColumn, includedIDs)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private class IndexesTable {

		// Companion object
		//--------------------------------------------------------------------------------------------------------------
		companion object {

			// Properties
			val	nameTableColumn = SQLiteTableColumn("name", Kind.TEXT, Options.NOT_NULL or Options.UNIQUE)
			val	versionTableColumn = SQLiteTableColumn("version", Kind.INTEGER, Options.NOT_NULL)
			val	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", Kind.INTEGER, Options.NOT_NULL)
			val	tableColumns = listOf(this.nameTableColumn, this.versionTableColumn, this.lastRevisionTableColumn)

			// Methods
			//----------------------------------------------------------------------------------------------------------
			fun create(database :SQLiteDatabase, version :Int?) :SQLiteTable {
				// Create table
				val	table = database.table("Indexes", tableColumns = this.tableColumns)
				if (version == null) table.create()

				return table
			}

			//----------------------------------------------------------------------------------------------------------
			fun info(name :String, table :SQLiteTable) :Pair<Int?, Int?> {
				// Query
				var	version :Int? = null
				var lastRevision :Int? = null
				table.selectTableColumns(listOf(this.versionTableColumn, this.lastRevisionTableColumn),
						where = SQLiteWhere(tableColumn = this.nameTableColumn, value = name)) {
							// Process results
							version = it.integer(this.versionTableColumn)!!
							lastRevision = it.integer(this.lastRevisionTableColumn)!!
						}

				return Pair(version, lastRevision)
			}

			//----------------------------------------------------------------------------------------------------------
			fun update(name :String, version :Int, lastRevision :Int, table :SQLiteTable) {
				// Insert or replace
				table.insertOrReplaceRow(
						listOf(
								SQLiteTableColumnAndValue(this.nameTableColumn, name),
								SQLiteTableColumnAndValue(this.versionTableColumn, version),
								SQLiteTableColumnAndValue(this.lastRevisionTableColumn, lastRevision),
							  ))
			}

			//----------------------------------------------------------------------------------------------------------
			fun update(name :String, lastRevision :Int, table :SQLiteTable) {
				// Update
				table.update(listOf(SQLiteTableColumnAndValue(this.lastRevisionTableColumn, lastRevision)),
						SQLiteWhere(tableColumn = this.nameTableColumn, value = name))
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private class IndexContentsTable {

		// Companion object
		//--------------------------------------------------------------------------------------------------------------
		companion object {

			// Properties
			val	keyTableColumn = SQLiteTableColumn("key", Kind.TEXT, Options.PRIMARY_KEY)
			val	idTableColumn = SQLiteTableColumn("id", Kind.INTEGER, Options.NOT_NULL)
			val	tableColumns = listOf(this.keyTableColumn, this.idTableColumn)

			// Methods
			//----------------------------------------------------------------------------------------------------------
			fun create(database :SQLiteDatabase, name :String, version :Int) :SQLiteTable {
				// Create table
				return database.table("Index-$name", SQLiteTable.Options.WITHOUT_ROWID, this.tableColumns)
			}

			//----------------------------------------------------------------------------------------------------------
			fun key(resultsRow :SQLiteResultsRow) :String { return resultsRow.text(this.keyTableColumn)!! }

			//----------------------------------------------------------------------------------------------------------
			fun iterate(table :SQLiteTable, documentInfoTable :SQLiteTable, keys :List<String>,
					proc :(key :String, info :Info) -> Unit) {
				// Select
				documentInfoTable.selectTableColumns(
						innerJoin = SQLiteInnerJoin(documentInfoTable, DocumentTypeInfoTable.idTableColumn, table),
						where = SQLiteWhere(tableColumn = this.keyTableColumn, values = keys))
						{ proc(it.text(this.keyTableColumn)!!, DocumentTypeInfoTable.info(it)) }
			}

			//----------------------------------------------------------------------------------------------------------
			fun update(keysInfos :List<MDSIndex.UpdateInfoKeysInfo<Long>>, removedIDs :List<Long>, table :SQLiteTable) {
				// Setup
				val	idsToRemove = removedIDs + keysInfos.map() { it.value }

				// Update tables
				if (idsToRemove.isNotEmpty()) table.deleteRows(this.idTableColumn, idsToRemove)
				keysInfos.forEach() { keysInfo -> keysInfo.keys.forEach() {
					// Insert this key
					table.insertRow(
							listOf(
									SQLiteTableColumnAndValue(this.keyTableColumn, it),
									SQLiteTableColumnAndValue(this.idTableColumn, keysInfo.value),
								  ))
				} }
			}
		}
	}

	// Properties
	private	val database :SQLiteDatabase
	private	var	databaseVersion :Int?

	private	val infoTable :SQLiteTable

	private	val documentsMasterTable :SQLiteTable
	private	val	documentTablesMap = LockingHashMap</* Document type */ String, DocumentTables>()
	private	val	documentLastRevisionMap = LockingHashMap</* Document type */ String, Int>()

	private	val	collectionsMasterTable :SQLiteTable
	private	val collectionTablesMap = LockingHashMap</* Collection name */ String, SQLiteTable>()

	private	val indexesMasterTable :SQLiteTable
	private	val indexTablesMap = LockingHashMap</* Index name */ String, SQLiteTable>()

	private	val batchInfoMap = LockingHashMap<Thread, BatchInfo>()

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(database :SQLiteDatabase) {
		// Store
		this.database = database

		// Create tables
		this.infoTable = InfoTable.create(this.database)
		this.databaseVersion = InfoTable.int("version", this.infoTable)

		this.documentsMasterTable = DocumentsTable.create(this.database, this.databaseVersion)
		this.collectionsMasterTable = CollectionsTable.create(this.database, this.databaseVersion)
		this.indexesMasterTable = IndexesTable.create(this.database, this.databaseVersion)

		// Finalize setup
		if (this.databaseVersion == null) {
			// Update version
			this.databaseVersion = 1
			InfoTable.set("version", this.databaseVersion, this.infoTable)
		}

		DocumentsTable.iterate(this.documentsMasterTable)
				{ documentType, lastRevision -> this.documentLastRevisionMap.set(documentType, lastRevision) }
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	fun int(key :String) :Int? { return InfoTable.int(key, this.infoTable) }

	//------------------------------------------------------------------------------------------------------------------
	fun string(key :String) :String? { return InfoTable.string(key, this.infoTable) }

	//------------------------------------------------------------------------------------------------------------------
	fun set(key :String, value :Any?) { InfoTable.set(key, value, this.infoTable) }

	//------------------------------------------------------------------------------------------------------------------
	fun note(documentType :String) { documentTables(documentType) }

	//------------------------------------------------------------------------------------------------------------------
	fun batch(proc :() -> Unit) {
		// Setup
		this.batchInfoMap.set(Thread.currentThread(), BatchInfo())

		// Call proc
		proc()

		// Commit changes
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())!!
		this.batchInfoMap.remove(Thread.currentThread())

		batchInfo.documentLastRevisionTypesNeedingWrite.forEach()
				{ DocumentsTable.set(this.documentLastRevisionMap.value(it)!!, it, this.documentsMasterTable) }
		batchInfo.collectionInfo.forEach()
				{ updateCollection(it.key, it.value.includedIDs, it.value.notIncludedIDs, it.value.lastRevision) }
		batchInfo.indexInfo.forEach()
				{ updateIndex(it.key, it.value.keysInfos, it.value.removedIDs, it.value.lastRevision) }
	}

	//------------------------------------------------------------------------------------------------------------------
	fun new(documentType :String, documentID :String, creationDate :Date? = null, modificationDate :Date? = null,
			propertyMap :Map<String, Any>) :NewInfo {
		// Setup
		val revision = nextRevision(documentType)
		val	creationDateUse = creationDate ?: Date()
		val modificationDateUse = modificationDate ?: creationDateUse
		val	(infoTable, contentTable) = documentTables(documentType)

		// Add to database
		val	id = DocumentTypeInfoTable.add(documentID, revision, infoTable)
		DocumentTypeContentTable.add(id, creationDateUse, modificationDateUse, propertyMap, contentTable)

		return NewInfo(id, revision, creationDateUse, modificationDateUse)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun iterate(documentType :String, innerJoin :SQLiteInnerJoin? = null, where :SQLiteWhere? = null,
			proc :(info :Info, resultsRow :SQLiteResultsRow) -> Unit) {
		// Setup
		val (infoTable, _) = documentTables(documentType)

		// Retrieve and iterate
		infoTable.selectTableColumns(innerJoin = innerJoin, where = where) { proc(DocumentTypeInfoTable.info(it), it) }
	}

	//------------------------------------------------------------------------------------------------------------------
	fun update(documentType :String, id :Long, propertyMap :Map<String, Any>) :Pair<Int, Date> {
		// Setup
		val revision = nextRevision(documentType)
		val modificationDate = Date()
		val	(infoTable, contentTable) = documentTables(documentType)

		// Update
		DocumentTypeInfoTable.update(id, revision, infoTable)
		DocumentTypeContentTable.update(id, modificationDate, propertyMap, contentTable)

		return Pair(revision, modificationDate)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun remove(documentType :String, id :Long) {
		// Setup
		val	(infoTable, contentTable) = documentTables(documentType)

		// Remove
		DocumentTypeInfoTable.remove(id, infoTable)
		DocumentTypeContentTable.remove(id, contentTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun registerCollection(documentType :String, name :String, version :Int, isUpToDate :Boolean) :Int {
		// Get current info
		val	(storedVersion, storedLastRevision) = CollectionsTable.info(name, this.collectionsMasterTable)

		// Setup table
		val	collectionContentsTable = CollectionContentsTable.create(this.database, name, this.databaseVersion!!)
		this.collectionTablesMap.set(name, collectionContentsTable)

		// Compose last revision
		val lastRevision :Int
		val updateMasterTable :Boolean
		if (storedLastRevision == null) {
			// New
			lastRevision = if (isUpToDate) this.documentLastRevisionMap.value(documentType) ?: 0 else 0
			updateMasterTable = true
		} else if (version != storedVersion) {
			// Updated version
			lastRevision = 0
			updateMasterTable = true
		} else {
			// No change
			lastRevision = storedLastRevision
			updateMasterTable = false
		}

		// Check if need to update the master table
		if (updateMasterTable) {
			// New or updated
			CollectionsTable.update(name, version, lastRevision, this.collectionsMasterTable)

			// Update table
			if (storedLastRevision != null) collectionContentsTable.drop()
			collectionContentsTable.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	fun queryCollectionDocumentCount(name :String) :Int { return this.collectionTablesMap.value(name)!!.count() }

	//------------------------------------------------------------------------------------------------------------------
	fun iterateCollection(name :String, documentType :String, proc :(info :Info) -> Unit) {
		// Setup
		val	(infoTable, _) = documentTables(documentType)
		val	collectionContentsTable = this.collectionTablesMap.value(name)!!

		// Iterate
		CollectionContentsTable.iterate(collectionContentsTable, infoTable, proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun updateCollection(name :String, includedIDs :List<Long>, notIncludedIDs :List<Long>, lastRevision :Int) {
		// Check if in batch
		val batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo != null) {
			// Update batch info
			val collectionUpdateInfo = batchInfo.collectionInfo[name]
			batchInfo.collectionInfo[name] =
					CollectionUpdateInfo((collectionUpdateInfo?.includedIDs ?: listOf())!! + includedIDs,
						(collectionUpdateInfo?.notIncludedIDs ?: listOf())!! + notIncludedIDs,
						lastRevision)
		} else {
			// Update tables
			CollectionsTable.update(name, lastRevision, this.collectionsMasterTable)
			CollectionContentsTable.update(includedIDs, notIncludedIDs, this.collectionTablesMap.value(name)!!)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	fun registerIndex(documentType :String, name :String, version :Int, isUpToDate :Boolean) :Int {
		// Get current info
		val (storedVersion, storedLastRevision) = IndexesTable.info(name, this.indexesMasterTable)

		// Setup table
		val	indexContentsTable = IndexContentsTable.create(this.database, name, this.databaseVersion!!)
		this.indexTablesMap.set(name, indexContentsTable)

		// Compose last revision
		val lastRevision :Int
		val updateMasterTable :Boolean
		if (storedLastRevision == null) {
			// New
			lastRevision = if (isUpToDate) this.documentLastRevisionMap.value(documentType) ?: 0 else 0
			updateMasterTable = true
		} else if (version != storedVersion) {
			// Updated version
			lastRevision = 0
			updateMasterTable = true
		} else {
			// No change
			lastRevision = storedLastRevision
			updateMasterTable = false
		}

		// Check if need to update the master table
		if (updateMasterTable) {
			// New or updated
			IndexesTable.update(name, version, lastRevision, this.indexesMasterTable)

			// Update table
			if (storedLastRevision != null) indexContentsTable.drop()
			indexContentsTable.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	fun iterateIndex(name :String, documentType :String, keys :List<String>, proc :(key :String, info :Info) -> Unit) {
		// Setup
		val	(infoTable, _) = documentTables(documentType)
		val	indexContentsTable = this.indexTablesMap.value(name)!!

		// Iterate
		IndexContentsTable.iterate(indexContentsTable, infoTable, keys, proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun updateIndex(name :String, keysInfos :List<MDSIndex.UpdateInfoKeysInfo<Long>>, removedIDs :List<Long>,
			lastRevision :Int) {
		// Check if in batch
		val batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo != null) {
			// Update batch info
			val	indexInfo = batchInfo.indexInfo[name]
			batchInfo.indexInfo[name] =
					IndexUpdateInfo((indexInfo?.keysInfos ?: listOf())!! + keysInfos,
						(indexInfo?.removedIDs ?: listOf())!! + removedIDs, lastRevision)
		} else {
			// Update tables
			IndexesTable.update(name, lastRevision, this.indexesMasterTable)
			IndexContentsTable.update(keysInfos, removedIDs, this.indexTablesMap.value(name)!!)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	fun innerJoin(documentType :String) :SQLiteInnerJoin {
		// Setup
		val	(infoTable, contentTable) = documentTables(documentType)

		return SQLiteInnerJoin(infoTable, DocumentTypeInfoTable.idTableColumn, contentTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun innerJoinForCollection(documentType :String, collectionName :String) :SQLiteInnerJoin {
		// Setup
		val	(infoTable, contentTable) = documentTables(documentType)
		val	collectionContentsTable = this.collectionTablesMap.value(collectionName)!!

		return SQLiteInnerJoin(infoTable, DocumentTypeInfoTable.idTableColumn, contentTable)
			.and(infoTable, DocumentTypeInfoTable.idTableColumn, collectionContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun innerJoinForIndex(documentType :String, indexName :String) :SQLiteInnerJoin {
		// Setup
		val	(infoTable, contentTable) = documentTables(documentType)
		val	indexContentsTable = this.indexTablesMap.value(indexName)!!

		return SQLiteInnerJoin(infoTable, DocumentTypeInfoTable.idTableColumn, contentTable)
			.and(infoTable, DocumentTypeInfoTable.idTableColumn, indexContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun where(active :Boolean = true) :SQLiteWhere {
		// Return SQLiteWhere
		return SQLiteWhere(tableColumn = DocumentTypeInfoTable.activeTableColumn, value = if (active) 1 else 0)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun whereForDocumentIDs(documentIDs :List<String>) :SQLiteWhere {
		// Return SQLiteWhere
		return SQLiteWhere(tableColumn = DocumentTypeInfoTable.documentIDTableColumn, values = documentIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun where(revision :Int, comparison :String = ">", includeInactive :Boolean) :SQLiteWhere {
		// Return SQLiteWhere
		return if (includeInactive)
				SQLiteWhere(tableColumn = DocumentTypeInfoTable.revisionTableColumn, comparison = comparison,
								value = revision) else
				SQLiteWhere(tableColumn = DocumentTypeInfoTable.revisionTableColumn, comparison = comparison,
								value = revision)
						.and(tableColumn = DocumentTypeInfoTable.activeTableColumn, value = 1)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun whereForIndexKeys(indexKeys :List<String>) :SQLiteWhere {
		// Return SQLiteWhere
		return SQLiteWhere(tableColumn = IndexContentsTable.keyTableColumn, values = indexKeys)
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	private fun documentTables(documentType :String) :DocumentTables {
		// Check for already having tables
		var	documentTables = this.documentTablesMap.value(documentType)
		if (documentTables == null) {
			// Setup tables
			val	nameRoot = documentType.capitalize(Locale.ROOT)
			val infoTable = DocumentTypeInfoTable.create(this.database, nameRoot, this.databaseVersion!!)
			val contentTable =
						DocumentTypeContentTable.create(this.database, nameRoot, infoTable, this.databaseVersion!!)
			documentTables = DocumentTables(infoTable, contentTable)

			// Cache
			this.documentTablesMap.set(documentType, documentTables)
		}

		return documentTables
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun nextRevision(documentType :String) :Int {
		// Compose next revision
		val	nextRevision = (this.documentLastRevisionMap.value(documentType) ?: 0) + 1

		// Check if in batch
		val batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo != null)
			// Update batch info
			batchInfo.documentLastRevisionTypesNeedingWrite.add(documentType)
		else
			// Update
			DocumentsTable.set(nextRevision, documentType, this.documentsMasterTable)

		// Store
		this.documentLastRevisionMap.set(documentType, nextRevision)

		return nextRevision
	}

	// Companion object
	//------------------------------------------------------------------------------------------------------------------
	companion object {

		// Methods
		//--------------------------------------------------------------------------------------------------------------
		fun documentBackingInfo(info :Info, resultsRow :SQLiteResultsRow)
				:MDSDocument.BackingInfo<MDSSQLiteDocumentBacking> {
			// Return document backing info
			return DocumentTypeContentTable.documentBackingInfo(info, resultsRow)
		}

		//--------------------------------------------------------------------------------------------------------------
		fun indexContentsKey(resultsRow :SQLiteResultsRow) :String { return IndexContentsTable.key(resultsRow) }
	}
}
