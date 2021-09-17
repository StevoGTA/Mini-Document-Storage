//
//  MDSSQLiteDatabaseManager.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/29/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

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

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSSQLiteDatabaseManager
class MDSSQLiteDatabaseManager {

	// MARK: Types
			typealias Info = (id :Int64, documentRevisionInfo :MDSDocument.RevisionInfo, active :Bool)

	private	typealias DocumentTables = (infoTable :SQLiteTable, contentTable :SQLiteTable)

	private	typealias CollectionUpdateInfo = (includedIDs :[Int64], notIncludedIDs :[Int64], lastRevision :Int)
	private	typealias IndexUpdateInfo =
						(keysInfos :[(keys :[String], value :Int64)], removedIDs :[Int64], lastRevision :Int)

	// MARK: BatchInfo
	private struct BatchInfo {

		// MARK: Properties
		var	documentLastRevisionTypesNeedingWrite = Set<String>()
		var	collectionInfo = [/* collection name */ String : CollectionUpdateInfo]()
		var	indexInfo = [/* index name */ String : IndexUpdateInfo]()
	}

	// MARK: InfoTable
	private struct InfoTable {

		// MARK: Properties
		static	let	keyTableColumn = SQLiteTableColumn("key", .text, [.primaryKey, .unique, .notNull])
		static	let	valueTableColumn = SQLiteTableColumn("value", .text, [.notNull])
		static	let	tableColumns = [keyTableColumn, valueTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func create(in database :SQLiteDatabase) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Info", options: [.withoutRowID], tableColumns: self.tableColumns)
			table.create()

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func int(for key :String, in table :SQLiteTable) -> Int? {
			// Retrieve value
			var	value :Int? = nil
			try! table.select(tableColumns: [self.valueTableColumn],
					where: SQLiteWhere(tableColumn: self.keyTableColumn, value: key)) {
				// Process values
				value = Int($0.text(for: self.valueTableColumn)!)!
			}

			return value
		}

		//--------------------------------------------------------------------------------------------------------------
		static func string(for key :String, in table :SQLiteTable) -> String? {
			// Retrieve value
			var	value :String? = nil
			try! table.select(tableColumns: [self.valueTableColumn],
					where: SQLiteWhere(tableColumn: self.keyTableColumn, value: key)) {
				// Process values
				value = $0.text(for: self.valueTableColumn)!
			}

			return value
		}

		//--------------------------------------------------------------------------------------------------------------
		static func set(value :Any?, for key :String, in table :SQLiteTable) {
			// Check if storing or removing
			if value != nil {
				// Storing
				table.insertOrReplaceRow([
											(self.keyTableColumn, key),
											(self.valueTableColumn, value!),
										 ])
			} else {
				// Removing
				table.deleteRows(self.keyTableColumn, values: [key])
			}
		}
	}

	// MARK: DocumentsTable
	private struct DocumentsTable {

