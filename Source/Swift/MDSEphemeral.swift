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
	public func document<T : MDSDocument>(for documentID :String) -> T? {
		// Call proc
		return T(id: documentID, documentStorage: self)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func creationDate(for document :MDSDocument) -> Date {
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
	public func modificationDate(for document :MDSDocument) -> Date {
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
	public func value(for property :String, in document :MDSDocument) -> Any? {
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
	public func date(for property :String, in document :MDSDocument) -> Date? {
		// Return date
		return value(for: property, in: document) as? Date
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.set(value, for: property)
			} else {
				// Don't have document in batch
				batchInfo.addDocument(documentType: type(of: document).documentType, documentID: document.id,
						reference: [:], creationDate: Date(), modificationDate: Date(), valueProc: { property in
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
	public func remove(_ document :MDSDocument) {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.mdsBatchInfoMapLock.read({ return self.mdsBatchInfoMap[Thread.current] }) {
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
			self.documentMapLock.write() {
				// Update maps
				self.documentMap[document.id] = nil
				self.documentTypeMap.removeSetValueElement(key: documentType, value: document.id)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Collect document IDs
		let	documentIDs = self.documentMapLock.read() { return self.documentTypeMap[T.documentType] ?? Set<String>() }

		// Call proc on each storable document
		documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void) {
		// Iterate all
		documentIDs.forEach() { proc(T(id: $0, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Setup
		let	batchInfo = MDSBatchInfo<[String : Any]>()

		// Store
		self.mdsBatchInfoMapLock.write() { self.mdsBatchInfoMap[Thread.current] = batchInfo }

		// Call proc
		let	result = try proc()

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
	public func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			values :[String], isUpToDate :Bool, isIncludedSelector :String,
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
	public func enumerateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// Not yet implemented
		fatalError("enumerateCollection(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping (_ document :T) -> [String]) {
		// Not yet implemented
		fatalError("registerIndex(...) has not been implemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func enumerateIndex<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
		// Not yet implemented
		fatalError("enumerateIndex(...) has not been implemented")
	}

	// MARK: Properties
	private	var	extraValues :[/* Key */ String : Any]?

	private	var	mdsBatchInfoMap = [Thread : MDSBatchInfo<[String : Any]>]()
	private	var	mdsBatchInfoMapLock = ReadPreferringReadWriteLock()

	private	var	documentMap = [/* Document ID */ String : [String : Any]]()
	private	var	documentMapLock = ReadPreferringReadWriteLock()
	private	var	documentTypeMap = [/* Document Type */ String : Set<String>]()
}
