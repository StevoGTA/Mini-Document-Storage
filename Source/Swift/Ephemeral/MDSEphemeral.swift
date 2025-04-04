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
public class MDSEphemeral : MDSDocumentStorageCore, MDSDocumentStorage {

	// MARK: DocumentBacking
	private class DocumentBacking : MDSDocumentBacking {

		// MARK: Properties
				let	documentID :String
				let	creationDate :Date

				var	revision :Int
				var	active = true
				var	modificationDate :Date
				var	propertyMap :[String : Any]

				var	documentRevisionInfo :MDSDocument.RevisionInfo
						{ MDSDocument.RevisionInfo(documentID: self.documentID, revision: self.revision) }
				var	documentFullInfo :MDSDocument.FullInfo
						{ MDSDocument.FullInfo(documentID: self.documentID, revision: self.revision,
							active: self.active, creationDate: self.creationDate,
							modificationDate: self.modificationDate, propertyMap: self.propertyMap,
							attachmentInfoByID:
									self.attachmentContentInfoByAttachmentID.mapValues({ $0.attachmentInfo })) }

				var	documentAttachmentInfoByID :MDSDocument.AttachmentInfoByID
						{ self.attachmentContentInfoByAttachmentID.mapValues({ $0.attachmentInfo }) }

		private	var	attachmentContentInfoByAttachmentID =
							[String : (attachmentInfo :MDSDocument.AttachmentInfo, content :Data)]()

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
			self.attachmentContentInfoByAttachmentID[attachmentID] = (documentAttachmentInfo, content)

			// Update
			self.revision = revision
			self.modificationDate = Date()

			return documentAttachmentInfo
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentContentInfo(for attachmentID :String) ->
				(attachmentInfo :MDSDocument.AttachmentInfo, content :Data)? {
			// Return info
			return self.attachmentContentInfoByAttachmentID[attachmentID]
		}
		
		//--------------------------------------------------------------------------------------------------------------
		func attachmentUpdate(revision :Int, attachmentID :String, updatedInfo :[String : Any], updatedContent :Data) ->
				Int {
			// Setup
			let	attachmentRevision = self.attachmentContentInfoByAttachmentID[attachmentID]!.attachmentInfo.revision + 1

			// Update
			self.attachmentContentInfoByAttachmentID[attachmentID] =
					(MDSDocument.AttachmentInfo(id: attachmentID, revision: attachmentRevision, info: updatedInfo),
							updatedContent)

			// Update
			self.revision = revision
			self.modificationDate = Date()

			return attachmentRevision
		}

		//--------------------------------------------------------------------------------------------------------------
		func attachmentRemove(revision :Int, attachmentID :String) {
			// Remove
			self.attachmentContentInfoByAttachmentID[attachmentID] = nil

			// Update
			self.revision = revision
			self.modificationDate = Date()
		}
	}

	// MARK: Types
	private	typealias Batch = MDSBatch<DocumentBacking>

	// MARK: Properties
	private	var	associationByName = LockingDictionary</* Name */ String, MDSAssociation>()
	private	var	associationItemsByName = LockingArrayDictionary</* Name */ String, MDSAssociation.Item>()

	private	let	batchByThread = LockingDictionary<Thread, Batch>()

	private	let	cacheByName = LockingDictionary</* Name */ String, MDSCache>()
	private	let	cachesByDocumentType = LockingArrayDictionary</* Document type */ String, MDSCache>()
	private	let	cacheValuesByName =
						LockingDictionary</* Cache Name */ String,
								[/* Document ID */ String : [/* Value Name */ String : /* Value */ Any]]>()

	private	let	collectionByName = LockingDictionary</* Name */ String, MDSCollection>()
	private	let	collectionsByDocumentType = LockingArrayDictionary</* Document type */ String, MDSCollection>()
	private	let	collectionValuesByName = LockingDictionary</* Name */ String, /* Document IDs */ [String]>()

	private	var	documentBackingByDocumentID = [/* Document ID */ String : DocumentBacking]()
	private	var	documentIDsByDocumentType = [/* Document Type */ String : /* Document IDs */ Set<String>]()
	private	let	documentMapsLock = ReadPreferringReadWriteLock()
	private	var	documentLastRevisionByDocumentType = [/* Document type */ String : Int]()
	private	let	documentLastRevisionByDocumentTypeLock = Lock()
	private	let	documentsBeingCreatedPropertyMapByDocumentID = LockingDictionary<String, [String : Any]>()

	private	let	indexByName = LockingDictionary</* Name */ String, MDSIndex>()
	private	let	indexesByDocumentType = LockingArrayDictionary</* Document type */ String, MDSIndex>()
	private	let	indexValuesByName = LockingDictionary</* Name */ String, [/* Key */ String : /* Document ID */ String]>()

	private	let	infoValueByKey = LockingDictionary<String, String>()
	private	let	internalValueByKey = LockingDictionary<String, String>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public override init() {}

