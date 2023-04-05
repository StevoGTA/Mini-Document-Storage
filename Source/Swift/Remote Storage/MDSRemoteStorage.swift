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

	// MARK: Properties
	public	let	documentStorageID :String

	public	var	authorization :String?

	private	let	httpEndpointClient :HTTPEndpointClient
	private	let	remoteStorageCache :MDSRemoteStorageCache
	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<DocumentBacking>>()
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
	public func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
		// Check if have updates
		guard !updates.isEmpty else { return }

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			batchInfo.associationNoteUpdated(for: name, updates: updates)
		} else {
			// Not in batch
			let	errors =
						self.httpEndpointClient.associationUpdate(documentStorageID: self.documentStorageID, name: name,
								updates: updates, authorization: self.authorization)
			if !errors.isEmpty { throw errors.first! }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(for name :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, associationItems :[MDSAssociation.Item]) {
// TODO: Check if in batch and add batch changes
		// Get associations
		let	info =
					self.httpEndpointClient.associationGet(documentStorageID: self.documentStorageID, name: name,
							startIndex: startIndex, count: count, authorization: self.authorization)

		// Handle results
		if let associationItems = info.info?.associationItems {
			// Success
			return (-1, associationItems)
		} else {
			// Error
			self.recentErrors.append(info.error!)

			return (0, [])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) {
// TODO: Check if in batch and add batch changes
		// Setup
		let	documentCreateProc = documentCreateProc(for: toDocumentType)

		// May need to try this more than once
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(info, error) =
						self.httpEndpointClient.associationGetDocumentInfos(documentStorageID: self.documentStorageID,
								name: name, fromDocumentID: fromDocumentID, startIndex: startIndex,
								authorization: self.authorization)

			// Handle results
			if let (documentRevisionInfos, isComplete) = info {
				// Success
				documentIterateIDs(documentType: toDocumentType, activeDocumentRevisionInfos: documentRevisionInfos)
					{ proc(documentCreateProc($0, self)) }

				// Update
				startIndex += documentRevisionInfos.count

				// Check if is complete
				if isComplete {
					// Complete
					return
				}
			} else {
				// Error
				self.recentErrors.append(error!)

				return
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate(for name :String, to toDocumentID :String, fromDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) {
// TODO: Check if in batch and add batch changes
		// Setup
		let	documentCreateProc = documentCreateProc(for: fromDocumentType)

		// May need to try this more than once
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(info, error) =
						self.httpEndpointClient.associationGetDocumentInfos(
								documentStorageID: self.documentStorageID, name: name, toDocumentID: toDocumentID,
								startIndex: startIndex, authorization: self.authorization)

			// Handle results
			if let (documentRevisionInfos, isComplete) = info {
				// Success
				documentIterateIDs(documentType: fromDocumentType, activeDocumentRevisionInfos: documentRevisionInfos)
					{ proc(documentCreateProc($0, self)) }

				// Update
				startIndex += documentRevisionInfos.count

				// Check if is complete
				if isComplete {
					// Complete
					return
				}
			} else {
				// Error
				self.recentErrors.append(error!)

				return
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGetIntegerValues(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentIDs :[String], cacheName :String, cachedValueNames :[String]) -> [String : Int64] {
		// May need to try this more than once
		while true {
			// Query collection document count
			let	(info, error) =
						self.httpEndpointClient.associationGetIntegerValues(
											documentStorageID: self.documentStorageID, name: name, action: action,
										fromDocumentIDs: fromDocumentIDs, cacheName: cacheName,
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
				self.recentErrors.append(error!)

				return [:]
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			valueInfos :[(name :String, valueType :MDSValueType, selector :String, proc :MDSDocument.ValueProc)]) {
		// Register cache
		let	error =
					self.httpEndpointClient.cacheRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: documentType, relevantProperties: relevantProperties,
							valueInfos:
									valueInfos.map(
											{ MDSHTTPServices.CacheRegisterEndpointValueInfo($0.name, $0.valueType,
													$0.selector) }),
							authorization: self.authorization)
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String,
			isIncludedProc :@escaping MDSDocument.IsIncludedProc) {
		// Register collection
		let	error =
					self.httpEndpointClient.collectionRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: documentType, relevantProperties: relevantProperties,
							isUpToDate: isUpToDate, isIncludedSelector: isIncludedSelector,
							isIncludedSelectorInfo: isIncludedInfo, authorization: self.authorization)
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionGetDocumentCount(for name :String) throws -> Int {
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
				self.recentErrors.append(error!)

				return 0
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) {
		// Setup
		let	documentCreateProc = self.documentCreateProc(for: documentType)

		// May need to try this more than once
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(isUpToDate, info, error)  =
						self.httpEndpointClient.collectionGetDocumentInfos(
								documentStorageID: self.documentStorageID, name: name, startIndex: startIndex,
								authorization: self.authorization)

			// Handle results
			if !(isUpToDate ?? true) {
				// Not up to date
				continue
			} else if let (documentRevisionInfos, isComplete) = info {
				// Success
				documentIterateIDs(documentType: documentType, activeDocumentRevisionInfos: documentRevisionInfos)
					{ proc(documentCreateProc($0, self)) }

				// Update
				startIndex += documentRevisionInfos.count

				// Check if is complete
				if isComplete {
					// Complete
					return
				}
			} else {
				// Error
				self.recentErrors.append(error!)

				return
			}
		}
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
						documentCreate(documentType: documentType, documentCreateInfos: updatedDocumentCreateInfos)

			// Update infos
			infos = documentOverviewInfos.map({ (documentsByDocumentID[$0.documentID]!, $0) })
		}

		return infos
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentGetCount(for documentType :String) throws -> Int {
		// Get document count
		let	(count, error) =
					self.httpEndpointClient.documentGetCount(documentStorageID: self.documentStorageID,
							documentType: documentType, authorization: self.authorization)
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			throw error!
		}

		return count!
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, documentIDs :[String],
			documentCreateProc :MDSDocument.CreateProc?,
			proc :(_ document :MDSDocument?, _ documentFullInfo :MDSDocument.FullInfo) -> Void) {
// TODO
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentIterate(for documentType :String, sinceRevision :Int, count :Int?, activeOnly: Bool,
			documentCreateProc :MDSDocument.CreateProc?,
			proc :(_ document :MDSDocument?, _ documentFullInfo :MDSDocument.FullInfo) -> Void) {
// TODO
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
			// Not in batch
			return self.documentBacking(for: type(of: document).documentType, documentID: document.id).creationDate
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
			// Not in batch
			return self.documentBacking(for: type(of: document).documentType, documentID: document.id).modificationDate
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
			// Creating
			return propertyMap[property]
		} else {
			// Retrieve document backing
			return self.documentBacking(for: type(of: document).documentType, documentID: document.id)
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
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: document.id) {
				// Have document in batch
				batchInfoDocumentInfo.set(valueUse, for: property)
			} else {
				// Don't have document in batch
				let	documentBacking =
							self.documentBacking(for: type(of: document).documentType, documentID: document.id)
				batchInfo.documentAdd(documentType: documentBacking.type, documentID: document.id,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.set(valueUse, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Creating
			propertyMap[property] = valueUse
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: document.id)
		} else {
			// Not in batch and not creating
			let	documentBacking = self.documentBacking(for: type(of: document).documentType, documentID: document.id)
			let	documentUpdateInfo =
						(valueUse != nil) ?
								MDSDocument.UpdateInfo(documentID: document.id, updated: [property : valueUse!]) :
								MDSDocument.UpdateInfo(documentID: document.id, removed: [property])
			documentUpdate(documentType: documentBacking.type,
					documentUpdateInfos: [DocumentUpdateInfo(documentUpdateInfo, documentBacking)])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any],
			content :Data) -> MDSDocument.AttachmentInfo {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
				// Have document in batch
				return batchInfoDocumentInfo.attachmentAdd(info: info, content: content)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: documentType, documentID: documentID)

				return batchInfo.documentAdd(documentType: documentBacking.type, documentID: documentID,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentAdd(info: info, content: content)
			}
		} else {
			// Not in batch
			return documentAttachmentAdd(documentType: documentType, documentID: documentID, documentBacking: nil,
					info: info, content: content) ?? MDSDocument.AttachmentInfo(id: "", revision: 0, info: [:])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentInfoMap(for documentType :String, documentID :String) ->
			MDSDocument.AttachmentInfoMap {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
			// Have document in batch
			return batchInfoDocumentInfo.documentBacking?.attachmentInfoMap ?? [:]
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: documentID) != nil {
			// Creating
			return [:]
		} else {
			// Retrieve document backing
			return self.documentBacking(for: documentType, documentID: documentID).attachmentInfoMap
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) -> Data {
// TODO: What about batch
		// Check cache
		if let content = self.remoteStorageCache.attachmentContent(for: attachmentID) { return content }

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
			// Store error
			self.recentErrors.append(error!)

			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) -> Int {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
				// Have document in batch
				let	attachmentInfo = documentAttachmentInfoMap(for: documentType, documentID: documentID)[attachmentID]!
				batchInfoDocumentInfo.attachmentUpdate(attachmentID: attachmentID,
						currentRevision: attachmentInfo.revision, info: updatedInfo, content: updatedContent)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: documentType, documentID: documentID)
				let	attachmentInfo = documentAttachmentInfoMap(for: documentType, documentID: documentID)[attachmentID]!
				batchInfo.documentAdd(documentType: documentBacking.type, documentID: documentID,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentUpdate(attachmentID: attachmentID, currentRevision: attachmentInfo.revision,
								info: updatedInfo, content: updatedContent)
			}
		} else {
			// Not in batch
			documentAttachmentUpdate(documentType: documentType, documentID: documentID, documentBacking: nil,
					attachmentID: attachmentID, info: updatedInfo, content: updatedContent)
		}

		return -1
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) {
		// Setup
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchInfoDocumentInfo = batchInfo.documentGetInfo(for: documentID) {
				// Have document in batch
				batchInfoDocumentInfo.attachmentRemove(attachmentID: attachmentID)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: documentType, documentID: documentID)
				batchInfo.documentAdd(documentType: documentBacking.type, documentID: documentID,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								initialPropertyMap: documentBacking.propertyMap)
						.attachmentRemove(attachmentID: attachmentID)
			}
		} else {
			// Not in batch
			documentAttachmentRemove(documentType: documentType, documentID: documentID, documentBacking: nil,
					attachmentID: attachmentID)
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
				let	documentBacking = self.documentBacking(for: documentType, documentID: document.id)
				batchInfo.documentAdd(documentType: documentType, documentID: document.id,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate)
						.remove()
			}
		} else {
			// Not in batch
			let	documentBacking = self.documentBacking(for: documentType, documentID: document.id)
			documentUpdate(documentType: documentBacking.type,
					documentUpdateInfos:
							[DocumentUpdateInfo(MDSDocument.UpdateInfo(documentID: document.id, active: false),
									documentBacking)])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexRegister(name :String, documentType :String, relevantProperties :[String],
			keysInfo :[String : Any], keysSelector :String, keysProc :@escaping MDSDocument.KeysProc) {
		// Register index
		let	error =
					self.httpEndpointClient.indexRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: documentType, relevantProperties: relevantProperties,
							keysSelector: keysSelector, keysSelectorInfo: keysInfo, authorization: self.authorization)
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) {
		// Setup
		let	documentCreateProc = documentCreateProc(for: documentType)
		var	keysRemaining = Set<String>(keys.filter({ !$0.isEmpty }))
		guard !keysRemaining.isEmpty else { return }

		// Process first key to ensure index is up to date.  We need to only call the API one at a time to avoid the
		//	server overlapping calls.  In the future would be great to figure a different way to make the client
		//	simpler.
		let	firstKey = keysRemaining.removeFirst()
		let	documentRevisionInfoMap = LockingDictionary<String, MDSDocument.RevisionInfo>()
		while true {
			// Retrieve info
			let	info =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForIndexGetDocumentInfos(
											documentStorageID: self.documentStorageID, name: name, keys: [firstKey],
											authorization: self.authorization),
									partialResultsProc: {
										// Handle results
										if $0 != nil {
											// Add to dictionary
											documentRevisionInfoMap.merge($0!)
										}

										// Ignore error (will collect via completionProc)
										_ = $1
									},
									completionProc: {completionProc(($0, $1)) })
						}

			// Handle results
			if let isUpToDate = info.0 {
				// Success
				if isUpToDate {
					// All good
					break
				} else {
					// Keep working
					continue
				}
			} else {
				// Error
				self.recentErrors += info.1

				return
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
							documentRevisionInfoMap.merge($0!)

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
		while errors.isEmpty && (!requestHasCompleted || !documentRevisionInfoMap.isEmpty) {
			// Check if waiting for more info
			if documentRevisionInfoMap.isEmpty {
				// Wait for signal
				semaphore.wait()
			}

			// Run lean
			autoreleasepool() {
				// Get queued document infos
				let	documentRevisionInfoMapToProcess = documentRevisionInfoMap.removeAll()
				let	map = Dictionary(documentRevisionInfoMapToProcess.map({ ($0.value.documentID, $0.key )}))
				if !map.isEmpty {
					// Iterate document IDs
					self.documentIterateIDs(documentType: documentType,
							activeDocumentRevisionInfos: Array(documentRevisionInfoMapToProcess.values))
							{ proc(map[$0]!, documentCreateProc($0, self)) }
				}
			}
		}

		// Add errors
		self.recentErrors += errors
	}

	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) -> [String : String] {
		// Preflight
		guard !keys.isEmpty else { return [:] }

		// Retrieve info
		let	(info, error) =
					self.httpEndpointClient.infoGet(documentStorageID: self.documentStorageID, keys: keys,
							authorization: self.authorization)
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return [:]
		}

		return info!
	}

	//------------------------------------------------------------------------------------------------------------------
	public func infoSet(_ info :[String : String]) {
		// Preflight
		guard !info.isEmpty else { return }

		// Set info
		let	error =
					self.httpEndpointClient.infoSet(documentStorageID: self.documentStorageID, info: info,
							authorization: self.authorization)
		if error != nil {
			// Store error
			self.recentErrors.append(error!)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(keys :[String]) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalGet(for keys: [String]) -> [String : String] {
		// Unimplemented (purposefully)
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func internalSet(_ info :[String : String]) {
		// Preflight
		guard !info.isEmpty else { return }

		// Set info
		let	error =
					self.httpEndpointClient.internalSet(documentStorageID: self.documentStorageID, info: info,
							authorization: self.authorization)
		if error != nil {
			// Store error
			self.recentErrors.append(error!)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		// Setup
		let	batchInfo = MDSBatchInfo<DocumentBacking>()

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
			// Iterate document types
			batchInfo.documentIterateChanges() { documentType, batchInfoDocumentInfosMap in
				// Setup
				var	documentCreateInfos = [MDSDocument.CreateInfo]()
				var	documentUpdateInfos = [DocumentUpdateInfo]()
				var	addAttachmentInfos = [(documentID :String, [MDSBatchInfo<DocumentBacking>.AddAttachmentInfo])]()

				// Iterate document info for this document type
				batchInfoDocumentInfosMap.forEach() { documentID, batchInfoDocumentInfo in
					// Check if have pre-existing document
					if let documentBacking = batchInfoDocumentInfo.documentBacking {
						// Have an existing document so update.  Updating the document will get fresh info from the
						//	server to update our document backing which includes the attachment info.  For efficiency,
						//	we go ahead and do all the attachment transactions now so that the actual document update
						//	return info already has the latest attachment info - which saves a server call if we were
						//	to do it in the other order.
						// Process attachments
						batchInfoDocumentInfo.removeAttachmentInfos.forEach() {
							// Remove attachment
							self.documentAttachmentRemove(documentType: documentType, documentID: documentID,
									documentBacking: documentBacking, attachmentID: $0.attachmentID)
						}
						batchInfoDocumentInfo.addAttachmentInfos.forEach() {
							// Add attachment
							_ = self.documentAttachmentAdd(documentType: documentType, documentID: documentID,
									documentBacking: documentBacking, info: $0.info, content: $0.content)
						}
						batchInfoDocumentInfo.updateAttachmentInfos.forEach() {
							// Update attachment
							self.documentAttachmentUpdate(documentType: documentType, documentID: documentID,
									documentBacking: documentBacking, attachmentID: $0.attachmentID, info: $0.info,
									content: $0.content)
						}

						// Queue update document
						let	documentUpdateInfo =
									MDSDocument.UpdateInfo(documentID: documentID,
											updated: batchInfoDocumentInfo.updatedPropertyMap ?? [:],
											removed: batchInfoDocumentInfo.removedProperties ?? Set<String>(),
											active: !batchInfoDocumentInfo.removed)
						documentUpdateInfos.append(DocumentUpdateInfo(documentUpdateInfo, documentBacking))
					} else {
						// This is a new document.  We cannot process the attachments before creating the document as
						//	the server must have a document reference in order to do any attachment processing, which
						//	it doesn't have until the document is created.  So go ahead and queue the document create,
						//	and also queue all the attachment handling to do after the document is created.
						// Process attachments
						addAttachmentInfos.append((documentID, batchInfoDocumentInfo.addAttachmentInfos))

						// Queue create document
						documentCreateInfos.append(
								MDSDocument.CreateInfo(documentID: documentID,
										creationDate: batchInfoDocumentInfo.creationDate,
										modificationDate: batchInfoDocumentInfo.modificationDate,
										propertyMap: batchInfoDocumentInfo.updatedPropertyMap ?? [:]))
					}
				}

				// Create documents
				_ = self.documentCreate(documentType: documentType, documentCreateInfos: documentCreateInfos)

				// Process attachments
				addAttachmentInfos.forEach() { documentID, addAttachmentInfos in
					// Setup
					let	documentBacking = self.documentBackingCache.documentBacking(for: documentID)

					// Iterate add attachment infos
					addAttachmentInfos.forEach() {
						// Add attachment
						_ = self.documentAttachmentAdd(documentType: documentType, documentID: documentID,
								documentBacking: documentBacking, info: $0.info, content: $0.content)
					}
				}

				// Update documents
				self.documentUpdate(documentType: documentType, documentUpdateInfos: documentUpdateInfos)
			}
			batchInfo.associationIterateChanges() {
				// Update association
				try? self.associationUpdate(for: $0, updates: $1)
			}
		}

		// Remove
		self.batchInfoMap.set(nil, for: Thread.current)
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
	private func documentBacking(for documentType :String, documentID :String) -> DocumentBacking {
		// Check if in cache
		if let documentBacking = self.documentBackingCache.documentBacking(for: documentID) {
			// Have in cache
			return documentBacking
		} else {
			// Must retrieve from server
			var	documentBackings = [DocumentBacking]()
			documentGet(for: [documentID], documentType: documentType) { documentBackings.append($0) }

			return documentBackings.first!
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
	private func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo]) ->
			[MDSDocument.OverviewInfo] {
		// Preflight
		guard !documentCreateInfos.isEmpty else { return [] }

		// Setup
		let	documentCreateInfosMap = Dictionary(documentCreateInfos.map({ ($0.documentID, $0) }))
		let	documentCreateReturnInfos = LockingArray<MDSDocument.CreateReturnInfo>()
		let	semaphore = DispatchSemaphore(value: 0)
		var	documentOverviewInfos = [MDSDocument.OverviewInfo]()
		var	allDone = false

		// Queue document retrieval
		self.httpEndpointClient.queue(documentStorageID: self.documentStorageID, type: documentType,
				documentCreateInfos: documentCreateInfos, authorization: self.authorization,
				partialResultsProc: {
					// Add to array
					documentCreateReturnInfos.append($0)

					// Signal
					semaphore.signal()
				}, completionProc: {
					// Add errors
					self.recentErrors += $0

					// All done
					allDone = true

					// Signal
					semaphore.signal()
				})

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
	private func documentGet(for documentIDs :[String], documentType :String,
			proc :(_ documentBacking :DocumentBacking) -> Void ) {
		// Preflight
		guard !documentIDs.isEmpty else { return }

		// Setup
		let	documentFullInfos = LockingArray<MDSDocument.FullInfo>()
		let	semaphore = DispatchSemaphore(value: 0)
		var	allDone = false

		// Queue document retrieval
		self.httpEndpointClient.queue(
				MDSHTTPServices.httpEndpointRequestForDocumentGet(documentStorageID: self.documentStorageID,
						documentType: documentType, documentIDs: documentIDs, authorization: self.authorization),
				partialResultsProc: {
					// Handle results
					if $0 != nil {
						// Add to array
						documentFullInfos.append($0!)

						// Signal
						semaphore.signal()
					}

					// Ignore error here (will collect below)
					_ = $1
				}, completionProc: {
					// Add errors
					self.recentErrors += $0

					// All done
					allDone = true

					// Signal
					semaphore.signal()
				})

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
	private func documentIterateIDs(documentType :String, activeDocumentRevisionInfos :[MDSDocument.RevisionInfo],
			proc :(_ documentID :String) -> Void) {
		// Preflight
		guard !activeDocumentRevisionInfos.isEmpty else { return }

		// Iterate all infos
		var	documentRevisionInfosPossiblyInCache = [MDSDocument.RevisionInfo]()
		var	documentRevisionInfosToRetrieve = [MDSDocument.RevisionInfo]()
		activeDocumentRevisionInfos.forEach() {
			// Check if have in cache and is most recent
			if let documentBacking = self.documentBackingCache.documentBacking(for: $0.documentID) {
				// Check revision
				if documentBacking.revision == $0.revision {
					// Use from documents cache
					proc($0.documentID)
				} else {
					// Must retrieve
					documentRevisionInfosToRetrieve.append($0)
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
		documentBackingCacheUpdate(for: documentType, with: documentFullInfos).forEach() { proc($0.documentID) }

		// Check if have documents to retrieve
		documentRevisionInfosToRetrieve += documentRevisionInfosNotResolved
		if !documentRevisionInfosToRetrieve.isEmpty {
			// Retrieve from server
			documentGet(for: documentRevisionInfosToRetrieve.map({ $0.documentID }), documentType: documentType)
					{ _ in }

			// Create documents
			documentRevisionInfosToRetrieve
					.map({ ($0.documentID, self.documentBackingCache.documentBacking(for: $0.documentID)!) })
					.forEach() { proc($0.0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentUpdate(documentType :String, documentUpdateInfos :[DocumentUpdateInfo]) {
		// Preflight
		guard !documentUpdateInfos.isEmpty else { return }

		// Setup
		let	documentUpdateInfosMap = Dictionary(documentUpdateInfos.map({ ($0.documentUpdateInfo.documentID, $0) }))
		let	documentUpdateReturnInfos = LockingArray<MDSDocument.UpdateReturnInfo>()
		let	semaphore = DispatchSemaphore(value: 0)
		var	allDone = false

		// Queue document retrieval
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
					self.recentErrors += $0

					// All done
					allDone = true

					// Signal
					semaphore.signal()
				})

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
			info :[String : Any], content :Data) -> MDSDocument.AttachmentInfo? {
		// Perform
		let	(attachmentInfo, error) =
					self.httpEndpointClient.documentAttachmentAdd(documentStorageID: self.documentStorageID,
							documentType: documentType, documentID: documentID, info: info, content: content,
							authorization: self.authorization)
		if attachmentInfo != nil {
			// Success
			guard let id = attachmentInfo!["id"] as? String else {
				// Missing id
				self.recentErrors.append(
						MDSRemoteStorageError.serverResponseMissingExpectedInfo(serverResponseInfo: attachmentInfo!,
								expectedKey: "id"))

				return nil
			}

			guard let revision = attachmentInfo!["revision"] as? Int else {
				// Missing id
				self.recentErrors.append(
						MDSRemoteStorageError.serverResponseMissingExpectedInfo(serverResponseInfo: attachmentInfo!,
								expectedKey: "revision"))

				return nil
			}

			// Update
			documentBacking?.attachmentInfoMap[id] = MDSDocument.AttachmentInfo(id: id, revision: revision, info: info)
			self.remoteStorageCache.setAttachment(content: content, for: id)

			return MDSDocument.AttachmentInfo(id: id, revision: revision, info: info)
		} else {
			// Store error
			self.recentErrors.append(error!)

			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentAttachmentUpdate(documentType :String, documentID :String, documentBacking :DocumentBacking?,
			attachmentID :String, info :[String : Any], content :Data) {
		// Perform
		let	(attachmentInfo, error) =
					self.httpEndpointClient.documentAttachmentUpdate(documentStorageID: self.documentStorageID,
							documentType: documentType, documentID: documentID, attachmentID: attachmentID, info: info,
							content: content, authorization: self.authorization)
		if attachmentInfo != nil {
			// Success
			guard let revision = attachmentInfo!["revision"] as? Int else {
				// Missing id
				self.recentErrors.append(
						MDSRemoteStorageError.serverResponseMissingExpectedInfo(serverResponseInfo: attachmentInfo!,
								expectedKey: "revision"))

				return
			}

			// Update
			documentBacking?.attachmentInfoMap[attachmentID] =
					MDSDocument.AttachmentInfo(id: attachmentID, revision: revision, info: info)
			self.remoteStorageCache.setAttachment(content: content, for: attachmentID)
		} else {
			// Store error
			self.recentErrors.append(error!)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func documentAttachmentRemove(documentType :String, documentID :String, documentBacking :DocumentBacking?,
			attachmentID :String) {
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
			// Store error
			self.recentErrors.append(error!)
		}
	}

	// MARK: Temporary sandbox
	//------------------------------------------------------------------------------------------------------------------
	// Will move this out when proper error handling is implemented
	private	var	recentErrors = LockingArray<Error>()
	public func queryRecentErrorsAndReset() -> [Error]? {
		// Retrieve erros and remove all
		let	errors = self.recentErrors.values
		self.recentErrors.removeAll()

		return !errors.isEmpty ? errors : nil
	}
}
