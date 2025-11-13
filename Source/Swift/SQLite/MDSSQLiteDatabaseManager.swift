//
//  MDSSQLiteDatabaseManager.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/29/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

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

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSSQLiteDatabaseManager
class MDSSQLiteDatabaseManager {

	// MARK: CacheValueInfo
	struct CacheValueInfo : Equatable {

		// MARK: Properties
		let	name :String
		let	valueType :MDSValueType
		let	selector :String

		var	info :[String : Any]
					{ ["name": self.name, "valueType": self.valueType.rawValue, "selector": self.selector] }

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(name :String, valueType :MDSValueType, selector :String) {
			// Store
			self.name = name
			self.valueType = valueType
			self.selector = selector
		}

		//--------------------------------------------------------------------------------------------------------------
		init(info :[String : Any]) {
			// Store
			self.name = info["name"] as! String
			self.valueType = MDSValueType(rawValue: info["valueType"] as! String)!
			self.selector = info["selector"] as! String
		}
	}

	// MARK: DocumentContentInfo
	struct DocumentContentInfo {

		// MARK: Properties
		let	id :Int64
		let	creationDate :Date
		let	modificationDate :Date
		let	propertyMap :[String : Any]
	}

	// MARK: DocumentInfo
	struct DocumentInfo {

		// MARK: Properties
		let	id :Int64
		let	documentID :String
		let	revision :Int
		let	active :Bool

		var	documentRevisionInfo :MDSDocument.RevisionInfo
				{ MDSDocument.RevisionInfo(documentID: self.documentID, revision: self.revision) }
	}

	// MARK: Types
	private	typealias DocumentTables =
					(infoTable :SQLiteTable, contentsTable :SQLiteTable, attachmentsTable :SQLiteTable)

	private	typealias CacheUpdateInfo =
						(valueInfoByID :[Int64 : [/* Name */ String : Any]], removedIDs :[Int64], lastRevision :Int?)
	private	typealias CollectionUpdateInfo = (includedIDs :[Int64], notIncludedIDs :[Int64], lastRevision :Int?)
	private	typealias IndexUpdateInfo =
						(keysInfos :[(keys :[String], id :Int64)], removedIDs :[Int64], lastRevision :Int?)

	// MARK: BatchInfo
	private class BatchInfo {

		// MARK: Instance methods
		//--------------------------------------------------------------------------------------------------------------
		func noteDocumentTypeNeedingLastRevisionWrite(documentType :String) {
			// Add
			self.documentLastRevisionTypesNeedingWrite.insert(documentType)
		}

