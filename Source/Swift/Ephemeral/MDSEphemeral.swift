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
public class MDSEphemeral : MDSHTTPServicesHandler {

	// MARK: Types
	typealias MDSEphemeralBatchInfo = MDSBatchInfo<[String : Any]>

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
	public	let	id :String = UUID().uuidString

	private	var	associationsByNameMap = LockingDictionary</* Name */ String, MDSAssociation>()
	private	var	associationItemsByNameMap = LockingArrayDictionary</* Name */ String, MDSAssociation.Item>()

	private	let	batchInfoMap = LockingDictionary<Thread, MDSEphemeralBatchInfo>()

	private	let	cachesByNameMap = LockingDictionary</* Name */ String, MDSCache>()
	private	let	cachesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCache>()
	private	let	cacheValuesMap =
						LockingDictionary</* Cache Name */ String,
								[/* Document ID */ String : [/* Value Name */ String : /* Value */ MDSValue.Value?]]>()

	private	let	collectionsByNameMap = LockingDictionary</* Name */ String, MDSCollection>()
	private	let	collectionsByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSCollection>()
	private	let	collectionValuesMap = LockingDictionary</* Name */ String, /* Document IDs */ [String]>()

	private	var	documentBackingByIDMap = [/* Document ID */ String : DocumentBacking]()
	private	let	documentCreateProcMap = LockingDictionary<String, MDSDocument.CreateProc>()
	private	let	documentChangedProcsMap = LockingArrayDictionary</* Document Type */ String, MDSDocument.ChangedProc>()
	private	var	documentIDsByTypeMap = [/* Document Type */ String : /* Document IDs */ Set<String>]()
	private	let	documentLastRevisionMap = LockingDictionary</* Document type */ String, Int>()
	private	let	documentMapsLock = ReadPreferringReadWriteLock()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, [String : Any]>()

	private	var	ephemeralValues :[/* Key */ String : Any]?

	private	let	indexesByNameMap = LockingDictionary</* Name */ String, MDSIndex>()
	private	let	indexesByDocumentTypeMap = LockingArrayDictionary</* Document type */ String, MDSIndex>()
	private	let	indexValuesMap = LockingDictionary</* Name */ String, [/* Key */ String : /* Document ID */ String]>()

