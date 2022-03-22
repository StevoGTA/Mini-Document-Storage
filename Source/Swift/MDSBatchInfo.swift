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
		private			let	lock = ReadPreferringReadWriteLock()

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(documentType :String, reference :T?, creationDate :Date, modificationDate :Date,
				valueProc :@escaping ValueProc) {
			// Store
			self.documentType = documentType
			self.reference = reference
			self.creationDate = creationDate

			self.modificationDate = modificationDate

			self.valueProc = valueProc
		}

		// MARK: Instance methods
		//--------------------------------------------------------------------------------------------------------------
		func value(for property :String) -> Any? {
			// Check for document removed
			if self.removed {
				// Document removed
				return nil
			} else if let (value, _) = self.lock.read({ () -> (value :Any?, removed :Bool)? in
						// Check the deal
						if self.removedProperties?.contains(property) ?? false {
							// Property removed
							return (nil, true)
						} else if let value = self.updatedPropertyMap?[property] {
							// Property updated
							return (value, false)
						} else {
							// Property neither removed nor updated
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
		}

		//--------------------------------------------------------------------------------------------------------------
		func remove() { self.lock.write() { self.removed = true; self.modificationDate = Date() } }
	}

	// MARK: AddAttachmentInfo
	struct AddAttachmentInfo {

		// MARK: Properties
		let	documentType :String
		let	documentID :String
		let	info :[String : Any]
		let	content :Data
	}

	// MARK: UpdateAttachmentInfo
	struct UpdateAttachmentInfo {

		// MARK: Properties
		let	documentType :String
		let	documentID :String
		let	attachmentID :String
		let	currentRevision :Int
		let	info :[String : Any]
		let	content :Data
	}

	// MARK: RemoveAttachmentInfo
	struct RemoveAttachmentInfo {

		// MARK: Properties
		let	documentType :String
		let	documentID :String
		let	attachmentID :String
	}

	// MARK: Properties
	private	var	documentInfoMap = [/* Document ID */ String : DocumentInfo<T>]()
	private	let	documentInfoMapLock = ReadPreferringReadWriteLock()

	private	var	addAttachmentInfos = [AddAttachmentInfo]()
	private	var	updateAttachmentInfos = [UpdateAttachmentInfo]()
	private	var	removeAttachmentInfos = [RemoveAttachmentInfo]()

	private	var	assocationUpdatesByAssocationName =
						[/* Name */ String :
								[(action :MDSAssociationAction, fromDocumentID :String, toDocumentID :String)]]()

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
		// Return document info
		return self.documentInfoMapLock.read() { self.documentInfoMap[documentID] }
	}

	//------------------------------------------------------------------------------------------------------------------
	func note(_ addAttachmentInfo :AddAttachmentInfo) { self.addAttachmentInfos.append(addAttachmentInfo) }

	//------------------------------------------------------------------------------------------------------------------
	func note(_ updateAttachmentInfo :UpdateAttachmentInfo) { self.updateAttachmentInfos.append(updateAttachmentInfo) }

	//------------------------------------------------------------------------------------------------------------------
	func note(_ removeAttachmentInfo :RemoveAttachmentInfo) { self.removeAttachmentInfos.append(removeAttachmentInfo) }

	//------------------------------------------------------------------------------------------------------------------
	func noteAssocationUpdated(for name :String,
			updates :[(action :MDSAssociationAction, fromDocumentID :String, toDocumentID :String)]) {
		// Add
		self.assocationUpdatesByAssocationName.appendArrayValueElements(key: name, values: updates)
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateDocumentChanges(
			_ proc
					:(_ documentType :String, _ documentInfoMap :[/* Document ID */ String : DocumentInfo<T>]) throws ->
							Void) rethrows {
		// Setup
		var	map = [/* Documewnt Type */ String : [/* Document ID */ String : DocumentInfo<T>]]()
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

	//------------------------------------------------------------------------------------------------------------------
	func iterateAttachmentChanges(addAttachmentProc :(_ addAttachmentInfo :AddAttachmentInfo) -> Void,
			updateAttachmentProc :(_ updateAttachmentInfo :UpdateAttachmentInfo) -> Void,
			removeAttachmentProc :(_ removeAttachmentInfo :RemoveAttachmentInfo) -> Void) {
		// Process attachment info
		self.removeAttachmentInfos.forEach() { removeAttachmentProc($0) }
		self.addAttachmentInfos.forEach() { addAttachmentProc($0) }
		self.updateAttachmentInfos.forEach() { updateAttachmentProc($0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func iterateAssocationChanges(
			proc :(_ name :String,
					_ updates :[(action :MDSAssociationAction, fromDocumentID :String, toDocumentID :String)]) -> Void) {
		// Iterate info
		self.assocationUpdatesByAssocationName.forEach() { proc($0.key, $0.value) }
	}
}
