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

	// MARK: AddAttachmentInfo
	struct AddAttachmentInfo {

		// MARK: Properties
		let	attachmentID :String
		let	revision :Int
		let	info :[String : Any]
		let	content :Data

		var	attachmentInfo :MDSDocument.AttachmentInfo
				{ MDSDocument.AttachmentInfo(id: self.attachmentID, revision: self.revision, info: self.info) }

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(info :[String : Any], content :Data) {
			// Setup
			self.attachmentID = UUID().base64EncodedString
			self.revision = 1

			// Store
			self.info = info
			self.content = content
		}
	}

	// MARK: UpdateAttachmentInfo
	struct UpdateAttachmentInfo {

		// MARK: Properties
		let	attachmentID :String
		let	currentRevision :Int
		let	info :[String : Any]
		let	content :Data

		var	attachmentInfo :MDSDocument.AttachmentInfo
				{ MDSDocument.AttachmentInfo(id: self.attachmentID, revision: self.currentRevision, info: self.info) }
	}

	// MARK: RemoveAttachmentInfo
	struct RemoveAttachmentInfo {

		// MARK: Properties
		let	attachmentID :String
	}

	// MARK: DocumentInfo
	class DocumentInfo<T> {

		// MARK: Procs
		typealias ValueProc = (_ property :String) -> Any?

		// MARK: Properties
						let	documentType :String
						let	documentBacking :T?
						let	creationDate :Date

		private(set)	var	updatedPropertyMap :[String : Any]?
		private(set)	var	removedProperties :Set<String>?
		private(set)	var	modificationDate :Date
		private(set)	var	addAttachmentInfos = [AddAttachmentInfo]()
		private(set)	var	updateAttachmentInfos = [UpdateAttachmentInfo]()
		private(set)	var	removeAttachmentInfos = [RemoveAttachmentInfo]()
		private(set)	var	removed = false

		private			let	initialPropertyMap :[String : Any]?

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		fileprivate init(documentType :String, documentBacking :T?, creationDate :Date, modificationDate :Date,
				initialPropertyMap :[String : Any]?) {
			// Store
			self.documentType = documentType
			self.documentBacking = documentBacking
			self.creationDate = creationDate

			self.modificationDate = modificationDate

			self.initialPropertyMap = initialPropertyMap
		}

		// MARK: Instance methods
		//--------------------------------------------------------------------------------------------------------------
		func value(for property :String) -> Any? {
			// Check for document removed
			if self.removed {
				// Document removed
				return nil
			} else if self.removedProperties?.contains(property) ?? false {
				// Removed
				return nil
			} else {
				// Not removed
				return self.updatedPropertyMap?[property] ?? self.initialPropertyMap?[property]
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		func set(_ value :Any?, for property :String) {
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
					// Have removed properties
					self.removedProperties!.insert(property)
				} else {
					// First removed property
					self.removedProperties = Set<String>([property])
				}
			}

			// Modified
			self.modificationDate = Date()
		}

		//--------------------------------------------------------------------------------------------------------------
		func remove() { self.removed = true; self.modificationDate = Date() }

		//--------------------------------------------------------------------------------------------------------------
		func attachmentInfoMap(applyingChangesTo attachmentInfoMap :MDSDocument.AttachmentInfoMap) ->
				MDSDocument.AttachmentInfoMap {
			// Start with initial
			var	updatedAttachmentInfoMap = attachmentInfoMap

			// Process adds
			self.addAttachmentInfos.forEach()
					{ updatedAttachmentInfoMap[$0.attachmentID] = $0.attachmentInfo }

			// Process updates
			self.updateAttachmentInfos.forEach()
					{ updatedAttachmentInfoMap[$0.attachmentID] = $0.attachmentInfo }

			// Process removes
			updatedAttachmentInfoMap.removeValues(
					forKeys: self.removeAttachmentInfos.map({ $0.attachmentID }))

			return updatedAttachmentInfoMap
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentContent(for attachmentID :String) -> Data? {
			// Check if have info on attachment
			if let addAttachmentInfo = self.addAttachmentInfos.first(where: { $0.attachmentID == attachmentID}) {
				// Have add
				return addAttachmentInfo.content
			} else if let updateAttachmentInfo =
					self.updateAttachmentInfos.first(where: { $0.attachmentID == attachmentID} ) {
				// Have update
				return updateAttachmentInfo.content
			} else {
				// No valid attachment
				return nil
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentAdd(info :[String : Any], content :Data) -> MDSDocument.AttachmentInfo {
			// Setup
			let	addAttachmentInfo = AddAttachmentInfo(info: info, content: content)

			// Add info
			self.addAttachmentInfos.append(addAttachmentInfo)

			// Modified
			self.modificationDate = Date()

			return addAttachmentInfo.attachmentInfo
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentUpdate(attachmentID :String, currentRevision :Int, info :[String : Any], content :Data) {
			// Add info
			self.updateAttachmentInfos.append(
					UpdateAttachmentInfo(attachmentID: attachmentID, currentRevision: currentRevision, info: info,
							content: content))

			// Modified
			self.modificationDate = Date()
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentRemove(attachmentID :String) {
			// Add info
			self.removeAttachmentInfos.append(RemoveAttachmentInfo(attachmentID: attachmentID))

			// Modified
			self.modificationDate = Date()
		}
	}

	// MARK: Procs
	typealias AddAttachmentProc =
				(_ documentType :String, _ documentID :String, _ documentBacking :T?,
						_ addAttachmentInfo :AddAttachmentInfo) -> Void
	typealias UpdateAttachmentProc =
				(_ documentType :String, _ documentID :String, _ documentBacking :T?,
						_ updateAttachmentInfo :UpdateAttachmentInfo) -> Void
	typealias RemoveAttachmentProc =
				(_ documentType :String, _ documentID :String, _ documentBacking :T?,
						_ removeAttachmentInfo :RemoveAttachmentInfo) -> Void

	// MARK: Properties
	private	var	documentInfoMap = [/* Document ID */ String : DocumentInfo<T>]()
	private	let	documentInfoMapLock = ReadPreferringReadWriteLock()

	private	var	associationUpdatesByAssociationName = [/* Name */ String : [MDSAssociation.Update]]()

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
	func associationGetChanges(for name :String) -> [MDSAssociation.Update]? {
		// Return updates
		return self.associationUpdatesByAssociationName[name]
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAdd(documentType :String, documentID :String, documentBacking :T? = nil, creationDate :Date,
			modificationDate :Date, initialPropertyMap :[String : Any]? = nil) -> DocumentInfo<T> {
		// Setup
		let	documentInfo =
					DocumentInfo(documentType: documentType, documentBacking: documentBacking,
							creationDate: creationDate, modificationDate: modificationDate,
							initialPropertyMap: initialPropertyMap)

		// Store
		self.documentInfoMapLock.write() { self.documentInfoMap[documentID] = documentInfo }

		return documentInfo
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGetInfo(for documentID :String) -> DocumentInfo<T>? {
		// Return document info
		return self.documentInfoMapLock.read() { self.documentInfoMap[documentID] }
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentIterateChanges(
			_ proc
					:(_ documentType :String, _ documentInfoMap :[/* Document ID */ String : DocumentInfo<T>]) throws ->
							Void) rethrows {
		// Setup
		var	map = [/* Document Type */ String : [/* Document ID */ String : DocumentInfo<T>]]()
		self.documentInfoMapLock.read() {
			// Collect info
			self.documentInfoMap.forEach() {
				// Retrieve already collated batch document infos
				if var documentInfoMap = map[$0.value.documentType] {
					// Next document of this type
					map[$0.value.documentType] = nil
					documentInfoMap[$0.key] = $0.value
					map[$0.value.documentType] = documentInfoMap
				} else {
					// First document of this type
					map[$0.value.documentType] = [$0.key : $0.value]
				}
			}
		}

		// Process all document info
		try map.forEach() { try proc($0.key, $0.value) }
	}
}
