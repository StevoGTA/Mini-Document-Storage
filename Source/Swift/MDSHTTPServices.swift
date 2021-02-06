//
//  MDSHTTPServices.swift
//  Mini Document Storage
//
//  Created by Stevo on 4/2/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentFullInfo extension
extension MDSDocumentFullInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"documentID": self.documentID,
					"revision": self.revision,
					"active": self.active,
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
		self.active = httpServicesInfo["active"] as! Bool
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
				var	info :[String : Any] =
							[
								"documentID": self.documentID,
								"json": self.propertyMap,
							]
				info["creationDate"] = self.creationDate?.rfc3339Extended
				info["modificationDate"] = self.modificationDate?.rfc3339Extended

				return info
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServicesInfo :[String : Any]) {
		// Store
		self.documentID = httpServicesInfo["documentID"] as! String
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

	// MARK: Get Info
	//	=> documentStorageID (path)
	//	=> key (query) (can specify multiple)
	//	=> authorization (header) (optional)
	//
	//	<= [
	//		"key" :String
	//		...
	//	   ]
	typealias GetInfoEndpointInfo = (documentStorageID :String, keys :[String], authorization :String?)
	static	let	getInfoEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/info/:documentStorageID")
								{ (urlComponents, headers) -> GetInfoEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]

									guard let keys = urlComponents.queryItemsMap.stringArray(for: "key") else {
										// Keys not specified
										throw HTTPEndpointError.badRequest(with: "missing key(s) in query")
									}

									return (documentStorageID, keys, headers["Authorization"])
								}
	static func httpEndpointRequestForGetInfo(documentStorageID :String, keys :[String], authorization :String? = nil)
			-> JSONHTTPEndpointRequest<[String : String]> {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return JSONHTTPEndpointRequest(method: .get, path: "/v1/info/\(documentStorageID)",
				multiValueQueryComponent: ("key", keys), headers: headers)
	}

	//MARK: Set Info
	//	=> documentStorageID (path)
	//	=> json (body)
	//		[
	//			"key" :String
	//			...
	//		]
	//	=> authorization (header) (optional)
	typealias SetInfoEndpointInfo = (documentStorageID :String, info :[String : String], authorization :String?)
	static	let	setInfoEndpoint =
						JSONHTTPEndpoint<[String : String], SetInfoEndpointInfo>(method: .post,
								path: "/v1/info/:documentStorageID")
								{ (urlComponents, headers, info) -> SetInfoEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]

									return (documentStorageID, info, headers["Authorization"])
								}
	static func httpEndpointRequewstForSetInfo(documentStorageID :String, info :[String : String],
			authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .post, path: "/v1/info/\(documentStorageID)", headers: headers,
				jsonBody: info)
	}

	// MARK: Get Documents
	//	=> documentStorageID (path)
	//	=> type (path)
	//	=> sinceRevision (query)
	//		-or-
	//	=> id (query) (can specify multiple)
	//	=> authorization (header) (optional)
	//
	//	<= json
	//		[
	//			{
	//				"documentID" :String,
	//				"revision" :Int,
	//				"active" :0/1,
	//				"creationDate" :String,
	//				"modificationDate" :String,
	//				"json" :{
	//							"key" :Any,
	//							...
	//						},
	//			},
	//			...
	//		]
	class GetDocumentsSinceRevisionHTTPEndpointRequest : JSONHTTPEndpointRequest<[[String : Any]]> {}
	class GetDocumentsForDocumentIDsHTTPEndpointRequest : JSONHTTPEndpointRequest<[[String : Any]]> {}
	typealias GetDocumentsEndpointInfo =
				(documentStorageID :String, type :String, documentIDs :[String]?, sinceRevision :Int?,
						authorization :String?)
	static	let	getDocumentsEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers) -> GetDocumentsEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	type = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									let	documentIDs = queryItemsMap.stringArray(for: "id")
									let	sinceRevision = Int(queryItemsMap["sinceRevision"] as? String)
									guard (documentIDs != nil) || (sinceRevision != nil) else {
										// Query info not specified
										throw HTTPEndpointError.badRequest(
												with: "missing id(s) or sinceRevision in query")
									}

									return (documentStorageID, type, documentIDs, sinceRevision,
											headers["Authorization"])
								}
	static func httpEndpointRequestForGetDocuments(documentStorageID :String, type :String, sinceRevision :Int,
			authorization :String? = nil) -> GetDocumentsSinceRevisionHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetDocumentsSinceRevisionHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageID)/\(type)", queryComponents: ["sinceRevision": sinceRevision],
				headers: headers)
	}
	static func httpEndpointRequestForGetDocuments(documentStorageID :String, type :String, documentIDs :[String],
			authorization :String? = nil) -> GetDocumentsForDocumentIDsHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetDocumentsForDocumentIDsHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageID)/\(type)", multiValueQueryComponent: ("id", documentIDs),
				headers: headers)
	}

	// MARK: Create Documents
	//	=> documentStorageID (path)
	//	=> type (path)
	//	=> json (body)
	//		[
	//			{
	//				"documentID" :String (optional)
	//				"creationDate" :String (optional)
	//				"modificationDate" :String (optional)
	//				"json" :{
	//							"key" :Any,
	//							...
	//						}
	//			},
	//			...
	//		]
	//	=> authorization (header) (optional)
	//
	//	<= json
	//		[
	//			{
	//				"documentID" :String,
	//				"revision" :Int,
	//				"creationDate" :String,
	//				"modificationDate" :String,
	//			},
	//			...
	//		]
	typealias CreateDocumentsEndpointInfo =
				(documentStorageID :String, type :String, documentCreateInfos :[MDSDocumentCreateInfo],
						authorization :String?)
	static	let	createDocumentsEndpoint =
						JSONHTTPEndpoint<Any, CreateDocumentsEndpointInfo>(method: .post,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> CreateDocumentsEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	type = pathComponents[3]

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

									return (documentStorageID, type, documentCreateInfos, headers["Authorization"])
								}
	static func httpEndpointRequestForCreateDocuments(documentStorageID :String, type :String,
			documentCreateInfos :[MDSDocumentCreateInfo], authorization :String? = nil) ->
			JSONHTTPEndpointRequest<[[String : Any]]> {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return JSONHTTPEndpointRequest<[[String : Any]]>(method: .post,
				path: "/v1/document/\(documentStorageID)/\(type)", headers: headers,
				jsonBody: documentCreateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: Update Documents
	//	=> documentStorageID (path)
	//	=> type (path)
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
	//	=> authorization (header) (optional)
	typealias UpdateDocumentsEndpointInfo =
				(documentStorageID :String, type :String, documentUpdateInfos :[MDSDocumentUpdateInfo],
						authorization :String?)
	static	let	updateDocumentsEndpoint =
						JSONHTTPEndpoint<Any, UpdateDocumentsEndpointInfo>(method: .patch,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> UpdateDocumentsEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	type = pathComponents[3]

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

									return (documentStorageID, type, documentUpdateInfos, headers["Authorization"])
								}
	static func httpEndpointRequestForUpdateDocuments(documentStorageID :String, type :String,
			documentUpdateInfos :[MDSDocumentUpdateInfo], authorization :String? = nil) ->
			JSONHTTPEndpointRequest<[[String : Any]]> {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return JSONHTTPEndpointRequest<[[String : Any]]>(method: .patch,
				path: "/v1/document/\(documentStorageID)/\(type)", headers: headers,
				jsonBody: documentUpdateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: Register Association
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"name" :String
	//			"fromDocumentType" :String,
	//			"toDocumentType" :String,
	//		}
	//	=> authorization (header) (optional)
	typealias RegisterAssociationEndpointInfo = (documentStorageID :String, name :String, authorization :String?)
	static	let	registerAssociationEndpoint =
						JSONHTTPEndpoint<[String : Any], RegisterAssociationEndpointInfo>(method: .put,
								path: "/v1/association/:documentStorageID")
								{ (urlComponents, headers, info) -> RegisterAssociationEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]

									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}

									return (documentStorageID, name, headers["Authorization"])
								}
	static func httpEndpointRequestForRegisterAssociation(documentStorageID :String, name :String,
			fromDocumentType :String, toDocumentType :String, authorization :String? = nil) ->
			SuccessHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put, path: "/v1/association/\(documentStorageID)", headers: headers,
				jsonBody: [
							"name": name,
							"fromDocumentType": fromDocumentType,
							"toDocumentType": toDocumentType,
						  ])
	}

	// MARK: Update Association
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> json (body)
	//		{
	//			"action" :"add", "update", or "remove"
	//			"fromID" :String
	//			"toID :String
	//		}
	//	=> authorization (header) (optional)
	enum UpdateAssocationAction : String {
		case add = "add"
		case update = "update"
		case remove = "remove"
	}
	typealias UpdateAssociationEndpointInfo =
				(documentStorageID :String, name :String, action :UpdateAssocationAction, fromID :String,
						toID :String, authorization :String?)
	static	let	updateAssocationEndpoint =
						JSONHTTPEndpoint<[String : Any], UpdateAssociationEndpointInfo>(method: .patch,
								path: "/v1/association/:documentStorageID/:name")
								{ (urlComponents, headers, info) -> UpdateAssociationEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	name = pathComponents[3]

									guard let action =
											UpdateAssocationAction(rawValue: (info["action"] as? String) ?? "") else {
										// Missing/invalid action
										throw HTTPEndpointError.badRequest(with: "missing or invalid action")
									}
									guard let fromID = info["fromID"] as? String else {
										// Missing fromID
										throw HTTPEndpointError.badRequest(with: "missing fromID")
									}
									guard let toID = info["toID"] as? String else {
										// Missing toID
										throw HTTPEndpointError.badRequest(with: "missing toID")
									}

									return (documentStorageID, name, action, fromID, toID, headers["Authorization"])
								}
	static func httpEndpointRequestForUpdateAssocation(documentStorageID :String, name :String,
			action :UpdateAssocationAction, fromID :String, toID :String, authorization :String? = nil) ->
			SuccessHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put,
				path: "/v1/association/\(documentStorageID)/\(name)", headers: headers,
				jsonBody: [
							"action": action.rawValue,
							"fromID": fromID,
							"toID": toID,
						  ])
	}

	// MARK: Get Association Document Infos
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> fromID (query) (optional) -or- toID (query) (optional)
	//	=> startIndex (query)
	//	=> authorization (header) (optional)
	//
	//	<= json
	//		{
	//			String (documentID) : Int (revision),
	//			...
	//		}
	typealias GetAssociationDocumentInfosHTTPEndpointRequest = JSONHTTPEndpointRequest<[String : Int]>
	typealias GetAssociationDocumentInfosEndpointInfo =
				(documentStorageID :String, name :String, fromID :String?, toID :String?, authorization :String?)
	static	let	getAssociationDocumentInfosEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/assocation/:documentStorageID/:name")
								{ (urlComponents, headers) -> GetAssociationDocumentInfosEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	name = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									let	fromID = queryItemsMap["fromID"] as? String
									let	toID = queryItemsMap["toID"] as? String
									guard (fromID != nil) || (toID != nil) else {
										// Missing fromID and toID
										throw HTTPEndpointError.badRequest(with: "missing fromID or toID")
									}

									return (documentStorageID, name, fromID, toID, headers["Authorization"])
								}
	static func httpEndpointRequestForGetAssociationDocumentInfos(documentStorageID :String, name :String,
			fromID :String, startIndex :Int, authorization :String? = nil) ->
			GetAssociationDocumentInfosHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		// Return endpoint request
		return GetAssociationDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageID)/\(name)",
				queryComponents: [
									"fromID": fromID,
									"startIndex": startIndex
								 ],
				headers: headers)
	}
	static func httpEndpointRequestForGetAssociationDocumentInfos(documentStorageID :String, name :String,
			toID :String, startIndex :Int, authorization :String? = nil) ->
			GetAssociationDocumentInfosHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		// Return endpoint request
		return GetAssociationDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageID)/\(name)",
				queryComponents: [
									"toID": toID,
									"startIndex": startIndex
								 ],
				headers: headers)
	}

	// MARK: Get Association Value
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> toID (query)
	//	=> action (query)
	//	=> cacheName (query)
	//	=> cacheValueName (query)
	//	=> authorization (header) (optional)
	//
	//	<= count
	enum GetAssociationValueAction : String {
		case sum = "sum"
	}
	typealias GetAssociationValueHTTPEndpointRequest = IntegerHTTPEndpointRequest
	typealias GetAssociationValueEndpointInfo =
				(documentStorageID :String, name :String, toID :String, action :GetAssociationValueAction,
						cacheName :String, cacheNameValue :String, authorization :String?)
	static	let	getAssocationValueEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/association/:documentStorageID/:name/value")
								{ (urlComponents, headers) -> GetAssociationValueEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	name = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									guard let toID = queryItemsMap["toID"] as? String else {
										// Missing toID
										throw HTTPEndpointError.badRequest(with: "missing toID")
									}
									guard let action =
											GetAssociationValueAction(
													rawValue: (queryItemsMap["action"] as? String) ?? "") else {
										// Missing/invalid action
										throw HTTPEndpointError.badRequest(with: "missing or invalid action")
									}
									guard let cacheName = queryItemsMap["cacheName"] as? String else {
										// Missing cacheName
										throw HTTPEndpointError.badRequest(with: "missing cacheName")
									}
									guard let cacheValueName = queryItemsMap["cacheValueName"] as? String else {
										// Missing cacheValueName
										throw HTTPEndpointError.badRequest(with: "missing cacheValueName")
									}

									return (documentStorageID, name, toID, action, cacheName, cacheValueName,
											headers["Authorization"])
								}
	static func httpEndpointRequestForGetAssocationValue(documentStorageID :String, name :String, toID :String,
			action :GetAssociationValueAction, cacheName :String, cacheNameValue :String, authorization :String? = nil)
			-> GetAssociationValueHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetAssociationValueHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageID)/\(name)/value",
				queryComponents: [
									"toID": toID,
									"action": action.rawValue,
									"cacheName": cacheName,
									"cacheValueName": cacheNameValue,
								 ],
				headers: headers)
	}

	// MARK: Register Cache
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"documentType" :String,
	//			"name" :String,
	//			"version" :Int,
	//			"relevantProperties" :[String]
	//			"valuesInfos" :[
	//							{
	//								"name" :String,
	//								"valueType" :"integer",
	//								"selector" :String,
	//							},
	//							...
	//				 		   ]
	//	=> authorization (header) (optional)
	typealias RegisterCacheEndpointValueInfo = (name :String, valueType :MDSValueType, selector :String)
	typealias RegisterCacheEndpointInfo =
				(documentStorageID :String, documentType :String, name :String, version :Int,
						relevantProperties :[String], valuesInfos :[RegisterCacheEndpointValueInfo],
						authorization :String?)
	static	let	registerCacheEndpoint =
						JSONHTTPEndpoint<[String : Any], RegisterCacheEndpointInfo>(method: .put,
								path: "/v1/cache/:documentStorageID")
								{ (urlComponents, headers, info) -> RegisterCacheEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]

									guard let documentType = info["documentType"] as? String else {
										// Missing documentType
										throw HTTPEndpointError.badRequest(with: "missing documentType")
									}
									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let version = info["version"] as? Int else {
										// Missing version
										throw HTTPEndpointError.badRequest(with: "missing version")
									}
									guard let relevantProperties = info["relevantProperties"] as? [String] else {
										// Missing relevantProperties
										throw HTTPEndpointError.badRequest(with: "missing relevantProperties")
									}
									guard let valuesInfosInfo = info["valuesInfos"] as? [[String : Any]] else {
										// Missing or invalid values infos
										throw HTTPEndpointError.badRequest(with: "missing or invalid valuesInfos")
									}
									let	valuesInfos =
												valuesInfosInfo.compactMap({ info -> RegisterCacheEndpointValueInfo? in
													// Setup
													guard let name = info["name"] as? String,
															let valueType = info["valueType"] as? String,
															valueType == "integer",
															let selector = info["selector"] as? String else
														{ return nil }

													return RegisterCacheEndpointValueInfo(name, .integer, selector)
												})
									guard valuesInfos.count == valuesInfosInfo.count else {
										// Invalid values infos
										throw HTTPEndpointError.badRequest(with: "invalid valuesInfos")
									}

									return (documentStorageID, documentType, name, version, relevantProperties,
											valuesInfos, headers["Authorization"])
								}
	static func httpEndpointRequestForRegisterCache(documentStorageID :String, documentType :String, name :String,
			version :Int, relevantProperties :[String] = [], valueInfos :[RegisterCacheEndpointValueInfo],
			authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	valuesInfosTransformed =
					valueInfos.map({ [
										"name": $0.name,
										"valueType": "integer",
										"selector": $0.selector,
									  ] })
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put, path: "/v1/cache/\(documentStorageID)", headers: headers,
				jsonBody: [
							"documentType": documentType,
							"name": name,
							"version": version,
							"relevantProperties": relevantProperties,
							"valuesInfos": valuesInfosTransformed,
						  ])
	}

	// MARK: Register Collection
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"documentType" :String,
	//			"name" :String,
	//			"version" :Int,
	//			"relevantProperties" :[String],
	//			"isUpToDate" :Int (0 or 1)
	//			"isIncludedSelector" :String,
	//			"isIncludedSelectorInfo" :{
	//											"key" :Any,
	//											...
	//									  },
	//		}
	//	=> authorization (header) (optional)
	typealias RegisterCollectionEndpointInfo =
				(documentStorageID :String, documentType :String, name :String, version :Int,
						relevantProperties :[String], isUpToDate :Bool, isIncludedSelector :String,
						isIncludedSelectorInfo :[String : Any], authorization :String?)
	static	let	registerCollectionEndpoint =
						JSONHTTPEndpoint<[String : Any], RegisterCollectionEndpointInfo>(method: .put,
								path: "/v1/collection/:documentStorageID")
								{ (urlComponents, headers, info) -> RegisterCollectionEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]

									guard let documentType = info["documentType"] as? String else {
										// Missing documentType
										throw HTTPEndpointError.badRequest(with: "missing documentType")
									}
									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let version = info["version"] as? Int else {
										// Missing version
										throw HTTPEndpointError.badRequest(with: "missing version")
									}
									guard let relevantProperties = info["relevantProperties"] as? [String] else {
										// Missing relevantProperties
										throw HTTPEndpointError.badRequest(with: "missing relevantProperties")
									}
									guard let isUpToDate = info["isUpToDate"] as? Bool else {
										// Missing isUpToDate
										throw HTTPEndpointError.badRequest(with: "missing isUpToDate")
									}
									guard let isIncludedSelector = info["isIncludedSelector"] as? String else {
										// Missing isIncludedSelector
										throw HTTPEndpointError.badRequest(with: "missing isIncludedSelector")
									}
									guard let isIncludedSelectorInfo =
											info["isIncludedSelectorInfo"] as? [String : Any] else {
										// Missing info
										throw HTTPEndpointError.badRequest(with: "missing isIncludedSelectorInfo")
									}

									return (documentStorageID, documentType, name, version, relevantProperties,
											isUpToDate, isIncludedSelector, isIncludedSelectorInfo,
											headers["Authorization"])
								}
	static func httpEndpointRequestForRegisterCollection(documentStorageID :String, documentType :String, name :String,
			version :Int, relevantProperties :[String] = [], isUpToDate :Bool = false, isIncludedSelector :String,
			isIncludedSelectorInfo :[String : Any] = [:], authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put, path: "/v1/collection/\(documentStorageID)", headers: headers,
				jsonBody: [
							"documentType": documentType,
							"name": name,
							"version": version,
							"relevantProperties": relevantProperties,
							"isUpToDate": isUpToDate ? 1 : 0,
							"isIncludedSelector": isIncludedSelector,
							"isIncludedSelectorInfo": isIncludedSelectorInfo,
					  ])
	}

	// MARK: Get Collection Document Count
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> authorization (header) (optional)
	//
	//	<= HTTP Status 409 if collection is out of date => call endpoint again
	//	<= count in header
	typealias GetCollectionDocumentCountHTTPEndpointRequest = HeadHTTPEndpointRequest
	typealias GetCollectionDocumentCountEndpointInfo = (documentStorageID :String, name :String, authorization :String?)
	static	let	getCollectionDocumentCountEndpoint =
						BasicHTTPEndpoint(method: .head, path: "/v1/collection/:documentStorageID/:name")
								{ (urlComponents, headers) -> GetCollectionDocumentCountEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	name = pathComponents[3]

									return (documentStorageID, name, headers["Authorization"])
								}
	static func httpEndpointRequestForGetCollectionDocumentCount(documentStorageID :String, name :String,
			authorization :String? = nil) -> GetCollectionDocumentCountHTTPEndpointRequest {
		// Setup
		let	nameUse = name.replacingOccurrences(of: "/", with: "%2F")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetCollectionDocumentCountHTTPEndpointRequest(method: .head,
				path: "/v1/collection/\(documentStorageID)/\(nameUse)", headers: headers)
	}

	// MARK: Get Collection Document Infos
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> startIndex (query)
	//	=> authorization (header) (optional)
	//
	//	<= HTTP Status 409 if collection is out of date => call endpoint again
	//	<= json
	//		{
	//			String (documentID) : Int (revision),
	//			...
	//		}
	typealias GetCollectionDocumentInfosHTTPEndpointRequest = JSONHTTPEndpointRequest<[String : Int]>
	typealias GetCollectionDocumentInfosEndpointInfo = (documentStorageID :String, name :String, authorization :String?)
	static	let	getCollectionDocumentInfosEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/collection/:documentStorageID/:name")
								{ (urlComponents, headers) -> GetCollectionDocumentInfosEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	name = pathComponents[3].replacingOccurrences(of: "%2F", with: "/")

									return (documentStorageID, name, headers["Authorization"])
								}
	static func httpEndpointRequestForGetCollectionDocumentInfos(documentStorageID :String, name :String,
			startIndex :Int, authorization :String? = nil) -> GetCollectionDocumentInfosHTTPEndpointRequest {
		// Setup
		let	nameUse = name.replacingOccurrences(of: "/", with: "%2F")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		// Return endpoint request
		return GetCollectionDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/collection/\(documentStorageID)/\(nameUse)", queryComponents: ["startIndex": startIndex],
				headers: headers)
	}

	// MARK: Register Index
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"documentType" :String,
	//			"name" :String,
	//			"version" :Int,
	//			"relevantProperties" :[String]
	//			"isUpToDate" :Int (0 or 1)
	//			"keysSelector" :String,
	//			"keysSelectorInfo" :{
	//									"key" :Any,
	//									...
	//							    },
	//		}
	//	=> authorization (header) (optional)
	typealias RegisterIndexEndpointInfo =
				(documentStorageID :String, documentType :String, name :String, version :Int,
						relevantProperties :[String], isUpToDate :Bool, keysSelector :String,
						keysSelectorInfo: [String : Any], authorization :String?)
	static	let	registerIndexEndpoint =
						JSONHTTPEndpoint<[String : Any], RegisterIndexEndpointInfo>(method: .put,
								path: "/v1/index/:documentStorageID")
								{ (urlComponents, headers, info) -> RegisterIndexEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]

									guard let documentType = info["documentType"] as? String else {
										// Missing documentType
										throw HTTPEndpointError.badRequest(with: "missing documentType")
									}
									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let version = info["version"] as? Int else {
										// Missing version
										throw HTTPEndpointError.badRequest(with: "missing version")
									}
									guard let relevantProperties = info["relevantProperties"] as? [String] else {
										// Missing relevantProperties
										throw HTTPEndpointError.badRequest(with: "missing relevantProperties")
									}
									guard let isUpToDate = info["isUpToDate"] as? Bool else {
										// Missing isUpToDate
										throw HTTPEndpointError.badRequest(with: "missing isUpToDate")
									}
									guard let keysSelector = info["keysSelector"] as? String else {
										// Missing keySelector
										throw HTTPEndpointError.badRequest(with: "missing keysSelector")
									}
									guard let keysSelectorInfo =
											info["keysSelectorInfo"] as? [String : Any] else {
										// Missing info
										throw HTTPEndpointError.badRequest(with: "missing keysSelectorInfo")
									}

									return (documentStorageID, documentType, name, version, relevantProperties,
											isUpToDate, keysSelector, keysSelectorInfo, headers["Authorization"])
								}
	static func httpEndpointRequestForRegisterIndex(documentStorageID :String, documentType :String, name :String,
			version :Int, relevantProperties :[String] = [], isUpToDate :Bool = false, keysSelector :String,
			keysSelectorInfo :[String : Any] = [:], authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put, path: "/v1/index/\(documentStorageID)", headers: headers,
				jsonBody: [
							"name": name,
							"documentType": documentType,
							"version": version,
							"relevantProperties": relevantProperties,
							"isUpToDate": isUpToDate ? 1 : 0,
							"keysSelector": keysSelector,
							"keysSelectorInfo": keysSelectorInfo,
						  ])
	}

	// MARK: Get Index Document Infos
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> key (query) (can specify multiple)
	//	=> authorization (header) (optional)
	//
	//	<= HTTP Status 409 if collection is out of date => call endpoint again
	//	<= json
	//		{
	//			String (key) :
	//				{
	//					String (documentID) : Int (revision)
	//				}
	//			...
	//		}
	typealias GetIndexDocumentInfosHTTPEndpointRequest = JSONHTTPEndpointRequest<[String : [String : Int]]>
	typealias GetIndexDocumentInfosEndpointInfo =
				(documentStorageID :String, name :String, keys :[String], authorization :String?)
	static	let	getIndexDocumentInfosEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/index/:documentStorageID/:name")
								{ (urlComponents, headers) -> GetIndexDocumentInfosEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2]
									let	name = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									guard let keys = queryItemsMap.stringArray(for: "keys") else {
										// Missing keys
										throw HTTPEndpointError.badRequest(with: "keys")
									}

									return (documentStorageID, name, keys, headers["Authorization"])
								}
	static func httpEndpointRequestForGetIndexDocumentInfos(documentStorageID :String, name :String, keys :[String],
			authorization :String? = nil) -> GetIndexDocumentInfosHTTPEndpointRequest {
		// Setup
		let	nameUse = name.replacingOccurrences(of: "/", with: "%2F")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetIndexDocumentInfosHTTPEndpointRequest(method: .get, path: "/v1/index/\(documentStorageID)/\(nameUse)",
				multiValueQueryComponent: ("key", keys), headers: headers)
	}
}
