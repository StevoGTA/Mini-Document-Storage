//
//  MDSSQLiteDocumentBacking.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/18/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSSQLiteDocumentBacking
class MDSSQLiteDocumentBacking {

	// MARK: Types
	struct Info {

		// MARK: Properties
		let	id :Int64
		let	documentID :String
		let	revision :Int
	}

	typealias DocumentInfo = (documentID :String, documentBacking :MDSSQLiteDocumentBacking)
	typealias PropertyMap = [/* Property */ String : /* Value */ Any]

	// MARK: Properties
			let	id :Int64
			let	creationDate :Date

			var	modificationDate :Date
			var	revision :Int

	private	var	propertyMap :PropertyMap
	private	var	propertyMapLock = ReadPreferringReadWriteLock()

	// MARK: Class methods
	//------------------------------------------------------------------------------------------------------------------
	static func infos(for documentType :String, with sqliteCore :MDSSQLiteCore) -> [MDSSQLiteDocumentBacking.Info] {
		// Setup
		let	(infoTable, _) = sqliteCore.documentTables(for: documentType)

		var	infos = [MDSSQLiteDocumentBacking.Info]()

		// Select all
		infoTable.select() {
			// Iterate all results
			while $0.next() {
				// Get info
				let	id :Int64 = $0.integer(for: infoTable.idTableColumn)!
				let	documentID = $0.text(for: infoTable.documentIDTableColumn)!
				let	revision :Int = $0.integer(for: infoTable.revisionTableColumn)!

				// Add to array
				infos.append(Info(id: id, documentID: documentID, revision: revision))
			}
		}

		return infos
	}

