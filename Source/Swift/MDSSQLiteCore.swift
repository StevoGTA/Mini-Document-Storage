//
//  MDSSQLiteCore.swift
//  Media Tools
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
			Columns: name, version, lastRevision, info
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
// MARK: MDSSQLiteCore
class MDSSQLiteCore {

	// MARK: Types
	typealias DocumentTables = (infoTable :SQLiteTable, contentTable :SQLiteTable)

	// MARK: Properties
	static	private	let	infoKeyTableColumn =
								SQLiteTableColumn("key", .text, [.primaryKey, .unique, .notNull])
	static	private	let	infoValueTableColumn = SQLiteTableColumn("value", .text, [.notNull])

	static	private	let	documentsMasterTypeTableColumn = SQLiteTableColumn("type", .text, [.notNull, .unique])
	static	private	let	documentsMasterLastRevisionTableColumn =
								SQLiteTableColumn("lastRevision", .integer4, [.notNull])

	static	private	let	documentsInfoIDTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey, .autoincrement])
	static	private	let	documentsInfoDocumentIDTableColumn = SQLiteTableColumn("documentID", .text, [.notNull, .unique])
	static	private	let	documentsInfoRevisionTableColumn = SQLiteTableColumn("revision", .integer4, [.notNull])

	static	private	let	documentsContentsIDTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])
	static	private	let	documentsContentsCreationDateTableColumn =
								SQLiteTableColumn("creationDate", .textWith(size: 23), [.notNull])
	static	private	let	documentsContentsModificationDateTableColumn =
								SQLiteTableColumn("modificationDate", .textWith(size: 23), [.notNull])
	static	private	let	documentsContentsJSONTableColumn = SQLiteTableColumn("json", .blob, [.notNull])

	static	private	let	collectionsMasterNameTableColumn = SQLiteTableColumn("name", .text, [.notNull, .unique])
	static	private	let	collectionsMasterVersionTableColumn = SQLiteTableColumn("version", .integer2, [.notNull])
	static	private	let	collectionsMasterLastRevisionTableColumn  =
								SQLiteTableColumn("lastRevision", .integer4, [.notNull])
	static	private	let	collectionsMasterInfoTableColumn = SQLiteTableColumn("info", .blob, [.notNull])

	static	private	let	collectionIDTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])

	static	private	let	indexesMasterNameTableColumn = SQLiteTableColumn("name", .text, [.notNull, .unique])
	static	private	let	indexesMasterVersionTableColumn = SQLiteTableColumn("version", .integer2, [.notNull])
	static	private	let	indexesMasterLastRevisionTableColumn = SQLiteTableColumn("lastRevision", .integer4, [.notNull])

	static	private	let	indexKeyTableColumn = SQLiteTableColumn("key", .text, [.notNull, .unique])
	static	private	let	indexIDTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])

			private	let	sqliteDatabase :SQLiteDatabase

			private	let	infoTable :SQLiteTable

			private	let	documentsMasterTable :SQLiteTable
			private	var	documentTablesMap = LockingDictionary</* Document type */ String, DocumentTables>()
			private	var	documentLastRevisionMap = LockingDictionary</* Document type */ String, Int>()

			private	var	collectionsMasterTable :SQLiteTable
			private	var	collectionTablesMap = LockingDictionary</* Collection name */ String, SQLiteTable>()

			private	var	indexesMasterTable :SQLiteTable
			private	var	indexTablesMap = LockingDictionary</* Index name */ String, SQLiteTable>()

			private	var	documentLastRevisionTypesNeedingWrite :LockingSet</* Document type */ String>?

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(sqliteDatabase :SQLiteDatabase) {
		// Store
		self.sqliteDatabase = sqliteDatabase

		// Create tables
		self.infoTable =
				self.sqliteDatabase.table(name: "Info", options: [.withoutRowID],
						tableColumns: [
										type(of: self).infoKeyTableColumn,
										type(of: self).infoValueTableColumn
									  ])
		self.infoTable.create()

		self.documentsMasterTable =
				self.sqliteDatabase.table(name: "Documents", options: [],
						tableColumns: [
										type(of: self).documentsMasterTypeTableColumn,
										type(of: self).documentsMasterLastRevisionTableColumn
									  ])
		self.documentsMasterTable.create()

		self.collectionsMasterTable =
				self.sqliteDatabase.table(name: "Collections", options: [],
						tableColumns: [
										type(of: self).collectionsMasterNameTableColumn,
										type(of: self).collectionsMasterVersionTableColumn,
										type(of: self).collectionsMasterLastRevisionTableColumn,
										type(of: self).collectionsMasterInfoTableColumn,
									  ])
		self.collectionsMasterTable.create()

		self.indexesMasterTable =
				self.sqliteDatabase.table(name: "Indexes", options: [],
						tableColumns: [
										type(of: self).indexesMasterNameTableColumn,
										type(of: self).indexesMasterVersionTableColumn,
										type(of: self).indexesMasterLastRevisionTableColumn,
									  ])
		self.indexesMasterTable.create()

		// Finalize setup
		try! self.documentsMasterTable.select() {
			// Process results
			let	documentType = $0.text(for: self.documentsMasterTable.typeTableColumn)!
			let	lastRevision :Int = $0.integer(for: self.documentsMasterTable.lastRevisionTableColumn)!

			// Add to key value store
			self.documentLastRevisionMap.set(lastRevision, for: documentType)
		}
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func int(for key :String) -> Int? {
		// Retrieve value
		var	value :Int?
		try! self.infoTable.select(tableColumns: [self.infoTable.valueTableColumn],
				where: SQLiteWhere(tableColumn: self.infoTable.keyTableColumn, value: key)) {
					// Process results
					value = Int($0.text(for: self.infoTable.valueTableColumn)!)
				}

		return value
	}

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any, for key :String) {
		// Store value
		self.infoTable.insertOrReplace([
										(self.infoTable.keyTableColumn, key),
										(self.infoTable.valueTableColumn, value),
									   ])
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentTables(for documentType :String) -> DocumentTables {
		// Check for already having tables
		if let documentTables = self.documentTablesMap.value(for: documentType) {
			// Have tables
			return documentTables
		} else {
			// Setup tables
			let	tableTitleRoot = documentType.prefix(1).uppercased() + documentType.dropFirst()
			let	infoTable =
						self.sqliteDatabase.table(name: "\(tableTitleRoot)s", options: [],
								tableColumns: [
												type(of: self).documentsInfoIDTableColumn,
												type(of: self).documentsInfoDocumentIDTableColumn,
												type(of: self).documentsInfoRevisionTableColumn
											  ])
			let	contentTable =
						self.sqliteDatabase.table(name: "\(tableTitleRoot)Contents", options: [],
								tableColumns: [
												type(of: self).documentsContentsIDTableColumn,
												type(of: self).documentsContentsCreationDateTableColumn,
												type(of: self).documentsContentsModificationDateTableColumn,
												type(of: self).documentsContentsJSONTableColumn
											  ],
								references: [
												(type(of: self).documentsContentsIDTableColumn, infoTable,
														type(of: self).documentsInfoIDTableColumn)
											])

			// Create tables
			_ = infoTable.create()
			_ = contentTable.create()

			// Store in key value store
			self.documentTablesMap.set((infoTable, contentTable), for: documentType)

			return (infoTable, contentTable)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func currentRevision(for documentType :String) -> Int {
		// Return current revision
		return self.documentLastRevisionMap.value(for: documentType) ?? 0
	}

	//------------------------------------------------------------------------------------------------------------------
	func nextRevision(for documentType :String) -> Int {
		// Compose next revision
		let	nextRevision = currentRevision(for: documentType) + 1

		// Check if in batch
		if self.documentLastRevisionTypesNeedingWrite == nil {
			// Write to storage
			self.documentsMasterTable.insertOrReplace([
														(self.documentsMasterTable.typeTableColumn, documentType),
														(self.documentsMasterTable.lastRevisionTableColumn,
																nextRevision),
													  ])
		} else {
			// Note to update later
			self.documentLastRevisionTypesNeedingWrite!.insert(documentType)
		}

		// Store
		self.documentLastRevisionMap.set(nextRevision, for: documentType)

		return nextRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func batch(_ proc :() -> Void) {
		// Setup
		self.documentLastRevisionTypesNeedingWrite = LockingSet<String>()

		// Call proc
		proc()

		// Commit changes
		self.documentLastRevisionTypesNeedingWrite!.values.forEach() {
			// Get revision
			let	revision = self.documentLastRevisionMap.value(for: $0)!

			// Write to storage
			self.documentsMasterTable.insertOrReplace([
														(self.documentsMasterTable.typeTableColumn, $0),
														(self.documentsMasterTable.lastRevisionTableColumn, revision),
													  ])
		}

		// Reset
		self.documentLastRevisionTypesNeedingWrite = nil
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection(documentType :String, name :String, version :UInt, info :[String : Any], isUpToDate :Bool)
			-> Int {
		// Query database
		var	storedVersion :UInt?
		var	storedLastRevision :Int?
		var	storedInfo :[String : Any]?
		try! self.collectionsMasterTable.select(
				tableColumns: [
								self.collectionsMasterTable.versionTableColumn,
								self.collectionsMasterTable.lastRevisionTableColumn,
								self.collectionsMasterTable.infoTableColumn,
							  ],
				where: SQLiteWhere(tableColumn: self.collectionsMasterTable.nameTableColumn, value: name)) {
					// Process results
					storedVersion = $0.integer(for: self.collectionsMasterTable.versionTableColumn)!
					storedLastRevision = $0.integer(for: self.collectionsMasterTable.lastRevisionTableColumn)!
					storedInfo =
							try! JSONSerialization.jsonObject(
									with: $0.blob(for: self.collectionsMasterTable.infoTableColumn)!) as! [String : Any]
				}

		// Setup table
		let	table =
					self.sqliteDatabase.table(name: "Collection-\(name)", options: [.withoutRowID],
							tableColumns: [type(of: self).collectionIDTableColumn])
		self.collectionTablesMap.set(table, for: name)

		// Compose last revision
		let	lastRevision :Int
		let	updateMasterTable :Bool
		if storedLastRevision == nil {
			// New
			lastRevision = isUpToDate ? self.documentLastRevisionMap.value(for: documentType)! : 0
			updateMasterTable = true
		} else if version != storedVersion {
			// Updated version
			lastRevision = 0
			updateMasterTable = true
		} else if !info.equals(storedInfo ?? [:]) {
			// Values changed
			lastRevision = isUpToDate ? storedLastRevision! : 0
			updateMasterTable = true
		} else {
			// No change
			lastRevision = storedLastRevision!
			updateMasterTable = false
		}

		// Check if need to update the master table
		if updateMasterTable {
			// New or updated
			self.collectionsMasterTable.insertOrReplace(
					[
						(self.collectionsMasterTable.versionTableColumn, version),
						(self.collectionsMasterTable.lastRevisionTableColumn, lastRevision),
						(self.collectionsMasterTable.infoTableColumn,
								try! JSONSerialization.data(withJSONObject: info)),
					])

			// Update table
			table.drop()
			table.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func sqliteTable(forCollectionNamed name :String) -> SQLiteTable {
		// Return table
		return self.collectionTablesMap.value(for: name)!
	}

	//------------------------------------------------------------------------------------------------------------------
	func updateCollection(name :String, includedIDs :[Int64], notIncludedIDs :[Int64], lastRevision :Int) {
		// Setup
		let	sqliteTable = self.collectionTablesMap.value(for: name)!
		let	infos :[(tableColumn :SQLiteTableColumn, value :Any)] =
					includedIDs.map({ (sqliteTable.idTableColumn, $0) })

		// Update tables
		if !infos.isEmpty {
			// Update
			sqliteTable.insertOrReplace(infos)
		}
		if !notIncludedIDs.isEmpty {
			// Delete
			sqliteTable.delete(where: SQLiteWhere(tableColumn: sqliteTable.idTableColumn, values: notIncludedIDs))
		}
		self.collectionsMasterTable.update(
				[(self.collectionsMasterTable.lastDocumentRevisionTableColumn, lastRevision)],
				where: SQLiteWhere(tableColumn: self.collectionsMasterTable.nameTableColumn, value: name))
	}

	//------------------------------------------------------------------------------------------------------------------
	func queryCollectionDocumentCount(name :String) -> UInt {
		// Return count
		return self.collectionTablesMap.value(for: name)!.count()
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerIndex(documentType :String, name :String, version :UInt, isUpToDate :Bool) -> Int {
		// Query database
		var	storedVersion :UInt?
		var	storedLastRevision :Int?
		try! self.indexesMasterTable.select(
				tableColumns: [
								self.indexesMasterTable.versionTableColumn,
								self.indexesMasterTable.lastRevisionTableColumn,
							  ],
				where: SQLiteWhere(tableColumn: self.indexesMasterTable.nameTableColumn, value: name)) {
					// Process results
					storedVersion = $0.integer(for: self.indexesMasterTable.versionTableColumn)!
					storedLastRevision = $0.integer(for: self.indexesMasterTable.lastRevisionTableColumn)!
				}

		// Setup table
		let	table =
					self.sqliteDatabase.table(name: "Index-\(name)", options: [.withoutRowID],
							tableColumns: [
											type(of: self).indexKeyTableColumn,
											type(of: self).indexIDTableColumn
										  ])
		self.indexTablesMap.set(table, for: name)

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
			self.indexesMasterTable.insertOrReplace(
					[
						(self.indexesMasterTable.nameTableColumn, name),
						(self.indexesMasterTable.versionTableColumn, version),
						(self.indexesMasterTable.lastRevisionTableColumn, lastRevision),
					])

			// Update table
			if storedLastRevision != nil { table.drop() }
			table.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func sqliteTable(forIndexNamed name :String) -> SQLiteTable {
		// Return table
		return self.indexTablesMap.value(for: name)!
	}

	//------------------------------------------------------------------------------------------------------------------
	func updateIndex(name :String, keysInfos :[(keys :[String], value :Int64)], removedIDs :[Int64],
			lastRevision :Int) {
		// Setup
		let	sqliteTable = self.indexTablesMap.value(for: name)!

		// Update tables
		keysInfos.forEach() { keysInfo in
			// Delete old keys
			sqliteTable.delete(where: SQLiteWhere(tableColumn: sqliteTable.idTableColumn, value: keysInfo.value))

			// Insert new keys
			keysInfo.keys.forEach() {
				// Insert this key
				sqliteTable.insert([
									(tableColumn: sqliteTable.keyTableColumn, value: $0),
									(tableColumn: sqliteTable.idTableColumn, value: keysInfo.value),
								   ])
			}
		}
		if !removedIDs.isEmpty {
			// Delete removed document IDs
			sqliteTable.delete(where: SQLiteWhere(tableColumn: sqliteTable.idTableColumn, values: removedIDs))
		}
		self.indexesMasterTable.update(
				[(self.indexesMasterTable.lastRevisionTableColumn, lastRevision)],
				where: SQLiteWhere(tableColumn: self.indexesMasterTable.nameTableColumn, value: name))
	}
}
