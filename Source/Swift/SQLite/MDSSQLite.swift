//
//  MDSSQLite.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

/*
	// TODOs:
		-Document backing cache needs to be make more performant
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
// MARK: - MDSSQLiteDocumentInfo
struct MDSSQLiteDocumentInfo {

	// MARK: Properties
	let	documentType :String
	let	documentID :String
	let	creationDate :Date?
	let	modificationDate :Date?
	let	propertyMap :MDSDocument.PropertyMap

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(documentType :String, documentID :String, creationDate :Date? = nil, modificationDate :Date? = nil,
			propertyMap :MDSDocument.PropertyMap) {
		// Store
		self.documentType = documentType
		self.documentID = documentID
		self.creationDate = creationDate
		self.modificationDate = modificationDate
		self.propertyMap = propertyMap
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSSQLite
public class MDSSQLite : MDSDocumentStorageServerBacking {

	// MARK: Properties
	public	var	id :String = UUID().uuidString

			var	logErrorMessageProc :(_ errorMessage :String) -> Void = { _ in }

	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<MDSSQLiteDocumentBacking>>()
	private	let	documentBackingCache = MDSDocumentBackingCache<MDSSQLiteDocumentBacking>()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, MDSDocument.PropertyMap>()
	private	let	sqliteCore :MDSSQLiteCore

	private	var	documentCreationProcMap = LockingDictionary<String, MDSDocument.CreationProc>()

	private	var	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	var	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()

	private	var	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	var	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()

	private	var	documentChangedProcsMap = LockingDictionary</* Document Type */ String, [MDSDocument.ChangedProc]>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(folderURL :URL, databaseName :String) throws {
		// Setup database
		let sqliteDatabase = try SQLiteDatabase(url: folderURL.appendingPathComponent(databaseName))

		// Setup core
		self.sqliteCore = MDSSQLiteCore(sqliteDatabase: sqliteDatabase)

		// Retrieve version
		var	version = self.sqliteCore.int(for: "version") ?? 0
		if version == 0 {
			// Initialize
			self.sqliteCore.set(1, for: "version")
			version = 1
		}
	}

	// MARK: MDSDocumentStorage implementation
	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) -> [String : String] {
		// Return dictionary
		return [String : String](keys){ self.sqliteCore.string(for: $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ info :[String : String]) { info.forEach() { self.sqliteCore.set($0.value, for: $0.key) } }

	//------------------------------------------------------------------------------------------------------------------
	public func remove(keys :[String]) { keys.forEach() { self.sqliteCore.set(nil, for: $0) } }

	//------------------------------------------------------------------------------------------------------------------
	public func newDocument<T : MDSDocument>(creationProc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T)
			-> T {
		// Setup
		let	documentID = UUID().base64EncodedString

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			_ = batchInfo.addDocument(documentType: T.documentType, documentID: documentID, creationDate: Date(),
					modificationDate: Date())

			return creationProc(documentID, self)
		} else {
			// Will be creating document
			self.documentsBeingCreatedPropertyMapMap.set(MDSDocument.PropertyMap(), for: documentID)

			// Create
			let	document = creationProc(documentID, self)

			// Remove property map
			let	propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID)!
			self.documentsBeingCreatedPropertyMapMap.remove(documentID)

			// Add document
			let	documentBacking =
						MDSSQLiteDocumentBacking(documentType: T.documentType, documentID: documentID,
								propertyMap: propertyMap, with: self.sqliteCore)
			self.documentBackingCache.add(
					[MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>(documentID: documentID,
							documentBacking: documentBacking)])

			// Update collections and indexes
			let	updateInfos :[MDSUpdateInfo<Int64>] =
						[MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
								value: documentBacking.id, changedProperties: nil)]
			updateCollections(for: T.documentType, updateInfos: updateInfos)
			updateIndexes(for: T.documentType, updateInfos: updateInfos)

			// Call document changed procs
			self.documentChangedProcsMap.value(for: T.documentType)?.forEach() { $0(document, .created) }

			return document
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) -> T? {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				batchInfo.batchDocumentInfo(for: documentID) != nil {
			// Have document in batch
			return T(id: documentID, documentStorage: self)
		} else if self.documentBacking(documentType: T.documentType, documentID: documentID) != nil {
			// Have document backing
			return T(id: documentID, documentStorage: self)
		} else {
			// Don't have document backing
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func creationDate(for document :MDSDocument) -> Date{
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.creationDate
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// "Idle"
			return documentBacking(documentType: type(of: document).documentType, documentID: document.id)!.creationDate
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func modificationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.modificationDate
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// "Idle"
			return documentBacking(documentType: type(of: document).documentType, documentID: document.id)!
					.modificationDate
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func value(for property :String, in document :MDSDocument) -> Any? {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			return propertyMap[property]
		} else {
			// "Idle"
			return documentBacking(documentType: type(of: document).documentType, documentID: document.id)!
					.value(for: property)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for property :String, in document :MDSDocument) -> Date? {
		// Return date
		Date(fromRFC3339Extended: value(for: property, in: document) as? String)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
		// Setup
		let	documentType = type(of: document).documentType

		// Transform
		let	valueUse :Any?
		if let date = value as? Date {
			// Date
			valueUse = date.rfc3339Extended
		} else {
			// Everythng else
			valueUse = value
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.set(valueUse, for: property)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(documentType: documentType, documentID: document.id)!
				let	now = Date()
				batchInfo.addDocument(documentType: documentType, documentID: document.id, reference: documentBacking,
								creationDate: now, modificationDate: now,
								valueProc: { documentBacking.value(for: $0) })
						.set(valueUse, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			propertyMap[property] = valueUse
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: document.id)
		} else {
			// Update document
			let	documentBacking = self.documentBacking(documentType: documentType, documentID: document.id)!
			documentBacking.set(valueUse, for: property, documentType: documentType, with: self.sqliteCore)

			// Update collections and indexes
			let	updateInfos :[MDSUpdateInfo<Int64>] =
						[MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
								value: documentBacking.id, changedProperties: [property])]
			updateCollections(for: documentType, updateInfos: updateInfos)
			updateIndexes(for: documentType, updateInfos: updateInfos)

			// Call document changed procs
			self.documentChangedProcsMap.value(for: T.documentType)?.forEach() { $0(document, .updated) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(_ document :MDSDocument) {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(documentType: documentType, documentID: document.id)!
				batchInfo.addDocument(documentType: documentType, documentID: document.id, reference: documentBacking,
						creationDate: Date(), modificationDate: Date()).remove()
			}
		} else {
			// Not in batch
			let	documentBacking = self.documentBacking(documentType: documentType, documentID: document.id)!

			// Remove from collections and indexes
			removeFromCollections(for: documentType, documentBackingIDs: [documentBacking.id])
			removeFromIndexes(for: documentType, documentBackingIDs: [documentBacking.id])

			// Remove
			self.sqliteCore.remove(documentType: documentType, id: documentBacking.id)

			// Remove from cache
			self.documentBackingCache.remove([document.id])

			// Call document changed procs
			self.documentChangedProcsMap.value(for: documentType)?.forEach() { $0(document, .removed) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Setup
		let	documentTables = self.sqliteCore.documentTables(for: T.documentType)

		// Iterate
// TODO: For now, don't know how to do SQLite actions during processing results, so cache results, then re-iterate
		var	documentIDs = [String]()
		autoreleasepool() {
			// Collect document IDs
			iterateDocumentBackingInfos(documentTables: documentTables,
					innerJoin:
							SQLiteInnerJoin(documentTables.infoTable,
									tableColumn: documentTables.infoTable.idTableColumn,
									to: documentTables.contentTable),
					where: SQLiteWhere(tableColumn: documentTables.infoTable.activeTableColumn, value: 1))
					{ documentIDs.append($1.documentID) }
		}
		autoreleasepool() { documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void) {
		// Iterate
// TODO: For now, don't know how to do SQLite actions during processing results, so cache results, then re-iterate
		autoreleasepool() {
			// Iterate
			iterateDocumentBackingInfos(documentType: T.documentType, documentIDs: documentIDs) { _ = $0 }
		}
		autoreleasepool() { documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Setup
		let	batchInfo = MDSBatchInfo<MDSSQLiteDocumentBacking>()

		// Store
		self.batchInfoMap.set(batchInfo, for: Thread.current)

		// Run lean
		var	result = MDSBatchResult.commit
		try autoreleasepool() {
			// Call proc
			result = try proc()
		}

		// Check result
		if result == .commit {
			// Batch changes
			self.sqliteCore.batch() {
				// Iterate all document changes
				batchInfo.forEach() { documentType, batchDocumentInfosMap in
					// Setup
					let	updateBatchQueue =
								BatchQueue<MDSUpdateInfo<Int64>>(maximumBatchSize: 999) {
									// Update collections and indexes
									self.updateCollections(for: documentType, updateInfos: $0)
									self.updateIndexes(for: documentType, updateInfos: $0)
								}
					let	removedBatchQueue =
								BatchQueue<Int64>(maximumBatchSize: 999) {
									// Update collections and indexes
									self.removeFromCollections(for: documentType, documentBackingIDs: $0)
									self.removeFromIndexes(for: documentType, documentBackingIDs: $0)
								}
					// Update documents
					batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
						// Is removed?
						if !batchDocumentInfo.removed {
							// Add/update document
							if let documentBacking = batchDocumentInfo.reference {
								// Update document
								documentBacking.update(documentType: documentType,
										updatedPropertyMap: batchDocumentInfo.updatedPropertyMap,
										removedProperties: batchDocumentInfo.removedProperties, with: self.sqliteCore)

								// Check if we have creation proc
								if let creationProc = self.documentCreationProcMap.value(for: documentType) {
									// Create document
									let	document = creationProc(documentID, self)

									// Update collections and indexes
									let	changedProperties =
												Array((batchDocumentInfo.updatedPropertyMap ?? [:]).keys) +
														Array(batchDocumentInfo.removedProperties ?? Set<String>())
									updateBatchQueue.add(
											MDSUpdateInfo<Int64>(document: document,
													revision: documentBacking.revision, value: documentBacking.id,
													changedProperties: changedProperties))

									// Call document changed procs
									self.documentChangedProcsMap.value(for: documentType)?.forEach()
										{ $0(document, .updated) }
								}
							} else {
								// Add document
								let	documentBacking =
											MDSSQLiteDocumentBacking(documentType: documentType, documentID: documentID,
													creationDate: batchDocumentInfo.creationDate,
													modificationDate: batchDocumentInfo.modificationDate,
													propertyMap: batchDocumentInfo.updatedPropertyMap ?? [:],
													with: self.sqliteCore)
								self.documentBackingCache.add(
										[MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>(documentID: documentID,
												documentBacking: documentBacking)])

								// Check if we have creation proc
								if let creationProc = self.documentCreationProcMap.value(for: documentType) {
									// Create document
									let	document = creationProc(documentID, self)

									// Update collections and indexes
									updateBatchQueue.add(
											MDSUpdateInfo<Int64>(document: document,
													revision: documentBacking.revision, value: documentBacking.id,
													changedProperties: nil))

									// Call document changed procs
									self.documentChangedProcsMap.value(for: documentType)?.forEach()
										{ $0(document, .created) }
								}
							}
						} else if let documentBacking = batchDocumentInfo.reference {
							// Remove document
							self.sqliteCore.remove(documentType: documentType, id: documentBacking.id)
							self.documentBackingCache.remove([documentID])

							// Remove from collections and indexes
							removedBatchQueue.add(documentBacking.id)

							// Check if we have creation proc
							if let creationProc = self.documentCreationProcMap.value(for: documentType) {
								// Create document
								let	document = creationProc(documentID, self)

								// Call document changed procs
								self.documentChangedProcsMap.value(for: documentType)?.forEach()
									{ $0(document, .removed) }
							}
						}
					}

					// Finalize batch queues
					updateBatchQueue.finalize()
					removedBatchQueue.finalize()
				}
			}
		}

		// Remove
		self.batchInfoMap.set(nil, for: Thread.current)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			info :[String : Any], isUpToDate :Bool, isIncludedSelector :String,
			isIncludedProc :@escaping (_ document :T, _ info :[String : Any]) -> Bool) {
		// Ensure this collection has not already been registered
		guard self.collectionsByNameMap.value(for: name) == nil else { return }

		// Ensure we have the document tables
		_ = self.sqliteCore.documentTables(for: T.documentType)

		// Register collection
		let	lastRevision =
					self.sqliteCore.registerCollection(documentType: T.documentType, name: name, version: version,
							info: info, isUpToDate: isUpToDate)

		// Create collection
		let	collection =
					MDSCollectionSpecialized(name: name, relevantProperties: relevantProperties,
							lastRevision: lastRevision, isIncludedProc: isIncludedProc, info: info)

		// Add to maps
		self.collectionsByNameMap.set(collection, for: name)
		self.collectionsByDocumentTypeMap.appendArrayValue(collection, for: T.documentType)

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func queryCollectionDocumentCount(name :String) -> UInt {
		// Run lean
		autoreleasepool() { _ = bringCollectionUpToDate(name: name) }

		return self.sqliteCore.queryCollectionDocumentCount(name: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// Iterate
// TODO: For now, don't know how to do SQLite actions during processing results, so cache results, then re-iterate
		var	documentIDs = [String]()
		autoreleasepool() { iterateCollection(name: name, with: { documentIDs.append($0.documentID) }) }
		autoreleasepool() { documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping (_ document :T) -> [String]) {
		// Ensure this index has not already been registered
		guard self.indexesByNameMap.value(for: name) == nil else { return }

		// Ensure we have the document tables
		_ = self.sqliteCore.documentTables(for: T.documentType)

		// Register index
		let	lastRevision =
					self.sqliteCore.registerIndex(documentType: T.documentType, name: name, version: version,
							isUpToDate: isUpToDate)

		// Create index
		let	index =
					MDSIndexSpecialized(name: name, relevantProperties: relevantProperties, lastRevision: lastRevision,
							keysProc: keysProc)

		// Add to maps
		self.indexesByNameMap.set(index, for: name)
		self.indexesByDocumentTypeMap.appendArrayValue(index, for: T.documentType)

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateIndex<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
		// Iterate
// TODO: For now, don't know how to do SQLite actions during processing results, so cache results, then re-iterate
		var	documentIDMap = [/* Key */ String : /* String */ String]()
		autoreleasepool() { iterateIndex(name: name, keys: keys, with: { documentIDMap[$0] = $1.documentID }) }
		autoreleasepool() { documentIDMap.forEach() { proc($0.key, T(id: $0.value, documentStorage: self)) } }
	}

	// MARK: MDSDocumentStorageServerBacking methods
	//------------------------------------------------------------------------------------------------------------------
	func newDocuments(documentType :String, documentCreateInfos :[MDSDocumentCreateInfo]) {
		// Batch
		self.sqliteCore.batch() {
			// Setup
			let	batchQueue =
						BatchQueue<MDSUpdateInfo<Int64>>(maximumBatchSize: 999) {
							// Update collections and indexes
							self.updateCollections(for: documentType, updateInfos: $0)
							self.updateIndexes(for: documentType, updateInfos: $0)
						}

			// Iterate all infos
			documentCreateInfos.forEach() {
				// Setup
				let	documentID = $0.documentID ?? UUID().base64EncodedString

				// Add document
				let	documentBacking =
							MDSSQLiteDocumentBacking(documentType: documentType, documentID: documentID,
									creationDate: $0.creationDate, modificationDate: $0.modificationDate,
									propertyMap: $0.propertyMap, with: self.sqliteCore)
				self.documentBackingCache.add(
						[MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>(documentID: documentID,
								documentBacking: documentBacking)])

				// Check if we have creation proc
				if let creationProc = self.documentCreationProcMap.value(for: documentType) {
					// Create document
					let	document = creationProc(documentID, self)

					// Update collections and indexes
					batchQueue.add(
							MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
									value: documentBacking.id, changedProperties: nil))
				}
			}

			// Finalize batch queue
			batchQueue.finalize()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterate(documentType :String, documentIDs :[String],
			proc :(_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void) {
		// Setup
		let	infoTable = self.sqliteCore.documentTables(for: documentType).infoTable

		// Select
		try! infoTable.select(where: SQLiteWhere(tableColumn: infoTable.documentIDTableColumn, values: documentIDs)) {
					// Call proc
					proc(MDSSQLiteCore.info(infoTable: infoTable, resultsRow: $0).documentRevisionInfo)
				}
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterate(documentType :String, documentIDs :[String],
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void) {
		// Iterate
		iterateDocumentBackingInfos(documentType: documentType, documentIDs: documentIDs) {
			// Call proc
			proc(MDSDocumentFullInfo(documentID: $0.documentID, revision: $0.documentBacking.revision,
					creationDate: $0.documentBacking.creationDate,
					modificationDate: $0.documentBacking.modificationDate, propertyMap: $0.documentBacking.propertyMap))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :(_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void) {
		// Setup
		let	infoTable = self.sqliteCore.documentTables(for: documentType).infoTable

		// Select
		try! infoTable.select(
				where: SQLiteWhere(tableColumn: infoTable.revisionTableColumn, comparison: ">", value: revision)) {
					// Call proc
					proc(MDSSQLiteCore.info(infoTable: infoTable, resultsRow: $0).documentRevisionInfo)
				}
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void) {
		// Iterate
		iterateDocumentBackingInfos(documentType: documentType, sinceRevision: revision, includeInactive: true) {
			// Call proc
			proc(MDSDocumentFullInfo(documentID: $0.documentID, revision: $0.documentBacking.revision,
					creationDate: $0.documentBacking.creationDate,
					modificationDate: $0.documentBacking.modificationDate, propertyMap: $0.documentBacking.propertyMap))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func updateDocuments(documentType :String, documentUpdateInfos :[MDSDocumentUpdateInfo]) {
		// Batch changes
		self.sqliteCore.batch() {
			// Setup
			let	map = Dictionary(documentUpdateInfos.map() { ($0.documentID, $0) })
			let	updateBatchQueue =
						BatchQueue<MDSUpdateInfo<Int64>>(maximumBatchSize: 999) {
							// Update collections and indexes
							self.updateCollections(for: documentType, updateInfos: $0)
							self.updateIndexes(for: documentType, updateInfos: $0)
						}
			let	removedBatchQueue =
						BatchQueue<Int64>(maximumBatchSize: 999) {
							// Update collections and indexes
							self.removeFromCollections(for: documentType, documentBackingIDs: $0)
							self.removeFromIndexes(for: documentType, documentBackingIDs: $0)
						}

			// Iterate document IDs
			iterateDocumentBackingInfos(documentType: documentType, documentIDs: Array(map.keys)) {
				// Set update info
				let	documentUpdateInfo = map[$0.documentID]!

				// Check active
				if documentUpdateInfo.active {
					// Update document
					$0.documentBacking.update(documentType: documentType,
							updatedPropertyMap: documentUpdateInfo.updated,
							removedProperties: Set(documentUpdateInfo.removed), with: self.sqliteCore)

					// Check if we have creation proc
					if let creationProc = self.documentCreationProcMap.value(for: documentType) {
						// Create document
						let	document = creationProc($0.documentID, self)

						// Update collections and indexes
						let	changedProperties = Array(documentUpdateInfo.updated.keys) + documentUpdateInfo.removed
						updateBatchQueue.add(
								MDSUpdateInfo<Int64>(document: document,
										revision: $0.documentBacking.revision, value: $0.documentBacking.id,
										changedProperties: changedProperties))
					}
				} else {
					// Remove document
					self.sqliteCore.remove(documentType: documentType, id: $0.documentBacking.id)
					self.documentBackingCache.remove([$0.documentID])

					// Remove from collections and indexes
					removedBatchQueue.add($0.documentBacking.id)
				}

				// Finalize batch queues
				updateBatchQueue.finalize()
				removedBatchQueue.finalize()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection(named name :String, documentType :String, version :UInt, isIncludedSelector :String,
			relevantProperties :[String], info :MDSDocument.PropertyMap, isUpToDate :Bool) {
		// Not implemented
		fatalError("MDSSQLite - registerCollection from remote is not implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateCollection(name :String, proc :(_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void) {
		// Bring up to date
		let	collection = autoreleasepool() { bringCollectionUpToDate(name: name) }
		let	documentType = collection.documentType

		// Setup
		let	(infoTable, _) = self.sqliteCore.documentTables(for: documentType)
		let	collectionContentsTable = self.sqliteCore.sqliteTable(forCollectionNamed: name)

		// Select
		try! collectionContentsTable.select(
				innerJoin:
						SQLiteInnerJoin(infoTable, tableColumn: infoTable.idTableColumn, to: collectionContentsTable)) {
					// Call proc
					proc(MDSSQLiteCore.info(infoTable: infoTable, resultsRow: $0).documentRevisionInfo)
				}
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateCollection(name :String, proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void) {
		// Iterate
		iterateCollection(name: name, with: {
			// Call proc
			proc(MDSDocumentFullInfo(documentID: $0.documentID, revision: $0.documentBacking.revision,
					creationDate: $0.documentBacking.creationDate,
					modificationDate: $0.documentBacking.modificationDate,
					propertyMap: $0.documentBacking.propertyMap))
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerIndex(named name :String, documentType :String, version :UInt, keySelector :String,
			relevantProperties :[String]) {
		// Not implemented
		fatalError("MDSSQLite - registerIndex from remote is not implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateIndex(name :String, keys :[String],
			proc :(_ key :String, _ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void) {
		// Bring up to date
		let	index = autoreleasepool() { bringIndexUpToDate(name: name) }
		let	documentType = index.documentType

		// Setup
		let	(infoTable, _) = self.sqliteCore.documentTables(for: documentType)
		let	indexContentsTable = self.sqliteCore.sqliteTable(forIndexNamed: name)

		// Select
		try! infoTable.select(
				innerJoin: SQLiteInnerJoin(infoTable, tableColumn: infoTable.idTableColumn, to: indexContentsTable)) {
					// Call proc
					proc(MDSSQLiteCore.key(for: indexContentsTable, resultsRow: $0),
							MDSSQLiteCore.info(infoTable: infoTable, resultsRow: $0).documentRevisionInfo)
				}
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateIndex(name :String, keys :[String],
			proc :(_ key :String, _ documentFullInfo :MDSDocumentFullInfo) -> Void) {
		// Iterate
		iterateIndex(name: name, keys: keys, with: {
			// Call proc
			proc($0,
					MDSDocumentFullInfo(documentID: $1.documentID, revision: $1.documentBacking.revision,
							creationDate: $1.documentBacking.creationDate,
							modificationDate: $1.documentBacking.modificationDate,
							propertyMap: $1.documentBacking.propertyMap))
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerDocumentChangedProc(documentType :String, proc :@escaping MDSDocument.ChangedProc) {
		//  Add
		self.documentChangedProcsMap.update(for: documentType) { ($0 ?? []) + [proc] }
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	func documentBackingMap(for documentInfos :[MDSSQLiteDocumentInfo]) -> [String : MDSSQLiteDocumentBacking] {
		// Setup
		var	documentBackingMap = [String : MDSSQLiteDocumentBacking]()

		// Perform as batch and iterate all
		self.sqliteCore.batch() {
			// Create document backings
			var	documentTypeMap = [/* Document type */ String : [MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>]]()
			documentInfos.forEach() {
				// Create document backing
				let	documentBacking =
							MDSSQLiteDocumentBacking(documentType: $0.documentType, documentID: $0.documentID,
									creationDate: $0.creationDate, modificationDate: $0.modificationDate,
									propertyMap: $0.propertyMap, with: self.sqliteCore)

				// Add to maps
				documentBackingMap[$0.documentID] = documentBacking
				documentTypeMap.appendArrayValueElement(key: $0.documentType,
						value:
								MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>(documentID: $0.documentID,
										documentBacking: documentBacking))
			}

			// Iterate document types
			documentTypeMap.forEach() {
				// Add to cache
				self.documentBackingCache.add($0.value)

				// Check if have creation proc
				if let creationProc = self.documentCreationProcMap.value(for: $0.key) {
					// Update collections and indexes
					let	updateInfos :[MDSUpdateInfo<Int64>] =
								$0.value.map() {
									MDSUpdateInfo<Int64>(document: creationProc($0.documentID, self),
											revision: $0.documentBacking.revision, value: $0.documentBacking.id,
											changedProperties: nil)
								}
					updateCollections(for: $0.key, updateInfos: updateInfos, processNotIncluded: false)
					updateIndexes(for: $0.key, updateInfos: updateInfos)
				}
			}
		}

		return documentBackingMap
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func documentBacking(documentType :String, documentID :String) -> MDSSQLiteDocumentBacking? {
		// Try to retrieve stored document
		if let documentBacking = self.documentBackingCache.documentBacking(for: documentID) {
			// Have document
			return documentBacking
		} else {
			// Try to retrieve document backing
			var	documentBackingInfo :MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>?
			iterateDocumentBackingInfos(documentType: documentType, documentIDs: [documentID])
					{ documentBackingInfo = $0 }

			// Check results
			if documentBackingInfo != nil {
				// Update cache
				self.documentBackingCache.add([documentBackingInfo!])
			} else {
				// Not found
				self.logErrorMessageProc(
						"MDSSQLite - Cannot find document of type \(documentType) with documentID \(documentID)")
			}

			return documentBackingInfo?.documentBacking
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateDocumentBackingInfos(documentTables :MDSSQLiteCore.DocumentTables,
			innerJoin :SQLiteInnerJoin? = nil, where sqliteWhere :SQLiteWhere? = nil,
			proc :(_ resultsRow :SQLiteResultsRow,
					_ documentBackingInfo :MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Retrieve and iterate
		try! documentTables.infoTable.select(innerJoin: innerJoin, where: sqliteWhere) {
			// Retrieve info
			let	(id, documentRevisionInfo, _) = MDSSQLiteCore.info(infoTable: documentTables.infoTable, resultsRow: $0)

			// Try to retrieve document backing
			let	documentBackingInfo :MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>
			if let documentBacking = self.documentBackingCache.documentBacking(for: documentRevisionInfo.documentID) {
				// Have document backing
				documentBackingInfo =
						MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>(documentID: documentRevisionInfo.documentID,
								documentBacking: documentBacking)
			} else {
				// Read
				documentBackingInfo =
						MDSSQLiteCore.documentBackingInfo(id: id, documentRevisionInfo: documentRevisionInfo,
								contentTable: documentTables.contentTable, resultsRow: $0)
			}

			// Note referenced
			self.documentBackingCache.add([documentBackingInfo])

			// Call proc
			proc($0, documentBackingInfo)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateDocumentBackingInfos(documentType :String, documentIDs :[String],
			proc :(_ documentBackingInfo :MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Setup
		let	documentTables = self.sqliteCore.documentTables(for: documentType)

		// Iterate
		iterateDocumentBackingInfos(documentTables: documentTables,
				innerJoin:
						SQLiteInnerJoin(documentTables.infoTable, tableColumn: documentTables.infoTable.idTableColumn,
								to: documentTables.contentTable),
				where: SQLiteWhere(tableColumn: documentTables.infoTable.documentIDTableColumn, values: documentIDs))
				{ proc($1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateDocumentBackingInfos(documentType :String, sinceRevision revision :Int,
			includeInactive :Bool,
			proc :(_ documentBackingInfo :MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Setup
		let	documentTables = self.sqliteCore.documentTables(for: documentType)
		let	sqliteWhereUse =
					includeInactive ?
							SQLiteWhere(tableColumn: documentTables.infoTable.revisionTableColumn, comparison: ">",
											value: revision) :
							SQLiteWhere(tableColumn: documentTables.infoTable.revisionTableColumn, comparison: ">",
											value: revision)
									.and(tableColumn: documentTables.infoTable.activeTableColumn, value: 1)

		// Iterate
		iterateDocumentBackingInfos(documentTables: documentTables,
				innerJoin:
						SQLiteInnerJoin(documentTables.infoTable, tableColumn: documentTables.infoTable.idTableColumn,
								to: documentTables.contentTable),
				where: sqliteWhereUse) { proc($1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateCollection(name :String,
			with proc :(_ documentBackingInfo :MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Bring up to date
		let	collection = autoreleasepool() { bringCollectionUpToDate(name: name) }
		let	documentType = collection.documentType

		// Setup
		let	documentTables = self.sqliteCore.documentTables(for: documentType)
		let	collectionContentsTable = self.sqliteCore.sqliteTable(forCollectionNamed: name)

		// Iterate
		iterateDocumentBackingInfos(documentTables: documentTables,
				innerJoin:
						SQLiteInnerJoin(documentTables.infoTable, tableColumn: documentTables.infoTable.idTableColumn,
										to: documentTables.contentTable)
								.and(documentTables.infoTable, tableColumn: documentTables.infoTable.idTableColumn,
										to: collectionContentsTable)) { proc($1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateCollections(for documentType :String, updateInfos :[MDSUpdateInfo<Int64>],
			processNotIncluded :Bool = true) {
		// Iterate all collections for this document type
		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update
			let	(includedIDs, notIncludedIDs, lastRevision) = $0.update(updateInfos)

			// Update
			self.sqliteCore.updateCollection(name: $0.name, includedIDs: includedIDs,
					notIncludedIDs: processNotIncluded ? notIncludedIDs : [], lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func bringCollectionUpToDate(name :String) -> MDSCollection {
		// Setup
		let	collection = self.collectionsByNameMap.value(for: name)!
		let	creationProc = self.documentCreationProcMap.value(for: collection.documentType)!

		// Collect infos
		var	bringUpToDateInfos = [MDSBringUpToDateInfo<Int64>]()
		iterateDocumentBackingInfos(documentType: collection.documentType, sinceRevision: collection.lastRevision,
				includeInactive: false) {
					// Append info
					bringUpToDateInfos.append(
							MDSBringUpToDateInfo<Int64>(document: creationProc($0.documentID, self),
									revision: $0.documentBacking.revision, value: $0.documentBacking.id))
				}

		// Bring up to date
		let	(includedIDs, notIncludedIDs, lastRevision) = collection.bringUpToDate(bringUpToDateInfos)

		// Update
		self.sqliteCore.updateCollection(name: name, includedIDs: includedIDs, notIncludedIDs: notIncludedIDs,
				lastRevision: lastRevision)

		return collection
	}

	//------------------------------------------------------------------------------------------------------------------
	private func removeFromCollections(for documentType :String, documentBackingIDs :[Int64]) {
		// Iterate all collections for this document type
		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update collection
			self.sqliteCore.updateCollection(name: $0.name, includedIDs: [], notIncludedIDs: documentBackingIDs,
					lastRevision: $0.lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateIndex(name :String, keys :[String],
			with proc
					:(_ key :String, _ documentBackingInfo :MDSDocumentBackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Bring up to date
		let	index = autoreleasepool() { bringIndexUpToDate(name: name) }
		let	documentType = index.documentType

		// Setup
		let	documentTables = self.sqliteCore.documentTables(for: documentType)
		let	indexContentsTable = self.sqliteCore.sqliteTable(forIndexNamed: name)

		// Iterate
		iterateDocumentBackingInfos(documentTables: documentTables,
				innerJoin:
					SQLiteInnerJoin(documentTables.infoTable, tableColumn: documentTables.infoTable.idTableColumn,
									to: documentTables.contentTable)
							.and(documentTables.infoTable, tableColumn: documentTables.infoTable.idTableColumn,
									to: indexContentsTable),
				where: SQLiteWhere(tableColumn: indexContentsTable.keyTableColumn, values: keys)) {
					// Setup
					let	key = MDSSQLiteCore.key(for: indexContentsTable, resultsRow: $0)

					// Call proc
					proc(key, $1)
				}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateIndexes(for documentType :String, updateInfos :[MDSUpdateInfo<Int64>]) {
		// Iterate all indexes for this document type
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update
			let	(keysInfos, lastRevision) = $0.update(updateInfos)

			// Update
			self.sqliteCore.updateIndex(name: $0.name, keysInfos: keysInfos, removedIDs: [], lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func bringIndexUpToDate(name :String) -> MDSIndex {
		// Setup
		let	index = self.indexesByNameMap.value(for: name)!
		let	creationProc = self.documentCreationProcMap.value(for: index.documentType)!

		// Collect infos
		var	bringUpToDateInfos = [MDSBringUpToDateInfo<Int64>]()
		iterateDocumentBackingInfos(documentType: index.documentType, sinceRevision: index.lastRevision,
				includeInactive: false) {
					// Append info
					bringUpToDateInfos.append(
							MDSBringUpToDateInfo<Int64>(document: creationProc($0.documentID, self),
									revision: $0.documentBacking.revision, value: $0.documentBacking.id))
				}

		// Bring up to date
		let	(keysInfos, lastRevision) = index.bringUpToDate(bringUpToDateInfos)

		// Update
		self.sqliteCore.updateIndex(name: name, keysInfos: keysInfos, removedIDs: [], lastRevision: lastRevision)

		return index
	}

	//------------------------------------------------------------------------------------------------------------------
	private func removeFromIndexes(for documentType :String, documentBackingIDs :[Int64]) {
		// Iterate all collections for this document type
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update collection
			self.sqliteCore.updateIndex(name: $0.name, keysInfos: [], removedIDs: documentBackingIDs,
					lastRevision: $0.lastRevision)
		}
	}
}
