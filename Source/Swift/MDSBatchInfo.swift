//
//  MDSBatchInfo.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSBatchDocumentInfo
public class MDSBatchDocumentInfo<T> {

	// MARK: Types
	public typealias PropertyMap = [/* Property */ String : /* Value */ Any]

	// MARK: Procs
	public typealias ValueProc = (_ property :String) -> Any?

	// MARK: Properties
	public					let	reference :T?
	public					let	creationDate :Date

	public	private(set)	var	updatedPropertyMap :PropertyMap?
	public	private(set)	var	removedProperties :Set<String>?
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
	public func value(for property :String) -> Any? {
		// Check for removed
		guard !self.removed else { return nil }

		// Check if have updated info
		if let (value, _) =
					self.lock.read({ () -> (value :Any?, removed :Bool)? in
						// Check the deal
						if self.removedProperties?.contains(property) ?? false {
							// Removed
							return (nil, true)
						} else if let value = self.updatedPropertyMap?[property] {
							// Have value
							return (value, false)
						} else {
							// Neither have value nor removed
							return nil
						}
					}) {
			// Have info
			return value
		} else {
			// Call value proc
			return self.valueProc(property)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ value :Any?, for property :String) {
		// Write
		self.lock.write() {
			// Check if have value
			if value != nil {
				// Have value
				if self.updatedPropertyMap != nil {
					// Have updated info
					self.updatedPropertyMap![property] = value
				} else {
					// First updated info
					self.updatedPropertyMap = [property : value!]
				}

				self.removedProperties?.remove(property)
			} else {
				// Removing value
				self.updatedPropertyMap?[property] = nil

				if self.removedProperties != nil {
					// Have removed propertys
					self.removedProperties!.insert(property)
				} else {
					// First removed property
					self.removedProperties = Set<String>([property])
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
			modificationDate :Date, valueProc :@escaping MDSBatchDocumentInfo<T>.ValueProc = { _ in nil }) ->
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
		return self.batchDocumentInfoMapLock.read() { self.batchDocumentInfoMap[documentID] }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func forEach(
			_ proc
					:(_ documentType :String,
							_ batchDocumentInfosMap :[/* id */ String : MDSBatchDocumentInfo<T>]) throws -> Void)
			rethrows {
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
		try map.forEach() { try proc($0.key, $0.value) }
	}
}
