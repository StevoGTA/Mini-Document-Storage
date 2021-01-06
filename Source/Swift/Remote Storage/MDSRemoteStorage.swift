//
//  MDSRemoteStorage.swift
//  Mini Document Storage
//
//  Created by Stevo on 1/14/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSRemoteStorage
open class MDSRemoteStorage : MDSDocumentStorage {

	// MARK: Types
	struct DocumentBacking {

		// MARK: Properties
		let	type :String
		let	active :Bool
		let	creationDate :Date

		var	modificationDate :Date
		var	revision :Int
		var	propertyMap :[String : Any]

		// MARK: Lifecycle methods
		init(type :String, revision :Int, active :Bool, creationDate :Date, modificationDate :Date,
				propertyMap :[String : Any]) {
			// Store
			self.type = type
			self.active = active
			self.creationDate = creationDate

			self.modificationDate = modificationDate
			self.revision = revision
			self.propertyMap = propertyMap
		}

		init(type :String, documentInfo :MDSRemoteStorageCache.DocumentInfo) {
			// Store
			self.type = type
			self.active = documentInfo.active
			self.creationDate = documentInfo.creationDate

			self.modificationDate = documentInfo.modificationDate
			self.revision = documentInfo.revision
			self.propertyMap = documentInfo.propertyMap
		}
	}

	struct DocumentUpdateInfo {

		// MARK: Properties
		let	documentUpdateInfo :MDSDocumentUpdateInfo
		let	documentBacking :DocumentBacking

		// MARK: Lifecycle methods
		init(_ documentUpdateInfo :MDSDocumentUpdateInfo, _ documentBacking :DocumentBacking) {
			// Store
			self.documentUpdateInfo = documentUpdateInfo
			self.documentBacking = documentBacking
		}
	}

	typealias DocumentCreationProc = (_ id :String, _ documentStorage :MDSDocumentStorage) -> MDSDocument

	// MARK: Properties
	public	var	id :String = UUID().uuidString

	private	let	httpEndpointClient :HTTPEndpointClient
	private	let	authorization :String?
	private	let	documentStorageID :String
	private	let	remoteStorageCache :MDSRemoteStorageCache
	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<DocumentBacking>>()
	private	let	documentBackingCache = MDSDocumentBackingCache<DocumentBacking>()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, [String : Any]>()

	private	var	documentCreationProcMap = LockingDictionary<String, DocumentCreationProc>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(httpEndpointClient :HTTPEndpointClient, authorization :String? = nil,
			documentStorageID :String = "default", remoteStorageCache :MDSRemoteStorageCache) {
		// Store
		self.httpEndpointClient = httpEndpointClient
		self.authorization = authorization
		self.documentStorageID = documentStorageID
		self.remoteStorageCache = remoteStorageCache
	}

