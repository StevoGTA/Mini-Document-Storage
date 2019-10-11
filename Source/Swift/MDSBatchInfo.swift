//
//  MDSBatchInfo.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSBatchDocumentInfo
public class MDSBatchDocumentInfo<T> {

	// MARK: Types
	public typealias PropertyMap = [/* Key */ String : /* Value */ Any]

	// MARK: Procs
	public typealias ValueProc = (_ documentInfo :T, _ key :String) -> Any?

	// MARK: Properties
	public					let	reference :T?
	public					let	creationDate :Date

	public	private(set)	var	updatedPropertyMap :PropertyMap?
	public	private(set)	var	removedKeys :Set<String>?
	public	private(set)	var	modificationDate :Date
	public	private(set)	var	removed = false

							let	documentType :String

			private			let	valueProc :ValueProc

			private			var	lock = ReadPreferringReadWriteLock()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(documentType :String, reference :T?, creationDate :Date, modificationDate :Date,
			valueProc :@escaping ValueProc) {
		// Store
		self.reference = reference
		self.creationDate = creationDate

		self.modificationDate = modificationDate

		self.documentType = documentType

		self.valueProc = valueProc
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func value(for key :String) -> Any? {
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
		} else if let reference = self.reference {
			// Call value proc
			return self.valueProc(reference, key)
		} else {
			// No value
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ value :Any?, for key :String) {
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

			// Modified
			self.modificationDate = Date()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove() {
		// Mark as removed
		self.lock.write() { self.removed = true }
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSBatchInfo
public class MDSBatchInfo<T> {

	// MARK: Properties
	private	var	batchDocumentInfoMap = [/* storable document id */ String : MDSBatchDocumentInfo<T>]()
	private	var	batchDocumentInfoMapLock = ReadPreferringReadWriteLock()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init() {}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func addDocument(documentType :String, documentID :String, reference :T? = nil, creationDate :Date,
			modificationDate :Date, valueProc :@escaping MDSBatchDocumentInfo<T>.ValueProc = { _,_ in return nil }) ->
			MDSBatchDocumentInfo<T> {
		// Setup
		let	batchDocumentInfo =
					MDSBatchDocumentInfo(documentType: documentType, reference: reference, creationDate: creationDate,
							modificationDate: modificationDate, valueProc: valueProc)

		// Store
		self.batchDocumentInfoMapLock.write() { self.batchDocumentInfoMap[documentID] = batchDocumentInfo }

		return batchDocumentInfo
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batchDocumentInfo(for documentID :String) -> MDSBatchDocumentInfo<T>? {
		// Return document
		return self.batchDocumentInfoMapLock.read() { return self.batchDocumentInfoMap[documentID] }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func forEach(
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
