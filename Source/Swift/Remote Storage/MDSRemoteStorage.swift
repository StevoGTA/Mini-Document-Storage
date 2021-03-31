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

		init(type :String, documentFullInfo :MDSDocumentFullInfo) {
			// Store
			self.type = type
			self.active = documentFullInfo.active
			self.creationDate = documentFullInfo.creationDate

			self.modificationDate = documentFullInfo.modificationDate
			self.revision = documentFullInfo.revision
			self.propertyMap = documentFullInfo.propertyMap
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
										keys: keys, authorization: self.authorization)) { completionProc(($1, $2)) }
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
											info: info, authorization: self.authorization)) { completionProc($1) }
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

			createDocuments(documentType: T.documentType,
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
			if let batchDocumentInfo = batchInfo.documentInfo(for: document.id) {
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
											documentStorageID: self.documentStorageID, type: documentType,
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
		retrieveDocuments(for: documentIDsToRetrieve, documentType: T.documentType)
				{ proc(T(id: $0.documentID, documentStorage: self)) }
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
											active: !batchDocumentInfo.removed,
											updated: batchDocumentInfo.updatedPropertyMap ?? [:],
											removed: batchDocumentInfo.removedProperties ?? Set<String>())
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
	public func registerCollection<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
			isIncludedProc :@escaping (_ document :T) -> Bool) {
		// Register collection
		let	(_, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.httpEndpointClient.queue(
								MDSHTTPServices.httpEndpointRequestForRegisterCollection(
										documentStorageID: self.documentStorageID, documentType: T.documentType,
										name: name, version: version, relevantProperties: relevantProperties,
										isUpToDate: isUpToDate, isIncludedSelector: isIncludedSelector,
										isIncludedSelectorInfo: isIncludedSelectorInfo,
										authorization: self.authorization)) { completionProc(($1, $2)) }
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
	public func queryCollectionDocumentCount(name :String) -> Int {
		// May need to try this more than once
		while true {
			// Query collection document count
			let	(isUpToDate, count, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForGetCollectionDocumentCount(
											documentStorageID: self.documentStorageID, name: name,
											authorization: self.authorization))
											{ (isUpToDate :Bool?, count :Int?, error :Error?) in
												// Call completion proc
												completionProc((isUpToDate, count, error))
											}
						}

			// Handle results
			if !(isUpToDate ?? true) {
				// Not up to date
				continue
			} else if count != nil {
				// Success
				return count!
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
			// Retrieve info
			let	(isUpToDate, documentRevisionInfos, isComplete, error)  =
						DispatchQueue.performBlocking() { completionProc in
							// Queue
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForGetCollectionDocumentInfos(
											documentStorageID: self.documentStorageID, name: name,
											startIndex: startIndex, authorization: self.authorization))
									{ (isUpToDate :Bool?, documentRevisionInfos :[MDSDocumentRevisionInfo]?,
											isComplete :Bool?, error :Error?) in
										// Call completion proc
										completionProc((isUpToDate, documentRevisionInfos, isComplete, error))
									}
						}

			// Handle results
			if !(isUpToDate ?? true) {
				// Not up to date
				continue
			} else if documentRevisionInfos != nil {
				// Success
				iterateDocumentIDs(documentType: T.documentType, activeDocumentRevisionInfos: documentRevisionInfos!)
					{ proc(T(id: $0, documentStorage: self)) }

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
	public func registerIndex<T : MDSDocument>(named name :String, version :Int, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any],
			keysProc :@escaping (_ document :T) -> [String]) {
		// Register index
		let	(_, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.httpEndpointClient.queue(
								MDSHTTPServices.httpEndpointRequestForRegisterIndex(
										documentStorageID: self.documentStorageID, documentType: T.documentType,
										name: name, version: version, relevantProperties: relevantProperties,
										isUpToDate: isUpToDate, keysSelector: keysSelector,
										keysSelectorInfo: keysSelectorInfo, authorization: self.authorization))
										{ completionProc(($1, $2)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Make sure index is up to date
		iterateIndex(name: name, keys: [" "]) { (key :String, t :T) in }

		// Update creation proc map
		self.documentCreationProcMap.set({ T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateIndex<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
		// Setup
		var	keysUse = keys.filter({ !$0.isEmpty })

		// Preflight
		guard !keysUse.isEmpty else { return }

		// Process first key to ensure index is up to date
		let	firstKey = keysUse.removeFirst()
		while true {
			// Retrieve info
			let	(isUpToDate, documentRevisionInfoMap, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.httpEndpointClient.queue(
									MDSHTTPServices.httpEndpointRequestForGetIndexDocumentInfos(
											documentStorageID: self.documentStorageID, name: name, keys: [firstKey],
											authorization: self.authorization),
									partialResultsProc: { (isUpToDate :Bool?,
											documentRevisionInfoMap :[String : MDSDocumentRevisionInfo]?,
											error :Error?) in
										// Call completion
										completionProc((isUpToDate, documentRevisionInfoMap, error))
									}, completionProc: { _ in })
						}

			// Handle results
			if !(isUpToDate ?? true) {
				// Not up to date
				continue
			} else if documentRevisionInfoMap != nil {
				// Success
				if !documentRevisionInfoMap!.isEmpty {
					// Process results
					iterateDocumentIDs(documentType: T.documentType,
							activeDocumentRevisionInfos: [documentRevisionInfoMap!.first!.value])
							{ proc(firstKey, T(id: $0, documentStorage: self)) }
				}

				break
			} else {
				// Error
				self.recentErrors.append(error!)

				return
			}
		}

		// Check if have more keys
		if !keysUse.isEmpty {
			// Retrieve the rest of the info
			let	documentRevisionInfoMap = LockingDictionary<String, MDSDocumentRevisionInfo>()
			let	semaphore = DispatchSemaphore(value: 0)
			var	allDone = false

			// Queue info retrieval
			self.httpEndpointClient.queue(
					MDSHTTPServices.httpEndpointRequestForGetIndexDocumentInfos(
							documentStorageID: self.documentStorageID, name: name, keys: keysUse,
							authorization: self.authorization),
					partialResultsProc: {
						// Handle results
						if $1 != nil {
							// Add to dictionary
							documentRevisionInfoMap.merge($1!)

							// Signal
							semaphore.signal()
						}

						// Ignore error (will collect below)
						_ = $2
					}, completionProc: {
						// Add errors
						self.recentErrors += $0

						// All done
						allDone = true

						// Signal
						semaphore.signal()
					})

			// Process results
			while !allDone || !documentRevisionInfoMap.isEmpty {
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
					let	map = Dictionary(documentRevisionInfoMapToProcess.map({ ($0.value.documentID, $0.key )}))
					self.iterateDocumentIDs(documentType: T.documentType,
							activeDocumentRevisionInfos: Array(documentRevisionInfoMapToProcess.values))
							{ proc(map[$0]!, T(id: $0, documentStorage: self)) }
				}
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerDocumentChangedProc(documentType :String,
			proc :@escaping (_ document :MDSDocument, _ documentChangeKind :MDSDocumentChangeKind) -> Void) {
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
	private func iterateDocumentIDs(documentType :String, activeDocumentRevisionInfos :[MDSDocumentRevisionInfo],
			proc :(_ documentID :String) -> Void) {
		// Preflight
		guard !activeDocumentRevisionInfos.isEmpty else { return }
		
		// Iterate all infos
		var	documentRevisionInfosPossiblyInCache = [MDSDocumentRevisionInfo]()
		var	documentRevisionInfosToRetrieve = [MDSDocumentRevisionInfo]()
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
		updateDocumentBackingCache(for: documentType, with: documentFullInfos)
				.forEach() { proc($0.documentID) }

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
	@discardableResult
	private func updateCaches(for documentType :String, with documentFullInfos :[MDSDocumentFullInfo])
			-> [MDSDocumentBackingInfo<DocumentBacking>] {
		// Update document backing cache
		let	documentBackingInfos = updateDocumentBackingCache(for: documentType, with: documentFullInfos)

		// Update remote storage cache
		self.remoteStorageCache.add(documentFullInfos, for: documentType)

		return documentBackingInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func updateDocumentBackingCache(for documentType :String, with documentFullInfos :[MDSDocumentFullInfo])
			-> [MDSDocumentBackingInfo<DocumentBacking>] {
		// Preflight
		guard !documentFullInfos.isEmpty else { return [] }

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

		return documentBackingInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	private func createDocuments(documentType :String, documentCreateInfos :[MDSDocumentCreateInfo]) {
		// Preflight
		guard !documentCreateInfos.isEmpty else { return }

		// Setup
		let	documentCreateInfosMap = Dictionary(documentCreateInfos.map({ ($0.documentID, $0) }))
		let	documentCreateReturnInfos = LockingArray<MDSDocumentCreateReturnInfo>()
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
									MDSDocumentFullInfo(documentID: $0.documentID, revision: $0.revision, active: true,
											creationDate: $0.creationDate, modificationDate: $0.modificationDate,
											propertyMap: documentCreateInfosMap[$0.documentID]!.propertyMap) })
				updateCaches(for: documentType, with: documentFullInfos)
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func retrieveDocuments(for documentIDs :[String], documentType :String,
			proc :(_ documentBackingInfo :MDSDocumentBackingInfo<DocumentBacking>) -> Void ) {
		// Preflight
		guard !documentIDs.isEmpty else { return }

		// Setup
		let	documentFullInfos = LockingArray<MDSDocumentFullInfo>()
		let	semaphore = DispatchSemaphore(value: 0)
		var	allDone = false

		// Queue document retrieval
		self.httpEndpointClient.queue(
				MDSHTTPServices.httpEndpointRequestForGetDocuments(documentStorageID: self.documentStorageID,
						type: documentType, documentIDs: documentIDs, authorization: self.authorization),
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
	private func updateDocuments(documentType :String, documentUpdateInfos :[DocumentUpdateInfo]) {
		// Preflight
		guard !documentUpdateInfos.isEmpty else { return }

		// Setup
		let	documentUpdateInfosMap = Dictionary(documentUpdateInfos.map({ ($0.documentUpdateInfo.documentID, $0) }))
		let	documentUpdateReturnInfos = LockingArray<MDSDocumentUpdateReturnInfo>()
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
							documentUpdateReturnInfosToProcess.map({
									MDSDocumentFullInfo(documentID: $0.documentID, revision: $0.revision,
											active: $0.active,
											creationDate:
													documentUpdateInfosMap[$0.documentID]!.documentBacking.creationDate,
											modificationDate: $0.modificationDate, propertyMap: $0.propertyMap) })
				updateCaches(for: documentType, with: documentFullInfos)
			}
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
