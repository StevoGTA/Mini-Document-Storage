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

extension MDSSQLiteError : CustomStringConvertible, LocalizedError {

	// MARK: Properties
	public 	var	description :String { self.localizedDescription }
	public	var	errorDescription :String? {
						switch self {
							case .documentNotFound(let documentType, let documentID):
								return "MDSSQLite cannot find document of type \(documentType) with id \"\(documentID)\""
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSSQLite
public class MDSSQLite : MDSDocumentStorageServerHandler {

	// MARK: DocumentInfo
	struct DocumentInfo {

		// MARK: Properties
		let	documentType :String
		let	documentID :String
		let	creationDate :Date?
		let	modificationDate :Date?
		let	propertyMap :[String : Any]

		// Lifecycle methods
		//------------------------------------------------------------------------------------------------------------------
		init(documentType :String, documentID :String, creationDate :Date? = nil, modificationDate :Date? = nil,
				propertyMap :[String : Any]) {
			// Store
			self.documentType = documentType
			self.documentID = documentID
			self.creationDate = creationDate
			self.modificationDate = modificationDate
			self.propertyMap = propertyMap
		}
	}

	// MARK: Properties
	public	var	id :String = UUID().uuidString

			var	logErrorMessageProc :(_ errorMessage :String) -> Void = { _ in }

	private	let	databaseManager :MDSSQLiteDatabaseManager

	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<MDSSQLiteDocumentBacking>>()

	private	let	documentBackingCache = MDSDocumentBackingCache<MDSSQLiteDocumentBacking>()
	private	var	documentChangedProcsMap = LockingArrayDictionary</* Document Type */ String, MDSDocument.ChangedProc>()
	private	var	documentCreationProcMap = LockingDictionary<String, MDSDocument.CreationProc>()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, [String : Any]>()

	private	var	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	var	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()

	private	var	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	var	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(in folder :Folder, with name :String = "database") throws {
		// Setup database
		let database = try SQLiteDatabase(in: folder, with: name)

		// Setup database manager
		self.databaseManager = MDSSQLiteDatabaseManager(database: database)
	}

	// MARK: MDSDocumentStorage methods
	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) -> [String : String] {
		// Return dictionary
		return [String : String](keys){ self.databaseManager.string(for: $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ info :[String : String]) { info.forEach() { self.databaseManager.set($0.value, for: $0.key) } }

	//------------------------------------------------------------------------------------------------------------------
	public func remove(keys :[String]) { keys.forEach() { self.databaseManager.set(nil, for: $0) } }

	//------------------------------------------------------------------------------------------------------------------
	public func newDocument<T : MDSDocument>(creationProc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T)
			-> T {
		// Setup
		let	documentID = UUID().base64EncodedString

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			let	date = Date()
			_ = batchInfo.addDocument(documentType: T.documentType, documentID: documentID, creationDate: date,
					modificationDate: date)

			return creationProc(documentID, self)
		} else {
			// Will be creating document
			self.documentsBeingCreatedPropertyMapMap.set([:], for: documentID)

			// Create
			let	document = creationProc(documentID, self)

			// Remove property map
			let	propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID)!
			self.documentsBeingCreatedPropertyMapMap.remove(documentID)

			// Add document
			let	documentBacking =
						MDSSQLiteDocumentBacking(documentType: T.documentType, documentID: documentID,
								propertyMap: propertyMap, with: self.databaseManager)
			self.documentBackingCache.add(
					[MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(documentID: documentID,
							documentBacking: documentBacking)])

			// Update collections and indexes
			let	updateInfos :[MDSUpdateInfo<Int64>] =
						[MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
								value: documentBacking.id, changedProperties: nil)]
			updateCollections(for: T.documentType, updateInfos: updateInfos)
			updateIndexes(for: T.documentType, updateInfos: updateInfos)

			// Call document changed procs
			self.documentChangedProcsMap.values(for: T.documentType)?.forEach() { $0(document, .created) }

			return document
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) -> T? {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				batchInfo.documentInfo(for: documentID) != nil {
			// Have document in batch
			return T(id: documentID, documentStorage: self)
		} else if documentBacking(documentType: T.documentType, documentID: documentID) != nil {
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
				let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
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
				let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
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
				let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
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
	public func data(for property :String, in document :MDSDocument) -> Data? {
		// Retrieve Base64-encoded string
		guard let string = value(for: property, in: document) as? String else { return nil }

		return Data(base64Encoded: string)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for property :String, in document :MDSDocument) -> Date? {
		// Return date
		return Date(fromRFC3339Extended: value(for: property, in: document) as? String)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
		// Setup
		let	documentType = type(of: document).documentType
		let	documentID = document.id

		// Transform
		let	valueUse :Any?
		if let data = value as? Data {
			// Data
			valueUse = data.base64EncodedString()
		} else if let date = value as? Date {
			// Date
			valueUse = date.rfc3339Extended
		} else {
			// Everythng else
			valueUse = value
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.documentInfo(for: documentID) {
				// Have document in batch
				batchDocumentInfo.set(valueUse, for: property)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(documentType: documentType, documentID: documentID)!
				batchInfo.addDocument(documentType: documentType, documentID: documentID, reference: documentBacking,
								creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								valueProc: { documentBacking.value(for: $0) })
						.set(valueUse, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID) {
			// Being created
			propertyMap[property] = valueUse
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: documentID)
		} else {
			// Update document
			let	documentBacking = self.documentBacking(documentType: documentType, documentID: documentID)!
			documentBacking.set(valueUse, for: property, documentType: documentType, with: self.databaseManager)

			// Update collections and indexes
			let	updateInfos :[MDSUpdateInfo<Int64>] =
						[MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
								value: documentBacking.id, changedProperties: [property])]
			updateCollections(for: documentType, updateInfos: updateInfos)
			updateIndexes(for: documentType, updateInfos: updateInfos)

			// Call document changed procs
			self.documentChangedProcsMap.values(for: documentType)?.forEach() { $0(document, .updated) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(_ document :MDSDocument) {
		// Setup
		let	documentType = type(of: document).documentType
		let	documentID = document.id

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.documentInfo(for: documentID) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(documentType: documentType, documentID: documentID)!
				batchInfo.addDocument(documentType: documentType, documentID: documentID, reference: documentBacking,
						creationDate: Date(), modificationDate: Date())
					.remove()
			}
		} else {
			// Not in batch
			let	documentBacking = self.documentBacking(documentType: documentType, documentID: documentID)!

			// Remove from collections and indexes
			removeFromCollections(for: documentType, documentBackingIDs: [documentBacking.id])
			removeFromIndexes(for: documentType, documentBackingIDs: [documentBacking.id])

			// Remove
			self.databaseManager.remove(documentType: documentType, id: documentBacking.id)

			// Remove from cache
			self.documentBackingCache.remove([documentID])

			// Call document changed procs
			self.documentChangedProcsMap.values(for: documentType)?.forEach() { $0(document, .removed) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Collect document IDs
		var	documentIDs = [String]()
		autoreleasepool() {
			// Iterate document backing infos
			iterateDocumentBackingInfos(documentType: T.documentType,
					innerJoin: self.databaseManager.innerJoin(for: T.documentType),
					where: self.databaseManager.where(forDocumentActive: true))
					{ documentIDs.append($0.documentID); _ = $1 }
		}

		// Iterate document IDs
		autoreleasepool() { documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void) {
		// Iterate document backing infos to ensure they are in the cache
		autoreleasepool()
			{ iterateDocumentBackingInfos(documentType: T.documentType, documentIDs: documentIDs) { _ = $0 } }

		// Iterate document IDs
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
			self.databaseManager.batch() {
				// Iterate all document changes
				batchInfo.forEach() { documentType, batchDocumentInfosMap in
					// Setup
					let	updateBatchQueue =
								BatchQueue<MDSUpdateInfo<Int64>>() {
									// Update collections and indexes
									self.updateCollections(for: documentType, updateInfos: $0)
									self.updateIndexes(for: documentType, updateInfos: $0)
								}
					var	removedDocumentBackingIDs = [Int64]()

					// Update documents
					batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
						// Check removed
						if !batchDocumentInfo.removed {
							// Add/update document
							if let documentBacking = batchDocumentInfo.reference {
								// Update document
								documentBacking.update(documentType: documentType,
										updatedPropertyMap: batchDocumentInfo.updatedPropertyMap,
										removedProperties: batchDocumentInfo.removedProperties,
										with: self.databaseManager)

								// Check if we have creation proc
								if let creationProc = self.documentCreationProcMap.value(for: documentType) {
									// Create document
									let	document = creationProc(documentID, self)

									// Update collections and indexes
									let	changedProperties =
												Set<String>((batchDocumentInfo.updatedPropertyMap ?? [:]).keys)
														.union(batchDocumentInfo.removedProperties ?? Set<String>())
									updateBatchQueue.add(
											MDSUpdateInfo<Int64>(document: document,
													revision: documentBacking.revision, value: documentBacking.id,
													changedProperties: changedProperties))

									// Call document changed procs
									self.documentChangedProcsMap.values(for: documentType)?.forEach()
										{ $0(document, .updated) }
								}
							} else {
								// Add document
								let	documentBacking =
											MDSSQLiteDocumentBacking(documentType: documentType, documentID: documentID,
													creationDate: batchDocumentInfo.creationDate,
													modificationDate: batchDocumentInfo.modificationDate,
													propertyMap: batchDocumentInfo.updatedPropertyMap ?? [:],
													with: self.databaseManager)
								self.documentBackingCache.add(
										[MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(documentID: documentID,
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
									self.documentChangedProcsMap.values(for: documentType)?.forEach()
										{ $0(document, .created) }
								}
							}
						} else if let documentBacking = batchDocumentInfo.reference {
							// Remove document
							self.databaseManager.remove(documentType: documentType, id: documentBacking.id)
							self.documentBackingCache.remove([documentID])

							// Remove from collections and indexes
							removedDocumentBackingIDs.append(documentBacking.id)

							// Check if we have creation proc
							if let creationProc = self.documentCreationProcMap.value(for: documentType) {
								// Create document
								let	document = creationProc(documentID, self)

								// Call document changed procs
								self.documentChangedProcsMap.values(for: documentType)?.forEach()
									{ $0(document, .removed) }
							}
						}
					}

					// Finalize updates
					updateBatchQueue.finalize()
					self.removeFromCollections(for: documentType, documentBackingIDs: removedDocumentBackingIDs)
					self.removeFromIndexes(for: documentType, documentBackingIDs: removedDocumentBackingIDs)
				}
			}
		}

		// Remove - must wait to do this until the batch has been fully processed in case processing Collections and
		//	Indexes ends up referencing other documents that have not yet been committed.
		self.batchInfoMap.set(nil, for: Thread.current)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerAssociation(named name :String, fromDocumentType :String, toDocumentType :String) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func updateAssociation<T : MDSDocument, U : MDSDocument>(for name :String,
			updates :[(action :MDSAssociationAction, fromDocument :T, toDocument :U)]) {
		// Unimplemented
		fatalError("Unimplemented")
	}

//	//------------------------------------------------------------------------------------------------------------------
//	public func iterateAssociation<T : MDSDocument, U : MDSDocument>(for name :String, from document :T,
//			proc :(_ document :U) -> Void) {
//		// Unimplemented
//		fatalError("Unimplemented")
//	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateAssociation<T : MDSDocument, U : MDSDocument>(for name :String, to document :U,
			proc :(_ document :T) -> Void) {
		// Unimplemented
		fatalError("Unimplemented")
	}

//	//------------------------------------------------------------------------------------------------------------------
//	public func retrieveAssociationValue<T : MDSDocument, U>(for name :String, to document :T,
//			summedFromCachedValueWithName cachedValueName :String) -> U {
//		// Unimplemented
//		fatalError("Unimplemented")
//	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerCache<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			valuesInfos :[(name :String, valueType :MDSValueType, selector :String, proc :(_ document :T) -> Any)]) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerCollection<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
			isIncludedProc :@escaping (_ document :T) -> Bool) {
		// Ensure this collection has not already been registered
		guard self.collectionsByNameMap.value(for: name) == nil else { return }

		// Note this document type
		self.databaseManager.note(documentType: T.documentType)

		// Register collection
		let	lastRevision =
					self.databaseManager.registerCollection(documentType: T.documentType, name: name, version: version,
							isUpToDate: isUpToDate)

		// Create collection
		let	collection =
					MDSCollectionSpecialized(name: name, relevantProperties: relevantProperties,
							lastRevision: lastRevision, isIncludedProc: isIncludedProc)

		// Add to maps
		self.collectionsByNameMap.set(collection, for: name)
		self.collectionsByDocumentTypeMap.append(collection, for: T.documentType)

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCountForCollection(named name :String) -> Int {
		// Run lean
		autoreleasepool() { _ = bringCollectionUpToDate(name: name) }

		return self.databaseManager.documentCountForCollection(named: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// Collect document IDs
		var	documentIDs = [String]()
		autoreleasepool() { iterateCollection(name: name, with: { documentIDs.append($0.documentID) }) }

		// Iterate document IDs
		autoreleasepool() { documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any],
			keysProc :@escaping (_ document :T) -> [String]) {
		// Ensure this index has not already been registered
		guard self.indexesByNameMap.value(for: name) == nil else { return }

		// Note this document type
		self.databaseManager.note(documentType: T.documentType)

		// Register index
		let	lastRevision =
					self.databaseManager.registerIndex(documentType: T.documentType, name: name, version: version,
							isUpToDate: isUpToDate)

		// Create index
		let	index =
					MDSIndexSpecialized(name: name, relevantProperties: relevantProperties, lastRevision: lastRevision,
							keysProc: keysProc)

		// Add to maps
		self.indexesByNameMap.set(index, for: name)
		self.indexesByDocumentTypeMap.append(index, for: T.documentType)

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateIndex<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
		// Compose map
		var	documentIDMap = [/* Key */ String : /* String */ String]()
		autoreleasepool() { iterateIndex(name: name, keys: keys, with: { documentIDMap[$0] = $1.documentID }) }

		// Iterate map
		autoreleasepool() { documentIDMap.forEach() { proc($0.key, T(id: $0.value, documentStorage: self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerDocumentChangedProc(documentType :String, proc :@escaping MDSDocument.ChangedProc) {
		//  Add
		self.documentChangedProcsMap.append(proc, for: documentType)
	}

	// MARK: MDSDocumentStorageServerHandler methods
	//------------------------------------------------------------------------------------------------------------------
	func newDocuments(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo]) {
		// Batch
		self.databaseManager.batch() {
			// Setup
			let	batchQueue =
						BatchQueue<MDSUpdateInfo<Int64>>(maximumBatchSize: 999) {
							// Update collections and indexes
							self.updateCollections(for: documentType, updateInfos: $0)
							self.updateIndexes(for: documentType, updateInfos: $0)
						}

			// Iterate all infos
			documentCreateInfos.forEach() {
				// Add document
				let	documentBacking =
							MDSSQLiteDocumentBacking(documentType: documentType, documentID: $0.documentID,
									creationDate: $0.creationDate, modificationDate: $0.modificationDate,
									propertyMap: $0.propertyMap, with: self.databaseManager)
				self.documentBackingCache.add(
						[MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(documentID: $0.documentID,
								documentBacking: documentBacking)])

				// Check if we have creation proc
				if let creationProc = self.documentCreationProcMap.value(for: documentType) {
					// Create document
					let	document = creationProc($0.documentID, self)

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
			proc :(_ documentFullInfo :MDSDocument.FullInfo) -> Void) {
		// Iterate
		iterateDocumentBackingInfos(documentType: documentType, documentIDs: documentIDs) {
			// Call proc
			proc(MDSDocument.FullInfo(documentID: $0.documentID, revision: $0.documentBacking.revision,
					active: $0.documentBacking.active, creationDate: $0.documentBacking.creationDate,
					modificationDate: $0.documentBacking.modificationDate, propertyMap: $0.documentBacking.propertyMap))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :(_ documentFullInfo :MDSDocument.FullInfo) -> Void) {
		// Iterate
		iterateDocumentBackingInfos(documentType: documentType, sinceRevision: revision, includeInactive: true) {
			// Call proc
			proc(MDSDocument.FullInfo(documentID: $0.documentID, revision: $0.documentBacking.revision,
					active: $0.documentBacking.active, creationDate: $0.documentBacking.creationDate,
					modificationDate: $0.documentBacking.modificationDate, propertyMap: $0.documentBacking.propertyMap))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func updateDocuments(documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) {
		// Batch changes
		self.databaseManager.batch() {
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
							removedProperties: Set(documentUpdateInfo.removed), with: self.databaseManager)

					// Check if we have creation proc
					if let creationProc = self.documentCreationProcMap.value(for: documentType) {
						// Create document
						let	document = creationProc($0.documentID, self)

						// Update collections and indexes
						let	changedProperties =
									Set<String>(documentUpdateInfo.updated.keys).union(documentUpdateInfo.removed)
						updateBatchQueue.add(
								MDSUpdateInfo<Int64>(document: document,
										revision: $0.documentBacking.revision, value: $0.documentBacking.id,
										changedProperties: changedProperties))
					}
				} else {
					// Remove document
					self.databaseManager.remove(documentType: documentType, id: $0.documentBacking.id)
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
	func registerCollection(named name :String, documentType :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any]) ->
			(documentLastRevision: Int, collectionLastDocumentRevision: Int) {
		// Not implemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateCollection(name :String, proc :(_ documentRevisionInfo :MDSDocument.RevisionInfo) -> Void) {
		// Bring up to date
		let	collection = autoreleasepool() { bringCollectionUpToDate(name: name) }
		let	documentType = collection.documentType

		// Iterate
		self.databaseManager.iterateCollection(name: name, documentType: documentType) { proc($0.documentRevisionInfo) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerIndex(named name :String, documentType :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any]) ->
			(documentLastRevision: Int, collectionLastDocumentRevision: Int) {
		// Not implemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateIndex(name :String, keys :[String],
			proc :(_ key :String, _ documentRevisionInfo :MDSDocument.RevisionInfo) -> Void) {
		// Bring up to date
		let	index = autoreleasepool() { bringIndexUpToDate(name: name) }
		let	documentType = index.documentType

		// Iterate index
		self.databaseManager.iterateIndex(name: name, documentType: documentType, keys: keys)
				{ proc($0, $1.documentRevisionInfo) }
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	func documentBackingMap(for documentInfos :[DocumentInfo]) -> [String : MDSSQLiteDocumentBacking] {
		// Setup
		var	documentBackingMap = [String : MDSSQLiteDocumentBacking]()

		// Perform as batch and iterate all
		self.databaseManager.batch() {
			// Create document backings
			var	documentTypeMap = [/* Document type */ String : [MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>]]()
			documentInfos.forEach() {
				// Create document backing
				let	documentBacking =
							MDSSQLiteDocumentBacking(documentType: $0.documentType, documentID: $0.documentID,
									creationDate: $0.creationDate, modificationDate: $0.modificationDate,
									propertyMap: $0.propertyMap, with: self.databaseManager)

				// Add to maps
				documentBackingMap[$0.documentID] = documentBacking
				documentTypeMap.appendArrayValueElement(key: $0.documentType,
						value:
								MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(documentID: $0.documentID,
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
		// Try to retrieve from cache
		if let documentBacking = self.documentBackingCache.documentBacking(for: documentID) {
			// Have document
			return documentBacking
		} else {
			// Try to retrieve from database
			var	documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>?
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
	private func iterateDocumentBackingInfos(documentType :String, innerJoin :SQLiteInnerJoin? = nil,
			where sqliteWhere :SQLiteWhere? = nil,
			proc
					:(_ documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>,
							_ resultsRow :SQLiteResultsRow) -> Void) {
		// Iterate
		self.databaseManager.iterate(documentType: documentType, innerJoin: innerJoin, where: sqliteWhere) {
			// Try to retrieve document backing
			let	documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>
			if let documentBacking =
					self.documentBackingCache.documentBacking(for: $0.documentRevisionInfo.documentID) {
				// Have document backing
				documentBackingInfo =
						MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(documentID: $0.documentRevisionInfo.documentID,
								documentBacking: documentBacking)
			} else {
				// Read
				documentBackingInfo = MDSSQLiteDatabaseManager.documentBackingInfo(for: $0, resultsRow: $1)
			}

			// Note referenced
			self.documentBackingCache.add([documentBackingInfo])

			// Call proc
			proc(documentBackingInfo, $1)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateDocumentBackingInfos(documentType :String, documentIDs :[String],
			proc :(_ documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Iterate
		iterateDocumentBackingInfos(documentType: documentType,
				innerJoin: self.databaseManager.innerJoin(for: documentType),
				where: self.databaseManager.where(forDocumentIDs: documentIDs)) { proc($0); _ = $1 }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateDocumentBackingInfos(documentType :String, sinceRevision revision :Int,
			includeInactive :Bool,
			proc :(_ documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Iterate
		iterateDocumentBackingInfos(documentType: documentType,
				innerJoin: self.databaseManager.innerJoin(for: documentType),
				where:
						self.databaseManager.where(forDocumentRevision: revision, comparison: ">",
								includeInactive: includeInactive))
				{ proc($0); _ = $1 }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateCollection(name :String,
			with proc :(_ documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Bring up to date
		let	collection = autoreleasepool() { bringCollectionUpToDate(name: name) }

		// Iterate
		iterateDocumentBackingInfos(documentType: collection.documentType,
				innerJoin: self.databaseManager.innerJoin(for: collection.documentType, collectionName: name))
				{ proc($0); _ = $1 }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateCollections(for documentType :String, updateInfos :[MDSUpdateInfo<Int64>],
			processNotIncluded :Bool = true) {
		// Get collections
		guard let collections = self.collectionsByDocumentTypeMap.values(for: documentType) else { return }

		// Setup
		let	minRevision = updateInfos.min(by: { $0.revision < $1.revision })?.revision

		// Iterate collections
		collections.forEach() {
			// Check revision state
			if $0.lastRevision + 1 == minRevision {
				// Update collection
				let	(includedIDs, notIncludedIDs, lastRevision) = $0.update(updateInfos)

				// Update database
				self.databaseManager.updateCollection(name: $0.name, includedIDs: includedIDs,
						notIncludedIDs: processNotIncluded ? notIncludedIDs : [], lastRevision: lastRevision)
			} else {
				// Bring up to date
				bringUpToDate($0)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func bringCollectionUpToDate(name :String) -> MDSCollection {
		// Setup
		let	collection = self.collectionsByNameMap.value(for: name)!

		// Bring up to date
		bringUpToDate(collection)

		return collection
	}

	//------------------------------------------------------------------------------------------------------------------
	private func bringUpToDate(_ collection :MDSCollection) {
		// Setup
		let	creationProc = self.documentCreationProcMap.value(for: collection.documentType)!
		let	batchInfo = self.batchInfoMap.value(for: Thread.current)

		// Collect infos
		var	bringUpToDateInfos = [MDSBringUpToDateInfo<Int64>]()
		iterateDocumentBackingInfos(documentType: collection.documentType, sinceRevision: collection.lastRevision,
				includeInactive: false) {
					// Query batch info
					let batchDocumentInfo = batchInfo?.documentInfo(for: $0.documentID)

					// Ensure we want to process this document
					if (batchDocumentInfo == nil) || !batchDocumentInfo!.removed {
						// Append info
						bringUpToDateInfos.append(
								MDSBringUpToDateInfo<Int64>(document: creationProc($0.documentID, self),
										revision: $0.documentBacking.revision, value: $0.documentBacking.id))
					}
				}

		// Bring up to date
		let	(includedIDs, notIncludedIDs, lastRevision) = collection.bringUpToDate(bringUpToDateInfos)

		// Update database
		self.databaseManager.updateCollection(name: collection.name, includedIDs: includedIDs,
				notIncludedIDs: notIncludedIDs, lastRevision: lastRevision)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func removeFromCollections(for documentType :String, documentBackingIDs :[Int64]) {
		// Iterate all collections for this document type
		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update collection
			self.databaseManager.updateCollection(name: $0.name, includedIDs: [], notIncludedIDs: documentBackingIDs,
					lastRevision: $0.lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateIndex(name :String, keys :[String],
			with proc
					:(_ key :String,
							_ documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
		// Bring up to date
		let	index = autoreleasepool() { bringIndexUpToDate(name: name) }

		// Iterate
		iterateDocumentBackingInfos(documentType: index.documentType,
				innerJoin: self.databaseManager.innerJoin(for: index.documentType, indexName: name),
				where: self.databaseManager.where(forIndexKeys: keys))
				{ proc(MDSSQLiteDatabaseManager.indexContentsKey(for: $1), $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateIndexes(for documentType :String, updateInfos :[MDSUpdateInfo<Int64>]) {
		// Get indexes
		guard let indexes = self.indexesByDocumentTypeMap.values(for: documentType) else { return }

		// Setup
		let	minRevision = updateInfos.min(by: { $0.revision < $1.revision })?.revision

		// Iterate indexes
		indexes.forEach() {
			// Check revision state
			if $0.lastRevision + 1 == minRevision {
				// Update index
				let	(keysInfos, lastRevision) = $0.update(updateInfos)

				// Update database
				self.databaseManager.updateIndex(name: $0.name, keysInfos: keysInfos, removedIDs: [],
						lastRevision: lastRevision)
			} else {
				// Bring up to date
				bringUpToDate($0)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func bringIndexUpToDate(name :String) -> MDSIndex {
		// Setup
		let	index = self.indexesByNameMap.value(for: name)!

		// Bring up to date
		bringUpToDate(index)

		return index
	}

	//------------------------------------------------------------------------------------------------------------------
	private func bringUpToDate(_ index :MDSIndex) {
		// Setp
		let	creationProc = self.documentCreationProcMap.value(for: index.documentType)!
		let	batchInfo = self.batchInfoMap.value(for: Thread.current)

		// Collect infos
		var	bringUpToDateInfos = [MDSBringUpToDateInfo<Int64>]()
		iterateDocumentBackingInfos(documentType: index.documentType, sinceRevision: index.lastRevision,
				includeInactive: false) {
					// Query batch info
					let batchDocumentInfo = batchInfo?.documentInfo(for: $0.documentID)

					// Ensure we want to process this document
					if (batchDocumentInfo == nil) || !batchDocumentInfo!.removed {
						// Append info
						bringUpToDateInfos.append(
								MDSBringUpToDateInfo<Int64>(document: creationProc($0.documentID, self),
										revision: $0.documentBacking.revision, value: $0.documentBacking.id))
					}
				}

		// Bring up to date
		let	(keysInfos, lastRevision) = index.bringUpToDate(bringUpToDateInfos)

		// Update database
		self.databaseManager.updateIndex(name: index.name, keysInfos: keysInfos, removedIDs: [],
				lastRevision: lastRevision)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func removeFromIndexes(for documentType :String, documentBackingIDs :[Int64]) {
		// Iterate all indexes for this document type
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update index
			self.databaseManager.updateIndex(name: $0.name, keysInfos: [], removedIDs: documentBackingIDs,
					lastRevision: $0.lastRevision)
		}
	}
}
