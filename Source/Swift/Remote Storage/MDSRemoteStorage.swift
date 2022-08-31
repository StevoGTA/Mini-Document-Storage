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
open class MDSRemoteStorage : MDSDocumentStorage {

	// MARK: Types
	class DocumentBacking {

		// MARK: Properties
		let	type :String
		let	active :Bool
		let	creationDate :Date

		var	modificationDate :Date
		var	revision :Int
		var	propertyMap :[String : Any]
		var	attachmentInfoMap :MDSDocument.AttachmentInfoMap

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(type :String, revision :Int, active :Bool, creationDate :Date, modificationDate :Date,
				propertyMap :[String : Any], attachmentInfoMap :MDSDocument.AttachmentInfoMap) {
			// Store
			self.type = type
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

	typealias DocumentCreationProc = (_ id :String, _ documentStorage :MDSDocumentStorage) -> MDSDocument

	// MARK: Properties
	public	let	documentStorageID :String

	public	var	id :String = UUID().uuidString
	public	var	authorization :String?

	private	let	httpEndpointClient :HTTPEndpointClient
	private	let	remoteStorageCache :MDSRemoteStorageCache
	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<DocumentBacking>>()
	private	let	documentBackingCache = MDSDocumentBackingCache<DocumentBacking>()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, [String : Any]>()

	private	var	ephemeralValues :[/* Key */ String : Any]?
	private	var	documentCreationProcMap = LockingDictionary<String, DocumentCreationProc>()

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
	public func set(_ info :[String : String]) {
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

	//------------------------------------------------------------------------------------------------------------------
	public func documentCreate<T : MDSDocument>(creationProc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T)
			-> T {
		// Setup
		let	documentID = UUID().base64EncodedString

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			_ = batchInfo.addDocument(documentType: T.documentType, documentID: documentID, creationDate: Date(),
					modificationDate: Date())

			return creationProc(documentID, self)
		} else {
			// Not in batch
			self.documentsBeingCreatedPropertyMapMap.set([:], for: documentID)

			let	document = creationProc(documentID, self)

			let	propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: documentID)!
			self.documentsBeingCreatedPropertyMapMap.remove([documentID])

			createDocuments(documentType: T.documentType,
					documentCreateInfos: [MDSDocument.CreateInfo(documentID: documentID, propertyMap: propertyMap)])

			return document
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) -> T? {
		// Retrieve document
		var	document :T?
		iterate(documentIDs: [documentID], documentType: T.documentType,
				creationProc: { T(id: $0, documentStorage: $1) }) { document = $0 }

		return document
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Setup
		let	documentType = T.documentType
		let	lastRevisionKey = "\(documentType)-lastRevision"
		var	lastRevision = self.remoteStorageCache.int(for: lastRevisionKey) ?? 0

		// May need to try this more than once
		while true {
			// Query documents
			let	(isComplete, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call HTTP Endpoint Client
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForDocumentGet(
											documentStorageID: self.documentStorageID, documentType: documentType,
											sinceRevision: lastRevision, authorization: self.authorization),
									partialResultsProc: { self.updateCaches(for: documentType, with: $0) },
									completionProc: { (isComplete :Bool?, error :Error?) in
										// Call completion proc
										completionProc((isComplete, error))
									})
						}

			// Handle results
			if (isComplete ?? false) {
				// Done
				break
			} else if error != nil {
				// Error
				self.recentErrors.append(error!)

				return
			}
		}

		// Retrieve documentInfos
		let	documentFullInfos = self.remoteStorageCache.activeDocumentFullInfos(for: documentType)

		// Update document backing cache
		updateDocumentBackingCache(for: documentType, with: documentFullInfos)
			.forEach() { lastRevision = max(lastRevision, $0.documentBacking.revision) }

		// Update last revision
		self.remoteStorageCache.set(lastRevision, for: lastRevisionKey)

		// Iterate document infos, again
		documentFullInfos.forEach() { proc(T(id: $0.documentID, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void) {
		// Iterate
		iterate(documentIDs: documentIDs, documentType: T.documentType,
				creationProc: { T(id: $0, documentStorage: $1) }, proc: proc)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func creationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.creationDate
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// Not in batch
			return self.documentBacking(for: document).creationDate
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func modificationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.modificationDate
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Being created
			return Date()
		} else {
			// Not in batch
			return self.documentBacking(for: document).modificationDate
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func value(for property :String, in document :MDSDocument) -> Any? {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
			// In batch
			return batchDocumentInfo.value(for: property)
		} else if let propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Creating
			return propertyMap[property]
		} else {
			// Retrieve document backing
			return self.documentBacking(for: document).propertyMap[property]
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func data(for property :String, in document :MDSDocument) -> Data? {
		// Retrieve Base64-encoded string
		guard let string = value(for: property, in: document) as? String else { return nil }

		return Data(base64Encoded: string)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func date(for property :String, in document :MDSDocument) -> Date? {
		// Return date
		return Date(fromRFC3339Extended: value(for: property, in: document) as? String)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
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
			if let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.set(valueUse, for: property)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: document)
				batchInfo.addDocument(documentType: documentBacking.type, documentID: document.id,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								valueProc: { documentBacking.propertyMap[$0] })
						.set(valueUse, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Creating
			propertyMap[property] = valueUse
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: document.id)
		} else {
			// Not in batch and not creating
			let	documentBacking = self.documentBacking(for: document)
			let	documentUpdateInfo =
						(valueUse != nil) ?
								MDSDocument.UpdateInfo(documentID: document.id, updated: [property : valueUse!]) :
								MDSDocument.UpdateInfo(documentID: document.id, removed: [property])
			documentUpdate(documentType: documentBacking.type,
					documentUpdateInfos: [DocumentUpdateInfo(documentUpdateInfo, documentBacking)])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentInfoMap(for document :MDSDocument) -> MDSDocument.AttachmentInfoMap {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let documentInfo = batchInfo.documentInfo(for: document.id) {
				// Have document in batch
				return documentInfo.documentBacking?.attachmentInfoMap ?? [:]
			} else {
				// Don't have document in batch
				return self.documentBacking(for: document).attachmentInfoMap
			}
		} else if self.documentsBeingCreatedPropertyMapMap.value(for: document.id) != nil {
			// Creating
			return [:]
		} else {
			// Retrieve document backing
			return self.documentBacking(for: document).attachmentInfoMap
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentContent<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo) ->
			Data? {
		// Check cache
		if let content = self.remoteStorageCache.attachmentContent(for: attachmentInfo.id) { return content }

		// Setup
		let	documentType = type(of: document).documentType

		// Get attachment
		let	(data, error) =
					self.httpEndpointClient.documentGetAttachment(documentStorageID: self.documentStorageID,
							documentType: documentType, documentID: document.id, attachmentID: attachmentInfo.id,
							authorization: self.authorization)
		if data != nil {
			// Update cache
			self.remoteStorageCache.setAttachment(content: data!, for: attachmentInfo.id)

			return data!
		} else {
			// Store error
			self.recentErrors.append(error!)

			return nil
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentAdd<T : MDSDocument>(for document :T, type :String, info :[String : Any], content :Data) {
		// Setup
		let	documentType = Swift.type(of: document).documentType

		var	infoUse = info
		infoUse["type"] = type

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.attachmentAdd(info: infoUse, content: content)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: document)
				batchInfo.addDocument(documentType: documentBacking.type, documentID: document.id,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								valueProc: { documentBacking.propertyMap[$0] })
						.attachmentAdd(info: infoUse, content: content)
			}
		} else {
			// Not in batch
			attachmentAdd(documentType: documentType, documentID: document.id, documentBacking: nil, info: infoUse,
					content: content)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentUpdate<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo,
			updatedInfo :[String : Any], updatedContent :Data) {
		// Setup
		let	documentType = type(of: document).documentType

		var	info = updatedInfo
		info["type"] = attachmentInfo.type

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.attachmentUpdate(attachmentID: attachmentInfo.id,
						currentRevision: attachmentInfo.revision, info: info, content: updatedContent)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: document)
				batchInfo.addDocument(documentType: documentBacking.type, documentID: document.id,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								valueProc: { documentBacking.propertyMap[$0] })
						.attachmentUpdate(attachmentID: attachmentInfo.id, currentRevision: attachmentInfo.revision,
								info: info, content: updatedContent)
			}
		} else {
			// Not in batch
			attachmentUpdate(documentType: documentType, documentID: document.id, documentBacking: nil,
					attachmentID: attachmentInfo.id, info: info, content: updatedContent)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func attachmentRemove<T : MDSDocument>(for document :T, attachmentInfo :MDSDocument.AttachmentInfo) {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.attachmentRemove(attachmentID: attachmentInfo.id)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: document)
				batchInfo.addDocument(documentType: documentBacking.type, documentID: document.id,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate,
								valueProc: { documentBacking.propertyMap[$0] })
						.attachmentRemove(attachmentID: attachmentInfo.id)
			}
		} else {
			// Not in batch
			attachmentRemove(documentType: documentType, documentID: document.id, documentBacking: nil,
					attachmentID: attachmentInfo.id)
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
			batchInfo.iterateDocumentChanges() { documentType, batchDocumentInfosMap in
				// Collect changes
				var	documentCreateInfos = [MDSDocument.CreateInfo]()
				var	documentUpdateInfos = [DocumentUpdateInfo]()
				var	addAttachmentInfos = [(documentID :String, [MDSBatchInfo<DocumentBacking>.AddAttachmentInfo])]()

				// Iterate document info for this document type
				batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
					// Check if have pre-existing document
					if let documentBacking = batchDocumentInfo.documentBacking {
						// Have an existing document so update.  Updating the document will get fresh info from the
						//	server to update our document backing which includes the attachment info.  For efficiency,
						//	we go ahead and do all the attachment transactions now so that the actual document update
						//	return info already has the latest attachment info - which saves a server call if we were
						//	to do it in the other order.
						// Process attachments
						batchDocumentInfo.removeAttachmentInfos.forEach() {
							// Remove attachment
							self.attachmentRemove(documentType: documentType, documentID: documentID,
									documentBacking: batchDocumentInfo.documentBacking,
									attachmentID: $0.attachmentID)
						}
						batchDocumentInfo.addAttachmentInfos.forEach() {
							// Add attachment
							self.attachmentAdd(documentType: documentType, documentID: documentID,
									documentBacking: batchDocumentInfo.documentBacking, info: $0.info,
									content: $0.content)
						}
						batchDocumentInfo.updateAttachmentInfos.forEach() {
							// Update attachment
							self.attachmentUpdate(documentType: documentType, documentID: documentID,
									documentBacking: batchDocumentInfo.documentBacking,
									attachmentID: $0.attachmentID, info: $0.info, content: $0.content)
						}

						// Queue update document
						let	documentUpdateInfo =
									MDSDocument.UpdateInfo(documentID: documentID,
											active: !batchDocumentInfo.removed,
											updated: batchDocumentInfo.updatedPropertyMap ?? [:],
											removed: batchDocumentInfo.removedProperties ?? Set<String>())
						documentUpdateInfos.append(DocumentUpdateInfo(documentUpdateInfo, documentBacking))
					} else {
						// This is a new document.  We cannot process the attachments before creating the document as
						//	the server must have a document reference in order to do any attachment processing, which
						//	it doesn't have until the document is created.  So go ahead and queue the document create,
						//	and also queue all the attachment handling to do after the document is created.
						// Process attachments
						addAttachmentInfos.append((documentID, batchDocumentInfo.addAttachmentInfos))

						// Queue create document
						documentCreateInfos.append(
								MDSDocument.CreateInfo(documentID: documentID,
										creationDate: batchDocumentInfo.creationDate,
										modificationDate: batchDocumentInfo.modificationDate,
										propertyMap: batchDocumentInfo.updatedPropertyMap ?? [:]))
					}
				}

				// Create documents
				self.createDocuments(documentType: documentType, documentCreateInfos: documentCreateInfos)

				// Process attachments
				addAttachmentInfos.forEach() { documentID, addAttachmentInfos in
					// Setup
					let	documentBacking = self.documentBackingCache.documentBacking(for: documentID)

					// Iterate add attachment infos
					addAttachmentInfos.forEach() {
						// Add attachment
						self.attachmentAdd(documentType: documentType, documentID: documentID,
								documentBacking: documentBacking, info: $0.info, content: $0.content)
					}
				}

				// Update documents
				self.documentUpdate(documentType: documentType, documentUpdateInfos: documentUpdateInfos)
			}
			batchInfo.iterateAssocationChanges() {
				// Update assocation
				self.associationUpdate(for: $0, updates: $1)
			}
		}

		// Remove
		self.batchInfoMap.set(nil, for: Thread.current)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(_ document :MDSDocument) {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: document)
				batchInfo.addDocument(documentType: documentType, documentID: document.id,
								documentBacking: documentBacking, creationDate: documentBacking.creationDate,
								modificationDate: documentBacking.modificationDate)
						.remove()
			}
		} else {
			// Not in batch
			let	documentBacking = self.documentBacking(for: document)
			documentUpdate(documentType: documentBacking.type,
					documentUpdateInfos:
							[DocumentUpdateInfo(MDSDocument.UpdateInfo(documentID: document.id, active: false),
									documentBacking)])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationRegister(named name :String, fromDocumentType :String, toDocumentType :String) {
		// Register assocation
		let	error =
					self.httpEndpointClient.associationRegister(documentStorageID: self.documentStorageID, name: name,
							fromDocumentType: fromDocumentType, toDocumentType: toDocumentType,
							authorization: self.authorization)
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationUpdate<T : MDSDocument, U : MDSDocument>(for name :String,
			updates :[(action :MDSAssociationAction, fromDocument :T, toDocument :U)]) {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			batchInfo.noteAssocationUpdated(for: name,
					updates: updates.map({ ($0.action, $0.fromDocument.id, $0.toDocument.id) }))
		} else {
			// Not in batch
			associationUpdate(for: name, updates: updates.map({ ($0.action, $0.fromDocument.id, $0.toDocument.id) }))
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationGet(for name :String) -> [(fromDocumentID :String, toDocumentID :String)] {
		// Get assocations
		let	info =
					self.httpEndpointClient.associationGet(documentStorageID: self.documentStorageID, name: name,
							authorization: self.authorization)

		// Handle results
		if let associations = info.info?.associations {
			// Success
			return associations
		} else {
			// Error
			self.recentErrors.append(info.error!)

			return []
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func associationIterate<T : MDSDocument, U : MDSDocument>(for name :String, from document :T,
			proc :(_ document :U) -> Void) {
		// May need to try this more than once
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(info, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Queue
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForAssociationGetDocumentInfos(
											documentStorageID: self.documentStorageID, name: name,
											fromDocumentID: document.id, startIndex: startIndex,
											authorization: self.authorization))
									{ completionProc(($0, $1)) }
						}

			// Handle results
			if let (documentRevisionInfos, isComplete) = info {
				// Success
				iterateDocumentIDs(documentType: U.documentType, activeDocumentRevisionInfos: documentRevisionInfos)
					{ proc(U(id: $0, documentStorage: self)) }

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
	public func associationIterate<T : MDSDocument, U : MDSDocument>(for name :String, to document :U,
			proc :(_ document :T) -> Void) {
		// May need to try this more than once
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(info, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Queue
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForAssociationGetDocumentInfos(
											documentStorageID: self.documentStorageID, name: name,
											toDocumentID: document.id, startIndex: startIndex,
											authorization: self.authorization))
									{ completionProc(($0, $1)) }
						}

			// Handle results
			if let (documentRevisionInfos, isComplete) = info {
				// Success
				iterateDocumentIDs(documentType: T.documentType, activeDocumentRevisionInfos: documentRevisionInfos)
					{ proc(T(id: $0, documentStorage: self)) }

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
	public func associationGetValue<T : MDSDocument, U>(for name :String, from document :T,
			summedFromCachedValueWithName cachedValueName :String) -> U {
		// May need to try this more than once
		while true {
			// Query collection document count
			let	(info, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call HTTP Endpoint Client
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForAssocationGetIntegerValue(
											documentStorageID: self.documentStorageID, name: name, fromID: document.id,
											action: .sum, cacheName: T.documentType, cacheValueName: cachedValueName,
											authorization: self.authorization))
									{ completionProc(($0, $1)) }
						}

			// Handle results
			if info != nil {
				// Received info
				if !info!.isUpToDate {
					// Not up to date
					continue
				} else {
					// Success
					return info!.value as! U
				}
			} else {
				// Error
				self.recentErrors.append(error!)

				return 0 as! U
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func cacheRegister<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			valuesInfos :[(name :String, valueType :MDSValueType, selector :String, proc :(_ document :T) -> Any)]) {
		// Register cache
		let	error =
					self.httpEndpointClient.cacheRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: T.documentType, relevantProperties: relevantProperties,
							valueInfos:
									valuesInfos.map(
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
	public func collectionRegister<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
			isIncludedProc :@escaping (_ document :T) -> Bool) {
		// Register collection
		let	error =
					self.httpEndpointClient.collectionRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: T.documentType, relevantProperties: relevantProperties,
							isUpToDate: isUpToDate, isIncludedSelector: isIncludedSelector,
							isIncludedSelectorInfo: isIncludedSelectorInfo, authorization: self.authorization)
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionGetDocumentCount(for name :String) -> Int {
		// May need to try this more than once
		while true {
			// Query collection document count
			let	(info, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call HTTP Endpoint Client
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForCollectionGetDocumentCount(
											documentStorageID: self.documentStorageID, name: name,
											authorization: self.authorization))
									{ completionProc(($0, $1)) }
						}
			if error != nil {
				// Error
				self.recentErrors.append(error!)

				return 0
			}

			// Handle results
			let	(isUpToDate, count) = info!
			if !isUpToDate {
				// Not up to date
				continue
			} else {
				// Success
				return count!
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func collectionIterate<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// May need to try this more than once
		var	startIndex = 0
		while true {
			// Retrieve info
			let	(isUpToDate, info, error)  =
						DispatchQueue.performBlocking() { completionProc in
							// Queue
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForCollectionGetDocumentInfo(
											documentStorageID: self.documentStorageID, name: name,
											startIndex: startIndex, authorization: self.authorization))
									{ completionProc(($0, $1, $2)) }
						}

			// Handle results
			if !(isUpToDate ?? true) {
				// Not up to date
				continue
			} else if let (documentRevisionInfos, isComplete) = info {
				// Success
				iterateDocumentIDs(documentType: T.documentType, activeDocumentRevisionInfos: documentRevisionInfos)
					{ proc(T(id: $0, documentStorage: self)) }

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
	public func indexRegister<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any],
			keysProc :@escaping (_ document :T) -> [String]) {
		// Register index
		let	error =
					self.httpEndpointClient.indexRegister(documentStorageID: self.documentStorageID, name: name,
							documentType: T.documentType, relevantProperties: relevantProperties,
							isUpToDate: isUpToDate, keysSelector: keysSelector, keysSelectorInfo: keysSelectorInfo,
							authorization: self.authorization)
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func indexIterate<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
		// Setup
		var	keysRemaining = Set<String>(keys.filter({ !$0.isEmpty }))
		var	isUpToDate = false
		var	errors = [Error]()

		// Keep going until all keys are processed
		while !isUpToDate && errors.isEmpty && !keysRemaining.isEmpty {
			// Retrieve the rest of the info
			let	documentRevisionInfoMap = LockingDictionary<String, MDSDocument.RevisionInfo>()
			let	semaphore = DispatchSemaphore(value: 0)
			var	requestHasCompleted = false

			// Queue info retrieval
			self.httpEndpointClient.queue(
					MDSHTTPServices.httpEndpointRequestForIndexGetDocumentInfo(
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
						// Store
						isUpToDate = $0 ?? false

						// Add errors
						errors += $1

						// All done
						requestHasCompleted = true

						// Signal
						semaphore.signal()
					})

			// Process results
			while !requestHasCompleted || !documentRevisionInfoMap.isEmpty {
				// Check if waiting for more info
				if documentRevisionInfoMap.isEmpty {
					// Wait for signal
					semaphore.wait()
				}

				// Run lean
				autoreleasepool() {
					// Get queued document infos
					let	documentRevisionInfoMapToProcess = documentRevisionInfoMap.removeAll()

					// Process
					keysRemaining.formSymmetricDifference(documentRevisionInfoMapToProcess.keys)

					let	map = Dictionary(documentRevisionInfoMapToProcess.map({ ($0.value.documentID, $0.key )}))
					self.iterateDocumentIDs(documentType: T.documentType,
							activeDocumentRevisionInfos: Array(documentRevisionInfoMapToProcess.values))
							{ proc(map[$0]!, T(id: $0, documentStorage: self)) }
				}
			}
		}

		// Add errors
		self.recentErrors += errors
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerDocumentChangedProc(documentType :String,
			proc :@escaping (_ document :MDSDocument, _ documentChangeKind :MDSDocument.ChangeKind) -> Void) {
		// Unimplemented
		fatalError("Unimplemented")
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
	private func documentBacking(for document :MDSDocument) -> DocumentBacking {
		// Check if in cache
		if let documentBacking = self.documentBackingCache.documentBacking(for: document.id) {
			// Have in cache
			return documentBacking
		} else {
			// Must retrieve from server
			var	documentBackings = [DocumentBacking]()
			retrieveDocuments(for: [document.id], documentType: type(of: document).documentType)
					{ documentBackings.append($0.documentBacking) }

			return documentBackings.first!
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterate<T : MDSDocument>(documentIDs :[String], documentType :String,
			creationProc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T, proc :(_ document : T) -> Void) {
		// Check for batch
		var	documentIDsToRetrieve = [String]()
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			documentIDs.forEach() {
				// Check if have in batch
				if batchInfo.documentInfo(for: $0) != nil {
					// Have in batch
					proc(T(id: $0, documentStorage: self))
				} else {
					// Not in batch
					documentIDsToRetrieve.append($0)
				}
			}
		} else {
			// Not in batch
			documentIDsToRetrieve = documentIDs
		}

		// Retrieve documents and call proc
		retrieveDocuments(for: documentIDsToRetrieve, documentType: documentType)
				{ proc(creationProc($0.documentID, self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private func iterateDocumentIDs(documentType :String, activeDocumentRevisionInfos :[MDSDocument.RevisionInfo],
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
		updateDocumentBackingCache(for: documentType, with: documentFullInfos).forEach() { proc($0.documentID) }

		// Check if have documents to retrieve
		documentRevisionInfosToRetrieve += documentRevisionInfosNotResolved
		if !documentRevisionInfosToRetrieve.isEmpty {
			// Retrieve from server
			retrieveDocuments(for: documentRevisionInfosToRetrieve.map({ $0.documentID }), documentType: documentType)
					{ _ in }

			// Create documents
			documentRevisionInfosToRetrieve
					.map({ ($0.documentID, self.documentBackingCache.documentBacking(for: $0.documentID)!) })
					.forEach() { proc($0.0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func associationUpdate(for name :String,
			updates :[(action :MDSAssociationAction, fromDocumentID :String, toDocumentID :String)]) {
		// Check if have updates
		guard !updates.isEmpty else { return }
		
		// Update assocation
		let	errors =
					self.httpEndpointClient.associationUpdate(documentStorageID: self.documentStorageID, name: name,
							updates: updates, authorization: self.authorization)
		self.recentErrors.append(errors)
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func updateCaches(for documentType :String, with documentFullInfos :[MDSDocument.FullInfo]) ->
			[MDSDocument.BackingInfo<DocumentBacking>] {
		// Update document backing cache
		let	documentBackingInfos = updateDocumentBackingCache(for: documentType, with: documentFullInfos)

		// Update remote storage cache
		self.remoteStorageCache.add(documentFullInfos, for: documentType)

		return documentBackingInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func updateDocumentBackingCache(for documentType :String, with documentFullInfos :[MDSDocument.FullInfo]) ->
			[MDSDocument.BackingInfo<DocumentBacking>] {
		// Preflight
		guard !documentFullInfos.isEmpty else { return [] }

		// Update document backing cache
		let	documentBackingInfos =
					documentFullInfos.map() {
						MDSDocument.BackingInfo<DocumentBacking>(documentID: $0.documentID,
								documentBacking:
										DocumentBacking(type: documentType, revision: $0.revision,
												active: $0.active, creationDate: $0.creationDate,
												modificationDate: $0.modificationDate, propertyMap: $0.propertyMap,
												attachmentInfoMap: $0.attachmentInfoMap))
					}
		self.documentBackingCache.add(documentBackingInfos)

		return documentBackingInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	private func createDocuments(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo]) {
		// Preflight
		guard !documentCreateInfos.isEmpty else { return }

		// Setup
		let	documentCreateInfosMap = Dictionary(documentCreateInfos.map({ ($0.documentID, $0) }))
		let	documentCreateReturnInfos = LockingArray<MDSDocument.CreateReturnInfo>()
		let	semaphore = DispatchSemaphore(value: 0)
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
				updateCaches(for: documentType, with: documentFullInfos)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func retrieveDocuments(for documentIDs :[String], documentType :String,
			proc :(_ documentBackingInfo :MDSDocument.BackingInfo<DocumentBacking>) -> Void ) {
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
				updateCaches(for: documentType, with: documentFullInfosToProcess).forEach() { proc($0) }
			}
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
				updateCaches(for: documentType, with: documentFullInfos)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func attachmentAdd(documentType :String, documentID :String, documentBacking :DocumentBacking?,
			info :[String : Any], content :Data) {
		// Perform
		let	(attachmentInfo, error) =
					self.httpEndpointClient.documentAddAttachment(documentStorageID: self.documentStorageID,
							documentType: documentType, documentID: documentID, info: info, content: content,
							authorization: self.authorization)
		if attachmentInfo != nil {
			// Success
			guard let id = attachmentInfo!["id"] as? String else {
				// Missing id
				self.recentErrors.append(
						MDSRemoteStorageError.serverResponseMissingExpectedInfo(serverResponseInfo: attachmentInfo!,
								expectedKey: "id"))

				return
			}

			guard let revision = attachmentInfo!["revision"] as? Int else {
				// Missing id
				self.recentErrors.append(
						MDSRemoteStorageError.serverResponseMissingExpectedInfo(serverResponseInfo: attachmentInfo!,
								expectedKey: "revision"))

				return
			}

			// Update
			documentBacking?.attachmentInfoMap[id] = MDSDocument.AttachmentInfo(id: id, revision: revision, info: info)
			self.remoteStorageCache.setAttachment(content: content, for: id)
		} else {
			// Store error
			self.recentErrors.append(error!)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func attachmentUpdate(documentType :String, documentID :String, documentBacking :DocumentBacking?,
			attachmentID :String, info :[String : Any], content :Data) {
		// Perform
		let	(attachmentInfo, error) =
					self.httpEndpointClient.documentUpdateAttachment(documentStorageID: self.documentStorageID,
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
	private func attachmentRemove(documentType :String, documentID :String, documentBacking :DocumentBacking?,
			attachmentID :String) {
		// Perform
		let	error =
					self.httpEndpointClient.documentRemoveAttachment(documentStorageID: self.documentStorageID,
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
