//
//  MDSSQLiteDocumentBacking.swift
//
//  Created by Stevo on 10/18/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSSQLiteDocumentBacking
class MDSSQLiteDocumentBacking {

	// MARK: Types
	typealias Info = (id :Int64, documentID :String, creationDate :Date, modificationDate :Date, revision :Int)
	typealias Map = [/* id */ String : MDSSQLiteDocumentBacking]
	typealias PropertyMap = [/* Key */ String : /* Value */ Any]

	typealias TypeInfoMap = [/* type */ String : /* last revision */ Int]

	typealias TablesInfo = (infoTable :SQLiteTable, contentTable :SQLiteTable)
	typealias TablesInfoMap = [/* type */ String : TablesInfo]

	// MARK: Properties
	static	private	let	masterTypeColumnInfo =
								SQLiteTableColumnInfo("type", .text(size: nil, default: nil), [.notNull, .unique])
	static	private	let	masterLastRevisionColumnInfo =
								SQLiteTableColumnInfo("lastRevision", .integer(size: 4, default: nil), [.notNull])

	static	private	let	infoIDTableColumnInfo =
								SQLiteTableColumnInfo("id", .integer(size: nil, default: nil),
										[.primaryKey, .autoincrement])
	static	private	let	infoDocumentIDTableColumnInfo =
								SQLiteTableColumnInfo("documentID", .text(size: nil, default: nil), [.notNull, .unique])
	static	private	let	infoCreationDateTableColumnInfo =
								SQLiteTableColumnInfo("creationDate", .text(size: 23, default: nil), [.notNull])
	static	private	let	infoModificationDateTableColumnInfo =
								SQLiteTableColumnInfo("modificationDate", .text(size: 23, default: nil), [.notNull])
	static	private	let	infoRevisionTableColumnInfo =
								SQLiteTableColumnInfo("revision", .integer(size: 4, default: nil), [.notNull])

	static	private	let	contentsIDTableColumnInfo =
								SQLiteTableColumnInfo("id", .integer(size: nil, default: nil), [.primaryKey])
	static	private	let	contentsJSONTableColumnInfo = SQLiteTableColumnInfo("json", .blob, [.notNull])

					let	creationDate :Date

					var	modificationDate :Date
					var	revision :Int

			private	let	id :Int64

			private	var	propertyMap :PropertyMap
			private	var	propertyMapLock = ReadPreferringReadWriteLock()

	// MARK: Class methods
	//------------------------------------------------------------------------------------------------------------------
	static func masterTable(for database :SQLiteDatabase) -> SQLiteTable {
		// Return table
		return database.table(name: "Documents", options: [],
				tableColumnInfos: [self.masterTypeColumnInfo, self.masterLastRevisionColumnInfo])
	}

