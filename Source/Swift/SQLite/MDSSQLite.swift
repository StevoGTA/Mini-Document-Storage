//
//  MDSSQLite.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSSQLite
public class MDSSQLite : MDSDocumentStorageCore, MDSDocumentStorage {

	// MARK: Types
	private	typealias Batch = MDSBatch<MDSSQLiteDocumentBacking>

	// MARK: Properties
	private	var	associationsByNameMap = LockingDictionary</* Name */ String, MDSAssociation>()

	private	let	batchMap = LockingDictionary<Thread, Batch>()

	private	let	cachesByNameMap = LockingDictionary</* Name */ String, MDSCache>()
	private	let	cachesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCache>()

	private	let	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	let	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()

	private	let	databaseManager :MDSSQLiteDatabaseManager

	private	let	documentBackingCache = MDSDocumentBackingCache<MDSSQLiteDocumentBacking>()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, [String : Any]>()

	private	let	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	let	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(in folder :Folder, with name :String = "database") throws {
		// Setup database
		let database = try SQLiteDatabase(in: folder, with: name)

		// Setup database manager
		self.databaseManager = MDSSQLiteDatabaseManager(database: database)
	}

	// MARK: MDSDocumentStorage methods
	//------------------------------------------------------------------------------------------------------------------
	public func associationRegister(named name :String, fromDocumentType :String, toDocumentType :String) throws {
		// Validate
		guard self.databaseManager.isKnown(documentType: fromDocumentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: fromDocumentType)
		}
		guard self.databaseManager.isKnown(documentType: toDocumentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: toDocumentType)
		}

		// Register
		self.databaseManager.associationRegister(name: name, fromDocumentType: fromDocumentType,
				toDocumentType: toDocumentType)

		// Create or re-create association
		let	association = MDSAssociation(name: name, fromDocumentType: fromDocumentType, toDocumentType: toDocumentType)

		// Add to map
		self.associationsByNameMap.set(association, for: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(for name :String) throws -> [MDSAssociation.Item] {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Get association items
		var	associationItems =
					self.databaseManager.associationGet(name: name, fromDocumentType: association.fromDocumentType,
							toDocumentType: association.toDocumentType)

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// Apply batch changes
			associationItems = batch.associationItems(applyingChangesTo: associationItems, for: name)
		}

		return associationItems
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Get association items
		var	associationItems =
					try self.databaseManager.associationGet(name: name, fromDocumentID: fromDocumentID,
							fromDocumentType: association.fromDocumentType, toDocumentType: association.toDocumentType)

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// Apply batch changes
			associationItems = batch.associationItems(applyingChangesTo: associationItems, for: name)
		}

		// Iterate document IDs
		let	documentCreateProc = self.documentCreateProc(for: toDocumentType)
		autoreleasepool() {
			associationItems
					.filter({ $0.fromDocumentID == fromDocumentID })
					.forEach() { proc(documentCreateProc($0.toDocumentID, self)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, to toDocumentID :String, fromDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		// Get association items
		var	associationItems =
					try self.databaseManager.associationGet(name: name, fromDocumentType: association.fromDocumentType,
							toDocumentID: toDocumentID, toDocumentType: association.toDocumentType)

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// Apply batch changes
			associationItems = batch.associationItems(applyingChangesTo: associationItems, for: name)
		}

		// Iterate document IDs
		let	documentCreateProc = self.documentCreateProc(for: fromDocumentType)
		autoreleasepool() {
			associationItems
					.filter({ $0.toDocumentID == toDocumentID })
					.forEach() { proc(documentCreateProc($0.fromDocumentID, self)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetIntegerValues(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentIDs :[String], cacheName :String, cachedValueNames :[String]) throws -> [String : Int64] {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard let cache = cache(for: cacheName) else {
			throw MDSDocumentStorageError.unknownCache(name: cacheName)
		}
		try cachedValueNames.forEach() {
			// Check if have info for this cachedValueName
			guard cache.hasValueInfo(for: $0) else {
				throw MDSDocumentStorageError.unknownCacheValueName(valueName: $0)
			}
		}

		// Process batch updates
		let	(associationAdds, associationRemoves) =
					self.batchMap.value(for: .current)?.associationUpdates(for: name) ?? ([], [])
		let	fromDocumentIDsUse :[String]
		if !associationAdds.isEmpty || !associationRemoves.isEmpty {
			// Remove document revision infos that have been removed
			let	associationRemoveDocumentIDs = Set(associationRemoves.map({ $0.fromDocumentID }))

			// Update document IDs
			fromDocumentIDsUse =
					Array(Set(fromDocumentIDs.filter({ !associationRemoveDocumentIDs.contains($0) }) +
							associationAdds.map({ $0.fromDocumentID })))
		} else {
			// Not in batch or no updates
			fromDocumentIDsUse = fromDocumentIDs
		}

		// Check action
		switch action {
			case .sum:
				// Sum
				return try self.databaseManager.associationSum(name: name, fromDocumentIDs: fromDocumentIDsUse,
						documentType: association.fromDocumentType, cacheName: cacheName,
						cachedValueNames: cachedValueNames)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Check if have updates
		guard !updates.isEmpty else { return }

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			batch.associationNoteUpdated(for: name, updates: updates)
		} else {
			// Not in batch
			self.databaseManager.associationUpdate(name: name, updates: updates,
					fromDocumentType: association.fromDocumentType, toDocumentType: association.toDocumentType)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			valueInfos :[MDSCache.ValueInfo]) throws {
		// Remove current cache if found
		if let cache = self.cachesByNameMap.value(for: name) {
			// Remove
			self.cachesByDocumentTypeMap.remove(cache, for: documentType)
		}

		// Register cache
		let	lastRevision =
					self.databaseManager.cacheRegister(name: name, documentType: documentType,
							relevantProperties: relevantProperties,
							valueInfos:
									valueInfos.map(
											{ MDSSQLiteDatabaseManager.CacheValueInfo(name: $0.valueInfo.name,
													valueType: $0.valueInfo.type, selector: $0.selector) }))

		// Create or re-create cache
		let	cache =
					MDSCache(name: name, documentType: documentType, relevantProperties: relevantProperties,
							valueInfos: valueInfos, lastRevision: lastRevision)

		// Add to maps
		self.cachesByNameMap.set(cache, for: name)
		self.cachesByDocumentTypeMap.append(cache, for: documentType)

		// Bring up to date
		autoreleasepool()
			{ cacheUpdate(cache, updateInfo: self.updateInfo(for: documentType, sinceRevision: lastRevision)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String,
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc) throws {
		// Remove current collection if found
		if let collection = self.collectionsByNameMap.value(for: name) {
			// Remove
			self.collectionsByDocumentTypeMap.remove(collection, for: documentType)
		}

		// Register collection
		let	lastRevision =
					self.databaseManager.collectionRegister(name: name, documentType: documentType,
							relevantProperties: relevantProperties, isIncludedSelector: isIncludedSelector,
							isIncludedSelectorInfo: isIncludedInfo, isUpToDate: isUpToDate)

		// Create or re-create collection
		let	collection =
					MDSCollection(name: name, documentType: documentType, relevantProperties: relevantProperties,
							documentIsIncludedProc: documentIsIncludedProc, isIncludedInfo: isIncludedInfo,
							lastRevision: lastRevision)

		// Add to maps
		self.collectionsByNameMap.set(collection, for: name)
		self.collectionsByDocumentTypeMap.append(collection, for: documentType)

		// Check if is up to date
		if !isUpToDate {
			// Bring up to date
			autoreleasepool()
				{ collectionUpdate(collection, updateInfo: self.updateInfo(for: documentType, sinceRevision: 0)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionGetDocumentCount(for name :String) throws -> Int {
		// Validate
		guard let collection = collection(for: name) else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Bring up to date
		autoreleasepool() {
			// Update
			collectionUpdate(collection, updateInfo: self.updateInfo(for: collection.documentType, sinceRevision: 0))
		}

		return self.databaseManager.collectionGetDocumentCount(for: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let collection = collection(for: name) else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Bring up to date
		autoreleasepool() {
			// Update
			collectionUpdate(collection, updateInfo: self.updateInfo(for: collection.documentType, sinceRevision: 0))
		}

		// Collect document IDs
		var	documentIDs = [String]()
		autoreleasepool() {
			collectionIterate(name: name, documentType: documentType, startIndex: 0, count: nil)
					{ documentIDs.append($0.documentID) }
		}

		// Iterate document IDs
		let	documentCreateProc = self.documentCreateProc(for: documentType)
		autoreleasepool() { documentIDs.forEach() { proc(documentCreateProc($0, self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
			proc :MDSDocument.CreateProc) throws ->
			[(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)] {
		// Setup
		let	date = Date()
		var	infos = [(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)]()

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			documentCreateInfos.forEach() {
				// Setup
				let	documentID = $0.documentID ?? UUID().base64EncodedString

				// Add document
				_ = batch.documentAdd(documentType: documentType, documentID: documentID,
						creationDate: $0.creationDate ?? date, modificationDate: $0.modificationDate ?? date,
						initialPropertyMap: !$0.propertyMap.isEmpty ? $0.propertyMap : nil)
				infos.append((proc(documentID, self), nil))
			}
		} else {
			// Setup
			let	documentChangedProcs = self.documentChangedProcs(for: documentType)

			// Batch
			self.databaseManager.batch() {
				// Setup
				let	batchQueue =
							BatchQueue<MDSUpdateInfo<Int64>>(
									maximumBatchSize: self.databaseManager.variableNumberLimit)
									{ self.update(for: documentType, updateInfo: ($0, [])) 	}

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
					let	creationDate = $0.creationDate ?? date
					let	modificationDate = $0.modificationDate ?? date
					let	documentBacking =
								MDSSQLiteDocumentBacking(documentType: documentType, documentID: documentID,
										creationDate: creationDate, modificationDate: modificationDate,
										propertyMap: propertyMap, with: self.databaseManager)
					self.documentBackingCache.add([documentBacking])
					infos.append(
							(document,
									MDSDocument.OverviewInfo(documentID: documentID, revision: documentBacking.revision,
											creationDate: creationDate, modificationDate: modificationDate)))

					// Call document changed procs
					documentChangedProcs.forEach() { $0(document, .created) }

					// Add update info
					batchQueue.add(
							MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
									id: documentBacking.id, changedProperties: Set<String>(propertyMap.keys)))
				}

				// Finalize batch queue
				batchQueue.finalize()
			}
		}

		return infos
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentGetCount(for documentType :String) throws -> Int {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		return self.databaseManager.documentCount(for: documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, documentIDs :[String],
			documentCreateProc :MDSDocument.CreateProc, proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Setup
		let	batch = self.batchMap.value(for: .current)

		// Iterate initial document IDs
		var	documentIDsToCache = [String]()
		documentIDs.forEach() {
			// Check what we have currently
			if batch?.documentInfoGet(for: $0) != nil {
				// Have document in batch
				proc(documentCreateProc($0, self))
			} else if self.documentBackingCache.documentBacking(for: $0) != nil {
				// Have documentBacking in cache
				proc(documentCreateProc($0, self))
			} else {
				// Will need to retrieve from database
				documentIDsToCache.append($0)
			}
		}

		// Iterate documentIDs not found in batch or cache
		documentBackingsIterate(documentType: documentType, documentIDs: documentIDsToCache) {
			// Call proc
			proc(documentCreateProc($0.documentID, self))

			// Update
			documentIDsToCache.remove($0.documentID)
		}

		// Check if have any that we didn't find
		if let documentID = documentIDsToCache.first {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, activeOnly: Bool, documentCreateProc :MDSDocument.CreateProc,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, sinceRevision: 0, count: nil, activeOnly: activeOnly)
				{ proc(documentCreateProc($0.documentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// In batch
			return batchDocumentInfo.creationDate
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// "Idle"
			return try! documentBacking(documentType: type(of: document).documentType, documentID: document.id)
					.creationDate
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentModificationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// In batch
			return batchDocumentInfo.modificationDate
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// "Idle"
			return try! documentBacking(documentType: type(of: document).documentType, documentID: document.id)
					.modificationDate
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentValue(for property :String, of document :MDSDocument) -> Any? {
		// Check for batch
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// In batch
			return batchDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			return propertyMap[property]
		} else {
			// "Idle"
			return try! documentBacking(documentType: type(of: document).documentType, documentID: document.id)
					.value(for: property)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentData(for property :String, of document :MDSDocument) -> Data? {
		// Retrieve Base64-encoded string
		guard let string = documentValue(for: property, of: document) as? String else { return nil }

		return Data(base64Encoded: string)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentDate(for property :String, of document :MDSDocument) -> Date? {
		// Return date
		return Date(fromRFC3339Extended: documentValue(for: property, of: document) as? String)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentSet<T : MDSDocument>(_ value :Any?, for property :String, of document :T) {
		// Setup
		let	documentType = type(of: document).documentType
		let	documentID = document.id

		// Transform
		let	valueUse :Any?
		if let data = value as? Data {
			// Data
			valueUse = data.base64EncodedString()
		} else if let date = value as? Date {
			// Date
			valueUse = date.rfc3339Extended
		} else {
			// Everythng else
			valueUse = value
		}

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				batchDocumentInfo.set(valueUse, for: property)
			} else {
				// Don't have document in batch
				let	documentBacking = try! self.documentBacking(documentType: documentType, documentID: documentID)
				batch.documentAdd(documentType: documentType, documentID: documentID, documentBacking: documentBacking,
								creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.set(valueUse, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID) {
			// Being created
			propertyMap[property] = valueUse
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: documentID)
		} else {
			// Update document
			let	documentBacking = try! self.documentBacking(documentType: documentType, documentID: documentID)
			documentBacking.set(valueUse, for: property, documentType: documentType, with: self.databaseManager)

			// Update stuffs
			let	updateInfos :[MDSUpdateInfo<Int64>] =
						[MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
								id: documentBacking.id, changedProperties: [property])]
			update(for: documentType, updateInfo: (updateInfos, []))

			// Call document changed procs
			self.documentChangedProcs(for: documentType).forEach() { $0(document, .updated) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any],
			content :Data) throws -> MDSDocument.AttachmentInfo {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				return batchDocumentInfo.attachmentAdd(info: info, content: content)
			} else {
				// Don't have document in batch
				let	documentBacking = try! self.documentBacking(documentType: documentType, documentID: documentID)

				return batch.documentAdd(documentType: documentType, documentID: documentID,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentAdd(info: info, content: content)
			}
		} else {
			// Not in batch
			return try self.documentBacking(documentType: documentType, documentID: documentID)
					.attachmentAdd(documentType: documentType, info: info, content: content, with: self.databaseManager)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentInfoMap(for documentType :String, documentID :String) throws ->
			MDSDocument.AttachmentInfoMap {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
			// Have document in batch
			return batchDocumentInfo.documentAttachmentInfoMap(
					applyingChangesTo: batchDocumentInfo.documentBacking?.attachmentInfoMap ?? [:])
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: documentID) != nil {
			// Creating
			return [:]
		} else {
			// Retrieve document backing
			return try self.documentBacking(documentType: documentType, documentID: documentID).attachmentInfoMap
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws ->
			Data {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
			// Have document in batch
			if let content = batchDocumentInfo.attachmentContent(for: attachmentID) {
				// Found
				return content
			}
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: documentID) != nil {
			// Creating
			throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
		}

		// Get non-batch attachmentMap
		let	documentBacking = try self.documentBacking(documentType: documentType, documentID: documentID)
		guard documentBacking.attachmentInfoMap[attachmentID] != nil else {
			// Don't have attachment
			throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
		}

		return documentBacking.attachmentContent(documentType: documentType, attachmentID: attachmentID,
				with: self.databaseManager)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				let	documentAttachmentInfoMap =
							batchDocumentInfo.documentAttachmentInfoMap(
									applyingChangesTo: batchDocumentInfo.documentBacking?.attachmentInfoMap ?? [:])
				guard let attachmentInfo = documentAttachmentInfoMap[attachmentID] else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batchDocumentInfo.attachmentUpdate(id: attachmentID, currentRevision: attachmentInfo.revision,
						info: updatedInfo, content: updatedContent)
			} else {
				// Don't have document in batch
				let	documentBacking = try self.documentBacking(documentType: documentType, documentID: documentID)
				guard let attachmentInfo = documentBacking.attachmentInfoMap[attachmentID] else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batch.documentAdd(documentType: documentType, documentID: documentID, documentBacking: documentBacking,
								creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentUpdate(id: attachmentID, currentRevision: attachmentInfo.revision,
								info: updatedInfo, content: updatedContent)
			}

			return -1
		} else {
			// Not in batch
			let	documentBacking = try self.documentBacking(documentType: documentType, documentID: documentID)
			guard documentBacking.attachmentInfoMap[attachmentID] != nil else {
				throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
			}

			// Update attachment
			return documentBacking.attachmentUpdate(documentType: documentType, attachmentID: attachmentID,
					updatedInfo: updatedInfo, updatedContent: updatedContent, with: self.databaseManager)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				let	documentAttachmentInfoMap =
							batchDocumentInfo.documentAttachmentInfoMap(
									applyingChangesTo: batchDocumentInfo.documentBacking?.attachmentInfoMap ?? [:])
				guard documentAttachmentInfoMap[attachmentID] != nil else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batchDocumentInfo.attachmentRemove(id: attachmentID)
			} else {
				// Don't have document in batch
				let	documentBacking = try self.documentBacking(documentType: documentType, documentID: documentID)
				guard documentBacking.attachmentInfoMap[attachmentID] != nil else {
					throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
				}

				batch.documentAdd(documentType: documentType, documentID: documentID, documentBacking: documentBacking,
								creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentRemove(id: attachmentID)
			}
		} else {
			// Not in batch
			let	documentBacking = try self.documentBacking(documentType: documentType, documentID: documentID)
			guard documentBacking.attachmentInfoMap[attachmentID] != nil else {
				throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
			}

			// Remove attachment
			documentBacking.attachmentRemove(documentType: documentType, attachmentID: attachmentID,
					with: self.databaseManager)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentRemove(_ document :MDSDocument) throws {
		// Setup
		let	documentType = type(of: document).documentType
		let	documentID = document.id

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = try! self.documentBacking(documentType: documentType, documentID: documentID)
				batch.documentAdd(documentType: documentType, documentID: documentID, documentBacking: documentBacking,
								creationDate: Date(), modificationDate: Date())
						.remove()
			}
		} else {
			// Not in batch
			let	documentBacking = try! self.documentBacking(documentType: documentType, documentID: documentID)

			// Remove from stuffs
			update(for: documentType, updateInfo: ([], [documentBacking.id]))

			// Remove
			self.databaseManager.documentRemove(documentType: documentType, id: documentBacking.id)

			// Remove from cache
			self.documentBackingCache.remove([documentID])

			// Call document changed procs
			self.documentChangedProcs(for: documentType).forEach() { $0(document, .removed) }
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

		// Register index
		let	lastRevision =
					self.databaseManager.indexRegister(name: name, documentType: documentType,
							relevantProperties: relevantProperties, keysSelector: keysSelector,
							keysSelectorInfo: keysInfo)

		// Create or re-create index
		let	index =
					MDSIndex(name: name, documentType: documentType, relevantProperties: relevantProperties,
							keysProc: keysProc, keysInfo: keysInfo, lastRevision: lastRevision)

		// Add to maps
		self.indexesByNameMap.set(index, for: name)
		self.indexesByDocumentTypeMap.append(index, for: documentType)

		// Bring up to date
		indexUpdate(index, updateInfo: self.updateInfo(for: documentType, sinceRevision: lastRevision))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws {
		// Validate
		guard let index = index(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Bring up to date
		autoreleasepool() { indexUpdate(index, updateInfo: self.updateInfo(for: index.documentType, sinceRevision: 0)) }

		// Compose map
		var	documentIDMap = [/* Key */ String : /* String */ String]()
		autoreleasepool() {
			// Iterate index
			self.indexIterate(name: name, documentType: documentType, keys: keys) {documentIDMap[$0] = $1.documentID }
		}

		// Iterate map
		let	documentCreateProc = self.documentCreateProc(for: documentType)
		autoreleasepool() { documentIDMap.forEach() { proc($0.key, documentCreateProc($0.value, self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoGet(for keys :[String]) throws -> [String : String] {
		// Return dictionary
		return [String : String](keys){ self.databaseManager.infoString(for: $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoSet(_ info :[String : String]) throws {
		// Iterate keys and values
		info.forEach() { self.databaseManager.infoSet($0.value, for: $0.key) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoRemove(keys :[String]) throws  { keys.forEach() { self.databaseManager.infoSet(nil, for: $0) } }

	//------------------------------------------------------------------------------------------------------------------
	public func internalGet(for keys :[String]) -> [String : String] {
		// Return dictionary
		return [String : String](keys){ self.databaseManager.internalString(for: $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalSet(_ info :[String : String]) throws {
		// Iterate keys and values
		info.forEach() { self.databaseManager.internalSet($0.value, for: $0.key) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatch<Any>.Result) rethrows {
		// Setup
		let	batch = Batch()

		// Store
		self.batchMap.set(batch, for: .current)

		// Run lean
		var	result = MDSBatch<Any>.Result.commit
		try autoreleasepool() {
			// Call proc
			result = try proc()
		}

		// Check result
		if result == .commit {
			// Batch changes
			self.databaseManager.batch() {
				// Iterate all document changes
			batch.documentInfosByDocumentType.forEach() { documentType, batchDocumentInfosByDocumentID in
					// Setup
					let	documentCreateProc = documentCreateProc(for: documentType)
					let	documentChangedProcs = self.documentChangedProcs(for: documentType)
					let	updateBatchQueue =
								BatchQueue<MDSUpdateInfo<Int64>>(
										maximumBatchSize: self.databaseManager.variableNumberLimit)
										{ self.update(for: documentType, updateInfo: ($0, [])) }
					let	removeBatchQueue =
								BatchQueue<Int64>(maximumBatchSize: self.databaseManager.variableNumberLimit)
										{ self.update(for: documentType, updateInfo: ([], $0)) }

					// Update documents
					batchDocumentInfosByDocumentID.forEach() { documentID, batchDocumentInfo in
						// Check removed
						if !batchDocumentInfo.removed {
							// Add/update document
							if let documentBacking = batchDocumentInfo.documentBacking {
								// Update document
								documentBacking.update(documentType: documentType,
										updatedPropertyMap: batchDocumentInfo.updatedPropertyMap,
										removedProperties: batchDocumentInfo.removedProperties,
										with: self.databaseManager)

								// Create document
								let	document = documentCreateProc(documentID, self)

								// Add updates to BatchQueue
								let	changedProperties =
											Set<String>(batchDocumentInfo.updatedPropertyMap.keys)
													.union(batchDocumentInfo.removedProperties)
								updateBatchQueue.add(
										MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
												id: documentBacking.id, changedProperties: changedProperties))

								// Process attachments
								batchDocumentInfo.removedAttachmentIDs.forEach() {
									// Remove attachment
									documentBacking.attachmentRemove(documentType: documentType, attachmentID: $0,
											with: self.databaseManager)
								}
								batchDocumentInfo.addAttachmentInfosByID.values.forEach() {
									// Add attachment
									_ = documentBacking.attachmentAdd(documentType: documentType, info: $0.info,
											content: $0.content, with: self.databaseManager)
								}
								batchDocumentInfo.updateAttachmentInfosByID.values.forEach() {
									// Update attachment
									_ = documentBacking.attachmentUpdate(documentType: documentType,
											attachmentID: $0.id, updatedInfo: $0.info,
											updatedContent: $0.content, with: self.databaseManager)
								}

								// Call document changed procs
								documentChangedProcs.forEach() { $0(document, .updated) }
							} else {
								// Add document
								let	documentBacking =
											MDSSQLiteDocumentBacking(documentType: documentType, documentID: documentID,
													creationDate: batchDocumentInfo.creationDate,
													modificationDate: batchDocumentInfo.modificationDate,
													propertyMap: batchDocumentInfo.updatedPropertyMap,
													with: self.databaseManager)
								self.documentBackingCache.add([documentBacking])

								// Create document
								let	document = documentCreateProc(documentID, self)

								// Add updates to BatchQueue
								updateBatchQueue.add(
										MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
												id: documentBacking.id, changedProperties: nil))

								// Process attachments
								batchDocumentInfo.addAttachmentInfosByID.values.forEach() {
									// Add attachment
									_ = documentBacking.attachmentAdd(documentType: documentType, info: $0.info,
											content: $0.content, with: self.databaseManager)
								}

								// Call document changed procs
								documentChangedProcs.forEach() { $0(document, .created) }
							}
						} else if let documentBacking = batchDocumentInfo.documentBacking {
							// Remove document
							self.databaseManager.documentRemove(documentType: documentType, id: documentBacking.id)
							self.documentBackingCache.remove([documentID])

							// Add updates to BatchQueue
							removeBatchQueue.add(documentBacking.id)

							// Check if have documentChangedProcs
							if !documentChangedProcs.isEmpty {
								// Create document
								let	document = documentCreateProc(documentID, self)

								// Call document changed procs
								documentChangedProcs.forEach() { $0(document, .removed) }
							}
						}
					}

					// Finalize updates
					removeBatchQueue.finalize()
					updateBatchQueue.finalize()
				}
			}
		}

		// Remove - must wait to do this until the batch has been fully processed in case processing Collections and
		//	Indexes ends up referencing other documents that have not yet been committed.
		self.batchMap.set(nil, for: .current)
	}

	// MARK: MDSDocumentStorageServer methods
	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Get count
		guard let totalCount =
					self.databaseManager.associationGetCount(name: name, fromDocumentID: fromDocumentID,
							fromDocumentType: association.fromDocumentType) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}

		// Collect MDSDocument RevisionInfos
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		try autoreleasepool() {
			// Iterate association
			try self.databaseManager.associationIterateDocumentInfos(name: name, fromDocumentID: fromDocumentID,
					fromDocumentType: association.fromDocumentType, toDocumentType: association.toDocumentType,
					startIndex: startIndex, count: count) { documentRevisionInfos.append($0.documentRevisionInfo) }
		}

		return (totalCount, documentRevisionInfos)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws
			-> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Get count
		guard let totalCount =
					self.databaseManager.associationGetCount(name: name, toDocumentID: toDocumentID,
							toDocumentType: association.toDocumentType) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: toDocumentID)
		}

		// Collect MDSDocument RevisionInfos
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		try autoreleasepool() {
			// Iterate association
			try self.databaseManager.associationIterateDocumentInfos(name: name, toDocumentID: toDocumentID,
					toDocumentType: association.toDocumentType, fromDocumentType: association.fromDocumentType,
					startIndex: startIndex, count: count) { documentRevisionInfos.append($0.documentRevisionInfo) }
		}

		return (totalCount, documentRevisionInfos)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?) throws
			-> (totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Get count
		guard let totalCount =
					self.databaseManager.associationGetCount(name: name, fromDocumentID: fromDocumentID,
							fromDocumentType: association.fromDocumentType) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}

		// Collect MDSDocument FullInfos
		var	documentFullInfos = [MDSDocument.FullInfo]()
		try autoreleasepool() {
			try associationIterate(association: association, fromDocumentID: fromDocumentID, startIndex: startIndex,
					count: count) { documentFullInfos.append($0.documentFullInfo) }
		}

		return (totalCount, documentFullInfos)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
		// Validate
		guard let association = association(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Get count
		guard let totalCount =
					self.databaseManager.associationGetCount(name: name, toDocumentID: toDocumentID,
							toDocumentType: association.toDocumentType) else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: toDocumentID)
		}

		// Collect MDSDocument FullInfos
		var	documentFullInfos = [MDSDocument.FullInfo]()
		try autoreleasepool() {
			try associationIterate(association: association, toDocumentID: toDocumentID, startIndex: startIndex,
					count: count) { documentFullInfos.append($0.documentFullInfo) }
		}

		return (totalCount, documentFullInfos)
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentRevisionInfos(name :String, startIndex :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
		// Setup
		let	collection = collection(for: name)!

		// Collect MDSDocument RevisionInfos
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		autoreleasepool() {
			// Iterate collection
			self.databaseManager.collectionIterateDocumentInfos(for: name, documentType: collection.documentType,
					startIndex: startIndex, count: count) { documentRevisionInfos.append($0.documentRevisionInfo) }
		}

		return documentRevisionInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentFullInfos(name :String, startIndex :Int, count :Int?) throws -> [MDSDocument.FullInfo] {
		// Setup
		let	collection = collection(for: name)!

		// Collect MDSDocument FullInfos
		var	documentFullInfos = [MDSDocument.FullInfo]()
		autoreleasepool() {
			collectionIterate(name: name, documentType: collection.documentType, startIndex: startIndex, count: count)
					{ documentFullInfos.append($0.documentFullInfo) }
		}

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRevisionInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.RevisionInfo] {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Iterate
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		self.databaseManager.documentInfoIterate(documentType: documentType, documentIDs: documentIDs)
				{ documentRevisionInfos.append($0.documentRevisionInfo) }

		return documentRevisionInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRevisionInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Iterate
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		self.databaseManager.documentInfoIterate(documentType: documentType, sinceRevision: sinceRevision, count: count,
				activeOnly: false) { documentRevisionInfos.append($0.documentRevisionInfo) }

		return documentRevisionInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentFullInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.FullInfo] {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Iterate initial document IDs
		var	documentFullInfos = [MDSDocument.FullInfo]()
		var	documentIDsToCache = [String]()
		documentIDs.forEach() {
			// Check what we have currently
			if let documentBacking = self.documentBackingCache.documentBacking(for: $0) {
				// Have documentBacking in cache
				documentFullInfos.append(documentBacking.documentFullInfo)
			} else {
				// Will need to retrieve from database
				documentIDsToCache.append($0)
			}
		}

		// Iterate documentIDs not found in batch or cache
		documentBackingsIterate(documentType: documentType, documentIDs: documentIDsToCache) {
			// Call proc
			documentFullInfos.append($0.documentFullInfo)

			// Update
			documentIDsToCache.remove($0.documentID)
		}

		// Check if have any that we didn't find
		if let documentID = documentIDsToCache.first {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentFullInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.FullInfo] {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Iterate document backings
		var	documentFullInfos = [MDSDocument.FullInfo]()
		documentBackingsIterate(documentType: documentType, sinceRevision: sinceRevision, count: count,
				activeOnly: false) { documentFullInfos.append($0.documentFullInfo) }

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentIntegerValue(for documentType :String, document :MDSDocument, property :String) -> Int64? {
		// Check for batch
		let	value :Any?
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// In batch
			value = batchDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			value = propertyMap[property]
		} else {
			// "Idle"
			value = try! documentBacking(documentType: documentType, documentID: document.id).value(for: property)
		}

		return value as? Int64
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentStringValue(for documentType :String, document :MDSDocument, property :String) -> String? {
		// Check for batch
		let	value :Any?
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// In batch
			value = batchDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Being created
			value = propertyMap[property]
		} else {
			// "Idle"
			value = try! documentBacking(documentType: documentType, documentID: document.id).value(for: property)
		}

		return value as? String
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo] {
		// Validate
		guard self.databaseManager.isKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Batch changes
		return self.databaseManager.batch() {
			// Setup
			let	map = Dictionary(documentUpdateInfos.map() { ($0.documentID, $0) })
			let	updateBatchQueue =
						BatchQueue<MDSUpdateInfo<Int64>>(maximumBatchSize: self.databaseManager.variableNumberLimit)
								{ self.update(for: documentType, updateInfo: ($0, [])) }
			let	removedBatchQueue =
						BatchQueue<Int64>(maximumBatchSize: 999)
								{ self.update(for: documentType, updateInfo: ([], $0)) }
			var	documentFullInfos = [MDSDocument.FullInfo]()

			// Iterate document IDs
			documentBackingsIterate(documentType: documentType, documentIDs: Array(map.keys)) {
				// Setup
				let	documentCreateProc = self.documentCreateProc(for: documentType)

				// Set update info
				let	documentUpdateInfo = map[$0.documentID]!

				// Check active
				if documentUpdateInfo.active {
					// Update document
					$0.update(documentType: documentType,
							updatedPropertyMap: documentUpdateInfo.updated,
							removedProperties: Set(documentUpdateInfo.removed), with: self.databaseManager)

					// Prepare for cache, collection, and index updates
					let	document = documentCreateProc($0.documentID, self)
					let	changedProperties =
								Set<String>(documentUpdateInfo.updated.keys).union(documentUpdateInfo.removed)
					updateBatchQueue.add(
							MDSUpdateInfo<Int64>(document: document, revision: $0.revision, id: $0.id,
									changedProperties: changedProperties))
				} else {
					// Remove document
					self.databaseManager.documentRemove(documentType: documentType, id: $0.id)
					self.documentBackingCache.remove([$0.documentID])

					// Remove from collections and indexes
					removedBatchQueue.add($0.id)
				}

				// Update array
				documentFullInfos.append($0.documentFullInfo)
			}

			// Finalize batch queues
			updateBatchQueue.finalize()
			removedBatchQueue.finalize()

			return documentFullInfos
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentRevisionInfos(name :String, keys :[String]) throws -> [String : MDSDocument.RevisionInfo] {
		// Validate
		guard let index = index(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		// Compose MDSDocument RevisionInfo map
		var	documentRevisionInfoMap = [String : MDSDocument.RevisionInfo]()
		autoreleasepool() {
			// Iterate index
			self.databaseManager.indexIterateDocumentInfos(name: name, documentType: index.documentType, keys: keys)
					{ documentRevisionInfoMap[$0] = $1.documentRevisionInfo }
		}

		return documentRevisionInfoMap
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentFullInfos(name :String, keys :[String]) throws -> [String : MDSDocument.FullInfo] {
		// Validate
		guard let index = index(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		// Compose MDSDocument FullInfo map
		var	documentFullInfoMap = [String : MDSDocument.FullInfo]()
		autoreleasepool() {
			// Iterate index
			self.indexIterate(name: name, documentType: index.documentType, keys: keys)
					{ documentFullInfoMap[$0] = $1.documentFullInfo }
		}

		return documentFullInfoMap
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func association(for name :String) -> MDSAssociation? {
		// Check if have loaded
		if let association = self.associationsByNameMap.value(for: name) {
			// Have loaded
			return association
		} else if let info = self.databaseManager.associationInfo(for: name) {
			// Have stored
			let	association =
						MDSAssociation(name: name, fromDocumentType: info.fromDocumentType,
								toDocumentType: info.toDocumentType)
			self.associationsByNameMap.set(association, for: name)

			return association
		} else {
			// Sorry
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func associationIterate(association :MDSAssociation, fromDocumentID :String, startIndex :Int,
			count :Int?, proc :(_ documentBacking :MDSSQLiteDocumentBacking) -> Void) throws {
		// Collect DocumentInfos
		var	documentInfos = [MDSSQLiteDatabaseManager.DocumentInfo]()
		try autoreleasepool() {
			// Iterate association
			try self.databaseManager.associationIterateDocumentInfos(name: association.name,
					fromDocumentID: fromDocumentID, fromDocumentType: association.fromDocumentType,
					toDocumentType: association.toDocumentType, startIndex: startIndex, count: count)
					{ documentInfos.append($0) }
		}

		// Iterate document backings
		documentBackingsIterate(documentType: association.toDocumentType, infos: documentInfos.map({ ("", $0) }))
				{ proc($1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func associationIterate(association :MDSAssociation, toDocumentID :String, startIndex :Int,
			count :Int?, proc :(_ documentBacking :MDSSQLiteDocumentBacking) -> Void) throws {
		// Collect DocumentInfos
		var	documentInfos = [MDSSQLiteDatabaseManager.DocumentInfo]()
		try autoreleasepool() {
			// Iterate association
			try self.databaseManager.associationIterateDocumentInfos(name: association.name, toDocumentID: toDocumentID,
					toDocumentType: association.toDocumentType, fromDocumentType: association.fromDocumentType,
					startIndex: startIndex, count: count) { documentInfos.append($0) }
		}

		// Iterate document backings
		documentBackingsIterate(documentType: association.fromDocumentType, infos: documentInfos.map({ ("", $0) }))
				{ proc($1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func cache(for name :String) -> MDSCache? {
		// Check if have loaded
		if let cache = self.cachesByNameMap.value(for: name) {
			// Have loaded
			return cache
		} else if let info = self.databaseManager.cacheInfo(for: name) {
			// Have stored
			let	valueInfos =
						info.valueInfos.map(
								{ MDSCache.ValueInfo(valueInfo: MDSValueInfo(name: $0.name, type: $0.valueType),
										selector: $0.selector, proc: self.documentValueProc(for: $0.selector)!) })
			let	cache =
						MDSCache(name: name, documentType: info.documentType,
								relevantProperties: info.relevantProperties, valueInfos: valueInfos,
								lastRevision: info.lastRevision)
			self.cachesByNameMap.set(cache, for: name)

			return cache
		} else {
			// Sorry
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func cacheUpdate(_ cache :MDSCache,
			updateInfo :(updateInfos :[MDSUpdateInfo<Int64>], removedIDs :[Int64])) {
		// Update Cache
		let	(infosByValue, lastRevision) = cache.update(updateInfo.updateInfos)

		// Check if have updates
		if !updateInfo.removedIDs.isEmpty || (lastRevision != nil) {
			// Update database
			self.databaseManager.cacheUpdate(name: cache.name, infosByValue: infosByValue,
					removedIDs: updateInfo.removedIDs, lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func collection(for name :String) -> MDSCollection? {
		// Check if have loaded
		if let collection = self.collectionsByNameMap.value(for: name) {
			// Have loaded
			return collection
		} else if let info = self.databaseManager.collectionInfo(for: name) {
			// Have stored
			let	collection =
						MDSCollection(name: name, documentType: info.documentType,
								relevantProperties: info.relevantProperties,
								documentIsIncludedProc: self.documentIsIncludedProc(for: info.isIncludedSelector)!,
								isIncludedInfo: info.isIncludedSelectorInfo, lastRevision: info.lastRevision)
			self.collectionsByNameMap.set(collection, for: name)

			return collection
		} else {
			// Sorry
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func collectionIterate(name :String, documentType :String, startIndex :Int, count :Int?,
			proc :(_ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Collect DocumentInfos
		var	documentInfos = [MDSSQLiteDatabaseManager.DocumentInfo]()
		autoreleasepool() {
			// Iterate collection
			self.databaseManager.collectionIterateDocumentInfos(for: name, documentType: documentType,
					startIndex: startIndex, count: count) { documentInfos.append($0) }
		}

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, infos: documentInfos.map({ ("", $0) })) { proc($1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func collectionUpdate(_ collection :MDSCollection,
			updateInfo :(updateInfos :[MDSUpdateInfo<Int64>], removedIDs :[Int64])) {
		// Update Collection
		var	(includedIDs, notIncludedIDs, lastRevision) = collection.update(updateInfo.updateInfos)

		// Process results
		if !updateInfo.removedIDs.isEmpty {
			// Add removedIDs
			notIncludedIDs = (notIncludedIDs ?? []) + updateInfo.removedIDs
		}

		// Check if have updates
		if (notIncludedIDs != nil) || (lastRevision != nil) {
			// Update database
			self.databaseManager.collectionUpdate(name: collection.name, includedIDs: includedIDs,
					notIncludedIDs: notIncludedIDs, lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBacking(documentType :String, documentID :String) throws -> MDSSQLiteDocumentBacking {
		// Try to retrieve from cache
		if let documentBacking = self.documentBackingCache.documentBacking(for: documentID) {
			// Have document
			return documentBacking
		} else {
			// Try to retrieve from database
			var	documentBacking :MDSSQLiteDocumentBacking?
			documentBackingsIterate(documentType: documentType, documentIDs: [documentID]) { documentBacking = $0 }

			// Check results
			guard documentBacking != nil else {
				throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
			}

			// Update cache
			self.documentBackingCache.add([documentBacking!])

			return documentBacking!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate(documentType :String, documentIDs :[String],
			proc :(_ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Collect DocumentInfos
		var	documentInfos = [MDSSQLiteDatabaseManager.DocumentInfo]()
		self.databaseManager.documentInfoIterate(documentType: documentType, documentIDs: documentIDs)
				{ documentInfos.append($0) }

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, infos: documentInfos.map({ ("", $0) })) { proc($1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate(documentType :String, sinceRevision :Int, count :Int? = nil, activeOnly: Bool,
			proc :(_ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Collect DocumentInfos
		var	documentInfos = [MDSSQLiteDatabaseManager.DocumentInfo]()
		self.databaseManager.documentInfoIterate(documentType: documentType, sinceRevision: sinceRevision,
				count: count, activeOnly: activeOnly) { documentInfos.append($0) }

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, infos: documentInfos.map({ ("", $0) })) { proc($1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate(documentType :String,
			infos :[(key :String, documentInfo :MDSSQLiteDatabaseManager.DocumentInfo)],
			proc :(_ key :String, _ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Iterate infos
		var	infosNotFound = [(key :String, documentInfo :MDSSQLiteDatabaseManager.DocumentInfo)]()
		infos.forEach() {
			// Check cache
			if let documentBacking = self.documentBackingCache.documentBacking(for: $0.documentInfo.documentID) {
				// Have in cache
				proc($0.key, documentBacking)
			} else {
				// Don't have in cache
				infosNotFound.append($0)
			}
		}

		// Collect DocumentContentInfos
		var	documentContentInfosByID = [Int64 : MDSSQLiteDatabaseManager.DocumentContentInfo]()
		self.databaseManager.documentContentInfoIterate(documentType: documentType,
				documentInfos: infosNotFound.map({ $0.documentInfo })) { documentContentInfosByID[$0.id] = $0 }

		// Iterate infos not found
		infosNotFound.forEach() {
			// Get DocumentContentInfo
			let	documentContentInfo = documentContentInfosByID[$0.documentInfo.id]!

			// Load attachment
			let	attachmentInfoMap =
						self.databaseManager.documentAttachmentInfoMap(documentType: documentType,
								id: $0.documentInfo.id)

			// Create MDSSQLiteDocumentBacking
			let	documentBacking =
						MDSSQLiteDocumentBacking(id: $0.documentInfo.id, documentID: $0.documentInfo.documentID,
								revision: $0.documentInfo.revision, active: $0.documentInfo.active,
								creationDate: documentContentInfo.creationDate,
								modificationDate: documentContentInfo.modificationDate,
								propertyMap: documentContentInfo.propertyMap, attachmentInfoMap: attachmentInfoMap)
			self.documentBackingCache.add([documentBacking])

			// Call proc
			proc($0.key, documentBacking)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func index(for name :String) -> MDSIndex? {
		// Check if have loaded
		if let index = self.indexesByNameMap.value(for: name) {
			// Have loaded
			return index
		} else if let info = self.databaseManager.indexInfo(for: name) {
			// Have stored
			let	index =
						MDSIndex(name: name, documentType: info.documentType,
								relevantProperties: info.relevantProperties,
								keysProc: self.documentKeysProc(for: info.keysSelector)!,
								keysInfo: info.keysSelectorInfo, lastRevision: info.lastRevision)
			self.indexesByNameMap.set(index, for: name)

			return index
		} else {
			// Sorry
			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Compose MDSDocument RevisionInfo map
		var	documentInfosByKey = [String : MDSSQLiteDatabaseManager.DocumentInfo]()
		autoreleasepool() {
			// Iterate index
			self.databaseManager.indexIterateDocumentInfos(name: name, documentType: documentType, keys: keys)
					{ documentInfosByKey[$0] = $1 }
		}

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, infos: documentInfosByKey.map({ ($0.key, $0.value) }))
				{ proc($0, $1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func indexUpdate(_ index :MDSIndex,
			updateInfo :(updateInfos :[MDSUpdateInfo<Int64>], removedIDs :[Int64])) {
		// Update Index
		let	(keysInfos, lastRevision) = index.update(updateInfo.updateInfos)

		// Check if have updates
		if !updateInfo.removedIDs.isEmpty || (lastRevision != nil) {
			// Update database
			self.databaseManager.indexUpdate(name: index.name, keysInfos: keysInfos, removedIDs: updateInfo.removedIDs,
					lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateInfo(for documentType :String, sinceRevision: Int) ->
			(updateInfos :[MDSUpdateInfo<Int64>], removedIDs :[Int64]) {
		// Setup
		let	documentCreateProc = self.documentCreateProc(for: documentType)
		let	batch = self.batchMap.value(for: .current)

		// Collect update infos
		var	updateInfos = [MDSUpdateInfo<Int64>]()
		var	removedIDs = [Int64]()
		documentBackingsIterate(documentType: documentType, sinceRevision: sinceRevision, activeOnly: false) {
			// Query batch info
			let batchDocumentInfo = batch?.documentInfoGet(for: $0.documentID)

			// Ensure we want to process this document
			if !(batchDocumentInfo?.removed ?? !$0.active) {
				// Append info
				updateInfos.append(
						MDSUpdateInfo<Int64>(document: documentCreateProc($0.documentID, self), revision: $0.revision,
								id: $0.id))
			} else {
				// Removed
				removedIDs.append($0.id)
			}
		}

		return (updateInfos, removedIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func update(for documentType :String,
			updateInfo: (updateInfos :[MDSUpdateInfo<Int64>], removedIDs :[Int64])) {
		// Update caches
		self.cachesByDocumentTypeMap.values(for: documentType)?.forEach()
			{ self.cacheUpdate($0, updateInfo: updateInfo) }

		// Update collections
		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach()
			{ self.collectionUpdate($0, updateInfo: updateInfo) }

		// Update indexes
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach()
			{ self.indexUpdate($0, updateInfo: updateInfo) }
	}
}
