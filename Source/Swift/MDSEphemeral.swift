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

	// MARK: Properties
	public	var	id :String = UUID().uuidString

	private	var	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<[String : Any]>>()

	private	var	documentBackingMap = [/* Document ID */ String : [String : Any]]()
	private	var	documentTypeMap = [/* Document Type */ String : Set<String>]()
	private	var	documentMapsLock = ReadPreferringReadWriteLock()
	private	var	documentCreationProcMap = LockingDictionary<String, MDSDocument.CreationProc>()

	private	var	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	var	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()
	private	var	indexValuesMap = LockingDictionary</* Name */ String, [/* Key */ String : /* Document ID */ String]>()

	// MARK: MDSDocumentStorage implementation
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
			// Add document
			self.documentMapsLock.write() {
				// Update maps
				self.documentTypeMap.appendSetValueElement(key: T.documentType, value: documentID)
				self.documentBackingMap[documentID] = [:]
			}

			// Create
			let	document = creationProc(documentID, self)

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
		} else {
			// Not in batch
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
		} else {
			// Not in batch
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
		} else {
			// Not in batch
			return self.documentMapsLock.read() { return self.documentBackingMap[document.id]?[property] }
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
										{ return self.documentBackingMap[document.id]?[property] }
								})
						.set(value, for: property)
			}
		} else {
			// Not in batch
			self.documentMapsLock.write() { self.documentBackingMap[document.id]?[property] = value }

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
							if var documentBacking = self.documentBackingMap[documentID] {
								// Update document
								self.documentBackingMap[documentID] = nil
								documentBacking =
										documentBacking.merging(batchDocumentInfo.updatedPropertyMap ?? [:],
												uniquingKeysWith: { $1 })
								batchDocumentInfo.removedProperties?.forEach() { documentBacking[$0] = nil }
								self.documentBackingMap[documentID] = documentBacking

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
								self.documentBackingMap[documentID] = batchDocumentInfo.updatedPropertyMap ?? [:]
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
		// Not yet implemented
		fatalError("registerCollection(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func queryCollectionDocumentCount(name :String) -> UInt {
		// Not yet implemented
		fatalError("queryCollectionDocumentCount(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// Not yet implemented
		fatalError("iterateCollection(...) has not been implemented")
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

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init() {}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func updateCollections(for documentType :String, updateInfos :[MDSUpdateInfo<String>],
			processNotIncluded :Bool = true) {
//		// Iterate all collections for this document type
//		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach() {
//			// Update
//			let	(includedIDs, notIncludedIDs, lastRevision) = $0.update(updateInfos)
//
//			// Update
//			self.sqliteCore.updateCollection(name: $0.name, includedIDs: includedIDs,
//					notIncludedIDs: processNotIncluded ? notIncludedIDs : [], lastRevision: lastRevision)
//		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateIndexes(for documentType :String, updateInfos :[MDSUpdateInfo<String>]) {
		// Iterate all indexes for this document type
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach() {
			// Update
			let	(keysInfos, _) = $0.update(updateInfos)
			guard !keysInfos.isEmpty else { return }

			// Retrieve existing values map
			var	indexValues = self.indexValuesMap.value(for: $0.name) ?? [:]

			// Filter out document IDs included in update
			let	documentIDs = Set<String>(keysInfos.map({ $0.value }))
			indexValues = indexValues.filter({ !documentIDs.contains($0.value) })

			// Add/Update keys => document IDs
			keysInfos.forEach() { keys, value in keys.forEach() { indexValues[$0] = value } }

			// Store
			self.indexValuesMap.set(indexValues, for: $0.name)
		}
	}
}
