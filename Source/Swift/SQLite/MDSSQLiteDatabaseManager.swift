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

	// MARK: DocumentContentInfo
	struct DocumentContentInfo {

		// MARK: Properties
		let	id :Int64
		let	creationDate :Date
		let	modificationDate :Date
		let	propertyMap :[String : Any]
	}

	// MARK: Types
	private	typealias DocumentTables =
					(infoTable :SQLiteTable, contentsTable :SQLiteTable, attachmentsTable :SQLiteTable)

	private	typealias CollectionUpdateInfo = (includedIDs :[Int64], notIncludedIDs :[Int64], lastRevision :Int)
	private	typealias IndexUpdateInfo =
						(keysInfos :[(keys :[String], id :Int64)], removedIDs :[Int64], lastRevision :Int)

	// MARK: BatchInfo
	private struct BatchInfo {

		// MARK: Properties
		var	documentLastRevisionTypesNeedingWrite = Set<String>()
		var	collectionInfo = [/* Collection name */ String : CollectionUpdateInfo]()
		var	indexInfo = [/* Index name */ String : IndexUpdateInfo]()
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

	// MARK: AssocationContentsTable
	private struct AssocationContentsTable {

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
		static func get(from table :SQLiteTable) -> [(fromID :Int64, toID :Int64)] {
			// Iterate all rows
			var	items = [(fromID :Int64, toID :Int64)]()
			try! table.select() {
				// Process values
				let	fromID = $0.integer(for: self.fromIDTableColumn)!
				let	toID = $0.integer(for: self.toIDTableColumn)!

				// Add item
				items.append((fromID, toID))
			}

			return items
		}

		//--------------------------------------------------------------------------------------------------------------
		static func add(items :[(fromID :Int64, toID :Int64)], in table :SQLiteTable) {
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
		static func remove(items :[(fromID :Int64, toID :Int64)], in table :SQLiteTable) {
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
		static func info(forName name :String, in table :SQLiteTable) ->
				(relevantProperties :[String], isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
						lastRevision :Int)? {
			// Query
			var	currentInfo
						:(relevantProperties :[String], isIncludedSelector :String,
								isIncludedSelectorInfo :[String : Any], lastRevision :Int)?
			try! table.select(tableColumns: [self.versionTableColumn, self.lastRevisionTableColumn],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name)) {
						// Get info
						let	relevantProperties =
								$0.text(for: self.relevantPropertiesTableColumn)!.components(separatedBy: ",")
						let	isIncludedSelector = $0.text(for: self.isIncludedSelectorTableColumn)!
						let	isIncludedSelectorInfo =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: self.isIncludedSelectorInfoTableColumn)!) as!
											[String : Any]
						let	lastRevision = Int($0.integer(for: self.lastRevisionTableColumn)!)

						// Set current info
						currentInfo = (relevantProperties, isIncludedSelector, isIncludedSelectorInfo, lastRevision)
					}

			return currentInfo
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
			// Create table
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
		static func update(includedIDs :[Int64], notIncludedIDs :[Int64], in table :SQLiteTable) {
			// Update
			if !notIncludedIDs.isEmpty { table.deleteRows(self.idTableColumn, values: notIncludedIDs) }
			if !includedIDs.isEmpty { table.insertOrReplaceRows(self.idTableColumn, values: includedIDs) }
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
		static func ids(for documentIDs :[String], in table :SQLiteTable) -> [String : Int64] {
			// Retrieve id
			var	idsByDocumentID = [String : Int64]()
			try! table.select(tableColumns: [self.idTableColumn, self.documentIDTableColumn],
					where: SQLiteWhere(tableColumn: self.documentIDTableColumn, values: documentIDs))
					{
						// Process values
						let	id = $0.integer(for: self.idTableColumn)!
						let	documentID = $0.text(for: self.documentIDTableColumn)!

						// Update Map
						idsByDocumentID[documentID] = id
					}

			return idsByDocumentID
		}

		//--------------------------------------------------------------------------------------------------------------
		static func documentIDs(for ids :[Int64], in table :SQLiteTable) -> [Int64 : String] {
			// Retrieve id
			var	documentIDsByID = [Int64 : String]()
			try! table.select(tableColumns: [self.idTableColumn, self.documentIDTableColumn],
					where: SQLiteWhere(tableColumn: self.idTableColumn, values: ids))
					{
						// Process values
						let	id = $0.integer(for: self.idTableColumn)!
						let	documentID = $0.text(for: self.documentIDTableColumn)!

						// Update Map
						documentIDsByID[id] = documentID
					}

			return documentIDsByID
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
		static func update(id :Int64, modificationDate :Date, in table :SQLiteTable) {
			// Update
			 table.update(
					[
						(self.modificationDateTableColumn, modificationDate.rfc3339Extended),
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
		static func documentAttachmentInfoMap(id :Int64, in table :SQLiteTable) -> MDSDocument.AttachmentInfoMap {
			// Get info
			var	documentAttachmentInfoMap = MDSDocument.AttachmentInfoMap()
			try! table.select(
					tableColumns: [self.attachmentIDTableColumn, self.revisionTableColumn, self.infoTableColumn],
					 where: SQLiteWhere(tableColumn: self.idTableColumn, value: id))  {
						// Process values
						let	id = $0.text(for: self.attachmentIDTableColumn)!
						let	revision = Int($0.integer(for: self.revisionTableColumn)!)
						let	info =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: self.infoTableColumn)!) as! [String : Any]

						documentAttachmentInfoMap[id] =
								MDSDocument.AttachmentInfo(id: id, revision: revision, info: info)
					 }

			return documentAttachmentInfoMap
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

			table.update([
								(self.revisionTableColumn, revision + 1),
								(self.infoTableColumn, try! JSONSerialization.data(withJSONObject: updatedInfo)),
								(self.contentTableColumn, updatedContent),
							],
					where: SQLiteWhere(tableColumn: self.attachmentIDTableColumn, value: attachmentID))

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
		static func info(forName name :String, in table :SQLiteTable) ->
				(relevantProperties :[String], keysSelector :String, keysSelectorInfo :[String : Any],
						lastRevision :Int)? {
			// Query
			var	currentInfo
						:(relevantProperties :[String], keysSelector :String, keysSelectorInfo :[String : Any],
								lastRevision :Int)?
			try! table.select(tableColumns: [self.versionTableColumn, self.lastRevisionTableColumn],
					where: SQLiteWhere(tableColumn: self.nameTableColumn, value: name)) {
						// Get info
						let	relevantProperties =
								$0.text(for: self.relevantPropertiesTableColumn)!.components(separatedBy: ",")
						let	keysSelector = $0.text(for: self.keysSelectorTableColumn)!
						let	keysSelectorInfo =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: self.keysSelectorInfoTableColumn)!) as! [String : Any]
						let	lastRevision = Int($0.integer(for: self.lastRevisionTableColumn)!)

						// Set current info
						currentInfo = (relevantProperties, keysSelector, keysSelectorInfo, lastRevision)
					}

			return currentInfo
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
		static func update(keysInfos :[(keys :[String], id :Int64)], removedIDs :[Int64], in table :SQLiteTable) {
			// Setup
			let	idsToRemove = removedIDs + keysInfos.map({ $0.id })

			// Update tables
			if !idsToRemove.isEmpty { table.deleteRows(self.idTableColumn, values: idsToRemove) }
			keysInfos.forEach() { keysInfo in keysInfo.keys.forEach() {
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

	private	let	batchInfoMap = LockingDictionary<Thread, BatchInfo>()

	private	let	associationsTable :SQLiteTable
	private	let	associationTablesByName = LockingDictionary</* Association name */ String, SQLiteTable>()

	private	let	cachesTable :SQLiteTable
	private	let	cacheTablesByName = LockingDictionary</* Cache name */ String, SQLiteTable>()

	private	let	collectionsTable :SQLiteTable
	private	let	collectionTablesByName = LockingDictionary</* Collection name */ String, SQLiteTable>()

	private	let	documentsTable :SQLiteTable
	private	let	documentTablesByDocumentType = LockingDictionary</* Document type */ String, DocumentTables>()
	private	let	documentLastRevisionMap = LockingDictionary</* Document type */ String, Int>()

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

		// Create tables
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

		// Load all existing document info
		try! self.documentsTable.select() {
			// Process results
			let	(documentType, lastRevision) = DocumentsTable.info(for: $0)

			// Update
			self.documentLastRevisionMap.set(lastRevision, for: documentType)
		}
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func associationRegister(name :String, fromDocumentType :String, toDocumentType :String) {
		// Register
		AssociationsTable.addOrUpdate(name: name, fromDocumentType: fromDocumentType, toDocumentType: toDocumentType,
				in: self.associationsTable)

		// Create contents table
		let	associationContentsTable =
					AssocationContentsTable.table(in: self.database, name: name, internalsTable: self.internalsTable)
		self.associationTablesByName.set(associationContentsTable, for: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationUpdate(name :String, updates :[MDSAssociation.Update], fromDocumentType :String,
			toDocumentType :String) {
		// Setup
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		let	fromIDsByDocumentID =
					DocumentTypeInfoTable.ids(for: Array(Set<String>(updates.map({ $0.item.fromDocumentID }))),
							in: fromDocumentTables.infoTable)

		let	toDocumentTables = documentTables(for: toDocumentType)
		let	toIDsByDocumentID =
					DocumentTypeInfoTable.ids(for: Array(Set<String>(updates.map({ $0.item.toDocumentID }))),
							in: toDocumentTables.infoTable)

		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Update Association
		AssocationContentsTable.remove(
				items:
						updates
								.filter({ $0.action == .remove })
								.map({ (fromIDsByDocumentID[$0.item.fromDocumentID]!,
										toIDsByDocumentID[$0.item.toDocumentID]!) }),
				in: associationContentsTable)
		AssocationContentsTable.add(
				items:
						updates
								.filter({ $0.action == .add })
								.map({ (fromIDsByDocumentID[$0.item.fromDocumentID]!,
										toIDsByDocumentID[$0.item.toDocumentID]!) }),
				in: associationContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGet(name :String, fromDocumentType :String, toDocumentType :String, startIndex :Int, count :Int?) ->
			(totalCount :Int, associationItems :[MDSAssociation.Item]) {
		// Setup
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		let	toDocumentTables = documentTables(for: toDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Get all
		let	items = AssocationContentsTable.get(from: associationContentsTable)
		let	fromDocumentIDsByID =
					DocumentTypeInfoTable.documentIDs(for: Array(Set<Int64>(items.map({ $0.fromID }))),
							in: fromDocumentTables.infoTable)
		let	toDocumentIDsByID =
					DocumentTypeInfoTable.documentIDs(for: Array(Set<Int64>(items.map({ $0.toID }))),
							in: toDocumentTables.infoTable)

		return (items.count,
				items.map({ MDSAssociation.Item(fromDocumentID: fromDocumentIDsByID[$0.fromID]!,
						toDocumentID: toDocumentIDsByID[$0.toID]!) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetCount(name :String, fromDocumentID :String, fromDocumentType :String) -> Int? {
		// Setup
		let	documentTables = self.documentTables(for: fromDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!

		// Get document id
		guard let id = DocumentTypeInfoTable.id(for: fromDocumentID, in: documentTables.infoTable) else { return nil }

		return AssocationContentsTable.count(fromID: id, in: associationContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetCount(name :String, toDocumentID :String, toDocumentType :String) -> Int? {
		// Setup
		let	documentTables = self.documentTables(for: toDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!
		guard let id = DocumentTypeInfoTable.id(for: toDocumentID, in: documentTables.infoTable) else { return nil }

		return AssocationContentsTable.count(toID: id, in: associationContentsTable)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterateDocumentInfos(name :String, fromDocumentID :String, fromDocumentType :String,
			toDocumentType :String, startIndex :Int, count :Int?, proc :(_ documentInfo :DocumentInfo) -> Void) {
		// Setup
		let	associationContentsTable = self.associationTablesByName.value(for: name)!
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		let	fromID = DocumentTypeInfoTable.id(for: fromDocumentID, in: fromDocumentTables.infoTable)!
		let	toDocumentTables = documentTables(for: toDocumentType)

		// Iterate rows
		try! associationContentsTable.select(tableColumns: DocumentTypeInfoTable.tableColumns,
				innerJoin:
						SQLiteInnerJoin(associationContentsTable,
								tableColumn: AssocationContentsTable.toIDTableColumn, to: toDocumentTables.infoTable,
								otherTableColumn: DocumentTypeInfoTable.idTableColumn),
				where: SQLiteWhere(tableColumn: AssocationContentsTable.fromIDTableColumn, value: fromID),
				orderBy: SQLiteOrderBy(tableColumn: AssocationContentsTable.toIDTableColumn),
				limit: SQLiteLimit(limit: count ?? -1, offset: startIndex))
				{ proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterateDocumentInfos(name :String, toDocumentID :String, toDocumentType :String,
			fromDocumentType :String, startIndex :Int, count :Int?, proc :(_ documentInfo :DocumentInfo) -> Void) {
		// Setup
		let	fromDocumentTables = documentTables(for: fromDocumentType)
		let	toDocumentTables = documentTables(for: toDocumentType)
		let	associationContentsTable = self.associationTablesByName.value(for: name)!
		let	toID = DocumentTypeInfoTable.id(for: toDocumentID, in: toDocumentTables.infoTable)!

		// Iterate rows
		try! associationContentsTable.select(tableColumns: DocumentTypeInfoTable.tableColumns,
				innerJoin:
						SQLiteInnerJoin(associationContentsTable,
								tableColumn: AssocationContentsTable.fromIDTableColumn,
								to: fromDocumentTables.infoTable,
								otherTableColumn: DocumentTypeInfoTable.idTableColumn),
				where: SQLiteWhere(tableColumn: AssocationContentsTable.toIDTableColumn, value: toID),
				orderBy: SQLiteOrderBy(tableColumn: AssocationContentsTable.fromIDTableColumn),
				limit: SQLiteLimit(limit: count ?? -1, offset: startIndex))
				{ proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
		// Get current info
		let (storedVersion, storedLastRevision) = CollectionsTable.info(forName: name, in: self.collectionsTable)
	//------------------------------------------------------------------------------------------------------------------
	func collectionRegister(name :String, documentType :String, relevantProperties :[String],
				isIncludedSelector :String, isIncludedSelectorInfo :[String : Any], isUpToDate :Bool) -> Int {
		// Get current info
		let currentInfo = CollectionsTable.info(forName: name, in: self.collectionsTable)

		// Setup table
		let	collectionContentsTable =
					CollectionContentsTable.table(in: self.database, name: name, internalsTable: self.internalsTable)
		self.collectionTablesByName.set(collectionContentsTable, for: name)

		// Compose next steps
		let	lastRevision :Int
		let	updateMasterTable :Bool
		if currentInfo == nil {
			// New
			lastRevision = isUpToDate ? self.documentLastRevisionMap.value(for: documentType) ?? 0 : 0
			updateMasterTable = true
		} else if (relevantProperties != currentInfo!.relevantProperties) ||
				(isIncludedSelector != currentInfo!.isIncludedSelector) ||
				!isIncludedSelectorInfo.equals(currentInfo!.isIncludedSelectorInfo) {
			// Info has changed
			lastRevision = 0
			updateMasterTable = true
		} else {
			// No change
			lastRevision = currentInfo!.lastRevision
			updateMasterTable = false
		}

		// Check if need to update the master table
		if updateMasterTable {
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
	func collectionGetDocumentCount(for name :String) -> Int { self.collectionTablesByName.value(for: name)!.count() }

	//------------------------------------------------------------------------------------------------------------------
	func collectionIterateDocumentInfos(for name :String, documentType :String, startIndex :Int, count :Int?,
			proc :(_ documentInfo :DocumentInfo) -> Void) {
		// Setup
		let	documentTables = documentTables(for: documentType)
		let	collectionContentsTable = self.collectionTablesByName.value(for: name)!

		// Iterate rows
		try! collectionContentsTable.select(tableColumns: DocumentTypeInfoTable.tableColumns,
				innerJoin:
						SQLiteInnerJoin(collectionContentsTable, tableColumn: CollectionContentsTable.idTableColumn,
								to: documentTables.infoTable),
				orderBy: SQLiteOrderBy(tableColumn: CollectionContentsTable.idTableColumn),
				limit: SQLiteLimit(limit: count ?? -1, offset: startIndex))
				{ proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionUpdate(name :String, includedIDs :[Int64], notIncludedIDs :[Int64], lastRevision :Int) {
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
			CollectionsTable.update(name: name, lastRevision: lastRevision, in: self.collectionsTable)
			CollectionContentsTable.update(includedIDs: includedIDs, notIncludedIDs: notIncludedIDs,
					in: self.collectionTablesByName.value(for: name)!)
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
	func documentIsKnown(documentType :String) -> Bool { self.documentLastRevisionMap.value(for: documentType) != nil }
	
	//------------------------------------------------------------------------------------------------------------------
	func documentCount(for documentType :String) -> Int { self.documentTables(for: documentType).infoTable.count() }

	//------------------------------------------------------------------------------------------------------------------
//	func documentInfoIterate(documentType :String, innerJoin :SQLiteInnerJoin? = nil,
//			where sqliteWhere :SQLiteWhere? = nil,
//			proc :(_ cocumentInfo :DocumentInfo, _ resultsRow :SQLiteResultsRow) -> Void) {
//		// Setup
//		let	documentTables = self.documentTables(for: documentType)
//
//		// Retrieve and iterate
//		try! documentTables.infoTable.select(innerJoin: innerJoin, where: sqliteWhere)
//				{ proc(DocumentTypeInfoTable.documentInfo(for: $0), $0) }
//	}

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
	func documentInfoIterate(documentType :String, sinceRevision :Int, activeOnly: Bool,
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
				orderBy: SQLiteOrderBy(tableColumn: DocumentTypeInfoTable.revisionTableColumn))
				{ proc(DocumentTypeInfoTable.documentInfo(for: $0)) }
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
	func documentAttachmentInfoMap(documentType :String, id :Int64) -> MDSDocument.AttachmentInfoMap {
		// Setup
		let	documentTables = documentTables(for: documentType)

		return DocumentTypeAttachmentsTable.documentAttachmentInfoMap(id: id, in: documentTables.attachmentsTable)
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
		let currentInfo = IndexesTable.info(forName: name, in: self.collectionsTable)

		// Setup table
		let	indexContentsTable =
					IndexContentsTable.table(in: self.database, name: name, internalsTable: self.internalsTable)
		self.indexTablesByName.set(indexContentsTable, for: name)

		// Compose next steps
		let	lastRevision :Int
		let	updateMasterTable :Bool
		if currentInfo == nil {
			// New
			lastRevision = 0
			updateMasterTable = true
		} else if (relevantProperties != currentInfo!.relevantProperties) ||
				(keysSelector != currentInfo!.keysSelector) || !keysSelectorInfo.equals(currentInfo!.keysSelectorInfo) {
			// Updated version
			lastRevision = 0
			updateMasterTable = true
		} else {
			// No change
			lastRevision = currentInfo!.lastRevision
			updateMasterTable = false
		}

		// Check if need to update the master table
		if updateMasterTable {
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
	func indexIterateDocumentInfos(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ documentInfo :DocumentInfo) -> Void) {
		// Setup
		let	documentTables = documentTables(for: documentType)
		let	indexContentsTable = self.indexTablesByName.value(for: name)!

		// Iterate rows
		try! indexContentsTable.select(
				tableColumns: [IndexContentsTable.keyTableColumn] + DocumentTypeInfoTable.tableColumns,
				innerJoin:
						SQLiteInnerJoin(indexContentsTable, tableColumn: IndexContentsTable.idTableColumn,
								to: documentTables.infoTable),
				where: SQLiteWhere(tableColumn: IndexContentsTable.keyTableColumn, values: keys))
				{ proc(IndexContentsTable.key(for: $0), DocumentTypeInfoTable.documentInfo(for: $0)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexUpdate(name :String, keysInfos :[(keys :[String], id :Int64)], removedIDs :[Int64], lastRevision :Int) {
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
			IndexesTable.update(name: name, lastRevision: lastRevision, in: self.indexesTable)
			IndexContentsTable.update(keysInfos: keysInfos, removedIDs: removedIDs,
					in: self.indexTablesByName.value(for: name)!)
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
//	func note(documentType :String) { _ = documentTables(for: documentType) }

	//------------------------------------------------------------------------------------------------------------------
	func batch<T>(_ proc :() -> T) -> T {
		// Setup
		self.batchInfoMap.set(BatchInfo(), for: Thread.current)

		// Call proc
		let	t = proc()

		// Commit changes
		let	batchInfo = self.batchInfoMap.value(for: Thread.current)!
		self.batchInfoMap.set(nil, for: Thread.current)

		batchInfo.documentLastRevisionTypesNeedingWrite.forEach() {
			// Update
			DocumentsTable.set(lastRevision: self.documentLastRevisionMap.value(for: $0)!, for: $0,
					in: self.documentsTable)
		}
		batchInfo.cacheInfo.forEach() {
			// Update Cache
			self.cacheUpdate(name: $0.key, infosByValue: $0.value.infosByValue, lastRevision: $0.value.lastRevision)
		}
		batchInfo.collectionInfo.forEach() {
			// Update Collection
			self.collectionUpdate(name: $0.key, includedIDs: $0.value.includedIDs,
					notIncludedIDs: $0.value.notIncludedIDs, lastRevision: $0.value.lastRevision)
		}
		batchInfo.indexInfo.forEach() {
			// Update Index
			self.indexUpdate(name: $0.key, keysInfos: $0.value.keysInfos, removedIDs: $0.value.removedIDs,
					lastRevision: $0.value.lastRevision)
		}

		return t
	}

	//------------------------------------------------------------------------------------------------------------------
//	func innerJoin(for documentType :String) -> SQLiteInnerJoin {
//		// Setup
//		let	documentTables = self.documentTables(for: documentType)
//
//		return SQLiteInnerJoin(documentTables.infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn,
//				to: documentTables.contentsTable)
//	}

	//------------------------------------------------------------------------------------------------------------------
//	func innerJoin(for documentType :String, collectionName :String) -> SQLiteInnerJoin {
//		// Setup
//		let	documentTables = self.documentTables(for: documentType)
//		let	collectionContentsTable = self.collectionTablesByName.value(for: collectionName)!
//
//		return SQLiteInnerJoin(documentTables.infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn,
//						to: documentTables.contentsTable)
//				.and(infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn, to: collectionContentsTable)
//	}

	//------------------------------------------------------------------------------------------------------------------
//	func innerJoin(for documentType :String, indexName :String) -> SQLiteInnerJoin {
//		// Setup
//		let	documentTables = self.documentTables(for: documentType)
//		let	indexContentsTable = self.indexTablesByName.value(for: indexName)!
//
//		return SQLiteInnerJoin(documentTables.infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn,
//						to: documentTables.contentsTable)
//				.and(infoTable, tableColumn: DocumentTypeInfoTable.idTableColumn, to: indexContentsTable)
//	}

	//------------------------------------------------------------------------------------------------------------------
//	func `where`(forDocumentActive active :Bool = true) -> SQLiteWhere {
//		// Return SQLiteWhere
//		return SQLiteWhere(tableColumn: DocumentTypeInfoTable.activeTableColumn, value: active ? 1 : 0)
//	}

	//------------------------------------------------------------------------------------------------------------------
//	func `where`(forDocumentIDs documentIDs :[String]) -> SQLiteWhere {
//		// Return SQLiteWhere
//		return SQLiteWhere(tableColumn: DocumentTypeInfoTable.documentIDTableColumn, values: documentIDs)
//	}

	//------------------------------------------------------------------------------------------------------------------
//	func `where`(forDocumentRevision revision :Int, comparison :String = ">", activeOnly :Bool) -> SQLiteWhere {
//		// Return SQLiteWhere
//		return activeOnly ?
//			SQLiteWhere(tableColumn: DocumentTypeInfoTable.revisionTableColumn, comparison: comparison, value: revision)
//					.and(tableColumn: DocumentTypeInfoTable.activeTableColumn, value: 1) :
//			SQLiteWhere(tableColumn: DocumentTypeInfoTable.revisionTableColumn, comparison: comparison,
//							value: revision)
//	}

	//------------------------------------------------------------------------------------------------------------------
//	func `where`(forIndexKeys keys :[String]) -> SQLiteWhere {
//		// Return SQLiteWhere
//		return SQLiteWhere(tableColumn: IndexContentsTable.keyTableColumn, values: keys)
//	}

	// MARK: Private methods
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
		let	nextRevision = (self.documentLastRevisionMap.value(for: documentType) ?? 0) + 1

		// Check if in batch
		if var batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// Update batch info
			batchInfo.documentLastRevisionTypesNeedingWrite.insert(documentType)
			self.batchInfoMap.set(batchInfo, for: Thread.current)
		} else {
			// Update
			DocumentsTable.set(lastRevision: nextRevision, for: documentType, in: self.documentsTable)
		}

		// Store
		self.documentLastRevisionMap.set(nextRevision, for: documentType)

		return nextRevision
	}
}
