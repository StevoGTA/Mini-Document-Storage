//
//  MDSRemoteStorageCache.swift
//  Mini Document Storage
//
//  Created by Stevo on 1/14/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocument.AttachmentInfoMap extension
extension MDSDocument.AttachmentInfoMap {

	// MARK: Properties
	var	data :Data
				{ try! JSONSerialization.data(
						withJSONObject: self.mapValues({ ["revision": $0.revision, "info": $0.info] }), options: []) }

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(_ data :Data) {
		// Setup
		self =
				(try! JSONSerialization.jsonObject(with: data, options: []) as! [String : [String : Any]])
						.mapPairs({ ($0.key,
								MDSDocument.AttachmentInfo(id: $0.key, revision: $0.value["revision"] as! Int,
										info: $0.value["info"] as! [String : Any])) })
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSRemoteStorageCache
public class MDSRemoteStorageCache {

	// MARK: Properties
	private	var	attachmentsTable :SQLiteTable!
	private	var	documentSQLiteTables = LockingDictionary</* document type */ String, SQLiteTable>()
	private	var	infoTable :SQLiteTable!
	private	var	sqliteDatabase :SQLiteDatabase!

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(storageFolder :Folder, databaseName :String = "MDSRemoteStorageCache") throws {
		// Create folder if needed
		try FileManager.default.create(storageFolder)

		// Setup SQLite database
		self.sqliteDatabase = try SQLiteDatabase(in: storageFolder, with: databaseName)

		self.attachmentsTable =
				self.sqliteDatabase.table(name: "Attachments", options: [.withoutRowID],
						tableColumns: [
										SQLiteTableColumn("id", .text, [.primaryKey, .unique, .notNull]),
										SQLiteTableColumn("content", .blob, [.notNull]),
									  ])
		self.attachmentsTable.create()

		self.infoTable =
				self.sqliteDatabase.table(name: "Info", options: [.withoutRowID],
						tableColumns: [
										SQLiteTableColumn("key", .text, [.primaryKey, .unique, .notNull]),
										SQLiteTableColumn("value", .text, [.notNull]),
									  ])
		self.infoTable.create()

		var	version :Int?
		try! self.infoTable.select(tableColumns: [self.infoTable.valueTableColumn],
				where: SQLiteWhere(tableColumn: self.infoTable.keyTableColumn, value: "version")) {
			// Process values
			version = Int($0.text(for: self.infoTable.valueTableColumn)!)!
		}
		if version == nil {
			// Initialize version
			_ = self.infoTable.insertRow([
											(self.infoTable.keyTableColumn, "version"),
											(self.infoTable.valueTableColumn, 2),
										 ])
		} else if version == 1 {
			// Update all document tables
			let	documentTables = self.sqliteDatabase.tables.filter({ $0.name.hasSuffix("s") })
			let	attachmentInfoTableColumn = SQLiteTableColumn("attachmentInfo", .blob)
			for var table in documentTables { table.add(attachmentInfoTableColumn) }

			// Now at version 2
			set(2, for: "version")
		}
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func data(for key :String) -> Data? {
		// Retrieve value
		if let string = string(for: key) {
			// Have string
			return Data(base64Encoded: string)
		} else {
			// Don't have string
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func int(for key :String) -> Int? {
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
	public func string(for key :String) -> String? {
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
	public func timeIntervals(for keys :[String]) -> [String : TimeInterval] {
		// Setup
		let	keyTableColumn = self.infoTable.keyTableColumn
		let	valueTableColumn = self.infoTable.valueTableColumn

		// Retrieve values
		var	map = [String : TimeInterval]()
		try! self.infoTable.select(where: SQLiteWhere(tableColumn: self.infoTable.keyTableColumn, values: keys)) {
					// Process results
					let	key = $0.text(for: keyTableColumn)!
					let	value = $0.text(for: valueTableColumn)!

					// Add to map
					map[key] = TimeInterval(value)
				}

		return map
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ value :Any?, for key :String) {
		// Storing or removing
		if value != nil {
			// Have value
			let	valueUse :String
			if let data = value as? Data {
				// Data
				valueUse = data.base64EncodedString()
			} else if let string = value as? String {
				// String
				valueUse = string
			} else {
				// Other
				valueUse = "\(value!)"
			}

			// Store value
			self.infoTable.insertOrReplaceRow([
												(self.infoTable.keyTableColumn, key),
												(self.infoTable.valueTableColumn, valueUse),
											  ])
		} else {
			// Removing
			self.infoTable.deleteRows(self.infoTable.keyTableColumn, values: [key])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ info :[String : Any]) {
		// Setup
		let	keyTableColumn = self.infoTable.keyTableColumn
		let	valueTableColumn = self.infoTable.valueTableColumn

		// Iterate all
		info.forEach() {
			// Store value
			self.infoTable.insertOrReplaceRow([
												(keyTableColumn, $0.key),
												(valueTableColumn, $0.value),
											  ])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentFullInfos(for documentType :String, activeOnly :Bool = true) -> [MDSDocument.FullInfo] {
		// Setup
		let	sqliteTable = self.sqliteTable(for: documentType)
		let	idTableColumn = sqliteTable.idTableColumn
		let	revisionTableColumn = sqliteTable.revisionTableColumn
		let	activeTableColumn = sqliteTable.activeTableColumn
		let	creationDateTableColumn = sqliteTable.creationDateTableColumn
		let	modificationDateTableColumn = sqliteTable.modificationDateTableColumn
		let	jsonTableColumn = sqliteTable.jsonTableColumn
		let	attachmentInfoTableColumn = sqliteTable.attachmentInfoTableColumn

		// Iterate records in database
		var	documentFullInfos = [MDSDocument.FullInfo]()
		try! sqliteTable.select() {
			// Process results
			let	active = Int($0.integer(for: activeTableColumn)!)
			guard !activeOnly || (active == 1) else { return }

			let	id = $0.text(for: idTableColumn)!
			let	revision = Int($0.integer(for: revisionTableColumn)!)
			let	creationDate = Date(timeIntervalSince1970: $0.real(for: creationDateTableColumn)!)
			let	modificationDate = Date(timeIntervalSince1970: $0.real(for: modificationDateTableColumn)!)
			let	propertyMap =
						try! JSONSerialization.jsonObject(with: $0.blob(for: jsonTableColumn)!, options: [])
								as! [String : Any]

			let	attachmentInfoMap :MDSDocument.AttachmentInfoMap
			if let data = $0.blob(for: attachmentInfoTableColumn) {
				// Have info
				attachmentInfoMap = MDSDocument.AttachmentInfoMap(data)
			} else {
				// Don't have info
				attachmentInfoMap = [:]
			}

			// Add to array
			documentFullInfos.append(
					MDSDocument.FullInfo(documentID: id, revision: revision, active: true, creationDate: creationDate,
							modificationDate: modificationDate, propertyMap: propertyMap,
							attachmentInfoMap: attachmentInfoMap))
		}

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	public func info(for documentType :String, with revisionInfos :[MDSDocument.RevisionInfo]) ->
			(documentFullInfos :[MDSDocument.FullInfo], documentRevisionInfosNotResolved :[MDSDocument.RevisionInfo]) {
		// Setup
		let	sqliteTable = self.sqliteTable(for: documentType)
		let	idTableColumn = sqliteTable.idTableColumn
		let	revisionTableColumn = sqliteTable.revisionTableColumn
		let	activeTableColumn = sqliteTable.activeTableColumn
		let	creationDateTableColumn = sqliteTable.creationDateTableColumn
		let	modificationDateTableColumn = sqliteTable.modificationDateTableColumn
		let	jsonTableColumn = sqliteTable.jsonTableColumn
		let	attachmentInfoTableColumn = sqliteTable.attachmentInfoTableColumn

		let	referenceMap = Dictionary(uniqueKeysWithValues: revisionInfos.lazy.map({ ($0.documentID, $0.revision) }))

		var	documentIDs = Set<String>(referenceMap.keys)

		// Iterate records in database
		var	documentFullInfos = [MDSDocument.FullInfo]()
		var	documentRevisionInfosNotResolved = [MDSDocument.RevisionInfo]()
		try! sqliteTable.select(where: SQLiteWhere(tableColumn: sqliteTable.idTableColumn,
				values: Array(documentIDs))) {
					// Retrieve info for this record
					let	id = $0.text(for: idTableColumn)!
					let	revision = Int($0.integer(for: revisionTableColumn)!)
					if revision == referenceMap[id] {
						// Revision matches
						let	active = Int($0.integer(for: activeTableColumn)!)
						let	creationDate = Date(timeIntervalSince1970: $0.real(for: creationDateTableColumn)!)
						let	modificationDate = Date(timeIntervalSince1970: $0.real(for: modificationDateTableColumn)!)
						let	propertyMap =
									try! JSONSerialization.jsonObject(with: $0.blob(for: jsonTableColumn)!, options: [])
											as! [String : Any]

						let	attachmentInfoMap :MDSDocument.AttachmentInfoMap
						if let data = $0.blob(for: attachmentInfoTableColumn) {
							// Have info
							attachmentInfoMap =
									(try! JSONSerialization.jsonObject(with: data, options: [])
													as! [String : [String : Any]])
											.mapValues({
													MDSDocument.AttachmentInfo(id: ($0["id"] as? String) ?? "None",
															revision: $0["revision"] as! Int,
															info: $0["info"] as! [String : Any])
											})
						} else {
							// Don't have info
							attachmentInfoMap = [:]
						}

						// Add to array
						documentFullInfos.append(
								MDSDocument.FullInfo(documentID: id, revision: revision, active: active == 1,
										creationDate: creationDate, modificationDate: modificationDate,
										propertyMap: propertyMap, attachmentInfoMap: attachmentInfoMap))
					} else {
						// Revision does not match
						documentRevisionInfosNotResolved.append(
								MDSDocument.RevisionInfo(documentID: id, revision: referenceMap[id]!))
					}

					// Update
					documentIDs.remove(id)
				}

		// Add references not found in database
		documentIDs.forEach()
			{ documentRevisionInfosNotResolved.append(
					MDSDocument.RevisionInfo(documentID: $0, revision: referenceMap[$0]!)) }

		return (documentFullInfos, documentRevisionInfosNotResolved)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func add(_ documentFullInfos :[MDSDocument.FullInfo], for documentType :String) {
		// Setup
		let	sqliteTable = self.sqliteTable(for: documentType)
		self.sqliteDatabase.performAsTransaction() {
			// Iterate all document infos
			documentFullInfos.forEach() {
				// Setup
				var	info :[(tableColumn :SQLiteTableColumn, value :Any)] =
							[
								(tableColumn: sqliteTable.idTableColumn, value: $0.documentID),
								(tableColumn: sqliteTable.revisionTableColumn, value: $0.revision),
								(tableColumn: sqliteTable.activeTableColumn, value: $0.active ? 1 : 0),
								(tableColumn: sqliteTable.creationDateTableColumn,
										value: $0.creationDate.timeIntervalSince1970),
								(tableColumn: sqliteTable.modificationDateTableColumn,
										value: $0.modificationDate.timeIntervalSince1970),
								(tableColumn: sqliteTable.jsonTableColumn, value: $0.propertyMap.data),
							]
				if !$0.attachmentInfoMap.isEmpty {
					// Add attachment info
					info.append((tableColumn: sqliteTable.attachmentInfoTableColumn, value: $0.attachmentInfoMap.data))
				}

				// Insert or replace
				sqliteTable.insertOrReplaceRow(info)
			}

			return .commit
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func attachmentContent(for id :String) -> Data? {
		// Retrieve content
		var	content :Data?
		try! self.attachmentsTable.select(tableColumns: [self.attachmentsTable.contentTableColumn],
				where: SQLiteWhere(tableColumn: self.attachmentsTable.idTableColumn, value: id)) {
					// Process results
					content = $0.blob(for: self.attachmentsTable.contentTableColumn)
				}

		return content
	}

	//------------------------------------------------------------------------------------------------------------------
	func setAttachment(content :Data? = nil, for id :String) {
		// Storing or removing
		if content != nil {
			// Store
			self.attachmentsTable.insertOrReplaceRow([
														(self.attachmentsTable.idTableColumn, id),
														(self.attachmentsTable.contentTableColumn, content!),
													 ])
		} else {
			// Removing
			self.attachmentsTable.deleteRows(self.attachmentsTable.idTableColumn, values: [id])
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func sqliteTable(for documentType :String) -> SQLiteTable {
		// Retrieve or create if needed
		var	sqliteTable = self.documentSQLiteTables.value(for: documentType)
		if sqliteTable == nil {
			// Create
			let	name = documentType.prefix(1).uppercased() + documentType.dropFirst() + "s"

			sqliteTable =
					self.sqliteDatabase.table(name: name, options: [],
							tableColumns: [
											SQLiteTableColumn("id", .text, [.primaryKey, .notNull]),
											SQLiteTableColumn("revision", .integer, [.notNull]),
											SQLiteTableColumn("active", .integer, [.notNull]),
											SQLiteTableColumn("creationDate", .real, [.notNull]),
											SQLiteTableColumn("modificationDate", .real, [.notNull]),
											SQLiteTableColumn("json", .blob, [.notNull]),
											SQLiteTableColumn("attachmentInfo", .blob),
										  ])
			sqliteTable!.create()
			self.documentSQLiteTables.set(sqliteTable, for: documentType)
		}

		return sqliteTable!
	}
}
