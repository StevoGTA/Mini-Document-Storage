//
//  MDSSQLite.swift
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

/*
	// TODOs:
		-Document backing cache needs to be make more performant
		-Updating collections as we go ends up with SQLite calls updating the last revision for every document
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
public class MDSSQLite : MDSDocumentStorage {

	// MARK: MDSDocumentStorage implementation
	public var id: String = UUID().uuidString

	//------------------------------------------------------------------------------------------------------------------
	public func extraValue<T>(for key :String) -> T? { return self.extraValues?[key] as? T }

	//------------------------------------------------------------------------------------------------------------------
	public func store<T>(extraValue :T?, for key :String) {
		// Store
		if (self.extraValues == nil) && (extraValue != nil) {
			// First one
			self.extraValues = [key : extraValue!]
		} else {
			// Update
			self.extraValues?[key] = extraValue

			// Check for empty
			if self.extraValues?.isEmpty ?? false {
				// No more values
				self.extraValues = nil
			}
		}
	}

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
			self.documentsBeingCreatedPropertyMapMap.set(MDSSQLiteDocumentBacking.PropertyMap(), for: documentID)

			// Create
			let	document = creationProc(documentID, self)

			// Remove property map
			let	propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID)!
			self.documentsBeingCreatedPropertyMapMap.remove([documentID])

			// Add document
			let	documentBacking =
						MDSSQLiteDocumentBacking(documentID: documentID, documentType: T.documentType,
								propertyMap: propertyMap, with: self.sqliteCore)
			self.documentBackingCache.add([(documentID: documentID, documentBacking: documentBacking)])

			// Update collections and indexes
			let	documentUpdateInfos :[DocumentUpdateInfo] = [(document, documentBacking, nil)]
			updateCollections(for: T.documentType, documentUpdateInfos: documentUpdateInfos)
			updateIndexes(for: T.documentType, documentUpdateInfos: documentUpdateInfos)

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
			// Not in batch
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
			// Not in batch
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
			// Not in batch
			return documentBacking(documentType: type(of: document).documentType, documentID: document.id)?
					.value(for: property)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for property :String, in document :MDSDocument) -> Date? {
		// Return date
		return Date(fromStandardized: value(for: property, in: document) as? String)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
		// Setup
		let	documentType = type(of: document).documentType

		// Transform
		let	valueUse :Any?
		if let date = value as? Date {
			// Date
			valueUse = date.standardized
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
				let	documentBacking = self.documentBacking(documentType: documentType, documentID: document.id)
				batchInfo.addDocument(documentType: documentType, documentID: document.id, reference: documentBacking,
								creationDate: Date(), modificationDate: Date(),
								valueProc: { return documentBacking?.value(for: $0) })
						.set(valueUse, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			propertyMap[property] = valueUse
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: document.id)
		} else if let documentBacking = self.documentBacking(documentType: documentType, documentID: document.id) {
			// Update document
			documentBacking.set(valueUse, for: property, documentType: documentType, with: self.sqliteCore)

			// Update collections and indexes
			let	documentUpdateInfos :[DocumentUpdateInfo] = [(document, documentBacking, [property])]
			updateCollections(for: documentType, documentUpdateInfos: documentUpdateInfos)
			updateIndexes(for: documentType, documentUpdateInfos: documentUpdateInfos)
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
				let	documentBacking = self.documentBacking(documentType: documentType, documentID: document.id)
				batchInfo.addDocument(documentType: documentType, documentID: document.id, reference: documentBacking,
						creationDate: Date(), modificationDate: Date()).remove()
			}
		} else {
			// Not in batch
			if let documentBacking =
					self.documentBacking(documentType: documentType, documentID: document.id) {
				// Remove from collections and indexes
				removeFromCollections(for: documentType, documentBackingIDs: [documentBacking.id])
				removeFromIndexes(for: documentType, documentBackingIDs: [documentBacking.id])

				// Remove
				documentBacking.remove(documentType: documentType, with: self.sqliteCore)
			}

			// Remove from cache
			self.documentBackingCache.remove([document.id])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Setup
		let	infos = MDSSQLiteDocumentBacking.infos(for: T.documentType, with: self.sqliteCore)
		guard !infos.isEmpty else { return }

		// Compose map of documentIDs to infos
		var	map = [/* Document ID */ String : MDSSQLiteDocumentBacking.Info]()
		infos.forEach() { map[$0.documentID] = $0 }

		// Collate documentIDs
		let (foundDocumentIDs, notFoundDocumentIDs) = self.documentBackingCache.query(Array(map.keys))

		// Call proc on all documentIDs already in cache
		foundDocumentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }

		// Check for not found document IDs
		if !notFoundDocumentIDs.isEmpty {
			// Retrieve document backings
			let	notFoundInfos = infos.filter() { notFoundDocumentIDs.contains($0.documentID) }
			let	documentInfos =
						MDSSQLiteDocumentBacking.documentInfos(for: notFoundInfos, of: T.documentType,
								with: self.sqliteCore)

			// Update cache
			self.documentBackingCache.add(documentInfos)

			// Call proc on all documentIDs that needed to be retrieved
			notFoundDocumentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void) {
		// Process those in batch first
		var	nonBatchDocumentIDs = [String]()
		documentIDs.forEach() {
			// Check for batch
			if let batchInfo = self.batchInfoMap.value(for: Thread.current),
					batchInfo.batchDocumentInfo(for: $0) != nil {
				// Have document in batch
				proc(T(id: $0, documentStorage: self))
			} else {
				// Document is not in the batch
				nonBatchDocumentIDs.append($0)
			}
		}

		// Collate documentIDs
		let (foundDocumentIDs, notFoundDocumentIDs) = self.documentBackingCache.query(nonBatchDocumentIDs)

		// Call proc on all documentIDs already in cache
		foundDocumentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }

		// Check for not found document IDs
		if !notFoundDocumentIDs.isEmpty {
			// Retrieve document backings
			let	documentInfos =
						MDSSQLiteDocumentBacking.documentInfos(for: Array(notFoundDocumentIDs), of: T.documentType,
								with: self.sqliteCore)

			// Update cache
			self.documentBackingCache.add(documentInfos)

			// Call proc on all documentIDs that needed to be retrieved
			notFoundDocumentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Setup
		let	batchInfo = MDSBatchInfo<MDSSQLiteDocumentBacking>()

		// Store
		self.batchInfoMap.set(batchInfo, for: Thread.current)

		// Call proc
		let	result = try proc()

		// Check result
		if result == .commit {
			// Batch changes
			self.sqliteCore.batch() {
				// Iterate all document changes
				batchInfo.forEach() { documentType, batchDocumentInfosMap in
					// Setup
					let	updateBatchQueue =
								BatchQueue<DocumentUpdateInfo>(maximumBatchSize: 999) {
									// Update collections and indexes
									self.updateCollections(for: documentType, documentUpdateInfos: $0)
									self.updateIndexes(for: documentType, documentUpdateInfos: $0)
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
							// Update document
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
									updateBatchQueue.add((document, documentBacking, changedProperties))
								}
							} else {
								// Add document
								let	documentBacking =
											MDSSQLiteDocumentBacking(documentID: documentID, documentType: documentType,
													creationDate: batchDocumentInfo.creationDate,
													modificationDate: batchDocumentInfo.modificationDate,
													propertyMap: batchDocumentInfo.updatedPropertyMap ?? [:],
													with: self.sqliteCore)
								self.documentBackingCache.add(
										[(documentID: documentID, documentBacking: documentBacking)])

								// Check if we have creation proc
								if let creationProc = self.documentCreationProcMap.value(for: documentType) {
									// Create document
									let	document = creationProc(documentID, self)

									// Update collections and indexes
									updateBatchQueue.add((document, documentBacking, nil))
								}
							}
						} else if let documentBacking = batchDocumentInfo.reference {
							// Remove document
							documentBacking.remove(documentType: documentType, with: self.sqliteCore)
							self.documentBackingCache.remove([documentID])

							// Remove from collections and indexes
							removedBatchQueue.add(documentBacking.id)
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
			info :[String : Any], isUpToDate :Bool, includeSelector :String,
			includeProc :@escaping (_ document :T, _ info :[String : Any]) -> Bool) {
		// Ensure we have the document tables
		_ = self.sqliteCore.documentTables(for: T.documentType)

		// Register collection
		let	lastRevision =
					self.sqliteCore.registerCollection(documentType: T.documentType, name: name, version: version,
							info: info, isUpToDate: isUpToDate)

		// Create collection
		let	collection =
					MDSCollectionSpecialized(name: name, relevantProperties: relevantProperties,
							lastRevision: lastRevision, includeProc: includeProc, info: info)

		// Add to maps
		self.collectionsByNameMap.set(collection, for: name)
		self.collectionsByDocumentTypeMap.appendArrayValue(collection, for: T.documentType)

		// Update creation proc map
		self.documentCreationProcMap.set({ return T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func queryCollectionDocumentCount(name :String) -> UInt {
		// Bring up to date
		bringCollectionUpToDate(name: name)

		return self.sqliteCore.queryCollectionDocumentCount(name: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// Bring up to date
		bringCollectionUpToDate(name: name)

		// Collect document infos
		let	(infoTable, _) = self.sqliteCore.documentTables(for: T.documentType)
		let	collectionContentsTable = self.sqliteCore.sqliteTable(forCollectionNamed: name)
		let	documentInfos =
					MDSSQLiteDocumentBacking.documentInfos(of: T.documentType, with: self.sqliteCore,
							sqliteInnerJoin:
									SQLiteInnerJoin(infoTable, tableColumn: infoTable.idTableColumn,
											to: collectionContentsTable))

		// Enumerate
		documentInfos.forEach() { proc(T(id: $0.documentID, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping (_ document :T) -> [String]) {
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
		self.documentCreationProcMap.set({ return T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerateIndex<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
		// Bring up to date
		bringIndexUpToDate(name: name)

		// Collect document infos
		let	(infoTable, _) = self.sqliteCore.documentTables(for: T.documentType)
		let	indexContentsTable = self.sqliteCore.sqliteTable(forIndexNamed: name)
		let	documentInfoMap =
					MDSSQLiteDocumentBacking.documentInfoMap(of: T.documentType, with: self.sqliteCore,
							keyTableColumn: indexContentsTable.keyTableColumn,
							sqliteInnerJoin:
									SQLiteInnerJoin(infoTable, tableColumn: infoTable.idTableColumn,
											to: indexContentsTable),
							where:
									SQLiteWhere(table: indexContentsTable,
											tableColumn: indexContentsTable.keyTableColumn, values: keys))

		// Enumerate
		documentInfoMap.forEach() { proc($0.key, T(id: $0.value.documentID, documentStorage: self)) }
	}

	// MARK: Types
	typealias DocumentUpdateInfo =
				(document :MDSDocument, documentBacking :MDSSQLiteDocumentBacking, changedProperties :[String]?)

	// MARK: Properties
			var	logErrorMessageProc :(_ errorMessage :String) -> Void = { _ in }

	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<MDSSQLiteDocumentBacking>>()
	private	let	documentBackingCache = MDSDocumentBackingCache<MDSSQLiteDocumentBacking>()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, MDSSQLiteDocumentBacking.PropertyMap>()
	private	let	sqliteCore :MDSSQLiteCore

	private	var	extraValues :[/* Key */ String : Any]?

	private	var	documentCreationProcMap =
						LockingDictionary<String,
								(_ id :String, _ documentStorage :MDSDocumentStorage) -> MDSDocument>()

	private	var	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	var	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()

	private	var	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	var	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()

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

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	func documentBacking(documentID :String, documentType :String, creationDate :Date? = nil,
			modificationDate :Date? = nil, propertyMap :MDSSQLiteDocumentBacking.PropertyMap) ->
			MDSSQLiteDocumentBacking {
		// Craete document
		let	documentBacking =
					MDSSQLiteDocumentBacking(documentID: documentID, documentType: documentType,
							creationDate: creationDate, modificationDate: modificationDate, propertyMap: propertyMap,
							with: self.sqliteCore)

		// Check if we have creation proc
		if let creationProc = self.documentCreationProcMap.value(for: documentType) {
			// Create document
			let	document = creationProc(documentID, self)

			// Update collections and indexes
			let	documentUpdateInfos :[DocumentUpdateInfo] = [(document, documentBacking, nil)]
			updateCollections(for: documentType, documentUpdateInfos: documentUpdateInfos)
			updateIndexes(for: documentType, documentUpdateInfos: documentUpdateInfos)
		}

		return documentBacking
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func documentBacking(documentType :String, documentID :String) -> MDSSQLiteDocumentBacking? {
		// Try to retrieve stored document
		if let documentBacking = self.documentBackingCache.documentBacking(for: documentID) {
			// Have document
			return documentBacking
		} else if let documentBacking =
				MDSSQLiteDocumentBacking.documentInfos(for: [documentID], of: documentType, with: self.sqliteCore)
						.first?.documentBacking {
			// Update map
			self.documentBackingCache.add([(documentID: documentID, documentBacking: documentBacking)])

			return documentBacking
		} else {
			// Doesn't exist
			self.logErrorMessageProc(
					"MDSSQLite - Cannot find document of type \(documentType) with documentID \(documentID)")

			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateCollections(for documentType :String, documentUpdateInfos :[DocumentUpdateInfo]) {
		// Setup
		let	collectionUpdateDocumentInfos =
					documentUpdateInfos.map({ ($0.document, $0.documentBacking.revision, $0.documentBacking.id,
							$0.changedProperties) })

		// Iterate all collections for this document type
		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update
			let	(includedIDs, notIncludedIDs, lastRevision) = $0.update(collectionUpdateDocumentInfos)

			// Update
			self.sqliteCore.updateCollection(name: $0.name, includedIDs: includedIDs, notIncludedIDs: notIncludedIDs,
					lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func bringCollectionUpToDate(name :String) {
		// Setup
		let	collection = self.collectionsByNameMap.value(for: name)!
		let	creationProc = self.documentCreationProcMap.value(for: collection.documentType)!

		// Collect document infos
		let	documentBackingDocumentInfos =
					MDSSQLiteDocumentBacking.documentInfos(since: collection.lastRevision, of: collection.documentType,
							with: self.sqliteCore)
		guard !documentBackingDocumentInfos.isEmpty else { return }

		let	collectionDocumentInfos =
					documentBackingDocumentInfos.map(
							{ (creationProc($0.documentID, self), $0.documentBacking.revision, $0.documentBacking.id) })

		// Bring up to date
		let	(includedIDs, notIncludedIDs, lastRevision) = collection.bringUpToDate(collectionDocumentInfos)

		// Update
		self.sqliteCore.updateCollection(name: name, includedIDs: includedIDs, notIncludedIDs: notIncludedIDs,
				lastRevision: lastRevision)
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
	private func updateIndexes(for documentType :String, documentUpdateInfos :[DocumentUpdateInfo]) {
		// Setup
		let	indexUpdateDocumentInfos =
					documentUpdateInfos.map({ ($0.document, $0.documentBacking.revision, $0.documentBacking.id,
							$0.changedProperties) })

		// Iterate all indexes for this document type
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update
			let	(keysInfos, lastRevision) = $0.update(indexUpdateDocumentInfos)

			// Update
			self.sqliteCore.updateIndex(name: $0.name, keysInfos: keysInfos, removedIDs: [], lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func bringIndexUpToDate(name :String) {
		// Setup
		let	index = self.indexesByNameMap.value(for: name)!
		let	creationProc = self.documentCreationProcMap.value(for: index.documentType)!

		// Collect document infos
		let	documentBackingDocumentInfos =
					MDSSQLiteDocumentBacking.documentInfos(since: index.lastRevision, of: index.documentType,
							with: self.sqliteCore)
		guard !documentBackingDocumentInfos.isEmpty else { return }

		let	indexDocumentInfos =
					documentBackingDocumentInfos.map(
							{ (creationProc($0.documentID, self), $0.documentBacking.revision, $0.documentBacking.id) })

		// Bring up to date
		let	(keysInfos, lastRevision) = index.bringUpToDate(indexDocumentInfos)

		// Update
		self.sqliteCore.updateIndex(name: name, keysInfos: keysInfos, removedIDs: [], lastRevision: lastRevision)
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
