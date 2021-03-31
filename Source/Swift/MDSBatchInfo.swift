//
//  MDSBatchInfo.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSBatchInfo
class MDSBatchInfo<T> {

	// MARK: DocumentInfo
	class DocumentInfo<T> {

		// MARK: Procs
		typealias ValueProc = (_ property :String) -> Any?

		// MARK: Properties
						let	documentType :String
						let	reference :T?
						let	creationDate :Date

		private(set)	var	updatedPropertyMap :[String : Any]?
		private(set)	var	removedProperties :Set<String>?
		private(set)	var	modificationDate :Date
		private(set)	var	removed = false

		private			let	valueProc :ValueProc

		private			var	lock = ReadPreferringReadWriteLock()

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
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
		//--------------------------------------------------------------------------------------------------------------
		func value(for property :String) -> Any? {
			// Check for removed
			if self.removed {
				// Removed
				return nil
			} else if let (value, _) = self.lock.read({ () -> (value :Any?, removed :Bool)? in
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

		//--------------------------------------------------------------------------------------------------------------
		func set(_ value :Any?, for property :String) {
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

		//--------------------------------------------------------------------------------------------------------------
		func remove() { self.lock.write() { self.removed = true; self.modificationDate = Date() } }
	}

	// MARK: Properties
	private	var	documentInfoMap = [/* storable document id */ String : DocumentInfo<T>]()
	private	var	documentInfoMapLock = ReadPreferringReadWriteLock()

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func addDocument(documentType :String, documentID :String, reference :T? = nil, creationDate :Date,
			modificationDate :Date, valueProc :@escaping DocumentInfo<T>.ValueProc = { _ in nil }) -> DocumentInfo<T> {
		// Setup
		let	documentInfo =
					DocumentInfo(documentType: documentType, reference: reference, creationDate: creationDate,
							modificationDate: modificationDate, valueProc: valueProc)

		// Store
		self.documentInfoMapLock.write() { self.documentInfoMap[documentID] = documentInfo }

		return documentInfo
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentInfo(for documentID :String) -> DocumentInfo<T>? {
		// Return document
		return self.documentInfoMapLock.read() { self.documentInfoMap[documentID] }
	}

	//------------------------------------------------------------------------------------------------------------------
	func forEach(
			_ proc :(_ documentType :String, _ documentInfosMap :[/* id */ String : DocumentInfo<T>]) throws -> Void)
			rethrows {
		// Collate
		var	map = [/* document type */ String : [/* id */ String : DocumentInfo<T>]]()
		self.documentInfoMapLock.read() {
			// Collect info
			self.documentInfoMap.forEach() {
				// Retrieve already collated batch document infos
				if var documentInfosMap = map[$0.value.documentType] {
					// Next document of this type
					map[$0.value.documentType] = nil
					documentInfosMap[$0.key] = $0.value
					map[$0.value.documentType] = documentInfosMap
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
