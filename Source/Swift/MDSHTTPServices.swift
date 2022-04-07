//
//  MDSHTTPServices.swift
//  Mini Document Storage
//
//  Created by Stevo on 4/2/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocument.FullInfo extension
extension MDSDocument.FullInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"documentID": self.documentID,
					"revision": self.revision,
					"active": self.active,
					"creationDate": self.creationDate.rfc3339Extended,
					"modificationDate": self.modificationDate.rfc3339Extended,
					"json": self.propertyMap,
					"attachments": self.attachmentInfoMap,
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
		self.attachmentInfoMap =
				(httpServicesInfo["attachments"] as! [String : [String : Any]])
					.mapPairs({ ($0.key,
							MDSDocument.AttachmentInfo(id: $0.key, revision: $0.value["revision"] as! Int,
									info: $0.value["info"] as! [String : Any])) })
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument.CreateInfo
extension MDSDocument.CreateInfo {

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
// MARK: - MDSDocument.UpdateInfo extension
extension MDSDocument.UpdateInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"documentID": self.documentID,
					"updated": self.updated,
					"removed": Array(self.removed),
					"active": self.active,
				]
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServicesInfo :[String : Any]) {
		// Store
		self.documentID = httpServicesInfo["documentID"] as! String
		self.updated = httpServicesInfo["updated"] as! [String : Any]
		self.removed = Set<String>(httpServicesInfo["removed"] as! [String])
		self.active = httpServicesInfo["active"] as! Bool
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSError
enum MDSError : Error {
	case invalidRequest(message :String)
	case responseWasEmpty
	case internalError
}

extension MDSError : CustomStringConvertible, LocalizedError {

	// MARK: Properties
	public 	var	description :String { self.localizedDescription }
	public	var	errorDescription :String? {
						// What are we
						switch self {
							case .invalidRequest(let message):	return message
							case .responseWasEmpty:	return "Server response was empty"
							case .internalError:	return "Server internal error"
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSHTTPServices
class MDSHTTPServices {

	// MARK: MDSHTTPEndpointRequest
	class MDSHTTPEndpointRequest : HTTPEndpointRequest {

		// MARK: Fileprivate methods
		//--------------------------------------------------------------------------------------------------------------
		fileprivate func mdsError(for responseData :Data?) -> Error? {
			// Check situation
			if responseData != nil {
				// Catch errors
				do {
					// Try to compose info from data
					let	info = try JSONSerialization.jsonObject(with: responseData!, options: []) as? [String : String]
					if let message = info?["error"] {
						// Received error message
						return MDSError.invalidRequest(message: message)
					} else {
						// Nope
						return HTTPEndpointRequestError.unableToProcessResponseData
					}
				} catch {
					// Error
					return error
				}
			} else {
				// No response data
				return MDSError.responseWasEmpty
			}
		}
	}

	// MARK: - MDSJSONHTTPEndpointRequest
	class MDSJSONHTTPEndpointRequest<T> : MDSHTTPEndpointRequest, HTTPEndpointRequestProcessMultiResults {

		// MARK: Types
		public typealias SingleResponseCompletionProc = (_ info :T?, _ error :Error?) -> Void
		public typealias MultiResponsePartialResultsProc = (_ info :T?, _ error :Error?) -> Void
		public typealias MultiResponseCompletionProc = (_ errors :[Error]) -> Void

		// MARK: Properties
		public	var	completionProc :SingleResponseCompletionProc?
		public	var	multiResponsePartialResultsProc :MultiResponsePartialResultsProc?
		public	var	multiResponseCompletionProc :MultiResponseCompletionProc?

		private	let	completedRequestsCount = LockingNumeric<Int>()

		private	var	errors = [Error]()

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		override init(method :HTTPEndpointMethod, path :String, queryComponents :[String : Any]? = nil,
				multiValueQueryComponent :MultiValueQueryComponent? = nil, headers :[String : String]? = nil,
				timeoutInterval :TimeInterval = defaultTimeoutInterval) {
			// Update
			var	headersUse = headers ?? [:]
			headersUse["Accept"] = "application/json"

			// Do super
			super.init(method: method, path: path, queryComponents: queryComponents,
					multiValueQueryComponent: multiValueQueryComponent, headers: headersUse,
					timeoutInterval: timeoutInterval)
		}

		// MARK: HTTPEndpointRequestProcessResults methods
		//------------------------------------------------------------------------------------------------------------------
		func processResults(response :HTTPURLResponse?, data :Data?, error :Error?, totalRequests :Int) {
			// Check cancelled
			if !self.isCancelled {
				// Handle results
				var	info :T? = nil
				var	localError :Error? = nil

				if (response != nil) {
					// Have response
					let	statusCode = response!.statusCode
					if (statusCode >= 200) && (statusCode < 300) {
						// Success
						if data != nil {
							// Catch errors
							do {
								// Try to compose info from data
								info = try JSONSerialization.jsonObject(with: data!, options: []) as? T

								// Check if got response data
								if info == nil {
									// Nope
									localError = HTTPEndpointRequestError.unableToProcessResponseData
								}
							} catch {
								// Error
								localError = error
							}
						} else {
							// No payload
							localError = MDSError.responseWasEmpty
						}
					} else if (statusCode >= 400) && (statusCode < 500) {
						// Error
						localError = mdsError(for: data)
					} else if statusCode >= 500 {
						// Internal error
						localError = MDSError.internalError
					}
				} else {
					// No response
					localError = error
				}

				// Check error
				if localError != nil { self.errors.append(localError!) }

				// Call proc
				if totalRequests == 1 {
					// Single request (but could have been multiple
					if self.completionProc != nil {
						// Single response expected
						self.completionProc!(info, localError)
					} else {
						// Multi-responses possible
						self.multiResponsePartialResultsProc!(info, localError)
						self.multiResponseCompletionProc!(self.errors)
					}
				} else {
					// Multiple requests
					self.multiResponsePartialResultsProc!(info, localError)
					if self.completedRequestsCount.add(1) == totalRequests {
						// All done
						self.multiResponseCompletionProc!(self.errors)
					}
				}
			}
		}
	}

	// MARK: - Association Register
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
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

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
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put, path: "/v1/association/\(documentStorageIDUse)",
				headers: headers,
				jsonBody: [
							"name": name,
							"fromDocumentType": fromDocumentType,
							"toDocumentType": toDocumentType,
						  ])
	}

	// MARK: - Association Update
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> json (body)
	//		[
	//			{
	//				"action" :"add" or "remove"
	//				"fromID" :String
	//				"toID :String
	//			}
	//		]
	//	=> authorization (header) (optional)
	typealias UpdateAssociationEndpointInfo =
				(documentStorageID :String, name :String,
						updates :[(action :MDSAssociationAction, fromID :String, toID :String)], authorization :String?)
	static	let	updateAssocationEndpoint =
						JSONHTTPEndpoint<[[String : Any]], UpdateAssociationEndpointInfo>(method: .patch,
								path: "/v1/association/:documentStorageID/:name")
								{ (urlComponents, headers, infos) -> UpdateAssociationEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3]

									let	updates :[(action :MDSAssociationAction, fromID :String, toID :String)] =
												infos.compactMap() {
													// Get info
													guard let action =
															MDSAssociationAction(
																	rawValue: ($0["action"] as? String) ?? ""),
															let fromID = $0["fromID"] as? String,
															let toID = $0["toID"] as? String else { return nil }

													return (action, fromID, toID)
												}
									guard updates.count == infos.count else {
										// Missing/invalid action
										throw HTTPEndpointError.badRequest(with: "invalid info")
									}

									return (documentStorageID, name, updates, headers["Authorization"])
								}
	static func httpEndpointRequestForUpdateAssocation(documentStorageID :String, name :String,
			updates :[(action :MDSAssociationAction, fromID :String, toID :String)], authorization :String? = nil) ->
			SuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put,
				path: "/v1/association/\(documentStorageIDUse)/\(name)", headers: headers,
				jsonBody:
						updates.map() {
							[
								"action": $0.action.rawValue,
								"fromID": $0.fromID,
								"toID": $0.toID,
							]
						})
	}

	// MARK: - Association Get Document Infos
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> fromID -or- toID (query)
	//	=> startIndex (query) (optional, default is 0)
	//	=> fullInfo (query) (optional, default is false)
	//	=> authorization (header) (optional)
	//
	//	<= json
	//		{
	//			String (documentID) : Int (revision),
	//			...
	//		}
	typealias GetAssociationDocumentInfosHTTPEndpointRequest = JSONHTTPEndpointRequest<[String : Int]>
	typealias GetAssociationDocumentInfosEndpointInfo =
				(documentStorageID :String, name :String, fromDocumentID :String?, toDocumentID :String?,
						startIndex :Int, fullInfo :Bool, authorization :String?)
	static	let	getAssociationDocumentInfosEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/assocation/:documentStorageID/:name")
								{ (urlComponents, headers) -> GetAssociationDocumentInfosEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									let	fromDocumentID = queryItemsMap["fromID"] as? String
									let	toDocumentID = queryItemsMap["toID"] as? String
									let	startIndex = queryItemsMap["startIndex"] as? Int
									let	fullInfo = queryItemsMap["fullInfo"] as? Int
									guard (fromDocumentID != nil) || (toDocumentID != nil) else {
										// Missing fromID and toID
										throw HTTPEndpointError.badRequest(with: "missing fromID or toID")
									}

									return (documentStorageID, name, fromDocumentID, toDocumentID, startIndex ?? 0,
											(fullInfo ?? 0) == 1, headers["Authorization"])
								}
	static func httpEndpointRequestForGetAssociationDocumentInfos(documentStorageID :String, name :String,
			fromDocumentID :String, startIndex :Int = 0, fullInfo :Bool = false, authorization :String? = nil) ->
			GetAssociationDocumentInfosHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		// Return endpoint request
		return GetAssociationDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageIDUse)/\(name)",
				queryComponents: [
									"fromID": fromDocumentID,
									"startIndex": startIndex,
									"fullInfo": fullInfo ? 1 : 0,
								 ],
				headers: headers)
	}
	static func httpEndpointRequestForGetAssociationDocumentInfos(documentStorageID :String, name :String,
			toDocumentID :String, startIndex :Int, authorization :String? = nil) ->
			GetAssociationDocumentInfosHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		// Return endpoint request
		return GetAssociationDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageIDUse)/\(name)",
				queryComponents: [
									"toID": toDocumentID,
									"startIndex": startIndex,
								 ],
				headers: headers)
	}

	// MARK: - Association Get Value
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> toID (query)
	//	=> action (query)
	//	=> cacheName (query)
	//	=> cacheValueName (query)
	//	=> authorization (header) (optional)
	//
	//	<= HTTP Status 409 if cache is out of date => call endpoint again
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
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
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
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetAssociationValueHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageIDUse)/\(name)/value",
				queryComponents: [
									"toID": toID,
									"action": action.rawValue,
									"cacheName": cacheName,
									"cacheValueName": cacheNameValue,
								 ],
				headers: headers)
	}

	// MARK: - Cache Register
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"name" :String,
	//			"documentType" :String,
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
				(documentStorageID :String, name :String, documentType :String, relevantProperties :[String],
						valuesInfos :[RegisterCacheEndpointValueInfo], authorization :String?)
	static	let	registerCacheEndpoint =
						JSONHTTPEndpoint<[String : Any], RegisterCacheEndpointInfo>(method: .put,
								path: "/v1/cache/:documentStorageID")
								{ (urlComponents, headers, info) -> RegisterCacheEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let documentType = info["documentType"] as? String else {
										// Missing documentType
										throw HTTPEndpointError.badRequest(with: "missing documentType")
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

									return (documentStorageID, name, documentType, relevantProperties, valuesInfos,
											headers["Authorization"])
								}
	static func httpEndpointRequestForRegisterCache(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], valueInfos :[RegisterCacheEndpointValueInfo],
			authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil
		let	valuesInfosTransformed =
					valueInfos.map({ [
										"name": $0.name,
										"valueType": $0.valueType.rawValue,
										"selector": $0.selector,
									  ] })

		return SuccessHTTPEndpointRequest(method: .put, path: "/v1/cache/\(documentStorageIDUse)", headers: headers,
				jsonBody: [
							"name": name,
							"documentType": documentType,
							"relevantProperties": relevantProperties,
							"valuesInfos": valuesInfosTransformed,
						  ])
	}

	// MARK: - Collection Register
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"name" :String,
	//			"documentType" :String,
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
				(documentStorageID :String, name :String, documentType :String, relevantProperties :[String],
						isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
						authorization :String?)
	static	let	registerCollectionEndpoint =
						JSONHTTPEndpoint<[String : Any], RegisterCollectionEndpointInfo>(method: .put,
								path: "/v1/collection/:documentStorageID")
								{ (urlComponents, headers, info) -> RegisterCollectionEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let documentType = info["documentType"] as? String else {
										// Missing documentType
										throw HTTPEndpointError.badRequest(with: "missing documentType")
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

									return (documentStorageID, name, documentType, relevantProperties, isUpToDate,
											isIncludedSelector, isIncludedSelectorInfo, headers["Authorization"])
								}
	static func httpEndpointRequestForRegisterCollection(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], isUpToDate :Bool = false, isIncludedSelector :String,
			isIncludedSelectorInfo :[String : Any] = [:], authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put, path: "/v1/collection/\(documentStorageIDUse)",
				headers: headers,
				jsonBody: [
							"name": name,
							"documentType": documentType,
							"relevantProperties": relevantProperties,
							"isUpToDate": isUpToDate ? 1 : 0,
							"isIncludedSelector": isIncludedSelector,
							"isIncludedSelectorInfo": isIncludedSelectorInfo,
					  ])
	}

	// MARK: - Collection Get Document Count
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
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, name, headers["Authorization"])
								}
	static func httpEndpointRequestForGetCollectionDocumentCount(documentStorageID :String, name :String,
			authorization :String? = nil) -> GetCollectionDocumentCountHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	nameUse = name.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetCollectionDocumentCountHTTPEndpointRequest(method: .head,
				path: "/v1/collection/\(documentStorageIDUse)/\(nameUse)", headers: headers)
	}

	// MARK: - Collection Get Document Infos
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> startIndex (query) (optional, default is 0)
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
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, name, headers["Authorization"])
								}
	static func httpEndpointRequestForGetCollectionDocumentInfos(documentStorageID :String, name :String,
			startIndex :Int = 0, authorization :String? = nil) -> GetCollectionDocumentInfosHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	nameUse = name.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		// Return endpoint request
		return GetCollectionDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/collection/\(documentStorageIDUse)/\(nameUse)", queryComponents: ["startIndex": startIndex],
				headers: headers)
	}

	// MARK: - Document Create
	//	=> documentStorageID (path)
	//	=> documentType (path)
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
				(documentStorageID :String, documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
						authorization :String?)
	static	let	createDocumentsEndpoint =
						JSONHTTPEndpoint<Any, CreateDocumentsEndpointInfo>(method: .post,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> CreateDocumentsEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]

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
												infos.map() { MDSDocument.CreateInfo(httpServicesInfo: $0) }

									return (documentStorageID, documentType, documentCreateInfos,
											headers["Authorization"])
								}
	static func httpEndpointRequestForCreateDocuments(documentStorageID :String, documentType :String,
			documentCreateInfos :[MDSDocument.CreateInfo], authorization :String? = nil) ->
			JSONHTTPEndpointRequest<[[String : Any]]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return JSONHTTPEndpointRequest<[[String : Any]]>(method: .post,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)", headers: headers,
				jsonBody: documentCreateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: - Document Get
	//	=> documentStorageID (path)
	//	=> documentType (path)
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
	//				"attachments":
	//						{
	//							id :
	//								{
	//									"revision" :Int,
	//									"info" :{
	//												"key" :Any,
	//												...
	//											},
	//								},
	//								..
	//						}
	//			},
	//			...
	//		]
	class GetDocumentsSinceRevisionHTTPEndpointRequest : JSONHTTPEndpointRequest<[[String : Any]]> {}
	class GetDocumentsForDocumentIDsHTTPEndpointRequest : JSONHTTPEndpointRequest<[[String : Any]]> {}
	typealias GetDocumentsEndpointInfo =
				(documentStorageID :String, documentType :String, documentIDs :[String]?, sinceRevision :Int?,
						authorization :String?)
	static	let	getDocumentsEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers) -> GetDocumentsEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									let	documentIDs = queryItemsMap.stringArray(for: "id")
									let	sinceRevision = Int(queryItemsMap["sinceRevision"] as? String)
									guard (documentIDs != nil) || (sinceRevision != nil) else {
										// Query info not specified
										throw HTTPEndpointError.badRequest(
												with: "missing id(s) or sinceRevision in query")
									}

									return (documentStorageID, documentType, documentIDs, sinceRevision,
											headers["Authorization"])
								}
	static func httpEndpointRequestForGetDocuments(documentStorageID :String, documentType :String, sinceRevision :Int,
			authorization :String? = nil) -> GetDocumentsSinceRevisionHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetDocumentsSinceRevisionHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)",
				queryComponents: ["sinceRevision": sinceRevision], headers: headers)
	}
	static func httpEndpointRequestForGetDocuments(documentStorageID :String, documentType :String,
			documentIDs :[String], authorization :String? = nil) -> GetDocumentsForDocumentIDsHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetDocumentsForDocumentIDsHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)",
				multiValueQueryComponent: ("id", documentIDs), headers: headers)
	}

	// MARK: - Document Update
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> json (body)
	//		[
	//			{
	//				"documentID" :String
	//				"updated" :{
	//								"key" :Any,
	//								...
	//						   }
	//				"removed" :[
	//								"key",
	//								...
	//						   ]
	//				"active" :0/1
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
	//				"active" :0/1,
	//				"modificationDate" :String,
	//				"json" :{
	//							"key" :Any,
	//							...
	//						},
	//			},
	//			...
	//		]
	typealias UpdateDocumentsEndpointInfo =
				(documentStorageID :String, documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo],
						authorization :String?)
	static	let	updateDocumentsEndpoint =
						JSONHTTPEndpoint<Any, UpdateDocumentsEndpointInfo>(method: .patch,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> UpdateDocumentsEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]

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
												infos.map() { MDSDocument.UpdateInfo(httpServicesInfo: $0) }

									return (documentStorageID, documentType, documentUpdateInfos,
											headers["Authorization"])
								}
	static func httpEndpointRequestForUpdateDocuments(documentStorageID :String, documentType :String,
			documentUpdateInfos :[MDSDocument.UpdateInfo], authorization :String? = nil) ->
			JSONHTTPEndpointRequest<[[String : Any]]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return JSONHTTPEndpointRequest<[[String : Any]]>(method: .patch,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)", headers: headers,
				jsonBody: documentUpdateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: - Document Add Attachment
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> documentID (path)
	//	=> info (body)
	//	=> content (body)
	//	=> authorization (header) (optional)
	//
	//	<= json
	//		{
	//			"id" :String,
	//		}
	static func httpEndpointRequestForAddDocumentAttachment(documentStorageID :String, documentType :String,
			documentID :String, info :[String : Any], content :Data, authorization :String? = nil) ->
			JSONHTTPEndpointRequest<[String : Any]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	documentIDUse = documentID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return JSONHTTPEndpointRequest<[String : Any]>(method: .post,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)/\(documentIDUse)/attachment",
				headers: headers, jsonBody: ["info": info, "content": content.base64EncodedString()])
	}

	// MARK: - Document Get Attachment
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> documentID (path)
	//	=> attachmentID (path)
	//	=> authorization (header) (optional)
	//
	//	<= data
	static func httpEndpointRequestForGetDocumentAttachment(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, authorization :String? = nil) -> DataHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	documentIDUse = documentID.replacingOccurrences(of: "/", with: "_")
		let	attachmentIDUse = attachmentID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return DataHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers)
	}

	// MARK: - Document Update Attachment
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> documentID (path)
	//	=> attachmentID (path)
	//	=> info (body)
	//	=> content (body)
	//	=> authorization (header) (optional)
	static func httpEndpointRequestForUpdateDocumentAttachment(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, info :[String : Any], content :Data,
			authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	documentIDUse = documentID.replacingOccurrences(of: "/", with: "_")
		let	attachmentIDUse = attachmentID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .patch,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers, jsonBody: ["info": info, "content": content.base64EncodedString()])
	}

	// MARK: - Document Remove Attachment
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> documentID (path)
	//	=> attachmentID (path)
	//	=> authorization (header) (optional)
	static func httpEndpointRequestForRemoveDocumentAttachment(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	documentIDUse = documentID.replacingOccurrences(of: "/", with: "_")
		let	attachmentIDUse = attachmentID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .delete,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers)
	}

	// MARK: - Index Register
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"name" :String,
	//			"documentType" :String,
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
				(documentStorageID :String, name :String, documentType :String, relevantProperties :[String],
						isUpToDate :Bool, keysSelector :String, keysSelectorInfo: [String : Any],
						authorization :String?)
	static	let	registerIndexEndpoint =
						JSONHTTPEndpoint<[String : Any], RegisterIndexEndpointInfo>(method: .put,
								path: "/v1/index/:documentStorageID")
								{ (urlComponents, headers, info) -> RegisterIndexEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let documentType = info["documentType"] as? String else {
										// Missing documentType
										throw HTTPEndpointError.badRequest(with: "missing documentType")
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

									return (documentStorageID, name, documentType, relevantProperties, isUpToDate,
											keysSelector, keysSelectorInfo, headers["Authorization"])
								}
	static func httpEndpointRequestForRegisterIndex(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], isUpToDate :Bool = false, keysSelector :String,
			keysSelectorInfo :[String : Any] = [:], authorization :String? = nil) -> SuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return SuccessHTTPEndpointRequest(method: .put, path: "/v1/index/\(documentStorageIDUse)", headers: headers,
				jsonBody: [
							"name": name,
							"documentType": documentType,
							"relevantProperties": relevantProperties,
							"isUpToDate": isUpToDate ? 1 : 0,
							"keysSelector": keysSelector,
							"keysSelectorInfo": keysSelectorInfo,
						  ])
	}

	// MARK: - Index Get Document Infos
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
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3].replacingOccurrences(of: "_", with: "/")

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
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	nameUse = name.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return GetIndexDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/index/\(documentStorageIDUse)/\(nameUse)", multiValueQueryComponent: ("key", keys),
				headers: headers)
	}

	// MARK: - Info Get
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
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									guard let keys = urlComponents.queryItemsMap.stringArray(for: "key") else {
										// Keys not specified
										throw HTTPEndpointError.badRequest(with: "missing key(s) in query")
									}

									return (documentStorageID, keys, headers["Authorization"])
								}
	static func httpEndpointRequestForGetInfo(documentStorageID :String, keys :[String], authorization :String? = nil)
			-> MDSJSONHTTPEndpointRequest<[String : String]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest(method: .get, path: "/v1/info/\(documentStorageIDUse)",
				multiValueQueryComponent: ("key", keys), headers: headers)
	}

	//MARK: - Info Set
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
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, info, headers["Authorization"])
								}
	static func httpEndpointRequestForSetInfo(documentStorageID :String, info :[String : String],
			authorization :String? = nil) -> JSONHTTPEndpointRequest<[String : String]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return JSONHTTPEndpointRequest(method: .post, path: "/v1/info/\(documentStorageIDUse)", headers: headers,
				jsonBody: info)
	}
}
