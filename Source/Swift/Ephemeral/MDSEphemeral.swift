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
public class MDSEphemeral : MDSDocumentStorage {

	// MARK: Types
	class DocumentBacking {

		// MARK: Properties
		let	creationDate :Date

		var	modificationDate :Date
		var	propertyMap :[String : Any]

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(creationDate :Date, modificationDate :Date, propertyMap :[String : Any]) {
			// Store
			self.creationDate = creationDate

			self.modificationDate = modificationDate
			self.propertyMap = propertyMap
		}

		// MARK: Instance methods
		//--------------------------------------------------------------------------------------------------------------
		func update(updatedPropertyMap :MDSDocument.PropertyMap? = nil, removedProperties :Set<String>? = nil) {
			// Update
			self.propertyMap.merge(updatedPropertyMap ?? [:], uniquingKeysWith: { $1 })
			removedProperties?.forEach() { self.propertyMap[$0] = nil }
		}
	}

	// MARK: Properties
	public	let	id :String = UUID().uuidString

	private	var	info = [String : String]()

	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<[String : Any]>>()

	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, MDSDocument.PropertyMap>()
	private	let	documentMapsLock = ReadPreferringReadWriteLock()
	private	let	documentCreationProcMap = LockingDictionary<String, MDSDocument.CreationProc>()
	private	var	documentBackingMap = [/* Document ID */ String : DocumentBacking]()
	private	var	documentTypeMap = [/* Document Type */ String : Set<String>]()

	private	let	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	let	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()
	private	let	collectionValuesMap = LockingDictionary</* Name */ String, /* Document IDs */ Set<String>>()

	private	let	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	let	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()
	private	let	indexValuesMap = LockingDictionary</* Name */ String, [/* Key */ String : /* Document ID */ String]>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init() {}

	// MARK: MDSDocumentStorage implementation
	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) -> [String : String] {
		// Setup
		var	info = [String : String]()

		// Iterate keys
		keys.forEach() { info[$0] = self.info[$0] }

		return info
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ info :[String : String]) {
		// Merge
		self.info.merge(info, uniquingKeysWith: { $1 })
	}

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
			self.documentsBeingCreatedPropertyMapMap.set(MDSDocument.PropertyMap(), for: documentID)

			// Create
			let	document = creationProc(documentID, self)

			// Remove property map
			let	propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID)!
			self.documentsBeingCreatedPropertyMapMap.remove(documentID)

			// Add document
			let	date = Date()
			self.documentMapsLock.write() {
				// Update maps
				self.documentTypeMap.appendSetValueElement(key: T.documentType, value: documentID)
				self.documentBackingMap[documentID] =
						DocumentBacking(creationDate: date, modificationDate: date, propertyMap: propertyMap)
			}

			// Update collections and indexes
			let	updateInfos :[MDSUpdateInfo<String>] =
						[MDSUpdateInfo<String>(document: document, revision: 1, value: documentID,
								changedProperties: nil)]
			updateCollections(for: T.documentType, updateInfos: updateInfos)
			updateIndexes(for: T.documentType, updateInfos: updateInfos)

			return document
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) -> T? {
		// Call proc
		return T(id: documentID, documentStorage: self)
	}

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
			return Date()
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
			return Date()
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
			return self.documentMapsLock.read() { return self.documentBackingMap[document.id]?.propertyMap[property] }
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
										{ return self.documentBackingMap[document.id]?.propertyMap[property] }
								})
						.set(value, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			propertyMap[property] = value
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: document.id)
		} else {
			// Update document
			self.documentMapsLock.write() { self.documentBackingMap[document.id]?.propertyMap[property] = value }

			// Update collections and indexes
			let	updateInfos :[MDSUpdateInfo<String>] =
						[MDSUpdateInfo<String>(document: document, revision: 1, value: document.id,
								changedProperties: [property])]
			updateCollections(for: documentType, updateInfos: updateInfos)
			updateIndexes(for: documentType, updateInfos: updateInfos)
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
			self.documentMapsLock.write() {
				// Update maps
				self.documentBackingMap[document.id] = nil
				self.documentTypeMap.removeSetValueElement(key: documentType, value: document.id)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Collect document IDs
		let	documentIDs = self.documentMapsLock.read() { return self.documentTypeMap[T.documentType] ?? Set<String>() }

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
							if let documentBacking = self.documentBackingMap[documentID] {
								// Update document backing
								documentBacking.update(updatedPropertyMap: batchDocumentInfo.updatedPropertyMap,
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
											MDSUpdateInfo<String>(document: document, revision: 1, value: documentID,
													changedProperties: changedProperties))
								}
							} else {
								// Add document
								self.documentBackingMap[documentID] =
										DocumentBacking(creationDate: batchDocumentInfo.creationDate,
												modificationDate: batchDocumentInfo.modificationDate,
												propertyMap: batchDocumentInfo.updatedPropertyMap ?? [:])
								self.documentTypeMap.appendSetValueElement(key: batchDocumentInfo.documentType,
										value: documentID)

								// Check if we have creation proc
								if let creationProc = self.documentCreationProcMap.value(for: documentType) {
									// Create document
									let	document = creationProc(documentID, self)

									// Update collections and indexes
									updateInfos.append(
											MDSUpdateInfo<String>(document: document, revision: 1, value: documentID,
													changedProperties: nil))
								}
							}
						}
					} else {
							// Remove document
						self.documentMapsLock.write() {
							// Update maps
							self.documentBackingMap[documentID] = nil
							self.documentTypeMap.removeSetValueElement(key: batchDocumentInfo.documentType,
									value: documentID)
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
	public func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			info :[String : Any], isUpToDate :Bool, isIncludedSelector :String,
			isIncludedProc :@escaping (_ document :T, _ info :[String : Any]) -> Bool) {
		// Ensure this collection has not already been registered
		guard self.collectionsByNameMap.value(for: name) == nil else { return }

		// Create collection
		let	collection =
					MDSCollectionSpecialized(name: name, relevantProperties: relevantProperties, lastRevision: 0,
							isIncludedProc: isIncludedProc, info: info)

		// Add to maps
		self.collectionsByNameMap.set(collection, for: name)
		self.collectionsByDocumentTypeMap.appendArrayValue(collection, for: T.documentType)

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func queryCollectionDocumentCount(name :String) -> UInt {
		// Return count
		return UInt((self.collectionValuesMap.value(for: name) ?? []).count)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// Iterate
		self.collectionValuesMap.value(for: name)?.forEach() { proc(T(id: $0, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping (_ document :T) -> [String]) {
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
		// Iterate
		let	indexValues = self.indexValuesMap.value(for: name) ?? [:]
		keys.forEach() {
			// Retrieve document
			guard let documentID = indexValues[$0] else { return }
			guard self.documentBackingMap[documentID] != nil else { return }

			// Call proc
			proc($0, T(id: documentID, documentStorage: self))
		}
	}

	// MARK: Private methods
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