	private	var	info = [String : String]()
	private	var	`internal` = [String : String]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init() {}

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
	public func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			batchInfo.associationNoteUpdated(for: name, updates: updates)
		} else {
			// Not in batch
			self.associationItemsByNameMap.remove(updates.filter({ $0.action == .remove }).map({ $0.item }), for: name)
			self.associationItemsByNameMap.append(updates.filter({ $0.action == .add }).map({ $0.item }), for: name)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(for name :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, associationItems :[MDSAssociation.Item]) {
		// Setup
		let	associationItems = try associationItems(for: name)

		// Validate
		guard startIndex >= 0 else {
			throw MDSDocumentStorageError.invalidStartIndex(startIndex: startIndex)
		}
		guard (count == nil) || (count! > 0) else {
			throw MDSDocumentStorageError.invalidCount(count: count!)
		}

		return (associationItems.count,
				(count != nil) ?
						Array(associationItems[startIndex...(startIndex + count!)]) :
						Array(associationItems[startIndex...]))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Setup
		let	associationItems = try associationItems(for: name)

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

		// Iterate values
		let	documentCreateProc =
				self.documentCreateProcMap.value(for: toDocumentType) ?? { MDSDocument(id: $0, documentStorage: $1) }
		associationItems
				.filter({ $0.fromDocumentID == fromDocumentID })
				.forEach() { proc(documentCreateProc($0.toDocumentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, to toDocumentID :String, fromDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Setup
		let	associationItems = try associationItems(for: name)

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

		// Iterate values
		let	documentCreateProc =
				self.documentCreateProcMap.value(for: fromDocumentType) ?? { MDSDocument(id: $0, documentStorage: $1) }
		associationItems
				.filter({ $0.toDocumentID == toDocumentID })
				.forEach() { proc(documentCreateProc($0.fromDocumentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetIntegerValue(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentID :String, cacheName :String, cachedValueName :String) throws -> Int {
		// Setup
		let	associationItems = try associationItems(for: name)

		// Validate
		guard self.associationsByNameMap.value(for: name) != nil else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}
		guard self.documentMapsLock.read({ self.documentBackingByIDMap[fromDocumentID] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentID(documentID: fromDocumentID)
		}
		guard let cache = self.cachesByNameMap.value(for: cacheName) else {
			throw MDSDocumentStorageError.unknownCache(name: cacheName)
		}
		guard cache.valueInfo(for: cachedValueName) != nil else {
			throw MDSDocumentStorageError.unknownCacheValueName(valueName: cachedValueName)
		}

		// Iterate values
		let	cacheValueInfos = self.cacheValuesMap.value(for: cacheName)!
		var	sum = 0
		associationItems
				.filter({ $0.fromDocumentID == fromDocumentID })
				.forEach() {
					// Get value and sum
					let	valueInfos = cacheValueInfos[$0.toDocumentID]!
					switch valueInfos[cachedValueName]!! {
						case .integer(let value):	sum += value
					}
				}

		return sum
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(named name :String, documentType :String, relevantProperties :[String],
			valueInfos :[(name :String, valueType :MDSValue.Type_, selector :String, proc :MDSDocument.ValueProc)])
			throws {
		// Validate
		guard self.documentIDsByTypeMap[documentType] != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Remove current cache if found
		if let cache = self.cachesByNameMap.value(for: name) {
			// Remove
			self.cachesByDocumentTypeMap.remove(cache, for: documentType)
		}

		// Create or re-create cache
		let	cache =
					MDSCache(name: name, documentType: documentType, lastRevision: 0,
							valueInfos: valueInfos.map({ (MDSValueInfo(name: $0, type: $1), $3) }))

		// Add to maps
		self.cachesByNameMap.set(cache, for: name)
		self.cachesByDocumentTypeMap.append(cache, for: documentType)

		// Bring up to date
		cacheUpdate(cache, updateInfos: self.updateInfos(for: documentType, sinceRevision: 0))
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String, isIncludedProcVersion :Int,
			isIncludedProc :@escaping MDSDocument.IsIncludedProc) throws {
		// Validate
		guard self.documentIDsByTypeMap[documentType] != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Remove current collection if found
		if let collection = self.collectionsByNameMap.value(for: name) {
			// Remove
			self.collectionsByDocumentTypeMap.remove(collection, for: documentType)
		}

		// Create or re-create collection
		let	collection =
					MDSCollection(name: name, documentType: documentType, relevantProperties: relevantProperties,
							lastRevision: isUpToDate ? (self.documentLastRevisionMap.value(for: documentType) ?? 0) : 0,
							isIncludedProc: isIncludedProc, isIncludedInfo: isIncludedInfo)

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

		// Return count
		return self.collectionValuesMap.value(for: name)!.count
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard let documentIDs = self.collectionValuesMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownCollection(name: name)
		}

		// Setup
		let	documentCreateProc =
				self.documentCreateProcMap.value(for: documentType) ?? { MDSDocument(id: $0, documentStorage: $1) }

		// Iterate
		documentIDs.forEach() { proc(documentCreateProc($0, self)) }
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
						MDSUpdateInfo<String>(document: document, revision: documentBacking.revision, value: documentID,
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

		return documentIDs.count
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, documentIDs :[String],
			documentCreateProc :MDSDocument.CreateProc?,
			proc :(_ document :MDSDocument?, _ documentFullInfo :MDSDocument.FullInfo) -> Void) throws {
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
		documentBackings.forEach() { proc(documentCreateProc?($0.documentID, self), $0.documentFullInfo) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, sinceRevision :Int, count :Int?, activeOnly: Bool,
			documentCreateProc :MDSDocument.CreateProc?,
			proc :(_ document :MDSDocument?, _ documentFullInfo :MDSDocument.FullInfo) -> Void) throws {
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
			documentBackings.sorted(by: { $0.revision < $1.revision })[..<count!]
					.forEach({ proc(documentCreateProc?($0.documentID, self), $0.documentFullInfo) })
		} else {
			// Don't have count
			documentBackings
					.forEach({ proc(documentCreateProc?($0.documentID, self), $0.documentFullInfo) })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
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
									value: document.id, changedProperties: [property])])

			// Call document changed procs
			self.documentChangedProcsMap.values(for: T.documentType)?.forEach() { $0(document, .updated) }
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
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
			Data? {
		// Validate
		guard self.documentMapsLock.read({ self.documentIDsByTypeMap[documentType] }) != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
			// Have document in batch
			if let content = batchInfoDocumentInfo.attachmentContent(for: attachmentID) {
				// Found
				return content
			} else {
				// Not found
				throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
			}
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: documentID) != nil {
			// Creating
			throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
		} else if let attachmentMap =
				self.documentMapsLock.read({ self.documentBackingByIDMap[documentID]?.attachmentMap }) {
			// Not in batch and not creating
			if let content = attachmentMap[attachmentID]?.content {
				// Have attachment
				return content
			} else {
				// Don't have attachment
				throw MDSDocumentStorageError.unknownAttachmentID(attachmentID: attachmentID)
			}
		} else {
			// Unknown documentID
			throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
		}
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
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
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
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
	public func documentRemove(_ document :MDSDocument) {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
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
			self.documentChangedProcsMap.values(for: documentType)?.forEach() { $0(document, .removed) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			keysInfo :[String : Any], keysSelector :String, keysProcVersion :Int,
			keysProc :@escaping MDSDocument.KeysProc) throws {
		// Validate
		guard self.documentIDsByTypeMap[documentType] != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Remove current index if found
		if let index = self.indexesByNameMap.value(for: name) {
			// Remove
			self.indexesByDocumentTypeMap.remove(index, for: documentType)
		}

		// Create or re-create index
		let	index =
					MDSIndex(name: name, documentType: documentType, relevantProperties: relevantProperties,
							lastRevision: isUpToDate ? (self.documentLastRevisionMap.value(for: documentType) ?? 0) : 0,
							keysProc: keysProc, keysInfo: keysInfo)

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
		guard let items = self.indexValuesMap.value(for: name) else {
			throw MDSDocumentStorageError.unknownIndex(name: name)
		}

		// Setup
		let	documentCreateProc =
				self.documentCreateProcMap.value(for: documentType) ?? { MDSDocument(id: $0, documentStorage: $1) }

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
	public func info(for keys :[String]) -> [String : String] { self.info.filter({ keys.contains($0.key) }) }

	//------------------------------------------------------------------------------------------------------------------
	public func infoSet(_ info :[String : String]) { self.info.merge(info, uniquingKeysWith: { $1 }) }

	//------------------------------------------------------------------------------------------------------------------
	public func remove(keys :[String]) { keys.forEach() { self.info[$0] = nil } }

	//------------------------------------------------------------------------------------------------------------------
	public func internalGet(for keys :[String]) -> [String : String] {
		// Return info
		return self.internal.filter({ keys.contains($0.key) })
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalSet(_ info :[String : String]) { self.internal.merge(info, uniquingKeysWith: { $1 }) }

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Setup
		let	batchInfo = MDSEphemeralBatchInfo()

		// Store
		self.batchInfoMap.set(batchInfo, for: Thread.current)

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
				let	documentCreateProc = self.documentCreateProcMap.value(for: documentType)

				var	updateInfos = [MDSUpdateInfo<String>]()
				var	removedDocumentIDs = Set<String>()

				let	process
							:(_ documentID :String,
									_ batchInfoDocumentInfo :MDSEphemeralBatchInfo.DocumentInfo<[String : Any]>,
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

								// Check if have create proc
								if documentCreateProc != nil {
									// Create document
									let	document = documentCreateProc!(documentID, self)

									// Note update info
									let	changedProperties =
												Set<String>((batchInfoDocumentInfo.updatedPropertyMap ?? [:]).keys)
														.union(batchInfoDocumentInfo.removedProperties ?? Set<String>())
									updateInfos.append(
											MDSUpdateInfo<String>(document: document,
													revision: documentBacking.revision, value: documentID,
													changedProperties: changedProperties))

									// Call document changed procs
									self.documentChangedProcsMap.values(for: documentType)?.forEach()
										{ $0(document, changeKind) }
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

							// Check if we have creation proc
							if let documentCreateProc = self.documentCreateProcMap.value(for: documentType) {
								// Create document
								let	document = documentCreateProc(documentID, self)

								// Call document changed procs
								self.documentChangedProcsMap.values(for: documentType)?.forEach()
									{ $0(document, .removed) }
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
		self.batchInfoMap.set(nil, for: Thread.current)
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
		// Setup
		let	associationItems = try associationItems(for: name)

		// Validate
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
		// Setup
		let	associationItems = try associationItems(for: name)

		// Validate
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
		// Setup
		let	associationItems = try associationItems(for: name)

		// Validate
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
		// Setup
		let	associationItems = try associationItems(for: name)

		// Validate
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
	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo] {
		// Validate
		guard self.documentIDsByTypeMap[documentType] != nil else {
			throw MDSDocumentStorageError.unknownDocumentType(documentType: documentType)
		}

		// Setup
		let	documentCreateProc = self.documentCreateProcMap.value(for: documentType)
		let	documentChangedProcs = self.documentChangedProcsMap.values(for: documentType)
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

					// Check if we have creation proc
					if documentCreateProc != nil {
						// Create document
						let	document = documentCreateProc!(documentID, self)

						// Note update infos
						updateInfos.append(
								MDSUpdateInfo<String>(document: document,
										revision: documentBacking.revision, value: documentID,
										changedProperties: Set<String>(updated.keys).union(removed)))

						// Call document changed procs
						documentChangedProcs?.forEach() { $0(document, .created) }
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
					if documentChangedProcs != nil, let document = documentCreateProc?(documentID, self) {
						// Call document changed procs
						documentChangedProcs?.forEach() { $0(document, .removed) }
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
	private func associationItems(for name :String) throws -> [MDSAssociation.Item] {
		// Setup
		guard var associationItems = self.associationItemsByNameMap.values(for: name) else {
			throw MDSDocumentStorageError.unknownAssociation(name: name)
		}

		// Process batch updates
		self.batchInfoMap.value(for: Thread.current)?.associationGetChanges(for: name)?.forEach() {
			// Process update
			if $0.action == .add {
				// Add
				associationItems.append($0.item)
			} else {
				// Remove
				associationItems.remove($0.item)
			}
		}

		return associationItems
	}

	//------------------------------------------------------------------------------------------------------------------
	private func cacheUpdate(_ cache :MDSCache, updateInfos :[MDSUpdateInfo<String>]) {
		// Get infos
		let	infos = cache.update(updateInfos)

		// Update
		self.cacheValuesMap.update(for: cache.name, with: { ($0 ?? [:]).merging(infos, uniquingKeysWith: { $1 }) })
	}

	//------------------------------------------------------------------------------------------------------------------
	private func collectionUpdate(_ collection :MDSCollection, updateInfos :[MDSUpdateInfo<String>]) {
		// Update
		if let (includedIDs, notIncludedIDs, _) = collection.update(updateInfos) {
			// Update storage
			self.collectionValuesMap.update(for: collection.name) {
				// Compose updated values
				let	updatedValues = ($0 ?? []).filter({ !notIncludedIDs.contains($0) }) + Array(includedIDs)

				return !updatedValues.isEmpty ? updatedValues : nil
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func indexUpdate(_ index :MDSIndex, updateInfos :[MDSUpdateInfo<String>]) {
		// Update
		if let (keysInfos, _) = index.update(updateInfos) {
			// Update storage
			let	documentIDs = Set<String>(keysInfos.map({ $0.value }))
			self.indexValuesMap.update(for: index.name) {
				// Filter out document IDs included in update
				var	updatedValueInfo = ($0 ?? [:]).filter({ !documentIDs.contains($0.value) })

				// Add/Update keys => document IDs
				keysInfos.forEach() { keys, value in keys.forEach() { updatedValueInfo[$0] = value } }

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
		let	documentCreateProc =
				self.documentCreateProcMap.value(for: documentType) ?? { MDSDocument(id: $0, documentStorage: $1) }
		var	updateInfos = [MDSUpdateInfo<String>]()
		try! documentIterate(for: documentType, sinceRevision: 0, count: nil, activeOnly: false,
				documentCreateProc: documentCreateProc, proc: {
					// Append MDSUpdateInfo
					updateInfos.append(
							MDSUpdateInfo<String>(document: $0!, revision: $1.revision, value: $1.documentID))
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
		self.indexValuesMap.keys.forEach() {
			// Remove document from this index
			self.indexValuesMap.update(for: $0) { $0?.filter({ !documentIDs.contains($0.value) }) }
		}
	}
}