		// MARK: Properties
		static	let	typeTableColumn = SQLiteTableColumn("type", .text, [.notNull, .unique])
		static	let	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", .integer, [.notNull])
		static	let	tableColumns = [typeTableColumn, lastRevisionTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func create(in database :SQLiteDatabase, version :Int?) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Documents", tableColumns: self.tableColumns)
			if version == nil { table.create() }

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func iterate(in table :SQLiteTable, proc :(_ documentType :String, _ lastRevision :Int) -> Void) {
			// Iterate
			try! table.select() {
				// Process results
				let	documentType = $0.text(for: self.typeTableColumn)!
				let	lastRevision = Int($0.integer(for: self.lastRevisionTableColumn)!)

				// Call proc
				proc(documentType, lastRevision)
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		static func set(lastRevision :Int, for documentType :String, in table :SQLiteTable) {
			// Insert or replace row
			table.insertOrReplaceRow([
										(self.typeTableColumn, documentType),
										(self.lastRevisionTableColumn, lastRevision),
									 ])
		}
	}

	// MARK: DocumentTypeInfoTable
	private struct DocumentTypeInfoTable {

		// MARK: Properties
		static	let	idTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey, .autoincrement])
		static	let	documentIDTableColumn = SQLiteTableColumn("documentID", .text, [.notNull, .unique])
		static	let	revisionTableColumn = SQLiteTableColumn("revision", .integer, [.notNull])
		static	let	activeTableColumn = SQLiteTableColumn("active", .integer, [.notNull])
		static	let	tableColumns = [idTableColumn, documentIDTableColumn, revisionTableColumn, activeTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func create(in database :SQLiteDatabase, nameRoot :String, version :Int) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "\(nameRoot)s", tableColumns: self.tableColumns)
			table.create()

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(for resultsRow :SQLiteResultsRow) -> Info {
			// Process results
			let	id :Int64 = resultsRow.integer(for: self.idTableColumn)!
			let	documentID = resultsRow.text(for: self.documentIDTableColumn)!
			let	revision = Int(resultsRow.integer(for: self.revisionTableColumn)!)
			let	active :Bool = resultsRow.integer(for: self.activeTableColumn)! == 1

			return (id, MDSDocument.RevisionInfo(documentID: documentID, revision: revision), active)
		}

		//--------------------------------------------------------------------------------------------------------------
		static func add(documentID :String, revision :Int, to table :SQLiteTable) -> Int64 {
			// Insert
			return table.insertRow([
									(self.documentIDTableColumn, documentID),
									(self.revisionTableColumn, revision),
									(self.activeTableColumn, 1),
								   ])
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(id :Int64, to revision :Int, in table :SQLiteTable) {
			// Update
			table.update([(self.revisionTableColumn, revision)],
					where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))
		}

		//--------------------------------------------------------------------------------------------------------------
		static func remove(id :Int64, in table :SQLiteTable) {
			// Update
			table.update([(self.activeTableColumn, 0)], where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))
		}
	}

	// MARK: DocumentTypeContentTable
	private struct DocumentTypeContentTable {

		// MARK: Properties
		static	let	idTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])
		static	let	creationDateTableColumn = SQLiteTableColumn("creationDate", .text, [.notNull])
		static	let	modificationDateTableColumn = SQLiteTableColumn("modificationDate", .text, [.notNull])
		static	let	jsonTableColumn = SQLiteTableColumn("json", .blob, [.notNull])
		static	let	tableColumns =
							[idTableColumn, creationDateTableColumn, modificationDateTableColumn, jsonTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func create(in database :SQLiteDatabase, nameRoot :String, infoTable :SQLiteTable, version :Int) ->
				SQLiteTable {
			// Create table
			let	table =
						database.table(name: "\(nameRoot)Contents", tableColumns: self.tableColumns,
								references: [(self.idTableColumn, infoTable, DocumentTypeInfoTable.idTableColumn)])
			table.create()

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func documentBackingInfo(for info :Info, with resultsRow :SQLiteResultsRow) ->
				MDSDocument.BackingInfo<MDSSQLiteDocumentBacking> {
			// Process results
			let	creationDate = Date(fromRFC3339Extended: resultsRow.text(for: self.creationDateTableColumn)!)!
			let	modificationDate = Date(fromRFC3339Extended: resultsRow.text(for: self.modificationDateTableColumn)!)!
			let	propertyMap =
						try! JSONSerialization.jsonObject(
								with: resultsRow.blob(for: self.jsonTableColumn)!) as! [String : Any]

			return MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(documentID: info.documentRevisionInfo.documentID,
					documentBacking:
							MDSSQLiteDocumentBacking(id: info.id, revision: info.documentRevisionInfo.revision,
									creationDate: creationDate, modificationDate: modificationDate,
									propertyMap: propertyMap, active: info.active))
		}

		//--------------------------------------------------------------------------------------------------------------
		static func add(id :Int64, creationDate :Date, modificationDate :Date, propertyMap :[String : Any],
				to table :SQLiteTable) {
			// Insert
			_ = table.insertRow([
									(self.idTableColumn, id),
									(self.creationDateTableColumn, creationDate.rfc3339Extended),
									(self.modificationDateTableColumn, modificationDate.rfc3339Extended),
									(self.jsonTableColumn, try! JSONSerialization.data(withJSONObject: propertyMap)),
								])
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(id :Int64, modificationDate :Date, propertyMap :[String : Any], in table :SQLiteTable) {
			// Update
			 table.update(
					[
						(self.modificationDateTableColumn, modificationDate.rfc3339Extended),
						(self.jsonTableColumn, try! JSONSerialization.data(withJSONObject: propertyMap))
					],
					where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))
		}

		//--------------------------------------------------------------------------------------------------------------
		static func remove(id :Int64, in table :SQLiteTable) {
			// Update
			table.update(
					[
						(self.modificationDateTableColumn, Date().rfc3339Extended),
						(self.jsonTableColumn, try! JSONSerialization.data(withJSONObject: [:], options: []))
					],
					where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))
		}
	}

