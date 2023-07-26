//
//  MDSEphemeral.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSEphemeral
/*
	Strategy
		MDSEphemeral will ensure all Caches, Collections, and Indexes are kept up-to-date after any change that would
			affect them.
*/
public class MDSEphemeral : MDSDocumentStorageCore, MDSDocumentStorage {

	// MARK: Types
	private	typealias BatchInfo = MDSBatchInfo<[String : Any]>
	private	typealias BatchInfoDocumentInfo = BatchInfo.DocumentInfo<[String : Any]>

	// MARK: DocumentBacking
	private class DocumentBacking : MDSDocumentBacking {

		// MARK: Properties
		let	documentID :String
		let	creationDate :Date

		var	revision :Int
		var	active = true
		var	modificationDate :Date
		var	propertyMap :[String : Any]
		var	attachmentMap = [/* Attachment ID */ String : (attachmentInfo :MDSDocument.AttachmentInfo, content :Data)]()

		var	documentRevisionInfo :MDSDocument.RevisionInfo
				{ MDSDocument.RevisionInfo(documentID: self.documentID, revision: self.revision) }
		var	documentFullInfo :MDSDocument.FullInfo
				{ MDSDocument.FullInfo(documentID: self.documentID, revision: self.revision, active: self.active,
					creationDate: self.creationDate, modificationDate: self.modificationDate,
					propertyMap: self.propertyMap,
					attachmentInfoMap: self.attachmentMap.mapValues({ $0.attachmentInfo })) }

		var	documentAttachmentInfoMap :MDSDocument.AttachmentInfoMap
				{ self.attachmentMap.mapValues({ $0.attachmentInfo }) }

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(documentID :String, revision :Int, creationDate :Date, modificationDate :Date,
				propertyMap :[String : Any]) {
			// Store
			self.documentID = documentID
			self.creationDate = creationDate

			self.revision = revision
			self.modificationDate = modificationDate
			self.propertyMap = propertyMap
		}

		// MARK: Instance methods
		//--------------------------------------------------------------------------------------------------------------
		func update(revision :Int, updatedPropertyMap :[String : Any]? = nil, removedProperties :Set<String>? = nil) {
			// Update
			self.revision = revision
			self.modificationDate = Date()
			self.propertyMap.merge(updatedPropertyMap ?? [:], uniquingKeysWith: { $1 })
			removedProperties?.forEach() { self.propertyMap[$0] = nil }
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentAdd(revision :Int, info :[String : Any], content :Data) -> MDSDocument.AttachmentInfo {
			// Setup
			let	attachmentID = UUID().base64EncodedString
			let	documentAttachmentInfo = MDSDocument.AttachmentInfo(id: attachmentID, revision: 1, info: info)

			// Add
			self.attachmentMap[attachmentID] = (documentAttachmentInfo, content)

			// Update
			self.revision = revision
			self.modificationDate = Date()

			return documentAttachmentInfo
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentUpdate(revision :Int, attachmentID :String, updatedInfo :[String : Any], updatedContent :Data) ->
				Int {
			// Setup
			let	info = self.attachmentMap[attachmentID]!
			let	revision = info.attachmentInfo.revision + 1

			// Update
			self.attachmentMap[attachmentID] =
					(MDSDocument.AttachmentInfo(id: attachmentID, revision: revision, info: updatedInfo),
							updatedContent)

			return revision
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentRemove(revision :Int, attachmentID :String) {
			// Remove
			self.attachmentMap[attachmentID] = nil

			// Update
			self.revision = revision
			self.modificationDate = Date()
		}
	}

	// MARK: Properties
	private	var	associationsByNameMap = LockingDictionary</* Name */ String, MDSAssociation>()
	private	var	associationItemsByNameMap = LockingArrayDictionary</* Name */ String, MDSAssociation.Item>()

	private	let	batchInfoMap = LockingDictionary<Thread, BatchInfo>()

	private	let	cachesByNameMap = LockingDictionary</* Name */ String, MDSCache>()
	private	let	cachesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCache>()
	private	let	cacheValuesMap =
						LockingDictionary</* Cache Name */ String,
								[/* Document ID */ String : [/* Value Name */ String : /* Value */ Any]]>()

	private	let	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	let	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()
	private	let	collectionValuesMap = LockingDictionary</* Name */ String, /* Document IDs */ [String]>()

	private	var	documentBackingByIDMap = [/* Document ID */ String : DocumentBacking]()
	private	var	documentIDsByTypeMap = [/* Document Type */ String : /* Document IDs */ Set<String>]()
	private	let	documentLastRevisionMap = LockingDictionary</* Document type */ String, Int>()
	private	let	documentMapsLock = ReadPreferringReadWriteLock()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, [String : Any]>()

	private	let	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	let	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()
	private	let	indexValuesMap = LockingDictionary</* Name */ String, [/* Key */ String : /* Document ID */ String]>()

	private	var	info = [String : String]()
	private	var	`internal` = [String : String]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public override init() {}

	// MARK: MDSDocumentStorage methods
	//------------------------------------------------------------------------------------------------------------------
	public func associationRegister(named name :String, fromDocumentType :String, toDocumentType :String) throws {
		// Validate
		guard self.documentIDsByTypeMap[fromDocumentType] != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: fromDocumentType)
		}
		guard self.documentIDsByTypeMap[toDocumentType] != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: toDocumentType)
		}

