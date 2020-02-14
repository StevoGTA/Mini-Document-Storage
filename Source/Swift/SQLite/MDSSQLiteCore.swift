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

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSSQLiteCore
class MDSSQLiteCore {

	// MARK: Types
	typealias DocumentTables = (infoTable :SQLiteTable, contentTable :SQLiteTable)

	typealias CollectionUpdateInfo = (includedIDs :[Int64], notIncludedIDs :[Int64], lastRevision :Int)
	typealias IndexUpdateInfo = (keysInfos :[(keys :[String], value :Int64)], removedIDs :[Int64], lastRevision :Int)
	struct BatchInfo {

		// MARK: Properties
		var	documentLastRevisionTypesNeedingWrite = Set<String>()
		var	collectionInfo = [/* collection name */ String : CollectionUpdateInfo]()
		var	indexInfo = [/* index name */ String : IndexUpdateInfo]()
	}

	// MARK: Properties
	private	let	sqliteDatabase :SQLiteDatabase

	private	let	infoTable :SQLiteTable

	private	let	documentsMasterTable :SQLiteTable
	private	var	documentTablesMap = LockingDictionary</* Document type */ String, DocumentTables>()
	private	var	documentLastRevisionMap = LockingDictionary</* Document type */ String, Int>()

	private	var	collectionsMasterTable :SQLiteTable
	private	var	collectionTablesMap = LockingDictionary</* Collection name */ String, SQLiteTable>()

	private	var	indexesMasterTable :SQLiteTable
	private	var	indexTablesMap = LockingDictionary</* Index name */ String, SQLiteTable>()

	private	var	batchInfoMap = LockingDictionary<Thread, BatchInfo>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(sqliteDatabase :SQLiteDatabase) {
		// Store
		self.sqliteDatabase = sqliteDatabase

		// Create tables
		self.infoTable =
				self.sqliteDatabase.table(name: "Info", options: [.withoutRowID],
						tableColumns: [
										SQLiteTableColumn("key", .text, [.primaryKey, .unique, .notNull]),
										SQLiteTableColumn("value", .text, [.notNull])
									  ])
		self.infoTable.create()

		self.documentsMasterTable =
				self.sqliteDatabase.table(name: "Documents",
						tableColumns: [
										SQLiteTableColumn("type", .text, [.notNull, .unique]),
										SQLiteTableColumn("lastRevision", .integer4, [.notNull])
									  ])
		self.documentsMasterTable.create()

		self.collectionsMasterTable =
				self.sqliteDatabase.table(name: "Collections",
						tableColumns: [
										SQLiteTableColumn("name", .text, [.notNull, .unique]),
										SQLiteTableColumn("version", .integer2, [.notNull]),
										SQLiteTableColumn("lastRevision", .integer4, [.notNull]),
										SQLiteTableColumn("info", .blob, [.notNull]),
									  ])
		self.collectionsMasterTable.create()

		self.indexesMasterTable =
				self.sqliteDatabase.table(name: "Indexes",
						tableColumns: [
										SQLiteTableColumn("name", .text, [.notNull, .unique]),
										SQLiteTableColumn("version", .integer2, [.notNull]),
										SQLiteTableColumn("lastRevision", .integer4, [.notNull]),
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
		self.infoTable.insertOrReplaceRow([
											(self.infoTable.keyTableColumn, key),
											(self.infoTable.valueTableColumn, value),
										  ])
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentTables(for documentType :String) -> DocumentTables {
		// Ensure we actually have a document type
		guard !documentType.isEmpty else {
			fatalError("documentType is empty")
		}

		// Check for already having tables
		if let documentTables = self.documentTablesMap.value(for: documentType) {
			// Have tables
			return documentTables
		} else {
			// Setup tables
			let	tableTitleRoot = documentType.prefix(1).uppercased() + documentType.dropFirst()
			let	contentIDTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])
			let	infoTable =
						self.sqliteDatabase.table(name: "\(tableTitleRoot)s",
								tableColumns: [
												SQLiteTableColumn("id", .integer, [.primaryKey, .autoincrement]),
												SQLiteTableColumn("documentID", .text, [.notNull, .unique]),
												SQLiteTableColumn("revision", .integer4, [.notNull])
											  ])
			let	contentTable =
						self.sqliteDatabase.table(name: "\(tableTitleRoot)Contents",
								tableColumns: [
												contentIDTableColumn,
												SQLiteTableColumn("creationDate", .textWith(size: 23), [.notNull]),
												SQLiteTableColumn("modificationDate", .textWith(size: 23), [.notNull]),
												SQLiteTableColumn("json", .blob, [.notNull])
											  ],
								references: [(contentIDTableColumn, infoTable, infoTable.idTableColumn)])

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
		if var batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// Update batch info
			batchInfo.documentLastRevisionTypesNeedingWrite.insert(documentType)
			self.batchInfoMap.set(batchInfo, for: Thread.current)
		} else {
			// Write to storage
			self.documentsMasterTable.insertOrReplaceRow([
															(self.documentsMasterTable.typeTableColumn, documentType),
															(self.documentsMasterTable.lastRevisionTableColumn,
																	nextRevision),
														 ])
		}

		// Store
		self.documentLastRevisionMap.set(nextRevision, for: documentType)

		return nextRevision
	}

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
			// Get revision
			let	revision = self.documentLastRevisionMap.value(for: $0)!

			// Write to storage
			self.documentsMasterTable.insertOrReplaceRow([
															(self.documentsMasterTable.typeTableColumn, $0),
															(self.documentsMasterTable.lastRevisionTableColumn,
																	revision),
														 ])
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
							tableColumns: [SQLiteTableColumn("id", .integer, [.primaryKey])])
		self.collectionTablesMap.set(table, for: name)

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
			self.collectionsMasterTable.insertOrReplaceRow(
					[
						(self.collectionsMasterTable.nameTableColumn, name),
						(self.collectionsMasterTable.versionTableColumn, version),
						(self.collectionsMasterTable.lastRevisionTableColumn, lastRevision),
						(self.collectionsMasterTable.infoTableColumn,
								try! JSONSerialization.data(withJSONObject: info)),
					])