	// MARK: CollectionsTable
	private struct CollectionsTable {

		// MARK: Properties
		static	let	nameTableColumn = SQLiteTableColumn("name", .text, [.notNull, .unique])
		static	let	versionTableColumn = SQLiteTableColumn("version", .integer, [.notNull])
		static	let	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", .integer, [.notNull])
		static	let	tableColumns = [nameTableColumn, versionTableColumn, lastRevisionTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func create(in database :SQLiteDatabase, version :Int?) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Collections", tableColumns: self.tableColumns)
			if version == nil { table.create() }

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(forName name :String, in table :SQLiteTable) -> (version :Int?, lastRevision :Int?) {
			// Query
			var	version :Int?
			var	lastRevision :Int?
			try! table.select(tableColumns: [self.versionTableColumn, self.lastRevisionTableColumn],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name)) {
						// Process results
						version = Int($0.integer(for: self.versionTableColumn)!)
						lastRevision = Int($0.integer(for: self.lastRevisionTableColumn)!)
					}

			return (version, lastRevision)
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(name :String, version :Int, lastRevision :Int, in table :SQLiteTable) {
			// Insert or replace
			table.insertOrReplaceRow(
					[
						(self.nameTableColumn, name),
						(self.versionTableColumn, version),
						(self.lastRevisionTableColumn, lastRevision),
					])
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(name :String, lastRevision :Int, in table :SQLiteTable) {
			// Update
			table.update([(self.lastRevisionTableColumn, lastRevision)],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name))
		}
	}

	// MARK: CollectionContentsTable
	private struct CollectionContentsTable {

