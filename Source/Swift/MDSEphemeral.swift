//
//  MDSEphemeral.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSEphemeral
class MDSEphemeral : MDSDocumentStorage {

	// MARK: MDSDocumentStorage implementation
	//------------------------------------------------------------------------------------------------------------------
	func newDocument<T : MDSDocument>(creationProc :MDSDocument.CreationProc<T>) -> T {
		// Setup
		let	documentID = UUID().base64EncodedString

		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }) {
			// In batch
			_ = batchInfo.addDocument(documentType: T.documentType, documentID: documentID, creationDate: Date(),
					modificationDate: Date())
		} else {
			// Add document
			self.documentMapLock.write() {
				// Update maps
				self.documentTypeMap.appendSetValueElement(key: T.documentType, value: documentID)
				self.documentMap[documentID] = [:]
			}
		}

		// Create
		return creationProc(documentID, self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func document<T : MDSDocument>(for documentID :String) -> T? {
		// Call proc
		return T(id: documentID, documentStorage: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	func creationDate<T : MDSDocument>(for document :T) -> Date {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }),
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.creationDate
		} else {
			// Not in batch
			return Date()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func modificationDate<T : MDSDocument>(for document :T) -> Date {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }),
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.modificationDate
		} else {
			// Not in batch
			return Date()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func value<T : MDSDocument>(for property :String, in document :T) -> Any? {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }),
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.value(for: property)
		} else {
			// Not in batch
			return self.documentMapLock.read() { return self.documentMap[document.id]?[property] }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func date<T : MDSDocument>(for property :String, in document :T) -> Date? {
		// Return date
		return value(for: property, in: document) as? Date
	}

	//------------------------------------------------------------------------------------------------------------------
	func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.set(value, for: property)
			} else {
				// Don't have document in batch
				batchInfo.addDocument(documentType: T.documentType, documentID: document.id, reference: [:],
						creationDate: Date(), modificationDate: Date(), valueProc: { property in
									// Play nice with others
									self.documentMapLock.read() { return self.documentMap[document.id]?[property] }
								})
						.set(value, for: property)
			}
		} else {
			// Not in batch
			self.documentMapLock.write() { self.documentMap[document.id]?[property] = value }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove<T : MDSDocument>(_ document :T) {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				batchInfo.addDocument(documentType: T.documentType, documentID: document.id, reference: [:],
						creationDate: Date(), modificationDate: Date()).remove()
			}
		} else {
			// Not in batch
			self.documentMapLock.write() {
				// Update maps
				self.documentMap[document.id] = nil
				self.documentTypeMap.removeSetValueElement(key: T.documentType, value: document.id)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(proc :MDSDocument.ApplyProc<T>) {
		// Collect document IDs
		let	documentIDs = self.documentMapLock.read() { return self.documentTypeMap[T.documentType] ?? Set<String>() }

		// Call proc on each storable document
		documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(documentIDs :[String], proc :MDSDocument.ApplyProc<T>) {
		// Iterate all
		documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func batch(_ proc :() -> MDSBatchResult) {
		// Setup
		let	batchInfo = MDSBatchInfo<[String : Any]>()

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
				// Update documents
				batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
					// Is removed?
					if !batchDocumentInfo.removed {
						// Update document
						self.documentMapLock.write() {
							// Retrieve existing document
							if var document = self.documentMap[documentID] {
								// Have existing
								self.documentMap[documentID] = nil
								document =
										document.merging(batchDocumentInfo.updatedPropertyMap ?? [:],
												uniquingKeysWith: { $1 })
								batchDocumentInfo.removedProperties?.forEach() { document[$0] = nil }
								self.documentMap[documentID] = document
							} else {
								// Create new
								self.documentMap[documentID] = batchDocumentInfo.updatedPropertyMap ?? [:]
								self.documentTypeMap.appendSetValueElement(key: batchDocumentInfo.documentType,
										value: documentID)
							}
						}
					} else {
						// Remove document
						self.documentMapLock.write() {
							// Update maps
							self.documentMap[documentID] = nil
							self.documentTypeMap.removeSetValueElement(key: batchDocumentInfo.documentType,
									value: documentID)
						}
					}
				}
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			values :[String], isUpToDate :Bool, includeSelector :String,
			includeProc :@escaping MDSDocument.IncludeProc<T>) {
		// Not yet implemented
		fatalError("registerCollection(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func queryCollectionDocumentCount(name :String) -> UInt {
		// Not yet implemented
		fatalError("queryCollectionDocumentCount(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerateCollection<T : MDSDocument>(name :String, proc :MDSDocument.ApplyProc<T>) {
		// Not yet implemented
		fatalError("enumerateCollection(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping MDSDocument.KeysProc<T>) {
		// Not yet implemented
		fatalError("registerIndex(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerateIndex<T : MDSDocument>(name :String, keys :[String], proc :MDSDocument.IndexApplyProc<T>) {
		// Not yet implemented
		fatalError("enumerateIndex(...) has not been implemented")
	}

	// MARK: Properties
	private	var	mdsBatchInfoMap = [Thread : MDSBatchInfo<[String : Any]>]()
	private	var	mdsBatchInfoMapLock = ReadPreferringReadWriteLock()

	private	var	documentMap = [/* Document ID */ String : [String : Any]]()
	private	var	documentMapLock = ReadPreferringReadWriteLock()
	private	var	documentTypeMap = [/* Document Type */ String : Set<String>]()
}
