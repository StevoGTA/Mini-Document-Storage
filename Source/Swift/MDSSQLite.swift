//
//  MDSSQLite.swift
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

/*
	See https://docs.google.com/document/d/1zgMAzYLemHA05F_FR4QZP_dn51cYcVfKMcUfai60FXE/edit for overview

	Summary:
		Info table
			Columns: key, value
		Documents table
			Columns: type, lastRevision
		Collections table
			Columns: id, name, type, version, lastRevision

		{DOCUMENTTYPE}s
			Columns: id, documentID, revision
		{DOCUMENTTYPE}Contents
			Columns: id, json

		Collection-{COLLECTIONNAME}
			Columns: id
*/

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSSQLiteError
public enum MDSSQLiteError : Error {
	case documentNotFound(documentType :String, documentID :String)
}

extension MDSSQLiteError : LocalizedError {
	public	var	errorDescription :String? {
						switch self {
							case .documentNotFound(let documentType, let documentID):
								return "MDSSQLite cannot find document of type \(documentType) with id \"\(documentID)\""
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSSQLite
class MDSSQLite : MiniDocumentStorage {

	// MARK: MiniDocumentStorage implementation
	//------------------------------------------------------------------------------------------------------------------
	func newDocument<T : MDSDocument>(documentType :String, creationProc :MDSDocument.CreationProc) -> T {
		// Setup
		let	documentID = UUID().base64EncodedString

		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }) {
			// In batch
			_ = batchInfo.addDocument(documentType: documentType, documentID: documentID, creationDate: Date(),
					modificationDate: Date())
		} else {
			// Add document
			let	document =
						MDSSQLiteDocumentBacking(documentID: documentID, type: documentType,
								typeInfoMap: &self.documentBackingTypeInfoMap, documentsTable: self.documentsTable,
								tablesInfo: tablesInfo(for: documentType))
			self.documentBackingMapLock.write() { self.documentBackingMap[documentID] = document }
		}

		// Create
		return creationProc(documentID, self) as! T
	}

	//------------------------------------------------------------------------------------------------------------------
	func document<T : MDSDocument>(for documentID :String, documentType :String, creationProc :MDSDocument.CreationProc)
			-> T? {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }),
				batchInfo.batchDocumentInfo(for: documentID) != nil {
			// Have document in batch
			return (creationProc(documentID, self) as! T)
		} else {
			// Don't have document in batch
			let	documentBacking = self.documentBacking(documentType: documentType, documentID: documentID)

			return (documentBacking != nil) ? (creationProc(documentID, self) as! T) : nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func value(for key :String, documentID :String, documentType :String) -> Any? {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }),
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: documentID) {
			// In batch
			return batchDocumentInfo.value(for: key)
		} else {
			// Not in batch
			return documentBacking(documentType: documentType, documentID: documentID)?.value(for: key)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for key :String, documentID :String, documentType :String) {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: documentID) {
				// Have document in batch
				batchDocumentInfo.set(value, for: key)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(documentType: documentType, documentID: documentID)
				batchInfo.addDocument(documentType: documentType, documentID: documentID, reference: documentBacking,
						creationDate: Date(), modificationDate: Date(), valueProc: { return $0.value(for: $1) })
						.set(value, for: key)
			}
		} else {
			// Not in batch
			let	tablesInfo = self.tablesInfo(for: documentType)
			if let documentBacking = self.documentBacking(documentID: documentID, in: tablesInfo) {
				// Update document
				documentBacking.set(value, for: key, type: documentType, typeInfoMap: &self.documentBackingTypeInfoMap,
						documentsTable: self.documentsTable, tablesInfo: tablesInfo)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func date(for value :Any?) -> Date? { return (value != nil) ? try! Date(fromStandardized: value as! String) : nil }

	//------------------------------------------------------------------------------------------------------------------
	func value(for date :Date?) -> Any? { return (date != nil) ? date!.standardized : nil }

	//------------------------------------------------------------------------------------------------------------------
	func remove(documentID :String, documentType :String) {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: documentID) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(documentType: documentType, documentID: documentID)
				batchInfo.addDocument(documentType: documentType, documentID: documentID, reference: documentBacking,
						creationDate: Date(), modificationDate: Date()).remove()
			}
		} else {
			// Not in batch
			let	tablesInfo = self.tablesInfo(for: documentType)
			if let documentBacking = self.documentBacking(documentID: documentID, in: tablesInfo) {
				// Remove document
				documentBacking.remove(from: tablesInfo)
				self.documentBackingMapLock.write() { self.documentBackingMap[documentID] = nil }
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(documentType :String, proc :MDSDocument.ApplyProc<T>,
			creationProc :MDSDocument.CreationProc) {
		// Setup
		let	tablesInfo = self.tablesInfo(for: documentType)
		let	infos = MDSSQLiteDocumentBacking.infos(in: tablesInfo)

		// Collect existing documents and collect infos for documents to retrieve
		var	documentBackingIDs = [String]()
		var	infosToRetrieve = [MDSSQLiteDocumentBacking.Info]()
		self.documentBackingMapLock.read() {
			// Iterate document infos
			infos.forEach() {
				// Check if already have this document
				if self.documentBackingMap[$0.documentID] != nil {
					// Have existing document
					documentBackingIDs.append($0.documentID)
				} else {
					// Need to retrieve
					infosToRetrieve.append($0)
				}
			}
		}

		// Enumerate and call proc
		documentBackingIDs.forEach() { proc(creationProc($0, self) as! T) }

		// Check if need to retrieve documents
		if !infosToRetrieve.isEmpty {
			// Retrieve documents
			let	map = MDSSQLiteDocumentBacking.map(for: infosToRetrieve, in: tablesInfo)

			// Update map
			self.documentBackingMapLock.write() { map.forEach() { self.documentBackingMap[$0.key] = $0.value } }

			// Enumerate and call proc
			map.keys.forEach() { proc(creationProc($0, self) as! T) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func batch(_ proc :() -> MDSBatchResult) {
		// Setup
		let	batchInfo = MDSBatchInfo<MDSSQLiteDocumentBacking>()

		// Store
		self.mdsBatchInfoMapLock.write() { self.mdsBatchInfoMap[Thread.current] = batchInfo }

		// Call proc
		let	result = proc()

		// Remove
		self.mdsBatchInfoMapLock.write() { self.mdsBatchInfoMap[Thread.current] = nil }

		// Check result
		if result == .commit {
			// Iterate all document changes
			batchInfo.forEach() { documentType, batchDocumentInfosMap in
				// Get tables
				let	tablesInfo = self.tablesInfo(for: documentType)

				// Update documents
				batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
					// Is removed?
					if !batchDocumentInfo.removed {
						// Update document
						if let document = batchDocumentInfo.reference {
							// Update document
							document.update(type: documentType,
									updatedPropertyMap: batchDocumentInfo.updatedPropertyMap,
									removedKeys: batchDocumentInfo.removedKeys,
									typeInfoMap: &self.documentBackingTypeInfoMap,
									documentsTable: self.documentsTable, tablesInfo: tablesInfo)
						} else {
							// Add document
							let	document =
										MDSSQLiteDocumentBacking(documentID: documentID, type: documentType,
												propertyMap: batchDocumentInfo.updatedPropertyMap,
												typeInfoMap: &self.documentBackingTypeInfoMap,
												documentsTable: self.documentsTable, tablesInfo: tablesInfo)
							self.documentBackingMapLock.write() { self.documentBackingMap[documentID] = document }
						}
					} else {
						// Remove document
						batchDocumentInfo.reference!.remove(from: tablesInfo)
						self.documentBackingMapLock.write() { self.documentBackingMap[documentID] = nil }
					}
				}
			}
		}
	}

	// MARK: Properties
	private	let	sqliteDatabase :SQLiteDatabase

	private	let	infoTable :SQLiteTable
	private	let	infoKeyTableColumn =
						SQLiteTableColumn("key", .text(size: nil, default: nil), [.primaryKey, .unique, .notNull])
	private	let	infoValueTableColumn = SQLiteTableColumn("value", .text(size: nil, default: nil), [.notNull])

	private	let	documentsTable :SQLiteTable
	private	let	collectionsTable :SQLiteTable

	private	var	mdsBatchInfoMap = [Thread : MDSBatchInfo<MDSSQLiteDocumentBacking>]()
	private	var	mdsBatchInfoMapLock = ReadPreferringReadWriteLock()

	private	var	documentBackingMap = [/* Document ID */ String : MDSSQLiteDocumentBacking]()
	private	var	documentBackingMapLock = ReadPreferringReadWriteLock()

	private	var	documentBackingTypeInfoMap :MDSSQLiteDocumentBacking.TypeInfoMap
	private	var	documentTablesInfoMap = MDSSQLiteDocumentBacking.TablesInfoMap()
	private	var	documentTablesInfoMapLock = ReadPreferringReadWriteLock()

//	private	var	collectionsMap = [/* ??? */ String : SQLiteTable]()
//	private	var	collectionsMapLock = ReadPreferringReadWriteLock()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(folderURL :URL, databaseName :String) throws {
		// Setup database
		self.sqliteDatabase = try SQLiteDatabase(url: folderURL.appendingPathComponent(databaseName))

		// Setup tables
		self.infoTable =
				self.sqliteDatabase.table(name: "Info", options: [.withoutRowID],
						tableColumns: [self.infoKeyTableColumn, self.infoValueTableColumn])
		self.infoTable.create()

		let	infoValueTableColumn = self.infoValueTableColumn

		var	version :Int?
		self.infoTable.select(tableColumns: [self.infoValueTableColumn],
				where: SQLiteWhere(tableColumn: self.infoKeyTableColumn, value: "version")) {
					// Retrieve value
					version = $0.next() ? Int($0.text(for: infoValueTableColumn)!) : nil
				}
		if version == nil {
			// Setup table
			_ = self.infoTable.insert([
										(self.infoKeyTableColumn, "version"),
										(self.infoValueTableColumn, 1),
									  ])
		}

		self.documentsTable = MDSSQLiteDocumentBacking.masterTable(for: self.sqliteDatabase)
		self.documentsTable.create()
		self.documentBackingTypeInfoMap = MDSSQLiteDocumentBacking.typeInfoMap(in: self.documentsTable)

		self.collectionsTable = MDSSQLiteCollection.masterTable(for: self.sqliteDatabase)
		self.collectionsTable.create()
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func tablesInfo(for documentType :String) -> MDSSQLiteDocumentBacking.TablesInfo {
		// Return tables
		return MDSSQLiteDocumentBacking.tablesInfo(for: documentType, tablesInfoMap: &self.documentTablesInfoMap,
				tablesInfoMapLock: &self.documentTablesInfoMapLock,
				tableProc: {
					// Return table
					return self.sqliteDatabase.table(name: $0, options: $1, tableColumns: $2, references: $3)
				})
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBacking(documentType :String, documentID :String) -> MDSSQLiteDocumentBacking? {
		// Try to retrieve stored document
		if let documentBacking = self.documentBackingMapLock.read({ return self.documentBackingMap[documentID] }) {
			// Have document
			return documentBacking
		} else {
			// Don't have document yet
			let	tablesInfo = self.tablesInfo(for: documentType)
			if let documentBacking = MDSSQLiteDocumentBacking.map(for: [documentID], in: tablesInfo).first?.value {
				// Update map
				self.documentBackingMapLock.write() { self.documentBackingMap[documentID] = documentBacking }

				return documentBacking
			} else {
				// Doesn't exist
				return nil
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBacking(documentID :String, in tablesInfo :MDSSQLiteDocumentBacking.TablesInfo) ->
			MDSSQLiteDocumentBacking? {
		// Try to retrieve stored document
		if let documentBacking = self.documentBackingMapLock.read({ return self.documentBackingMap[documentID] }) {
			// Have document
			return documentBacking
		} else {
			// Don't have document yet
			if let documentBacking = MDSSQLiteDocumentBacking.map(for: [documentID], in: tablesInfo).first?.value {
				// Update map
				self.documentBackingMapLock.write() { self.documentBackingMap[documentID] = documentBacking }

				return documentBacking
			} else {
				// Doesn't exist
				return nil
			}
		}
	}
}