	//------------------------------------------------------------------------------------------------------------------
	static func tablesInfo(for documentType :String, tablesInfoMap :inout TablesInfoMap,
			tablesInfoMapLock :inout ReadPreferringReadWriteLock,
			tableProc:
					(_ name :String, _ options :SQLiteTable.Options, _ tableColumnInfos :[SQLiteTableColumnInfo],
							_ referenceInfos :[SQLiteTableColumnReferencesInfo]) -> SQLiteTable) -> TablesInfo {
		// Try existing tables
		if let tablesInfo = tablesInfoMapLock.read({ return tablesInfoMap[documentType] }) {
			// Return tables
			return tablesInfo
		} else {
			// Setup
			let	tableTitleRoot = documentType.prefix(1).uppercased() + documentType.dropFirst()
			let	infoTable =
						tableProc("\(tableTitleRoot)s", [],
								[self.infoIDTableColumnInfo, self.infoDocumentIDTableColumnInfo,
										self.infoCreationDateTableColumnInfo, self.infoModificationDateTableColumnInfo,
										self.infoRevisionTableColumnInfo],
								[])
			let	contentTable =
						tableProc("\(tableTitleRoot)Contents", [],
								[self.contentsIDTableColumnInfo, self.contentsJSONTableColumnInfo],
								[(self.contentsIDTableColumnInfo, infoTable, self.infoIDTableColumnInfo)])

			// Create tables
			_ = infoTable.create()
			_ = contentTable.create()

			// Store in map
			tablesInfoMapLock.write() { tablesInfoMap[documentType] = (infoTable, contentTable) }

			return (infoTable, contentTable)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	static func typeInfoMap(in documentsTable :SQLiteTable) -> TypeInfoMap {
		// Setup
		var	typeInfoMap = TypeInfoMap()

		// Select all
		documentsTable.select() {
			// Iterate all results
			while $0.next() {
				// Get info
				let	type = $0.text(for: self.masterTypeColumnInfo)
				let	lastRevision :Int = $0.integer(for: self.masterLastRevisionColumnInfo)

				// Add to map
				typeInfoMap[type] = lastRevision
			}
		}

		return typeInfoMap
	}

	//------------------------------------------------------------------------------------------------------------------
	static func infos(in tablesInfo :TablesInfo) -> [MDSSQLiteDocumentBacking.Info] {
		// Setup
		var	infos = [MDSSQLiteDocumentBacking.Info]()

		// Select all
		tablesInfo.infoTable.select() {
			// Iterate all results
			while $0.next() {
				// Get info
				let	id :Int = $0.integer(for: self.infoIDTableColumnInfo)
				let	documentID = $0.text(for: self.infoDocumentIDTableColumnInfo)
				let	creationDateStandardized = $0.text(for: self.infoCreationDateTableColumnInfo)
				let	modificationDateStandardized = $0.text(for: self.infoModificationDateTableColumnInfo)
				let	revision :Int = $0.integer(for: self.infoRevisionTableColumnInfo)

				let	creationDate = try! Date(fromStandardized: creationDateStandardized)
				let	modificationDate = try! Date(fromStandardized: modificationDateStandardized)

				// Add to array
				infos.append(
						(id: Int64(id), documentID: documentID, creationDate: creationDate,
								modificationDate: modificationDate, revision: revision))
			}
		}

		return infos
	}

	//------------------------------------------------------------------------------------------------------------------
	static func map(for documentIDs :[String], in tablesInfo :TablesInfo) -> MDSSQLiteDocumentBacking.Map {
		// Setup
		var	map = MDSSQLiteDocumentBacking.Map()

		// Select
		tablesInfo.infoTable.select(innerJoin: (tablesInfo.contentTable, self.contentsIDTableColumnInfo),
				where: (tableColumnInfo: self.infoDocumentIDTableColumnInfo, columnValues: documentIDs)) {
					// Iterate all results
					while $0.next() {
						// Get info
						let	id :Int = $0.integer(for: self.infoIDTableColumnInfo)
						let	documentID = $0.text(for: self.infoDocumentIDTableColumnInfo)
						let	creationDateStandardized = $0.text(for: self.infoCreationDateTableColumnInfo)
						let	modificationDateStandardized = $0.text(for: self.infoModificationDateTableColumnInfo)
						let	revision :Int = $0.integer(for: self.infoRevisionTableColumnInfo)
						let	propertyMap =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: self.contentsJSONTableColumnInfo), options: []) as!
											[String : Any]

						let	creationDate = try! Date(fromStandardized: creationDateStandardized)
						let	modificationDate = try! Date(fromStandardized: modificationDateStandardized)

						// Add to map
						map[documentID] =
								MDSSQLiteDocumentBacking(
										info: (Int64(id), documentID, creationDate, modificationDate, revision),
										propertyMap: propertyMap)
					}
				}

		return map
	}

	//------------------------------------------------------------------------------------------------------------------
	static func map(for infos :[MDSSQLiteDocumentBacking.Info], in tablesInfo :TablesInfo) ->
			MDSSQLiteDocumentBacking.Map {
		// Setup
		var	infoMap = [Int64 : Info]()
		infos.forEach() { infoMap[$0.id] = $0 }

		var	map = MDSSQLiteDocumentBacking.Map()

		// Select
		tablesInfo.contentTable.select(
				tableColumnInfos: [self.contentsIDTableColumnInfo, self.contentsJSONTableColumnInfo],
				where: (tableColumnInfo: self.contentsIDTableColumnInfo, columnValues: Array(infoMap.keys))) {
					// Iterate all results
					while $0.next() {
						// Get info
						let	id :Int = $0.integer(for: self.contentsIDTableColumnInfo)
						let	propertyMap =
									try! JSONSerialization.jsonObject(
											with: $0.blob(for: self.contentsJSONTableColumnInfo), options: []) as!
											[String : Any]
						let	info = infoMap[Int64(id)]!

						// Add to map
						map[info.documentID] = MDSSQLiteDocumentBacking(info: info, propertyMap: propertyMap)
					}
				}

		return map
	}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(info :Info, propertyMap :PropertyMap) {
		// Store
		self.creationDate = info.creationDate

		self.modificationDate = info.modificationDate
		self.revision = info.revision

		self.id = info.id

		self.propertyMap = propertyMap
	}

