//
//  MDSHTTPServices.swift
//  Mini Document Storage
//
//  Created by Stevo on 4/2/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentRevisionInfo extension
extension MDSDocumentRevisionInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"documentID": self.documentID,
					"revision": self.revision,
				]
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServicesInfo :[String : Any]) {
		// Store
		self.documentID = httpServicesInfo["documentID"] as! String
		self.revision = httpServicesInfo["revision"] as! Int
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentFullInfo extension
extension MDSDocumentFullInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"documentID": self.documentID,
					"revision": self.revision,
					"creationDate": self.creationDate.rfc3339Extended,
					"modificationDate": self.modificationDate.rfc3339Extended,
					"json": self.propertyMap,
				]
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServicesInfo :[String : Any]) {
		// Store
		self.documentID = httpServicesInfo["documentID"] as! String
		self.revision = httpServicesInfo["revision"] as! Int
		self.creationDate = Date(fromRFC3339Extended: httpServicesInfo["creationDate"] as? String)!
		self.modificationDate = Date(fromRFC3339Extended: httpServicesInfo["modificationDate"] as? String)!
		self.propertyMap = httpServicesInfo["json"] as! [String : Any]
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentCreateInfo
extension MDSDocumentCreateInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				// Compose info
				var	info :[String : Any] = ["json": self.propertyMap]
				info["documentID"] = self.documentID
				info["creationDate"] = self.creationDate?.rfc3339Extended
				info["modificationDate"] = self.modificationDate?.rfc3339Extended

				return info
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServicesInfo :[String : Any]) {
		// Store
		self.documentID = httpServicesInfo["documentID"] as? String
		self.creationDate = Date(fromRFC3339Extended: httpServicesInfo["creationDate"] as? String)
		self.modificationDate = Date(fromRFC3339Extended: httpServicesInfo["modificationDate"] as? String)
		self.propertyMap = httpServicesInfo["json"] as! [String : Any]
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentUpdateInfo extension
extension MDSDocumentUpdateInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"documentID": self.documentID,
					"updated": self.updated,
					"removed": self.removed,
					"active": self.active,
				]
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServicesInfo :[String : Any]) {
		// Store
		self.documentID = httpServicesInfo["documentID"] as! String
		self.updated = httpServicesInfo["updated"] as! [String : Any]
		self.removed = httpServicesInfo["removed"] as! [String]
		self.active = httpServicesInfo["active"] as! Bool
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSHTTPServices
class MDSHTTPServices {

	// MARK: Documents return info
	//	<= json
	//		fullInfo == "0"
	//			[
	//				{
	//					"documentID" :String,
	//					"revision" :Int,
	//				},
	//				...
	//			]
	//
	//		fullInfo == "1"
	//			[
	//				{
	//					"documentID" :String,
	//					"revision" :Int,
	//					"creationDate" :String,
	//					"modificationDate" :String,
	//					"json" :{
	//								"key" :Any,
	//								...
	//							},
	//				},
	//				...
	//			]
	class DocumentRevisionHTTPEndpointRequest : JSONHTTPEndpointRequest<[[String : Any]]> {

		// MARK: Properties
		var	documentsProc :(_ documentRevisionInfos :[MDSDocumentRevisionInfo]?, _ error :Error?) -> Void = { _,_ in } {
					didSet {
						// Setup info proc
						self.completionProc = { [unowned self] in
							// Call proc
							self.documentsProc($0?.map({ MDSDocumentRevisionInfo(httpServicesInfo: $0) }), $1)
						}
					}
				}
	}

	class DocumentInfoHTTPEndpointRequest : JSONHTTPEndpointRequest<[[String : Any]]> {

		// MARK: Properties
		var	documentsProc :(_ documentFullInfos :[MDSDocumentFullInfo]?, _ error :Error?) -> Void = { _,_ in } {
					didSet {
						// Setup info proc
						self.completionProc = { [unowned self] in
							// Call proc
							self.documentsProc($0?.map({ MDSDocumentFullInfo(httpServicesInfo: $0) }), $1)
						}
					}
				}
	}

	//	<= json
	//		fullInfo == "0"
	//			{
	//				key:
	//					{
	//						"documentID" :String,
	//						"revision" :Int,
	//					},
	//				...
	//			}
	//
	//		fullInfo == "1"
	//			{
	//				key:
	//					{
	//						"documentID" :String,
	//						"revision" :Int,
	//						"creationDate" :String,
	//						"modificationDate" :String,
	//						"json" :{
	//									"key" :Any,
	//									...
	//								},
	//					},
	//				...
	//			]
	class DocumentRevisionMapHTTPEndpointRequest : JSONHTTPEndpointRequest<[String : [String : Any]]> {

		// MARK: Properties
		var	documentMapProc :(_ documentRevisionInfoMap :[String : MDSDocumentRevisionInfo]?, _ error :Error?) -> Void =
					{ _,_ in } {
					didSet {
						// Setup info proc
						self.completionProc = { [unowned self] in
							// Call proc
							self.documentMapProc($0?.mapValues({ MDSDocumentRevisionInfo(httpServicesInfo: $0) }), $1)
						}
					}
				}
	}

	class DocumentInfoMapHTTPEndpointRequest : JSONHTTPEndpointRequest<[String : [String : Any]]> {

		// MARK: Properties
		var	documentMapProc :(_ documentMap :[String : MDSDocumentFullInfo]?, _ error :Error?) -> Void =
					{ _,_ in } {
					didSet {
						// Setup info proc
						self.completionProc = { [unowned self] in
							// Call proc
							self.documentMapProc($0!.mapValues({ MDSDocumentFullInfo(httpServicesInfo: $0) }), $1)
						}
					}
				}
	}

	// MARK: GET Documents
	//	=> documentID (query) (can specify multiple)
	//	=> fullInfo (query) (optional), "0" or "1", defaults to "0"
	//		-or-
	//	=> sinceRevision (query)
	//	=> fullInfo (query) (optional), "0" or "1", defaults to "0"
	//
	//	<= Documents return info
	typealias DocumentsGetEndpointInfo =
				(documentStorageID :String, type :String, documentIDs :[String]?, sinceRevision :Int?, fullInfo :Bool)
	static	let	documentsGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/documents/:documentStorageID/:type")
								{ (urlComponents, headers) -> DocumentsGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]
									let	type = pathComponents[2]

									let	queryItemsMap = urlComponents.queryItemsMap
									let	documentIDs = queryItemsMap.stringArray(for: "documentID")
									let	sinceRevision = queryItemsMap["sinceRevision"] as? Int
									let	fullInfo = ((queryItemsMap["fullInfo"] as? String) ?? "") == "1"
									guard (documentIDs != nil) || (sinceRevision != nil) else {
										// Query info not specified
										throw HTTPEndpointError.badRequest(
												with: "missing documentID(s) or sinceRevision in query")
									}

									return (documentStorageID, type, documentIDs, sinceRevision, fullInfo)
								}
	static func httpEndpointRequestForGetDocumentsRevision(documentStorageID :String, type :String,
			documentIDs :[String]) -> DocumentRevisionHTTPEndpointRequest {
		// Return endpoint request
		return DocumentRevisionHTTPEndpointRequest(method: .get, path: "/documents/\(documentStorageID)/\(type)",
				queryComponents: [
									"documentID": documentIDs,
									"fullInfo": 0,
								 ])
	}
	static func httpEndpointRequestForGetDocumentsInfo(documentStorageID :String, type :String, documentIDs :[String])
			-> DocumentInfoHTTPEndpointRequest {
		// Return endpoint request
		return DocumentInfoHTTPEndpointRequest(method: .get, path: "/documents/\(documentStorageID)/\(type)",
				queryComponents: [
									"documentID": documentIDs,
									"fullInfo": 1,
								 ])
	}
	static func httpEndpointRequestForGetDocumentsRevision(documentStorageID :String, type :String, sinceRevision :Int)
			-> DocumentRevisionHTTPEndpointRequest {
		// Return endpoint request
		return DocumentRevisionHTTPEndpointRequest(method: .get, path: "/documents/\(documentStorageID)/\(type)",
				queryComponents: [
									"sinceRevision": sinceRevision,
									"fullInfo": 0,
								 ])
	}
	static func httpEndpointRequestForGetDocumentsInfo(documentStorageID :String, type :String, sinceRevision :Int) ->
			DocumentInfoHTTPEndpointRequest {
		// Return endpoint request
		return DocumentInfoHTTPEndpointRequest(method: .get, path: "/documents/\(documentStorageID)/\(type)",
				queryComponents: [
									"sinceRevision": sinceRevision,
									"fullInfo": 1,
								 ])
	}

	// MARK: POST Documents
	//	=> json (body)
	//		[
	//			{
	//				"documentID" :(optional) String
	//				"creationDate" :(optional) String
	//				"modificationDate" :(optional) String
	//				"json" :[
	//							"key" :Any,
	//							...
	//						]
	//			},
	//			...
	//		]
	typealias DocumentsPostEndpointInfo =
				(documentStorageID :String, type :String, documentCreateInfos :[MDSDocumentCreateInfo])
	static	let	documentsPostEndpoint =
						JSONHTTPEndpoint<Any, DocumentsPostEndpointInfo>(method: .post,
								path: "/documents/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> DocumentsPostEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]
									let	type = pathComponents[2]

									guard let infos = info as? [[String : Any]] else {
										// Unable to retrieve infos properly
										throw HTTPEndpointError.badRequest(
												with: "body data is not in the correct format")
									}
									guard infos.first(where: { $0["json"] == nil }) != nil else {
										// json not found in all infos
										throw HTTPEndpointError.badRequest(
												with: "json not specified for all document infos")
									}
									let	documentCreateInfos =
												infos.map() { MDSDocumentCreateInfo(httpServicesInfo: $0) }

									return (documentStorageID, type, documentCreateInfos)
								}
	static func httpEndpointRequestForPostDocuments(documentStorageID :String, type :String,
			documentCreateInfos :[MDSDocumentCreateInfo]) -> SuccessHTTPEndpointRequest {
		// Return endpoint request
		return SuccessHTTPEndpointRequest(method: .post, path: "/documents/\(documentStorageID)/\(type)",
				jsonBody: documentCreateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: PATCH Documents
	//	=> json (body)
	//		[
	//			{
	//				"documentID" :String
	//				"updated" :[
	//								"key" :Any,
	//								...
	//						   ]
	//				"removed" :[
	//								"key",
	//								...
	//						   ]
	//				"active" :0/1
	//			},
	//			...
	//		]
	typealias DocumentsPatchEndpointInfo =
				(documentStorageID :String, type :String, documentUpdateInfos :[MDSDocumentUpdateInfo])
	static	let	documentsPatchEndpoint =
						JSONHTTPEndpoint<Any, DocumentsPatchEndpointInfo>(method: .patch,
								path: "/documents/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> DocumentsPatchEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]
									let	type = pathComponents[2]

									guard let infos = info as? [[String : Any]] else {
										// Document storage not found
										throw HTTPEndpointError.badRequest(
												with: "body data is not in the correct format")
									}
									guard infos.first(where: { $0["documentID"] == nil }) != nil else {
										// documentID not found in all infos
										throw HTTPEndpointError.badRequest(
												with: "documentID not specified for all document infos")
									}
									guard infos.first(where: { $0["updated"] == nil }) != nil else {
										// updated not found in all infos
										throw HTTPEndpointError.badRequest(
												with: "updated not specified for all document infos")
									}
									guard infos.first(where: { $0["removed"] == nil }) != nil else {
										// removed not found in all infos
										throw HTTPEndpointError.badRequest(
												with: "removed not specified for all document infos")
									}
									guard infos.first(where: { $0["active"] == nil }) != nil else {
										// active not found in all infos
										throw HTTPEndpointError.badRequest(
												with: "active not specified for all document infos")
									}
									let	documentUpdateInfos =
												infos.map() { MDSDocumentUpdateInfo(httpServicesInfo: $0) }

									return (documentStorageID, type, documentUpdateInfos)
								}
	static func httpEndpointRequestForPatchDocuments(documentStorageID :String, type :String,
			documentUpdateInfos :[MDSDocumentUpdateInfo]) -> SuccessHTTPEndpointRequest {
		// Return endpoint request
		return SuccessHTTPEndpointRequest(method: .patch, path: "/documents/\(documentStorageID)/\(type)",
				jsonBody: documentUpdateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: HEAD Collection
	//	<= count in header
	typealias CollectionHeadEndpointInfo = (documentStorageID :String, name :String)
	static	let	collectionHeadEndpoint =
						BasicHTTPEndpoint(method: .head, path: "/collection/:documentStorageID/:name")
								{ (urlComponents, headers) -> CollectionHeadEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]
									let	name = pathComponents[2]

									return (documentStorageID, name)
								}
	static func httpEndpointRequestForHeadCollection(documentStorageID :String, name :String) ->
			HeadHTTPEndpointRequest {
		// Return endpoint request
		return HeadHTTPEndpointRequest(method: .head, path: "/collection/\(documentStorageID)/\(name)")
	}

	// MARK: GET Collection
	//	=> fullInfo (query) optional, "0" or "1", defaults to "0"
	//
	//	<= Documents return info
	typealias CollectionGetEndpointInfo = (documentStorageID :String, name :String, fullInfo :Bool)
	static	let	collectionGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/collection/:documentStorageID/:name")
								{ (urlComponents, headers) -> CollectionGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]
									let	name = pathComponents[2]

									let	queryItemsMap = urlComponents.queryItemsMap
									let	fullInfo = ((queryItemsMap["fullInfo"] as? String) ?? "") == "1"

									return (documentStorageID, name, fullInfo)
								}
	static func httpEndpointRequestForGetCollectionRevision(documentStorageID :String, name :String) ->
			DocumentRevisionHTTPEndpointRequest {
		// Return endpoint request
		return DocumentRevisionHTTPEndpointRequest(method: .get, path: "/collection/\(documentStorageID)/\(name)",
				queryComponents: ["fullInfo": 0])
	}
	static func httpEndpointRequestForGetCollectionInfo(documentStorageID :String, name :String) ->
			DocumentInfoHTTPEndpointRequest {
		// Return endpoint request
		return DocumentInfoHTTPEndpointRequest(method: .get, path: "/collection/\(documentStorageID)/\(name)",
				queryComponents: ["fullInfo": 1])
	}

	// MARK: PUT Collection
	//	=> json (body)
	//		{
	//			"name" :String,
	//			"documentType" :String,
	//			"version" :Int,
	//			"isIncludedSelector" :String,
	//			"relevantProperties" :(optional) [String]
	//			"info" :(optional) {
	//									"key" :Any,
	//									...
	//							   },
	//			"isUpToDate" :(optional) Int (0 or 1)
	//		}
	typealias CollectionPutEndpointInfo =
				(documentStorageID :String, name :String, documentType :String, version :UInt,
						isIncludedSelector :String, relevantProperties :[String], info :MDSDocument.PropertyMap,
						isUpToDate :Bool)
	static	let	collectionPutEndpoint =
						JSONHTTPEndpoint<[String : Any], CollectionPutEndpointInfo>(method: .put,
								path: "/collection/:documentStorageID")
								{ (urlComponents, headers, info) -> CollectionPutEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]

									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let documentType = info["documentType"] as? String else {
										// Missing documentType
										throw HTTPEndpointError.badRequest(with: "missing documentType")
									}
									guard let version = info["version"] as? UInt else {
										// Missing version
										throw HTTPEndpointError.badRequest(with: "missing version")
									}
									guard let isIncludedSelector = info["isIncludedSelector"] as? String else {
										// Missing isIncludedSelector
										throw HTTPEndpointError.badRequest(with: "missing isIncludedSelector")
									}
									guard let relevantProperties = info["relevantProperties"] as? [String] else {
										// Missing relevantProperties
										throw HTTPEndpointError.badRequest(with: "missing relevantProperties")
									}
									guard let updateInfo = info["info"] as? MDSDocument.PropertyMap else {
										// Missing info
										throw HTTPEndpointError.badRequest(with: "missing info")
									}
									guard let isUpToDate = info["isUpToDate"] as? Bool else {
										// Missing isUpToDate
										throw HTTPEndpointError.badRequest(with: "missing isUpToDate")
									}

									return (documentStorageID, name, documentType, version, isIncludedSelector,
											relevantProperties, updateInfo, isUpToDate)
								}
	static func httpEndpointRequestForPutCollection(documentStorageID :String, name :String, documentType :String,
			version :UInt, info :[String : Any], isUpToDate :Bool, isIncludedSelector :String) ->
			SuccessHTTPEndpointRequest {
		// Return endpoint request
		return SuccessHTTPEndpointRequest(method: .put, path: "/collection/\(documentStorageID)",
				jsonBody: [
							"name": name,
							"documentType": documentType,
							"version": version,
							"info": info,
							"isUpToDate": isUpToDate ? 1 : 0,
							"isIncludedSelector": isIncludedSelector,
						  ])
	}

	// MARK: Patch Collection
	//	=> json (body)
	//		{
	//			"documentCount" :Int,
	//		}
	typealias CollectionPatchEndpointInfo = (documentStorageID :String, name :String, documentCount :Int)
	static	let	collectionPatchEndpoint =
						JSONHTTPEndpoint<[String : Any], CollectionPatchEndpointInfo>(method: .patch,
								path: "/collection/:documentStorageID/:name")
								{ (urlComponents, headers, info) -> CollectionPatchEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]
									let	name = pathComponents[2]

									guard let documentCount = info["documentCount"] as? Int else {
										// Missing documentCount
										throw HTTPEndpointError.badRequest(with: "missing documentCount")
									}

									return (documentStorageID, name, documentCount)
								}
	static func httpEndpointRequestForPatchCollection(documentStorageID :String, name :String, documentCount :Int) ->
			SuccessHTTPEndpointRequest {
		// Return endpoint request
		return SuccessHTTPEndpointRequest(method: .patch, path: "/collection/\(documentStorageID)/\(name)",
				jsonBody: ["documentCount": documentCount])
	}

	// MARK: GET Index
	//	=> key (query) (can specify multiple)
	//	=> fullInfo (query) optional, "0" or "1", defaults to "0"
	//
	//	<= Documents return info
	typealias IndexGetEndpointInfo = (documentStorageID :String, name :String, keys :[String], fullInfo :Bool)
	static	let	indexGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/index/:documentStorageID/:name")
								{ (urlComponents, headers) -> IndexGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]
									let	name = pathComponents[2]

									let	queryItemsMap = urlComponents.queryItemsMap
									guard let keys = queryItemsMap.stringArray(for: "keys") else {
										// Missing keys
										throw HTTPEndpointError.badRequest(with: "keys")
									}
									let	fullInfo = ((queryItemsMap["fullInfo"] as? String) ?? "") == "1"

									return (documentStorageID, name, keys, fullInfo)
								}
	static func httpEndpointRequestForGetIndexRevision(documentStorageID :String, name :String, keys :[String]) ->
			DocumentRevisionMapHTTPEndpointRequest {
		// Return endpoint request
		return DocumentRevisionMapHTTPEndpointRequest(method: .get, path: "/index/\(documentStorageID)/\(name)",
				queryComponents: [
									"key": keys,
									"fullInfo": 0,
								 ])
	}
	static func httpEndpointRequestForGetIndexInfo(documentStorageID :String, name :String, keys :[String]) ->
			DocumentInfoMapHTTPEndpointRequest {
		// Return endpoint request
		return DocumentInfoMapHTTPEndpointRequest(method: .get, path: "/index/\(documentStorageID)/\(name)",
				queryComponents: [
									"key": keys,
									"fullInfo": 1,
								 ])
	}

	// MARK: PUT Index
	//	=> json (body)
	//		{
	//			"name" :String,
	//			"documentType" :String,
	//			"version" :Int,
	//			"keySelector" :String,
	//			"relevantProperties" :(optional) [String]
	//		}
	typealias IndexPutEndpointInfo =
				(documentStorageID :String, name :String, documentType :String, version :UInt, keySelector :String,
						relevantProperties :[String])
	static	let	indexPutEndpoint =
						JSONHTTPEndpoint<[String : Any], IndexPutEndpointInfo>(method: .put,
								path: "/index/:documentStorageID")
								{ (urlComponents, headers, info) -> IndexPutEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]

									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let documentType = info["documentType"] as? String else {
										// Missing documentType
										throw HTTPEndpointError.badRequest(with: "missing documentType")
									}
									guard let version = info["version"] as? UInt else {
										// Missing version
										throw HTTPEndpointError.badRequest(with: "missing version")
									}
									guard let keySelector = info["keySelector"] as? String else {
										// Missing keySelector
										throw HTTPEndpointError.badRequest(with: "missing keySelector")
									}
									guard let relevantProperties = info["relevantProperties"] as? [String] else {
										// Missing relevantProperties
										throw HTTPEndpointError.badRequest(with: "missing relevantProperties")
									}

									return (documentStorageID, name, documentType, version, keySelector,
											relevantProperties)
								}
	static func httpEndpointRequestForPutIndex(documentStorageID :String, name :String, documentType :String,
			version :UInt, keySelector :String) -> SuccessHTTPEndpointRequest {
		// Return endpoint request
		return SuccessHTTPEndpointRequest(method: .put, path: "/index/\(documentStorageID)",
				jsonBody: [
							"name": name,
							"documentType": documentType,
							"version": version,
							"keySelector": keySelector,
						  ])
	}

	// MARK: Patch Index
	//	=> json (body)
	//		{
	//			"documentCount" :Int,
	//		}
	typealias IndexPatchEndpointInfo = (documentStorageID :String, name :String, documentCount :Int)
	static	let	indexPatchEndpoint =
						JSONHTTPEndpoint<[String : Any], IndexPatchEndpointInfo>(method: .patch,
								path: "/index/:documentStorageID/:name")
								{ (urlComponents, headers, info) -> IndexPatchEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]
									let	name = pathComponents[2]

									guard let documentCount = info["documentCount"] as? Int else {
										// Missing documentCount
										throw HTTPEndpointError.badRequest(with: "missing documentCount")
									}

									return (documentStorageID, name, documentCount)
								}
	static func httpEndpointRequestForPatchIndex(documentStorageID :String, name :String, documentCount :Int) ->
			SuccessHTTPEndpointRequest {
		// Return endpoint request
		return SuccessHTTPEndpointRequest(method: .patch, path: "/index/\(documentStorageID)/\(name)",
				jsonBody: ["documentCount" : documentCount])
	}

	// MARK: GET Info
	//	=> key (query) (can specify multiple)
	//
	//	<= [
	//		"key" :String
	//		...
	//	   ]
	typealias InfoGetEndpointInfo = (documentStorageID :String, keys :[String])
	static	let	infoGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/info/:documentStorageID")
								{ (urlComponents, headers) -> InfoGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]

									guard let keys = urlComponents.queryItemsMap.stringArray(for: "key") else {
										// Keys not specified
										throw HTTPEndpointError.badRequest(with: "missing key(s) in query")
									}

									return (documentStorageID, keys)
								}
	static func httpEndpointRequestForGetInfo(documentStorageID :String, keys :[String]) ->
			JSONHTTPEndpointRequest<[String : String]> {
		// Return endpoint request
		return JSONHTTPEndpointRequest(method: .get, path: "/info/\(documentStorageID)",
				queryComponents: ["key": keys])
	}

	//MARK: POST Info
	//	=> json (body)
	//		[
	//			"key" :String
	//			...
	//		]
	typealias InfoPostEndpointInfo = (documentStorageID :String, info :[String : String])
	static	let	infoPostEndpoint =
						JSONHTTPEndpoint<[String : String], InfoPostEndpointInfo>(method: .post,
								path: "/info/:documentStorageID")
								{ (urlComponents, headers, info) -> InfoPostEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[1]

									return (documentStorageID, info)
								}
	static func httpEndpointRequewstForPostInfo(documentStorageID :String, info :[String : String]) ->
			SuccessHTTPEndpointRequest {
		// Return endpoint request
		return SuccessHTTPEndpointRequest(method: .post, path: "/info/\(documentStorageID)", jsonBody: info)
	}
}
