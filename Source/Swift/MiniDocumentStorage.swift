//
//  MiniDocumentStorage.swift
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSBatchResult
enum MDSBatchResult {
	case commit
	case cancel
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MiniDocumentStorage protocol
protocol MiniDocumentStorage : class {

	// MARK: Instance methods
	func newDocument<T : MDSDocument>(_ creationProc :MDSDocument.CreationProc) -> T
	func enumerate<T : MDSDocument>(_ proc :MDSDocument.ApplyProc<T>, _ creationProc :MDSDocument.CreationProc)

	func batch(_ proc :() -> MDSBatchResult)

	func value(for key :String, documentType :String, documentID :String) -> Any?
	func set(_ value :Any?, for key :String, documentType :String, documentID :String)

	func date(for value :Any?) -> Date?
	func value(for date :Date?) -> Any?

	func remove(documentType :String, documentID :String)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MiniDocumentStorage extension
extension MiniDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func newDocument<T : MDSDocument>() -> T {
		// Use default creation proc
		return newDocument() { return T(id: $0, miniDocumentStorage: $1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(_ proc :(_ mdsDocument :T) -> Void) {
		// Use default creation proc
		return enumerate(proc) { return T(id: $0, miniDocumentStorage: $1) }
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSBatchDocumentInfo
class MDSBatchDocumentInfo<T> {

	// MARK: Procs
	typealias ValueProc = (_ documentReference :T, _ key :String) -> Any?

	// MARK: Properties
					let	documentType :String
					let	documentReference :T?

	private(set)	var	updatedPropertyMap :MDSSQLiteDocumentBacking.PropertyMap?
	private(set)	var	removedKeys :Set<String>?
	private(set)	var	removed = false

	private			let	valueProc :ValueProc

	private			var	lock = ReadPreferringReadWriteLock()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(documentType :String, documentReference :T?, valueProc :@escaping ValueProc) {
		// Store
		self.documentType = documentType
		self.documentReference = documentReference

		self.valueProc = valueProc
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func value(for key :String) -> Any? {
		// Check for removed
		guard !self.removed else { return nil }

		// Check if have updated info
		if let (value, _) =
					self.lock.read({ () -> (value :Any?, removed :Bool)? in
						// Check the deal
						if self.removedKeys?.contains(key) ?? false {
							// Removed
							return (nil, true)
						} else if let value = self.updatedPropertyMap?[key] {
							// Have value
							return (value, false)
						} else {
							// Neither have value nor removed
							return nil
						}
					}) {
			// Have info
			return value
		} else if self.documentReference != nil {
			// Call value proc
			return self.valueProc(self.documentReference!, key)
		} else {
			// No way to get value
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for key :String) {
		// Write
		self.lock.write() {
			// Check if have value
			if value != nil {
				// Have value
				if self.updatedPropertyMap != nil {
					// Have updated info
					self.updatedPropertyMap![key] = value
				} else {
					// First updated info
					self.updatedPropertyMap = [key : value!]
				}

				self.removedKeys?.remove(key)
			} else {
				// Removing value
				self.updatedPropertyMap?[key] = nil

				if self.removedKeys != nil {
					// Have removed keys
					self.removedKeys!.insert(key)
				} else {
					// First removed key
					self.removedKeys = Set<String>([key])
				}
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove() {
		// Mark as removed
		self.lock.write() { self.removed = true }
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSBatchInfo
class MDSBatchInfo<T> {

	// MARK: Properties
	private	var	batchDocumentInfoMap = [/* storable document id */ String : MDSBatchDocumentInfo<T>]()
	private	var	batchDocumentInfoMapLock = ReadPreferringReadWriteLock()

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func addDocument(documentType :String, documentID :String, documentReference :T? = nil,
			valueProc :@escaping MDSBatchDocumentInfo<T>.ValueProc = { _,_ in return nil }) -> MDSBatchDocumentInfo<T> {
		// Setup
		let	batchDocumentInfo =
					MDSBatchDocumentInfo(documentType: documentType, documentReference: documentReference,
							valueProc: valueProc)

		// Store
		self.batchDocumentInfoMapLock.write() { self.batchDocumentInfoMap[documentID] = batchDocumentInfo }

		return batchDocumentInfo
	}

	//------------------------------------------------------------------------------------------------------------------
	func batchDocumentInfo(for documentID :String) -> MDSBatchDocumentInfo<T>? {
		// Return document
		return self.batchDocumentInfoMapLock.read() { return self.batchDocumentInfoMap[documentID] }
	}

	//------------------------------------------------------------------------------------------------------------------
	func forEach(
			_ proc
					:(_ documentType :String,
							_ batchDocumentInfosMap :[/* id */ String : MDSBatchDocumentInfo<T>]) -> Void) {
		// Collate
		var	map = [/* document type */ String : [/* id */ String : MDSBatchDocumentInfo<T>]]()
		self.batchDocumentInfoMapLock.read() {
			// Collect info
			self.batchDocumentInfoMap.forEach() {
				// Retrieve already collated batch document infos
				if var batchDocumentInfosMap = map[$0.value.documentType] {
					// Next document of this type
					map[$0.value.documentType] = nil
					batchDocumentInfosMap[$0.key] = $0.value
					map[$0.value.documentType] = batchDocumentInfosMap
				} else {
					// First document of this type
					map[$0.value.documentType] = [$0.key : $0.value]
				}
			}
		}

		// Iterate and call proc
		map.forEach() { proc($0.key, $0.value) }
	}
}
