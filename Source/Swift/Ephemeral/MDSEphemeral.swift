//
//  MDSEphemeral.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSEphemeral
public class MDSEphemeral : MDSDocumentStorageServerHandler {

	// MARK: Types
	class DocumentBacking {

		// MARK: Properties
		let	creationDate :Date

		var	revision :Int
		var	modificationDate :Date
		var	propertyMap :[String : Any]
		var	active :Bool

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(revision :Int, creationDate :Date, modificationDate :Date, propertyMap :[String : Any]) {
			// Store
			self.creationDate = creationDate

			self.revision = revision
			self.modificationDate = modificationDate
			self.propertyMap = propertyMap
			self.active = true
		}

		// MARK: Instance methods
		//--------------------------------------------------------------------------------------------------------------
		func update(revision :Int, updatedPropertyMap :[String : Any]? = nil, removedProperties :Set<String>? = nil) {
			// Update
			self.revision = revision

			self.propertyMap.merge(updatedPropertyMap ?? [:], uniquingKeysWith: { $1 })
			removedProperties?.forEach() { self.propertyMap[$0] = nil }
		}
	}

	// MARK: Properties
	public	let	id :String = UUID().uuidString

	private	var	info = [String : String]()

	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<[String : Any]>>()

	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, [String : Any]>()
	private	let	documentCreationProcMap = LockingDictionary<String, MDSDocument.CreationProc>()
	private	let	documentMapsLock = ReadPreferringReadWriteLock()
	private	var	documentBackingByIDMap = [/* Document ID */ String : DocumentBacking]()
	private	var	documentIDsByTypeMap = [/* Document Type */ String : /* Document IDs */ Set<String>]()
	private	var	documentLastRevisionMap = LockingDictionary</* Document type */ String, Int>()

	private	let	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	let	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()
	private	let	collectionValuesMap = LockingDictionary</* Name */ String, /* Document IDs */ Set<String>>()

	private	let	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	let	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()
	private	let	indexValuesMap = LockingDictionary</* Name */ String, [/* Key */ String : /* Document ID */ String]>()

	private	var	documentChangedProcsMap = LockingDictionary</* Document Type */ String, [MDSDocument.ChangedProc]>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init() {}