			// Update table
			if storedLastRevision != nil { table.drop() }
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
		// Check if in batch
		if var batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// Update batch info
			let	collectionInfo = batchInfo.collectionInfo[name]
			batchInfo.collectionInfo[name] =
					((collectionInfo?.includedIDs ?? []) + includedIDs,
							(collectionInfo?.notIncludedIDs ?? []) + notIncludedIDs, lastRevision)
			self.batchInfoMap.set(batchInfo, for: Thread.current)
		} else {
			// Setup
			let	sqliteTable = self.collectionTablesMap.value(for: name)!
			let	idTableColumn = sqliteTable.idTableColumn

			// Update tables
			if !includedIDs.isEmpty {
				// Update
				sqliteTable.insertOrReplaceRows(idTableColumn, values: includedIDs)
			}
			if !notIncludedIDs.isEmpty {
				// Delete
				sqliteTable.deleteRows(idTableColumn, values: notIncludedIDs)
			}
			self.collectionsMasterTable.update(
					[(self.collectionsMasterTable.lastRevisionTableColumn, lastRevision)],
					where: SQLiteWhere(tableColumn: self.collectionsMasterTable.nameTableColumn, value: name))
		}
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
											SQLiteTableColumn("key", .text, [.primaryKey]),
											SQLiteTableColumn("id", .integer, [])
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
			self.indexesMasterTable.insertOrReplaceRow(
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
		// Check if in batch
		if var batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// Update batch info
			let	indexInfo = batchInfo.indexInfo[name]
			batchInfo.indexInfo[name] =
					((indexInfo?.keysInfos ?? []) + keysInfos, (indexInfo?.removedIDs ?? []) + removedIDs,
							lastRevision)
			self.batchInfoMap.set(batchInfo, for: Thread.current)
		} else {
			// Setup
			let	sqliteTable = self.indexTablesMap.value(for: name)!
			let	idTableColumn = sqliteTable.idTableColumn

			let	idsToRemove = removedIDs + keysInfos.map({ $0.value })

			// Update tables
			sqliteTable.deleteRows(idTableColumn, values: idsToRemove)
			keysInfos.forEach() { keysInfo in
				// Insert new keys
				keysInfo.keys.forEach() {
					// Insert this key
					sqliteTable.insertRow([
											(tableColumn: sqliteTable.keyTableColumn, value: $0),
											(tableColumn: idTableColumn, value: keysInfo.value),
										  ])
				}
			}
			self.indexesMasterTable.update(
					[(self.indexesMasterTable.lastRevisionTableColumn, lastRevision)],
					where: SQLiteWhere(tableColumn: self.indexesMasterTable.nameTableColumn, value: name))
		}
	}
}
