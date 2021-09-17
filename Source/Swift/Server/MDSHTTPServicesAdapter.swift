//
//  MDSHTTPServicesAdapter.swift
//  Mini Document Storage
//
//  Created by Stevo on 3/29/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSHTTPServicesAdapter
class MDSHTTPServicesAdapter {

	// MARK: Types
			typealias AuthorizationValidationProc = (_ authorization :String) -> Bool

	private	typealias DocumentStorageHandlerInfo =
						(documentStorageServerHandler :MDSDocumentStorageServerHandler,
								authorizationValidationProc :AuthorizationValidationProc)

	// MARK: Properties
	private	var	documentStorageHandlerInfoMap = [/* HTTP API ID */ String : DocumentStorageHandlerInfo]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServer :HTTPServer) {
		// Setup
		setupInfoEndpoints(with: httpServer)
		setupDocumentsEndpoints(with: httpServer)
		setupCollectionEndpoints(with: httpServer)
		setupIndexEndpoints(with: httpServer)
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func add(documentStorageServerHandler :MDSDocumentStorageServerHandler, for documentStorageID :String = "default",
			authorizationValidationProc :@escaping AuthorizationValidationProc) {
		// Store
		self.documentStorageHandlerInfoMap[documentStorageID] =
				(documentStorageServerHandler, authorizationValidationProc)
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func setupInfoEndpoints(with httpServer :HTTPServer) {
		// Setup info endpoints
		var	retrieveInfoEndpoint = MDSHTTPServices.getInfoEndpoint
		retrieveInfoEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			return (.ok, nil, .json(documentStorageServerHandler.info(for: info.keys)))
		}
		httpServer.register(retrieveInfoEndpoint)

		var	setInfoEndpoint = MDSHTTPServices.setInfoEndpoint
		setInfoEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Update
			documentStorageServerHandler.set(info.info)

			return (.ok, nil, nil)
		}
		httpServer.register(setInfoEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupDocumentsEndpoints(with httpServer :HTTPServer) {
		// Setup documents endpoints
		var	retrieveDocumentsEndpoint = MDSHTTPServices.getDocumentsEndpoint
		retrieveDocumentsEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Check requested flavor
			if let documentIDs = info.documentIDs {
				// Iterate documentIDs
				var	documentInfos = [[String : Any]]()
				documentStorageServerHandler.iterate(documentType: info.type, documentIDs: documentIDs)
						{ documentInfos.append($0.httpServicesInfo) }

				return (.ok, nil, .json(documentInfos))
			} else {
				// Iterate documents since revision
				var	documentInfos = [[String : Any]]()
				documentStorageServerHandler.iterate(documentType: info.type, sinceRevision: info.sinceRevision!)
						{ documentInfos.append($0.httpServicesInfo) }

				return (.ok,
						[HTTPURLResponse.contentRangeHeader(for: "documentInfos", start: 0,
								length: Int64(documentInfos.count), size: Int64(documentInfos.count))],
						.json(documentInfos))
			}
		}
		httpServer.register(retrieveDocumentsEndpoint)

		var	createDocumentsEndpoint = MDSHTTPServices.createDocumentsEndpoint
		createDocumentsEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Create documents
			documentStorageServerHandler.newDocuments(documentType: info.type,
					documentCreateInfos: info.documentCreateInfos)

			return (.ok, nil, nil)
		}
		httpServer.register(createDocumentsEndpoint)

		var	updateDocumentsEndpoint = MDSHTTPServices.updateDocumentsEndpoint
		updateDocumentsEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Update documents
			documentStorageServerHandler.updateDocuments(documentType: info.type,
					documentUpdateInfos: info.documentUpdateInfos)

			return (.ok, nil, nil)
		}
		httpServer.register(updateDocumentsEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupCollectionEndpoints(with httpServer :HTTPServer) {
		// Setup collection endpoints
		var	registerCollectionEndpoint = MDSHTTPServices.registerCollectionEndpoint
		registerCollectionEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Register collection
			let	(documentLastRevision, collectionLastDocumentRevision) =
						documentStorageServerHandler.registerCollection(named: info.name,
								documentType: info.documentType, version: info.version,
								relevantProperties: info.relevantProperties, isUpToDate: info.isUpToDate,
								isIncludedSelector: info.isIncludedSelector,
								isIncludedSelectorInfo: info.isIncludedSelectorInfo)
			let	info :[String : Any] = [
										"documentLastRevision": documentLastRevision,
										"collectionLastDocumentRevision": collectionLastDocumentRevision,
									   ]

			return (.ok, nil, .json(info))
		}
		httpServer.register(registerCollectionEndpoint)

		var	retrieveCollectionDocumentCountEndpoint = MDSHTTPServices.getCollectionDocumentCountEndpoint
		retrieveCollectionDocumentCountEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Query count
			let	count = documentStorageServerHandler.documentCountForCollection(named: info.name)

			return (.ok,
					[HTTPURLResponse.contentRangeHeader(for: "items", start: 0, length: Int64(count),
							size: Int64(count))],
					nil)
		}
		httpServer.register(retrieveCollectionDocumentCountEndpoint)

		var	retrieveCollectionDocumentInfosEndpoint = MDSHTTPServices.getCollectionDocumentInfosEndpoint
		retrieveCollectionDocumentInfosEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Retrieve document revision info
			var	documentInfos = [String : Int]()
			documentStorageServerHandler.iterateCollection(name: info.name)
					{ (documentRevisionInfo :MDSDocument.RevisionInfo) in
						// Add info
						documentInfos[documentRevisionInfo.documentID] = documentRevisionInfo.revision
					}

			return (.ok,
					[HTTPURLResponse.contentRangeHeader(for: "documentInfos", start: 0,
							length: Int64(documentInfos.count), size: Int64(documentInfos.count))],
					.json(documentInfos))
		}
		httpServer.register(retrieveCollectionDocumentInfosEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupIndexEndpoints(with httpServer :HTTPServer) {
		// Setup index endpoints
		var	registerIndexEndpoint = MDSHTTPServices.registerIndexEndpoint
		registerIndexEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Register index
			let	(documentLastRevision, collectionLastDocumentRevision) =
						documentStorageServerHandler.registerIndex(named: info.name, documentType: info.documentType,
								version: info.version, relevantProperties: info.relevantProperties,
								isUpToDate: info.isUpToDate, keysSelector: info.keysSelector,
								keysSelectorInfo: info.keysSelectorInfo)
			let	info :[String : Any] = [
										"documentLastRevision": documentLastRevision,
										"collectionLastDocumentRevision": collectionLastDocumentRevision,
									   ]

			return (.ok, nil, .json(info))
		}
		httpServer.register(registerIndexEndpoint)
		var	retrieveIndexDocumentInfosEndpoint = MDSHTTPServices.getIndexDocumentInfosEndpoint
		retrieveIndexDocumentInfosEndpoint.performProc = { info in
			// Setup
			guard let (documentStorageServerHandler, authorizationValidationProc) =
					self.documentStorageHandlerInfoMap[info.documentStorageID] else {
				// Document storage not found
				return (.badRequest, nil, nil)
			}

			// Validate authorization
			if let authorization = info.authorization, !authorizationValidationProc(authorization) {
				// Not authorized
				return (.unauthorized, [], .json(["error": "not authorized"]))
			}

			// Retrieve key => document revision infos
			var	documentMap = [String : [String : Int]]()
			documentStorageServerHandler.iterateIndex(name: info.name, keys: info.keys)
					{ (key :String, documentRevisionInfo :MDSDocument.RevisionInfo) in
						// Add info
						documentMap[key] = [documentRevisionInfo.documentID: documentRevisionInfo.revision]
					}

			return (.ok, nil, .json(documentMap))
		}
		httpServer.register(retrieveIndexDocumentInfosEndpoint)
	}
}