	// MARK: MDSDocumentStorage methods
	//------------------------------------------------------------------------------------------------------------------
	public func associationRegister(named name :String, fromDocumentType :String, toDocumentType :String) throws {
		// Check if have association already
		if self.associationByName.value(for: name) == nil {
			// Create
			self.associationByName.set(
					MDSAssociation(name: name, fromDocumentType: fromDocumentType, toDocumentType: toDocumentType),
					for: name)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(for name :String) throws -> [MDSAssociation.Item] {
		// Validate
		guard self.associationByName.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		return associationItems(for: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let association = self.associationByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByDocumentID[fromDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}
		guard association.toDocumentType == toDocumentType else {
			throw MDSDocumentStorageError.invalidDocumentType(documentType: toDocumentType)
		}

		// Iterate association items
		let	documentCreateProc = self.documentCreateProc(for: toDocumentType)
		self.associationItems(for: name)
				.filter({ $0.fromDocumentID == fromDocumentID })
				.forEach() { proc(documentCreateProc($0.toDocumentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, fromDocumentType :String, to toDocumentID :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let association = self.associationByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByDocumentID[toDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: toDocumentID)
		}
		guard association.fromDocumentType == fromDocumentType else {
			throw MDSDocumentStorageError.invalidDocumentType(documentType: fromDocumentType)
		}

		// Iterate association items
		let	documentCreateProc = self.documentCreateProc(for: fromDocumentType)
		self.associationItems(for: name)
				.filter({ $0.toDocumentID == toDocumentID })
				.forEach() { proc(documentCreateProc($0.fromDocumentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetValues(for name :String, action :MDSAssociation.GetValueAction, fromDocumentIDs :[String],
			cacheName :String, cachedValueNames :[String]) throws -> Any {
		// Validate
		guard self.associationByName.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		try self.documentMapsLock.read() {
			// Iterate fromDocumentIDsUse
			try fromDocumentIDs.forEach() {
				// Check if have document with this ID
				guard self.documentBackingByDocumentID[$0] != nil else {
					throw MDSDocumentStorageError.unknownDocumentID(documentID: $0)
				}
			}
		}
		guard let cache = self.cacheByName.value(for: cacheName) else {
			throw MDSDocumentStorageError.unknownCache(name: cacheName)
		}
		try cachedValueNames.forEach() {
			// Check if have info for this cachedValueName
			guard cache.hasValueInfo(for: $0) else {
				throw MDSDocumentStorageError.unknownCacheValueName(valueName: $0)
			}
		}

		// Setup
		let	fromDocumentIDsUse = Set<String>(fromDocumentIDs)
		let	associationItems =
					self.associationItems(for: name).filter({ fromDocumentIDsUse.contains($0.fromDocumentID) })
		let	cacheValueInfos = self.cacheValuesByName.value(for: cacheName)!

		// Process association items
		switch action {
			case .detail:
				// Detail
				return associationItems.map({
					// Setup
					let	toDocumentID = $0.toDocumentID
					var	info :[String : Any] = ["fromID": $0.fromDocumentID, "toID": toDocumentID]

					// Add cached values
					cachedValueNames.forEach() { info[$0] = cacheValueInfos[toDocumentID]?[$0] }

					return info
				})

			case .sum:
				// Sum
				var	results = ["count": Int64(associationItems.count)]
				associationItems.forEach() {
					// Setup
					let	valueInfos = cacheValueInfos[$0.toDocumentID]!

					// Iterate cachedValueNames
					cachedValueNames.forEach()
						{ results[$0] = (results[$0] ?? 0) + ((valueInfos[$0] as? Int64) ?? 0) }
				}

				return results
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
		// Validate
		guard let association = self.associationByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Check if have updates
		guard !updates.isEmpty else { return }

		// Setup
		let	updateFromDocumentIDs = Set<String>(updates.map({ $0.item.fromDocumentID }))
		let	updateToDocumentIDs = Set<String>(updates.map({ $0.item.toDocumentID }))

		// Check for batch
		if let batch = self.batchByThread.value(for: .current) {
			// In batch
			try self.documentMapsLock.read({
				// Ensure all update from documentIDs exist
				let	existingFromDocumentIDs =
							Set<String>(
									(self.documentIDsByDocumentType[association.fromDocumentType] ?? []) +
											batch.documentIDs(for: association.fromDocumentType))
				let	missingFromDocumentIDs = updateFromDocumentIDs.subtracting(existingFromDocumentIDs)
				guard missingFromDocumentIDs.isEmpty else {
					throw MDSDocumentStorageError.unknownDocumentID(documentID: missingFromDocumentIDs.first!)
				}

				// Ensure all update to documentIDs exist
				let	existingToDocumentIDs =
							Set<String>(
									(self.documentIDsByDocumentType[association.toDocumentType] ?? []) +
											batch.documentIDs(for: association.toDocumentType))
				let	missingToDocumentIDs = updateToDocumentIDs.subtracting(existingToDocumentIDs)
				guard missingToDocumentIDs.isEmpty else {
					throw MDSDocumentStorageError.unknownDocumentID(documentID: missingToDocumentIDs.first!)
				}
			})

			// Update
			batch.associationNoteUpdated(for: name, updates: updates)
		} else {
			// Not in batch
			try self.documentMapsLock.read({
				// Ensure all update from documentIDs exist
				let	existingFromDocumentIDs =
							Set<String>(self.documentIDsByDocumentType[association.fromDocumentType] ?? [])
				let	missingFromDocumentIDs = updateFromDocumentIDs.subtracting(existingFromDocumentIDs)
				guard missingFromDocumentIDs.isEmpty else {
					throw MDSDocumentStorageError.unknownDocumentID(documentID: missingFromDocumentIDs.first!)
				}

				// Ensure all update to documentIDs exist
				let	existingToDocumentIDs =
							Set<String>(self.documentIDsByDocumentType[association.toDocumentType] ?? [])
				let	missingToDocumentIDs = updateToDocumentIDs.subtracting(existingToDocumentIDs)
				guard missingToDocumentIDs.isEmpty else {
					throw MDSDocumentStorageError.unknownDocumentID(documentID: missingToDocumentIDs.first!)
				}
			})

			// Update
			self.associationItemsByName.remove(updates.filter({ $0.action == .remove }).map({ $0.item }), for: name)
			self.associationItemsByName.append(updates.filter({ $0.action == .add }).map({ $0.item }), for: name)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			cacheValueInfos :[(valueInfo :MDSValueInfo, selector :String)]) throws {
		// Remove current cache if found
		if let cache = self.cacheByName.value(for: name) {
			// Remove
			self.cachesByDocumentType.remove(cache, for: documentType)
		}

		// Create or re-create cache
		let	cache =
					MDSCache(name: name, documentType: documentType, relevantProperties: relevantProperties,
							valueInfos:
									cacheValueInfos.map(
											{ MDSCache.ValueInfo(valueInfo: $0.valueInfo, selector: $0.selector,
													proc: self.documentValueProc(for: $0.selector)!) }),
							lastRevision: 0)

		// Add to maps
		self.cacheByName.set(cache, for: name)
		self.cachesByDocumentType.append(cache, for: documentType)

		// Bring up to date
		cacheUpdate(cache, updateInfos: self.updateInfos(for: documentType, sinceRevision: 0))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheGetValues(for name :String, valueNames :[String], documentIDs :[String]?) throws ->
			[[String : Any]] {
		// Validate
		guard let cache = self.cacheByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownCache(name: name)
		}

		if valueNames.isEmpty {
			throw MDSDocumentStorageError.missingValueNames
		}
		try valueNames.forEach() {
			// Ensure we have this value name
			if !cache.hasValueInfo(for: $0) {
				throw MDSDocumentStorageError.unknownCacheValueName(valueName: $0)
			}
		}

		// Setup
		let	cacheValuesByDocumentID = self.cacheValuesByName.value(for: cache.name) ?? [:]

		// Check if have documentIDs
		var	infos = [[String : Any]]()
		if documentIDs != nil {
			// Iteratoe documentIDs
			try documentIDs!.forEach() {
				// Get cached values
				if let cacheValues = cacheValuesByDocumentID[$0] {
					// Have documentID
					var	info :[String : Any] = ["documentID": $0]

					// Iterate valueNames
					valueNames.forEach() { info[$0] = cacheValues[$0] }

					// Add to array
					infos.append(info)
				} else {
					// Don't have documentID
					throw MDSDocumentStorageError.unknownDocumentID(documentID: $0)
				}
			}
		} else {
			// All documentIDs
			cacheValuesByDocumentID.forEach() { documentID, cacheValues in
				// Setup
				var	info :[String : Any] = ["documentID": documentID]

				// Iterate valueNames
				valueNames.forEach() { info[$0] = cacheValues[$0] }

				// Add to array
				infos.append(info)
			}
		}

		return infos
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String,
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc, checkRelevantProperties :Bool) throws {
		// Remove current collection if found
		if let collection = self.collectionByName.value(for: name) {
			// Remove
			self.collectionsByDocumentType.remove(collection, for: documentType)
		}

		// Create or re-create collection
		let	lastRevision =
					isUpToDate ?
							self.documentLastRevisionByDocumentTypeLock.perform()
									{ self.documentLastRevisionByDocumentType[documentType] ?? 0 } : 0
		let	collection =
					MDSCollection(name: name, documentType: documentType, relevantProperties: relevantProperties,
							documentIsIncludedProc: documentIsIncludedProc,
							checkRelevantProperties: checkRelevantProperties, isIncludedInfo: isIncludedInfo,
							lastRevision: lastRevision)

		// Add to maps
		self.collectionByName.set(collection, for: name)
		self.collectionsByDocumentType.append(collection, for: documentType)

		// Check if is up to date
		if !isUpToDate {
			// Bring up to date
			collectionUpdate(collection, updateInfos: self.updateInfos(for: documentType, sinceRevision: 0))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionGetDocumentCount(for name :String) throws -> Int {
		// Validate
		guard let documentIDs = self.collectionValuesByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}
		guard self.batchByThread.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		return documentIDs.count
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let documentIDs = self.collectionValuesByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}
		guard self.batchByThread.value(for: .current) == nil else {
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
		if let batch = self.batchByThread.value(for: .current) {
			// In batch
			documentCreateInfos.forEach() {
				// Setup
				let	documentID = $0.documentID ?? UUID().base64EncodedString

				// Add document
				_ = batch.documentAdd(documentType: documentType, documentID: documentID,
						creationDate: $0.creationDate ?? date, modificationDate: $0.modificationDate ?? date,
						propertyMap: !$0.propertyMap.isEmpty ? $0.propertyMap : nil)
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
				self.documentsBeingCreatedPropertyMapByDocumentID.set($0.propertyMap, for: documentID)

				// Create
				let	document = proc(documentID, self)

				// Remove property map
				let	propertyMap = self.documentsBeingCreatedPropertyMapByDocumentID.value(for: documentID)!
				self.documentsBeingCreatedPropertyMapByDocumentID.remove(documentID)

				// Add document
				let	revision = nextRevision(for: documentType)
				let	creationDate = $0.creationDate ?? date
				let	modificationDate = $0.modificationDate ?? date
				let	documentBacking =
							DocumentBacking(documentID: documentID, revision: revision, creationDate: creationDate,
									modificationDate: modificationDate, propertyMap: propertyMap)
				self.documentMapsLock.write() {
					// Update maps
					self.documentBackingByDocumentID[documentID] = documentBacking
					self.documentIDsByDocumentType.insertSetValueElement(key: documentType, value: documentID)
				}
				infos.append(
						(document,
								MDSDocument.OverviewInfo(documentID: documentID, revision: revision,
										creationDate: creationDate, modificationDate: modificationDate)))

				// Call document changed procs
				documentChangedProcs.forEach() { $0(document, .created) }

				// Add update info
				updateInfos.append(
						MDSUpdateInfo<String>(document: document, revision: revision, id: documentID,
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
		guard let documentIDs = self.documentMapsLock.read({ self.documentIDsByDocumentType[documentType] }) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}
		guard self.batchByThread.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		return documentIDs.count
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, documentIDs :[String],
			documentCreateProc :MDSDocument.CreateProc, proc :(_ document :MDSDocument) -> Void) throws {
		// Setup
		let	batch = self.batchByThread.value(for: .current)

		// Iterate document IDs
		var	documentIDsForDocumentBackings = [String]()
		documentIDs.forEach() {
			// Check what we have currently
			if batch?.documentInfoGet(for: $0) != nil {
				// Have document in batch
				proc(documentCreateProc($0, self))
			} else {
				// Not in batch
				documentIDsForDocumentBackings.append($0)
			}
		}

		// Iterate document backings
		try documentBackingsIterate(for: documentType, documentIDs: documentIDsForDocumentBackings,
				proc: { proc(documentCreateProc($0.documentID, self)) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, activeOnly: Bool, documentCreateProc :MDSDocument.CreateProc,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard self.batchByThread.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Iterate document backings
		try documentBackingsIterate(for: documentType, sinceRevision: 0, count: nil, activeOnly: activeOnly,
				proc: { proc(documentCreateProc($0.documentID, self)) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batch = self.batchByThread.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// In batch
			return batchDocumentInfo.creationDate
		} else if self.documentsBeingCreatedPropertyMapByDocumentID.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// "Idle"
			return self.documentMapsLock.read({ self.documentBackingByDocumentID[document.id]?.creationDate ?? Date() })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentModificationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batch = self.batchByThread.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// In batch
			return batchDocumentInfo.modificationDate
		} else if self.documentsBeingCreatedPropertyMapByDocumentID.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// "Idle"
			return self.documentMapsLock.read(
					{ self.documentBackingByDocumentID[document.id]?.modificationDate ?? Date() })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentValue(for property :String, of document :MDSDocument) -> Any? {
		// Check for batch
		if let batch = self.batchByThread.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// In batch
			return batchDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapByDocumentID.value(for: document.id) {
			// Being created
			return propertyMap[property]
		} else {
			// "Idle"
			return self.documentMapsLock.read({ self.documentBackingByDocumentID[document.id]?.propertyMap[property] })
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
		if let batch = self.batchByThread.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
				// Have document in batch
				batchDocumentInfo.set(value, for: property)
			} else {
				// Don't have document in batch
				let	documentBacking =
							try! self.documentMapsLock.read() { () -> DocumentBacking in
								// Validate
								guard let documentBacking = self.documentBackingByDocumentID[document.id] else {
									throw MDSDocumentStorageError.unknownDocumentID(documentID: document.id)
								}

								return documentBacking
							}
				batch.documentAdd(documentType: documentType, documentBacking: documentBacking)
					.set(value, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapByDocumentID.value(for: document.id) {
			// Being created
			propertyMap[property] = value
			self.documentsBeingCreatedPropertyMapByDocumentID.set(propertyMap, for: document.id)
		} else {
			// Update document
			let	documentBacking :DocumentBacking =
						self.documentMapsLock.write() {
							// Setup
							let	documentBacking = self.documentBackingByDocumentID[document.id]!

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
			noteDocumentChanged(document: document, changeKind: .updated)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any],
			content :Data) throws -> MDSDocument.AttachmentInfo {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByDocumentType[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batch = self.batchByThread.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				return batchDocumentInfo.attachmentAdd(info: info, content: content)
			} else {
				// Don't have document in batch
				let	documentBacking =
							try self.documentMapsLock.read() { () -> DocumentBacking in
								// Validate
								guard let documentBacking = self.documentBackingByDocumentID[documentID] else {
									throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
								}

								return documentBacking
							}

				return batch.documentAdd(documentType: documentType, documentBacking: documentBacking)
						.attachmentAdd(info: info, content: content)
			}
		} else {
			// Not in batch
			return try self.documentMapsLock.write() {
				// Setup
				if let documentBacking = self.documentBackingByDocumentID[documentID] {
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
	public func documentAttachmentInfoByID(for documentType :String, documentID :String) throws ->
			MDSDocument.AttachmentInfoByID {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByDocumentType[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batch = self.batchByThread.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
			// Have document in batch
			let	documentAttachmentInfoByID =
						self.documentMapsLock.read(
								{ self.documentBackingByDocumentID[documentID]!.documentAttachmentInfoByID })

			return batchDocumentInfo.documentAttachmentInfoByID(applyingChangesTo: documentAttachmentInfoByID)
		} else if self.documentsBeingCreatedPropertyMapByDocumentID.value(for: documentID) != nil {
			// Creating
			return [:]
		} else if let documentAttachmentInfoByID =
				self.documentMapsLock.read(
						{ self.documentBackingByDocumentID[documentID]?.documentAttachmentInfoByID }) {
			// Not in batch and not creating
			return documentAttachmentInfoByID
		} else {
			// Unknown documentID
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws ->
			Data {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByDocumentType[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batch = self.batchByThread.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: documentID),
				let content = batchDocumentInfo.attachmentContent(for: attachmentID) {
			// Found
			return content
		} else if self.documentsBeingCreatedPropertyMapByDocumentID.value(for: documentID) != nil {
			// Creating
			throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
		}

		// Get non-batch attachment content
		guard let documentBacking =
				self.documentMapsLock.read({ self.documentBackingByDocumentID[documentID] }) else {
			// Unknown documentID
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}
		guard let attachmentContentInfo = documentBacking.attachmentContentInfo(for: attachmentID) else {
			// Don't have attachment
			throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
		}

		return attachmentContentInfo.content
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int? {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByDocumentType[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}
		guard let documentBacking = self.documentMapsLock.read({ self.documentBackingByDocumentID[documentID] }) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}

		// Check for batch
		if let batch = self.batchByThread.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				let	documentAttachmentInfoByID =
							batchDocumentInfo.documentAttachmentInfoByID(
									applyingChangesTo: documentBacking.documentAttachmentInfoByID)
				guard let attachmentInfo = documentAttachmentInfoByID[attachmentID] else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batchDocumentInfo.attachmentUpdate(id: attachmentID, currentRevision: attachmentInfo.revision,
						info: updatedInfo, content: updatedContent)
			} else {
				// Don't have document in batch
				guard let attachmentInfo =
						documentBacking.attachmentContentInfo(for: attachmentID)?.attachmentInfo else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batch.documentAdd(documentType: documentType, documentBacking: documentBacking)
						.attachmentUpdate(id: attachmentID, currentRevision: attachmentInfo.revision, info: updatedInfo,
								content: updatedContent)
			}

			return nil
		} else {
			// Not in batch
			guard documentBacking.attachmentContentInfo(for: attachmentID) != nil else {
				throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
			}

			return self.documentMapsLock.write() {
				// Update attachment
				return documentBacking.attachmentUpdate(revision: self.nextRevision(for: documentType),
						attachmentID: attachmentID, updatedInfo: updatedInfo, updatedContent: updatedContent)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByDocumentType[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}
		guard let documentBacking = self.documentMapsLock.read({ self.documentBackingByDocumentID[documentID] }) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}

		// Check for batch
		if let batch = self.batchByThread.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				let	documentAttachmentInfoByID =
							batchDocumentInfo.documentAttachmentInfoByID(
									applyingChangesTo: documentBacking.documentAttachmentInfoByID)
				guard documentAttachmentInfoByID[attachmentID] != nil else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batchDocumentInfo.attachmentRemove(id: attachmentID)
			} else {
				// Don't have document in batch
				guard documentBacking.attachmentContentInfo(for: attachmentID) != nil else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				return batch.documentAdd(documentType: documentType, documentBacking: documentBacking)
						.attachmentRemove(id: attachmentID)
			}
		} else {
			// Not in batch
			guard documentBacking.attachmentContentInfo(for: attachmentID) != nil else {
				throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
			}

			self.documentMapsLock.write() {
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
		if let batch = self.batchByThread.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentMapsLock.read({ self.documentBackingByDocumentID[document.id]! })
				batch.documentAdd(documentType: documentType, documentBacking: documentBacking).remove()
			}
		} else {
			// Not in batch
			self.documentMapsLock.write({ self.documentBackingByDocumentID[document.id]?.active = false })

			// Remove
			note(removedDocumentIDs: Set<String>([document.id]))

			// Call document changed procs
			noteDocumentChanged(document: document, changeKind: .removed)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister(name :String, documentType :String, relevantProperties :[String],
			keysInfo :[String : Any], keysSelector :String, keysProc :@escaping MDSDocument.KeysProc) throws {
		// Remove current index if found
		if let index = self.indexByName.value(for: name) {
			// Remove
			self.indexesByDocumentType.remove(index, for: documentType)
		}

		// Create or re-create index
		let	index =
					MDSIndex(name: name, documentType: documentType, relevantProperties: relevantProperties,
							keysProc: keysProc, keysInfo: keysInfo, lastRevision: 0)

		// Add to maps
		self.indexByName.set(index, for: name)
		self.indexesByDocumentType.append(index, for: documentType)

		// Bring up to date
		indexUpdate(index, updateInfos: self.updateInfos(for: documentType, sinceRevision: 0))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws {
		// Validate
		guard let items = self.indexValuesByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}
		guard self.batchByThread.value(for: .current) == nil else {
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
	public func infoGet(for keys :[String]) throws -> [String : String] {
		// Return values
		self.infoValueByKey.dictionary.filter({ keys.contains($0.key) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoSet(_ info :[String : String]) throws { self.infoValueByKey.merge(info) }

	//------------------------------------------------------------------------------------------------------------------
	public func infoRemove(keys :[String]) throws { self.infoValueByKey.remove(keys) }

	//------------------------------------------------------------------------------------------------------------------
	public func internalGet(for keys :[String]) -> [String : String] {
		// Return values
		return self.internalValueByKey.dictionary.filter({ keys.contains($0.key) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalSet(_ info :[String : String]) throws { self.internalValueByKey.merge(info) }

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Setup
		let	batch = Batch()

		// Store
		self.batchByThread.set(batch, for: .current)
		defer { self.batchByThread.set(nil, for: .current) }

		// Run lean
		var	result = MDSBatchResult.commit
		try autoreleasepool() {
			// Call proc
			result = try proc()
		}

		// Check result
		if result == .commit {
			// Iterate all document changes
			batch.documentInfosByDocumentType.forEach() { documentType, batchDocumentInfoByDocumentID in
				// Setup
				let	documentCreateProc = self.documentCreateProc(for: documentType)
				let	documentChangedProcs = self.documentChangedProcs(for: documentType)

				var	updateInfos = [MDSUpdateInfo<String>]()
				var	removedDocumentIDs = Set<String>()

				let	process
							:(_ documentID :String, _ batchDocumentInfo :Batch.DocumentInfo,
									_ documentBacking :DocumentBacking, _ changedProperties :Set<String>?,
									_ changeKind :MDSDocument.ChangeKind) -> Void =
							{ documentID, batchDocumentInfo, documentBacking, changedProperties, changeKind in
								// Process attachments
								batchDocumentInfo.removedAttachmentIDs.forEach() {
									// Remove attachment
									documentBacking.attachmentRemove(revision: documentBacking.revision,
											attachmentID: $0)
								}
								batchDocumentInfo.addAttachmentInfosByID.values.forEach() {
									// Add attachment
									_ = documentBacking.attachmentAdd(revision: documentBacking.revision, info: $0.info,
											content: $0.content)
								}
								batchDocumentInfo.updateAttachmentInfosByID.values.forEach() {
									// Update attachment
									_ = documentBacking.attachmentUpdate(revision: documentBacking.revision,
											attachmentID: $0.id, updatedInfo: $0.info,
											updatedContent: $0.content)
								}

								// Create document
								let	document = documentCreateProc(documentID, self)

								// Note update info
								updateInfos.append(
										MDSUpdateInfo<String>(document: document, revision: documentBacking.revision,
												id: documentID, changedProperties: changedProperties))

								// Call document changed procs
								documentChangedProcs.forEach() { $0(document, changeKind) }
							}

				// Update documents
				batchDocumentInfoByDocumentID.forEach() { documentID, batchDocumentInfo in
					// Check removed
					if !batchDocumentInfo.removed {
						// Add/update document
						self.documentMapsLock.write() {
							// Retrieve existing document
							if let documentBacking = self.documentBackingByDocumentID[documentID] {
								// Update document backing
								documentBacking.update(revision: nextRevision(for: documentType),
										updatedPropertyMap: batchDocumentInfo.updatedPropertyMap,
										removedProperties: batchDocumentInfo.removedProperties)

								// Process
								let	changedProperties =
											Set<String>(batchDocumentInfo.updatedPropertyMap.keys)
													.union(batchDocumentInfo.removedProperties)
								process(documentID, batchDocumentInfo, documentBacking, changedProperties, .updated)
							} else {
								// Add document
								let	documentBacking =
											DocumentBacking(documentID: documentID,
													revision: nextRevision(for: documentType),
													creationDate: batchDocumentInfo.creationDate,
													modificationDate: batchDocumentInfo.modificationDate,
													propertyMap: batchDocumentInfo.updatedPropertyMap)
								self.documentBackingByDocumentID[documentID] = documentBacking
								self.documentIDsByDocumentType.insertSetValueElement(key: documentType,
										value: documentID)

								// Process
								process(documentID, batchDocumentInfo, documentBacking,
										Set<String>(batchDocumentInfo.updatedPropertyMap.keys), .created)
							}
						}
					} else {
						// Remove document
						removedDocumentIDs.insert(documentID)

						self.documentMapsLock.write() {
							// Update maps
							self.documentBackingByDocumentID[documentID]!.active = false

							// Check if have changed procs
							if !documentChangedProcs.isEmpty {
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
			batch.associationIterateChanges() { name, updates in
				// Update association
				self.associationItemsByName.remove(updates.filter({ $0.action == .remove }).map({ $0.item }),
						for: name)
				self.associationItemsByName.append(updates.filter({ $0.action == .add }).map({ $0.item }), for: name)
			}
		}
	}

	// MARK: MDSDocumentStorageServer methods
	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
		// Validate
		guard self.associationByName.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByDocumentID[fromDocumentID] }) != nil else {
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
					self.documentMapsLock.read(
						{ documentIDsToProcess.map({ self.documentBackingByDocumentID[$0]!.documentRevisionInfo }) })

		return (documentIDs.count, Array(documentRevisionInfos))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws
			-> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
		// Validate
		guard self.associationByName.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByDocumentID[toDocumentID] }) != nil else {
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
					self.documentMapsLock.read(
						{ documentIDsToProcess.map({ self.documentBackingByDocumentID[$0]!.documentRevisionInfo }) })

		return (documentIDs.count, Array(documentRevisionInfos))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?) throws
			-> (totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
		// Validate
		guard self.associationByName.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByDocumentID[fromDocumentID] }) != nil else {
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
					self.documentMapsLock.read(
						{ documentIDsToProcess.map({ self.documentBackingByDocumentID[$0]!.documentFullInfo }) })

		return (documentIDs.count, Array(documentFullInfos))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
		// Validate
		guard self.associationByName.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByDocumentID[toDocumentID] }) != nil else {
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
					self.documentMapsLock.read(
						{ documentIDsToProcess.map({ self.documentBackingByDocumentID[$0]!.documentFullInfo }) })

		return (documentIDs.count, Array(documentFullInfos))
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentRevisionInfos(name :String, startIndex :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
		// Validate
		guard let documentIDs =
						self.collectionValuesByName.value(for: name)?[startIndex...].prefix(count ?? Int.max) else
				{ throw MDSDocumentStorageError.unknownCollection(name: name) }

		// Process documentIDs
		guard !documentIDs.isEmpty else { return [] }

		return self.documentMapsLock.read(
			{ documentIDs.map({ self.documentBackingByDocumentID[$0]!.documentRevisionInfo }) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentFullInfos(name :String, startIndex :Int, count :Int?) throws -> [MDSDocument.FullInfo] {
		// Validate
		guard let documentIDs =
						self.collectionValuesByName.value(for: name)?[startIndex...].prefix(count ?? Int.max) else
				{ throw MDSDocumentStorageError.unknownCollection(name: name) }

		// Process documentIDs
		guard !documentIDs.isEmpty else { return [] }

		return self.documentMapsLock.read(
			{ documentIDs.map({ self.documentBackingByDocumentID[$0]!.documentFullInfo }) })
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
	func documentValue(for documentType :String, documentID :String, property :String) -> Any? {
		// Check for batch
		if let batch = self.batchByThread.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
			// In batch
			return batchDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapByDocumentID.value(for: documentID) {
			// Being created
			return propertyMap[property]
		} else {
			// "Idle"
			return
					self.documentMapsLock.read(
						{ self.documentBackingByDocumentID[documentID]?.propertyMap[property] })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo] {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByDocumentType[documentType] }) != nil else {
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
					guard let documentBacking = self.documentBackingByDocumentID[documentID] else { return }

					// Update document backing
					documentBacking.update(revision: nextRevision(for: documentType), updatedPropertyMap: updated,
							removedProperties: removed)

					// Create document
					let	document = documentCreateProc(documentID, self)

					// Add update info
					updateInfos.append(
							MDSUpdateInfo<String>(document: document,
									revision: documentBacking.revision, id: documentID,
									changedProperties: Set<String>(updated.keys).union(removed)))

					// Add full info
					documentFullInfos.append(documentBacking.documentFullInfo)

					// Call document changed procs
					documentChangedProcs.forEach() { $0(document, .updated) }
				}
			} else {
				// Remove document
				removedDocumentIDs.insert(documentID)

				self.documentMapsLock.write() {
					// Retrieve existing document backing
					guard let documentBacking = self.documentBackingByDocumentID[documentID] else { return }

					// Update active
					documentBacking.active = false

					// Add full info
					documentFullInfos.append(documentBacking.documentFullInfo)

					// Check if have document changed procs
					if !documentChangedProcs.isEmpty {
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

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentRevisionInfos(name :String, keys :[String]) throws -> [String : MDSDocument.RevisionInfo] {
		// Validate
		guard let items = self.indexValuesByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		return try self.documentMapsLock.read() {
			Dictionary(try keys.map({
				// Get documentID
				guard let documentID = items[$0] else {
					throw MDSDocumentStorageError.missingFromIndex(key: $0)
				}

				return ($0, self.documentBackingByDocumentID[documentID]!.documentRevisionInfo)
			}))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentFullInfos(name :String, keys :[String]) throws -> [String : MDSDocument.FullInfo] {
		// Validate
		guard let items = self.indexValuesByName.value(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		return try self.documentMapsLock.read() {
			Dictionary(try keys.map({
				// Retrieve documentID
				guard let documentID = items[$0] else {
					throw MDSDocumentStorageError.missingFromIndex(key: $0)
				}

				return ($0, self.documentBackingByDocumentID[documentID]!.documentFullInfo)
			}))
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func associationItems(for name :String) -> [MDSAssociation.Item] {
		// Setup
		var	associationItems = self.documentMapsLock.read({ self.associationItemsByName.values(for: name) ?? [] })

		// Process batch updates
		if let batch = self.batchByThread.value(for: .current) {
			// Apply batch changes
			associationItems = batch.associationItems(applyingChangesTo: associationItems, for: name)
		}

		return associationItems
	}

	//------------------------------------------------------------------------------------------------------------------
	private func cacheUpdate(_ cache :MDSCache, updateInfos :[MDSUpdateInfo<String>]) {
		// Update Cache
		let	(infosByID, _) = cache.update(updateInfos)

		// Check if have updates
		if infosByID != nil {
			// Update storage
			self.cacheValuesByName.update(for: cache.name,
					with: { ($0 ?? [:]).merging(infosByID!, uniquingKeysWith: { $1 }) })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func collectionUpdate(_ collection :MDSCollection, updateInfos :[MDSUpdateInfo<String>]) {
		// Update Collection
		let	(includedIDs, notIncludedIDs, _) = collection.update(updateInfos)

		// Check if have updates
		if (includedIDs != nil) || (notIncludedIDs != nil) {
			// Update storage
			self.collectionValuesByName.update(for: collection.name) {
				// Setup
				let	notIncludedIDsUse = Set<String>(notIncludedIDs ?? [])

				// Compose updated values
				let	updatedValues = ($0?.filter({ !notIncludedIDsUse.contains($0) }) ?? []) + (includedIDs ?? [])

				return !updatedValues.isEmpty ? updatedValues : nil
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate(for documentType :String, documentIDs :[String],
			proc :(_ documentBacking :DocumentBacking) -> Void) throws {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByDocumentType[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Retrieve document backings
		let	documentBackings =
				try self.documentMapsLock.read() {
					try documentIDs.map() { documentID -> DocumentBacking in
						// Validate
						guard let documentBacking = self.documentBackingByDocumentID[documentID] else {
							throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
						}

						return documentBacking
					}
				}

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
						guard let documentBackings = self.documentIDsByDocumentType[documentType] else {
							throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
						}

						return documentBackings
								.map({ self.documentBackingByDocumentID[$0]! })
								.filter({ ($0.revision > sinceRevision) && (!activeOnly || $0.active) })
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
			self.indexValuesByName.update(for: index.name) {
				// Filter out document IDs included in update
				var	updatedValueInfo = ($0 ?? [:]).filter({ !documentIDs.contains($0.value) })

				// Add keys => document IDs
				keysInfos!.forEach() { keys, value in keys.forEach() { updatedValueInfo[$0] = value } }

				return !updatedValueInfo.isEmpty ? updatedValueInfo : nil
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func nextRevision(for documentType :String) -> Int {
		// Compose next revision
		return self.documentLastRevisionByDocumentTypeLock.perform() {
			// Compose next revision
			let	nextRevision = (self.documentLastRevisionByDocumentType[documentType] ?? 0) + 1

			// Store
			self.documentLastRevisionByDocumentType[documentType] = nextRevision

			return nextRevision
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateInfos(for documentType :String, sinceRevision: Int) -> [MDSUpdateInfo<String>] {
		// Collect update infos
		let	documentCreateProc = self.documentCreateProc(for: documentType)
		var	updateInfos = [MDSUpdateInfo<String>]()
		try? documentBackingsIterate(for: documentType, sinceRevision: sinceRevision, count: nil, activeOnly: false,
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
		self.cachesByDocumentType.values(for: documentType)?.forEach()
			{ self.cacheUpdate($0, updateInfos: updateInfos) }

		// Update collections
		self.collectionsByDocumentType.values(for: documentType)?.forEach()
			{ self.collectionUpdate($0, updateInfos: updateInfos) }

		// Update indexes
		self.indexesByDocumentType.values(for: documentType)?.forEach()
			{ self.indexUpdate($0, updateInfos: updateInfos) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func note(removedDocumentIDs documentIDs :Set<String>) {
		// Iterate all caches
		self.cacheValuesByName.keys.forEach()
			{ self.cacheValuesByName.update(for: $0, with: { $0?.filter({ !documentIDs.contains($0.key) }) }) }

		// Iterate all collections
		self.collectionValuesByName.keys.forEach()
			{ self.collectionValuesByName.update(for: $0, with: { $0?.filter({ !documentIDs.contains($0) }) }) }

		// Iterate all indexes
		self.indexValuesByName.keys.forEach()
			{ self.indexValuesByName.update(for: $0, with: { $0?.filter({ !documentIDs.contains($0.value) }) }) }
	}
}
