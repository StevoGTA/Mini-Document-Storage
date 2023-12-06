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
class MDSSQLiteDocumentBacking : MDSDocumentBacking {

	// MARK: Properties
			let	id :Int64
			let	documentID :String
			let	creationDate :Date

			var	revision :Int
			var	active :Bool
			var	modificationDate :Date
			var	propertyMap :[String : Any] { self.propertiesLock.read({ self.propertyMapInternal }) }
			var	documentAttachmentInfoMap :MDSDocument.AttachmentInfoMap

			var	documentFullInfo :MDSDocument.FullInfo
					{ MDSDocument.FullInfo(documentID: self.documentID, revision: self.revision, active: self.active,
						creationDate: self.creationDate, modificationDate: self.modificationDate,
						propertyMap: self.propertyMap, attachmentInfoMap: self.documentAttachmentInfoMap) }

	private	var	propertyMapInternal :[String : Any]
	private	let	propertiesLock = ReadPreferringReadWriteLock()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(id :Int64, documentID :String, revision :Int, active :Bool, creationDate :Date, modificationDate :Date,
			propertyMap :[String : Any], documentAttachmentInfoMap :MDSDocument.AttachmentInfoMap) {
		// Store
		self.id = id
		self.documentID = documentID
		self.creationDate = creationDate

		self.revision = revision
		self.active = active
		self.modificationDate = modificationDate
		self.propertyMapInternal = propertyMap
		self.documentAttachmentInfoMap = documentAttachmentInfoMap
	}

	//------------------------------------------------------------------------------------------------------------------
	init(documentType :String, documentID :String, creationDate :Date? = nil, modificationDate :Date? = nil,
			propertyMap :[String : Any], with databaseManager :MDSSQLiteDatabaseManager) {
		// Setup
		let	(id, revision, creationDate, modificationDate) =
					databaseManager.documentCreate(documentType: documentType, documentID: documentID,
							creationDate: creationDate, modificationDate: modificationDate, propertyMap: propertyMap)

		// Store
		self.id = id
		self.documentID = documentID
		self.creationDate = creationDate

		self.revision = revision
		self.active = true
		self.modificationDate = modificationDate
		self.propertyMapInternal = propertyMap
		self.documentAttachmentInfoMap = [:]
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func value(for property :String) -> Any? { self.propertiesLock.read() { self.propertyMapInternal[property] } }

	//------------------------------------------------------------------------------------------------------------------
	func set(_ value :Any?, for property :String, documentType :String,
			with databaseManager :MDSSQLiteDatabaseManager) {
		// Update
		update(documentType: documentType, updatedPropertyMap: (value != nil) ? [property : value!] : nil,
				removedProperties: (value != nil) ? nil : Set([property]), with: databaseManager)
	}

	//------------------------------------------------------------------------------------------------------------------
	func update(documentType :String, updatedPropertyMap :[String : Any]? = nil,
			removedProperties :Set<String>? = nil, with databaseManager :MDSSQLiteDatabaseManager) {
		// Exclusive access
		self.propertiesLock.write() {
			// Update property map
			updatedPropertyMap?.forEach() { self.propertyMapInternal[$0.key] = $0.value }
			removedProperties?.forEach() { self.propertyMapInternal[$0] = nil }

			// Update persistent storage
			let	(revision, modificationDate) =
						databaseManager.documentUpdate(documentType: documentType, id: self.id,
								propertyMap: self.propertyMapInternal)

			// Update properties
			self.revision = revision
			self.modificationDate = modificationDate
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func attachmentAdd(documentType :String, info :[String : Any], content :Data,
			with databaseManager :MDSSQLiteDatabaseManager) -> MDSDocument.AttachmentInfo {
		// Exclusive access
		self.propertiesLock.write() {
			// Update persistent storage
			let	(revision, modificationDate, documentAttachmentInfo) =
						databaseManager.documentAttachmentAdd(documentType: documentType, id: self.id, info: info,
								content: content)

			// Update
			self.revision = revision
			self.modificationDate = modificationDate
			self.documentAttachmentInfoMap[documentAttachmentInfo.id] = documentAttachmentInfo

			return documentAttachmentInfo
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func attachmentContent(documentType :String, attachmentID :String, with databaseManager :MDSSQLiteDatabaseManager)
			-> Data {
		// Return content
		return databaseManager.documentAttachmentContent(documentType: documentType, id: self.id,
				attachmentID: attachmentID)
	}

	//------------------------------------------------------------------------------------------------------------------
	func attachmentUpdate(documentType :String, attachmentID :String, updatedInfo :[String : Any], updatedContent :Data,
			with databaseManager :MDSSQLiteDatabaseManager) -> Int {
		// Exclusive access
		self.propertiesLock.write() {
			// Update persistent storage
			let	(revision, modificationDate, documentAttachmentInfo) =
						databaseManager.documentAttachmentUpdate(documentType: documentType, id: self.id,
								attachmentID: attachmentID, updatedInfo: updatedInfo, updatedContent: updatedContent)

			// Update
			self.revision = revision
			self.modificationDate = modificationDate
			self.documentAttachmentInfoMap[attachmentID] = documentAttachmentInfo

			return documentAttachmentInfo.revision
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func attachmentRemove(documentType :String, attachmentID :String, with databaseManager :MDSSQLiteDatabaseManager) {
		// Exclusive access
		self.propertiesLock.write() {
			// Update persistent storage
			let	(revision, modificationDate) =
						databaseManager.documentAttachmentRemove(documentType: documentType, id: self.id,
								attachmentID: attachmentID)

			// Update
			self.revision = revision
			self.modificationDate = modificationDate
			self.documentAttachmentInfoMap[attachmentID] = nil
		}
	}
}