		// MARK: Properties
		static	let	idTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])
		static	let	tableColumns = [idTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func create(in database :SQLiteDatabase, name :String, version :Int) -> SQLiteTable {
			// Create table
			return database.table(name: "Collection-\(name)", options: [.withoutRowID], tableColumns: self.tableColumns)
		}

		//--------------------------------------------------------------------------------------------------------------
		static func iterate(table :SQLiteTable, documentInfoTable :SQLiteTable, proc :(_ info :Info) -> Void) {
			// Select
			try! table.select(innerJoin: SQLiteInnerJoin(table, tableColumn: self.idTableColumn, to: documentInfoTable))
					{ proc(DocumentTypeInfoTable.info(for: $0)) }
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(includedIDs :[Int64], notIncludedIDs :[Int64], in table :SQLiteTable) {
			// Update
			if !notIncludedIDs.isEmpty { table.deleteRows(self.idTableColumn, values: notIncludedIDs) }
			if !includedIDs.isEmpty { table.insertOrReplaceRows(self.idTableColumn, values: includedIDs) }
		}
	}

	// MARK: IndexesTable
	private struct IndexesTable {

		// MARK: Properties
		static	let	nameTableColumn = SQLiteTableColumn("name", .text, [.notNull, .unique])
		static	let	versionTableColumn = SQLiteTableColumn("version", .integer, [.notNull])
		static	let	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", .integer, [.notNull])
		static	let	tableColumns = [nameTableColumn, versionTableColumn, lastRevisionTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func create(in database :SQLiteDatabase, version :Int?) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Indexes", tableColumns: self.tableColumns)
			if version == nil { table.create() }

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(forName name :String, in table :SQLiteTable) -> (version :Int?, lastRevision :Int?) {
			// Query
			var	version :Int?
			var	lastRevision :Int?
			try! table.select(tableColumns: [self.versionTableColumn, self.lastRevisionTableColumn],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name)) {
						// Process results
						version = Int($0.integer(for: self.versionTableColumn)!)
						lastRevision = Int($0.integer(for: self.lastRevisionTableColumn)!)
					}

			return (version, lastRevision)
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(name :String, version :Int, lastRevision :Int, in table :SQLiteTable) {
			// Insert or replace
			table.insertOrReplaceRow(
					[
						(self.nameTableColumn, name),
						(self.versionTableColumn, version),
						(self.lastRevisionTableColumn, lastRevision),
					])
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(name :String, lastRevision :Int, in table :SQLiteTable) {
			// Update
			table.update([(self.lastRevisionTableColumn, lastRevision)],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name))
		}
	}

	// MARK: IndexContentsTable
	private struct IndexContentsTable {

		// MARK: Properties
		static	let	keyTableColumn = SQLiteTableColumn("key", .text, [.primaryKey])
		static	let	idTableColumn = SQLiteTableColumn("id", .integer, [.notNull])
		static	let	tableColumns = [keyTableColumn, idTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func create(in database :SQLiteDatabase, name :String, version :Int) -> SQLiteTable {
			// Create table
			return database.table(name: "Index-\(name)", options: [.withoutRowID], tableColumns: self.tableColumns)
		}

		//--------------------------------------------------------------------------------------------------------------
		static func key(for resultsRow :SQLiteResultsRow) -> String { resultsRow.text(for: self.keyTableColumn)! }

		//--------------------------------------------------------------------------------------------------------------
		static func iterate(table :SQLiteTable, documentInfoTable :SQLiteTable, keys :[String],
				proc :(_ key :String, _ info :Info) -> Void) {
			// Select
			try! documentInfoTable.select(
					innerJoin:
							SQLiteInnerJoin(documentInfoTable, tableColumn: DocumentTypeInfoTable.idTableColumn,
									to: table),
					where: SQLiteWhere(tableColumn: self.keyTableColumn, values: keys))
					{ proc($0.text(for: self.keyTableColumn)!, DocumentTypeInfoTable.info(for: $0)) }
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(keysInfos :[(keys :[String], value :Int64)], removedIDs :[Int64], in table :SQLiteTable) {
			// Setup
			let	idsToRemove = removedIDs + keysInfos.map({ $0.value })

			// Update tables
			if !idsToRemove.isEmpty { table.deleteRows(self.idTableColumn, values: idsToRemove) }
			keysInfos.forEach() { keysInfo in keysInfo.keys.forEach() {
				// Insert this key
				table.insertRow([
									(tableColumn: self.keyTableColumn, value: $0),
									(tableColumn: self.idTableColumn, value: keysInfo.value),
								])
			} }
		}
	}

	// MARK: Properties
	private	let	database :SQLiteDatabase
	private	var	databaseVersion :Int?

	private	let	infoTable :SQLiteTable

	private	let	documentsMasterTable :SQLiteTable
	private	let	documentTablesMap = LockingDictionary</* Document type */ String, DocumentTables>()
	private	let	documentLastRevisionMap = LockingDictionary</* Document type */ String, Int>()

	private	let	collectionsMasterTable :SQLiteTable
	private	let	collectionTablesMap = LockingDictionary</* Collection name */ String, SQLiteTable>()

	private	let	indexesMasterTable :SQLiteTable
	private	let	indexTablesMap = LockingDictionary</* Index name */ String, SQLiteTable>()

	private	let	batchInfoMap = LockingDictionary<Thread, BatchInfo>()

	// MARK: Class methods
	//------------------------------------------------------------------------------------------------------------------
	static func documentBackingInfo(for info :Info, resultsRow :SQLiteResultsRow) ->
			MDSDocument.BackingInfo<MDSSQLiteDocumentBacking> {
		// Return document backing info
		return DocumentTypeContentTable.documentBackingInfo(for: info, with: resultsRow)
	}

	//------------------------------------------------------------------------------------------------------------------
	static func indexContentsKey(for resultsRow :SQLiteResultsRow) -> String { IndexContentsTable.key(for: resultsRow) }

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(database :SQLiteDatabase) {
		// Store
		self.database = database

		// Create tables
		self.infoTable = InfoTable.create(in: self.database)
		self.databaseVersion = InfoTable.int(for: "version", in: self.infoTable)

		self.documentsMasterTable = DocumentsTable.create(in: self.database, version: self.databaseVersion)
		self.collectionsMasterTable = CollectionsTable.create(in: self.database, version: self.databaseVersion)
		self.indexesMasterTable = IndexesTable.create(in: self.database, version: self.databaseVersion)

		// Finalize setup
		if self.databaseVersion == nil {
			// Update version
			self.databaseVersion = 1
			InfoTable.set(value: self.databaseVersion, for: "version", in: self.infoTable)
		}

		DocumentsTable.iterate(in: self.documentsMasterTable) { self.documentLastRevisionMap.set($1, for: $0) }
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func int(for key :String) -> Int? { InfoTable.int(for: key, in: self.infoTable) }

	//------------------------------------------------------------------------------------------------------------------
	func string(for key :String) -> String? { InfoTable.string(for: key, in: self.infoTable) }

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for key :String) { InfoTable.set(value: value, for: key, in: self.infoTable) }

	//------------------------------------------------------------------------------------------------------------------
	func note(documentType :String) { _ = documentTables(for: documentType) }

	//------------------------------------------------------------------------------------------------------------------
	func batch(_ proc :() -> Void) {
		// Setup
		self.batchInfoMap.set(BatchInfo(), for: Thread.current)

		// Call proc
		proc()

		// Commit changes
		let	batchInfo = self.batchInfoMap.value(for: Thread.current)!
		self.batchInfoMap.set(nil, for: Thread.current)

		batchInfo.documentLastRevisionTypesNeedingWrite.forEach() {
			// Update
			DocumentsTable.set(lastRevision: self.documentLastRevisionMap.value(for: $0)!, for: $0,
					in: self.documentsMasterTable)
		}
		batchInfo.collectionInfo.forEach() {
			// Update collection
			self.updateCollection(name: $0.key, includedIDs: $0.value.includedIDs,
					notIncludedIDs: $0.value.notIncludedIDs, lastRevision: $0.value.lastRevision)
		}
		batchInfo.indexInfo.forEach() {
			// Update index
			self.updateIndex(name: $0.key, keysInfos: $0.value.keysInfos, removedIDs: $0.value.removedIDs,
					lastRevision: $0.value.lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func new(documentType :String, documentID :String, creationDate :Date? = nil, modificationDate :Date? = nil,
			propertyMap :[String : Any]) -> (id :Int64, revision :Int, creationDate :Date, modificationDate :Date) {
		// Setup
		let	revision = nextRevision(for: documentType)
		let	creationDateUse = creationDate ?? Date()
		let	modificationDateUse = modificationDate ?? creationDateUse
		let	(infoTable, contentTable) = documentTables(for: documentType)

		// Add to database
		let	id = DocumentTypeInfoTable.add(documentID: documentID, revision: revision, to: infoTable)
		DocumentTypeContentTable.add(id: id, creationDate: creationDateUse, modificationDate: modificationDateUse,
				propertyMap: propertyMap, to: contentTable)

		return (id, revision, creationDateUse, modificationDateUse)
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterate(documentType :String, innerJoin :SQLiteInnerJoin? = nil, where sqliteWhere :SQLiteWhere? = nil,
			proc :(_ info :Info, _ resultsRow :SQLiteResultsRow) -> Void) {
		// Setup
		let	(infoTable, _) = self.documentTables(for: documentType)

		// Retrieve and iterate
		try! infoTable.select(innerJoin: innerJoin, where: sqliteWhere)
				{ proc(DocumentTypeInfoTable.info(for: $0), $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func update(documentType :String, id :Int64, propertyMap :[String : Any]) ->
			(revision :Int, modificationDate :Date) {
		// Setup
		let	revision = nextRevision(for: documentType)
		let	modificationDate = Date()
		let	(infoTable, contentTable) = documentTables(for: documentType)

		// Update
		DocumentTypeInfoTable.update(id: id, to: revision, in: infoTable)
		DocumentTypeContentTable.update(id: id, modificationDate: modificationDate, propertyMap: propertyMap,
				in: contentTable)

		return (revision, modificationDate)
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove(documentType :String, id :Int64) {
		// Setup
		let	(infoTable, contentTable) = documentTables(for: documentType)

		// Remove
		DocumentTypeInfoTable.remove(id: id, in: infoTable)
		DocumentTypeContentTable.remove(id: id, in: contentTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection(documentType :String, name :String, version :Int, isUpToDate :Bool) -> Int {
		// Get current info
		let (storedVersion, storedLastRevision) = CollectionsTable.info(forName: name, in: self.collectionsMasterTable)

		// Setup table
		let	collectionContentsTable =
					CollectionContentsTable.create(in: self.database, name: name, version: self.databaseVersion!)
		self.collectionTablesMap.set(collectionContentsTable, for: name)

		// Compose last revision
		let	lastRevision :Int
		let	updateMasterTable :Bool
		if storedLastRevision == nil {
			// New
			lastRevision = isUpToDate ? self.documentLastRevisionMap.value(for: documentType) ?? 0 : 0
			updateMasterTable = true
		} else if version != storedVersion {
			// Updated version
			lastRevision = 0
			updateMasterTable = true
		} else {
			// No change
			lastRevision = storedLastRevision!
			updateMasterTable = false
		}

		// Check if need to update the master table
		if updateMasterTable {
			// New or updated
			CollectionsTable.update(name: name, version: version, lastRevision: lastRevision,
					in: self.collectionsMasterTable)

			// Update table
			if storedLastRevision != nil { collectionContentsTable.drop() }
			collectionContentsTable.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentCountForCollection(named name :String) -> Int { self.collectionTablesMap.value(for: name)!.count() }

	//------------------------------------------------------------------------------------------------------------------
	func iterateCollection(name :String, documentType :String, proc :(_ info :Info) -> Void) {
		// Setup
		let	(infoTable, _) = documentTables(for: documentType)
		let	collectionContentsTable = self.collectionTablesMap.value(for: name)!

		// Iterate
		CollectionContentsTable.iterate(table: collectionContentsTable, documentInfoTable: infoTable, proc: proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	func updateCollection(name :String, includedIDs :[Int64], notIncludedIDs :[Int64], lastRevision :Int) {
		// Check if in batch
		if var batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// Update batch info
			let	collectionUpdateInfo = batchInfo.collectionInfo[name]
			batchInfo.collectionInfo[name] =
					((collectionUpdateInfo?.includedIDs ?? []) + includedIDs,
							(collectionUpdateInfo?.notIncludedIDs ?? []) + notIncludedIDs, lastRevision)
			self.batchInfoMap.set(batchInfo, for: Thread.current)
		} else {
			// Update tables
			CollectionsTable.update(name: name, lastRevision: lastRevision, in: self.collectionsMasterTable)
			CollectionContentsTable.update(includedIDs: includedIDs, notIncludedIDs: notIncludedIDs,
					in: self.collectionTablesMap.value(for: name)!)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerIndex(documentType :String, name :String, version :Int, isUpToDate :Bool) -> Int {
		// Get current info
		let (storedVersion, storedLastRevision) = IndexesTable.info(forName: name, in: self.indexesMasterTable)

		// Setup table
		let	indexContentsTable =
					IndexContentsTable.create(in: self.database, name: name, version: self.databaseVersion!)
		self.indexTablesMap.set(indexContentsTable, for: name)

		// Compose last revision
		let	lastRevision :Int
		let	updateMasterTable :Bool
		if storedLastRevision == nil {
			// New
			lastRevision = isUpToDate ? (self.documentLastRevisionMap.value(for: documentType) ?? 0) : 0
			updateMasterTable = true
		} else if version != storedVersion {
			// Updated version
			lastRevision = 0
			updateMasterTable = true
		} else {
			// No change
			lastRevision = storedLastRevision!
			updateMasterTable = false
		}

		// Check if need to update the master table
		if updateMasterTable {
			// New or updated
			IndexesTable.update(name: name, version: version, lastRevision: lastRevision, in: self.indexesMasterTable)

			// Update table
			if storedLastRevision != nil { indexContentsTable.drop() }
			indexContentsTable.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateIndex(name :String, documentType :String, keys :[String], proc :(_ key :String, _ info :Info) -> Void) {
		// Setup
		let	(infoTable, _) = documentTables(for: documentType)
		let	indexContentsTable = self.indexTablesMap.value(for: name)!

		// Iterate
		IndexContentsTable.iterate(table: indexContentsTable, documentInfoTable: infoTable, keys: keys, proc: proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	func updateIndex(name :String, keysInfos :[(keys :[String], value :Int64)], removedIDs :[Int64],
			lastRevision :Int) {
		// Check if in batch
		if var batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// Update batch info
			let	indexInfo = batchInfo.indexInfo[name]
			batchInfo.indexInfo[name] =
					((indexInfo?.keysInfos ?? []) + keysInfos, (indexInfo?.removedIDs ?? []) + removedIDs,
							lastRevision)
			self.batchInfoMap.set(batchInfo, for: Thread.current)
		} else {
			// Update tables
			IndexesTable.update(name: name, lastRevision: lastRevision, in: self.indexesMasterTable)
			IndexContentsTable.update(keysInfos: keysInfos, removedIDs: removedIDs,
					in: self.indexTablesMap.value(for: name)!)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func innerJoin(for documentType :String) -> SQLiteInnerJoin {
		// Setup
		let	(infoTable, contentTable) = self.documentTables(for: documentType)

		return SQLiteInnerJoin(infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn, to: contentTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func innerJoin(for documentType :String, collectionName :String) -> SQLiteInnerJoin {
		// Setup
		let	(infoTable, contentTable) = self.documentTables(for: documentType)
		let	collectionContentsTable = self.collectionTablesMap.value(for: collectionName)!

		return SQLiteInnerJoin(infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn, to: contentTable)
				.and(infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn, to: collectionContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func innerJoin(for documentType :String, indexName :String) -> SQLiteInnerJoin {
		// Setup
		let	(infoTable, contentTable) = self.documentTables(for: documentType)
		let	indexContentsTable = self.indexTablesMap.value(for: indexName)!

		return SQLiteInnerJoin(infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn, to: contentTable)
				.and(infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn, to: indexContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func `where`(forDocumentActive active :Bool = true) -> SQLiteWhere {
		// Return SQLiteWhere
		return SQLiteWhere(tableColumn: DocumentTypeInfoTable.activeTableColumn, value: active ? 1 : 0)
	}

	//------------------------------------------------------------------------------------------------------------------
	func `where`(forDocumentIDs documentIDs :[String]) -> SQLiteWhere {
		// Return SQLiteWhere
		return SQLiteWhere(tableColumn: DocumentTypeInfoTable.documentIDTableColumn, values: documentIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	func `where`(forDocumentRevision revision :Int, comparison :String = ">", includeInactive :Bool) -> SQLiteWhere {
		// Return SQLiteWhere
		return includeInactive ?
			SQLiteWhere(tableColumn: DocumentTypeInfoTable.revisionTableColumn, comparison: comparison,
							value: revision) :
			SQLiteWhere(tableColumn: DocumentTypeInfoTable.revisionTableColumn, comparison: comparison, value: revision)
					.and(tableColumn: DocumentTypeInfoTable.activeTableColumn, value: 1)
	}

	//------------------------------------------------------------------------------------------------------------------
	func `where`(forIndexKeys keys :[String]) -> SQLiteWhere {
		// Return SQLiteWhere
		return SQLiteWhere(tableColumn: IndexContentsTable.keyTableColumn, values: keys)
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func documentTables(for documentType :String) -> DocumentTables {
		// Ensure we actually have a document type
		guard !documentType.isEmpty else { fatalError("documentType is empty") }

		// Check for already having tables
		if let documentTables = self.documentTablesMap.value(for: documentType) {
			// Have tables
			return documentTables
		} else {
			// Setup tables
			let	nameRoot = documentType.prefix(1).uppercased() + documentType.dropFirst()
			let	infoTable =
						DocumentTypeInfoTable.create(in: self.database, nameRoot: nameRoot,
								version: self.databaseVersion!)
			let	contentTable =
						DocumentTypeContentTable.create(in: self.database, nameRoot: nameRoot,
								infoTable: infoTable, version: self.databaseVersion!)

			// Cache
			self.documentTablesMap.set((infoTable, contentTable), for: documentType)

			return (infoTable, contentTable)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func nextRevision(for documentType :String) -> Int {
		// Compose next revision
		let	nextRevision = (self.documentLastRevisionMap.value(for: documentType) ?? 0) + 1

		// Check if in batch
		if var batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// Update batch info
			batchInfo.documentLastRevisionTypesNeedingWrite.insert(documentType)
			self.batchInfoMap.set(batchInfo, for: Thread.current)
		} else {
			// Update
			DocumentsTable.set(lastRevision: nextRevision, for: documentType, in: self.documentsMasterTable)
		}

		// Store
		self.documentLastRevisionMap.set(nextRevision, for: documentType)

		return nextRevision
	}
}
