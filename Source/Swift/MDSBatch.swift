//
//  MDSBatch.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSBatchResult
public enum MDSBatchResult {
	case commit
	case cancel
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSBatch
public class MDSBatch<DB : MDSDocumentBacking> {

	// MARK: AddAttachmentInfo
	struct AddAttachmentInfo {

		// MARK: Properties
		let	id :String
		let	revision :Int
		let	info :[String : Any]
		let	content :Data

		var	documentAttachmentInfo :MDSDocument.AttachmentInfo
				{ MDSDocument.AttachmentInfo(id: self.id, revision: self.revision, info: self.info) }

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(info :[String : Any], content :Data) {
			// Setup
			self.id = UUID().base64EncodedString
			self.revision = 1

			// Store
			self.info = info
			self.content = content
		}
	}

	// MARK: UpdateAttachmentInfo
	struct UpdateAttachmentInfo {

		// MARK: Properties
		let	id :String
		let	currentRevision :Int
		let	info :[String : Any]
		let	content :Data

		var	documentAttachmentInfo :MDSDocument.AttachmentInfo
				{ MDSDocument.AttachmentInfo(id: self.id, revision: self.currentRevision, info: self.info) }
	}

	// MARK: DocumentInfo
	class DocumentInfo {

		// MARK: Properties
						let	documentType :String
						let	documentBacking :DB?
						let	creationDate :Date

		private(set)	var	updatedPropertyMap = [String : Any]()
		private(set)	var	removedProperties = Set<String>()
		private(set)	var	modificationDate :Date
		private(set)	var	addAttachmentInfosByID = [String : AddAttachmentInfo]()
		private(set)	var	updateAttachmentInfosByID = [String : UpdateAttachmentInfo]()
		private(set)	var	removedAttachmentIDs = Set<String>()
		private(set)	var	removed = false

		private			let	initialPropertyMap :[String : Any]?

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		fileprivate init(documentType :String, documentBacking :DB) {
			// Store
			self.documentType = documentType
			self.documentBacking = documentBacking
			self.creationDate = documentBacking.creationDate

			self.modificationDate = Date()

			self.initialPropertyMap = documentBacking.propertyMap
		}

		//--------------------------------------------------------------------------------------------------------------
		fileprivate init(documentType :String, creationDate :Date, modificationDate :Date,
				initialPropertyMap :[String : Any]?) {
			// Store
			self.documentType = documentType
			self.documentBacking = nil
			self.creationDate = creationDate

			self.modificationDate = modificationDate

			self.initialPropertyMap = initialPropertyMap
		}