	//------------------------------------------------------------------------------------------------------------------
	static func documentInfos(for infos :[Info], of documentType :String, with sqliteCore :MDSSQLiteCore) ->
			[DocumentInfo] {
		// Setup
		let	(_, contentTable) = sqliteCore.documentTables(for: documentType)

		var	infoMap = [Int64 : Info]()
		infos.forEach() { infoMap[$0.id] = $0 }

		// Select
		var	documentInfos = [DocumentInfo]()
		contentTable.select(
				tableColumns: [
								contentTable.idTableColumn,
								contentTable.creationDateTableColumn,
								contentTable.modificationDateTableColumn,
								contentTable.jsonTableColumn,
							  ],
				where: SQLiteWhere(tableColumn: contentTable.idTableColumn, values: Array(infoMap.keys))) {
					// Iterate all results
					while $0.next() {
						// Get info
						let	id :Int64 = $0.integer(for: contentTable.idTableColumn)!
						let	creationDate = Date(fromStandardized: $0.text(for: contentTable.creationDateTableColumn)!)!
						let	modificationDate =
									Date(fromStandardized: $0.text(for: contentTable.modificationDateTableColumn)!)!
						let	propertyMap =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: contentTable.jsonTableColumn)!) as! [String : Any]
						let	info = infoMap[id]!

						// Add to array
						documentInfos.append(
								(info.documentID,
										MDSSQLiteDocumentBacking(info: info, creationDate: creationDate,
												modificationDate: modificationDate, propertyMap: propertyMap)))
					}
				}

		return documentInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	static func documentInfos(for documentIDs :[String], of documentType :String, with sqliteCore :MDSSQLiteCore) ->
			[DocumentInfo] {
		// Setup
		let	(infoTable, contentTable) = sqliteCore.documentTables(for: documentType)

		return documentInfos(infoTable: infoTable, contentTable: contentTable,
				where: SQLiteWhere(tableColumn: infoTable.documentIDTableColumn, values: documentIDs))
	}

	//------------------------------------------------------------------------------------------------------------------
	static func documentInfos(since revision :Int, of documentType :String, with sqliteCore :MDSSQLiteCore) ->
			[DocumentInfo] {
		// Setup
		let	(infoTable, contentTable) = sqliteCore.documentTables(for: documentType)

		return documentInfos(infoTable: infoTable, contentTable: contentTable,
				where: SQLiteWhere(tableColumn: infoTable.revisionTableColumn, comparison: ">", value: revision))
	}

	//------------------------------------------------------------------------------------------------------------------
	static func documentInfos(of documentType :String, with sqliteCore :MDSSQLiteCore,
			sqliteInnerJoin :SQLiteInnerJoin, where _where :SQLiteWhere? = nil) -> [DocumentInfo] {
		// Setup
		let	(infoTable, contentTable) = sqliteCore.documentTables(for: documentType)

		return documentInfos(infoTable: infoTable, contentTable: contentTable, sqliteInnerJoin: sqliteInnerJoin,
				where: _where)
	}

	//------------------------------------------------------------------------------------------------------------------
	static private func documentInfos(infoTable :SQLiteTable, contentTable :SQLiteTable,
			sqliteInnerJoin :SQLiteInnerJoin? = nil, where _where :SQLiteWhere? = nil) -> [DocumentInfo] {
		// Setup
		let	sqliteInnerJoinUse =
					(sqliteInnerJoin != nil) ?
							sqliteInnerJoin!.and(infoTable, tableColumn: infoTable.idTableColumn, to: contentTable) :
							SQLiteInnerJoin(infoTable, tableColumn: infoTable.idTableColumn, to: contentTable)

		// Select
		var	documentInfos = [DocumentInfo]()
		infoTable.select(innerJoin: sqliteInnerJoinUse, where: _where) {
			// Iterate all results
			while $0.next() {
				// Get info
				let	id :Int64 = $0.integer(for: infoTable.idTableColumn)!
				let	documentID = $0.text(for: infoTable.documentIDTableColumn)!
				let	revision :Int = $0.integer(for: infoTable.revisionTableColumn)!
				let	creationDate = Date(fromStandardized: $0.text(for: contentTable.creationDateTableColumn)!)!
				let	modificationDate = Date(fromStandardized: $0.text(for: contentTable.modificationDateTableColumn)!)!
				let	propertyMap =
							try! JSONSerialization.jsonObject(
									with: $0.blob(for: contentTable.jsonTableColumn)!) as! [String : Any]

				// Create
				documentInfos.append(
						(documentID,
								MDSSQLiteDocumentBacking(info: Info(id: id, documentID: documentID, revision: revision),
										creationDate: creationDate, modificationDate: modificationDate,
										propertyMap: propertyMap)))
			}
		}

		return documentInfos
	}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(info :Info, creationDate :Date, modificationDate :Date, propertyMap :PropertyMap) {
		// Store
		self.creationDate = creationDate

		self.modificationDate = modificationDate
		self.revision = info.revision

		self.id = info.id

		self.propertyMap = propertyMap
	}

	//------------------------------------------------------------------------------------------------------------------
	init(documentID :String, documentType :String, propertyMap :PropertyMap, with sqliteCore :MDSSQLiteCore) {
		// Setup
		let	(infoTable, contentTable) = sqliteCore.documentTables(for: documentType)

		// Store
		self.revision = sqliteCore.nextRevision(for: documentType)

		// Setup
		let	date = Date()

		self.creationDate = date

		self.modificationDate = date

		self.propertyMap = propertyMap

		// Prepare to update database
		let	data :Data = try! JSONSerialization.data(withJSONObject: self.propertyMap)

		// Add to database
		self.id =
				infoTable.insert([
									(infoTable.documentIDTableColumn, documentID),
									(infoTable.revisionTableColumn, revision),
								 ])
		_ = contentTable.insert([
									(contentTable.idTableColumn, self.id),
									(contentTable.creationDateTableColumn, self.creationDate.standardized),
									(contentTable.modificationDateTableColumn, self.modificationDate.standardized),
									(contentTable.jsonTableColumn, data),
								])
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func value(for property :String) -> Any?
			{ return self.propertyMapLock.read() { return self.propertyMap[property] } }

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for property :String, documentType :String, with sqliteCore :MDSSQLiteCore,
			commitChange :Bool = true) {
		// Check if have value
		if value != nil {
			// Add/Update value
			update(documentType: documentType, updatedPropertyMap: [property : value!], removedProperties: nil,
					with: sqliteCore, commitChange: commitChange)
		} else {
			// Remove value
			update(documentType: documentType, updatedPropertyMap: nil, removedProperties: Set([property]),
					with: sqliteCore, commitChange: commitChange)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func update(documentType :String, updatedPropertyMap :PropertyMap?, removedProperties :Set<String>?,
			with sqliteCore :MDSSQLiteCore, commitChange :Bool = true) {
		// Update
		self.propertyMapLock.write() {
			// Store
			updatedPropertyMap?.forEach() { self.propertyMap[$0.key] = $0.value }
			removedProperties?.forEach() { self.propertyMap[$0] = nil }
		}

		// Check if committing change
		if commitChange {
			// Write
			write(documentType: documentType, with: sqliteCore)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func write(documentType :String, with sqliteCore :MDSSQLiteCore) {
		// Setup
		let	(infoTable, contentTable) = sqliteCore.documentTables(for: documentType)

		// Update
		self.revision = sqliteCore.nextRevision(for: documentType)

		self.modificationDate = Date()

		// Prepare to update database
		let	data :Data =
					self.propertyMapLock.read() {
						// Return data
						return try! JSONSerialization.data(withJSONObject: self.propertyMap)
					}

		// Update
		infoTable.update(
				[
					(infoTable.modificationDateTableColumn, self.modificationDate.standardized),
					(infoTable.revisionTableColumn, self.revision)
				],
				where: SQLiteWhere(tableColumn: infoTable.idTableColumn, value: self.id))
		contentTable.update([(contentTable.jsonTableColumn, data)],
				where: SQLiteWhere(tableColumn: contentTable.idTableColumn, value: self.id))
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove(documentType :String, with sqliteCore :MDSSQLiteCore) {
		// Setup
		let	(infoTable, contentTable) = sqliteCore.documentTables(for: documentType)

		// Delete
		infoTable.delete(where: SQLiteWhere(tableColumn: infoTable.idTableColumn, value: self.id))
		contentTable.delete(where: SQLiteWhere(tableColumn: contentTable.idTableColumn, value: self.id))
	}
}