		//--------------------------------------------------------------------------------------------------------------
		func noteCacheUpdate(name :String, valueInfoByID :[Int64 : [/* Name */ String : Any]]?, removedIDs :[Int64],
				lastRevision :Int?) {
			// Check for existing
			if let cacheUpdateInfo = self.cacheUpdateInfoByName[name] {
				// Update
				self.cacheUpdateInfoByName[name] =
						(cacheUpdateInfo.valueInfoByID
										.merging(valueInfoByID ?? [:],
												uniquingKeysWith: { $0.merging($1, uniquingKeysWith: { $1 }) }),
								cacheUpdateInfo.removedIDs + removedIDs, lastRevision)
			} else {
				// Add
				self.cacheUpdateInfoByName[name] = (valueInfoByID ?? [:], removedIDs, lastRevision)
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		func noteCollectionUpdate(name :String, includedIDs :[Int64]?, notIncludedIDs :[Int64]?, lastRevision :Int?) {
			// Check for existing
			if let collectionUpdateInfo = self.collectionUpdateInfoByName[name] {
				// Update
				self.collectionUpdateInfoByName[name] =
						(collectionUpdateInfo.includedIDs + (includedIDs ?? []),
								collectionUpdateInfo.notIncludedIDs + (notIncludedIDs ?? []), lastRevision)
			} else {
				// Add
				self.collectionUpdateInfoByName[name] = (includedIDs ?? [], notIncludedIDs ?? [], lastRevision)
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		func noteIndexUpdate(name :String, keysInfos :[(keys :[String], id :Int64)]?, removedIDs :[Int64]?,
				lastRevision :Int?) {
			// Check for existing
			if let indexInfo = self.indexUpdateInfoByName[name] {
				// Update
				self.indexUpdateInfoByName[name] =
						(indexInfo.keysInfos + (keysInfos ?? []), indexInfo.removedIDs + (removedIDs ?? []),
								lastRevision)
			} else {
				// Add
				self.indexUpdateInfoByName[name] = (keysInfos ?? [], removedIDs ?? [], lastRevision)
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		func iterateDocumentLastRevisionTypesNeedingWrite(_ proc :(_ documentType :String) -> Void) {
			// Iterate
			self.documentLastRevisionTypesNeedingWrite.forEach() { proc($0) }
		}

		//--------------------------------------------------------------------------------------------------------------
		func iterateCacheUpdateInfos(_ proc :(_ name :String, _ cacheUpdateInfo :CacheUpdateInfo) -> Void) {
			// Iterate
			self.cacheUpdateInfoByName.forEach() { proc($0, $1) }
		}


		//--------------------------------------------------------------------------------------------------------------
		func iterateCollectionUpdateInfos(
				_ proc :(_ name :String, _ collectionUpdateInfo :CollectionUpdateInfo) -> Void) {
			// Iterate
			self.collectionUpdateInfoByName.forEach() { proc($0, $1) }
		}

		//--------------------------------------------------------------------------------------------------------------
		func iterateIndexUpdateInfos(_ proc :(_ name :String, _ indexUpdateInfo :IndexUpdateInfo) -> Void) {
			// Iterate
			self.indexUpdateInfoByName.forEach() { proc($0, $1) }
		}

		// MARK: Properties
		private	var	documentLastRevisionTypesNeedingWrite = Set<String>()
		private	var	cacheUpdateInfoByName = [/* Cache name */ String : CacheUpdateInfo]()
		private	var	collectionUpdateInfoByName = [/* Collection name */ String : CollectionUpdateInfo]()
		private	var	indexUpdateInfoByName = [/* Index name */ String : IndexUpdateInfo]()
	}

	// MARK: AssociationsTable
	private struct AssociationsTable {

		// MARK: Properties
		static	let	nameTableColumn = SQLiteTableColumn("name", .text, [.notNull, .unique])
		static	let	fromTypeTableColumn = SQLiteTableColumn("fromType", .text, [.notNull])
		static	let	toTypeTableColumn = SQLiteTableColumn("toType", .text, [.notNull])
		static	let	tableColumns = [nameTableColumn, fromTypeTableColumn, toTypeTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase, internalsTable :SQLiteTable) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Associations", tableColumns: self.tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(for name :String, in table :SQLiteTable) ->
				(fromDocumentType :String, toDocumentType :String)? {
			// Iterate all rows
			var	info :(fromDocumentType :String, toDocumentType :String)?
			try! table.select(where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name)) {
				// Process values
				let	fromDocumentType = $0.text(for: self.fromTypeTableColumn)!
				let	toDocumentType = $0.text(for: self.toTypeTableColumn)!

				// Store
				info = (fromDocumentType, toDocumentType)
			}

			return info
		}

		//--------------------------------------------------------------------------------------------------------------
		static func addOrUpdate(name :String, fromDocumentType :String, toDocumentType :String, in table :SQLiteTable) {
			// Insert or replace
			table.insertOrReplaceRow(
					[
						(self.nameTableColumn, name),
						(self.fromTypeTableColumn, fromDocumentType),
						(self.toTypeTableColumn, toDocumentType),
					])
		}
	}

	// MARK: AssociationContentsTable
	private struct AssociationContentsTable {

		// MARK: Properties
		static	let	fromIDTableColumn = SQLiteTableColumn("fromID", .integer, [])
		static	let	toIDTableColumn = SQLiteTableColumn("toID", .integer, [])
		static	let	tableColumns = [fromIDTableColumn, toIDTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase, name :String, internalsTable :SQLiteTable) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Association-\(name)", tableColumns: self.tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func count(fromID :Int64, in table :SQLiteTable) -> Int {
			// Return count
			return table.count(where: SQLiteWhere(tableColumn: self.fromIDTableColumn, value: fromID))
		}

		//--------------------------------------------------------------------------------------------------------------
		static func count(toID :Int64, in table :SQLiteTable) -> Int {
			// Return count
			return table.count(where: SQLiteWhere(tableColumn: self.toIDTableColumn, value: toID))
		}

		//--------------------------------------------------------------------------------------------------------------
		static func get(where sqliteWhere :SQLiteWhere? = nil, from table :SQLiteTable) ->
				[(fromID :Int64, toID :Int64)] {
			// Iterate all rows
			var	items = [(fromID :Int64, toID :Int64)]()
			try! table.select(where: sqliteWhere) {
				// Process values
				let	fromID = $0.integer(for: self.fromIDTableColumn)!
				let	toID = $0.integer(for: self.toIDTableColumn)!

				// Add item
				items.append((fromID, toID))
			}

			return items
		}

		//--------------------------------------------------------------------------------------------------------------
		static func add(items :[(fromID :Int64, toID :Int64)], to table :SQLiteTable) {
			// Iterate items
			items.forEach() {
				// Insert
				table.insertOrReplaceRow(
						[
							(self.fromIDTableColumn, $0.fromID),
							(self.toIDTableColumn, $0.toID),
						])
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		static func remove(items :[(fromID :Int64, toID :Int64)], from table :SQLiteTable) {
			// Iterate items
			items.forEach() {
				// Delete
				table.deleteRow(
						where:
								SQLiteWhere(tableColumn: self.fromIDTableColumn, value: $0.fromID)
										.and(tableColumn: self.toIDTableColumn, value: $0.toID))
			}
		}
	}

	// MARK: CachesTable
	private struct CachesTable {

		// MARK: Properties
		static	let	nameTableColumn = SQLiteTableColumn("name", .text, [.notNull, .unique])
		static	let	typeTableColumn = SQLiteTableColumn("type", .text, [.notNull])
		static	let	relevantPropertiesTableColumn = SQLiteTableColumn("relevantProperties", .text, [.notNull])
		static	let	infoTableColumn = SQLiteTableColumn("info", .blob, [.notNull])
		static	let	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", .integer, [.notNull])
		static	let	tableColumns =
							[nameTableColumn, typeTableColumn, relevantPropertiesTableColumn, infoTableColumn,
									lastRevisionTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase, internalsTable :SQLiteTable) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Caches", tableColumns: self.tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(for name :String, in table :SQLiteTable) ->
				(type :String, relevantProperties :[String], valueInfos :[CacheValueInfo], lastRevision :Int)? {
			// Query
			var	info :(type :String, relevantProperties :[String], valueInfos :[CacheValueInfo], lastRevision :Int)?
			try! table.select(
					tableColumns:
							[
								self.typeTableColumn,
								self.relevantPropertiesTableColumn,
								self.infoTableColumn,
								self.lastRevisionTableColumn
							],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name)) {
						// Get info
						let	type = $0.text(for: self.typeTableColumn)!
						let	relevantProperties =
								$0.text(for: self.relevantPropertiesTableColumn)!
										.components(separatedBy: ",")
										.filter({ !$0.isEmpty })
						let	cacheValueInfos =
									(try! JSONSerialization.jsonObject(with: $0.blob(for: self.infoTableColumn)!) as!
											[[String : String]]).map({ CacheValueInfo(info: $0) })
						let	lastRevision = Int($0.integer(for: self.lastRevisionTableColumn)!)

						// Set current info
						info = (type, relevantProperties, cacheValueInfos, lastRevision)
					}

			return info
		}

		//--------------------------------------------------------------------------------------------------------------
		static func addOrUpdate(name :String, documentType :String, relevantProperties :[String],
				valueInfos :[CacheValueInfo], in table :SQLiteTable) {
			// Insert or replace
			table.insertOrReplaceRow(
					[
						(self.nameTableColumn, name),
						(self.typeTableColumn, documentType),
						(self.relevantPropertiesTableColumn, String(combining: relevantProperties, with: ",")),
						(self.infoTableColumn,
								try! JSONSerialization.data(withJSONObject: valueInfos.map({ $0.info }))),
						(self.lastRevisionTableColumn, 0),
					])
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(name :String, lastRevision :Int, in table :SQLiteTable) {
			// Update
			table.update([(self.lastRevisionTableColumn, lastRevision)],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name))
		}
	}

	// MARK: CacheContentsTable
	private struct CacheContentsTable {

		// MARK: Properties
		static	let	idTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase, name :String, valueInfos :[CacheValueInfo],
				internalsTable :SQLiteTable) -> SQLiteTable {
			// Setup
			let	tableColumns =
						[self.idTableColumn] + valueInfos.map({ SQLiteTableColumn($0.name, .integer, [.notNull]) })
			let	table = database.table(name: "Cache-\(name)", options: [.withoutRowID], tableColumns: tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(valueInfoByID :[Int64 : [/* Name */ String : Any]]?, removedIDs :[Int64],
				in table :SQLiteTable) {
			// Update
			if !removedIDs.isEmpty { table.deleteRows(self.idTableColumn, values: removedIDs) }
			valueInfoByID?.forEach() {
				// Insert or replace row for this id
				table.insertOrReplaceRow(
						[(self.idTableColumn, $0.key)] + $0.value.map({ (table.tableColumn(for: $0.key), $0.value) }))
			}
		}
	}

	// MARK: CollectionsTable
	private struct CollectionsTable {

		// MARK: Properties
		static	let	nameTableColumn = SQLiteTableColumn("name", .text, [.notNull, .unique])
		static	let	typeTableColumn = SQLiteTableColumn("type", .text, [.notNull])
		static	let	relevantPropertiesTableColumn = SQLiteTableColumn("relevantProperties", .text, [.notNull])
		static	let	isIncludedSelectorTableColumn = SQLiteTableColumn("isIncludedSelector", .text, [.notNull])
		static	let	isIncludedSelectorInfoTableColumn = SQLiteTableColumn("isIncludedSelectorInfo", .blob, [.notNull])
		static	let	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", .integer, [.notNull])
		static	let	tableColumns =
							[nameTableColumn, typeTableColumn, relevantPropertiesTableColumn,
									isIncludedSelectorTableColumn, isIncludedSelectorInfoTableColumn,
									lastRevisionTableColumn]

		static	let	versionTableColumn = SQLiteTableColumn("version", .integer, [.notNull])

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase, internalsTable :SQLiteTable, infoTable :SQLiteTable) ->
				SQLiteTable {
			// Create table
			let	table = database.table(name: "Collections", tableColumns: self.tableColumns)

			// Check if need to create/migrate
			let	version =
						InternalsTable.version(for: table, in: internalsTable) ??
								InfoTable.int(for: "version", in: infoTable)
			if version == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 2, for: table, in: internalsTable)
			} else if version! == 1 {
				// Migrate to version 2
				try! table.migrate() {
					// Get old info
					let	name = $0.text(for: self.nameTableColumn)!
					let	version = $0.integer(for: self.versionTableColumn)!
					let	lastRevision = $0.integer(for: self.lastRevisionTableColumn)!

					return [
							(self.nameTableColumn, name),
							(self.typeTableColumn, ""),
							(self.relevantPropertiesTableColumn, ""),
							(self.isIncludedSelectorTableColumn, ""),
							(self.isIncludedSelectorInfoTableColumn,
									try! JSONSerialization.data(withJSONObject: ["version": version])),
							(self.lastRevisionTableColumn, lastRevision),
						   ]
				}

				// Store version
				InternalsTable.set(version: 2, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(for name :String, in table :SQLiteTable) ->
				(type :String, relevantProperties :[String], isIncludedSelector :String,
						isIncludedSelectorInfo :[String : Any], lastRevision :Int)? {
			// Query
			var	info
						:(type :String, relevantProperties :[String], isIncludedSelector :String,
								isIncludedSelectorInfo :[String : Any], lastRevision :Int)?
			try! table.select(
					tableColumns:
							[
								self.typeTableColumn,
								self.relevantPropertiesTableColumn,
								self.isIncludedSelectorTableColumn,
								self.isIncludedSelectorInfoTableColumn,
								self.lastRevisionTableColumn,
							],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name)) {
						// Get info
						let	type = $0.text(for: self.typeTableColumn)!
						let	relevantProperties =
								$0.text(for: self.relevantPropertiesTableColumn)!
										.components(separatedBy: ",")
										.filter({ !$0.isEmpty })
						let	isIncludedSelector = $0.text(for: self.isIncludedSelectorTableColumn)!
						let	isIncludedSelectorInfo =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: self.isIncludedSelectorInfoTableColumn)!) as!
											[String : Any]
						let	lastRevision = Int($0.integer(for: self.lastRevisionTableColumn)!)

						// Set current info
						info = (type, relevantProperties, isIncludedSelector, isIncludedSelectorInfo, lastRevision)
					}

			return info
		}

		//--------------------------------------------------------------------------------------------------------------
		static func addOrUpdate(name :String, documentType :String, relevantProperties :[String],
				isIncludedSelector :String, isIncludedSelectorInfo :[String : Any], lastRevision :Int,
				in table :SQLiteTable) {
			// Insert or replace
			table.insertOrReplaceRow(
					[
						(self.nameTableColumn, name),
						(self.typeTableColumn, documentType),
						(self.relevantPropertiesTableColumn, String(combining: relevantProperties, with: ",")),
						(self.isIncludedSelectorTableColumn, isIncludedSelector),
						(self.isIncludedSelectorInfoTableColumn,
								try! JSONSerialization.data(withJSONObject: isIncludedSelectorInfo)),
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
		static func table(in database :SQLiteDatabase, name :String, internalsTable :SQLiteTable) -> SQLiteTable {
			// Setup
			let	table =
						database.table(name: "Collection-\(name)", options: [.withoutRowID],
								tableColumns: self.tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(includedIDs :[Int64]?, notIncludedIDs :[Int64]?, in table :SQLiteTable) {
			// Update
			if !(notIncludedIDs?.isEmpty ?? true) { table.deleteRows(self.idTableColumn, values: notIncludedIDs!) }
			if !(includedIDs?.isEmpty ?? true) { table.insertOrReplaceRows(self.idTableColumn, values: includedIDs!) }
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
		static func table(in database :SQLiteDatabase, internalsTable :SQLiteTable) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Documents", tableColumns: self.tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(for resultsRow :SQLiteResultsRow) -> (documentType :String, lastRevision :Int) {
			// Process results
			let	documentType = resultsRow.text(for: self.typeTableColumn)!
			let	lastRevision = Int(resultsRow.integer(for: self.lastRevisionTableColumn)!)

			return (documentType, lastRevision)
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
		static func table(in database :SQLiteDatabase, nameRoot :String, internalsTable :SQLiteTable) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "\(nameRoot)s", tableColumns: self.tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func id(for documentID :String, in table :SQLiteTable) -> Int64? {
			// Retrieve id
			var	id :Int64?
			try! table.select(tableColumns: [self.idTableColumn],
					where: SQLiteWhere(tableColumn: self.documentIDTableColumn, value: documentID))
					{ id = $0.integer(for: self.idTableColumn)! }

			return id
		}

		//--------------------------------------------------------------------------------------------------------------
		static func idByDocumentID(for documentIDs :[String], in table :SQLiteTable) -> [String : Int64] {
			// Retrieve id map
			var	idByDocumentID = [String : Int64]()
			try! table.select(tableColumns: [self.idTableColumn, self.documentIDTableColumn],
					where: SQLiteWhere(tableColumn: self.documentIDTableColumn, values: documentIDs))
					{
						// Process values
						let	id = $0.integer(for: self.idTableColumn)!
						let	documentID = $0.text(for: self.documentIDTableColumn)!

						// Update map
						idByDocumentID[documentID] = id
					}

			return idByDocumentID
		}

		//--------------------------------------------------------------------------------------------------------------
		static func documentIDByID(in table :SQLiteTable) -> [Int64 : String] {
			// Retrieve documentID map
			var	documentIDsByID = [Int64 : String]()
			try! table.select(tableColumns: [self.idTableColumn, self.documentIDTableColumn])
					{
						// Process values
						let	id = $0.integer(for: self.idTableColumn)!
						let	documentID = $0.text(for: self.documentIDTableColumn)!

						// Update map
						documentIDsByID[id] = documentID
					}

			return documentIDsByID
		}

		//--------------------------------------------------------------------------------------------------------------
		static func documentIDByID(for ids :[Int64], in table :SQLiteTable) -> [Int64 : String] {
			// Retrieve documentID map
			var	documentIDsByID = [Int64 : String]()
			try! table.select(tableColumns: [self.idTableColumn, self.documentIDTableColumn],
					where: SQLiteWhere(tableColumn: self.idTableColumn, values: ids))
					{
						// Process values
						let	id = $0.integer(for: self.idTableColumn)!
						let	documentID = $0.text(for: self.documentIDTableColumn)!

						// Update map
						documentIDsByID[id] = documentID
					}

			return documentIDsByID
		}

		//--------------------------------------------------------------------------------------------------------------
		static func documentIDByID(for documentIDs :[String], in table :SQLiteTable) -> [Int64 : String] {
			// Retrieve documentID map
			var	documentIDsByID = [Int64 : String]()
			try! table.select(tableColumns: [self.idTableColumn, self.documentIDTableColumn],
					where: SQLiteWhere(tableColumn: self.documentIDTableColumn, values: documentIDs))
					{
						// Process values
						let	id = $0.integer(for: self.idTableColumn)!
						let	documentID = $0.text(for: self.documentIDTableColumn)!

						// Update map
						documentIDsByID[id] = documentID
					}

			return documentIDsByID
		}

		//--------------------------------------------------------------------------------------------------------------
		static func documentRevisionInfoByID(for ids :[Int64], in table :SQLiteTable) ->
				[Int64 : (documentID :String, revision :Int)] {
			// Retrieve document revision map
			var	documentRevisionInfoByID = [Int64 : (documentID :String, revision :Int)]()
			try! table.select(tableColumns: [self.idTableColumn, self.documentIDTableColumn, self.revisionTableColumn],
					where: SQLiteWhere(tableColumn: self.idTableColumn, values: ids))
					{
						// Process values
						let	id = $0.integer(for: self.idTableColumn)!
						let	revision = Int($0.integer(for: self.revisionTableColumn)!)
						let	documentID = $0.text(for: self.documentIDTableColumn)!

						// Update map
						documentRevisionInfoByID[id] = (documentID, revision)
					}

			return documentRevisionInfoByID
		}

		//--------------------------------------------------------------------------------------------------------------
		static func documentInfo(for resultsRow :SQLiteResultsRow) -> DocumentInfo {
			// Process results
			let	id :Int64 = resultsRow.integer(for: self.idTableColumn)!
			let	documentID = resultsRow.text(for: self.documentIDTableColumn)!
			let	revision = Int(resultsRow.integer(for: self.revisionTableColumn)!)
			let	active :Bool = resultsRow.integer(for: self.activeTableColumn)! == 1

			return DocumentInfo(id: id, documentID: documentID, revision: revision, active: active)
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

	// MARK: DocumentTypeContentsTable
	private struct DocumentTypeContentsTable {

		// MARK: Properties
		static	let	idTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])
		static	let	creationDateTableColumn = SQLiteTableColumn("creationDate", .text, [.notNull])
		static	let	modificationDateTableColumn = SQLiteTableColumn("modificationDate", .text, [.notNull])
		static	let	jsonTableColumn = SQLiteTableColumn("json", .blob, [.notNull])
		static	let	tableColumns =
							[idTableColumn, creationDateTableColumn, modificationDateTableColumn, jsonTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase, nameRoot :String, infoTable :SQLiteTable,
				internalsTable :SQLiteTable) -> SQLiteTable {
			// Create table
			let	table =
						database.table(name: "\(nameRoot)Contents", tableColumns: self.tableColumns,
								references: [(self.idTableColumn, infoTable, DocumentTypeInfoTable.idTableColumn)])

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(for resultsRow :SQLiteResultsRow) ->
				(id :Int64, creationDate :Date, modificationDate :Date, propertyMap :[String : Any]) {
			// Process results
			let	id :Int64 = resultsRow.integer(for: self.idTableColumn)!
			let	creationDate = Date(fromRFC3339Extended: resultsRow.text(for: self.creationDateTableColumn)!)!
			let	modificationDate = Date(fromRFC3339Extended: resultsRow.text(for: self.modificationDateTableColumn)!)!
			let	propertyMap =
						try! JSONSerialization.jsonObject(
								with: resultsRow.blob(for: self.jsonTableColumn)!) as! [String : Any]

			return (id, creationDate, modificationDate, propertyMap)
		}

		//--------------------------------------------------------------------------------------------------------------
		static func add(id :Int64, creationDate :Date, modificationDate :Date, propertyMap :[String : Any],
				to table :SQLiteTable) {
			// Insert
			_ = table.insertRow([
									(self.idTableColumn, id),
									(self.creationDateTableColumn, creationDate.rfc3339ExtendedString),
									(self.modificationDateTableColumn, modificationDate.rfc3339ExtendedString),
									(self.jsonTableColumn, try! JSONSerialization.data(withJSONObject: propertyMap)),
								])
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(id :Int64, modificationDate :Date, propertyMap :[String : Any], in table :SQLiteTable) {
			// Update
			 table.update(
					[
						(self.modificationDateTableColumn, modificationDate.rfc3339ExtendedString),
						(self.jsonTableColumn, try! JSONSerialization.data(withJSONObject: propertyMap))
					],
					where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))
		}

		//--------------------------------------------------------------------------------------------------------------
		static func update(id :Int64, modificationDate :Date, in table :SQLiteTable) {
			// Update
			 table.update(
					[
						(self.modificationDateTableColumn, modificationDate.rfc3339ExtendedString),
					],
					where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))
		}

		//--------------------------------------------------------------------------------------------------------------
		static func remove(id :Int64, in table :SQLiteTable) {
			// Update
			table.update(
					[
						(self.modificationDateTableColumn, Date().rfc3339ExtendedString),
						(self.jsonTableColumn, try! JSONSerialization.data(withJSONObject: [String : Any]()))
					],
					where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))
		}
	}

	// MARK: DocumentTypeAttachmentsTable
	private struct DocumentTypeAttachmentsTable {

		// MARK: Properties
		static	let	idTableColumn = SQLiteTableColumn("id", .integer, [.primaryKey])
		static	let	attachmentIDTableColumn = SQLiteTableColumn("attachmentID", .text, [.notNull, .unique])
		static	let	revisionTableColumn = SQLiteTableColumn("revision", .integer, [.notNull])
		static	let	infoTableColumn = SQLiteTableColumn("info", .blob, [.notNull])
		static	let	contentTableColumn = SQLiteTableColumn("content", .blob, [.notNull])
		static	let	tableColumns =
							[idTableColumn, attachmentIDTableColumn, revisionTableColumn, infoTableColumn,
									contentTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase, nameRoot :String, internalsTable :SQLiteTable) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "\(nameRoot)Attachments", tableColumns: self.tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func add(id :Int64, attachmentID :String, info :[String : Any], content :Data, to table :SQLiteTable) ->
				Int {
			// Insert
			_ = table.insertRow([
									(self.idTableColumn, id),
									(self.attachmentIDTableColumn, attachmentID),
									(self.revisionTableColumn, 1),
									(self.infoTableColumn, try! JSONSerialization.data(withJSONObject: info)),
									(self.contentTableColumn, content),
								])

			return 1
		}

		//--------------------------------------------------------------------------------------------------------------
		static func documentAttachmentInfoByID(id :Int64, in table :SQLiteTable) -> MDSDocument.AttachmentInfoByID {
			// Get info
			var	documentAttachmentInfoByID = MDSDocument.AttachmentInfoByID()
			try! table.select(
					tableColumns: [self.attachmentIDTableColumn, self.revisionTableColumn, self.infoTableColumn],
					 where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))  {
						// Process values
						let	attachmentID = $0.text(for: self.attachmentIDTableColumn)!
						let	revision = Int($0.integer(for: self.revisionTableColumn)!)
						let	info =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: self.infoTableColumn)!) as! [String : Any]

						documentAttachmentInfoByID[attachmentID] =
								MDSDocument.AttachmentInfo(id: attachmentID, revision: revision, info: info)
					 }

			return documentAttachmentInfoByID
		}

		//--------------------------------------------------------------------------------------------------------------
		static func content(for resultsRow :SQLiteResultsRow) -> Data { resultsRow.blob(for: self.contentTableColumn)! }

		//--------------------------------------------------------------------------------------------------------------
		static func update(id :Int64, attachmentID :String, updatedInfo :[String : Any], updatedContent :Data,
				to table :SQLiteTable) -> Int {
			// Setup
			let	sqliteWhere = SQLiteWhere(tableColumn: self.attachmentIDTableColumn, value: attachmentID)

			// Get current revision
			var	revision :Int!
			try! table.select(tableColumns: [self.revisionTableColumn], where: sqliteWhere)
					{ revision = Int($0.integer(for: self.revisionTableColumn)!) }

			// Update
			table.update([
							(self.revisionTableColumn, revision + 1),
							(self.infoTableColumn, try! JSONSerialization.data(withJSONObject: updatedInfo)),
							(self.contentTableColumn, updatedContent),
						 ],
					where: sqliteWhere)

			return revision + 1
		}

		//--------------------------------------------------------------------------------------------------------------
		static func remove(id :Int64, attachmentID :String, in table :SQLiteTable) {
			// Delete rows
			table.deleteRows(self.attachmentIDTableColumn, values: [attachmentID])
		}

		//--------------------------------------------------------------------------------------------------------------
		static func remove(id :Int64, in table :SQLiteTable) {
			// Delete rows
			table.deleteRows(self.idTableColumn, values: [id])
		}
	}

	// MARK: IndexesTable
	private struct IndexesTable {

		// MARK: Properties
		static	let	nameTableColumn = SQLiteTableColumn("name", .text, [.notNull, .unique])
		static	let	typeTableColumn = SQLiteTableColumn("type", .text, [.notNull])
		static	let	relevantPropertiesTableColumn = SQLiteTableColumn("relevantProperties", .text, [.notNull])
		static	let	keysSelectorTableColumn = SQLiteTableColumn("keysSelector", .text, [.notNull])
		static	let	keysSelectorInfoTableColumn = SQLiteTableColumn("keysSelectorInfo", .blob, [.notNull])
		static	let	lastRevisionTableColumn = SQLiteTableColumn("lastRevision", .integer, [.notNull])
		static	let	tableColumns =
							[nameTableColumn, typeTableColumn, relevantPropertiesTableColumn, keysSelectorTableColumn,
									keysSelectorInfoTableColumn, lastRevisionTableColumn]

		static	let	versionTableColumn = SQLiteTableColumn("version", .integer, [.notNull])

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase, internalsTable :SQLiteTable, infoTable :SQLiteTable) ->
				SQLiteTable {
			// Create table
			let	table = database.table(name: "Indexes", tableColumns: self.tableColumns)

			// Check if need to create/migrate
			let	version =
						InternalsTable.version(for: table, in: internalsTable) ??
								InfoTable.int(for: "version", in: infoTable)
			if version == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 2, for: table, in: internalsTable)
			} else if version! == 1 {
				// Migrate to version 2
				try! table.migrate() {
					// Get old info
					let	name = $0.text(for: self.nameTableColumn)!
					let	version = $0.integer(for: self.versionTableColumn)!
					let	lastRevision = $0.integer(for: self.lastRevisionTableColumn)!

					return [
							(self.nameTableColumn, name),
							(self.typeTableColumn, ""),
							(self.relevantPropertiesTableColumn, ""),
							(self.keysSelectorTableColumn, ""),
							(self.keysSelectorInfoTableColumn,
									try! JSONSerialization.data(withJSONObject: ["version": version])),
							(self.lastRevisionTableColumn, lastRevision),
						   ]
				}

				// Store version
				InternalsTable.set(version: 2, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func info(for name :String, in table :SQLiteTable) ->
				(type :String, relevantProperties :[String], keysSelector :String, keysSelectorInfo :[String : Any],
						lastRevision :Int)? {
			// Query
			var	info
						:(type :String, relevantProperties :[String], keysSelector :String,
								keysSelectorInfo :[String : Any], lastRevision :Int)?
			try! table.select(
					tableColumns:
							[
								self.typeTableColumn,
								self.relevantPropertiesTableColumn,
								self.keysSelectorTableColumn,
								self.keysSelectorInfoTableColumn,
								self.lastRevisionTableColumn,
							],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name)) {
						// Get info
						let	type = $0.text(for: self.typeTableColumn)!
						let	relevantProperties =
								$0.text(for: self.relevantPropertiesTableColumn)!
										.components(separatedBy: ",")
										.filter({ !$0.isEmpty })
						let	keysSelector = $0.text(for: self.keysSelectorTableColumn)!
						let	keysSelectorInfo =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: self.keysSelectorInfoTableColumn)!) as! [String : Any]
						let	lastRevision = Int($0.integer(for: self.lastRevisionTableColumn)!)

						// Set current info
						info = (type, relevantProperties, keysSelector, keysSelectorInfo, lastRevision)
					}

			return info
		}

		//--------------------------------------------------------------------------------------------------------------
		static func addOrUpdate(name :String, documentType :String, relevantProperties :[String], keysSelector :String,
				keysSelectorInfo :[String : Any], lastRevision :Int, in table :SQLiteTable) {
			// Insert or replace
			table.insertOrReplaceRow(
					[
						(self.nameTableColumn, name),
						(self.typeTableColumn, documentType),
						(self.relevantPropertiesTableColumn, String(combining: relevantProperties, with: ",")),
						(self.keysSelectorTableColumn, keysSelector),
						(self.keysSelectorInfoTableColumn,
								try! JSONSerialization.data(withJSONObject: keysSelectorInfo)),
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
		static func table(in database :SQLiteDatabase, name :String, internalsTable :SQLiteTable) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Index-\(name)", options: [.withoutRowID], tableColumns: self.tableColumns)

			// Check if need to create
			if InternalsTable.version(for: table, in: internalsTable) == nil {
				// Create
				table.create()

				// Store version
				InternalsTable.set(version: 1, for: table, in: internalsTable)
			}

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func key(for resultsRow :SQLiteResultsRow) -> String { resultsRow.text(for: self.keyTableColumn)! }

		//--------------------------------------------------------------------------------------------------------------
		static func update(keysInfos :[(keys :[String], id :Int64)]?, removedIDs :[Int64]?, in table :SQLiteTable) {
			// Setup
			let	idsToRemove = (removedIDs ?? []) + (keysInfos?.map({ $0.id }) ?? [])

			// Update
			if !idsToRemove.isEmpty { table.deleteRows(self.idTableColumn, values: idsToRemove) }
			keysInfos?.forEach() { keysInfo in keysInfo.keys.forEach() {
				// Insert this key
				table.insertRow([
									(tableColumn: self.keyTableColumn, value: $0),
									(tableColumn: self.idTableColumn, value: keysInfo.id),
								])
			} }
		}
	}

	// MARK: InfoTable
	private struct InfoTable {

		// MARK: Properties
		static	let	keyTableColumn = SQLiteTableColumn("key", .text, [.primaryKey, .unique, .notNull])
		static	let	valueTableColumn = SQLiteTableColumn("value", .text, [.notNull])
		static	let	tableColumns = [keyTableColumn, valueTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase) -> SQLiteTable {
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

	// MARK: InternalTable
	private struct InternalTable {

		// MARK: Properties
		static	let	keyTableColumn = SQLiteTableColumn("key", .text, [.primaryKey, .unique, .notNull])
		static	let	valueTableColumn = SQLiteTableColumn("value", .text, [.notNull])
		static	let	tableColumns = [keyTableColumn, valueTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Internal", options: [.withoutRowID], tableColumns: self.tableColumns)
			table.create()

			return table
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

	// MARK: InternalsTable
	private struct InternalsTable {

		// MARK: Properties
		static	let	keyTableColumn = SQLiteTableColumn("key", .text, [.primaryKey, .unique, .notNull])
		static	let	valueTableColumn = SQLiteTableColumn("value", .text, [.notNull])
		static	let	tableColumns = [keyTableColumn, valueTableColumn]

		// MARK: Class methods
		//--------------------------------------------------------------------------------------------------------------
		static func table(in database :SQLiteDatabase) -> SQLiteTable {
			// Create table
			let	table = database.table(name: "Internals", options: [.withoutRowID], tableColumns: self.tableColumns)
			table.create()

			return table
		}

		//--------------------------------------------------------------------------------------------------------------
		static func version(for table :SQLiteTable, in internalsTable :SQLiteTable) -> Int? {
			// Retrieve value
			var	value :Int? = nil
			try! internalsTable.select(tableColumns: [self.valueTableColumn],
					where: SQLiteWhere(tableColumn: self.keyTableColumn, value: table.name + "TableVersion")) {
						// Process values
						value = Int($0.text(for: self.valueTableColumn)!)!
					}

			return value
		}

		//--------------------------------------------------------------------------------------------------------------
		static func set(version :Int, for table :SQLiteTable, in internalsTable :SQLiteTable) {
			// Update
			internalsTable.insertOrReplaceRow([
										(self.keyTableColumn, table.name + "TableVersion"),
										(self.valueTableColumn, version),
									 ])
		}
	}

	// MARK: Properties
			var	variableNumberLimit :Int { self.infoTable.variableNumberLimit }

	private	let	database :SQLiteDatabase

	private	let	batchInfoByThread = LockingDictionary<Thread, BatchInfo>()

	private	let	associationsTable :SQLiteTable
	private	let	associationTablesByName = LockingDictionary</* Association name */ String, SQLiteTable>()

	private	let	cachesTable :SQLiteTable
	private	let	cacheTablesByName = LockingDictionary</* Cache name */ String, SQLiteTable>()

	private	let	collectionsTable :SQLiteTable
	private	let	collectionTablesByName = LockingDictionary</* Collection name */ String, SQLiteTable>()

	private	let	documentsTable :SQLiteTable
	private	let	documentTablesByDocumentType = LockingDictionary</* Document type */ String, DocumentTables>()
	private	let	documentLastRevisionByDocumentType = LockingDictionary</* Document type */ String, Int>()

	private	let	indexesTable :SQLiteTable
	private	let	indexTablesByName = LockingDictionary</* Index name */ String, SQLiteTable>()

	private	let	infoTable :SQLiteTable

	private	let	internalTable :SQLiteTable

	private	let	internalsTable :SQLiteTable

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(database :SQLiteDatabase) {
		// Store
		self.database = database

		// Setup tables
		self.infoTable = InfoTable.table(in: self.database)
		self.internalsTable = InternalsTable.table(in: self.database)

		self.associationsTable = AssociationsTable.table(in: self.database, internalsTable: self.internalsTable)
		self.cachesTable = CachesTable.table(in: self.database, internalsTable: self.internalsTable)
		self.collectionsTable =
				CollectionsTable.table(in: self.database, internalsTable: self.internalsTable,
						infoTable: self.infoTable)
		self.documentsTable = DocumentsTable.table(in: self.database, internalsTable: self.internalsTable)
		self.indexesTable =
				IndexesTable.table(in: self.database, internalsTable: self.internalsTable,
						infoTable: self.infoTable)
		self.internalTable = InternalTable.table(in: self.database)

		// Finalize setup
		InfoTable.set(value: nil, for: "version", in: self.infoTable)

		try! self.documentsTable.select() {
			// Process results
			let	(documentType, lastRevision) = DocumentsTable.info(for: $0)

			// Update
			self.documentLastRevisionByDocumentType.set(lastRevision, for: documentType)
		}
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func associationRegister(name :String, fromDocumentType :String, toDocumentType :String) {
		// Register
		AssociationsTable.addOrUpdate(name: name, fromDocumentType: fromDocumentType, toDocumentType: toDocumentType,
				in: self.associationsTable)

		// Create contents table
		self.associationTablesByName.set(
				AssociationContentsTable.table(in: self.database, name: name, internalsTable: self.internalsTable),
				for: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationInfo(for name :String) -> (fromDocumentType :String, toDocumentType :String)? {
		// Get info
		if let info = AssociationsTable.info(for: name, in: self.associationsTable) {
			// Found
			let	associationContentsTable =
						AssociationContentsTable.table(in: self.database, name: name,
								internalsTable: self.internalsTable)
			self.associationTablesByName.set(associationContentsTable, for: name)

			return info
		} else {
			// Not found
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGet(name :String, fromDocumentType :String, toDocumentType :String) -> [MDSAssociation.Item] {
		// Setup
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		let	toDocumentTables = documentTables(for: toDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Get all items
		let	items = AssociationContentsTable.get(from: associationContentsTable)
		let	fromDocumentIDByID =
					DocumentTypeInfoTable.documentIDByID(for: Array(Set<Int64>(items.map({ $0.fromID }))),
							in: fromDocumentTables.infoTable)
		let	toDocumentIDByID =
					DocumentTypeInfoTable.documentIDByID(for: Array(Set<Int64>(items.map({ $0.toID }))),
							in: toDocumentTables.infoTable)

		return items.map(
				{ MDSAssociation.Item(fromDocumentID: fromDocumentIDByID[$0.fromID]!,
						toDocumentID: toDocumentIDByID[$0.toID]!) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGet(name :String, fromDocumentID :String, fromDocumentType :String, toDocumentType :String)
			throws -> [MDSAssociation.Item] {
		// Setup
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		guard let fromID = DocumentTypeInfoTable.id(for: fromDocumentID, in: fromDocumentTables.infoTable) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}
		let	toDocumentTables = documentTables(for: toDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Get items
		let	items =
					AssociationContentsTable.get(
							where: SQLiteWhere(tableColumn: AssociationContentsTable.fromIDTableColumn, value: fromID),
							from: associationContentsTable)
		let	toDocumentIDByID =
					DocumentTypeInfoTable.documentIDByID(for: Array(Set<Int64>(items.map({ $0.toID }))),
							in: toDocumentTables.infoTable)

		return items.map(
				{ MDSAssociation.Item(fromDocumentID: fromDocumentID, toDocumentID: toDocumentIDByID[$0.toID]!) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGet(name :String, fromDocumentType :String, toDocumentID :String, toDocumentType :String) throws ->
			[MDSAssociation.Item] {
		// Setup
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		let	toDocumentTables = documentTables(for: toDocumentType)
		guard let toID = DocumentTypeInfoTable.id(for: toDocumentID, in: toDocumentTables.infoTable) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: toDocumentID)
		}
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Get items
		let	items =
					AssociationContentsTable.get(
							where: SQLiteWhere(tableColumn: AssociationContentsTable.toIDTableColumn, value: toID),
							from: associationContentsTable)
		let	fromDocumentIDByID =
					DocumentTypeInfoTable.documentIDByID(for: Array(Set<Int64>(items.map({ $0.fromID }))),
							in: fromDocumentTables.infoTable)

		return items.map(
				{ MDSAssociation.Item(fromDocumentID: fromDocumentIDByID[$0.fromID]!, toDocumentID: toDocumentID) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetCount(name :String, fromDocumentID :String, fromDocumentType :String) -> Int? {
		// Setup
		let	documentTables = self.documentTables(for: fromDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Get id
		guard let id = DocumentTypeInfoTable.id(for: fromDocumentID, in: documentTables.infoTable) else { return nil }

		return AssociationContentsTable.count(fromID: id, in: associationContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetCount(name :String, toDocumentID :String, toDocumentType :String) -> Int? {
		// Setup
		let	documentTables = self.documentTables(for: toDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Get id
		guard let id = DocumentTypeInfoTable.id(for: toDocumentID, in: documentTables.infoTable) else { return nil }

		return AssociationContentsTable.count(toID: id, in: associationContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterateDocumentInfos(name :String, fromDocumentID :String, fromDocumentType :String,
			toDocumentType :String, startIndex :Int, count :Int?, proc :(_ documentInfo :DocumentInfo) -> Void) throws {
		// Setup
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		guard let fromID = DocumentTypeInfoTable.id(for: fromDocumentID, in: fromDocumentTables.infoTable) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}
		let	toDocumentTables = documentTables(for: toDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Iterate rows
		try! associationContentsTable.select(tableColumns: DocumentTypeInfoTable.tableColumns,
				innerJoin:
						SQLiteInnerJoin(associationContentsTable,
								tableColumn: AssociationContentsTable.toIDTableColumn, to: toDocumentTables.infoTable,
								otherTableColumn: DocumentTypeInfoTable.idTableColumn),
				where: SQLiteWhere(tableColumn: AssociationContentsTable.fromIDTableColumn, value: fromID),
				orderBy: SQLiteOrderBy(tableColumn: AssociationContentsTable.toIDTableColumn),
				limit: SQLiteLimit(limit: count, offset: startIndex))
				{ proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterateDocumentInfos(name :String, toDocumentID :String, toDocumentType :String,
			fromDocumentType :String, startIndex :Int, count :Int?, proc :(_ documentInfo :DocumentInfo) -> Void)
			throws {
		// Setup
		let	toDocumentTables = documentTables(for: toDocumentType)
		guard let toID = DocumentTypeInfoTable.id(for: toDocumentID, in: toDocumentTables.infoTable) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: toDocumentID)
		}
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Iterate rows
		try! associationContentsTable.select(tableColumns: DocumentTypeInfoTable.tableColumns,
				innerJoin:
						SQLiteInnerJoin(associationContentsTable,
								tableColumn: AssociationContentsTable.fromIDTableColumn,
								to: fromDocumentTables.infoTable,
								otherTableColumn: DocumentTypeInfoTable.idTableColumn),
				where: SQLiteWhere(tableColumn: AssociationContentsTable.toIDTableColumn, value: toID),
				orderBy: SQLiteOrderBy(tableColumn: AssociationContentsTable.fromIDTableColumn),
				limit: SQLiteLimit(limit: count, offset: startIndex))
				{ proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationUpdate(name :String, updates :[MDSAssociation.Update], fromDocumentType :String,
			toDocumentType :String) {
		// Setup
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		let	fromIDByDocumentID =
					DocumentTypeInfoTable.idByDocumentID(
							for: Array(Set<String>(updates.map({ $0.item.fromDocumentID }))),
							in: fromDocumentTables.infoTable)

		let	toDocumentTables = documentTables(for: toDocumentType)
		let	toIDByDocumentID =
					DocumentTypeInfoTable.idByDocumentID(for: Array(Set<String>(updates.map({ $0.item.toDocumentID }))),
							in: toDocumentTables.infoTable)

		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Update Association
		AssociationContentsTable.remove(
				items:
						updates
								.filter({ $0.action == .remove })
								.map({ (fromIDByDocumentID[$0.item.fromDocumentID]!,
										toIDByDocumentID[$0.item.toDocumentID]!) }),
				from: associationContentsTable)
		AssociationContentsTable.add(
				items:
						updates
								.filter({ $0.action == .add })
								.map({ (fromIDByDocumentID[$0.item.fromDocumentID]!,
										toIDByDocumentID[$0.item.toDocumentID]!) }),
				to: associationContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationDetail(association :MDSAssociation, fromDocumentIDs :[String], cache :MDSCache,
			cachedValueNames :[String]) throws -> [[String : Any]] {
		// Preflight
		let	fromDocumentTables = documentTables(for: association.fromDocumentType)
		let	fromDocumentIDByID =
					DocumentTypeInfoTable.documentIDByID(for: fromDocumentIDs, in: fromDocumentTables.infoTable)
		if fromDocumentIDByID.count < fromDocumentIDs.count {
			// Did not resolve all documentIDs
			let	documentID = Set(fromDocumentIDs).symmetricDifference(fromDocumentIDByID.values).first!

			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}

		// Setup
		let	associationContentsTable = self.associationTablesByName.value(for: association.name)!

		let	cacheContentsTable = self.cacheTablesByName.value(for: cache.name)!
		let	cacheContentsTableColumns = cachedValueNames.map({ cacheContentsTable.tableColumn(for: $0) })

		let	toDocumentTables = documentTables(for: association.toDocumentType)

		let	tableColumns =
					[AssociationContentsTable.fromIDTableColumn, AssociationContentsTable.toIDTableColumn] +
							cacheContentsTableColumns

		var	infos = [[String : Any]]()
		var	toIDs = Set<Int64>()
		try! associationContentsTable.select(tableColumns: tableColumns,
				innerJoin:
						SQLiteInnerJoin(associationContentsTable,
								tableColumn: AssociationContentsTable.toIDTableColumn,
								to: cacheContentsTable,
								otherTableColumn: CacheContentsTable.idTableColumn),
				where:
						SQLiteWhere(tableColumn: AssociationContentsTable.fromIDTableColumn,
								values: Array(fromDocumentIDByID.keys)))
				{
					// Setup
					let	toID = $0.integer(for: AssociationContentsTable.toIDTableColumn)!
					var	info :[String : Any] =
							[
								"fromID": $0.integer(for: AssociationContentsTable.fromIDTableColumn)!,
								"toID": toID,
							]

					// Iterate cached value names
					for tableColumn in cacheContentsTableColumns {
						// Get SQLiteTableColumn
						switch tableColumn.kind {
							case .integer:	info[tableColumn.name] = $0.integer(for: tableColumn)
							case .real:		info[tableColumn.name] = $0.real(for: tableColumn)
							case .text:		info[tableColumn.name] = $0.text(for: tableColumn)
							case .blob:		info[tableColumn.name] = $0.blob(for: tableColumn)
							default:		break
						}
					}

					// Update
					infos.append(info)
					toIDs.insert(toID)
				}

		let	toDocumentIDByID = DocumentTypeInfoTable.documentIDByID(for: Array(toIDs), in: toDocumentTables.infoTable)

		return infos.map({
			// Update info
			var	info = $0
			info["fromID"] = fromDocumentIDByID[info["fromID"] as! Int64]!
			info["toID"] = toDocumentIDByID[info["toID"] as! Int64]!

			return info
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationSum(association :MDSAssociation, fromDocumentIDs :[String], cache :MDSCache,
			cachedValueNames :[String]) throws -> [String : Int64] {
		// Preflight
		let	fromDocumentTables = documentTables(for: association.fromDocumentType)
		let	fromDocumentIDByID =
					DocumentTypeInfoTable.documentIDByID(for: fromDocumentIDs, in: fromDocumentTables.infoTable)
		if fromDocumentIDByID.count < fromDocumentIDs.count {
			// Did not resolve all documentIDs
			let	documentID = Set(fromDocumentIDs).symmetricDifference(fromDocumentIDByID.values).first!

			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}

		// Setup
		let	associationContentsTable = self.associationTablesByName.value(for: association.name)!

		let	cacheContentsTable = self.cacheTablesByName.value(for: cache.name)!
		let	cacheContentsTableColumns = cachedValueNames.map({ cacheContentsTable.tableColumn(for: $0) })

		return try associationContentsTable.sum(tableColumns: cacheContentsTableColumns,
				innerJoin:
						SQLiteInnerJoin(associationContentsTable, tableColumn: AssociationContentsTable.toIDTableColumn,
								to: cacheContentsTable, otherTableColumn: CacheContentsTable.idTableColumn),
				where:
						SQLiteWhere(tableColumn: AssociationContentsTable.fromIDTableColumn,
								values: Array(fromDocumentIDByID.keys)),
				includeCount: true)
	}

	//------------------------------------------------------------------------------------------------------------------
	func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			cacheValueInfos :[CacheValueInfo]) -> Int {
		// Get current info
		let	currentInfo = CachesTable.info(for: name, in: self.cachesTable)

		// Setup table
		let	cacheContentsTable =
					CacheContentsTable.table(in: self.database, name: name, valueInfos: cacheValueInfos,
							internalsTable: self.internalsTable)
		self.cacheTablesByName.set(cacheContentsTable, for: name)

		// Compose next steps
		let	lastRevision :Int
		let	updateMainTable :Bool
		if currentInfo == nil {
			// New
			lastRevision = 0
			updateMainTable = true
		} else if (relevantProperties != currentInfo!.relevantProperties) ||
				(cacheValueInfos != currentInfo!.valueInfos) {
			// Info has changed
			lastRevision = 0
			updateMainTable = true
		} else {
			// No change
			lastRevision = currentInfo!.lastRevision
			updateMainTable = false
		}

		// Check if need to update the master table
		if updateMainTable {
			// New or updated
			CachesTable.addOrUpdate(name: name, documentType: documentType, relevantProperties: relevantProperties,
					valueInfos: cacheValueInfos, in: self.cachesTable)

			// Update table
			if currentInfo != nil { cacheContentsTable.drop() }
			cacheContentsTable.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func cacheInfo(for name :String) ->
			(documentType :String, relevantProperties :[String], valueInfos :[CacheValueInfo], lastRevision :Int)? {
		// Get info
		if let info = CachesTable.info(for: name, in: self.cachesTable) {
			// Found
			let	cacheContentsTable =
						CacheContentsTable.table(in: self.database, name: name, valueInfos: info.valueInfos,
								internalsTable: self.internalsTable)
			self.cacheTablesByName.set(cacheContentsTable, for: name)

			return (info.type, info.relevantProperties, info.valueInfos, info.lastRevision)
		} else {
			// Not found
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func cacheGetValues(cache :MDSCache, valueNames :[String], documentIDs :[String]?) throws ->
			[[String : Any]] {
		// Setup
		let	cacheContentsTable = self.cacheTablesByName.value(for: cache.name)!
		let	cacheContentsTableColumns = valueNames.map({ cacheContentsTable.tableColumn(for: $0) })

		let	documentTables = documentTables(for: cache.documentType)

		let	documentIDByID :[Int64 : String]
		if documentIDs != nil {
			// Setup
			documentIDByID = DocumentTypeInfoTable.documentIDByID(for: documentIDs!, in: documentTables.infoTable)

			if documentIDByID.count < documentIDs!.count {
				// Did not resolve all documentIDs
				let	documentID = Set(documentIDs!).symmetricDifference(documentIDByID.values).first!

				throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
			}
		} else {
			// Setup
			documentIDByID = DocumentTypeInfoTable.documentIDByID(in: documentTables.infoTable)
		}

		let	tableColumns = [CacheContentsTable.idTableColumn] + cacheContentsTableColumns

		// Check if have documentIDs
		var	infos = [[String : Any]]()
		if documentIDs != nil {
			// Iterate documentIDs
			try cacheContentsTable.select(tableColumns: tableColumns,
					where:
							SQLiteWhere(tableColumn: CacheContentsTable.idTableColumn,
									values: Array(documentIDByID.keys))) {
				// Setup
				let	documentID = documentIDByID[$0.integer(for: CacheContentsTable.idTableColumn)!]!
				var	info :[String : Any] = ["documentID": documentID]

				// Iterate cached value names
				for tableColumn in cacheContentsTableColumns {
					// Get SQLiteTableColumn
					switch tableColumn.kind {
						case .integer:	info[tableColumn.name] = $0.integer(for: tableColumn)
						case .real:		info[tableColumn.name] = $0.real(for: tableColumn)
						case .text:		info[tableColumn.name] = $0.text(for: tableColumn)
						case .blob:		info[tableColumn.name] = $0.blob(for: tableColumn)
						default:		break
					}
				}

				// Add to array
				infos.append(info)
			}
		} else {
			// All documentIDs
			try cacheContentsTable.select(tableColumns: tableColumns) {
				// Setup
				let	documentID = documentIDByID[$0.integer(for: CacheContentsTable.idTableColumn)!]!
				var	info :[String : Any] = ["documentID": documentID]

				// Iterate cached value names
				for tableColumn in cacheContentsTableColumns {
					// Get SQLiteTableColumn
					switch tableColumn.kind {
						case .integer:	info[tableColumn.name] = $0.integer(for: tableColumn)
						case .real:		info[tableColumn.name] = $0.real(for: tableColumn)
						case .text:		info[tableColumn.name] = $0.text(for: tableColumn)
						case .blob:		info[tableColumn.name] = $0.blob(for: tableColumn)
						default:		break
					}
				}

				// Add to array
				infos.append(info)
			}
		}

		return infos
	}

	//------------------------------------------------------------------------------------------------------------------
	func cacheUpdate(name :String, valueInfoByID :[Int64 : [/* Name */ String : Any]]?, removedIDs :[Int64],
			lastRevision :Int?) {
		// Check if in batch
		if let batchInfo = self.batchInfoByThread.value(for: .current) {
			// Update batch info
			batchInfo.noteCacheUpdate(name: name, valueInfoByID: valueInfoByID, removedIDs: removedIDs,
					lastRevision: lastRevision)
		} else {
			// Update
			cacheUpdateInternal(name: name, valueInfoByID: valueInfoByID, removedIDs: removedIDs,
					lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionRegister(name :String, documentType :String, relevantProperties :[String],
				isIncludedSelector :String, isIncludedSelectorInfo :[String : Any], isUpToDate :Bool) -> Int {
		// Get current info
		let currentInfo = CollectionsTable.info(for: name, in: self.collectionsTable)

		// Setup table
		let	collectionContentsTable =
					CollectionContentsTable.table(in: self.database, name: name, internalsTable: self.internalsTable)
		self.collectionTablesByName.set(collectionContentsTable, for: name)

		// Compose next steps
		let	lastRevision :Int
		let	updateMainTable :Bool
		if currentInfo == nil {
			// New
			lastRevision = isUpToDate ? self.documentLastRevisionByDocumentType.value(for: documentType) ?? 0 : 0
			updateMainTable = true
		} else if (relevantProperties != currentInfo!.relevantProperties) ||
				(isIncludedSelector != currentInfo!.isIncludedSelector) ||
				!isIncludedSelectorInfo.equals(currentInfo!.isIncludedSelectorInfo) {
			// Info has changed
			lastRevision = isUpToDate ? self.documentLastRevisionByDocumentType.value(for: documentType) ?? 0 : 0
			updateMainTable = true
		} else {
			// No change
			lastRevision = currentInfo!.lastRevision
			updateMainTable = false
		}

		// Check if need to update the master table
		if updateMainTable {
			// New or updated
			CollectionsTable.addOrUpdate(name: name, documentType: documentType, relevantProperties: relevantProperties,
					isIncludedSelector: isIncludedSelector, isIncludedSelectorInfo: isIncludedSelectorInfo,
					lastRevision: lastRevision, in: self.collectionsTable)

			// Update table
			if currentInfo != nil { collectionContentsTable.drop() }
			collectionContentsTable.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionInfo(for name :String) ->
			(documentType :String, relevantProperties :[String], isIncludedSelector :String,
					isIncludedSelectorInfo :[String : Any], lastRevision :Int)? {
		// Get info
		if let info = CollectionsTable.info(for: name, in: self.collectionsTable) {
			// Found
			let	collectionContentsTable =
						CollectionContentsTable.table(in: self.database, name: name,
								internalsTable: self.internalsTable)
			self.collectionTablesByName.set(collectionContentsTable, for: name)

			return (info.type, info.relevantProperties, info.isIncludedSelector, info.isIncludedSelectorInfo,
					info.lastRevision)
		} else {
			// Not found
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentCount(for name :String) -> Int { self.collectionTablesByName.value(for: name)!.count() }

	//------------------------------------------------------------------------------------------------------------------
	func collectionIterateDocumentInfos(for name :String, documentType :String, startIndex :Int, count :Int?,
			proc :(_ documentInfo :DocumentInfo) -> Void) {
		// Setup
		let	documentTables = documentTables(for: documentType)
		let	collectionContentsTable = self.collectionTablesByName.value(for: name)!

		// Iterate rows
		try! collectionContentsTable.select(
				innerJoin:
						SQLiteInnerJoin(collectionContentsTable, tableColumn: CollectionContentsTable.idTableColumn,
								to: documentTables.infoTable),
				orderBy: SQLiteOrderBy(tableColumn: CollectionContentsTable.idTableColumn),
				limit: SQLiteLimit(limit: count, offset: startIndex))
				{ proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionUpdate(name :String, includedIDs :[Int64]?, notIncludedIDs :[Int64]?, lastRevision :Int?) {
		// Check if in batch
		if let batchInfo = self.batchInfoByThread.value(for: .current) {
			// Update batch info
			batchInfo.noteCollectionUpdate(name: name, includedIDs: includedIDs, notIncludedIDs: notIncludedIDs,
					lastRevision: lastRevision)
		} else {
			// Update
			collectionUpdateInternal(name: name, includedIDs: includedIDs, notIncludedIDs: notIncludedIDs,
					lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentCreate(documentType :String, documentID :String, creationDate :Date?, modificationDate :Date?,
			propertyMap :[String : Any]) -> (id :Int64, revision :Int, creationDate :Date, modificationDate :Date) {
		// Setup
		let	revision = documentNextRevision(for: documentType)
		let	creationDateUse = creationDate ?? Date()
		let	modificationDateUse = modificationDate ?? creationDateUse
		let	documentTables = documentTables(for: documentType)

		// Add to database
		let	id = DocumentTypeInfoTable.add(documentID: documentID, revision: revision, to: documentTables.infoTable)
		DocumentTypeContentsTable.add(id: id, creationDate: creationDateUse, modificationDate: modificationDateUse,
				propertyMap: propertyMap, to: documentTables.contentsTable)

		return (id, revision, creationDateUse, modificationDateUse)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentCount(for documentType :String) -> Int { self.documentTables(for: documentType).infoTable.count() }

	//------------------------------------------------------------------------------------------------------------------
	func documentTypeIsKnown(_ documentType :String) -> Bool {
		// Check if have last revision for this document type
		self.documentLastRevisionByDocumentType.value(for: documentType) != nil
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentInfoIterate(documentType :String, documentIDs :[String],
			proc :(_ documentInfo :DocumentInfo) -> Void) {
		// Setup
		let	documentTables = documentTables(for: documentType)

		// Iterate rows
		try! documentTables.infoTable.select(
				where: SQLiteWhere(tableColumn: DocumentTypeInfoTable.documentIDTableColumn, values: documentIDs))
				{ proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentContentInfoIterate(documentType :String, documentInfos :[DocumentInfo],
			proc :(_ documentContentInfo :DocumentContentInfo) -> Void) {
		// Setup
		let	documentTables = documentTables(for: documentType)

		// Iterate rows
		try! documentTables.contentsTable.select(
				where:
						SQLiteWhere(tableColumn: DocumentTypeInfoTable.idTableColumn,
								values: documentInfos.map({ $0.id }))) {
					// Get info
					let	(id, creationDate, modificationDate, propertyMap) = DocumentTypeContentsTable.info(for: $0)

					// Call proc
					proc(
							DocumentContentInfo(id: id, creationDate: creationDate, modificationDate: modificationDate,
									propertyMap: propertyMap))
				}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentInfoIterate(documentType :String, sinceRevision :Int, count :Int?, activeOnly: Bool,
			proc :(_ documentInfo :DocumentInfo) -> Void) {
		// Setup
		let	documentTables = documentTables(for: documentType)

		// Iterate rows
		try! documentTables.infoTable.select(
				where:
						activeOnly ?
							SQLiteWhere(tableColumn: DocumentTypeInfoTable.revisionTableColumn, comparison: ">",
											value: sinceRevision)
									.and(tableColumn: DocumentTypeInfoTable.activeTableColumn, value: 1) :
							SQLiteWhere(tableColumn: DocumentTypeInfoTable.revisionTableColumn, comparison: ">",
											value: sinceRevision),
				orderBy: SQLiteOrderBy(tableColumn: DocumentTypeInfoTable.revisionTableColumn),
				limit: SQLiteLimit(limit: count)) { proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdate(documentType :String, id :Int64, propertyMap :[String : Any]) ->
			(revision :Int, modificationDate :Date) {
		// Setup
		let	revision = documentNextRevision(for: documentType)
		let	modificationDate = Date()
		let	documentTables = documentTables(for: documentType)

		// Update
		DocumentTypeInfoTable.update(id: id, to: revision, in: documentTables.infoTable)
		DocumentTypeContentsTable.update(id: id, modificationDate: modificationDate, propertyMap: propertyMap,
				in: documentTables.contentsTable)

		return (revision, modificationDate)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRemove(documentType :String, id :Int64) {
		// Setup
		let	documentTables = documentTables(for: documentType)

		// Remove
		DocumentTypeInfoTable.remove(id: id, in: documentTables.infoTable)
		DocumentTypeContentsTable.remove(id: id, in: documentTables.contentsTable)
		DocumentTypeAttachmentsTable.remove(id: id, in: documentTables.attachmentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentAdd(documentType :String, id :Int64, info: [String : Any], content :Data) ->
			(revision :Int, modificationDate :Date, documentAttachmentInfo :MDSDocument.AttachmentInfo) {
		// Setup
		let	revision = documentNextRevision(for: documentType)
		let	modificationDate = Date()
		let	attachmentID = UUID().base64EncodedString
		let	documentTables = documentTables(for: documentType)

		// Add attachment
		DocumentTypeInfoTable.update(id: id, to: revision, in: documentTables.infoTable)
		DocumentTypeContentsTable.update(id: id, modificationDate: modificationDate, in: documentTables.contentsTable)
		let	attachmentRevision =
					DocumentTypeAttachmentsTable.add(id: id, attachmentID: attachmentID, info: info, content: content,
							to: documentTables.attachmentsTable)

		return (revision, modificationDate,
				MDSDocument.AttachmentInfo(id: attachmentID, revision: attachmentRevision, info: info))
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentInfoByID(documentType :String, id :Int64) -> MDSDocument.AttachmentInfoByID {
		// Setup
		let	documentTables = documentTables(for: documentType)

		return DocumentTypeAttachmentsTable.documentAttachmentInfoByID(id: id, in: documentTables.attachmentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentContent(documentType :String, id :Int64, attachmentID :String) -> Data {
		// Setup
		let	documentTables = documentTables(for: documentType)

		// Iterate rows
		var	content :Data!
		try! documentTables.attachmentsTable.select(tableColumns: [DocumentTypeAttachmentsTable.contentTableColumn],
				where:
						SQLiteWhere(tableColumn: DocumentTypeAttachmentsTable.attachmentIDTableColumn,
								value: attachmentID))
				{ content = $0.blob(for: DocumentTypeAttachmentsTable.contentTableColumn) }

		return content
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentUpdate(documentType :String, id :Int64, attachmentID :String, updatedInfo :[String : Any],
			updatedContent :Data) ->
			(revision :Int, modificationDate :Date, documentAttachmentInfo :MDSDocument.AttachmentInfo) {
		// Setup
		let	revision = documentNextRevision(for: documentType)
		let	modificationDate = Date()
		let	documentTables = documentTables(for: documentType)

		// Update attachment
		DocumentTypeInfoTable.update(id: id, to: revision, in: documentTables.infoTable)
		DocumentTypeContentsTable.update(id: id, modificationDate: modificationDate, in: documentTables.contentsTable)
		let	attachmentRevision =
					DocumentTypeAttachmentsTable.update(id: id, attachmentID: attachmentID, updatedInfo: updatedInfo,
							updatedContent: updatedContent, to: documentTables.attachmentsTable)

		return (revision, modificationDate,
				MDSDocument.AttachmentInfo(id: attachmentID, revision: attachmentRevision, info: updatedInfo))
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentRemove(documentType :String, id :Int64, attachmentID :String) ->
			(revision :Int, modificationDate :Date) {
		// Setup
		let	revision = documentNextRevision(for: documentType)
		let	modificationDate = Date()
		let	documentTables = documentTables(for: documentType)

		// Remove attachment
		DocumentTypeInfoTable.update(id: id, to: revision, in: documentTables.infoTable)
		DocumentTypeContentsTable.update(id: id, modificationDate: modificationDate, in: documentTables.contentsTable)
		DocumentTypeAttachmentsTable.remove(id: id, attachmentID: attachmentID, in: documentTables.attachmentsTable)

		return (revision, modificationDate)
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexRegister(name :String, documentType :String, relevantProperties :[String], keysSelector :String,
				keysSelectorInfo :[String : Any]) -> Int {
		// Get current info
		let currentInfo = IndexesTable.info(for: name, in: self.indexesTable)

		// Setup table
		let	indexContentsTable =
					IndexContentsTable.table(in: self.database, name: name, internalsTable: self.internalsTable)
		self.indexTablesByName.set(indexContentsTable, for: name)

		// Compose next steps
		let	lastRevision :Int
		let	updateMainTable :Bool
		if currentInfo == nil {
			// New
			lastRevision = 0
			updateMainTable = true
		} else if (relevantProperties != currentInfo!.relevantProperties) ||
				(keysSelector != currentInfo!.keysSelector) || !keysSelectorInfo.equals(currentInfo!.keysSelectorInfo) {
			// Info has changed
			lastRevision = 0
			updateMainTable = true
		} else {
			// No change
			lastRevision = currentInfo!.lastRevision
			updateMainTable = false
		}

		// Check if need to update the master table
		if updateMainTable {
			// New or updated
			IndexesTable.addOrUpdate(name: name, documentType: documentType, relevantProperties: relevantProperties,
					keysSelector: keysSelector, keysSelectorInfo: keysSelectorInfo, lastRevision: lastRevision,
					in: self.indexesTable)

			// Update table
			if currentInfo != nil { indexContentsTable.drop() }
			indexContentsTable.create()
		}

		return lastRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexInfo(for name :String) ->
			(documentType :String, relevantProperties :[String], keysSelector :String, keysSelectorInfo :[String : Any],
					lastRevision :Int)? {
		// Get info
		if let info = IndexesTable.info(for: name, in: self.indexesTable) {
			// Found
			let	indexContentsTable =
						IndexContentsTable.table(in: self.database, name: name, internalsTable: self.internalsTable)
			self.indexTablesByName.set(indexContentsTable, for: name)

			return (info.type, info.relevantProperties, info.keysSelector, info.keysSelectorInfo, info.lastRevision)
		} else {
			// Not found
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexIterateDocumentInfos(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ documentInfo :DocumentInfo) -> Void) {
		// Setup
		let	documentTables = documentTables(for: documentType)
		let	indexContentsTable = self.indexTablesByName.value(for: name)!

		// Iterate rows
		try! indexContentsTable.select(
				innerJoin:
						SQLiteInnerJoin(indexContentsTable, tableColumn: IndexContentsTable.idTableColumn,
								to: documentTables.infoTable),
				where: SQLiteWhere(tableColumn: IndexContentsTable.keyTableColumn, values: keys))
				{ proc(IndexContentsTable.key(for: $0), DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexUpdate(name :String, keysInfos :[(keys :[String], id :Int64)]?, removedIDs :[Int64]?,
			lastRevision :Int?) {
		// Check if in batch
		if let batchInfo = self.batchInfoByThread.value(for: .current) {
			// Update batch info
			batchInfo.noteIndexUpdate(name: name, keysInfos: keysInfos, removedIDs: removedIDs,
					lastRevision: lastRevision)
		} else {
			// Update
			indexUpdateInternal(name: name, keysInfos: keysInfos, removedIDs: removedIDs, lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoString(for key :String) -> String? { InfoTable.string(for: key, in: self.infoTable) }

	//------------------------------------------------------------------------------------------------------------------
	func infoSet(_ value :Any?, for key :String) { InfoTable.set(value: value, for: key, in: self.infoTable) }

	//------------------------------------------------------------------------------------------------------------------
	func internalString(for key :String) -> String? { InternalTable.string(for: key, in: self.internalTable) }

	//------------------------------------------------------------------------------------------------------------------
	func internalSet(_ value :Any?, for key :String) {
		// Set value
		InternalTable.set(value: value, for: key, in: self.internalTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func batch(_ proc :() -> Void) {
		// Setup
		let	batchInfo = BatchInfo()
		self.batchInfoByThread.set(batchInfo, for: .current)

		// Call proc
		proc()

		// Commit changes
		self.batchInfoByThread.set(nil, for: .current)

		batchInfo.iterateDocumentLastRevisionTypesNeedingWrite() {
			// Update
			DocumentsTable.set(lastRevision: self.documentLastRevisionByDocumentType.value(for: $0)!, for: $0,
					in: self.documentsTable)
		}
		batchInfo.iterateCacheUpdateInfos() {
			// Update Cache
			self.cacheUpdateInternal(name: $0, valueInfoByID: $1.valueInfoByID, removedIDs: $1.removedIDs,
					lastRevision: $1.lastRevision)
		}
		batchInfo.iterateCollectionUpdateInfos() {
			// Update Collection
			self.collectionUpdateInternal(name: $0, includedIDs: $1.includedIDs, notIncludedIDs: $1.notIncludedIDs,
					lastRevision: $1.lastRevision)
		}
		batchInfo.iterateIndexUpdateInfos() {
			// Update Index
			self.indexUpdateInternal(name: $0, keysInfos: $1.keysInfos, removedIDs: $1.removedIDs,
					lastRevision: $1.lastRevision)
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func cacheUpdateInternal(name :String, valueInfoByID :[Int64 : [/* Name */ String : Any]]?,
			removedIDs :[Int64], lastRevision :Int?) {
		// Update tables
		CacheContentsTable.update(valueInfoByID: valueInfoByID, removedIDs: removedIDs,
				in: self.cacheTablesByName.value(for: name)!)
		if lastRevision != nil {
			// Update Caches table
			CachesTable.update(name: name, lastRevision: lastRevision!, in: self.cachesTable)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionUpdateInternal(name :String, includedIDs :[Int64]?, notIncludedIDs :[Int64]?, lastRevision :Int?) {
		// Update tables
		CollectionContentsTable.update(includedIDs: includedIDs, notIncludedIDs: notIncludedIDs,
				in: self.collectionTablesByName.value(for: name)!)
		if lastRevision != nil {
			// Update Collections table
			CollectionsTable.update(name: name, lastRevision: lastRevision!, in: self.collectionsTable)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentTables(for documentType :String) -> DocumentTables {
		// Ensure we actually have a document type
		guard !documentType.isEmpty else { fatalError("documentType is empty") }

		// Check for already having tables
		if let documentTables = self.documentTablesByDocumentType.value(for: documentType) {
			// Have tables
			return documentTables
		} else {
			// Setup tables
			let	nameRoot = documentType.prefix(1).uppercased() + documentType.dropFirst()
			let	infoTable =
						DocumentTypeInfoTable.table(in: self.database, nameRoot: nameRoot,
								internalsTable: self.internalsTable)
			let	contentsTable =
						DocumentTypeContentsTable.table(in: self.database, nameRoot: nameRoot,
								infoTable: infoTable, internalsTable: self.internalsTable)
			let	attachmentsTable =
						DocumentTypeAttachmentsTable.table(in: self.database, nameRoot: nameRoot,
								internalsTable: self.internalsTable)
			let	documentTables = (infoTable, contentsTable, attachmentsTable)

			// Cache
			self.documentTablesByDocumentType.set(documentTables, for: documentType)

			return documentTables
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentNextRevision(for documentType :String) -> Int {
		// Compose next revision
		let	nextRevision = (self.documentLastRevisionByDocumentType.value(for: documentType) ?? 0) + 1

		// Check if in batch
		if let batchInfo = self.batchInfoByThread.value(for: .current) {
			// Update batch info
			batchInfo.noteDocumentTypeNeedingLastRevisionWrite(documentType: documentType)
		} else {
			// Update
			DocumentsTable.set(lastRevision: nextRevision, for: documentType, in: self.documentsTable)
		}

		// Store
		self.documentLastRevisionByDocumentType.set(nextRevision, for: documentType)

		return nextRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexUpdateInternal(name :String, keysInfos :[(keys :[String], id :Int64)]?, removedIDs :[Int64]?,
			lastRevision :Int?) {
		// Update tables
		IndexContentsTable.update(keysInfos: keysInfos, removedIDs: removedIDs,
				in: self.indexTablesByName.value(for: name)!)
		if lastRevision != nil {
			// Update Indexes table
			IndexesTable.update(name: name, lastRevision: lastRevision!, in: self.indexesTable)
		}
	}
}