		// Check if have association already
		if self.associationsByNameMap.value(for: name) == nil {
			// Create
			self.associationsByNameMap.set(
					MDSAssociation(name: name, fromDocumentType: fromDocumentType, toDocumentType: toDocumentType),
					for: name)
			self.associationItemsByNameMap.set([], for: name)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(for name :String) throws -> [MDSAssociation.Item] {
		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Get association items
		var	associationItems = self.documentMapsLock.read() { self.associationItems(for: name) }

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// Apply batch changes
			associationItems = batchInfo.associationItems(applyingChangesTo: associationItems, for: name)
		}

		return associationItems
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let association = self.associationsByNameMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByIDMap[fromDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}
		guard association.toDocumentType == toDocumentType else {
			throw MDSDocumentStorageError.invalidDocumentType(documentType: toDocumentType)
		}

		// Get association items
		var	associationItems = self.documentMapsLock.read() { self.associationItems(for: name) }

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// Apply batch changes
			associationItems = batchInfo.associationItems(applyingChangesTo: associationItems, for: name)
		}

		// Iterate association items
		let	documentCreateProc = self.documentCreateProc(for: toDocumentType)
		associationItems
				.filter({ $0.fromDocumentID == fromDocumentID })
				.forEach() { proc(documentCreateProc($0.toDocumentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, to toDocumentID :String, fromDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let association = self.associationsByNameMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByIDMap[toDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: toDocumentID)
		}
		guard association.fromDocumentType == fromDocumentType else {
			throw MDSDocumentStorageError.invalidDocumentType(documentType: fromDocumentType)
		}

		// Get association items
		var	associationItems = self.documentMapsLock.read() { self.associationItems(for: name) }

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// Apply batch changes
			associationItems = batchInfo.associationItems(applyingChangesTo: associationItems, for: name)
		}

		// Iterate association items
		let	documentCreateProc = self.documentCreateProc(for: fromDocumentType)
		associationItems
				.filter({ $0.toDocumentID == toDocumentID })
				.forEach() { proc(documentCreateProc($0.fromDocumentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetIntegerValues(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentIDs :[String], cacheName :String, cachedValueNames :[String]) throws -> [String : Int64] {
		// Setup
		let	fromDocumentIDsUse = Set<String>(fromDocumentIDs)

		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		try self.documentMapsLock.read() {
			// Iterate fromDocumentIDsUse
			try fromDocumentIDsUse.forEach() {
				// Check if have document with this id
				guard self.documentBackingByIDMap[$0] != nil else {
					throw MDSDocumentStorageError.unknownDocumentID(documentID: $0)
				}
			}
		}
		guard let cache = self.cachesByNameMap.value(for: cacheName) else {
			throw MDSDocumentStorageError.unknownCache(name: cacheName)
		}
		try cachedValueNames.forEach() {
			// Check if have info for this cachedValueName
			guard cache.valueInfo(for: $0) != nil else {
				throw MDSDocumentStorageError.unknownCacheValueName(valueName: $0)
			}
		}

		// Get association items
		var	associationItems = self.documentMapsLock.read() { self.associationItems(for: name) }

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// Apply batch changes
			associationItems = batchInfo.associationItems(applyingChangesTo: associationItems, for: name)
		}

		// Process associationItems
		let	cacheValueInfos = self.cacheValuesMap.value(for: cacheName)!
		var	results = [String : Int64]()
		associationItems
				.filter({ fromDocumentIDsUse.contains($0.fromDocumentID) })
				.forEach() {
					// Get value and sum
					let	valueInfos = cacheValueInfos[$0.toDocumentID]!

					// Iterate cachedValueNames
					cachedValueNames.forEach() { results[$0] = (results[$0] ?? 0) + ((valueInfos[$0] as? Int64) ?? 0) }
				}

		return results
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Check if have updates
		guard !updates.isEmpty else { return }

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// In batch
			batchInfo.associationNoteUpdated(for: name, updates: updates)
		} else {
			// Not in batch
			self.associationItemsByNameMap.remove(updates.filter({ $0.action == .remove }).map({ $0.item }), for: name)
			self.associationItemsByNameMap.append(updates.filter({ $0.action == .add }).map({ $0.item }), for: name)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			valueInfos :[(name :String, valueType :MDSValueType, selector :String, proc :MDSDocument.ValueProc)])
			throws {
		// Remove current cache if found
		if let cache = self.cachesByNameMap.value(for: name) {
			// Remove
			self.cachesByDocumentTypeMap.remove(cache, for: documentType)
		}

		// Create or re-create cache
		let	cache =
					MDSCache(name: name, documentType: documentType, relevantProperties: relevantProperties,
							valueInfos: valueInfos.map({ (MDSValueInfo(name: $0, type: $1), $3) }), lastRevision: 0)

		// Add to maps
		self.cachesByNameMap.set(cache, for: name)
		self.cachesByDocumentTypeMap.append(cache, for: documentType)

		// Bring up to date
		cacheUpdate(cache, updateInfos: self.updateInfos(for: documentType, sinceRevision: 0))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String,
			isIncludedProc :@escaping MDSDocument.IsIncludedProc) throws {
		// Remove current collection if found
		if let collection = self.collectionsByNameMap.value(for: name) {
			// Remove
			self.collectionsByDocumentTypeMap.remove(collection, for: documentType)
		}

		// Create or re-create collection
		let	collection =
					MDSCollection(name: name, documentType: documentType, relevantProperties: relevantProperties,
							isIncludedProc: isIncludedProc, isIncludedInfo: isIncludedInfo,
							lastRevision: isUpToDate ? (self.documentLastRevisionMap.value(for: documentType) ?? 0) : 0)

		// Add to maps
		self.collectionsByNameMap.set(collection, for: name)
		self.collectionsByDocumentTypeMap.append(collection, for: documentType)

		// Check if is up to date
		if !isUpToDate {
			// Bring up to date
			collectionUpdate(collection, updateInfos: self.updateInfos(for: documentType, sinceRevision: 0))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionGetDocumentCount(for name :String) throws -> Int {
		// Validate
		guard let documentIDs = self.collectionValuesMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}
		guard self.batchInfoMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		return documentIDs.count
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let documentIDs = self.collectionValuesMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}
		guard self.batchInfoMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Setup
		let	documentCreateProc = self.documentCreateProc(for: documentType)

		// Iterate
		documentIDs.forEach() { proc(documentCreateProc($0, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
			proc :MDSDocument.CreateProc) throws ->
			[(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)] {
		// Setup
		let	date = Date()
		var	infos = [(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)]()

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// In batch
			documentCreateInfos.forEach() {
				// Setup
				let	documentID = $0.documentID ?? UUID().base64EncodedString

				// Add document
				_ = batchInfo.documentAdd(documentType: documentType, documentID: documentID,
						creationDate: $0.creationDate ?? date, modificationDate: $0.modificationDate ?? date,
						initialPropertyMap: !$0.propertyMap.isEmpty ? $0.propertyMap : nil)
				infos.append((proc(documentID, self), nil))
			}
		} else {
			// Setup
			let	documentChangedProcs = self.documentChangedProcs(for: documentType)
			var	updateInfos = [MDSUpdateInfo<String>]()

			// Iterate document create infos
			documentCreateInfos.forEach() {
				// Setup
				let	documentID = $0.documentID ?? UUID().base64EncodedString

				// Will be creating document
				self.documentsBeingCreatedPropertyMapMap.set($0.propertyMap, for: documentID)

				// Create
				let	document = proc(documentID, self)

				// Remove property map
				let	propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID)!
				self.documentsBeingCreatedPropertyMapMap.remove(documentID)

				// Add document
				let	revision = nextRevision(for: documentType)
				let	creationDate = $0.creationDate ?? date
				let	modificationDate = $0.modificationDate ?? date
				let	documentBacking =
							DocumentBacking(documentID: documentID, revision: revision, creationDate: creationDate,
									modificationDate: modificationDate, propertyMap: propertyMap)
				self.documentMapsLock.write() {
					// Update maps
					self.documentBackingByIDMap[documentID] = documentBacking
					self.documentIDsByTypeMap.insertSetValueElement(key: documentType, value: documentID)
				}
				infos.append(
						(document,
								MDSDocument.OverviewInfo(documentID: documentID, revision: revision,
										creationDate: creationDate, modificationDate: modificationDate)))

				// Call document changed procs
				documentChangedProcs?.forEach() { $0(document, .created) }

				// Add update info
				updateInfos.append(
						MDSUpdateInfo<String>(document: document, revision: documentBacking.revision, id: documentID,
								changedProperties: Set<String>(propertyMap.keys)))
			}

			// Update stuffs
			update(for: documentType, updateInfos: updateInfos)
		}

		return infos
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentGetCount(for documentType :String) throws -> Int {
		// Validate
		guard let documentIDs = self.documentMapsLock.read({ self.documentIDsByTypeMap[documentType] }) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}
		guard self.batchInfoMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		return documentIDs.count
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, documentIDs :[String],
			documentCreateProc :MDSDocument.CreateProc, proc :(_ document :MDSDocument) -> Void) throws {
		// Setup
		let	batchInfo = self.batchInfoMap.value(for: .current)

		// Iterate initial document IDs
		var	documentIDsToIterate = [String]()
		documentIDs.forEach() {
			// Check what we have currently
			if batchInfo?.documentGetInfo(for: $0) != nil {
				// Have document in batch
				proc(documentCreateProc($0, self))
			} else {
				// Will need to iterate
				documentIDsToIterate.append($0)
			}
		}

		// Iterate document backings
		try documentBackingsIterate(for: documentType, documentIDs: documentIDsToIterate,
				proc: { proc(documentCreateProc($0.documentID, self)) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, activeOnly: Bool, documentCreateProc :MDSDocument.CreateProc,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard self.batchInfoMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Iterate document backings
		try documentBackingsIterate(for: documentType, sinceRevision: 0, count: nil, activeOnly: activeOnly,
				proc: { proc(documentCreateProc($0.documentID, self)) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
			// In batch
			return batchInfoDocumentInfo.creationDate
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// "Idle"
			return self.documentMapsLock.read() { self.documentBackingByIDMap[document.id]?.creationDate ?? Date() }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentModificationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
			// In batch
			return batchInfoDocumentInfo.modificationDate
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// "Idle"
			return self.documentMapsLock.read() { self.documentBackingByIDMap[document.id]?.modificationDate ?? Date() }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentValue(for property :String, of document :MDSDocument) -> Any? {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
			// In batch
			return batchInfoDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			return propertyMap[property]
		} else {
			// "Idle"
			return self.documentMapsLock.read() { self.documentBackingByIDMap[document.id]?.propertyMap[property] }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentData(for property :String, of document :MDSDocument) -> Data? {
		// Return data
		return documentValue(for: property, of: document) as? Data
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentDate(for property :String, of document :MDSDocument) -> Date? {
		// Return date
		return documentValue(for: property, of: document) as? Date
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentSet<T : MDSDocument>(_ value :Any?, for property :String, of document :T) {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// In batch
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
				// Have document in batch
				batchInfoDocumentInfo.set(value, for: property)
			} else {
				// Don't have document in batch
				let	date = Date()
				batchInfo.documentAdd(documentType: documentType, documentID: document.id,
						creationDate: date, modificationDate: date,
						initialPropertyMap:
								self.documentMapsLock.read()
									{ self.documentBackingByIDMap[document.id]?.propertyMap })
					.set(value, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			propertyMap[property] = value
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: document.id)
		} else {
			// Update document
			let	documentBacking :DocumentBacking =
						self.documentMapsLock.write() {
							// Setup
							let	documentBacking = self.documentBackingByIDMap[document.id]!

							// Update
							documentBacking.propertyMap[property] = value

							return documentBacking
						}

			// Update stuffs
			update(for: documentType,
					updateInfos:
							[MDSUpdateInfo<String>(document: document, revision: documentBacking.revision,
									id: document.id, changedProperties: [property])])

			// Call document changed procs
			self.documentChangedProcs(for: documentType)?.forEach() { $0(document, .updated) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any],
			content :Data) throws -> MDSDocument.AttachmentInfo {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByTypeMap[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// In batch
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
				// Have document in batch
				return batchInfoDocumentInfo.attachmentAdd(info: info, content: content)
			} else {
				// Don't have document in batch
				let	propertyMap =
							try self.documentMapsLock.read() { () -> [String : Any] in
								// Validate
								guard let documentBacking = self.documentBackingByIDMap[documentID] else {
									throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
								}

								return documentBacking.propertyMap
							}
				let	date = Date()

				return batchInfo.documentAdd(documentType: documentType, documentID: documentID,
								creationDate: date, modificationDate: date, initialPropertyMap: propertyMap)
						.attachmentAdd(info: info, content: content)
			}
		} else {
			// Not in batch
			return try self.documentMapsLock.write() {
				// Setup
				if let documentBacking = self.documentBackingByIDMap[documentID] {
					// Add attachment
					return documentBacking.attachmentAdd(revision: self.nextRevision(for: documentType), info: info,
							content: content)
				} else {
					// No document
					throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
				}
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentInfoMap(for documentType :String, documentID :String) throws ->
			MDSDocument.AttachmentInfoMap {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByTypeMap[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
			// Have document in batch
			return batchInfoDocumentInfo.attachmentInfoMap(
					applyingChangesTo: self.documentBackingByIDMap[documentID]!.documentAttachmentInfoMap)
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: documentID) != nil {
			// Creating
			return [:]
		} else if let documentAttachmentInfoMap =
				self.documentMapsLock.read({ self.documentBackingByIDMap[documentID]?.documentAttachmentInfoMap }) {
			// Not in batch and not creating
			return documentAttachmentInfoMap
		} else {
			// Unknown documentID
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws ->
			Data {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByTypeMap[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
			// Have document in batch
			if let content = batchInfoDocumentInfo.attachmentContent(for: attachmentID) {
				// Found
				return content
			}
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: documentID) != nil {
			// Creating
			throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
		}

		// Get non-batch attachmentMap
		guard let attachmentMap =
				self.documentMapsLock.read({ self.documentBackingByIDMap[documentID]?.attachmentMap }) else {
			// Unknown documentID
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}
		guard let documentAttachmentInfo = attachmentMap[attachmentID] else {
			// Don't have attachment
			throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
		}

		return documentAttachmentInfo.content
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByTypeMap[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}
		guard let documentBacking = self.documentMapsLock.read({ self.documentBackingByIDMap[documentID] }) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// In batch
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
				// Have document in batch
				let	documentAttachmentInfoMap =
							batchInfoDocumentInfo.attachmentInfoMap(
									applyingChangesTo: documentBacking.documentAttachmentInfoMap)
				guard let attachmentInfo = documentAttachmentInfoMap[attachmentID] else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batchInfoDocumentInfo.attachmentUpdate(attachmentID: attachmentID,
						currentRevision: attachmentInfo.revision, info: updatedInfo, content: updatedContent)
			} else {
				// Don't have document in batch
				guard let attachmentInfo = documentBacking.attachmentMap[attachmentID]?.attachmentInfo else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}
				let	date = Date()

				batchInfo.documentAdd(documentType: documentType, documentID: documentID, creationDate: date,
								modificationDate: date,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentUpdate(attachmentID: attachmentID, currentRevision: attachmentInfo.revision,
								info: updatedInfo, content: updatedContent)
			}

			return -1
		} else {
			// Not in batch
			return try self.documentMapsLock.write() {
				// Validate
				guard documentBacking.attachmentMap[attachmentID] != nil else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				// Update attachment
				return documentBacking.attachmentUpdate(revision: self.nextRevision(for: documentType),
						attachmentID: attachmentID, updatedInfo: updatedInfo, updatedContent: updatedContent)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByTypeMap[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}
		guard let documentBacking = self.documentMapsLock.read({ self.documentBackingByIDMap[documentID] }) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// In batch
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
				// Have document in batch
				let	documentAttachmentInfoMap =
							batchInfoDocumentInfo.attachmentInfoMap(
									applyingChangesTo: documentBacking.documentAttachmentInfoMap)
				guard documentAttachmentInfoMap[attachmentID] != nil else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batchInfoDocumentInfo.attachmentRemove(attachmentID: attachmentID)
			} else {
				// Don't have document in batch
				guard documentBacking.attachmentMap[attachmentID] != nil else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}
				let	date = Date()

				return batchInfo.documentAdd(documentType: documentType, documentID: documentID,
								creationDate: date, modificationDate: date,
								initialPropertyMap:
										self.documentMapsLock.read()
											{ self.documentBackingByIDMap[documentID]?.propertyMap })
						.attachmentRemove(attachmentID: attachmentID)
			}
		} else {
			// Not in batch
			return try self.documentMapsLock.write() {
				// Validate
				guard documentBacking.attachmentMap[attachmentID] != nil else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				// Remove attachment
				documentBacking.attachmentRemove(revision: self.nextRevision(for: documentType),
						attachmentID: attachmentID)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentRemove(_ document :MDSDocument) throws {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// In batch
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
				// Have document in batch
				batchInfoDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	date = Date()
				batchInfo.documentAdd(documentType: documentType, documentID: document.id, creationDate: date,
								modificationDate: date)
						.remove()
			}
		} else {
			// Not in batch
			self.documentMapsLock.write() { self.documentBackingByIDMap[document.id]?.active = false }

			// Remove
			note(removedDocumentIDs: Set<String>([document.id]))

			// Call document changed procs
			self.documentChangedProcs(for: documentType)?.forEach() { $0(document, .removed) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister(name :String, documentType :String, relevantProperties :[String],
			keysInfo :[String : Any], keysSelector :String, keysProc :@escaping MDSDocument.KeysProc) throws {
		// Remove current index if found
		if let index = self.indexesByNameMap.value(for: name) {
			// Remove
			self.indexesByDocumentTypeMap.remove(index, for: documentType)
		}

		// Create or re-create index
		let	index =
					MDSIndex(name: name, documentType: documentType, relevantProperties: relevantProperties,
							keysProc: keysProc, keysInfo: keysInfo, lastRevision: 0)

		// Add to maps
		self.indexesByNameMap.set(index, for: name)
		self.indexesByDocumentTypeMap.append(index, for: documentType)

		// Bring up to date
		indexUpdate(index, updateInfos: self.updateInfos(for: documentType, sinceRevision: 0))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws {
		// Validate
		guard let items = self.indexValuesMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}
		guard self.batchInfoMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Setup
		let	documentCreateProc = self.documentCreateProc(for: documentType)

		// Iterate keys
		try keys.forEach() {
			// Retrieve documentID
			guard let documentID = items[$0] else {
				throw MDSDocumentStorageError.missingFromIndex(key: $0)
			}

			// Call proc
			proc($0, documentCreateProc(documentID, self))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) throws -> [String : String] { self.info.filter({ keys.contains($0.key) }) }

	//------------------------------------------------------------------------------------------------------------------
	public func infoSet(_ info :[String : String]) throws { self.info.merge(info, uniquingKeysWith: { $1 }) }

	//------------------------------------------------------------------------------------------------------------------
	public func remove(keys :[String]) { keys.forEach() { self.info[$0] = nil } }

	//------------------------------------------------------------------------------------------------------------------
	public func internalGet(for keys :[String]) -> [String : String] {
		// Return info
		return self.internal.filter({ keys.contains($0.key) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalSet(_ info :[String : String]) throws { self.internal.merge(info, uniquingKeysWith: { $1 }) }

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Setup
		let	batchInfo = BatchInfo()

		// Store
		self.batchInfoMap.set(batchInfo, for: .current)

		// Run lean
		var	result = MDSBatchResult.commit
		try autoreleasepool() {
			// Call proc
			result = try proc()
		}

		// Check result
		if result == .commit {
			// Iterate all document changes
			batchInfo.documentIterateChanges() { documentType, batchInfoDocumentInfosMap in
				// Setup
				let	documentCreateProc = self.documentCreateProc(for: documentType)
				let	documentChangedProcs = self.documentChangedProcs(for: documentType)

				var	updateInfos = [MDSUpdateInfo<String>]()
				var	removedDocumentIDs = Set<String>()

				let	process
							:(_ documentID :String, _ batchInfoDocumentInfo :BatchInfoDocumentInfo,
									_ documentBacking :DocumentBacking,
									_ changedProperties :Set<String>?, _ changeKind :MDSDocument.ChangeKind) -> Void =
							{ documentID, batchInfoDocumentInfo, documentBacking, changedProperties, changeKind in
								// Process attachments
								batchInfoDocumentInfo.removeAttachmentInfos.forEach() {
									// Remove attachment
									documentBacking.attachmentRemove(revision: documentBacking.revision,
											attachmentID: $0.attachmentID)
								}
								batchInfoDocumentInfo.addAttachmentInfos.forEach() {
									// Add attachment
									_ = documentBacking.attachmentAdd(revision: documentBacking.revision, info: $0.info,
											content: $0.content)
								}
								batchInfoDocumentInfo.updateAttachmentInfos.forEach() {
									// Update attachment
									_ = documentBacking.attachmentUpdate(revision: documentBacking.revision,
											attachmentID: $0.attachmentID, updatedInfo: $0.info,
											updatedContent: $0.content)
								}

								// Check if have changed procs
								if documentChangedProcs != nil {
									// Create document
									let	document = documentCreateProc(documentID, self)

									// Note update info
									let	changedProperties =
												Set<String>((batchInfoDocumentInfo.updatedPropertyMap ?? [:]).keys)
														.union(batchInfoDocumentInfo.removedProperties ?? Set<String>())
									updateInfos.append(
											MDSUpdateInfo<String>(document: document,
													revision: documentBacking.revision, id: documentID,
													changedProperties: changedProperties))

									// Call document changed procs
									documentChangedProcs!.forEach() { $0(document, changeKind) }
								}
							}

				// Update documents
				batchInfoDocumentInfosMap.forEach() { documentID, batchInfoDocumentInfo in
					// Check removed
					if !batchInfoDocumentInfo.removed {
						// Add/update document
						self.documentMapsLock.write() {
							// Retrieve existing document
							if let documentBacking = self.documentBackingByIDMap[documentID] {
								// Update document backing
								documentBacking.update(revision: nextRevision(for: documentType),
										updatedPropertyMap: batchInfoDocumentInfo.updatedPropertyMap,
										removedProperties: batchInfoDocumentInfo.removedProperties)

								// Process
								let	changedProperties =
											Set<String>((batchInfoDocumentInfo.updatedPropertyMap ?? [:]).keys)
													.union(batchInfoDocumentInfo.removedProperties ?? Set<String>())
								process(documentID, batchInfoDocumentInfo, documentBacking, changedProperties,
										.updated)
							} else {
								// Add document
								let	documentBacking =
											DocumentBacking(documentID: documentID,
													revision: nextRevision(for: documentType),
													creationDate: batchInfoDocumentInfo.creationDate,
													modificationDate: batchInfoDocumentInfo.modificationDate,
													propertyMap: batchInfoDocumentInfo.updatedPropertyMap ?? [:])
								self.documentBackingByIDMap[documentID] = documentBacking
								self.documentIDsByTypeMap.insertSetValueElement(key: documentType, value: documentID)

								// Process
								process(documentID, batchInfoDocumentInfo, documentBacking, nil, .created)
							}
						}
					} else {
						// Remove document
						removedDocumentIDs.insert(documentID)

						self.documentMapsLock.write() {
							// Update maps
							self.documentBackingByIDMap[documentID]?.active = false

							// Check if have changed procs
							if let documentChangedProcs {
								// Create document
								let	document = documentCreateProc(documentID, self)

								// Call document changed procs
								documentChangedProcs.forEach() { $0(document, .removed) }
							}
						}
					}
				}

				// Update stuffs
				note(removedDocumentIDs: removedDocumentIDs)
				update(for: documentType, updateInfos: updateInfos)
			}

			// Iterate all association changes
			batchInfo.associationIterateChanges() { name, updates in
				// Update association
				self.associationItemsByNameMap.remove(updates.filter({ $0.action == .remove }).map({ $0.item }),
						for: name)
				self.associationItemsByNameMap.append(updates.filter({ $0.action == .add }).map({ $0.item }), for: name)
			}
		}

		// Remove
		self.batchInfoMap.set(nil, for: .current)
	}

	// MARK: MDSHTTPServicesHandler methods
	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByIDMap[fromDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}
		guard startIndex >= 0 else {
			throw MDSDocumentStorageError.invalidStartIndex(startIndex: startIndex)
		}
		guard (count == nil) || (count! > 0) else {
			throw MDSDocumentStorageError.invalidCount(count: count!)
		}

		// Get document IDs
		let	associationItems = associationItems(for: name)
		let	documentIDs = associationItems.filter({ $0.fromDocumentID == fromDocumentID }).map({ $0.toDocumentID })
		guard !documentIDs.isEmpty else { return (0, []) }

		// Figure documentIDs to process
		let	documentIDsToProcess =
					(count != nil) ? documentIDs[startIndex...(startIndex + count!)] : documentIDs[startIndex...]

		// Retrieve document revision infos
		let	documentRevisionInfos =
					self.documentMapsLock.read() {
						documentIDsToProcess.map() { self.documentBackingByIDMap[$0]!.documentRevisionInfo }
					}

		return (documentIDs.count, Array(documentRevisionInfos))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws
			-> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByIDMap[toDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: toDocumentID)
		}
		guard startIndex >= 0 else {
			throw MDSDocumentStorageError.invalidStartIndex(startIndex: startIndex)
		}
		guard (count == nil) || (count! > 0) else {
			throw MDSDocumentStorageError.invalidCount(count: count!)
		}

		// Get document IDs
		let	associationItems = associationItems(for: name)
		let	documentIDs = associationItems.filter({ $0.toDocumentID == toDocumentID }).map({ $0.fromDocumentID })
		guard !documentIDs.isEmpty else { return (0, []) }

		// Figure documentIDs to process
		let	documentIDsToProcess =
					(count != nil) ? documentIDs[startIndex...(startIndex + count!)] : documentIDs[startIndex...]

		// Retrieve document revision infos
		let	documentRevisionInfos =
					self.documentMapsLock.read() {
						documentIDsToProcess.map() { self.documentBackingByIDMap[$0]!.documentRevisionInfo }
					}

		return (documentIDs.count, Array(documentRevisionInfos))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?) throws
			-> (totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByIDMap[fromDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}
		guard startIndex >= 0 else {
			throw MDSDocumentStorageError.invalidStartIndex(startIndex: startIndex)
		}
		guard (count == nil) || (count! > 0) else {
			throw MDSDocumentStorageError.invalidCount(count: count!)
		}

		// Get document IDs
		let	associationItems = associationItems(for: name)
		let	documentIDs = associationItems.filter({ $0.fromDocumentID == fromDocumentID }).map({ $0.toDocumentID })
		guard !documentIDs.isEmpty else { return (0, []) }

		// Figure documentIDs to process
		let	documentIDsToProcess =
					(count != nil) ? documentIDs[startIndex...(startIndex + count!)] : documentIDs[startIndex...]

		// Get document full infos
		let	documentFullInfos =
					self.documentMapsLock.read() {
						documentIDsToProcess.map() { self.documentBackingByIDMap[$0]!.documentFullInfo }
					}

		return (documentIDs.count, Array(documentFullInfos))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByIDMap[toDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: toDocumentID)
		}
		guard startIndex >= 0 else {
			throw MDSDocumentStorageError.invalidStartIndex(startIndex: startIndex)
		}
		guard (count == nil) || (count! > 0) else {
			throw MDSDocumentStorageError.invalidCount(count: count!)
		}

		// Get document IDs
		let	associationItems = associationItems(for: name)
		let	documentIDs = associationItems.filter({ $0.toDocumentID == toDocumentID }).map({ $0.fromDocumentID })
		guard !documentIDs.isEmpty else { return (0, []) }

		// Figure documentIDs to process
		let	documentIDsToProcess =
					(count != nil) ? documentIDs[startIndex...(startIndex + count!)] : documentIDs[startIndex...]

		// Get document full infos
		let	documentFullInfos =
					self.documentMapsLock.read() {
						documentIDsToProcess.map() { self.documentBackingByIDMap[$0]!.documentFullInfo }
					}

		return (documentIDs.count, Array(documentFullInfos))
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentRevisionInfos(name :String, startIndex :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
		// Validate
		guard let documentIDs = self.collectionValuesMap.value(for: name)?[startIndex...].prefix(count ?? Int.max) else
				{ throw MDSDocumentStorageError.unknownCollection(name: name) }

		// Process documentIDs
		guard !documentIDs.isEmpty else { return [] }

		return self.documentMapsLock.read() {
			documentIDs.map() { self.documentBackingByIDMap[$0]!.documentRevisionInfo }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentFullInfos(name :String, startIndex :Int, count :Int?) throws -> [MDSDocument.FullInfo] {
		// Validate
		guard let documentIDs = self.collectionValuesMap.value(for: name)?[startIndex...].prefix(count ?? Int.max) else
				{ throw MDSDocumentStorageError.unknownCollection(name: name) }

		// Process documentIDs
		guard !documentIDs.isEmpty else { return [] }

		return self.documentMapsLock.read() {
			documentIDs.map() { self.documentBackingByIDMap[$0]!.documentFullInfo }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRevisionInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.RevisionInfo] {
		// Iterate document backings
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		try documentBackingsIterate(for: documentType, documentIDs: documentIDs)
				{ documentRevisionInfos.append($0.documentRevisionInfo) }

		return documentRevisionInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRevisionInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
		// Iterate document backings
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		try documentBackingsIterate(for: documentType, sinceRevision: sinceRevision, count: count, activeOnly: false)
				{ documentRevisionInfos.append($0.documentRevisionInfo) }

		return documentRevisionInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentFullInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.FullInfo] {
		// Iterate document backings
		var	documentFullInfos = [MDSDocument.FullInfo]()
		try documentBackingsIterate(for: documentType, documentIDs: documentIDs)
				{ documentFullInfos.append($0.documentFullInfo) }

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentFullInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.FullInfo] {
		// Iterate document backings
		var	documentFullInfos = [MDSDocument.FullInfo]()
		try documentBackingsIterate(for: documentType, sinceRevision: sinceRevision, count: count, activeOnly: false)
				{ documentFullInfos.append($0.documentFullInfo) }

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentIntegerValue(for documentType :String, document :MDSDocument, property :String) -> Int64? {
		// Check for batch
		let	value :Any?
		if let batchInfo = self.batchInfoMap.value(for: .current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
			// In batch
			value = batchInfoDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			value = propertyMap[property]
		} else {
			// "Idle"
			value = self.documentMapsLock.read() { self.documentBackingByIDMap[document.id]?.propertyMap[property] }
		}

		return value as? Int64
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentStringValue(for documentType :String, document :MDSDocument, property :String) -> String? {
		// Check for batch
		let	value :Any?
		if let batchInfo = self.batchInfoMap.value(for: .current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
			// In batch
			value = batchInfoDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			value = propertyMap[property]
		} else {
			// "Idle"
			value = self.documentMapsLock.read() { self.documentBackingByIDMap[document.id]?.propertyMap[property] }
		}

		return value as? String
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo] {
		// Validate
		guard self.documentIDsByTypeMap[documentType] != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Setup
		let	documentCreateProc = self.documentCreateProc(for: documentType)
		let	documentChangedProcs = self.documentChangedProcs(for: documentType)
		var	updateInfos = [MDSUpdateInfo<String>]()
		var	removedDocumentIDs = Set<String>()
		var	documentFullInfos = [MDSDocument.FullInfo]()

		// Iterate document update infos
		documentUpdateInfos.forEach() {
			// Setup
			let	documentID = $0.documentID
			let	updated = $0.updated
			let	removed = $0.removed

			// Check active
			if $0.active {
				// Update document
				self.documentMapsLock.write() {
					// Retrieve existing document backing
					guard let documentBacking = self.documentBackingByIDMap[documentID] else { return }

					// Update document backing
					documentBacking.update(revision: nextRevision(for: documentType), updatedPropertyMap: updated,
							removedProperties: removed)

					// Check if have changed procs
					if documentChangedProcs != nil {
						// Create document
						let	document = documentCreateProc(documentID, self)

						// Note update infos
						updateInfos.append(
								MDSUpdateInfo<String>(document: document,
										revision: documentBacking.revision, id: documentID,
										changedProperties: Set<String>(updated.keys).union(removed)))

						// Call document changed procs
						documentChangedProcs!.forEach() { $0(document, .created) }
					}

					// Add full info
					documentFullInfos.append(documentBacking.documentFullInfo)
				}
			} else {
				// Remove document
				removedDocumentIDs.insert(documentID)

				self.documentMapsLock.write() {
					// Retrieve existing document backing
					guard let documentBacking = self.documentBackingByIDMap[documentID] else { return }

					// Update active
					documentBacking.active = false

					// Check if have document changed procs and can create document
					if documentChangedProcs != nil {
						// Call document changed procs
						let document = documentCreateProc(documentID, self)
						documentChangedProcs!.forEach() { $0(document, .removed) }
					}

					// Add full info
					documentFullInfos.append(documentBacking.documentFullInfo)
				}
			}
		}

		// Update stuffs
		note(removedDocumentIDs: removedDocumentIDs)
		update(for: documentType, updateInfos: updateInfos)

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentRevisionInfos(name :String, keys :[String]) throws -> [String : MDSDocument.RevisionInfo] {
		// Validate
		guard let items = self.indexValuesMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		return try self.documentMapsLock.read() {
			Dictionary(try keys.map({
				// Retrieve documentID
				guard let documentID = items[$0] else {
					throw MDSDocumentStorageError.missingFromIndex(key: $0)
				}

				return ($0, self.documentBackingByIDMap[documentID]!.documentRevisionInfo)
			}))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentFullInfos(name :String, keys :[String]) throws -> [String : MDSDocument.FullInfo] {
		// Validate
		guard let items = self.indexValuesMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		return try self.documentMapsLock.read() {
			Dictionary(try keys.map({
				// Retrieve documentID
				guard let documentID = items[$0] else {
					throw MDSDocumentStorageError.missingFromIndex(key: $0)
				}

				return ($0, self.documentBackingByIDMap[documentID]!.documentFullInfo)
			}))
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func associationItems(for name :String) -> [MDSAssociation.Item] {
		// Setup
		var associationItems = self.associationItemsByNameMap.values(for: name)!

		// Process batch updates
		if let batchInfo = self.batchInfoMap.value(for: .current) {
			// Apply batch changes
			associationItems = batchInfo.associationItems(applyingChangesTo: associationItems, for: name)
		}

		return associationItems
	}

	//------------------------------------------------------------------------------------------------------------------
	private func cacheUpdate(_ cache :MDSCache, updateInfos :[MDSUpdateInfo<String>]) {
		// Update Cache
		let	(infosByValue, _) = cache.update(updateInfos)

		// Check if have updates
		if infosByValue != nil {
			// Update storage
			self.cacheValuesMap.update(for: cache.name, with: { ($0 ?? [:])
					.merging(infosByValue!, uniquingKeysWith: { $1 }) })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func collectionUpdate(_ collection :MDSCollection, updateInfos :[MDSUpdateInfo<String>]) {
		// Update Collection
		let	(includedIDs, notIncludedIDs, _) = collection.update(updateInfos)

		// Check if have updates
		if (includedIDs != nil) || (notIncludedIDs != nil) {
			// Setup
			let	notIncludedIDsUse = Set<String>(notIncludedIDs ?? [])

			// Update storage
			self.collectionValuesMap.update(for: collection.name) {
				// Compose updated values
				let	updatedValues = ($0 ?? []).filter({ !notIncludedIDsUse.contains($0) }) + (includedIDs ?? [])

				return !updatedValues.isEmpty ? updatedValues : nil
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate(for documentType :String, documentIDs :[String],
			proc :(_ documentBacking :DocumentBacking) -> Void) throws {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByTypeMap[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Retrieve document backings
		let	documentBackings =
				try self.documentMapsLock.read() { try documentIDs.map() { documentID -> DocumentBacking in
					// Validate
					guard let documentBacking = self.documentBackingByIDMap[documentID] else {
						throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
					}

					return documentBacking
				} }

		// Iterate document backings
		documentBackings.forEach({ proc($0) })
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate(for documentType :String, sinceRevision :Int, count :Int?, activeOnly: Bool,
			proc :(_ documentBacking :DocumentBacking) -> Void) throws {
		// Retrieve document backings
		let	documentBackings =
					try self.documentMapsLock.read() { () -> [DocumentBacking] in
						// Collect DocumentBackings
						guard let documentBackings = self.documentIDsByTypeMap[documentType] else {
							throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
						}

						return documentBackings
								.map({ self.documentBackingByIDMap[$0]! })
								.filter({ ($0.revision > sinceRevision) && (!activeOnly || $0.active) })
								.map({ $0 })
					}

		// Check if have count
		if count != nil {
			// Have count
			documentBackings.sorted(by: { $0.revision < $1.revision })[..<count!].forEach({ proc($0) })
		} else {
			// Don't have count
			documentBackings.forEach({ proc($0) })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func indexUpdate(_ index :MDSIndex, updateInfos :[MDSUpdateInfo<String>]) {
		// Update Index
		let	(keysInfos, _) = index.update(updateInfos)

		// Check if have updates
		if keysInfos != nil {
			// Update storage
			let	documentIDs = Set<String>(keysInfos!.map({ $0.id }))
			self.indexValuesMap.update(for: index.name) {
				// Filter out document IDs included in update
				var	updatedValueInfo = ($0 ?? [:]).filter({ !documentIDs.contains($0.value) })

				// Add/Update keys => document IDs
				keysInfos!.forEach() { keys, value in keys.forEach() { updatedValueInfo[$0] = value } }

				return !updatedValueInfo.isEmpty ? updatedValueInfo : nil
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func nextRevision(for documentType :String) -> Int {
		// Compose next revision
		let	nextRevision = (self.documentLastRevisionMap.value(for: documentType) ?? 0) + 1

		// Store
		self.documentLastRevisionMap.set(nextRevision, for: documentType)

		return nextRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateInfos(for documentType :String, sinceRevision: Int) -> [MDSUpdateInfo<String>] {
		// Collect update infos
		let	documentCreateProc = self.documentCreateProc(for: documentType)
		var	updateInfos = [MDSUpdateInfo<String>]()
		try! documentBackingsIterate(for: documentType, sinceRevision: sinceRevision, count: nil, activeOnly: false,
				proc: {
					// Append MDSUpdateInfo
					updateInfos.append(
							MDSUpdateInfo<String>(document: documentCreateProc($0.documentID, self),
									revision: $0.revision, id: $0.documentID))
				})

		return updateInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	private func update(for documentType :String, updateInfos :[MDSUpdateInfo<String>]) {
		// Update caches
		self.cachesByDocumentTypeMap.values(for: documentType)?.forEach()
			{ self.cacheUpdate($0, updateInfos: updateInfos) }

		// Update collections
		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach()
			{ self.collectionUpdate($0, updateInfos: updateInfos) }

		// Update indexes
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach()
			{ self.indexUpdate($0, updateInfos: updateInfos) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func note(removedDocumentIDs documentIDs :Set<String>) {
		// Iterate all caches
		self.cacheValuesMap.keys.forEach()
			{ self.cacheValuesMap.update(for: $0, with: { $0?.filter({ !documentIDs.contains($0.key) }) }) }

		// Iterate all collections
		self.collectionValuesMap.keys.forEach()
			{ self.collectionValuesMap.update(for: $0, with: { $0?.filter({ !documentIDs.contains($0) }) }) }

		// Iterate all indexes
		self.indexValuesMap.keys.forEach()
			{ self.indexValuesMap.update(for: $0, with: { $0?.filter({ !documentIDs.contains($0.value) }) }) }
	}
}
