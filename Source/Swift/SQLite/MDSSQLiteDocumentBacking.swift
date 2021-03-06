//
//  MDSSQLiteDocumentBacking.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/18/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSSQLiteDocumentBacking
class MDSSQLiteDocumentBacking {
	// MARK: Properties
			let	id :Int64
			let	creationDate :Date

			var	revision :Int
			var	modificationDate :Date
			var	propertyMap :[String : Any] { self.propertiesLock.read({ self.propertyMapInternal }) }
			var	active :Bool

	private	var	propertyMapInternal :[String : Any]
	private	let	propertiesLock = ReadPreferringReadWriteLock()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(id :Int64, revision :Int, creationDate :Date, modificationDate :Date, propertyMap :[String : Any],
			active :Bool) {
		// Store
		self.id = id
		self.creationDate = creationDate

		self.revision = revision
		self.modificationDate = modificationDate
		self.propertyMapInternal = propertyMap
		self.active = active
	}

	//------------------------------------------------------------------------------------------------------------------
	init(documentType :String, documentID :String, creationDate :Date? = nil, modificationDate :Date? = nil,
			propertyMap :[String : Any], with databaseManager :MDSSQLiteDatabaseManager) {
		// Setup
		let	(id, revision, creationDate, modificationDate) =
					databaseManager.new(documentType: documentType, documentID: documentID, creationDate: creationDate,
							modificationDate: modificationDate, propertyMap: propertyMap)

		// Store
		self.id = id
		self.creationDate = creationDate

		self.revision = revision
		self.modificationDate = modificationDate
		self.propertyMapInternal = propertyMap
		self.active = true
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func value(for property :String) -> Any? { self.propertiesLock.read() { self.propertyMapInternal[property] } }

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for property :String, documentType :String, with databaseManager :MDSSQLiteDatabaseManager,
			commitChange :Bool = true) {
		// Update
		update(documentType: documentType, updatedPropertyMap: (value != nil) ? [property : value!] : nil,
				removedProperties: (value != nil) ? nil : Set([property]), with: databaseManager,
				commitChange: commitChange)
	}

	//------------------------------------------------------------------------------------------------------------------
	func update(documentType :String, updatedPropertyMap :[String : Any]? = nil,
			removedProperties :Set<String>? = nil, with databaseManager :MDSSQLiteDatabaseManager,
			commitChange :Bool = true) {
		// Update
		self.propertiesLock.write() {
			// Store
			updatedPropertyMap?.forEach() { self.propertyMapInternal[$0.key] = $0.value }
			removedProperties?.forEach() { self.propertyMapInternal[$0] = nil }

			// Check if committing change
			if commitChange {
				// Get info
				let	(revision, modificationDate) =
							databaseManager.update(documentType: documentType, id: self.id,
									propertyMap: self.propertyMapInternal)

				// Store
				self.revision = revision
				self.modificationDate = modificationDate
			}
		}
	}
}
