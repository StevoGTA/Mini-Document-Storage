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
		let	creationDate :Date
		let	active :Bool

		var	modificationDate :Date
		var	revision :Int
		var	json :[String : Any]
	}

	typealias DocumentCreationProc = (_ id :String, _ documentStorage :MDSDocumentStorage) -> MDSDocument

	// MARK: Properties
	public	var	id :String = UUID().uuidString

	private	let	networkClient :MDSRemoteStorageNetworkClient
	private	let	cache :MDSRemoteStorageCache
	private	let	batchInfoMap = LockingDictionary<Thread, MDSBatchInfo<DocumentBacking>>()
	private	let	documentBackingCache = MDSDocumentBackingCache<DocumentBacking>()
	private	let	documentsBeingCreatedPropertyMapMap = LockingDictionary<String, MDSDocument.PropertyMap>()

	private	var	documentCreationProcMap = LockingDictionary<String, DocumentCreationProc>()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(networkClient :MDSRemoteStorageNetworkClient, cache :MDSRemoteStorageCache) {
		// Store
		self.networkClient = networkClient
		self.cache = cache
	}

	// MARK: MDSDocumentStorage implementation
	//------------------------------------------------------------------------------------------------------------------
	public func info(for keys :[String]) -> [String : String] {
		// Preflight
		guard !keys.isEmpty else { return [:] }

		// Perform blocking
		let	(returnInfo, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.networkClient.retrieveInfo(keys: keys) { completionProc(($0, $1)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return [:]
		}

		return returnInfo
	}

	//------------------------------------------------------------------------------------------------------------------
	public func set(_ info :[String : String]) {
		// Preflight
		guard !info.isEmpty else { return }

		// Perform blocking
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.networkClient.updateInfo(info: info) { completionProc($0) }
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

			let	info :[String : Any] = [
										"documentID": documentID,
										"json": propertyMap,
									   ]

			_ = createDocuments(documentType: T.documentType, infos: [info])

			return document
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func document<T : MDSDocument>(for documentID :String) -> T? {
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
			// Not in batch
			return self.documentBacking(for: document).json[property]
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
								valueProc: { return documentBacking.json[$0] })
						.set(valueUse, for: property)
			}
		} else if var propertyMap = self.documentsBeingCreatedPropertyMapMap.value(for: document.id) {
			// Creating
			propertyMap[property] = valueUse
			self.documentsBeingCreatedPropertyMapMap.set(propertyMap, for: document.id)
		} else {
			// Not in batch and not creating
			let	documentBacking = self.documentBacking(for: document)

			// Check for value
			if valueUse != nil {
				// Have value
				updateDocuments(documentType: documentBacking.type,
						documentInfos: [(document.id, documentBacking, [property : valueUse!], [], true)])
			} else {
				// No value
				updateDocuments(documentType: documentBacking.type,
						documentInfos: [(document.id, documentBacking, [:], [property], true)])
			}
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
			updateDocuments(documentType: documentType,
					documentInfos:
							[(document.id, documentBacking, updatedPropertyMap: [:], removedKeys: [], active: false)])
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterate<T : MDSDocument>(proc :(_ document : T) -> Void) {
		// Perform blocking
		let	(infos, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.networkClient.retrieveDocuments(documentType: T.documentType, sinceRevision: 0)
								{ completionProc(($0, $1)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Iterate documents
		documents(for: infos!, creationProc: { T(id: $0, documentStorage: $1) }).forEach({ proc($0) })
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

		// Do we have any ids to retrieve
		if !documentIDsToRetrieve.isEmpty {
			// Perform blocking
			let	(infos, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.networkClient.retrieveDocuments(documentType: T.documentType,
									documentIDs: documentIDsToRetrieve) { completionProc(($0, $1)) }
						}
			guard error == nil else {
				// Store error
				self.recentErrors.append(error!)

				return
			}

			// Call proc
			self.documents(for: infos!, creationProc: { T(id: $0, documentStorage: $1) }).forEach({ proc($0) })
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
			batchInfo.forEach() { documentType, batchDocumentInfosMap in
				// Collect changes
				var	createdInfos = [[String : Any]]()
				var	updatedInfos =
							[(documentID :String, documentBacking :DocumentBacking, updatedPropertyMap :[String : Any],
									removedKeys :[String], active :Bool)]()

				// Iterate document info for this document type
				batchDocumentInfosMap.forEach() { documentID, batchDocumentInfo in
					// Check if have pre-existing document
					if let documentBacking = batchDocumentInfo.reference {
						// Update documnet
						updatedInfos.append(
								(documentID, documentBacking, batchDocumentInfo.updatedPropertyMap ?? [:],
										Array(batchDocumentInfo.removedProperties ?? Set<String>()),
										!batchDocumentInfo.removed))
					} else {
						// Create document
						createdInfos.append(
								[
									"documentID": documentID,
									"creationDate": batchDocumentInfo.creationDate.rfc3339Extended,
									"modificationDate": batchDocumentInfo.modificationDate.rfc3339Extended,
									"json": batchDocumentInfo.updatedPropertyMap ?? [:],
								])
					}
				}

				// Update storage
				self.createDocuments(documentType: documentType, infos: createdInfos)
				self.updateDocuments(documentType: documentType, documentInfos: updatedInfos)
			}
		}

		// Remove
		self.batchInfoMap.set(nil, for: Thread.current)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerCollection<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			info :[String : Any], isUpToDate :Bool, isIncludedSelector :String,
			isIncludedProc :@escaping (_ document :T, _ info :[String : Any]) -> Bool) {
		// Perform blocking
		let	(resultInfo, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.networkClient.registerCollection(name: name, documentType: T.documentType,
								version: version, relevantProperties: relevantProperties, info: info,
								isUpToDate: isUpToDate, isIncludedSelector: isIncludedSelector)
								{ completionProc(($0, $1)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Update collection
		updateCollection(named: name, documentLastRevision: (resultInfo!["documentLastRevision"] as! UInt),
				collectionLastDocumentRevision: (resultInfo!["collectionLastDocumentRevision"] as! UInt))

		// Update creation proc map
		self.documentCreationProcMap.set({ return T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func queryCollectionDocumentCount(name :String) -> UInt {
		// May need to try this more than once
		while true {
			// Perform blocking
			let	(count, needsUpdate, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.networkClient.retrieveCollectionDocumentCount(name: name)
									{ completionProc(($0, $1, $2)) }
						}
			if count != nil {
				// Success
				return UInt(count!)
			} else if (needsUpdate ?? false) {
				// Collection is not up to date
				updateCollection(named: name)
			} else if error != nil {
				// Error
				self.recentErrors.append(error!)

				return 0
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateCollection<T : MDSDocument>(name :String, proc :(_ document : T) -> Void) {
		// May need to try this more than once
		while true {
			// Perform blocking
			let	(infos, needsUpdate, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.networkClient.retrieveCollectionDocumentInfos(name: name)
									{ completionProc(($0, $1, $2)) }
						}
			if infos != nil {
				// Success
				documents(for: infos!, creationProc: { T(id: $0, documentStorage: $1) }).forEach({ proc($0) })

				return
			} else if (needsUpdate ?? false) {
				// Collection is not up to date
				updateCollection(named: name)
			} else if error != nil {
				// Error
				self.recentErrors.append(error!)

				return
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func registerIndex<T : MDSDocument>(named name :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysProc :@escaping (_ document :T) -> [String]) {
		// Perform blocking
		let	(info, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.networkClient.registerIndex(name: name, documentType: T.documentType, version: version,
								relevantProperties: relevantProperties, keysSelector: keysSelector)
								{ completionProc(($0, $1)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Update index
		updateIndex(named: name, documentLastRevision: (info!["documentLastRevision"] as! UInt),
				indexLastDocumentRevision: (info!["indexLastDocumentRevision"] as! UInt))

		// Update creation proc map
		self.documentCreationProcMap.set({ return T(id: $0, documentStorage: $1) }, for: T.documentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func iterateIndex<T : MDSDocument>(name :String, keys :[String],
			proc :(_ key :String, _ document :T) -> Void) {
		// May need to try this more than once
		var	documentInfosMap = [String : Any]()
		while true {
			// Perform blocking
			let	(_documentInfosMap, needsUpdate, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.networkClient.retrieveIndexDocumentInfosMap(name: name, keys: keys)
									{ completionProc(($0, $1, $2)) }
						}
			if _documentInfosMap != nil {
				// Success
				documentInfosMap = _documentInfosMap!
				break
			} else if (needsUpdate ?? false) {
				// Collection is not up to date
				updateIndex(named: name)
			} else if error != nil {
				// Error
				self.recentErrors.append(error!)

				return
			}
		}

		// Map keys to document IDs - Note that there may be some keys that map to the same document
		var	keysToDocumentIDsMap = [String : String]()
		var	documentInfos = [[String : Any]]()
		var	documentIDsProcessed = Set<String>()
		documentInfosMap.forEach() {
			// Check if we have document info for this key
			if let info = $0.value as? [String : Any] {
				// We have document info for this key
				let	documentID = info["documentID"] as! String

				// Update
				keysToDocumentIDsMap[$0.key] = (info["documentID"] as! String)
				if !documentIDsProcessed.contains(documentID) {
					// Append this info
					documentInfos.append(info)
					documentIDsProcessed.insert(documentID)
				}
			}
		}

		// Iterate documents
		let	documents :[T] =
					self.documents(for: documentInfos,
							creationProc: self.documentCreationProcMap.value(for: T.documentType)!)
		let	documentsMap = Dictionary(documents.map({ return ($0.id, $0) }))
		keysToDocumentIDsMap.forEach() { proc($0.key, documentsMap[$0.value]!) }
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

	//------------------------------------------------------------------------------------------------------------------
	private func documents<T :MDSDocument>(for infos :[[String : Any]], creationProc :DocumentCreationProc) -> [T] {
		// Setup
		let	documentType = T.documentType

		var	documents = [T]()

		// Iterate all infos
		var	documentReferences = [MDSRemoteStorageCache.DocumentReference]()
		infos.forEach() {
			// Get info
			let	documentID = $0["documentID"] as! String
			let	revision = $0["revision"] as! Int

			// Check if have in cache and is most recent
			if let documentBacking = self.documentBackingCache.documentBacking(for: documentID),
					documentBacking.revision == revision {
				// Use from property storables cache
				documents.append(creationProc(documentID, self) as! T)
			} else {
				// Must retrieve elsewhere
				documentReferences.append(MDSRemoteStorageCache.DocumentReference(id: documentID, revision: revision))
			}
		}

		// Retrieve from disk cache
		let	(documentInfos, documentReferencesNotResolved) =
					self.cache.documentInfos(for: documentType, with: documentReferences)
		if !documentInfos.isEmpty {
			// Iterate all document infos
			var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
			documentInfos.forEach() {
				// Update document backing infos
				documentBackingInfos.append(
						MDSDocumentBackingInfo<MDSRemoteStorage.DocumentBacking>(documentID: $0.id,
								documentBacking:
										MDSRemoteStorage.DocumentBacking(type: documentType,
												creationDate: $0.creationDate, active: $0.active,
												modificationDate: $0.modificationDate, revision: $0.revision,
												json: $0.propertyMap)))
			}

			// Update cache
			self.documentBackingCache.add(documentBackingInfos)

			// Create property storables
			documentInfos.forEach() { documents.append(creationProc($0.id, self) as! T) }
		}

		// Check if have documents to retrieve
		if !documentReferencesNotResolved.isEmpty {
			// Retrieve from server
			retrieveDocuments(for: documentReferencesNotResolved.map({ $0.id }), documentType: documentType)

			// Create property storables
			documentReferencesNotResolved.forEach() { documents.append(creationProc($0.id, self) as! T) }
		}

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateCollection(named name :String, documentLastRevision :UInt? = nil,
			collectionLastDocumentRevision :UInt? = nil) {
		// Setup
		var	documentLastRevisionUse = documentLastRevision
		var	collectionLastDocumentRevisionUse = collectionLastDocumentRevision

		// Repeat until up to date
		while (documentLastRevisionUse == nil) || (collectionLastDocumentRevisionUse == nil) ||
				(documentLastRevisionUse! != collectionLastDocumentRevisionUse!) {
			// Perform blocking
			let	(info, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.networkClient.updateCollection(name: name, documentCount: 500)
									{ completionProc(($0, $1)) }
						}
			guard error == nil else {
				// Store error
				self.recentErrors.append(error!)

				return
			}

			// Update info
			documentLastRevisionUse = (info!["documentLastRevision"] as! UInt)
			collectionLastDocumentRevisionUse = (info!["collectionLastDocumentRevision"] as! UInt)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateIndex(named name :String, documentLastRevision :UInt? = nil,
			indexLastDocumentRevision :UInt? = nil) {
		// Setup
		var	documentLastRevisionUse = documentLastRevision
		var	indexLastDocumentRevisionUse = indexLastDocumentRevision

		// Repeat until up to date
		while (documentLastRevisionUse == nil) || (indexLastDocumentRevisionUse == nil) ||
				(documentLastRevisionUse! != indexLastDocumentRevisionUse!) {
			// Perform blocking
			let	(info, error) =
						DispatchQueue.performBlocking() { completionProc in
							// Call network client
							self.networkClient.updateIndex(name: name, documentCount: 500) { completionProc(($0, $1)) }
						}
			guard error == nil else {
				// Store error
				self.recentErrors.append(error!)

				return
			}

			// Update info
			documentLastRevisionUse = (info!["documentLastRevision"] as! UInt)
			indexLastDocumentRevisionUse = (info!["indexLastDocumentRevision"] as! UInt)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func createDocuments(documentType :String, infos :[[String : Any]]) -> [String] {
		// Preflight
		guard !infos.isEmpty else { return [] }

		// Perform blocking
		let	(returnInfos, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.networkClient.createDocuments(documentType: documentType, infos: infos)
								{ completionProc(($0, $1)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return []
		}

		// Update caches
		var	documentIDs = [String]()
		var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
		var	documentInfos = [MDSRemoteStorageCache.DocumentInfo]()
		returnInfos!.enumerated().forEach() {
			// Get info
			let	documentID = $0.element["documentID"] as! String
			let	creationDate = Date(fromRFC3339Extended: ($0.element["creationDate"] as! String))!
			let	modificationDate = Date(fromRFC3339Extended: ($0.element["modificationDate"] as! String))!
			let	revision = $0.element["revision"] as! Int
			let	json = (infos[$0.offset]["json"] as? [String : Any]) ?? [:]

			// Add to arrays
			documentIDs.append(documentID)
			documentBackingInfos.append(
					MDSDocumentBackingInfo<DocumentBacking>(documentID: documentID,
							documentBacking:
									DocumentBacking(type: documentType, creationDate: creationDate, active: true,
											modificationDate: modificationDate, revision: revision, json: json)))
			documentInfos.append(
					MDSRemoteStorageCache.DocumentInfo(id: documentID, revision: revision, active: true,
							creationDate: creationDate, modificationDate: modificationDate, propertyMap: json))
		}
		self.documentBackingCache.add(documentBackingInfos)
		self.cache.add(documentInfos, for: documentType)

		return documentIDs
	}

	//------------------------------------------------------------------------------------------------------------------
	@discardableResult
	private func retrieveDocuments(for ids :[String], documentType :String) ->
			[MDSDocumentBackingInfo<DocumentBacking>] {
		// Preflight
		guard !ids.isEmpty else { return [] }

		// Perform blocking
		let	(infos, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.networkClient.retrieveDocuments(documentType: documentType, documentIDs: ids)
								{ completionProc(($0, $1)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return []
		}

		// Update caches
		var	documentBackings = [DocumentBacking]()
		var	documentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
		var	documentInfos = [MDSRemoteStorageCache.DocumentInfo]()
		infos!.forEach() {
			// Get info
			let	documentID = $0["documentID"] as! String
			let	creationDate = Date(fromRFC3339Extended: $0["creationDate"] as? String)!
			let	modificationDate = Date(fromRFC3339Extended: $0["modificationDate"] as? String)!
			let	revision = $0["revision"] as! Int
			let	active = ($0["active"] as! Int) == 1
			let	json = $0["json"] as! [String : Any]

			let	documentBacking =
						DocumentBacking(type: documentType, creationDate: creationDate, active: active,
								modificationDate: modificationDate, revision: revision, json: json)
			documentBackings.append(documentBacking)
			documentBackingInfos.append(
					MDSDocumentBackingInfo<DocumentBacking>(documentID: documentID, documentBacking: documentBacking))
			documentInfos.append(
					MDSRemoteStorageCache.DocumentInfo(id: documentID, revision: revision, active: active,
							creationDate: creationDate, modificationDate: modificationDate, propertyMap: json))
		}
		self.documentBackingCache.add(documentBackingInfos)
		self.cache.add(documentInfos, for: documentType)

		return documentBackingInfos
	}

	//------------------------------------------------------------------------------------------------------------------
	private func updateDocuments(documentType :String,
			documentInfos
					:[(documentID :String, documentBacking :DocumentBacking, updatedPropertyMap :[String : Any],
							removedKeys :[String], active :Bool)]) {
		// Preflight
		guard !documentInfos.isEmpty else { return }

		// Setup
		let	infos :[(documentID :String, updatedPropertyMap :[String : Any], removedKeys :[String], active :Bool)] =
					documentInfos.map() { return ($0.documentID, $0.updatedPropertyMap, $0.removedKeys, $0.active) }

		// Perform blocking
		let	(returnInfos, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Call network client
						self.networkClient.updateDocuments(documentType: documentType, infos: infos)
								{ completionProc(($0, $1)) }
					}
		guard error == nil else {
			// Store error
			self.recentErrors.append(error!)

			return
		}

		// Update caches
		var	updatedDocumentBackingInfos = [MDSDocumentBackingInfo<DocumentBacking>]()
		var	updatedDocumentInfos = [MDSRemoteStorageCache.DocumentInfo]()
		returnInfos!.enumerated().forEach() {
			// Get info
			var	documentBacking = documentInfos[$0.offset].documentBacking

			let	documentID = documentInfos[$0.offset].documentID
			let	creationDate = documentBacking.creationDate
			let	modificationDate = Date(fromRFC3339Extended: $0.element["modificationDate"] as? String)!
			let	revision = $0.element["revision"] as! Int
			let	active = ($0.element["active"] as! Int) == 1
			let	json = $0.element["json"] as! [String : Any]

			// Update
			documentBacking.modificationDate = modificationDate
			documentBacking.revision = revision
			documentBacking.json = json

			// Add to array
			updatedDocumentBackingInfos.append(
				MDSDocumentBackingInfo<DocumentBacking>(documentID: documentID, documentBacking: documentBacking))
			updatedDocumentInfos.append(
					MDSRemoteStorageCache.DocumentInfo(id: documentID, revision: revision, active: active,
							creationDate: creationDate, modificationDate: modificationDate, propertyMap: json))
		}
		self.documentBackingCache.add(updatedDocumentBackingInfos)
		self.cache.add(updatedDocumentInfos, for: documentType)
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
