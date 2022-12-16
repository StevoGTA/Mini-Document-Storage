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
public class MDSSQLite : MDSHTTPServicesHandler {

	// MARK: Properties
	public	var	id :String = UUID().uuidString

	private	var	associationsByNameMap = LockingDictionary</* Name */ String, MDSAssociation>()
	private	var	associationItemsByNameMap = LockingArrayDictionary</* Name */ String, MDSAssociation.Item>()

	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<MDSSQLiteDocumentBacking>>()

	private	let	cachesByNameMap = LockingDictionary</* Name */ String, MDSCache>()
	private	let	cachesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCache>()

	private	let	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	let	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()

	private	let	databaseManager :MDSSQLiteDatabaseManager

	private	var	ephemeralValues :[/* Key */ String : Any]?

	private	let	documentBackingCache = MDSDocumentBackingCache<MDSSQLiteDocumentBacking>()
	private	let	documentCreateProcMap = LockingDictionary<String, MDSDocument.CreateProc>()
	private	let	documentChangedProcsMap = LockingArrayDictionary</* Document Type */ String, MDSDocument.ChangedProc>()
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
// TODO: associationRegister(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
// TODO: associationUpdate(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(for name :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, associationItems :[MDSAssociation.Item]) {
// TODO: associationGet(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
// TODO: associationIterate(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, to toDocumentID :String, fromDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
// TODO: associationIterate(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetIntegerValue(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentID :String, cacheName :String, cachedValueName :String) throws -> Int {
// TODO: associationGetIntegerValue(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(named name :String, documentType :String, relevantProperties :[String],
			valueInfos :[(name :String, valueType :MDSValue.Type_, selector :String, proc :MDSDocument.ValueProc)])
			throws {
// TODO: cacheRegister(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String, isIncludedProcVersion :Int,
			isIncludedProc :@escaping MDSDocument.IsIncludedProc) throws {
		// Validate
		guard self.databaseManager.documentIsKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Remove current collection if found
		if let collection = self.collectionsByNameMap.value(for: name) {
			// Remove
			self.collectionsByDocumentTypeMap.remove(collection, for: documentType)
		}

		// Register collection
		let	lastRevision =
					self.databaseManager.collectionRegister(documentType: documentType, name: name,
							version: isIncludedProcVersion, isUpToDate: isUpToDate)

		// Create or re-create collection
		let	collection =
					MDSCollection(name: name, documentType: documentType, relevantProperties: relevantProperties,
							lastRevision: lastRevision, isIncludedProc: isIncludedProc, isIncludedInfo: isIncludedInfo)

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
		guard self.collectionsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}

//		// Run lean
//		autoreleasepool() { _ = bringCollectionUpToDate(name: name) }

		return self.databaseManager.collectionGetDocumentCount(for: name)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard self.collectionsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}