		// MARK: Instance methods
		//--------------------------------------------------------------------------------------------------------------
		func value(for property :String) -> Any? {
			// Check for document removed
			if self.removed || self.removedProperties.contains(property) {
				// Removed
				return nil
			} else {
				// Not removed
				return self.updatedPropertyMap[property] ?? self.initialPropertyMap?[property]
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		func set(_ value :Any?, for property :String) {
			// Check if have value
			if value != nil {
				// Have value
				self.updatedPropertyMap[property] = value
				self.removedProperties.remove(property)
			} else {
				// Removing value
				self.updatedPropertyMap[property] = nil
				self.removedProperties.insert(property)
			}

			// Modified
			self.modificationDate = Date()
		}

		//--------------------------------------------------------------------------------------------------------------
		func remove() { self.removed = true; self.modificationDate = Date() }

		//--------------------------------------------------------------------------------------------------------------
		func documentAttachmentInfoMap(applyingChangesTo documentAttachmentInfoMap :MDSDocument.AttachmentInfoMap) ->
				MDSDocument.AttachmentInfoMap {
			// Return updated map
			return documentAttachmentInfoMap
					.merging(self.addAttachmentInfosByID.mapValues({ $0.documentAttachmentInfo }),
							uniquingKeysWith: { $1 })
					.merging(self.updateAttachmentInfosByID.mapValues({ $0.documentAttachmentInfo }),
							uniquingKeysWith: { $1 })
					.removingValues(forKeys: self.removedAttachmentIDs)
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentContent(for id :String) -> Data? {
			// Return content
			return self.addAttachmentInfosByID[id]?.content ?? self.updateAttachmentInfosByID[id]?.content
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentAdd(info :[String : Any], content :Data) -> MDSDocument.AttachmentInfo {
			// Setup
			let	addAttachmentInfo = AddAttachmentInfo(info: info, content: content)

			// Add info
			self.addAttachmentInfosByID[addAttachmentInfo.id] = addAttachmentInfo

			// Modified
			self.modificationDate = Date()

			return addAttachmentInfo.documentAttachmentInfo
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentUpdate(id :String, currentRevision :Int, info :[String : Any], content :Data) {
			// Add info
			self.updateAttachmentInfosByID[id] =
					UpdateAttachmentInfo(id: id, currentRevision: currentRevision, info: info, content: content)

			// Modified
			self.modificationDate = Date()
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentRemove(id :String) {
			// Add id
			self.removedAttachmentIDs.insert(id)

			// Modified
			self.modificationDate = Date()
		}
	}

	// MARK: Properties
			var	documentInfosByDocumentType :[String : [String : DocumentInfo]] {
						// Setup
						var	info = [String : [String : DocumentInfo]]()

						// Iterate DocumentInfos
						self.documentInfosByDocumentID.forEach() {
							// Add
							if var documentInfoInfo = info[$1.documentType] {
								//
								info[$1.documentType] = nil
								documentInfoInfo[$0] = $1
								info[$1.documentType] = documentInfoInfo
							} else {
								//
								info[$1.documentType] = [$0 : $1]
							}
						}

						return info
					}

	private	var	associationUpdatesByAssociationName = [/* Name */ String : [MDSAssociation.Update]]()
	private	var	documentInfosByDocumentID = [/* Document ID */ String : DocumentInfo]()

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func associationNoteUpdated(for name :String, updates :[MDSAssociation.Update]) {
		// Add
		self.associationUpdatesByAssociationName.appendArrayValueElements(key: name, values: updates)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterateChanges(proc :(_ name :String, _ updates :[MDSAssociation.Update]) -> Void) {
		// Iterate info
		self.associationUpdatesByAssociationName.forEach() { proc($0.key, $0.value) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationItems(applyingChangesTo associationItems :[MDSAssociation.Item], for name :String) ->
			[MDSAssociation.Item] {
		// Setup
		var	associationItemsUpdated = associationItems
		self.associationUpdatesByAssociationName[name]?.forEach() {
			// Process update
			if $0.action == .add {
				// Add
				associationItemsUpdated.append($0.item)
			} else {
				// Remove
				associationItemsUpdated.remove($0.item)
			}
		}

		return associationItemsUpdated
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationUpdates(for name :String) -> (adds :[MDSAssociation.Item], removes :[MDSAssociation.Item]) {
		// Setup
		let	associationUpdates = self.associationUpdatesByAssociationName[name] ?? []

		return (associationUpdates.filter({ $0.action == .add }).map({ $0.item }),
				associationUpdates.filter({ $0.action == .remove} ).map({ $0.item }))
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAdd(documentType :String, documentBacking :DB) -> DocumentInfo {
		// Setup
		let	documentInfo = DocumentInfo(documentType: documentType, documentBacking: documentBacking)

		// Store
		self.documentInfosByDocumentID[documentBacking.documentID] = documentInfo

		return documentInfo
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAdd(documentType :String, documentID :String, creationDate :Date, modificationDate :Date,
			propertyMap :[String : Any]? = nil) -> DocumentInfo {
		// Setup
		let	documentInfo =
					DocumentInfo(documentType: documentType, creationDate: creationDate,
							modificationDate: modificationDate, initialPropertyMap: propertyMap)

		// Store
		self.documentInfosByDocumentID[documentID] = documentInfo

		return documentInfo
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentInfoGet(for documentID :String) -> DocumentInfo? { self.documentInfosByDocumentID[documentID] }
}