	//------------------------------------------------------------------------------------------------------------------
	init(documentID :String, type :String, propertyMap :PropertyMap? = nil, typeInfoMap :inout TypeInfoMap,
			documentsTable :SQLiteTable, tablesInfo :TablesInfo) {
		// Setup
		let	revision = (typeInfoMap[type] ?? 0) + 1
		typeInfoMap[type] = revision

		// Store
		self.revision = revision

		// Setup
		let	date = Date()

		self.creationDate = date

		self.modificationDate = date

		self.propertyMap = propertyMap ?? [:]

		// Prepare to update database
		let	data :Data = try! JSONSerialization.data(withJSONObject: self.propertyMap, options: [])

		// Add to database
		_ = documentsTable.insertOrReplace([
											(MDSSQLiteDocumentBacking.masterTypeColumnInfo, type),
											(MDSSQLiteDocumentBacking.masterLastRevisionColumnInfo, revision),
										   ])
		self.id =
				tablesInfo.infoTable.insert([
												(MDSSQLiteDocumentBacking.infoDocumentIDTableColumnInfo, documentID),
												(MDSSQLiteDocumentBacking.infoCreationDateTableColumnInfo,
														self.creationDate.standardized),
												(MDSSQLiteDocumentBacking.infoModificationDateTableColumnInfo,
														self.modificationDate.standardized),
												(MDSSQLiteDocumentBacking.infoRevisionTableColumnInfo, revision),
											])
		_ = tablesInfo.contentTable.insert([
											(MDSSQLiteDocumentBacking.contentsIDTableColumnInfo, self.id),
											(MDSSQLiteDocumentBacking.contentsJSONTableColumnInfo, data),
										   ])
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func value(for key :String) -> Any? { return self.propertyMapLock.read() { return self.propertyMap[key] } }

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for key :String, type :String, typeInfoMap :inout TypeInfoMap, documentsTable :SQLiteTable,
			tablesInfo :TablesInfo) {
		// Check if have value
		if value != nil {
			// Add/Update value
			update(type: type, updatedPropertyMap: [key : value!], removedKeys: nil, typeInfoMap: &typeInfoMap,
					documentsTable: documentsTable, tablesInfo: tablesInfo)
		} else {
			// Remove value
			update(type: type, updatedPropertyMap: nil, removedKeys: Set([key]), typeInfoMap: &typeInfoMap,
					documentsTable: documentsTable, tablesInfo: tablesInfo)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func update(type :String, updatedPropertyMap :PropertyMap?, removedKeys :Set<String>?,
			typeInfoMap :inout TypeInfoMap, documentsTable :SQLiteTable, tablesInfo :TablesInfo) {
		// Setup
		let	revision = (typeInfoMap[type] ?? 0) + 1
		typeInfoMap[type] = revision

		// Update
		self.revision = revision

		self.modificationDate = Date()

		// Prepare to update database
		let	data :Data =
					self.propertyMapLock.write() {
						// Store
						updatedPropertyMap?.forEach() { self.propertyMap[$0.key] = $0.value }
						removedKeys?.forEach() { self.propertyMap[$0] = nil }

						// Return data
						return try! JSONSerialization.data(withJSONObject: self.propertyMap, options: [])
					}

		// Update
		_ = documentsTable.insertOrReplace([
											(MDSSQLiteDocumentBacking.masterTypeColumnInfo, type),
											(MDSSQLiteDocumentBacking.masterLastRevisionColumnInfo, revision),
										   ])
		tablesInfo.infoTable.update(
				[
					(MDSSQLiteDocumentBacking.infoModificationDateTableColumnInfo, self.modificationDate.standardized),
					(MDSSQLiteDocumentBacking.infoRevisionTableColumnInfo, self.revision)
				],
				where: (tableColumnInfo: MDSSQLiteDocumentBacking.infoIDTableColumnInfo, columnValue: self.id))
		tablesInfo.contentTable.update([(MDSSQLiteDocumentBacking.contentsJSONTableColumnInfo, data)],
				where: (tableColumnInfo: MDSSQLiteDocumentBacking.contentsIDTableColumnInfo, columnValue: self.id))
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove(from tablesInfo :TablesInfo) {
		// Delete
		tablesInfo.infoTable.delete(
				where: (tableColumnInfo: MDSSQLiteDocumentBacking.infoIDTableColumnInfo, columnValue: self.id))
		tablesInfo.contentTable.delete(
				where: (tableColumnInfo: MDSSQLiteDocumentBacking.contentsIDTableColumnInfo, columnValue: self.id))
	}
}