//		// Bring up to date
//		_ = autoreleasepool() { bringCollectionUpToDate(name: name) }
//
		// Collect document IDs
		var	documentIDs = [String]()
		autoreleasepool() {
			collectionIterate(name: name, documentType: documentType, startIndex: 0, count: nil)
					{ documentIDs.append($0.documentID) }
		}

		// Iterate document IDs
		let	documentCreateProc =
				self.documentCreateProcMap.value(for: documentType) ?? { MDSDocument(id: $0, documentStorage: $1) }
		autoreleasepool() { documentIDs.forEach() { proc(documentCreateProc($0, self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
			proc :MDSDocument.CreateProc) ->
			[(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)] {
		// Setup
		let	date = Date()
		var	infos = [(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)]()

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
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
			let	documentChangedProcs = self.documentChangedProcsMap.values(for: documentType)

			// Batch
			self.databaseManager.batch() {
				// Setup
				let	batchQueue =
							BatchQueue<MDSUpdateInfo<Int64>>(
									maximumBatchSize: self.databaseManager.variableNumberLimit) {
//								// Update collections and indexes
//								self.updateCollections(for: documentType, updateInfos: $0)
//								self.updateIndexes(for: documentType, updateInfos: $0)
_ = $0
							}

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
					documentChangedProcs?.forEach() { $0(document, .created) }

					// Update collections and indexes
					batchQueue.add(
							MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
									value: documentBacking.id, changedProperties: Set<String>(propertyMap.keys)))
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
		guard self.databaseManager.documentIsKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		return self.databaseManager.documentCount(for: documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, documentIDs :[String],
			documentCreateProc :MDSDocument.CreateProc?,
			proc :(_ document :MDSDocument?, _ documentFullInfo :MDSDocument.FullInfo) -> Void) throws {
		// Validate
		guard self.databaseManager.documentIsKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Setup
		let	batchInfo = self.batchInfoMap.value(for: Thread.current)

		// Iterate initial document IDs
		var	documentIDsToCache = Set<String>()
		documentIDs.forEach() {
			// Check what we have currently
			if let documentInfo = batchInfo?.documentGetInfo(for: $0) {
				// Have document in batch
				proc(documentCreateProc?($0, self), documentInfo.documentBacking!.documentFullInfo)
			} else if let documentBacking = self.documentBackingCache.documentBacking(for: $0) {
				// Have documentBacking in cache
				proc(documentCreateProc?($0, self), documentBacking.documentFullInfo)
			} else {
				// Will need to retrieve from database
				documentIDsToCache.insert($0)
			}
		}

		// Iterate documentIDs not found in batch or cache
		documentBackingsIterate(documentType: documentType, documentIDs: Array(documentIDsToCache)) {
			// Call proc
			proc(documentCreateProc?($0.documentID, self), $0.documentFullInfo)

			// Update
			documentIDsToCache.remove($0.documentID)
		}

		// Check if have any that we didn't find
		if let documentID = documentIDsToCache.first {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, sinceRevision :Int, count :Int?, activeOnly: Bool,
			documentCreateProc :MDSDocument.CreateProc?,
			proc :(_ document :MDSDocument?, _ documentFullInfo :MDSDocument.FullInfo) -> Void) throws {
		// Validate
		guard self.databaseManager.documentIsKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check if have count
		if count != nil {
			// Have count
			var	documentBackings = [MDSSQLiteDocumentBacking]()
			documentBackingsIterate(documentType: documentType, sinceRevision: sinceRevision,
					activeOnly: activeOnly) { documentBackings.append($0) }

			documentBackings[..<count!]
					.forEach({ proc(documentCreateProc?($0.documentID, self), $0.documentFullInfo) })
		} else {
			// Don't have count
			documentBackingsIterate(documentType: documentType, sinceRevision: sinceRevision, activeOnly: activeOnly)
					{ proc(documentCreateProc?($0.documentID, self), $0.documentFullInfo) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
				// Have document in batch
				batchDocumentInfo.set(valueUse, for: property)
			} else {
				// Don't have document in batch
				let	documentBacking = try! self.documentBacking(documentType: documentType, documentID: documentID)
				batchInfo.documentAdd(documentType: documentType, documentID: documentID,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
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

//			// Update collections and indexes
//			let	updateInfos :[MDSUpdateInfo<Int64>] =
//						[MDSUpdateInfo<Int64>(document: document, revision: documentBacking.revision,
//								value: documentBacking.id, changedProperties: [property])]
//			updateCollections(for: documentType, updateInfos: updateInfos)
//			updateIndexes(for: documentType, updateInfos: updateInfos)

			// Call document changed procs
			self.documentChangedProcsMap.values(for: documentType)?.forEach() { $0(document, .updated) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any],
			content :Data) throws -> MDSDocument.AttachmentInfo {
// TODO: documentAttachmentAdd(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentInfoMap(for documentType :String, documentID :String) throws ->
			MDSDocument.AttachmentInfoMap {
// TODO: documentAttachmentInfoMap(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws ->
			Data? {
// TODO: documentAttachmentContent(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int {
// TODO: documentAttachmentUpdate(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws {
// TODO: documentAttachmentRemove(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentRemove(_ document :MDSDocument) {
		// Setup
		let	documentType = type(of: document).documentType
		let	documentID = document.id

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = try! self.documentBacking(documentType: documentType, documentID: documentID)
				batchInfo.documentAdd(documentType: documentType, documentID: documentID,
								documentBacking: documentBacking, creationDate: Date(), modificationDate: Date())
						.remove()
			}
		} else {
			// Not in batch
			let	documentBacking = try! self.documentBacking(documentType: documentType, documentID: documentID)

//			// Remove from collections and indexes
//			removeFromCollections(for: documentType, documentBackingIDs: [documentBacking.id])
//			removeFromIndexes(for: documentType, documentBackingIDs: [documentBacking.id])

			// Remove
			self.databaseManager.documentRemove(documentType: documentType, id: documentBacking.id)

			// Remove from cache
			self.documentBackingCache.remove([documentID])

			// Call document changed procs
			self.documentChangedProcsMap.values(for: documentType)?.forEach() { $0(document, .removed) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			keysInfo :[String : Any], keysSelector :String, keysProcVersion :Int,
			keysProc :@escaping MDSDocument.KeysProc) throws {
		// Validate
		guard self.databaseManager.documentIsKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Remove current index if found
		if let index = self.indexesByNameMap.value(for: name) {
			// Remove
			self.indexesByDocumentTypeMap.remove(index, for: documentType)
		}

		// Register index
		let	lastRevision =
					self.databaseManager.indexRegister(documentType: documentType, name: name, version: keysProcVersion,
							isUpToDate: isUpToDate)

		// Create or re-create index
		let	index =
					MDSIndex(name: name, documentType: documentType, relevantProperties: relevantProperties,
							lastRevision: lastRevision, keysProc: keysProc, keysInfo: keysInfo)

		// Add to maps
		self.indexesByNameMap.set(index, for: name)
		self.indexesByDocumentTypeMap.append(index, for: documentType)

		// Check if is up to date
		if !isUpToDate {
			// Bring up to date
			indexUpdate(index, updateInfos: self.updateInfos(for: documentType, sinceRevision: 0))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws {
		// Validate
		guard self.indexesByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		// Compose map
		var	documentIDMap = [/* Key */ String : /* String */ String]()
		autoreleasepool() {
			// Iterate index
			self.indexIterate(name: name, documentType: documentType, keys: keys,
					proc: {documentIDMap[$0] = $1.documentID })
		}

		// Iterate map
		let	documentCreateProc =
				self.documentCreateProcMap.value(for: documentType) ?? { MDSDocument(id: $0, documentStorage: $1) }
		autoreleasepool() { documentIDMap.forEach() { proc($0.key, documentCreateProc($0.value, self)) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) -> [String : String] {
		// Return dictionary
		return [String : String](keys){ self.databaseManager.infoString(for: $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoSet(_ info :[String : String]) {
		// Iterate keys and values
		info.forEach() { self.databaseManager.infoSet($0.value, for: $0.key) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(keys :[String]) { keys.forEach() { self.databaseManager.infoSet(nil, for: $0) } }

	//------------------------------------------------------------------------------------------------------------------
	public func internalGet(for keys :[String]) -> [String : String] {
		// Return dictionary
		return [String : String](keys){ self.databaseManager.internalString(for: $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalSet(_ info :[String : String]) {
		// Iterate keys and values
		info.forEach() { self.databaseManager.internalSet($0.value, for: $0.key) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
//		// Setup
//		let	batchInfo = MDSBatchInfo<MDSSQLiteDocumentBacking>()
//
//		// Store
//		self.batchInfoMap.set(batchInfo, for: Thread.current)
//
//		// Run lean
//		var	result = MDSBatchResult.commit
//		try autoreleasepool() {
//			// Call proc
//			result = try proc()
//		}
//
//		// Check result
//		if result == .commit {
//			// Batch changes
//			self.databaseManager.batch() {
//				// Iterate all document changes
//				batchInfo.documentIterateChanges() { documentType, batchDocumentInfosMap in
//					// Setup
//					let	updateBatchQueue =
//								BatchQueue<MDSUpdateInfo<Int64>>(
//										maximumBatchSize: self.databaseManager.variableNumberLimit) {
//									// Update collections and indexes
//									self.updateCollections(for: documentType, updateInfos: $0)
//									self.updateIndexes(for: documentType, updateInfos: $0)
//								}
//					var	removedDocumentBackingIDs = [Int64]()
//
//					// Update documents
//					batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
//						// Check removed
//						if !batchDocumentInfo.removed {
//							// Add/update document
//							if let documentBacking = batchDocumentInfo.documentBacking {
//								// Update document
//								documentBacking.update(documentType: documentType,
//										updatedPropertyMap: batchDocumentInfo.updatedPropertyMap,
//										removedProperties: batchDocumentInfo.removedProperties,
//										with: self.databaseManager)
//
//								// Check if we have creation proc
//								if let documentCreateProc = self.documentCreateProcMap.value(for: documentType) {
//									// Create document
//									let	document = documentCreateProc(documentID, self)
//
//									// Update collections and indexes
//									let	changedProperties =
//												Set<String>((batchDocumentInfo.updatedPropertyMap ?? [:]).keys)
//														.union(batchDocumentInfo.removedProperties ?? Set<String>())
//									updateBatchQueue.add(
//											MDSUpdateInfo<Int64>(document: document,
//													revision: documentBacking.revision, value: documentBacking.id,
//													changedProperties: changedProperties))
//
//									// Call document changed procs
//									self.documentChangedProcsMap.values(for: documentType)?.forEach()
//										{ $0(document, .updated) }
//								}
//							} else {
//								// Add document
//								let	documentBacking =
//											MDSSQLiteDocumentBacking(documentType: documentType, documentID: documentID,
//													creationDate: batchDocumentInfo.creationDate,
//													modificationDate: batchDocumentInfo.modificationDate,
//													propertyMap: batchDocumentInfo.updatedPropertyMap ?? [:],
//													with: self.databaseManager)
//								self.documentBackingCache.add(documentBacking)
//
//								// Check if we have creation proc
//								if let documentCreateProc = self.documentCreateProcMap.value(for: documentType) {
//									// Create document
//									let	document = documentCreateProc(documentID, self)
//
//									// Update collections and indexes
//									updateBatchQueue.add(
//											MDSUpdateInfo<Int64>(document: document,
//													revision: documentBacking.revision, value: documentBacking.id,
//													changedProperties: nil))
//
//									// Call document changed procs
//									self.documentChangedProcsMap.values(for: documentType)?.forEach()
//										{ $0(document, .created) }
//								}
//							}
//						} else if let documentBacking = batchDocumentInfo.documentBacking {
//							// Remove document
//							self.databaseManager.remove(documentType: documentType, id: documentBacking.id)
//							self.documentBackingCache.remove([documentID])
//
//							// Remove from collections and indexes
//							removedDocumentBackingIDs.append(documentBacking.id)
//
//							// Check if we have creation proc
//							if let documentCreateProc = self.documentCreateProcMap.value(for: documentType) {
//								// Create document
//								let	document = documentCreateProc(documentID, self)
//
//								// Call document changed procs
//								self.documentChangedProcsMap.values(for: documentType)?.forEach()
//									{ $0(document, .removed) }
//							}
//						}
//					}
//
//					// Finalize updates
//					updateBatchQueue.finalize()
//					self.removeFromCollections(for: documentType, documentBackingIDs: removedDocumentBackingIDs)
//					self.removeFromIndexes(for: documentType, documentBackingIDs: removedDocumentBackingIDs)
//				}
//			}
//		}
//
//		// Remove - must wait to do this until the batch has been fully processed in case processing Collections and
//		//	Indexes ends up referencing other documents that have not yet been committed.
//		self.batchInfoMap.set(nil, for: Thread.current)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerDocumentCreateProc<T : MDSDocument>(
			proc :@escaping (_ id :String, _ documentStorage :MDSDocumentStorage) -> T) {
		// Add
		self.documentCreateProcMap.set(proc, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerDocumentChangedProc<T : MDSDocument>(
			proc :@escaping (_ document :T, _ changeKind :MDSDocument.ChangeKind) -> Void) {
		//  Add
		self.documentChangedProcsMap.append({ proc($0 as! T, $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func ephemeralValue<T>(for key :String) -> T? { self.ephemeralValues?[key] as? T }

	//------------------------------------------------------------------------------------------------------------------
	public func store<T>(ephemeralValue value :T?, for key :String) {
		// Store
		if (self.ephemeralValues == nil) && (value != nil) {
			// First one
			self.ephemeralValues = [key : value!]
		} else {
			// Update
			self.ephemeralValues?[key] = value

			// Check for empty
			if self.ephemeralValues?.isEmpty ?? false {
				// No more values
				self.ephemeralValues = nil
			}
		}
	}

	// MARK: MDSHTTPServicesHandler methods
	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
// TODO: associationGetDocumentRevisionInfos(...)
		// Unimplemented
		fatalError("associationGetDocumentRevisionInfos")
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws
			-> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
// TODO: associationGetDocumentRevisionInfos(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?) throws
			-> (totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
// TODO: associationGetDocumentFullInfos(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
// TODO: associationGetDocumentFullInfos(...)
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentRevisionInfos(name :String, startIndex :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
		// Setup
		let	collection = self.collectionsByNameMap.value(for: name)!

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
		let	collection = self.collectionsByNameMap.value(for: name)!

		// Collect MDSDocument FullInfos
		var	documentFullInfos = [MDSDocument.FullInfo]()
		autoreleasepool() {
			collectionIterate(name: name, documentType: collection.documentType, startIndex: startIndex, count: count)
					{ documentFullInfos.append($0.documentFullInfo) }
		}

		return documentFullInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo] {
		// Validate
		guard self.databaseManager.documentIsKnown(documentType: documentType) else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Batch changes
		return self.databaseManager.batch() {
			// Setup
			let	map = Dictionary(documentUpdateInfos.map() { ($0.documentID, $0) })
			let	updateBatchQueue =
						BatchQueue<MDSUpdateInfo<Int64>>(
								maximumBatchSize: self.databaseManager.variableNumberLimit) {
//							// Update collections and indexes
//							self.updateCollections(for: documentType, updateInfos: $0)
//							self.updateIndexes(for: documentType, updateInfos: $0)
_ = $0
						}
			let	removedBatchQueue =
						BatchQueue<Int64>(maximumBatchSize: 999) {
//							// Update collections and indexes
//							self.removeFromCollections(for: documentType, documentBackingIDs: $0)
//							self.removeFromIndexes(for: documentType, documentBackingIDs: $0)
_ = $0
						}
			var	documentFullInfos = [MDSDocument.FullInfo]()

			// Iterate document IDs
			documentBackingsIterate(documentType: documentType, documentIDs: Array(map.keys)) {
				// Set update info
				let	documentUpdateInfo = map[$0.documentID]!

				// Check active
				if documentUpdateInfo.active {
					// Update document
					$0.update(documentType: documentType,
							updatedPropertyMap: documentUpdateInfo.updated,
							removedProperties: Set(documentUpdateInfo.removed), with: self.databaseManager)

					// Check if we have creation proc
					if let documentCreateProc = self.documentCreateProcMap.value(for: documentType) {
						// Create document
						let	document = documentCreateProc($0.documentID, self)

						// Update collections and indexes
						let	changedProperties =
									Set<String>(documentUpdateInfo.updated.keys).union(documentUpdateInfo.removed)
						updateBatchQueue.add(
								MDSUpdateInfo<Int64>(document: document, revision: $0.revision, value: $0.id,
										changedProperties: changedProperties))
					}
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
		guard let index = self.indexesByNameMap.value(for: name) else {
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
		guard let index = self.indexesByNameMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		// Compose MDSDocument FullInfo map
		var	documentFullInfoMap = [String : MDSDocument.FullInfo]()
		autoreleasepool() {
			// Iterate index
			self.indexIterate(name: name, documentType: index.documentType, keys: keys,
					proc: { documentFullInfoMap[$0] = $1.documentFullInfo })
		}

		return documentFullInfoMap
	}

	// MARK: Instance methods
//	//------------------------------------------------------------------------------------------------------------------
//	@discardableResult
//	func documentBackingMap(for documentInfos :[DocumentInfo]) -> [String : MDSSQLiteDocumentBacking] {
//		// Setup
//		var	documentBackingMap = [String : MDSSQLiteDocumentBacking]()
//
//		// Perform as batch and iterate all
//		self.databaseManager.batch() {
//			// Create document backings
//			var	documentTypeMap = [/* Document type */ String : [MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>]]()
//			documentInfos.forEach() {
//				// Create document backing
//				let	documentBacking =
//							MDSSQLiteDocumentBacking(documentType: $0.documentType, documentID: $0.documentID,
//									creationDate: $0.creationDate, modificationDate: $0.modificationDate,
//									propertyMap: $0.propertyMap, with: self.databaseManager)
//
//				// Add to maps
//				documentBackingMap[$0.documentID] = documentBacking
//				documentTypeMap.appendArrayValueElement(key: $0.documentType,
//						value:
//								MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(documentID: $0.documentID,
//										documentBacking: documentBacking))
//			}
//
//			// Iterate document types
//			documentTypeMap.forEach() {
//				// Add to cache
//				self.documentBackingCache.add($0.value)
//
//				// Check if have creation proc
//				if let documentCreateProc = self.documentCreateProcMap.value(for: $0.key) {
//					// Update collections and indexes
//					let	updateInfos :[MDSUpdateInfo<Int64>] =
//								$0.value.map() {
//									MDSUpdateInfo<Int64>(document: documentCreateProc($0.documentID, self),
//											revision: $0.documentBacking.revision, value: $0.documentBacking.id,
//											changedProperties: nil)
//								}
//					updateCollections(for: $0.key, updateInfos: updateInfos, processNotIncluded: false)
//					updateIndexes(for: $0.key, updateInfos: updateInfos)
//				}
//			}
//		}
//
//		return documentBackingMap
//return [:]
//	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func collectionIterate(name :String, documentType :String, startIndex :Int, count :Int?,
			proc :(_ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Collect MDSDocument RevisionInfos
		var	documentInfos = [MDSSQLiteDatabaseManager.DocumentInfo]()
		autoreleasepool() {
			// Iterate collection
			self.databaseManager.collectionIterateDocumentInfos(for: name, documentType: documentType,
					startIndex: startIndex, count: count, proc: { documentInfos.append($0) })
		}

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, infos: documentInfos.map({ ($0, "") }),
				proc: { proc($0); _ = $1 })
	}

	//------------------------------------------------------------------------------------------------------------------
	private func collectionUpdate(_ collection :MDSCollection, updateInfos :[MDSUpdateInfo<Int64>]) {
		// Update
		if let (includedIDs, notIncludedIDs, lastRevision) = collection.update(updateInfos) {
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

//	//------------------------------------------------------------------------------------------------------------------
//	private func documentBackingsIterate(documentType :String, innerJoin :SQLiteInnerJoin? = nil,
//			where sqliteWhere :SQLiteWhere? = nil,
//			proc :(_ documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
//		// Iterate
//		self.databaseManager.documentInfoIterate(documentType: documentType, innerJoin: innerJoin, where: sqliteWhere) {
//			// Try to retrieve document backing
//			let	documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>
//			if let documentBacking =
//					self.documentBackingCache.documentBacking(for: $0.documentRevisionInfo.documentID) {
//				// Have document backing
//				documentBackingInfo =
//						MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(
//								documentID: $0.documentRevisionInfo.documentID, documentBacking: documentBacking)
//			} else {
//				// Read
//				documentBackingInfo = MDSSQLiteDatabaseManager.documentBackingInfo(for: $0, resultsRow: $1)
//			}
//
//			// Note referenced
//			self.documentBackingCache.add([documentBackingInfo])
//
//			// Call proc
//			proc(documentBackingInfo)
//		}
//	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate(documentType :String, documentIDs :[String],
			proc :(_ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Collect MDSDocument RevisionInfos
		var	documentInfos = [MDSSQLiteDatabaseManager.DocumentInfo]()
		self.databaseManager.documentInfoIterate(documentType: documentType, documentIDs: documentIDs,
				proc: { documentInfos.append($0) })

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, infos: documentInfos.map({ ($0, "") }))
				{ proc($0); _ = $1 }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate(documentType :String, sinceRevision :Int, activeOnly: Bool,
			proc :(_ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Collect MDSDocument RevisionInfos
		var	documentInfos = [MDSSQLiteDatabaseManager.DocumentInfo]()
		self.databaseManager.documentInfoIterate(documentType: documentType, sinceRevision: sinceRevision,
				activeOnly: activeOnly, proc: { documentInfos.append($0) })

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, infos: documentInfos.map({ ($0, "") }))
				{ proc($0); _ = $1 }
	}

	//------------------------------------------------------------------------------------------------------------------
//	private func updateCollections(for documentType :String, updateInfos :[MDSUpdateInfo<Int64>],
//			processNotIncluded :Bool = true) {
//		// Get collections
//		guard let collections = self.collectionsByDocumentTypeMap.values(for: documentType) else { return }
//
//		// Setup
//		let	minRevision = updateInfos.min(by: { $0.revision < $1.revision })?.revision
//
//		// Iterate collections
//		collections.forEach() {
//			// Check revision state
//			if $0.lastRevision + 1 == minRevision {
//				// Update collection
//				if let (includedIDs, notIncludedIDs, lastRevision) = $0.update(updateInfos) {
//					// Update database
//					self.databaseManager.updateCollection(name: $0.name, includedIDs: includedIDs,
//							notIncludedIDs: processNotIncluded ? notIncludedIDs : [], lastRevision: lastRevision)
//				}
//			} else {
//				// Bring up to date
//				bringUpToDate($0)
//			}
//		}
//	}

	//------------------------------------------------------------------------------------------------------------------
//	private func bringCollectionUpToDate(name :String) -> MDSCollection {
//		// Setup
//		let	collection = self.collectionsByNameMap.value(for: name)!
//
//		// Bring up to date
//		bringUpToDate(collection)
//
//		return collection
//	}

	//------------------------------------------------------------------------------------------------------------------
//	private func bringUpToDate(_ collection :MDSCollection) {
//		// Setup
//		let	documentCreateProc = self.documentCreateProcMap.value(for: collection.documentType)!
//		let	batchInfo = self.batchInfoMap.value(for: Thread.current)
//
//		// Collect infos
//		var	updateInfos = [MDSUpdateInfo<Int64>]()
//		iterateDocumentBackingInfos(documentType: collection.documentType, sinceRevision: collection.lastRevision,
//				activeOnly: true) {
//					// Query batch info
//					let batchDocumentInfo = batchInfo?.documentGetInfo(for: $0.documentID)
//
//					// Ensure we want to process this document
//					if (batchDocumentInfo == nil) || !batchDocumentInfo!.removed {
//						// Append info
//						updateInfos.append(
//								MDSUpdateInfo<Int64>(document: documentCreateProc($0.documentID, self),
//										revision: $0.documentBacking.revision, value: $0.documentBacking.id))
//					}
//				}
//
//		// Update
//		if let (includedIDs, notIncludedIDs, lastRevision) = collection.update(updateInfos) {
//			// Update database
//			self.databaseManager.updateCollection(name: collection.name, includedIDs: includedIDs,
//					notIncludedIDs: notIncludedIDs, lastRevision: lastRevision)
//		}
//	}

	//------------------------------------------------------------------------------------------------------------------
//	private func removeFromCollections(for documentType :String, documentBackingIDs :[Int64]) {
//		// Iterate all collections for this document type
//		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach() {
//			// Update collection
//			self.databaseManager.updateCollection(name: $0.name, includedIDs: [], notIncludedIDs: documentBackingIDs,
//					lastRevision: $0.lastRevision)
//		}
//	}

	//------------------------------------------------------------------------------------------------------------------
	private func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ documentBacking :MDSSQLiteDocumentBacking) -> Void) {
		// Compose MDSDocument RevisionInfo map
		var	documentInfosByKey = [String : MDSSQLiteDatabaseManager.DocumentInfo]()
		autoreleasepool() {
			// Iterate index
			self.databaseManager.indexIterateDocumentInfos(name: name, documentType: documentType, keys: keys,
					proc: { documentInfosByKey[$0] = $1 })
		}

		// Iterate document backings
		documentBackingsIterate(documentType: documentType, infos: documentInfosByKey.map({ ($0.value, $0.key) }))
				{ proc($1, $0) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentBackingsIterate<T>(documentType :String,
			infos :[(documentInfo :MDSSQLiteDatabaseManager.DocumentInfo, t :T)],
			proc :(_ documentBacking :MDSSQLiteDocumentBacking, _ t : T) -> Void) {
		// Iterate infos
		var	infosNotFound = [(documentInfo :MDSSQLiteDatabaseManager.DocumentInfo, t :T)]()
		infos.forEach() {
			// Check cache
			if let documentBacking = self.documentBackingCache.documentBacking(for: $0.documentInfo.documentID) {
				// Have in cache
				proc(documentBacking, $0.t)
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
let	attachmentInfoMap = MDSDocument.AttachmentInfoMap()
//TODO

			// Create MDSSQLiteDocumentBacking
			let	documentBacking =
						MDSSQLiteDocumentBacking(id: $0.documentInfo.id, documentID: $0.documentInfo.documentID,
								revision: $0.documentInfo.revision, active: $0.documentInfo.active,
								creationDate: documentContentInfo.creationDate,
								modificationDate: documentContentInfo.modificationDate,
								propertyMap: documentContentInfo.propertyMap, attachmentInfoMap: attachmentInfoMap)
			self.documentBackingCache.add([documentBacking])

			// Call proc
			proc(documentBacking, $0.t)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func indexUpdate(_ index :MDSIndex, updateInfos :[MDSUpdateInfo<Int64>]) {
		// Update
		if let (keysInfos, lastRevision) = index.update(updateInfos) {
			// Update database
			self.databaseManager.indexUpdate(name: index.name, keysInfos: keysInfos, removedIDs: [],
					lastRevision: lastRevision)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
//	private func indexIterate(name :String, keys :[String],
//			with proc
//					:(_ key :String,
//							_ documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Void) {
//		// Bring up to date
//		let	index = autoreleasepool() { bringIndexUpToDate(name: name) }
//
//		// Iterate
//		iterateDocumentBackingInfos(documentType: index.documentType,
//				innerJoin: self.databaseManager.innerJoin(for: index.documentType, indexName: name),
//				where: self.databaseManager.where(forIndexKeys: keys))
//				{ proc(MDSSQLiteDatabaseManager.indexContentsKey(for: $1), $0) }
//	}

	//------------------------------------------------------------------------------------------------------------------
//	private func updateIndexes(for documentType :String, updateInfos :[MDSUpdateInfo<Int64>]) {
//		// Get indexes
//		guard let indexes = self.indexesByDocumentTypeMap.values(for: documentType) else { return }
//
//		// Setup
//		let	minRevision = updateInfos.min(by: { $0.revision < $1.revision })?.revision
//
//		// Iterate indexes
//		indexes.forEach() {
//			// Check revision state
//			if $0.lastRevision + 1 == minRevision {
//				// Update index
//				if let (keysInfos, lastRevision) = $0.update(updateInfos) {
//					// Update database
//					self.databaseManager.updateIndex(name: $0.name, keysInfos: keysInfos, removedIDs: [],
//							lastRevision: lastRevision)
//				}
//			} else {
//				// Bring up to date
//				bringUpToDate($0)
//			}
//		}
//	}

	//------------------------------------------------------------------------------------------------------------------
//	private func bringIndexUpToDate(name :String) -> MDSIndex {
//		// Setup
//		let	index = self.indexesByNameMap.value(for: name)!
//
//		// Bring up to date
//		bringUpToDate(index)
//
//		return index
//	}

	//------------------------------------------------------------------------------------------------------------------
//	private func bringUpToDate<I : MDSIndex>(_ index :I) {
//		// Setp
//		let	documentCreateProc = self.documentCreateProcMap.value(for: index.documentType)!
//		let	batchInfo = self.batchInfoMap.value(for: Thread.current)
//
//		// Collect infos
//		var	updateInfos = [MDSUpdateInfo<Int64>]()
//		iterateDocumentBackingInfos(documentType: index.documentType, sinceRevision: index.lastRevision,
//				activeOnly: true) {
//					// Query batch info
//					let batchDocumentInfo = batchInfo?.documentGetInfo(for: $0.documentID)
//
//					// Ensure we want to process this document
//					if (batchDocumentInfo == nil) || !batchDocumentInfo!.removed {
//						// Append info
//						updateInfos.append(
//								MDSUpdateInfo<Int64>(document: documentCreateProc($0.documentID, self),
//										revision: $0.documentBacking.revision, value: $0.documentBacking.id))
//					}
//				}
//
//		// Update
//		if let (keysInfos, lastRevision) = index.update(updateInfos) {
//			// Update database
//			self.databaseManager.updateIndex(name: index.name, keysInfos: keysInfos, removedIDs: [],
//					lastRevision: lastRevision)
//		}
//	}

	//------------------------------------------------------------------------------------------------------------------
//	private func removeFromIndexes(for documentType :String, documentBackingIDs :[Int64]) {
//		// Iterate all indexes for this document type
//		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach() {
//			// Update index
//			self.databaseManager.updateIndex(name: $0.name, keysInfos: [], removedIDs: documentBackingIDs,
//					lastRevision: $0.lastRevision)
//		}
//	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateInfos(for documentType :String, sinceRevision: Int) -> [MDSUpdateInfo<Int64>] {
		// Setup
		let	documentCreateProc =
				self.documentCreateProcMap.value(for: documentType) ?? { MDSDocument(id: $0, documentStorage: $1) }
		let	batchInfo = self.batchInfoMap.value(for: Thread.current)

		// Collect update infos
		var	updateInfos = [MDSUpdateInfo<Int64>]()
		documentBackingsIterate(documentType: documentType, sinceRevision: sinceRevision, activeOnly: false) {
			// Query batch info
			let batchDocumentInfo = batchInfo?.documentGetInfo(for: $0.documentID)

			// Ensure we want to process this document
			if (batchDocumentInfo == nil) || !batchDocumentInfo!.removed {
				// Append info
				updateInfos.append(
						MDSUpdateInfo<Int64>(document: documentCreateProc($0.documentID, self),
								revision: $0.revision, value: $0.id))
			}
		}

		return updateInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	private func update(for documentType :String, updateInfos :[MDSUpdateInfo<Int64>]) {
		// Update caches
//		self.cachesByDocumentTypeMap.values(for: documentType)?.forEach()
//				{ self.cacheUpdate($0, updateInfos: updateInfos) }

		// Update collections
		self.collectionsByDocumentTypeMap.values(for: documentType)?.forEach()
				{ self.collectionUpdate($0, updateInfos: updateInfos) }

		// Update indexes
		self.indexesByDocumentTypeMap.values(for: documentType)?.forEach()
			{ self.indexUpdate($0, updateInfos: updateInfos) }
	}

//	//------------------------------------------------------------------------------------------------------------------
//	private func note(removedDocumentIDs documentIDs :Set<Int64>) {
//		// Iterate all caches
//		self.cacheValuesMap.keys.forEach()
//			{ self.cacheValuesMap.update(for: $0, with: { $0?.filter({ !documentIDs.contains($0.key) }) }) }
//
//		// Iterate all collections
//		self.collectionValuesMap.keys.forEach()
//			{ self.collectionValuesMap.update(for: $0, with: { $0?.filter({ !documentIDs.contains($0) }) }) }
//
//		// Iterate all indexes
//		self.indexValuesMap.keys.forEach() {
//			// Remove document from this index
//			self.indexValuesMap.update(for: $0) { $0?.filter({ !documentIDs.contains($0.value) }) }
//		}
//	}
}
