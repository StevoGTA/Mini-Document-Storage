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

			var	modificationDate :Date
			var	revision :Int
			var	propertyMap :MDSDocument.PropertyMap
					{ self.propertiesLock.read({ self.propertyMapInternal }) }

	private	var	propertyMapInternal :MDSDocument.PropertyMap
	private	var	propertiesLock = ReadPreferringReadWriteLock()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(id :Int64, revision :Int, creationDate :Date, modificationDate :Date, propertyMap :MDSDocument.PropertyMap) {
		// Store
		self.id = id
		self.creationDate = creationDate

		self.modificationDate = modificationDate
		self.revision = revision
		self.propertyMapInternal = propertyMap
	}

	//------------------------------------------------------------------------------------------------------------------
	init(documentType :String, documentID :String, creationDate :Date? = nil, modificationDate :Date? = nil,
			propertyMap :MDSDocument.PropertyMap, with sqliteCore :MDSSQLiteCore) {
		// Store
		let	(id, revision, creationDate, modificationDate) =
					sqliteCore.new(documentType: documentType, documentID: documentID, creationDate: creationDate,
							modificationDate: modificationDate, propertyMap: propertyMap)

		// Store
		self.id = id
		self.creationDate = creationDate

		self.modificationDate = modificationDate
		self.revision = revision
		self.propertyMapInternal = propertyMap
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func value(for property :String) -> Any?
			{ return self.propertiesLock.read() { return self.propertyMapInternal[property] } }

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for property :String, documentType :String, with sqliteCore :MDSSQLiteCore,
			commitChange :Bool = true) {
		// Update
		update(documentType: documentType, updatedPropertyMap: (value != nil) ? [property : value!] : nil,
				removedProperties: (value != nil) ? nil : Set([property]), with: sqliteCore, commitChange: commitChange)
	}

	//------------------------------------------------------------------------------------------------------------------
	func update(documentType :String, updatedPropertyMap :MDSDocument.PropertyMap? = nil,
			removedProperties :Set<String>? = nil, with sqliteCore :MDSSQLiteCore, commitChange :Bool = true) {
		// Update
		self.propertiesLock.write() {
			// Store
			updatedPropertyMap?.forEach() { self.propertyMapInternal[$0.key] = $0.value }
			removedProperties?.forEach() { self.propertyMapInternal[$0] = nil }

			// Check if committing change
			if commitChange {
				// Get info
				let	(revision, modificationDate) =
							sqliteCore.update(documentType: documentType, id: self.id,
									propertyMap: self.propertyMapInternal)

				// Store
				self.revision = revision
				self.modificationDate = modificationDate
			}
		}
	}
}