	// MARK: MDSDocumentStorage implementation
	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) -> [String : String] {
		// Preflight
		guard !keys.isEmpty else { return [:] }

		// Retrieve info
		let	(info, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.httpEndpointClient.queue(
								MDSHTTPServices.httpEndpointRequestForGetInfo(documentStorageID: self.documentStorageID,
										authorization: self.authorization, keys: keys)) { completionProc(($1, $2)) }
					}
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
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequewstForSetInfo(
											documentStorageID: self.documentStorageID,
											authorization: self.authorization, info: info)) { completionProc($1) }
					}
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
	public func newDocument<T : MDSDocument>(creationProc :(_ id :String, _ documentStorage :MDSDocumentStorage) -> T)
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

			_ = createDocuments(documentType: T.documentType,
					documentCreateInfos: [MDSDocumentCreateInfo(documentID: documentID, propertyMap: propertyMap)])

			return document
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) -> T? {
		// Retrieve document
		var	document :T?
		iterate(documentIDs: [documentID]) { document = $0 }

		return document
	}

	//------------------------------------------------------------------------------------------------------------------
	public func creationDate(for document :MDSDocument) -> Date {
		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current),
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
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
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
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
				let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
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
	public func date(for property :String, in document :MDSDocument) -> Date? {
		// Return date
		return Date(fromRFC3339Extended: value(for: property, in: document) as? String)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set<T : MDSDocument>(_ value :Any?, for property :String, in document :T) {
		// Transform
		let	valueUse :Any?
		if let date = value as? Date {
			// Date
			valueUse = date.rfc3339Extended
		} else {
			// Everythng else
			valueUse = value
		}

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.set(valueUse, for: property)
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: document)
				batchInfo.addDocument(documentType: documentBacking.type, documentID: document.id,
								reference: documentBacking, creationDate: documentBacking.creationDate,
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
								MDSDocumentUpdateInfo(documentID: document.id, updated: [property : valueUse!]) :
								MDSDocumentUpdateInfo(documentID: document.id, removed: [property])
			updateDocuments(documentType: documentBacking.type,
					documentUpdateInfos: [DocumentUpdateInfo(documentUpdateInfo, documentBacking)])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(_ document :MDSDocument) {
		// Setup
		let	documentType = type(of: document).documentType

		// Check for batch
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			if let batchDocumentInfo = batchInfo.batchDocumentInfo(for: document.id) {
				// Have document in batch
				batchDocumentInfo.remove()
			} else {
				// Don't have document in batch
				let	documentBacking = self.documentBacking(for: document)
				batchInfo.addDocument(documentType: documentType, documentID: document.id, reference: documentBacking,
						creationDate: documentBacking.creationDate, modificationDate: documentBacking.modificationDate)
						.remove()
			}
		} else {
			// Not in batch
			let	documentBacking = self.documentBacking(for: document)
			updateDocuments(documentType: documentBacking.type,
					documentUpdateInfos:
							[DocumentUpdateInfo(MDSDocumentUpdateInfo(documentID: document.id, active: false),
									documentBacking)])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Setup
		let	documentType = T.documentType
		let	lastRevisionKey = "\(documentType)-lastRevision"
		var	lastRevision = self.remoteStorageCache.int(for: lastRevisionKey) ?? 0

		// May need to try this more than once
		while true {
			// Query collection document count
			let	(isComplete, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForGetDocuments(
											documentStorageID: self.documentStorageID, authorization: self.authorization,
											type: documentType, sinceRevision: lastRevision),
											processingProc: { self.updateDocuments(for: documentType, with: $0) },
											completionProc: { (isComplete :Bool?, error :Error?) in
												// Call completion proc
												completionProc((isComplete, error))
											})
						}

			// Handle results
			if isComplete! {
				// Done
				break
			} else {
				// Error
				self.recentErrors.append(error!)

				return
			}
		}

		// Retrieve documentInfos
		let	documentInfos = self.remoteStorageCache.activeDocumentInfos(for: documentType)

		// Iterate documents
		var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
		documentInfos.forEach() {
			// Update revision
			lastRevision = max(lastRevision, $0.revision)

			// Append document backing info
			documentBackingInfos.append(
					MDSDocumentBackingInfo<DocumentBacking>(documentID: $0.id,
							documentBacking: DocumentBacking(type: documentType, documentInfo: $0)))
		}

		// Update cache
		self.documentBackingCache.add(documentBackingInfos)

		// Update last revision
		self.remoteStorageCache.set(lastRevision, for: lastRevisionKey)

		// Iterate document infos, again
		documentInfos.forEach() { proc(T(id: $0.id, documentStorage: self)) }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(documentIDs :[String], proc :(_ document : T) -> Void) {
		// Check for batch
		var	documentIDsToRetrieve = [String]()
		if let batchInfo = self.batchInfoMap.value(for: Thread.current) {
			// In batch
			documentIDs.forEach() {
				// Check if have in batch
				if batchInfo.batchDocumentInfo(for: $0) != nil {
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
		retrieveDocuments(for: documentIDsToRetrieve, documentType: T.documentType)
				.forEach() { proc(T(id: $0.documentID, documentStorage: self)) }
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
			batchInfo.forEach() { documentType, batchDocumentInfosMap in
				// Collect changes
				var	documentCreateInfos = [MDSDocumentCreateInfo]()
				var	documentUpdateInfos = [DocumentUpdateInfo]()

				// Iterate document info for this document type
				batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
					// Check if have pre-existing document
					if let documentBacking = batchDocumentInfo.reference {
						// Update documnet
						let	documentUpdateInfo =
									MDSDocumentUpdateInfo(documentID: documentID,
											updated: batchDocumentInfo.updatedPropertyMap,
											removed: batchDocumentInfo.removedProperties,
											active: !batchDocumentInfo.removed)
						documentUpdateInfos.append(DocumentUpdateInfo(documentUpdateInfo, documentBacking))
					} else {
						// Create document
						documentCreateInfos.append(
								MDSDocumentCreateInfo(documentID: documentID,
										creationDate: batchDocumentInfo.creationDate,
										modificationDate: batchDocumentInfo.modificationDate,
										propertyMap: batchDocumentInfo.updatedPropertyMap ?? [:]))
					}
				}

				// Update storage
				self.createDocuments(documentType: documentType, documentCreateInfos: documentCreateInfos)
				self.updateDocuments(documentType: documentType, documentUpdateInfos: documentUpdateInfos)
			}
		}

		// Remove
		self.batchInfoMap.set(nil, for: Thread.current)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
			isIncludedProc :@escaping (_ document :T) -> Bool) {
		// Register collection
		let	(_, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.httpEndpointClient.queue(
								MDSHTTPServices.httpEndpointRequestForRegisterCollection(
										documentStorageID: self.documentStorageID, authorization: self.authorization,
										documentType: T.documentType, name: name, version: version,
										relevantProperties: relevantProperties, isUpToDate: isUpToDate,
										isIncludedSelector: isIncludedSelector,
										isIncludedSelectorInfo: isIncludedSelectorInfo)) { completionProc(($1, $2)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Make sure collection is up to date
		_ = queryCollectionDocumentCount(name: name)

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func queryCollectionDocumentCount(name :String) -> UInt {
		// May need to try this more than once
		while true {
			// Query collection document count
			let	(isUpToDate, count, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForGetCollectionDocumentCount(
											documentStorageID: self.documentStorageID,
											authorization: self.authorization, name: name))
											{ (isUpToDate :Bool?, count :Int?, error :Error?) in
												// Call completion proc
												completionProc((isUpToDate, count, error))
											}
						}

			// Handle results
			if (isUpToDate != nil) && !isUpToDate! {
				// Not up to date
				continue
			} else if count != nil {
				// Success
				return UInt(count!)
			} else {
				// Error
				self.recentErrors.append(error!)

				return 0
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// May need to try this more than once
		var	startIndex = 0
		while true {
			// Retrieve document revision infos
			let	(isUpToDate, documentRevisionInfos, isComplete, error)  =
						DispatchQueue.performBlocking() { completionProc in
							// Queue
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForGetCollectionDocumentInfos(
											documentStorageID: self.documentStorageID,
											authorization: self.authorization, name: name, startIndex: startIndex))
									{ (isUpToDate :Bool?, documentRevisionInfos :[MDSDocumentRevisionInfo]?,
											isComplete :Bool?, error :Error?) in
										// Call completion proc
										completionProc((isUpToDate, documentRevisionInfos, isComplete, error))
									}
						}

			// Handle results
			if (isUpToDate != nil) && !isUpToDate! {
				// Not up to date
				continue
			} else if documentRevisionInfos != nil {
				// Success
				documents(for: documentRevisionInfos!, creationProc: { T(id: $0, documentStorage: $1) })
					.forEach({ proc($0) })

				// Update
				startIndex += documentRevisionInfos!.count

				// Check if is complete
				if isComplete! {
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
	public func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any],
			keysProc :@escaping (_ document :T) -> [String]) {
		// Register index
		let	(_, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.httpEndpointClient.queue(
								MDSHTTPServices.httpEndpointRequestForRegisterIndex(
										documentStorageID: self.documentStorageID, authorization: self.authorization,
										documentType: T.documentType, name: name, version: version,
										relevantProperties: relevantProperties, isUpToDate: isUpToDate,
										keysSelector: keysSelector, keysSelectorInfo: keysSelectorInfo))
										{ completionProc(($1, $2)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Make sure index is up to date
		iterateIndex(name: name, keys: []) { (key :String, t :T) in }

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateIndex<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
//		// May need to try this more than once
//		var	documentInfosMap = [String : Any]()
//		while true {
//			// Get document infos
//// TODO: Can be multiple requests
// Technically needs to support multiple responses if requested keys causes to be mulitple calls.
// BUT***
//	If the index is out of date AND there are multiple calls, it is possible for the index to become up to date during
//		2nd or subsequent calls ultimately leading to partial results.  Need to figure how to handle so as to not be
//		ambiguous.

// So, must send only 1 key until it is known that it is up to date.  Then can send all the rest of the keys.

//			let	(_documentInfosMap, error) =
//						DispatchQueue.performBlocking() { completionProc in
//							// Call network client
//							self.httpEndpointClient.queue(
//									MDSHTTPServices.httpEndpointRequestForGetIndexDocumentInfos(
//											documentStorageID: self.documentStorageID, name: name, keys: keys))
//									{ completionProc(($0, $1)) }
//						}
//			if _documentInfosMap != nil {
//				// Success
//				documentInfosMap = _documentInfosMap!
//				break
//			} else if let nsError = error as NSError?, nsError.domain == "LightIronNetworkClient", nsError.code == 409 {
//				// Collection is not up to date
//				updateIndex(named: name)
//			} else {
//				// Error
//				self.recentErrors.append(error!)
//
//				return
//			}
//		}
//
//		// Map keys to document IDs - Note that there may be some keys that map to the same document
//		var	keysToDocumentIDsMap = [String : String]()
//		var	documentInfos = [[String : Any]]()
//		var	documentIDsProcessed = Set<String>()
//		documentInfosMap.forEach() {
//			// Check if we have document info for this key
//			if let info = $0.value as? [String : Any] {
//				// We have document info for this key
//				let	documentID = info["documentID"] as! String
//
//				// Update
//				keysToDocumentIDsMap[$0.key] = (info["documentID"] as! String)
//				if !documentIDsProcessed.contains(documentID) {
//					// Append this info
//					documentInfos.append(info)
//					documentIDsProcessed.insert(documentID)
//				}
//			}
//		}
//
//		// Iterate documents
//		let	documents :[T] =
//					self.documents(for: documentInfos,
//							creationProc: self.documentCreationProcMap.value(for: T.documentType)!)
//		let	documentsMap = Dictionary(documents.map({ ($0.id, $0) }))
//		keysToDocumentIDsMap.forEach() { proc($0.key, documentsMap[$0.value]!) }
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerDocumentChangedProc(documentType :String,
			proc :@escaping (_ document :MDSDocument, _ documentChangeKind :MDSDocumentChangeKind) -> Void) {
		// Unimplemented
		fatalError("Unimplemented")
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func documentBacking(for document :MDSDocument) -> DocumentBacking {
		// Check if in cache
		if let documentBacking = self.documentBackingCache.documentBacking(for: document.id) {
			// Have in cache
			return documentBacking
		} else {
			// Must retrieve from server
			return retrieveDocuments(for: [document.id], documentType: type(of: document).documentType).first!
					.documentBacking
		}
	}

//	//------------------------------------------------------------------------------------------------------------------
//	private func documents<T :MDSDocument>(for infos :[[String : Any]], creationProc :DocumentCreationProc) -> [T] {
//		// Setup
//		let	documentType = T.documentType
//
//		var	documents = [T]()
//
//		// Iterate all infos
//		var	documentReferences = [MDSRemoteStorageCache.DocumentReference]()
//		infos.forEach() {
//			// Get info
//			let	documentID = $0["documentID"] as! String
//			let	revision = $0["revision"] as! Int
//
//			// Check if have in cache and is most recent
//			if let documentBacking = self.documentBackingCache.documentBacking(for: documentID),
//					documentBacking.revision == revision {
//				// Use from property storables cache
//				documents.append(creationProc(documentID, self) as! T)
//			} else {
//				// Must retrieve elsewhere
//				documentReferences.append(MDSRemoteStorageCache.DocumentReference(id: documentID, revision: revision))
//			}
//		}
//
//		// Retrieve from disk cache
//		let	(documentInfos, documentReferencesNotResolved) =
//					self.remoteStorageCache.documentInfos(for: documentType, with: documentReferences)
//		if !documentInfos.isEmpty {
//			// Iterate all document infos
//			var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
//			documentInfos.forEach() {
//				// Update document backing infos
//				documentBackingInfos.append(
//						MDSDocumentBackingInfo<MDSRemoteStorage.DocumentBacking>(documentID: $0.id,
//								documentBacking:
//										MDSRemoteStorage.DocumentBacking(type: documentType,
//												creationDate: $0.creationDate, active: $0.active,
//												modificationDate: $0.modificationDate, revision: $0.revision,
//												json: $0.propertyMap)))
//			}
//
//			// Update cache
//			self.documentBackingCache.add(documentBackingInfos)
//
//			// Create property storables
//			documentInfos.forEach() { documents.append(creationProc($0.id, self) as! T) }
//		}
//
//		// Check if have documents to retrieve
//		if !documentReferencesNotResolved.isEmpty {
//			// Retrieve from server
//			retrieveDocuments(for: documentReferencesNotResolved.map({ $0.id }), documentType: documentType)
//
//			// Create property storables
//			documentReferencesNotResolved.forEach() { documents.append(creationProc($0.id, self) as! T) }
//		}
//
//		return documents
//	}

	//------------------------------------------------------------------------------------------------------------------
	private func documents<T :MDSDocument>(for activeDocumentRevisionInfos :[MDSDocumentRevisionInfo],
			creationProc :DocumentCreationProc) -> [T] {
/*
	Need to take DRIs and update stuffs - which may require additional calls to the server to retrieve the doc contents

*/
		// Setup
		let	documentType = T.documentType

		var	documents = [T]()

		// Iterate all infos
		var	documentReferencesPossiblyInCache = [MDSRemoteStorageCache.DocumentReference]()
		var	documentReferencesToRetrieve = [MDSRemoteStorageCache.DocumentReference]()
		activeDocumentRevisionInfos.forEach() {
			// Check if have in cache and is most recent
			if let documentBacking = self.documentBackingCache.documentBacking(for: $0.documentID) {
				// Check revision
				if documentBacking.revision == $0.revision {
					// Use from property storables cache
					documents.append(creationProc($0.documentID, self) as! T)
				} else {
					// Must retrieve
					documentReferencesToRetrieve.append(
							MDSRemoteStorageCache.DocumentReference(id: $0.documentID, revision: $0.revision))
				}
			} else {
				// Check cache
				documentReferencesPossiblyInCache.append(
						MDSRemoteStorageCache.DocumentReference(id: $0.documentID, revision: $0.revision))
			}
		}

		// Retrieve from disk cache
		let	(documentInfos, documentReferencesNotResolved) =
					self.remoteStorageCache.documentInfos(for: documentType, with: documentReferencesPossiblyInCache)
		if !documentInfos.isEmpty {
			// Iterate all document infos
			var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
			documentInfos.forEach() {
				// Update document backing infos
				documentBackingInfos.append(
						MDSDocumentBackingInfo<MDSRemoteStorage.DocumentBacking>(documentID: $0.id,
								documentBacking:
										MDSRemoteStorage.DocumentBacking(type: documentType, revision: $0.revision,
												active: $0.active, creationDate: $0.creationDate,
												modificationDate: $0.modificationDate, propertyMap: $0.propertyMap)))
			}

			// Update cache
			self.documentBackingCache.add(documentBackingInfos)

			// Create property storables
			documentInfos.forEach() { documents.append(creationProc($0.id, self) as! T) }
		}

		// Check if have documents to retrieve
		documentReferencesToRetrieve += documentReferencesNotResolved
		if !documentReferencesToRetrieve.isEmpty {
			// Retrieve from server
			retrieveDocuments(for: documentReferencesToRetrieve.map({ $0.id }), documentType: documentType)

			// Create property storables
			documentReferencesToRetrieve
					.map({ ($0.id, self.documentBackingCache.documentBacking(for: $0.id)!) })
					.forEach() { documents.append(creationProc($0.0, self) as! T) }
		}

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateDocuments(for documentType :String, with documentRevisionInfos :[MDSDocumentRevisionInfo]) {
		// Iterate all infos
		var	documentReferences = [MDSRemoteStorageCache.DocumentReference]()
		documentRevisionInfos.forEach() {
			// Check if have in cache and is most recent
			let	documentBacking = self.documentBackingCache.documentBacking(for: $0.documentID)
			if (documentBacking == nil) || (documentBacking!.revision != $0.revision) {
				// Must retrieve elsewhere
				documentReferences.append(
						MDSRemoteStorageCache.DocumentReference(id: $0.documentID, revision: $0.revision))
			}
		}

		// Retrieve from disk cache
		let	(documentInfos, documentReferencesNotResolved) =
					self.remoteStorageCache.documentInfos(for: documentType, with: documentReferences)
		if !documentInfos.isEmpty {
			// Iterate all document infos
			var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
			documentInfos.forEach() {
				// Update document backing infos
				documentBackingInfos.append(
						MDSDocumentBackingInfo<MDSRemoteStorage.DocumentBacking>(documentID: $0.id,
								documentBacking:
										MDSRemoteStorage.DocumentBacking(type: documentType, revision: $0.revision,
												active: $0.active, creationDate: $0.creationDate,
												modificationDate: $0.modificationDate, propertyMap: $0.propertyMap)))
			}

			// Update cache
			self.documentBackingCache.add(documentBackingInfos)
		}

		// Check if have documents to retrieve
		if !documentReferencesNotResolved.isEmpty {
			// Retrieve from server
			retrieveDocuments(for: documentReferencesNotResolved.map({ $0.id }), documentType: documentType)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateDocuments(for documentType :String, with documentFullInfos :[MDSDocumentFullInfo]) {
		// Update document backing cache
		let	documentBackingInfos =
					documentFullInfos.map() {
						MDSDocumentBackingInfo<DocumentBacking>(documentID: $0.documentID,
								documentBacking:
										DocumentBacking(type: documentType, revision: $0.revision,
												active: $0.active, creationDate: $0.creationDate,
												modificationDate: $0.modificationDate, propertyMap: $0.propertyMap))
					}
		self.documentBackingCache.add(documentBackingInfos)

		// Update remote storage cache
		let	documentInfos =
					documentFullInfos.map() {
						MDSRemoteStorageCache.DocumentInfo(id: $0.documentID, revision: $0.revision,
								active: $0.active, creationDate: $0.creationDate,
								modificationDate: $0.modificationDate, propertyMap: $0.propertyMap)
					}
		self.remoteStorageCache.add(documentInfos, for: documentType)
	}

//	//------------------------------------------------------------------------------------------------------------------
//	private func updateCollection(named name :String, documentLastRevision :Int? = nil,
//			collectionLastDocumentRevision :Int? = nil) {
//		// Setup
//		var	documentLastRevisionUse = documentLastRevision
//		var	collectionLastDocumentRevisionUse = collectionLastDocumentRevision
//
//		// Repeat until up to date
//		while (documentLastRevisionUse == nil) || (collectionLastDocumentRevisionUse == nil) ||
//				(documentLastRevisionUse! != collectionLastDocumentRevisionUse!) {
//			// Update collection
//			let	(info, error) =
//						DispatchQueue.performBlocking() { completionProc in
//							// Call network client
//							self.httpEndpointClient.queue(
//									MDSHTTPServices.httpEndpointRequestForUpdateCollection(
//											documentStorageID: self.documentStorageID, name: name, documentCount: 100))
//									{ completionProc(($0, $1)) }
//						}
//			guard error == nil else {
//				// Store error
//				self.recentErrors.append(error!)
//
//				return
//			}
//
//			// Update info
//			documentLastRevisionUse = (info!["documentLastRevision"] as! Int)
//			collectionLastDocumentRevisionUse = (info!["collectionLastDocumentRevision"] as! Int)
//		}
//		fatalError("Unimplemented")
//	}

//	//------------------------------------------------------------------------------------------------------------------
//	private func updateIndex(named name :String, documentLastRevision :Int? = nil,
//			indexLastDocumentRevision :Int? = nil) {
//		// Setup
//		var	documentLastRevisionUse = documentLastRevision
//		var	indexLastDocumentRevisionUse = indexLastDocumentRevision
//
//		// Repeat until up to date
//		while (documentLastRevisionUse == nil) || (indexLastDocumentRevisionUse == nil) ||
//				(documentLastRevisionUse! != indexLastDocumentRevisionUse!) {
//			// Update index
//			let	(info, error) =
//						DispatchQueue.performBlocking() { completionProc in
//							// Call network client
//							self.httpEndpointClient.queue(
//									MDSHTTPServices.httpEndpointRequestForUpdateIndex(
//											documentStorageID: self.documentStorageID, name: name, documentCount: 100))
//									{ completionProc(($0, $1)) }
//						}
//			guard error == nil else {
//				// Store error
//				self.recentErrors.append(error!)
//
//				return
//			}
//
//			// Update info
//			documentLastRevisionUse = (info!["documentLastRevision"] as! Int)
//			indexLastDocumentRevisionUse = (info!["indexLastDocumentRevision"] as! Int)
//		}
//		fatalError("Unimplemented")
//	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func createDocuments(documentType :String, documentCreateInfos :[MDSDocumentCreateInfo]) -> [String] {
//		// Preflight
//		guard !documentCreateInfos.isEmpty else { return [] }
//
//		// Create documents
//// TODO: Can be multiple requests
//		let	(returnInfos, error) =
//					DispatchQueue.performBlocking() { completionProc in
//						// Call network client
//						self.httpEndpointClient.queue(
//								MDSHTTPServices.httpEndpointRequestForCreateDocuments(
//										documentStorageID: self.documentStorageID, type: documentType,
//												documentCreateInfos: documentCreateInfos))
//								{ completionProc(($0, $1)) }
//					}
//		guard error == nil else {
//			// Store error
//			self.recentErrors.append(error!)
//
//			return []
//		}
//
//		// Update caches
//		var	documentIDs = [String]()
//		var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
//		var	documentInfos = [MDSRemoteStorageCache.DocumentInfo]()
//		returnInfos!.enumerated().forEach() {
//			// Get info
//			let	documentID = $0.element["documentID"] as! String
//			let	creationDate = Date(fromRFC3339Extended: ($0.element["creationDate"] as! String))!
//			let	modificationDate = Date(fromRFC3339Extended: ($0.element["modificationDate"] as! String))!
//			let	revision = $0.element["revision"] as! Int
//			let	json = documentCreateInfos[$0.offset].propertyMap
//
//			// Add to arrays
//			documentIDs.append(documentID)
//			documentBackingInfos.append(
//					MDSDocumentBackingInfo<DocumentBacking>(documentID: documentID,
//							documentBacking:
//									DocumentBacking(type: documentType, creationDate: creationDate, active: true,
//											modificationDate: modificationDate, revision: revision, json: json)))
//			documentInfos.append(
//					MDSRemoteStorageCache.DocumentInfo(id: documentID, revision: revision, active: true,
//							creationDate: creationDate, modificationDate: modificationDate, propertyMap: json))
//		}
//		self.documentBackingCache.add(documentBackingInfos)
//		self.remoteStorageCache.add(documentInfos, for: documentType)
//
//		return documentIDs
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func retrieveDocuments(for ids :[String], documentType :String) ->
			[MDSDocumentBackingInfo<DocumentBacking>] {
		// Preflight
		guard !ids.isEmpty else { return [] }

		// Retrieve document infos
		var	documentFullInfos = [MDSDocumentFullInfo]()
		let	errors =
					DispatchQueue.performBlocking() { (completionProc :@escaping(_ errors :[Error]) -> Void) in
						// Queue
						self.httpEndpointClient.queue(
								MDSHTTPServices.httpEndpointRequestForGetDocuments(
										documentStorageID: self.documentStorageID, authorization: self.authorization,
										type: documentType, documentIDs: ids),
								partialResultsProc: { documentFullInfos += $0 ?? []; _ = $1 },
								completionProc: { completionProc($0) })
					}
		guard errors.isEmpty else {
			// Store errors
			self.recentErrors += errors

			return []
		}

		// Update caches
		var	documentBackings = [DocumentBacking]()
		var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
		var	documentInfos = [MDSRemoteStorageCache.DocumentInfo]()
		documentFullInfos.forEach() {
			// Get info
			let	documentBacking =
						DocumentBacking(type: documentType, revision: $0.revision, active: $0.active,
								creationDate: $0.creationDate, modificationDate: $0.modificationDate,
								propertyMap: $0.propertyMap)
			documentBackings.append(documentBacking)
			documentBackingInfos.append(
					MDSDocumentBackingInfo<DocumentBacking>(documentID: $0.documentID,
							documentBacking: documentBacking))
			documentInfos.append(
					MDSRemoteStorageCache.DocumentInfo(id: $0.documentID, revision: $0.revision, active: $0.active,
							creationDate: $0.creationDate, modificationDate: $0.modificationDate,
							propertyMap: $0.propertyMap))
		}
		self.documentBackingCache.add(documentBackingInfos)
		self.remoteStorageCache.add(documentInfos, for: documentType)

		return documentBackingInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateDocuments(documentType :String, documentUpdateInfos :[DocumentUpdateInfo]) {
//		// Preflight
//		guard !documentUpdateInfos.isEmpty else { return }
//
//		// Update documents
//// TODO: Can be multiple requests
//		let	(returnInfos, error) =
//					DispatchQueue.performBlocking() { completionProc in
//						// Call network client
//						self.httpEndpointClient.queue(
//								MDSHTTPServices.httpEndpointRequestForUpdateDocuments(
//										documentStorageID: self.documentStorageID, type: documentType,
//										documentUpdateInfos: documentUpdateInfos.map({ $0.documentUpdateInfo })))
//								{ completionProc(($0, $1)) }
//					}
//		guard error == nil else {
//			// Store error
//			self.recentErrors.append(error!)
//
//			return
//		}
//
//		// Update caches
//		var	updatedDocumentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
//		var	updatedDocumentInfos = [MDSRemoteStorageCache.DocumentInfo]()
//		returnInfos!.enumerated().forEach() {
//			// Get info
//			var	documentBacking = documentUpdateInfos[$0.offset].documentBacking
//
//			let	documentID = documentUpdateInfos[$0.offset].documentUpdateInfo.documentID
//			let	creationDate = documentBacking.creationDate
//			let	modificationDate = Date(fromRFC3339Extended: $0.element["modificationDate"] as? String)!
//			let	revision = $0.element["revision"] as! Int
//			let	active = ($0.element["active"] as! Int) == 1
//			let	json = $0.element["json"] as! [String : Any]
//
//			// Update
//			documentBacking.modificationDate = modificationDate
//			documentBacking.revision = revision
//			documentBacking.json = json
//
//			// Add to array
//			updatedDocumentBackingInfos.append(
//				MDSDocumentBackingInfo<DocumentBacking>(documentID: documentID, documentBacking: documentBacking))
//			updatedDocumentInfos.append(
//					MDSRemoteStorageCache.DocumentInfo(id: documentID, revision: revision, active: active,
//							creationDate: creationDate, modificationDate: modificationDate, propertyMap: json))
//		}
//		self.documentBackingCache.add(updatedDocumentBackingInfos)
//		self.remoteStorageCache.add(updatedDocumentInfos, for: documentType)
		fatalError("Unimplemented")
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