	// MARK: MDSDocumentStorage methods
	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) -> [String : String] { self.info.filter({ keys.contains($0.key) }) }

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ info :[String : String]) { self.info.merge(info, uniquingKeysWith: { $1 }) }

	//------------------------------------------------------------------------------------------------------------------
	public func remove(keys :[String]) { keys.forEach() { self.info[$0] = nil } }

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
			let	date = Date()
			let	documentBacking =
						DocumentBacking(revision: nextRevision(for: T.documentType), creationDate: date,
								modificationDate: date, propertyMap: propertyMap)
			self.documentMapsLock.write() {
				// Update maps
				self.documentBackingByIDMap[documentID] = documentBacking
				self.documentIDsByTypeMap.appendSetValueElement(key: T.documentType, value: documentID)
			}

			// Update collections and indexes
			let	updateInfos :[MDSUpdateInfo<String>] =
						[MDSUpdateInfo<String>(document: document, revision: documentBacking.revision,
								value: documentID, changedProperties: nil)]
			updateCollections(for: T.documentType, updateInfos: updateInfos)
			updateIndexes(for: T.documentType, updateInfos: updateInfos)

			// Call document changed procs
			self.documentChangedProcsMap.value(for: T.documentType)?.forEach() { $0(document, .created) }

			return document
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) -> T? { T(id: documentID, documentStorage: self) }

	//------------------------------------------------------------------------------------------------------------------
	public func creationDate(for document :MDSDocument) -> Date {
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
			return self.documentMapsLock.read() { self.documentBackingByIDMap[document.id]?.creationDate ?? Date() }
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
			return self.documentMapsLock.read() { self.documentBackingByIDMap[document.id]?.modificationDate ?? Date() }
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
			return self.documentMapsLock.read() { self.documentBackingByIDMap[document.id]?.propertyMap[property] }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for property :String, in document :MDSDocument) -> Date? {
		// Return date
		return value(for: property, in: document) as? Date
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.set(value, for: property)
			} else {
				// Don't have document in batch
				batchInfo.addDocument(documentType: documentType, documentID: document.id, reference: [:],
						creationDate: Date(), modificationDate: Date(), valueProc: { property in
									// Play nice with others
									self.documentMapsLock.read()
										{ self.documentBackingByIDMap[document.id]?.propertyMap[property] }
								})
						.set(value, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			propertyMap[property] = value
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: document.id)
		} else {
			// Update document
			var	documentBacking :DocumentBacking!
			self.documentMapsLock.write() {
				// Setup
				documentBacking = self.documentBackingByIDMap[document.id]!

				// Update
				documentBacking.propertyMap[property] = value
			}

			// Update collections and indexes
			let	updateInfos :[MDSUpdateInfo<String>] =
						[MDSUpdateInfo<String>(document: document, revision: documentBacking.revision,
								value: document.id, changedProperties: [property])]
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
				batchInfo.addDocument(documentType: documentType, documentID: document.id, reference: [:],
						creationDate: Date(), modificationDate: Date()).remove()
			}
		} else {
			// Not in batch
			self.documentMapsLock.write() { self.documentBackingByIDMap[document.id]?.active = false }

			// Remove from collections and indexes
			self.collectionValuesMap.keys.forEach() {
				// Remove document from this collection
				self.collectionValuesMap.update(for: $0) { $0?.removing(document.id) }
			}
			self.indexValuesMap.keys.forEach() {
				// Remove document from this index
				self.indexValuesMap.update(for: $0) { $0?.filter({ $0.value != document.id }) }
			}

			// Call document changed procs
			self.documentChangedProcsMap.value(for: documentType)?.forEach() { $0(document, .removed) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Collect document IDs
		let	documentIDs =
					self.documentMapsLock.read() {
						// Return ids filtered by active
						(self.documentIDsByTypeMap[T.documentType] ?? Set<String>())
								.filter({ self.documentBackingByIDMap[$0]!.active })
					}

		// Call proc on each storable document
		documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void) {
		// Iterate all
		documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Setup
		let	batchInfo = MDSBatchInfo<[String : Any]>()

		// Store
		self.batchInfoMap.set(batchInfo, for: Thread.current)

		// Call proc
		let	result = try proc()

		// Check result
		if result == .commit {
			// Iterate all document changes
			batchInfo.forEach() { documentType, batchDocumentInfosMap in
				// Setup
				var	updateInfos = [MDSUpdateInfo<String>]()

				// Update documents
				batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
					// Is removed?
					if !batchDocumentInfo.removed {
						// Add/update document
						self.documentMapsLock.write() {
							// Retrieve existing document
							if let documentBacking = self.documentBackingByIDMap[documentID] {
								// Update document backing
								documentBacking.update(revision: nextRevision(for: documentType),
										updatedPropertyMap: batchDocumentInfo.updatedPropertyMap,
										removedProperties: batchDocumentInfo.removedProperties)

								// Check if we have creation proc
								if let creationProc = self.documentCreationProcMap.value(for: documentType) {
									// Create document
									let	document = creationProc(documentID, self)

										// Update collections and indexes
									let	changedProperties =
												Array((batchDocumentInfo.updatedPropertyMap ?? [:]).keys) +
														Array(batchDocumentInfo.removedProperties ?? Set<String>())
									updateInfos.append(
											MDSUpdateInfo<String>(document: document,
													revision: documentBacking.revision, value: documentID,
													changedProperties: changedProperties))

									// Call document changed procs
									self.documentChangedProcsMap.value(for: documentType)?.forEach()
										{ $0(document, .updated) }
								}
							} else {
								// Add document
								let	documentBacking =
											DocumentBacking(revision: nextRevision(for: documentType),
													creationDate: batchDocumentInfo.creationDate,
													modificationDate: batchDocumentInfo.modificationDate,
													propertyMap: batchDocumentInfo.updatedPropertyMap ?? [:])
								self.documentBackingByIDMap[documentID] = documentBacking
								self.documentIDsByTypeMap.appendSetValueElement(key: batchDocumentInfo.documentType,
										value: documentID)

								// Check if we have creation proc
								if let creationProc = self.documentCreationProcMap.value(for: documentType) {
									// Create document
									let	document = creationProc(documentID, self)

									// Update collections and indexes
									updateInfos.append(
											MDSUpdateInfo<String>(document: document,
													revision: documentBacking.revision, value: documentID,
													changedProperties: nil))

									// Call document changed procs
									self.documentChangedProcsMap.value(for: documentType)?.forEach()
										{ $0(document, .created) }
								}
							}
						}
					} else {
						// Remove document
						self.documentMapsLock.write() {
							// Update maps
							self.documentBackingByIDMap[documentID]?.active = false

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
				}

				// Update collections and indexes
				updateCollections(for: documentType, updateInfos: updateInfos)
				updateIndexes(for: documentType, updateInfos: updateInfos)
			}
		}

		// Remove
		self.batchInfoMap.set(nil, for: Thread.current)
	}
	
	//------------------------------------------------------------------------------------------------------------------
	public func registerAssociation(named name :String, fromDocumentType :String, toDocumentType :String) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func addAssociation<T : MDSDocument, U : MDSDocument>(for name :String, from fromDocument :T,
			to toDocument :U) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func updateAssociation<T : MDSDocument, U : MDSDocument>(for name :String, from fromDocument :T,
			to toDocument :U) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func removeAssociation<T : MDSDocument, U : MDSDocument>(for name :String, from fromDocument :T,
			to toDocument :U) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateAssociations<T : MDSDocument, U : MDSDocument>(for name :String, from document :T,
			proc :(_ document :U) -> Void) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateAssociations<T : MDSDocument, U : MDSDocument>(for name :String, to document :U,
			proc :(_ document :T) -> Void) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func retrieveAssociationValue<T : MDSDocument, U>(for name :String, to document :T,
			summedFromCachedValueWithName cachedValueName :String) -> U {
		// Unimplemented
		fatalError("Unimplemented")
	}

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

		// Create collection
		let	collection =
					MDSCollectionSpecialized(name: name, relevantProperties: relevantProperties, lastRevision: 0,
							isIncludedProc: isIncludedProc)

		// Add to maps
		self.collectionsByNameMap.set(collection, for: name)
		self.collectionsByDocumentTypeMap.appendArrayValue(collection, for: T.documentType)

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func queryCollectionDocumentCount(name :String) -> Int {
		// Return count
		return (self.collectionValuesMap.value(for: name) ?? Set<String>()).count
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// Iterate
		self.collectionValuesMap.value(for: name)?.forEach() { proc(T(id: $0, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any],
			keysProc :@escaping (_ document :T) -> [String]) {
		// Ensure this index has not already been registered
		guard self.indexesByNameMap.value(for: name) == nil else { return }

		// Create index
		let	index =
					MDSIndexSpecialized(name: name, relevantProperties: relevantProperties, lastRevision: 0,
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
		// Setup
		guard let indexValues = self.indexValuesMap.value(for: name) else { return }

		// Play nice
		self.documentMapsLock.read() {
			// Iterate keys
			keys.forEach() {
				// Retrieve document
				guard let documentID = indexValues[$0] else { return }
				guard self.documentBackingByIDMap[documentID] != nil else { return }

				// Call proc
				proc($0, T(id: documentID, documentStorage: self))
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerDocumentChangedProc(documentType :String, proc :@escaping MDSDocument.ChangedProc) {
		//  Add
		self.documentChangedProcsMap.update(for: documentType) { ($0 ?? []) + [proc] }
	}

	// MARK: MDSDocumentStorageServerHandler methods
	//------------------------------------------------------------------------------------------------------------------
	func newDocuments(documentType :String, documentCreateInfos :[MDSDocumentCreateInfo]) {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterate(documentType :String, documentIDs :[String],
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void) {
		// Play nice
		self.documentMapsLock.read() {
			// Iterate
			documentIDs.forEach() {
				// Setup
				let	documentBacking = self.documentBackingByIDMap[$0]!

				// Call proc
				proc(
						MDSDocumentFullInfo(documentID: $0, revision: documentBacking.revision,
								active: documentBacking.active, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								propertyMap: documentBacking.propertyMap))
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void) {
		// Play nice
		self.documentMapsLock.read() {
			// Iterate
			self.documentIDsByTypeMap[documentType]?.forEach() {
				// Retrieve info
				if let documentBacking = self.documentBackingByIDMap[$0], documentBacking.revision > revision {
					// Call proc
					proc(
							MDSDocumentFullInfo(documentID: $0, revision: documentBacking.revision,
									active: documentBacking.active, creationDate: documentBacking.creationDate,
									modificationDate: documentBacking.modificationDate,
									propertyMap: documentBacking.propertyMap))
				}
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func updateDocuments(documentType :String, documentUpdateInfos :[MDSDocumentUpdateInfo]) {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection(named name :String, documentType :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any]) ->
			(documentLastRevision: Int, collectionLastDocumentRevision: Int) {
		// Not implemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateCollection(name :String, proc :@escaping (_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void) {
		// Retrieve collection
		guard let collection = self.collectionValuesMap.value(for: name) else { return }

		// Play nice
		self.documentMapsLock.read() {
			// Iterate all documents in collection
			collection.forEach() {
				// Call proc
				proc(MDSDocumentRevisionInfo(documentID: $0, revision: self.documentBackingByIDMap[$0]!.revision))
			}
		}
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
			proc :@escaping (_ key :String, _ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void) {
		// Iterate
		guard let indexValues = self.indexValuesMap.value(for: name) else { return }

		// Play nice
		self.documentMapsLock.read() {
			// Iterate keys
			keys.forEach() {
				// Retrieve document
				guard let documentID = indexValues[$0] else { return }
				guard let documentBacking = self.documentBackingByIDMap[documentID] else { return }

				// Call proc
				proc($0, MDSDocumentRevisionInfo(documentID: documentID, revision: documentBacking.revision))
			}
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func nextRevision(for documentType :String) -> Int {
		// Compose next revision
		let	nextRevision = (self.documentLastRevisionMap.value(for: documentType) ?? 0) + 1

		// Store
		self.documentLastRevisionMap.set(nextRevision, for: documentType)

		return nextRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateCollections(for documentType :String, updateInfos :[MDSUpdateInfo<String>],
			processNotIncluded :Bool = true) {
		// Iterate all collections for this document type
		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Query update info
			let	(includedIDs, notIncludedIDs, _) = $0.update(updateInfos)

			// Update storage
			self.collectionValuesMap.update(for: $0.name)
				{ ($0 ?? Set<String>()).subtracting(notIncludedIDs).union(includedIDs) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateIndexes(for documentType :String, updateInfos :[MDSUpdateInfo<String>]) {
		// Iterate all indexes for this document type
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Query update info
			let	(keysInfos, _) = $0.update(updateInfos)
			guard !keysInfos.isEmpty else { return }

			// Update storage
			let	documentIDs = Set<String>(keysInfos.map({ $0.value }))
			self.indexValuesMap.update(for: $0.name) {
				// Filter out document IDs included in update
				var	updatedValues = ($0 ?? [:]).filter({ !documentIDs.contains($0.value) })

				// Add/Update keys => document IDs
				keysInfos.forEach() { keys, value in keys.forEach() { updatedValues[$0] = value } }

				return updatedValues
			}
		}
	}
}
