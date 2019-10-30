//
//  MDSEphemeral.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSEphemeral
class MDSEphemeral : MiniDocumentStorage {

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
			self.documentMapLock.write() {
				// Update maps
				self.documentTypeMap.appendSetValueElement(key: documentType, value: documentID)
				self.documentMap[documentID] = [:]
			}
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
			// In batch
			return (creationProc(documentID, self) as! T)
		} else {
			// Not in batch
			let	document = self.documentMapLock.read() { return self.documentMap[documentID] }

			return (document != nil) ? (creationProc(documentID, self) as! T) : nil
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
			return self.documentMapLock.read() { return self.documentMap[documentID]?[key] }
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
				batchInfo.addDocument(documentType: documentType, documentID: documentID, reference: [:],
						creationDate: Date(), modificationDate: Date(), valueProc: { _, key in
									// Play nice with others
									self.documentMapLock.read() { return self.documentMap[documentID]?[key] }
								})
						.set(value, for: key)
			}
		} else {
			// Not in batch
			self.documentMapLock.write() { self.documentMap[documentID]?[key] = value }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func date(for value: Any?) -> Date? { return value as? Date }

	//------------------------------------------------------------------------------------------------------------------
	func value(for date: Date?) -> Any? { return date }

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
				batchInfo.addDocument(documentType: documentType, documentID: documentID, reference: [:],
						creationDate: Date(), modificationDate: Date()).remove()
			}
		} else {
			// Not in batch
			self.documentMapLock.write() {
				// Update maps
				self.documentMap[documentID] = nil
				self.documentTypeMap.removeSetValueElement(key: documentType, value: documentID)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(documentType :String, proc :MDSDocument.ApplyProc<T>,
			creationProc :MDSDocument.CreationProc) {
		// Collect document IDs
		let	documentIDs = self.documentMapLock.read() { return self.documentTypeMap[documentType] ?? Set<String>() }

		// Call proc on each storable document
		documentIDs.forEach() { proc(creationProc($0, self) as! T) }
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
								batchDocumentInfo.removedKeys?.forEach() { document[$0] = nil }
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

	// MARK: Properties
	private	var	mdsBatchInfoMap = [Thread : MDSBatchInfo<[String : Any]>]()
	private	var	mdsBatchInfoMapLock = ReadPreferringReadWriteLock()

	private	var	documentMap = [/* Document ID */ String : [String : Any]]()
	private	var	documentMapLock = ReadPreferringReadWriteLock()
	private	var	documentTypeMap = [/* Document Type */ String : Set<String>]()
}
