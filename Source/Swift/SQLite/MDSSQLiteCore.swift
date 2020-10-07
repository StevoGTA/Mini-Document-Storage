//
//  MDSSQLiteCore.swift
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

	// MARK: Class methods
	//------------------------------------------------------------------------------------------------------------------
	static func info(infoTable :SQLiteTable, resultsRow :SQLiteResultsRow) ->
			(id :Int64, documentRevisionInfo :MDSDocumentRevisionInfo, active :Bool) {
		// Process results
		let	id :Int64 = resultsRow.integer(for: infoTable.idTableColumn)!
		let	documentID = resultsRow.text(for: infoTable.documentIDTableColumn)!
		let	revision :Int = resultsRow.integer(for: infoTable.revisionTableColumn)!
		let	active :Bool = resultsRow.integer(for: infoTable.activeTableColumn)! == 1

		return (id, MDSDocumentRevisionInfo(documentID: documentID, revision: revision), active)
	}

	//------------------------------------------------------------------------------------------------------------------
	static func documentBackingInfo(id :Int64, documentRevisionInfo :MDSDocumentRevisionInfo, contentTable :SQLiteTable,
			resultsRow :SQLiteResultsRow) -> MDSDocumentBackingInfo<MDSSQLiteDocumentBacking> {
		// Process results
		let	creationDate = Date(fromRFC3339Extended: resultsRow.text(for: contentTable.creationDateTableColumn)!)!
		let	modificationDate =
					Date(fromRFC3339Extended: resultsRow.text(for: contentTable.modificationDateTableColumn)!)!
		let	propertyMap =
					try! JSONSerialization.jsonObject(
							with: resultsRow.blob(for: contentTable.jsonTableColumn)!) as! [String : Any]

		return MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>(documentID: documentRevisionInfo.documentID,
				documentBacking:
						MDSSQLiteDocumentBacking(id: id, revision: documentRevisionInfo.revision,
								creationDate: creationDate, modificationDate: modificationDate,
								propertyMap: propertyMap))
	}

	//------------------------------------------------------------------------------------------------------------------
	static func key(for indexContentsTable :SQLiteTable, resultsRow :SQLiteResultsRow) -> String {
		// Return key
		resultsRow.text(for: indexContentsTable.keyTableColumn)!
	}

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
										SQLiteTableColumn("value", .text, [.notNull]),
									  ])
		self.infoTable.create()

		self.documentsMasterTable =
				self.sqliteDatabase.table(name: "Documents",
						tableColumns: [
										SQLiteTableColumn("type", .text, [.notNull, .unique]),
										SQLiteTableColumn("lastRevision", .integer4, [.notNull]),
									  ])
		self.documentsMasterTable.create()

		self.collectionsMasterTable =
				self.sqliteDatabase.table(name: "Collections",
						tableColumns: [
										SQLiteTableColumn("name", .text, [.notNull, .unique]),
										SQLiteTableColumn("version", .integer2, [.notNull]),
										SQLiteTableColumn("lastRevision", .integer4, [.notNull]),
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
	func string(for key :String) -> String? {
		// Retrieve value
		var	value :String?
		try! self.infoTable.select(tableColumns: [self.infoTable.valueTableColumn],
				where: SQLiteWhere(tableColumn: self.infoTable.keyTableColumn, value: key)) {
					// Process results
					value = $0.text(for: self.infoTable.valueTableColumn)!
				}

		return value
	}

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for key :String) {
		// Storing or removing
		if value != nil {
			// Store value
			self.infoTable.insertOrReplaceRow([
												(self.infoTable.keyTableColumn, key),
												(self.infoTable.valueTableColumn, value!),
											  ])
		} else {
			// Removing
			self.infoTable.deleteRows(self.infoTable.keyTableColumn, values: [key])
		}
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
												SQLiteTableColumn("revision", .integer4, [.notNull]),
												SQLiteTableColumn("active", .integer1, [.notNull]),
											  ])
			let	contentTable =
						self.sqliteDatabase.table(name: "\(tableTitleRoot)Contents",
								tableColumns: [
												contentIDTableColumn,
												SQLiteTableColumn("creationDate", .textWith(size: 23), [.notNull]),
												SQLiteTableColumn("modificationDate", .textWith(size: 23), [.notNull]),
												SQLiteTableColumn("json", .blob, [.notNull]),
											  ],
								references: [(contentIDTableColumn, infoTable, infoTable.idTableColumn)])

			// Create tables
			infoTable.create()
			contentTable.create()

			// Store in key value store
			self.documentTablesMap.set((infoTable, contentTable), for: documentType)

			return (infoTable, contentTable)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func currentRevision(for documentType :String) -> Int { self.documentLastRevisionMap.value(for: documentType) ?? 0 }

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
	func new(documentType :String, documentID :String, creationDate :Date? = nil, modificationDate :Date? = nil,
			propertyMap :MDSDocument.PropertyMap) ->
			(id :Int64, revision :Int, creationDate :Date, modificatinoDate :Date) {
		// Setup
		let	revision = nextRevision(for: documentType)
		let	creationDate = creationDate ?? Date()
		let	modificationDate = modificationDate ?? creationDate

		let	data :Data = try! JSONSerialization.data(withJSONObject: propertyMap)

		// Add to database
		let	(infoTable, contentTable) = documentTables(for: documentType)
		let	id =
				infoTable.insertRow([
										(infoTable.documentIDTableColumn, documentID),
										(infoTable.revisionTableColumn, revision),
										(infoTable.activeTableColumn, 1),
									])
		_ = contentTable.insertRow([
									(contentTable.idTableColumn, id),
									(contentTable.creationDateTableColumn, creationDate.rfc3339Extended),
									(contentTable.modificationDateTableColumn, modificationDate.rfc3339Extended),
									(contentTable.jsonTableColumn, data),
								   ])

		return (id, revision, creationDate, modificationDate)
	}

	//------------------------------------------------------------------------------------------------------------------
	func update(documentType :String, id :Int64, propertyMap :MDSDocument.PropertyMap) ->
			(revision :Int, modificationDate :Date) {
		// Setup
		let	revision = nextRevision(for: documentType)
		let	modificationDate = Date()
		let	data = try! JSONSerialization.data(withJSONObject: propertyMap)

		// Update
		let	(infoTable, contentTable) = documentTables(for: documentType)
		infoTable.update([(infoTable.revisionTableColumn, revision)],
				where: SQLiteWhere(tableColumn: infoTable.idTableColumn, value: id))
		contentTable.update(
				[
					(contentTable.modificationDateTableColumn, modificationDate.rfc3339Extended),
					(contentTable.jsonTableColumn, data)
				],
				where: SQLiteWhere(tableColumn: contentTable.idTableColumn, value: id))

		return (revision, modificationDate)
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove(documentType :String, id :Int64) {
		// Setup
		let	data = try! JSONSerialization.data(withJSONObject: [:], options: [])

		// Mark as not active
		let	(infoTable, contentTable) = documentTables(for: documentType)
		infoTable.update([(infoTable.activeTableColumn, 0)],
				where: SQLiteWhere(tableColumn: infoTable.idTableColumn, value: id))
		contentTable.update(
				[
					(contentTable.modificationDateTableColumn, Date().rfc3339Extended),
					(contentTable.jsonTableColumn, data)
				],
				where: SQLiteWhere(tableColumn: contentTable.idTableColumn, value: id))
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection(documentType :String, name :String, version :UInt, isUpToDate :Bool) -> Int {
		// Query database
		var	storedVersion :UInt?
		var	storedLastRevision :Int?
		try! self.collectionsMasterTable.select(
				tableColumns: [
								self.collectionsMasterTable.versionTableColumn,
								self.collectionsMasterTable.lastRevisionTableColumn,
							  ],
				where: SQLiteWhere(tableColumn: self.collectionsMasterTable.nameTableColumn, value: name)) {
					// Process results
					storedVersion = $0.integer(for: self.collectionsMasterTable.versionTableColumn)!
					storedLastRevision = $0.integer(for: self.collectionsMasterTable.lastRevisionTableColumn)!
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
					])

			// Update table
			if storedLastRevision != nil { table.drop() }
			table.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func sqliteTable(forCollectionNamed name :String) -> SQLiteTable { self.collectionTablesMap.value(for: name)! }

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
	func queryCollectionDocumentCount(name :String) -> UInt { self.collectionTablesMap.value(for: name)!.count() }

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
	func sqliteTable(forIndexNamed name :String) -> SQLiteTable { self.indexTablesMap.value(for: name)! }

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
