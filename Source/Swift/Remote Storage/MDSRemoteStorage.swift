//
//  MDSRemoteStorage.swift
//  Mini Document Storage
//
//  Created by Stevo on 1/14/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSRemoteStorageError
public enum MDSRemoteStorageError : Error {
	case serverResponseMissingExpectedInfo(serverResponseInfo :[String : Any], expectedKey :String)
}

extension MDSRemoteStorageError : CustomStringConvertible, LocalizedError {

	// MARK: Properties
	public 	var	description :String { self.localizedDescription }
	public	var	errorDescription :String? {
						switch self {
							case .serverResponseMissingExpectedInfo(let serverResponseInfo, let expectedKey):
								return "MDSRemoteStorage server response (\(serverResponseInfo)) is missing expected key \(expectedKey)"
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSRemoteStorage
open class MDSRemoteStorage : MDSDocumentStorageCore, MDSDocumentStorage {

	// MARK: Types
	class DocumentBacking : MDSDocumentBacking {

		// MARK: Properties
		let	type :String
		let	documentID :String
		let	active :Bool
		let	creationDate :Date

		var	modificationDate :Date
		var	revision :Int
		var	propertyMap :[String : Any]
		var	attachmentInfoMap :MDSDocument.AttachmentInfoMap

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(type :String, documentID :String, revision :Int, active :Bool, creationDate :Date, modificationDate :Date,
				propertyMap :[String : Any], attachmentInfoMap :MDSDocument.AttachmentInfoMap) {
			// Store
			self.type = type
			self.documentID = documentID
			self.active = active
			self.creationDate = creationDate

			self.modificationDate = modificationDate
			self.revision = revision
			self.propertyMap = propertyMap
			self.attachmentInfoMap = attachmentInfoMap
		}

		//--------------------------------------------------------------------------------------------------------------
		init(type :String, documentFullInfo :MDSDocument.FullInfo) {
			// Store
			self.type = type
			self.documentID = documentFullInfo.documentID
			self.active = documentFullInfo.active
			self.creationDate = documentFullInfo.creationDate

			self.modificationDate = documentFullInfo.modificationDate
			self.revision = documentFullInfo.revision
			self.propertyMap = documentFullInfo.propertyMap
			self.attachmentInfoMap = documentFullInfo.attachmentInfoMap
		}
	}

	struct DocumentUpdateInfo {

		// MARK: Properties
		let	documentUpdateInfo :MDSDocument.UpdateInfo
		let	documentBacking :DocumentBacking

		// MARK: Lifecycle methods
		init(_ documentUpdateInfo :MDSDocument.UpdateInfo, _ documentBacking :DocumentBacking) {
			// Store
			self.documentUpdateInfo = documentUpdateInfo
			self.documentBacking = documentBacking
		}
	}

	private	typealias Batch = MDSBatch<DocumentBacking>

	// MARK: Properties
	public	let	documentStorageID :String

	public	var	authorization :String?

	private	let	httpEndpointClient :HTTPEndpointClient
	private	let	remoteStorageCache :MDSRemoteStorageCache
	private	let	batchMap = LockingDictionary<Thread, Batch>()
	private	let	documentBackingCache = MDSDocumentBackingCache<DocumentBacking>()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, [String : Any]>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(httpEndpointClient :HTTPEndpointClient, authorization :String? = nil,
			documentStorageID :String = "default", remoteStorageCache :MDSRemoteStorageCache) {
		// Store
		self.documentStorageID = documentStorageID

		self.httpEndpointClient = httpEndpointClient
		self.authorization = authorization
		self.remoteStorageCache = remoteStorageCache
	}

	// MARK: MDSDocumentStorage implementation
	//------------------------------------------------------------------------------------------------------------------
	public func associationRegister(named name :String, fromDocumentType :String, toDocumentType :String) throws {
		// Register association
		let	error =
					self.httpEndpointClient.associationRegister(documentStorageID: self.documentStorageID, name: name,
							fromDocumentType: fromDocumentType, toDocumentType: toDocumentType,
							authorization: self.authorization)
		guard error == nil else { throw error! }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(for name :String) throws -> [MDSAssociation.Item] {
		// Get from client
		var	associationItems = [MDSAssociation.Item]()
		var	startIndex = 0
		while true {
			// Get associations
			let	(info, error) =
						self.httpEndpointClient.associationGet(documentStorageID: self.documentStorageID, name: name,
								startIndex: startIndex, count: 10000, authorization: self.authorization)
			guard error == nil else { throw error! }

			// Update
			associationItems +=
					info!.associationItems.map(
							{ MDSAssociation.Item(fromDocumentID: $0.fromDocumentID, toDocumentID: $0.toDocumentID) })
			startIndex += info!.associationItems.count

			// Check if done
			if info!.isComplete {
				// Done
				break
			}
		}

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
		// Setup
		let	documentCreateProc = documentCreateProc(for: toDocumentType)

		// Get document revision infos
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(info, error) =
						self.httpEndpointClient.associationGetDocumentRevisionInfos(
								documentStorageID: self.documentStorageID, name: name, fromDocumentID: fromDocumentID,
								startIndex: startIndex, authorization: self.authorization)

			// Handle results
			if info != nil {
				// Success
				documentRevisionInfos += info!.documentRevisionInfos
				startIndex += info!.documentRevisionInfos.count

				// Check if is complete
				if info!.isComplete {
					break
				}
			} else {
				// Error
				throw error!
			}
		}

		// Check for batch
		let	(associationAdds, associationRemoves) =
					self.batchMap.value(for: .current)?.associationUpdates(for: name) ?? ([], [])
		if !associationRemoves.isEmpty {
			// Remove document revision infos that have been removed
			let	associationRemoveDocumentIDs = Set(associationRemoves.map({ $0.toDocumentID }))

			// Filter document revision infos
			documentRevisionInfos =
						documentRevisionInfos.filter({ !associationRemoveDocumentIDs.contains($0.documentID) })
		}

		// Iterate document IDs and retrieve any needed documents
		try documentIterateIDs(documentType: toDocumentType, documentRevisionInfos: documentRevisionInfos,
				activeOnly: false) { proc(documentCreateProc($0, self)) }

		// Iterate adds and just use latest local document backing
		associationAdds.forEach() { proc(documentCreateProc($0.toDocumentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, fromDocumentType :String, to toDocumentID :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Setup
		let	documentCreateProc = documentCreateProc(for: fromDocumentType)

		// Get document revision infos
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(info, error) =
						self.httpEndpointClient.associationGetDocumentRevisionInfos(
								documentStorageID: self.documentStorageID, name: name, toDocumentID: toDocumentID,
								startIndex: startIndex, authorization: self.authorization)

			// Handle results
			if info != nil {
				// Success
				documentRevisionInfos += info!.documentRevisionInfos
				startIndex += info!.documentRevisionInfos.count

				// Check if is complete
				if info!.isComplete {
					break
				}
			} else {
				// Error
				throw error!
			}
		}

		// Check for batch
		let	(associationAdds, associationRemoves) =
					self.batchMap.value(for: .current)?.associationUpdates(for: name) ?? ([], [])
		if !associationRemoves.isEmpty {
			// Remove document revision infos that have been removed
			let	associationRemoveDocumentIDs = Set(associationRemoves.map({ $0.fromDocumentID }))

			// Filter document revision infos
			documentRevisionInfos =
						documentRevisionInfos.filter({ !associationRemoveDocumentIDs.contains($0.documentID) })
		}

		// Iterate document IDs and retrieve any needed documents
		try documentIterateIDs(documentType: fromDocumentType, documentRevisionInfos: documentRevisionInfos,
				activeOnly: false) { proc(documentCreateProc($0, self)) }

		// Iterate adds and just use latest local document backing
		associationAdds.forEach() { proc(documentCreateProc($0.fromDocumentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetIntegerValues(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentIDs :[String], cacheName :String, cachedValueNames :[String]) throws -> [String : Int64] {
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

		// May need to try this more than once
		while true {
			// Query collection document count
			let	(info, error) =
						self.httpEndpointClient.associationGetIntegerValues(
								documentStorageID: self.documentStorageID, name: name, action: action,
										fromDocumentIDs: Array(fromDocumentIDsUse), cacheName: cacheName,
										cachedValueNames: cachedValueNames, authorization: self.authorization)

			// Handle results
			if info != nil {
				// Received info
				if !info!.isUpToDate {
					// Not up to date
					continue
				} else {
					// Success
					return info!.cachedValues ?? [:]
				}
			} else {
				// Error
				throw error!
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
		// Check if have updates
		guard !updates.isEmpty else { return }

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			batch.associationNoteUpdated(for: name, updates: updates)
		} else {
			// Not in batch
			let	errors =
						self.httpEndpointClient.associationUpdate(documentStorageID: self.documentStorageID, name: name,
								updates: updates, authorization: self.authorization)
			if !errors.isEmpty { throw errors.first! }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			cacheValueInfos :[(valueInfo :MDSValueInfo, selector :String)]) throws {
		// Register cache
		let	error =
					self.httpEndpointClient.cacheRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: documentType, relevantProperties: relevantProperties,
							valueInfos: cacheValueInfos, authorization: self.authorization)
		guard error == nil else {
			// Error
			throw error!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String,
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc) throws {
		// Register collection
		let	error =
					self.httpEndpointClient.collectionRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: documentType, relevantProperties: relevantProperties,
							isUpToDate: isUpToDate, isIncludedSelector: isIncludedSelector,
							isIncludedSelectorInfo: isIncludedInfo, authorization: self.authorization)
		guard error == nil else {
			// Error
			throw error!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionGetDocumentCount(for name :String) throws -> Int {
		// Validate
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// May need to try this more than once
		while true {
			// Query collection document count
			let	(info, error) =
						self.httpEndpointClient.collectionGetDocumentCount(
								documentStorageID: self.documentStorageID, name: name,authorization: self.authorization)

			// Handle results
			if let (isUpToDate, count) = info {
				// Success
				if !isUpToDate {
					// Not up to date
					continue
				} else {
					// Success
					return count!
				}
			} else {
				// Error
				throw error!
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws {
		// Validate
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Setup
		let	documentCreateProc = self.documentCreateProc(for: documentType)

		// May need to try this more than once
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(isUpToDate, info, error)  =
						self.httpEndpointClient.collectionGetDocumentRevisionInfos(
								documentStorageID: self.documentStorageID, name: name, startIndex: startIndex,
								authorization: self.authorization)

			// Handle results
			if !(isUpToDate ?? true) {
				// Not up to date
				continue
			} else if let (documentRevisionInfos, isComplete) = info {
				// Success
				try documentIterateIDs(documentType: documentType, documentRevisionInfos: documentRevisionInfos,
						activeOnly: false) { proc(documentCreateProc($0, self)) }

				// Update
				startIndex += documentRevisionInfos.count

				// Check if is complete
				if isComplete {
					// Complete
					return
				}
			} else {
				// Error
				throw error!
			}
		}
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
			// Not in batch
			var	updatedDocumentCreateInfos = [MDSDocument.CreateInfo]()

			// Iterate document create infos
			var	documentsByDocumentID = [String : MDSDocument]()
			documentCreateInfos.forEach() {
				// Setup
				let	documentID = $0.documentID ?? UUID().base64EncodedString

				// Will be creating document
				self.documentsBeingCreatedPropertyMapMap.set([:], for: documentID)

				// Create
				let	document = proc(documentID, self)

				// Remove property map
				let	propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID)!
				self.documentsBeingCreatedPropertyMapMap.remove([documentID])

				// Add document
				let	creationDate = $0.creationDate ?? date
				let	modificationDate = $0.modificationDate ?? date
				updatedDocumentCreateInfos.append(
						MDSDocument.CreateInfo(documentID: documentID, creationDate: creationDate,
								modificationDate: modificationDate, propertyMap: propertyMap))
				documentsByDocumentID[documentID] = document
			}

			// Create documents
			let	documentOverviewInfos =
						try documentCreate(documentType: documentType, documentCreateInfos: updatedDocumentCreateInfos)

			// Update infos
			infos = documentOverviewInfos.map({ (documentsByDocumentID[$0.documentID]!, $0) })
		}

		return infos
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentGetCount(for documentType :String) throws -> Int {
		// Validate
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Get document count
		let	(count, error) =
					self.httpEndpointClient.documentGetCount(documentStorageID: self.documentStorageID,
							documentType: documentType, authorization: self.authorization)
		guard error == nil else {
			// Error
			throw error!
		}

		return count!
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, documentIDs :[String],
			documentCreateProc :MDSDocument.CreateProc, proc :(_ document :MDSDocument) -> Void) throws {
		// Retrieve info
		let	(documentRevisionInfos, errors) =
					self.httpEndpointClient.documentGetDocumentRevisionInfos(documentStorageID: self.documentStorageID,
							documentType: documentType, documentIDs: documentIDs, authorization: self.authorization)
		if !errors.isEmpty {
			// Error
			throw errors.first!
		}

		// Iterate document IDs and retrieve any needed documents
		try documentIterateIDs(documentType: documentType, documentRevisionInfos: documentRevisionInfos!,
				activeOnly: false) { proc(documentCreateProc($0, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, activeOnly: Bool, documentCreateProc :MDSDocument.CreateProc,
			proc :(_ document :MDSDocument) -> Void) throws {
		// Iterate document revision infos
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		var	startRevision = 0
		while true {
			// Retrieve info
			let	(info, error) =
						self.httpEndpointClient.documentGetDocumentRevisionInfos(
								documentStorageID: self.documentStorageID, documentType: documentType,
								sinceRevision: startRevision, authorization: self.authorization)

			// Handle results
			if info != nil {
				// Success
				documentRevisionInfos += info!.documentRevisionInfos
				startRevision = info!.documentRevisionInfos.map({ $0.revision }).max()! + 1

				// Check if is complete
				if info!.isComplete {
					break
				}
			} else {
				// Error
				throw error!
			}
		}

		// Iterate document IDs and retrieve any needed documents
		try documentIterateIDs(documentType: documentType, documentRevisionInfos: documentRevisionInfos,
				activeOnly: activeOnly) { proc(documentCreateProc($0, self)) }
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
			// Not in batch
			return try! self.documentBacking(for: type(of: document).documentType, documentID: document.id).creationDate
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
			// Not in batch
			return try! self.documentBacking(for: type(of: document).documentType, documentID: document.id)
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
			// Creating
			return propertyMap[property]
		} else {
			// Retrieve document backing
			return try! self.documentBacking(for: type(of: document).documentType, documentID: document.id)
					.propertyMap[property]
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
		// Check for batch
		guard let batch = self.batchMap.value(for: .current) else {
			// Nope!
			fatalError("MDSRemoteStorage - action must be performed in a batch")
		}

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

		// Store update
		if let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
			// Have document in batch
			batchDocumentInfo.set(valueUse, for: property)
		} else {
			// Don't have document in batch
			let	documentBacking =
						try! self.documentBacking(for: type(of: document).documentType, documentID: document.id)
			batch.documentAdd(documentType: documentBacking.type, documentID: document.id,
							documentBacking: documentBacking, creationDate: documentBacking.creationDate,
							modificationDate: documentBacking.modificationDate,
							initialPropertyMap: documentBacking.propertyMap)
					.set(valueUse, for: property)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any],
			content :Data) throws -> MDSDocument.AttachmentInfo {
		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				return batchDocumentInfo.attachmentAdd(info: info, content: content)
			} else {
				// Don't have document in batch
				let	documentBacking = try self.documentBacking(for: documentType, documentID: documentID)

				return batch.documentAdd(documentType: documentBacking.type, documentID: documentID,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentAdd(info: info, content: content)
			}
		} else {
			// Not in batch
			return try documentAttachmentAdd(documentType: documentType, documentID: documentID, documentBacking: nil,
					info: info, content: content)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentInfoMap(for documentType :String, documentID :String) throws ->
			MDSDocument.AttachmentInfoMap {
		// Check for batch
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
			// Have document in batch
			return batchDocumentInfo.documentAttachmentInfoMap(
					applyingChangesTo:
							try! self.documentBacking(for: documentType, documentID: documentID).attachmentInfoMap)
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: documentID) != nil {
			// Creating
			return [:]
		} else {
			// Retrieve document backing
			return try self.documentBacking(for: documentType, documentID: documentID).attachmentInfoMap
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws ->
			Data {
		// Check for batch
		if let batch = self.batchMap.value(for: .current),
				let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
			// Have document in batch
			if let content = batchDocumentInfo.attachmentContent(for: attachmentID) {
				// Found
				return content
			}
		} else if let content = self.remoteStorageCache.attachmentContent(for: attachmentID) {
			// Found in cache
			return content
		}

		// Get attachment
		let	(data, error) =
					self.httpEndpointClient.documentAttachmentGet(documentStorageID: self.documentStorageID,
							documentType: documentType, documentID: documentID, attachmentID: attachmentID,
							authorization: self.authorization)
		if data != nil {
			// Update cache
			self.remoteStorageCache.setAttachment(content: data!, for: attachmentID)

			return data!
		} else {
			// Error
			throw error!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int {
		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				let	attachmentInfo =
							try documentAttachmentInfoMap(for: documentType, documentID: documentID)[attachmentID]!
				batchDocumentInfo.attachmentUpdate(id: attachmentID, currentRevision: attachmentInfo.revision,
						info: updatedInfo, content: updatedContent)
			} else {
				// Don't have document in batch
				let	documentBacking = try self.documentBacking(for: documentType, documentID: documentID)
				let	attachmentInfo =
							try documentAttachmentInfoMap(for: documentType, documentID: documentID)[attachmentID]!
				batch.documentAdd(documentType: documentBacking.type, documentID: documentID,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentUpdate(id: attachmentID, currentRevision: attachmentInfo.revision,
								info: updatedInfo, content: updatedContent)
			}

			return -1
		} else {
			// Not in batch
			return try documentAttachmentUpdate(documentType: documentType, documentID: documentID, documentBacking: nil,
					attachmentID: attachmentID, info: updatedInfo, content: updatedContent)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws {
		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: documentID) {
				// Have document in batch
				batchDocumentInfo.attachmentRemove(id: attachmentID)
			} else {
				// Don't have document in batch
				let	documentBacking = try self.documentBacking(for: documentType, documentID: documentID)
				batch.documentAdd(documentType: documentBacking.type, documentID: documentID,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentRemove(id: attachmentID)
			}
		} else {
			// Not in batch
			try documentAttachmentRemove(documentType: documentType, documentID: documentID, documentBacking: nil,
					attachmentID: attachmentID)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentRemove(_ document :MDSDocument) throws {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batch = self.batchMap.value(for: .current) {
			// In batch
			if let batchDocumentInfo = batch.documentInfoGet(for: document.id) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = try! self.documentBacking(for: documentType, documentID: document.id)
				batch.documentAdd(documentType: documentType, documentID: document.id, documentBacking: documentBacking,
								creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate)
						.remove()
			}
		} else {
			// Not in batch
			let	documentBacking = try! self.documentBacking(for: documentType, documentID: document.id)
			try documentUpdate(documentType: documentBacking.type,
					documentUpdateInfos:
							[DocumentUpdateInfo(MDSDocument.UpdateInfo(documentID: document.id, active: false),
									documentBacking)])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister(name :String, documentType :String, relevantProperties :[String],
			keysInfo :[String : Any], keysSelector :String, keysProc :@escaping MDSDocument.KeysProc) throws {
		// Register index
		let	error =
					self.httpEndpointClient.indexRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: documentType, relevantProperties: relevantProperties,
							keysSelector: keysSelector, keysSelectorInfo: keysInfo, authorization: self.authorization)
		guard error == nil else {
			// Error
			throw error!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws {
		// Validate
		guard self.batchMap.value(for: .current) == nil else {
			throw MDSDocumentStorageError.illegalInBatch
		}

		// Setup
		let	documentCreateProc = documentCreateProc(for: documentType)
		var	keysRemaining = Set<String>(keys.filter({ !$0.isEmpty }))
		guard !keysRemaining.isEmpty else { return }

		// Process first key to ensure index is up to date.  We need to only call the API one at a time to avoid the
		//	server overlapping calls.  In the future would be great to figure a different way to make the client
		//	simpler.
		let	firstKey = keysRemaining.removeFirst()
		let	documentRevisionInfosMap = LockingDictionary<String, MDSDocument.RevisionInfo>()
		while true {
			// Retrieve info
			let	info =
						self.httpEndpointClient.indexGetDocumentInfos(documentStorageID: self.documentStorageID,
								name: name, keys: [firstKey], authorization: self.authorization)

			// Handle results
			if let isUpToDate = info.isUpToDate {
				// Success
				if isUpToDate {
					// All good
					documentRevisionInfosMap.merge(info.documentRevisionInfosMap!)
					break
				} else {
					// Keep working
					continue
				}
			} else {
				// Error
				throw info.error!
			}
		}

		// Check if have remaining keys
		let	semaphore = DispatchSemaphore(value: 0)
		var	errors = [Error]()
		var	requestHasCompleted = keysRemaining.isEmpty
		if !keysRemaining.isEmpty {
			// Queue info retrieval
			self.httpEndpointClient.queue(
					MDSHTTPServices.httpEndpointRequestForIndexGetDocumentInfos(
							documentStorageID: self.documentStorageID, name: name, keys: Array(keysRemaining),
							authorization: self.authorization),
					partialResultsProc: {
						// Handle results
						if $0 != nil {
							// Add to dictionary
							documentRevisionInfosMap.merge($0!)

							// Signal
							semaphore.signal()
						}

						// Ignore error (will collect below)
						_ = $1
					}, completionProc: {
						// Note errors
						errors += $1

						// All done
						requestHasCompleted = true

						// Signal
						semaphore.signal()
					})

			// All keys submitted
			keysRemaining.removeAll()
		}

		// Keep going until all keys are processed
		while errors.isEmpty && (!requestHasCompleted || !documentRevisionInfosMap.isEmpty) {
			// Check if waiting for more info
			if documentRevisionInfosMap.isEmpty {
				// Wait for signal
				semaphore.wait()
			}

			// Run lean
			try autoreleasepool() {
				// Get queued document infos
				let	documentRevisionInfosMapToProcess = documentRevisionInfosMap.removeAll()
				let	map = Dictionary(documentRevisionInfosMapToProcess.map({ ($0.value.documentID, $0.key )}))
				if !map.isEmpty {
					// Iterate document IDs
					try self.documentIterateIDs(documentType: documentType,
							documentRevisionInfos: Array(documentRevisionInfosMapToProcess.values), activeOnly: false)
							{ proc(map[$0]!, documentCreateProc($0, self)) }
				}
			}
		}

		// Check for error
		if !errors.isEmpty {
			// Error
			throw errors.first!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoGet(for keys :[String]) throws -> [String : String] {
		// Preflight
		guard !keys.isEmpty else { return [:] }

		// Retrieve info
		let	(info, error) =
					self.httpEndpointClient.infoGet(documentStorageID: self.documentStorageID, keys: keys,
							authorization: self.authorization)
		guard error == nil else {
			// Error
			throw error!
		}

		return info!
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoSet(_ info :[String : String]) throws {
		// Preflight
		guard !info.isEmpty else { return }

		// Set info
		let	error =
					self.httpEndpointClient.infoSet(documentStorageID: self.documentStorageID, info: info,
							authorization: self.authorization)
		if error != nil {
			// Error
			throw error!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoRemove(keys :[String]) throws {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalGet(for keys: [String]) -> [String : String] {
		// Unimplemented (purposefully)
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalSet(_ info :[String : String]) throws {
		// Preflight
		guard !info.isEmpty else { return }

		// Set info
		let	error =
					self.httpEndpointClient.internalSet(documentStorageID: self.documentStorageID, info: info,
							authorization: self.authorization)
		if error != nil {
			// Error
			throw error!
		}
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
			// Iterate document types
			try batch.documentInfosByDocumentType.forEach() { documentType, batchDocumentInfosByDocumentID in
				// Setup
				var	documentCreateInfos = [MDSDocument.CreateInfo]()
				var	documentUpdateInfos = [DocumentUpdateInfo]()
				var	addAttachmentInfos = [(documentID :String, [MDSBatch<DocumentBacking>.AddAttachmentInfo])]()

				// Iterate document info for this document type
				try batchDocumentInfosByDocumentID.forEach() { documentID, batchDocumentInfo in
					// Check if have pre-existing document
					if let documentBacking = batchDocumentInfo.documentBacking {
						// Have an existing document so update.  Updating the document will get fresh info from the
						//	server to update our document backing which includes the attachment info.  For efficiency,
						//	we go ahead and do all the attachment transactions now so that the actual document update
						//	return info already has the latest attachment info - which saves a server call if we were
						//	to do it in the other order.
						// Process attachments
						try batchDocumentInfo.removedAttachmentIDs.forEach() {
							// Remove attachment
							try self.documentAttachmentRemove(documentType: documentType, documentID: documentID,
									documentBacking: documentBacking, attachmentID: $0)
						}
						try batchDocumentInfo.addAttachmentInfosByID.values.forEach() {
							// Add attachment
							_ = try self.documentAttachmentAdd(documentType: documentType, documentID: documentID,
									documentBacking: documentBacking, info: $0.info, content: $0.content)
						}
						try batchDocumentInfo.updateAttachmentInfosByID.values.forEach() {
							// Update attachment
							_ = try self.documentAttachmentUpdate(documentType: documentType, documentID: documentID,
									documentBacking: documentBacking, attachmentID: $0.id, info: $0.info,
									content: $0.content)
						}

						// Queue update document
						let	documentUpdateInfo =
									MDSDocument.UpdateInfo(documentID: documentID,
											updated: batchDocumentInfo.updatedPropertyMap,
											removed: batchDocumentInfo.removedProperties,
											active: !batchDocumentInfo.removed)
						documentUpdateInfos.append(DocumentUpdateInfo(documentUpdateInfo, documentBacking))
					} else {
						// This is a new document.  We cannot process the attachments before creating the document as
						//	the server must have a document reference in order to do any attachment processing, which
						//	it doesn't have until the document is created.  So go ahead and queue the document create,
						//	and also queue all the attachment handling to do after the document is created.
						// Process attachments
						addAttachmentInfos.append((documentID, Array(batchDocumentInfo.addAttachmentInfosByID.values)))

						// Queue create document
						documentCreateInfos.append(
								MDSDocument.CreateInfo(documentID: documentID,
										creationDate: batchDocumentInfo.creationDate,
										modificationDate: batchDocumentInfo.modificationDate,
										propertyMap: batchDocumentInfo.updatedPropertyMap))
					}
				}

				// Create documents
				_ = try self.documentCreate(documentType: documentType, documentCreateInfos: documentCreateInfos)

				// Process attachments
				try addAttachmentInfos.forEach() { documentID, addAttachmentInfos in
					// Setup
					let	documentBacking = self.documentBackingCache.documentBacking(for: documentID)

					// Iterate add attachment infos
					try addAttachmentInfos.forEach() {
						// Add attachment
						_ = try self.documentAttachmentAdd(documentType: documentType, documentID: documentID,
								documentBacking: documentBacking, info: $0.info, content: $0.content)
					}
				}

				// Update documents
				try self.documentUpdate(documentType: documentType, documentUpdateInfos: documentUpdateInfos)
			}
			batch.associationIterateChanges() {
				// Update association
				try? self.associationUpdate(for: $0, updates: $1)
			}
		}

		// Remove
		self.batchMap.set(nil, for: .current)
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func cachedData(for key :String) -> Data? { self.remoteStorageCache.data(for: key) }

	//------------------------------------------------------------------------------------------------------------------
	public func cachedInt(for key :String) -> Int? { self.remoteStorageCache.int(for: key) }

	//------------------------------------------------------------------------------------------------------------------
	public func cachedString(for key :String) -> String? { self.remoteStorageCache.string(for: key) }

	//------------------------------------------------------------------------------------------------------------------
	public func cachedTimeIntervals(for keys :[String]) -> [String : TimeInterval] {
		// Return info from cache
		return self.remoteStorageCache.timeIntervals(for: keys)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cache(_ value :Any?, for key :String) { self.remoteStorageCache.set(value, for: key) }

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func documentBacking(for documentType :String, documentID :String) throws -> DocumentBacking {
		// Check if in cache
		if let documentBacking = self.documentBackingCache.documentBacking(for: documentID) {
			// Have in cache
			return documentBacking
		} else {
			// Must retrieve from server
			var	documentBackings = [DocumentBacking]()
			try documentGet(for: documentType, documentIDs: [documentID]) { documentBackings.append($0) }

			if let documentBacking = documentBackings.first {
				// Found
				return documentBacking
			} else {
				// Not found
				throw MDSDocumentStorageError.unknownDocumentID(documentID: documentID)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func cacheUpdate(for documentType :String, with documentFullInfos :[MDSDocument.FullInfo]) ->
			[DocumentBacking] {
		// Update document backing cache
		let	documentBackingInfos = documentBackingCacheUpdate(for: documentType, with: documentFullInfos)

		// Update remote storage cache
		self.remoteStorageCache.add(documentFullInfos, for: documentType)

		return documentBackingInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func documentBackingCacheUpdate(for documentType :String, with documentFullInfos :[MDSDocument.FullInfo]) ->
			[DocumentBacking] {
		// Preflight
		guard !documentFullInfos.isEmpty else { return [] }

		// Update document backing cache
		let	documentBackings =
					documentFullInfos.map() {
						DocumentBacking(type: documentType, documentID: $0.documentID, revision: $0.revision,
								active: $0.active, creationDate: $0.creationDate,
								modificationDate: $0.modificationDate, propertyMap: $0.propertyMap,
								attachmentInfoMap: $0.attachmentInfoMap)
					}
		self.documentBackingCache.add(documentBackings)

		return documentBackings
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo]) throws ->
			[MDSDocument.OverviewInfo] {
		// Preflight
		guard !documentCreateInfos.isEmpty else { return [] }

		// Queue document retrieval
		let	documentCreateInfosMap = Dictionary(documentCreateInfos.map({ ($0.documentID, $0) }))
		let	documentCreateReturnInfos = LockingArray<MDSDocument.CreateReturnInfo>()
		let	semaphore = DispatchSemaphore(value: 0)
		var	documentOverviewInfos = [MDSDocument.OverviewInfo]()
		var	allDone = false
		var	errors = [Error]()
		self.httpEndpointClient.queue(documentStorageID: self.documentStorageID, type: documentType,
				documentCreateInfos: documentCreateInfos, authorization: self.authorization,
				partialResultsProc: {
					// Add to array
					documentCreateReturnInfos.append($0)

					// Signal
					semaphore.signal()
				}, completionProc: {
					// Add errors
					errors = $0

					// All done
					allDone = true

					// Signal
					semaphore.signal()
				})
		if !errors.isEmpty {
			// Error
			throw errors.first!
		}

		// Process results
		while !allDone || !documentCreateReturnInfos.isEmpty {
			// Check if waiting for more info
			if documentCreateReturnInfos.isEmpty {
				// Wait for signal
				semaphore.wait()
			}

			// Run lean
			autoreleasepool() {
				// Get queued document infos
				let	documentCreateReturnInfosToProcess = documentCreateReturnInfos.removeAll()

				// Update caches
				let	documentFullInfos =
							documentCreateReturnInfosToProcess.map({
									MDSDocument.FullInfo(documentID: $0.documentID, revision: $0.revision, active: true,
											creationDate: $0.creationDate, modificationDate: $0.modificationDate,
											propertyMap: documentCreateInfosMap[$0.documentID]!.propertyMap,
											attachmentInfoMap: [:]) })
				cacheUpdate(for: documentType, with: documentFullInfos)

				// Update overview infos
				documentOverviewInfos +=
						documentFullInfos.map({
							// Return OverviewInfo
							MDSDocument.OverviewInfo(documentID: $0.documentID, revision: $0.revision,
									creationDate: $0.creationDate, modificationDate: $0.modificationDate)
						})
			}
		}

		return documentOverviewInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentGet(for documentType :String, documentIDs :[String],
			proc :(_ documentBacking :DocumentBacking) -> Void ) throws {
		// Preflight
		guard !documentIDs.isEmpty else { return }

		// Queue document retrieval
		let	documentFullInfos = LockingArray<MDSDocument.FullInfo>()
		let	semaphore = DispatchSemaphore(value: 0)
		var	allDone = false
		var	errors = [Error]()
		self.httpEndpointClient.queue(
				MDSHTTPServices.httpEndpointRequestForDocumentGetDocumentFullInfos(
						documentStorageID: self.documentStorageID, documentType: documentType, documentIDs: documentIDs,
						authorization: self.authorization),
				documentFullInfosProc: {
					// Add to array
					documentFullInfos.append($0)

					// Signal
					semaphore.signal()
				}, completionProc: {
					// Add errors
					errors = $0

					// All done
					allDone = true

					// Signal
					semaphore.signal()
				})
		if !errors.isEmpty {
			// Error
			throw errors.first!
		}

		// Process results
		while !allDone || !documentFullInfos.isEmpty {
			// Check if waiting for more info
			if documentFullInfos.isEmpty {
				// Wait for signal
				semaphore.wait()
			}

			// Run lean
			autoreleasepool() {
				// Get queued document infos
				let	documentFullInfosToProcess = documentFullInfos.removeAll()

				// Update caches
				cacheUpdate(for: documentType, with: documentFullInfosToProcess).forEach() { proc($0) }
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentIterateIDs(documentType :String, documentRevisionInfos :[MDSDocument.RevisionInfo],
			activeOnly :Bool, proc :(_ documentID :String) -> Void) throws {
		// Preflight
		guard !documentRevisionInfos.isEmpty else { return }

		// Setup
		let	batch = self.batchMap.value(for: .current)

		// Iterate all infos
		var	documentRevisionInfosPossiblyInCache = [MDSDocument.RevisionInfo]()
		var	documentRevisionInfosToRetrieve = [MDSDocument.RevisionInfo]()
		documentRevisionInfos.forEach() {
			// Check if in batch
			if let documentInfo = batch?.documentInfoGet(for: $0.documentID) {
				// Have document in batch
				if !activeOnly || (documentInfo.documentBacking == nil) || documentInfo.documentBacking!.active {
					// Call proc
					proc($0.documentID)
				}
			} else if let documentBacking = self.documentBackingCache.documentBacking(for: $0.documentID) {
				// Check active
				if !activeOnly || documentBacking.active {
					// Check revision
					if documentBacking.revision == $0.revision {
						// Use from documents cache
						proc($0.documentID)
					} else {
						// Must retrieve
						documentRevisionInfosToRetrieve.append($0)
					}
				}
			} else {
				// Check cache
				documentRevisionInfosPossiblyInCache.append($0)
			}
		}

		// Retrieve from disk cache
		let	(documentFullInfos, documentRevisionInfosNotResolved) =
					self.remoteStorageCache.info(for: documentType, with: documentRevisionInfosPossiblyInCache)

		// Update document backing cache
		documentBackingCacheUpdate(for: documentType, with: documentFullInfos)
				.filter({ !activeOnly || $0.active })
				.forEach() { proc($0.documentID) }

		// Check if have documents to retrieve
		documentRevisionInfosToRetrieve += documentRevisionInfosNotResolved
		if !documentRevisionInfosToRetrieve.isEmpty {
			// Retrieve from server
			try documentGet(for: documentType, documentIDs: documentRevisionInfosToRetrieve.map({ $0.documentID }))
					{ _ in }

			// Create documents
			documentRevisionInfosToRetrieve
					.map({ ($0.documentID, self.documentBackingCache.documentBacking(for: $0.documentID)!) })
					.filter({ !activeOnly || $0.1.active })
					.forEach() { proc($0.0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentUpdate(documentType :String, documentUpdateInfos :[DocumentUpdateInfo]) throws {
		// Preflight
		guard !documentUpdateInfos.isEmpty else { return }

		// Queue document retrieval
		let	documentUpdateInfosMap = Dictionary(documentUpdateInfos.map({ ($0.documentUpdateInfo.documentID, $0) }))
		let	documentUpdateReturnInfos = LockingArray<MDSDocument.UpdateReturnInfo>()
		let	semaphore = DispatchSemaphore(value: 0)
		var	allDone = false
		var	errors = [Error]()
		self.httpEndpointClient.queue(documentStorageID: self.documentStorageID, type: documentType,
				documentUpdateInfos: documentUpdateInfos.map({ $0.documentUpdateInfo }),
				authorization: self.authorization,
				partialResultsProc: {
					// Add to array
					documentUpdateReturnInfos.append($0)

					// Signal
					semaphore.signal()
				}, completionProc: {
					// Add errors
					errors = $0

					// All done
					allDone = true

					// Signal
					semaphore.signal()
				})
		if !errors.isEmpty {
			// Error
			throw errors.first!
		}

		// Process results
		while !allDone || !documentUpdateReturnInfos.isEmpty {
			// Check if waiting for more info
			if documentUpdateReturnInfos.isEmpty {
				// Wait for signal
				semaphore.wait()
			}

			// Run lean
			autoreleasepool() {
				// Get queued document infos
				let	documentUpdateReturnInfosToProcess = documentUpdateReturnInfos.removeAll()

				// Update caches
				let	documentFullInfos =
							documentUpdateReturnInfosToProcess.map({ documentUpdateReturnInfo -> MDSDocument.FullInfo in
								// Setup
								let	documentBacking =
											documentUpdateInfosMap[documentUpdateReturnInfo.documentID]!.documentBacking

								return MDSDocument.FullInfo(documentID: documentUpdateReturnInfo.documentID,
										revision: documentUpdateReturnInfo.revision,
										active: documentUpdateReturnInfo.active,
										creationDate: documentBacking.creationDate,
										modificationDate: documentUpdateReturnInfo.modificationDate,
										propertyMap: documentUpdateReturnInfo.propertyMap,
										attachmentInfoMap: documentBacking.attachmentInfoMap)
							})
				cacheUpdate(for: documentType, with: documentFullInfos)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentAttachmentAdd(documentType :String, documentID :String, documentBacking :DocumentBacking?,
			info :[String : Any], content :Data) throws -> MDSDocument.AttachmentInfo {
		// Perform
		let	(attachmentInfo, error) =
					self.httpEndpointClient.documentAttachmentAdd(documentStorageID: self.documentStorageID,
							documentType: documentType, documentID: documentID, info: info, content: content,
							authorization: self.authorization)
		if attachmentInfo != nil {
			// Success
			guard let id = attachmentInfo!["id"] as? String else {
				// Missing id
				throw MDSRemoteStorageError.serverResponseMissingExpectedInfo(serverResponseInfo: attachmentInfo!,
						expectedKey: "id")
			}

			guard let revision = attachmentInfo!["revision"] as? Int else {
				// Missing revision
				throw MDSRemoteStorageError.serverResponseMissingExpectedInfo(serverResponseInfo: attachmentInfo!,
						expectedKey: "revision")
			}

			// Update
			documentBacking?.attachmentInfoMap[id] = MDSDocument.AttachmentInfo(id: id, revision: revision, info: info)
			self.remoteStorageCache.setAttachment(content: content, for: id)

			return MDSDocument.AttachmentInfo(id: id, revision: revision, info: info)
		} else {
			// Error
			throw error!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentAttachmentUpdate(documentType :String, documentID :String, documentBacking :DocumentBacking?,
			attachmentID :String, info :[String : Any], content :Data) throws -> Int {
		// Perform
		let	(attachmentInfo, error) =
					self.httpEndpointClient.documentAttachmentUpdate(documentStorageID: self.documentStorageID,
							documentType: documentType, documentID: documentID, attachmentID: attachmentID, info: info,
							content: content, authorization: self.authorization)
		if attachmentInfo != nil {
			// Success
			guard let revision = attachmentInfo!["revision"] as? Int else {
				// Missing revision
				throw MDSRemoteStorageError.serverResponseMissingExpectedInfo(serverResponseInfo: attachmentInfo!,
						expectedKey: "revision")
			}

			// Update
			documentBacking?.attachmentInfoMap[attachmentID] =
					MDSDocument.AttachmentInfo(id: attachmentID, revision: revision, info: info)
			self.remoteStorageCache.setAttachment(content: content, for: attachmentID)

			return revision
		} else {
			// Error
			throw error!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentAttachmentRemove(documentType :String, documentID :String, documentBacking :DocumentBacking?,
			attachmentID :String) throws {
		// Perform
		let	error =
					self.httpEndpointClient.documentAttachmentRemove(documentStorageID: self.documentStorageID,
							documentType: documentType, documentID: documentID, attachmentID: attachmentID,
							authorization: self.authorization)
		if error == nil {
			// Update
			documentBacking?.attachmentInfoMap[attachmentID] = nil
			self.remoteStorageCache.setAttachment(for: attachmentID)
		} else {
			// Error
			throw error!
		}
	}
}
