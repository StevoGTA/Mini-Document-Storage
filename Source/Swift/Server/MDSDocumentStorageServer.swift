//
//  MDSDocumentStorageServer.swift
//  Mini Document Storage
//
//  Created by Stevo on 3/29/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageServerBacking
protocol MDSDocumentStorageServerBacking : MDSDocumentStorage {

	// MARK: Instance methods
	func info(for keys :[String]) -> [String : String]
	func update(_ valueMap :[String : String])

	func newDocuments(documentType :String, documentCreateInfos :[MDSDocumentCreateInfo])
	func iterate(documentType :String, documentIDs :[String],
			proc :@escaping (_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
	func iterate(documentType :String, documentIDs :[String],
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void)
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :@escaping (_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void)
	func updateDocuments(documentType :String, documentUpdateInfos :[MDSDocumentUpdateInfo])

	func registerCollection(named name :String, documentType :String, version :UInt, isIncludedSelector :String,
			relevantProperties :[String], info :MDSDocument.PropertyMap, isUpToDate :Bool)
	func iterateCollection(name :String, proc :@escaping (_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
	func iterateCollection(name :String, proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void)

	func registerIndex(named name :String, documentType :String, version :UInt, keySelector :String,
			relevantProperties :[String])
	func iterateIndex(name :String, keys :[String],
			proc :@escaping (_ key :String, _ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
	func iterateIndex(name :String, keys :[String],
			proc :(_ key :String, _ documentFullInfo :MDSDocumentFullInfo) -> Void)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorageServer
class MDSDocumentStorageServer {

	// MARK: Properties
	private	var	documentStorageServerBackingMap = [/* HTTP API ID */ String : MDSDocumentStorageServerBacking]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServerManager: HTTPServerManager) {
		// Setup
		setupInfoEndpoints(with: httpServerManager)
		setupDocumentsEndpoints(with: httpServerManager)
		setupCollectionEndpoints(with: httpServerManager)
		setupIndexEndpoints(with: httpServerManager)
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func add(documentStorageServerBacking :MDSDocumentStorageServerBacking, for documentStorageID :String = "default") {
		// Store
		self.documentStorageServerBackingMap[documentStorageID] = documentStorageServerBacking
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func setupInfoEndpoints(with httpServerManager: HTTPServerManager) {
		// Setup info endpoints
		var	getEndpoint = MDSHTTPServices.infoGetEndpoint
		getEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			return (.ok, nil, .json(documentStorageServerBacking.info(for: info.keys)))
		}
		httpServerManager.register(getEndpoint)

		var	postEndpoint = MDSHTTPServices.infoPostEndpoint
		postEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Update
			documentStorageServerBacking.update(info.info)

			return (.ok, nil, nil)
		}
		httpServerManager.register(postEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupDocumentsEndpoints(with httpServerManager: HTTPServerManager) {
		// Setup documents endpoints
		var	getEndpoint = MDSHTTPServices.documentsGetEndpoint
		getEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Check requested flavor
			var	documentInfos = [[String : Any]]()
			if let documentIDs = info.documentIDs {
				// Document IDs
				if info.fullInfo {
					// Iterate and query full info
					documentStorageServerBacking.iterate(documentType: info.type, documentIDs: documentIDs)
							{ (documentFullInfo :MDSDocumentFullInfo) in
								// Add info
								documentInfos.append(documentFullInfo.httpServicesInfo)
							}
				} else {
					// Iterate and query minimal info
					documentStorageServerBacking.iterate(documentType: info.type, documentIDs: documentIDs)
							{ (documentRevisionInfo :MDSDocumentRevisionInfo) in
								// Add info
								documentInfos.append(documentRevisionInfo.httpServicesInfo)
							}
				}
			} else {
				// Since revision
				if info.fullInfo {
					// Iterate and query full info
					documentStorageServerBacking.iterate(documentType: info.type, sinceRevision: info.sinceRevision!)
							{ (documentFullInfo :MDSDocumentFullInfo) in
								// Add info
								documentInfos.append(documentFullInfo.httpServicesInfo)
							}
				} else {
					// Iterate and query minimal info
					documentStorageServerBacking.iterate(documentType: info.type, sinceRevision: info.sinceRevision!)
							{ (documentRevisionInfo :MDSDocumentRevisionInfo) in
								// Add info
								documentInfos.append(documentRevisionInfo.httpServicesInfo)
							}
				}
			}

			return (.ok, nil, .json(documentInfos))
		}
		httpServerManager.register(getEndpoint)

		var	postEndpoint = MDSHTTPServices.documentsPostEndpoint
		postEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Create documents
			documentStorageServerBacking.newDocuments(documentType: info.type,
					documentCreateInfos: info.documentCreateInfos)

			return (.ok, nil, nil)
		}
		httpServerManager.register(postEndpoint)

		var	patchEndpoint = MDSHTTPServices.documentsPatchEndpoint
		patchEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Update documents
			documentStorageServerBacking.updateDocuments(documentType: info.type,
					documentUpdateInfos: info.documentUpdateInfos)

			return (.ok, nil, nil)
		}
		httpServerManager.register(patchEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupCollectionEndpoints(with httpServerManager: HTTPServerManager) {
		// Setup collection endpoints
		var	headEndpoint = MDSHTTPServices.collectionHeadEndpoint
		headEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Query count
			let	count = documentStorageServerBacking.queryCollectionDocumentCount(name: info.name)

			return (.ok, [("Content-Range", "items 0-\(count)/\(count)")], nil)
		}
		httpServerManager.register(headEndpoint)

		var	getEndpoint = MDSHTTPServices.collectionGetEndpoint
		getEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Retrieve document infos
			var	documentInfos = [[String : Any]]()
			if info.fullInfo {
				// Iterate and query full info
				documentStorageServerBacking.iterateCollection(name: info.name)
						{ (documentFullInfo :MDSDocumentFullInfo) in
							// Add info
							documentInfos.append(documentFullInfo.httpServicesInfo)
						}
			} else {
				// Iterate and query minimal info
				documentStorageServerBacking.iterateCollection(name: info.name)
						{ (documentRevisionInfo :MDSDocumentRevisionInfo) in
							// Add info
							documentInfos.append(documentRevisionInfo.httpServicesInfo)
						}
			}

			return (.ok, nil, .json(documentInfos))
		}
		httpServerManager.register(getEndpoint)

		var	putEndpoint = MDSHTTPServices.collectionPutEndpoint
		putEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Register collection
			documentStorageServerBacking.registerCollection(named: info.name, documentType: info.documentType,
					version: info.version, isIncludedSelector: info.isIncludedSelector,
					relevantProperties: info.relevantProperties, info: info.info, isUpToDate: info.isUpToDate)

			return (.ok, nil, nil)
		}
		httpServerManager.register(putEndpoint)

		var	patchEndpoint = MDSHTTPServices.collectionPatchEndpoint
		patchEndpoint.performProc = { info in
			// Query document storage
			guard self.documentStorageServerBackingMap[info.documentStorageID] != nil else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			return (.ok, nil, nil)
		}
		httpServerManager.register(patchEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupIndexEndpoints(with httpServerManager: HTTPServerManager) {
		// Setup index endpoints
		var	getEndpoint = MDSHTTPServices.indexGetEndpoint
		getEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Retrieve document infos
			var	documentMap = [String : [String : Any]]()
			if info.fullInfo {
				// Iterate and query full info
				documentStorageServerBacking.iterateIndex(name: info.name, keys: info.keys)
						{ (key :String, documentFullInfo :MDSDocumentFullInfo) in
							// Add info
							documentMap[key] = documentFullInfo.httpServicesInfo
						}
			} else {
				// Iterate and query minimal info
				documentStorageServerBacking.iterateIndex(name: info.name, keys: info.keys)
						{ (key :String, documentRevisionInfo :MDSDocumentRevisionInfo) in
							// Add info
							documentMap[key] = documentRevisionInfo.httpServicesInfo
						}
			}

			return (.ok, nil, .json(documentMap))
		}
		httpServerManager.register(getEndpoint)

		var	putEndpoint = MDSHTTPServices.indexPutEndpoint
		putEndpoint.performProc = { info in
			// Query document storage
			guard let documentStorageServerBacking = self.documentStorageServerBackingMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Register index
			documentStorageServerBacking.registerIndex(named: info.name, documentType: info.documentType,
					version: info.version, keySelector: info.keySelector, relevantProperties: info.relevantProperties)

			return (.ok, nil, nil)
		}
		httpServerManager.register(putEndpoint)

		var	patchEndpoint = MDSHTTPServices.indexPatchEndpoint
		patchEndpoint.performProc = { info in
			// Query document storage
			guard self.documentStorageServerBackingMap[info.documentStorageID] != nil else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			return (.ok, nil, nil)
		}
		httpServerManager.register(patchEndpoint)
	}
}
