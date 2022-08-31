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
	case didNotReceiveSizeInHeader
	case failed(status :HTTPEndpointStatus)
	case internalError
	case unknownResponseStatus(status :HTTPEndpointStatus)
}

extension MDSError : CustomStringConvertible, LocalizedError {

	// MARK: Properties
	public 	var	description :String { self.localizedDescription }
	public	var	errorDescription :String? {
						// What are we
						switch self {
							case .invalidRequest(let message):			return message
							case .responseWasEmpty:						return "Server response was empty"
							case .didNotReceiveSizeInHeader:			return "Did not receive size in header"
							case .failed(let status):					return "Failed: \(status)"
							case .internalError:						return "Server internal error"
							case .unknownResponseStatus(let status):	return "Unknown reponse status: \(status)"
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

	// MARK: - MDSDataHTTPEndpointRequest
	class MDSDataHTTPEndpointRequest : MDSHTTPEndpointRequest, HTTPEndpointRequestProcessResults {

		// MARK: Types
		typealias	CompletionProc = (_ data :Data?, _ error :Error?) -> Void

		// MARK: Properties
		var	completionProc :CompletionProc = { _,_ in }

		// MARK: HTTPEndpointRequestProcessResults methods
		//--------------------------------------------------------------------------------------------------------------
		func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
			// Check cancelled
			if !self.isCancelled {
				// Handle results
				if response != nil {
					// Have response
					let	statusCode = response!.statusCode
					if (statusCode >= 200) && (statusCode < 300) {
						// Success
						self.completionProc(data, nil)
					} else if (statusCode >= 400) && (statusCode < 500) {
						// Error
						self.completionProc(nil, mdsError(for: data))
					} else if statusCode >= 500 {
						// Internal error
						self.completionProc(nil, MDSError.internalError)
					} else {
						// Unknown response status
						self.completionProc(nil,
								MDSError.unknownResponseStatus(status: HTTPEndpointStatus(rawValue: statusCode)!))
					}
				} else {
					// No response
					self.completionProc(nil, error)
				}
			}
		}
	}

	// MARK: - MDSHeadHTTPEndpointRequest
	class MDSHeadHTTPEndpointRequest : MDSHTTPEndpointRequest, HTTPEndpointRequestProcessResults {

		// MARK: Types
		typealias	CompletionProc = (_ count :Int?, _ error :Error?) -> Void

		// MARK: Properties
		var	completionProc :CompletionProc = { _,_ in }

		// MARK: HTTPEndpointRequestProcessResults methods
		//--------------------------------------------------------------------------------------------------------------
		func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
			// Check cancelled
			if !self.isCancelled {
				// Handle results
				if response != nil {
					// Have response
					let	statusCode = response!.statusCode
					if (statusCode >= 200) && (statusCode < 300) {
						// Success
						if let contentRange = response?.contentRange, let size = contentRange.size {
							// Success
							completionProc(Int(size), nil)
						} else {
							// Bad server
							completionProc(nil, MDSError.didNotReceiveSizeInHeader)
						}
					} else if statusCode == 409 {
						// Not up to date
						completionProc(nil, nil)
					} else if (statusCode >= 400) && (statusCode < 500) {
						// Error
						self.completionProc(nil, MDSError.failed(status: HTTPEndpointStatus(rawValue: statusCode)!))
					} else if statusCode >= 500 {
						// Internal error
						self.completionProc(nil, MDSError.internalError)
					} else {
						// Unknown response status
						self.completionProc(nil,
								MDSError.unknownResponseStatus(status: HTTPEndpointStatus(rawValue: statusCode)!))
					}
				} else {
					// Error
					completionProc(nil, error)
				}
			}
		}
	}

	// MARK: - MDSHeadWithUpToDateHTTPEndpointRequest
	class MDSHeadWithUpToDateHTTPEndpointRequest : MDSHTTPEndpointRequest, HTTPEndpointRequestProcessResults {

		// MARK: Types
		typealias	CompletionWithUpToDateProc = (_ info :(isUpToDate :Bool, count :Int?)?, _ error :Error?) -> Void

		// MARK: Properties
		var	completionWithUpToDateProc :CompletionWithUpToDateProc = { _,_ in }

		// MARK: HTTPEndpointRequestProcessResults methods
		//--------------------------------------------------------------------------------------------------------------
		func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
			// Check cancelled
			if !self.isCancelled {
				// Handle results
				if response != nil {
					// Have response
					let	statusCode = response!.statusCode
					if (statusCode >= 200) && (statusCode < 300) {
						// Success
						if let contentRange = response?.contentRange, let size = contentRange.size {
							// Success
							completionWithUpToDateProc((true, Int(size)), nil)
						} else {
							// Bad server
							completionWithUpToDateProc(nil, MDSError.didNotReceiveSizeInHeader)
						}
					} else if statusCode == 409 {
						// Not up to date
						completionWithUpToDateProc((false, nil), nil)
					} else if (statusCode >= 400) && (statusCode < 500) {
						// Error
						self.completionWithUpToDateProc(nil,
								MDSError.failed(status: HTTPEndpointStatus(rawValue: statusCode)!))
					} else if statusCode >= 500 {
						// Internal error
						self.completionWithUpToDateProc(nil, MDSError.internalError)
					} else {
						// Unknown response status
						self.completionWithUpToDateProc(nil,
								MDSError.unknownResponseStatus(status: HTTPEndpointStatus(rawValue: statusCode)!))
					}
				} else {
					// Error
					completionWithUpToDateProc(nil, error)
				}
			}
		}
	}

	// MARK: - MDSIntegerWithUpToDateHTTPEndpointRequest
	class MDSIntegerWithUpToDateHTTPEndpointRequest : MDSHTTPEndpointRequest, HTTPEndpointRequestProcessResults {

		// MARK: Types
		typealias	CompletionWithUpToDateProc = (_ info :(isUpToDate :Bool, value :Int?)?, _ error :Error?) -> Void

		// MARK: Properties
		var	completionWithUpToDateProc :CompletionWithUpToDateProc = { _,_ in }

		// MARK: HTTPEndpointRequestProcessResults methods
		//--------------------------------------------------------------------------------------------------------------
		func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
			// Check cancelled
			if !self.isCancelled {
				// Handle results
				if response != nil {
					// Have response
					let	statusCode = response!.statusCode
					if (statusCode >= 200) && (statusCode < 300) {
						// Success
						if data != nil {
							// Try to compose string from response
							if let string = String(data: data!, encoding: .utf8),
									let value = Int(string) {
								// Success
								self.completionWithUpToDateProc((true, value), nil)
							} else {
								// Unable to get string
								self.completionWithUpToDateProc(nil,
										HTTPEndpointRequestError.unableToProcessResponseData)
							}
						}
					} else if statusCode == 409 {
						// Not up to date
						completionWithUpToDateProc((false, nil), nil)
					} else if (statusCode >= 400) && (statusCode < 500) {
						// Error
						self.completionWithUpToDateProc(nil,
								MDSError.failed(status: HTTPEndpointStatus(rawValue: statusCode)!))
					} else if statusCode >= 500 {
						// Internal error
						self.completionWithUpToDateProc(nil, MDSError.internalError)
					} else {
						// Unknown response status
						self.completionWithUpToDateProc(nil,
								MDSError.unknownResponseStatus(status: HTTPEndpointStatus(rawValue: statusCode)!))
					}
				} else {
					// Error
					completionWithUpToDateProc(nil, error)
				}
			}
		}
	}

	// MARK: - MDSJSONHTTPEndpointRequest
	class MDSJSONHTTPEndpointRequest<T> : MDSHTTPEndpointRequest, HTTPEndpointRequestProcessMultiResults {

		// MARK: Types
		typealias SingleResponseCompletionProc = (_ info :T?, _ error :Error?) -> Void
		typealias SingleResponseWithCountCompletionProc = (_ info :(info :T, count :Int)?, _ error :Error?) -> Void
		typealias SingleResponseWithUpToDateAndCountCompletionProc =
					(_ isUpToDate :Bool?, _ info :(info :T, count :Int)?, _ error :Error?) -> Void
		typealias MultiResponsePartialResultsProc = (_ info :T?, _ error :Error?) -> Void
		typealias MultiResponseCompletionProc = (_ errors :[Error]) -> Void

		// MARK: Properties
				var	completionProc :SingleResponseCompletionProc?
				var	completionWithCountProc :SingleResponseWithCountCompletionProc?
				var	completionWithUpToDateAndCountProc :SingleResponseWithUpToDateAndCountCompletionProc?
				var	multiResponsePartialResultsProc :MultiResponsePartialResultsProc?
				var	multiResponseCompletionProc :MultiResponseCompletionProc?

		private	let	completedRequestsCount = LockingNumeric<Int>()

		private	var	errors = [Error]()

		// MARK: HTTPEndpointRequest methods
		//--------------------------------------------------------------------------------------------------------------
		override func adjustHeaders() {
			// Setup
			self.headers = self.headers ?? [:]
			self.headers!["Accept"] = "application/json"
		}

		// MARK: HTTPEndpointRequestProcessResults methods
		//--------------------------------------------------------------------------------------------------------------
		func processResults(response :HTTPURLResponse?, data :Data?, error :Error?, totalRequests :Int) {
			// Check cancelled
			if !self.isCancelled {
				// Handle results
				var	info :T? = nil
				var	localError :Error? = nil

				if response != nil {
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
					} else if statusCode == 409 {
						// Not up to date
						localError = error
					} else if (statusCode >= 400) && (statusCode < 500) {
						// Error
						localError = mdsError(for: data)
					} else if statusCode >= 500 {
						// Internal error
						localError = MDSError.internalError
					} else {
						// Unknown response status
						localError = MDSError.unknownResponseStatus(status: HTTPEndpointStatus(rawValue: statusCode)!)
					}
				} else {
					// No response
					localError = error
				}

				// Check error
				if localError != nil { self.errors.append(localError!) }

				// Call proc
				if totalRequests == 1 {
					// Single request, check desired completion approach
					if self.completionProc != nil {
						// Single response expected
						self.completionProc!(info, localError)
					} else if self.completionWithCountProc != nil {
						// Single response expected with count
						if info != nil {
							// Got info
							if let contentRange = response!.contentRange, let size = contentRange.size {
								// Got size
								self.completionWithCountProc!((info!, Int(size)), nil)
							} else {
								// Did not get size
								self.completionWithCountProc!(nil,
										MDSError.invalidRequest(message: "Missing content range size"))
							}
						} else {
							// No info
							self.completionWithCountProc!(nil, localError);
						}
					} else if self.completionWithUpToDateAndCountProc != nil {
						// Single response expected with count, but could be not up to date
						if info != nil {
							// Got info
							if let contentRange = response!.contentRange, let size = contentRange.size {
								// Got size
								self.completionWithUpToDateAndCountProc!(true, (info!, Int(size)), nil)
							} else {
								// Did not get size
								self.completionWithUpToDateAndCountProc!(nil, nil,
										MDSError.invalidRequest(message: "Missing content range size"))
							}
						} else if response != nil, HTTPEndpointStatus(rawValue: response!.statusCode)! == .conflict {
							// Not up to date
							self.completionWithUpToDateAndCountProc!(false, nil, nil)
						} else {
							// Error
							self.completionWithUpToDateAndCountProc!(nil, nil, localError)
						}
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

	// MARK: - MDSSuccessHTTPEndpointRequest
	class MDSSuccessHTTPEndpointRequest : MDSHTTPEndpointRequest, HTTPEndpointRequestProcessResults {

		// MARK: Types
		typealias	CompletionProc = (_ error :Error?) -> Void

		// MARK: Properties
		var	completionProc :CompletionProc = { _ in }

		// MARK: HTTPEndpointRequestProcessResults methods
		//--------------------------------------------------------------------------------------------------------------
		func processResults(response :HTTPURLResponse?, data :Data?, error :Error?) {
			// Check cancelled
			if !self.isCancelled {
				// Handle results
				if response != nil {
					// Have response
					let	statusCode = response!.statusCode
					if (statusCode >= 200) && (statusCode < 300) {
						// Success
						self.completionProc(nil)
					} else if (statusCode >= 400) && (statusCode < 500) {
						// Error
						self.completionProc(mdsError(for: data))
					} else if statusCode >= 500 {
						// Internal error
						self.completionProc(MDSError.internalError)
					}
				} else {
					// No response
					self.completionProc(error)
				}
			}
		}
	}

	// MARK: - General HTTPEndpointRequests
	class GetDocumentInfosHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[[String : Any]]> {}
	class GetDocumentsHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[[String : Any]]> {}

	// MARK: - Association Register
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"name" :String
	//			"fromDocumentType" :String,
	//			"toDocumentType" :String,
	//		}
	//	=> authorization (header) (optional)
	typealias AssociationRegisterEndpointInfo =
			(documentStorageID :String, name :String, fromDocumentType :String, toDOcumentType :String,
					authorization :String?)
	static	let	associationRegisteEndpoint =
						JSONHTTPEndpoint<[String : Any], AssociationRegisterEndpointInfo>(method: .put,
								path: "/v1/association/:documentStorageID")
								{ (urlComponents, headers, info) -> AssociationRegisterEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									guard let name = info["name"] as? String else {
										// Missing name
										throw HTTPEndpointError.badRequest(with: "missing name")
									}
									guard let fromDocumentType = info["fromDocumentType"] as? String else {
										// Missing fromDocumentType
										throw HTTPEndpointError.badRequest(with: "missing fromDocumentType")
									}
									guard let toDocumentType = info["toDocumentType"] as? String else {
										// Missing toDocumentType
										throw HTTPEndpointError.badRequest(with: "missing toDocumentType")
									}

									return (documentStorageID, name, fromDocumentType, toDocumentType,
											headers["Authorization"])
								}
	static func httpEndpointRequestForAssociationRegister(documentStorageID :String, name :String,
			fromDocumentType :String, toDocumentType :String, authorization :String? = nil) ->
			MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .put, path: "/v1/association/\(documentStorageIDUse)",
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
	typealias AssociationUpdateEndpointInfo =
				(documentStorageID :String, name :String,
						updates :[(action :MDSAssociationAction, fromDocumentID :String, toDocumentID :String)],
						authorization :String?)
	static	let	assocationUpdateEndpoint =
						JSONHTTPEndpoint<[[String : Any]], AssociationUpdateEndpointInfo>(method: .patch,
								path: "/v1/association/:documentStorageID/:name")
								{ (urlComponents, headers, infos) -> AssociationUpdateEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3]

									let	updates
												:[(action :MDSAssociationAction, fromDocumentID :String,
														toDocumentID :String)] =
												infos.compactMap() {
													// Get info
													guard let action =
															MDSAssociationAction(
																	rawValue: ($0["action"] as? String) ?? ""),
															let fromDocumentID = $0["fromID"] as? String,
															let toDocumentID = $0["toID"] as? String else { return nil }

													return (action, fromDocumentID, toDocumentID)
												}
									guard updates.count == infos.count else {
										// Missing/invalid action
										throw HTTPEndpointError.badRequest(with: "invalid info")
									}

									return (documentStorageID, name, updates, headers["Authorization"])
								}
	static func httpEndpointRequestForAssocationUpdate(documentStorageID :String, name :String,
			updates :[(action :MDSAssociationAction, fromDocumentID :String, toDocumentID :String)],
			authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .put,
				path: "/v1/association/\(documentStorageIDUse)/\(name)", headers: headers,
				jsonBody:
						updates.map() {
							[
								"action": $0.action.rawValue,
								"fromID": $0.fromDocumentID,
								"toID": $0.toDocumentID,
							]
						})
	}

	// MARK: - Association Get
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> fromID -or- toID (query) (optional)
	//	=> startIndex (query) (optional, default is 0)
	//	=> count (query) (optional, default is all)
	//	=> fullInfo (query) (optional, default is false)
	//	=> authorization (header) (optional)
	//
	//	<= json (no fromID nor toID given)
	//		[
	//			{
	//				"fromDocumentID" :String,
	//				"toDocumentID" :String,
	//			},
	//			...
	//		]
	//	<= json (fromID or toID given, fullInfo == 0)
	//		[
	//			{
	//				"documentID" :String,
	//				"revision" :Int
	//			},
	//			...
	//		]
	//	<= json (fromID or toID given, fullInfo == 1)
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
	class AssociationGetHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[[String : String]]> {}
	typealias AssociationGetEndpointInfo =
				(documentStorageID :String, name :String, fromDocumentID :String?, toDocumentID :String?,
						startIndex :Int, count :Int?, fullInfo :Bool, authorization :String?)
	static	let	associationGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/assocation/:documentStorageID/:name")
								{ (urlComponents, headers) -> AssociationGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									let	fromDocumentID = queryItemsMap["fromID"] as? String
									let	toDocumentID = queryItemsMap["toID"] as? String
									let	startIndex = queryItemsMap["startIndex"] as? Int
									let	count = queryItemsMap["count"] as? Int
									let	fullInfo = queryItemsMap["fullInfo"] as? Int

									return (documentStorageID, name, fromDocumentID, toDocumentID, startIndex ?? 0,
											count, (fullInfo ?? 0) == 1, headers["Authorization"])
								}
	static func httpEndpointRequestForAssociationGet(documentStorageID :String, name :String, startIndex :Int = 0,
			count :Int? = nil, authorization :String? = nil) -> AssociationGetHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] = ["startIndex": startIndex]
		queryComponents["count"] = count

		// Return endpoint request
		return AssociationGetHTTPEndpointRequest(method: .get, path: "/v1/association/\(documentStorageIDUse)/\(name)",
				queryComponents: queryComponents, headers: headers)
	}
	static func httpEndpointRequestForAssociationGetDocumentInfos(documentStorageID :String, name :String,
			fromDocumentID :String, startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			GetDocumentInfosHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] =
					[
						"fromID": fromDocumentID,
						"startIndex": startIndex,
						"fullInfo": 0,
					]
		queryComponents["count"] = count

		// Return endpoint request
		return GetDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageIDUse)/\(name)", queryComponents: queryComponents,
				headers: headers)
	}
	static func httpEndpointRequestForAssociationGetDocuments(documentStorageID :String, name :String,
			fromDocumentID :String, startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			GetDocumentsHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] =
					[
						"fromID": fromDocumentID,
						"startIndex": startIndex,
						"fullInfo": 1,
					]
		queryComponents["count"] = count

		// Return endpoint request
		return GetDocumentsHTTPEndpointRequest(method: .get, path: "/v1/association/\(documentStorageIDUse)/\(name)",
				queryComponents: queryComponents, headers: headers)
	}
	static func httpEndpointRequestForAssociationGetDocumentInfos(documentStorageID :String, name :String,
			toDocumentID :String, startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			GetDocumentInfosHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] =
					[
						"toID": toDocumentID,
						"startIndex": startIndex,
						"fullInfo": 0,
					]
		queryComponents["count"] = count

		// Return endpoint request
		return GetDocumentInfosHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageIDUse)/\(name)", queryComponents: queryComponents,
				headers: headers)
	}
	static func httpEndpointRequestForAssociationGetDocuments(documentStorageID :String, name :String,
			toDocumentID :String, startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			GetDocumentsHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] =
					[
						"toID": toDocumentID,
						"startIndex": startIndex,
						"fullInfo": 1,
					]
		queryComponents["count"] = count

		// Return endpoint request
		return GetDocumentsHTTPEndpointRequest(method: .get, path: "/v1/association/\(documentStorageIDUse)/\(name)",
				queryComponents: queryComponents, headers: headers)
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
	enum AssociationGetValueAction : String {
		case sum = "sum"
	}
	typealias AssociationGetValueEndpointInfo =
				(documentStorageID :String, name :String, fromID :String, action :AssociationGetValueAction,
						cacheName :String, cacheNameValue :String, authorization :String?)
	static	let	assocationGetValueEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/association/:documentStorageID/:name/value")
								{ (urlComponents, headers) -> AssociationGetValueEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									guard let fromID = queryItemsMap["fromID"] as? String else {
										// Missing fromID
										throw HTTPEndpointError.badRequest(with: "missing fromID")
									}
									guard let action =
											AssociationGetValueAction(
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

									return (documentStorageID, name, fromID, action, cacheName, cacheValueName,
											headers["Authorization"])
								}
	static func httpEndpointRequestForAssocationGetIntegerValue(documentStorageID :String, name :String, fromID :String,
			action :AssociationGetValueAction, cacheName :String, cacheValueName :String, authorization :String? = nil)
			-> MDSIntegerWithUpToDateHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSIntegerWithUpToDateHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageIDUse)/\(name)/value",
				queryComponents: [
									"fromID": fromID,
									"action": action.rawValue,
									"cacheName": cacheName,
									"cacheValueName": cacheValueName,
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
	typealias CacheRegisterEndpointValueInfo = (name :String, valueType :MDSValueType, selector :String)
	typealias CacheRegisterEndpointInfo =
				(documentStorageID :String, name :String, documentType :String, relevantProperties :[String],
						valuesInfos :[CacheRegisterEndpointValueInfo], authorization :String?)
	static	let	cacheRegisterEndpoint =
						JSONHTTPEndpoint<[String : Any], CacheRegisterEndpointInfo>(method: .put,
								path: "/v1/cache/:documentStorageID")
								{ (urlComponents, headers, info) -> CacheRegisterEndpointInfo in
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
												valuesInfosInfo.compactMap({ info -> CacheRegisterEndpointValueInfo? in
													// Setup
													guard let name = info["name"] as? String,
															let valueType = info["valueType"] as? String,
															valueType == "integer",
															let selector = info["selector"] as? String else
														{ return nil }

													return CacheRegisterEndpointValueInfo(name, .integer, selector)
												})
									guard valuesInfos.count == valuesInfosInfo.count else {
										// Invalid values infos
										throw HTTPEndpointError.badRequest(with: "invalid valuesInfos")
									}

									return (documentStorageID, name, documentType, relevantProperties, valuesInfos,
											headers["Authorization"])
								}
	static func httpEndpointRequestForCacheRegister(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], valueInfos :[CacheRegisterEndpointValueInfo],
			authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil
		let	valuesInfosTransformed =
					valueInfos.map({ [
										"name": $0.name,
										"valueType": $0.valueType.rawValue,
										"selector": $0.selector,
									  ] })

		return MDSSuccessHTTPEndpointRequest(method: .put, path: "/v1/cache/\(documentStorageIDUse)", headers: headers,
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
	typealias CollectionRegisterEndpointInfo =
				(documentStorageID :String, name :String, documentType :String, relevantProperties :[String],
						isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any],
						authorization :String?)
	static	let	collectionRegisterEndpoint =
						JSONHTTPEndpoint<[String : Any], CollectionRegisterEndpointInfo>(method: .put,
								path: "/v1/collection/:documentStorageID")
								{ (urlComponents, headers, info) -> CollectionRegisterEndpointInfo in
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
	static func httpEndpointRequestForCollectionRegister(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], isUpToDate :Bool = false, isIncludedSelector :String,
			isIncludedSelectorInfo :[String : Any] = [:], authorization :String? = nil) ->
			MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .put, path: "/v1/collection/\(documentStorageIDUse)",
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
	typealias CollectionGetDocumentCountEndpointInfo = (documentStorageID :String, name :String, authorization :String?)
	static	let	collectionGetDocumentCountEndpoint =
						BasicHTTPEndpoint(method: .head, path: "/v1/collection/:documentStorageID/:name")
								{ (urlComponents, headers) -> CollectionGetDocumentCountEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, name, headers["Authorization"])
								}
	static func httpEndpointRequestForCollectionGetDocumentCount(documentStorageID :String, name :String,
			authorization :String? = nil) -> MDSHeadWithUpToDateHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	nameUse = name.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSHeadWithUpToDateHTTPEndpointRequest(method: .head,
				path: "/v1/collection/\(documentStorageIDUse)/\(nameUse)", headers: headers)
	}

	// MARK: - Collection Get
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> startIndex (query) (optional, default is 0)
	//	=> count (query) (optional, default is all)
	//	=> fullInfo (query) (optional, default is false)
	//	=> authorization (header) (optional)
	//
	//	<= HTTP Status 409 if collection is out of date => call endpoint again
	//	<= json (fullInfo == 0)
	//		[
	//			{
	//				"fromDocumentID" :String,
	//				"toDocumentID" :String,
	//			},
	//			...
	//		]
	//	<= json (fullInfo == 1)
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
	class CollectionGetDocumentInfoHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[[String : Any]]> {}
	class CollectionGetDocumentHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[[String : Any]]> {}
	typealias CollectionGetDocumentInfoEndpointInfo =
			(documentStorageID :String, name :String, startIndex :Int, count :Int?, fullInfo :Bool,
					authorization :String?)
	static	let	collectionGetDocumentInfoEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/collection/:documentStorageID/:name")
								{ (urlComponents, headers) -> CollectionGetDocumentInfoEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	name = pathComponents[3].replacingOccurrences(of: "_", with: "/")

									let	queryItemsMap = urlComponents.queryItemsMap
									let	startIndex = queryItemsMap["startIndex"] as? Int
									let	count = queryItemsMap["count"] as? Int
									let	fullInfo = queryItemsMap["fullInfo"] as? Int

									return (documentStorageID, name, startIndex ?? 0, count, (fullInfo ?? 0) == 1,
											headers["Authorization"])
								}
	static func httpEndpointRequestForCollectionGetDocumentInfo(documentStorageID :String, name :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			CollectionGetDocumentInfoHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	nameUse = name.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] =
					[
						"startIndex": startIndex,
						"fullInfo": 0,
					]
		queryComponents["count"] = count

		// Return endpoint request
		return CollectionGetDocumentInfoHTTPEndpointRequest(method: .get,
				path: "/v1/collection/\(documentStorageIDUse)/\(nameUse)", queryComponents: queryComponents,
				headers: headers)
	}
	static func httpEndpointRequestForCollectionGetDocument(documentStorageID :String, name :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			CollectionGetDocumentHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	nameUse = name.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] =
					[
						"startIndex": startIndex,
						"fullInfo": 1,
					]
		queryComponents["count"] = count

		// Return endpoint request
		return CollectionGetDocumentHTTPEndpointRequest(method: .get,
				path: "/v1/collection/\(documentStorageIDUse)/\(nameUse)", queryComponents: queryComponents,
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
	typealias DocumentCreateEndpointInfo =
				(documentStorageID :String, documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
						authorization :String?)
	static	let	documentCreateEndpoint =
						JSONHTTPEndpoint<Any, DocumentCreateEndpointInfo>(method: .post,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> DocumentCreateEndpointInfo in
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
	static func httpEndpointRequestForDocumentCreate(documentStorageID :String, documentType :String,
			documentCreateInfos :[MDSDocument.CreateInfo], authorization :String? = nil) ->
			MDSJSONHTTPEndpointRequest<[[String : Any]]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest<[[String : Any]]>(method: .post,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)", headers: headers,
				jsonBody: documentCreateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: - Document Get Count
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> authorization (header) (optional)
	//
	//	<= count in header
	static func httpEndpointRequestForDocumentGetCount(documentStorageID :String, documentType :String,
			authorization :String? = nil) -> MDSHeadHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSHeadHTTPEndpointRequest(method: .head, path: "/v1/document/\(documentStorageIDUse)/\(documentType)",
				headers: headers)
	}

	// MARK: - Document Get
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//
	//	=> sinceRevision (query)
	//	=> count (query) (optional, default is all)
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
	class DocumentGetSinceRevisionHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[[String : Any]]> {}
	class DocumentGetForDocumentIDsHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[[String : Any]]> {}
	typealias DocumentGetEndpointInfo =
				(documentStorageID :String, documentType :String, documentIDs :[String]?, sinceRevision :Int?,
						count :Int?, authorization :String?)
	static	let	documentGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers) -> DocumentGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]

									let	queryItemsMap = urlComponents.queryItemsMap
									let	documentIDs = queryItemsMap.stringArray(for: "id")
									let	sinceRevision = Int(queryItemsMap["sinceRevision"] as? String)
									let	count = queryItemsMap["count"] as? Int
									guard (documentIDs != nil) || (sinceRevision != nil) else {
										// Query info not specified
										throw HTTPEndpointError.badRequest(
												with: "missing id(s) or sinceRevision in query")
									}

									return (documentStorageID, documentType, documentIDs, sinceRevision, count,
											headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentGet(documentStorageID :String, documentType :String, sinceRevision :Int,
			count :Int? = nil, authorization :String? = nil) -> DocumentGetSinceRevisionHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] = ["sinceRevision": sinceRevision]
		queryComponents["count"] = count

		return DocumentGetSinceRevisionHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)", queryComponents: queryComponents,
				headers: headers)
	}
	static func httpEndpointRequestForDocumentGet(documentStorageID :String, documentType :String,
			documentIDs :[String], authorization :String? = nil) -> DocumentGetForDocumentIDsHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return DocumentGetForDocumentIDsHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)",
				multiValueQueryComponent: ("id", documentIDs), headers: headers)
	}

	// MARK: - Document Update
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> json (body)
	//		[
	//			{
	//				"documentID" :String,		// Required
	//				"updated" :{				// Optional
	//								"key" :Any,
	//								...
	//						   },
	//				"removed" :[				// Optional
	//								"key",
	//								...
	//						   ],
	//				"active" :0/1,				// Optional
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
	typealias DocumentUpdateEndpointInfo =
				(documentStorageID :String, documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo],
						authorization :String?)
	static	let	documentUpdateEndpoint =
						JSONHTTPEndpoint<Any, DocumentUpdateEndpointInfo>(method: .patch,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> DocumentUpdateEndpointInfo in
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
	static func httpEndpointRequestForDocumentUpdate(documentStorageID :String, documentType :String,
			documentUpdateInfos :[MDSDocument.UpdateInfo], authorization :String? = nil) ->
			MDSJSONHTTPEndpointRequest<[[String : Any]]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest<[[String : Any]]>(method: .patch,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)", headers: headers,
				jsonBody: documentUpdateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: - Document Attachment Add
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
	//			"revision" :Int
	//		}
	static func httpEndpointRequestForDocumentAttachmentAdd(documentStorageID :String, documentType :String,
			documentID :String, info :[String : Any], content :Data, authorization :String? = nil) ->
			MDSJSONHTTPEndpointRequest<[String : Any]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	documentIDUse = documentID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest<[String : Any]>(method: .post,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)/\(documentIDUse)/attachment",
				headers: headers, jsonBody: ["info": info, "content": content.base64EncodedString()])
	}

	// MARK: - Document Attachment Get
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> documentID (path)
	//	=> attachmentID (path)
	//	=> authorization (header) (optional)
	//
	//	<= data
	static func httpEndpointRequestForDocumentAttachmentGet(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, authorization :String? = nil) -> MDSDataHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	documentIDUse = documentID.replacingOccurrences(of: "/", with: "_")
		let	attachmentIDUse = attachmentID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSDataHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers)
	}

	// MARK: - Document Attachment Update
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> documentID (path)
	//	=> attachmentID (path)
	//	=> info (body)
	//	=> content (body)
	//	=> authorization (header) (optional)
	//
	//	<= json
	//		{
	//			"revision" :Int
	//		}
	static func httpEndpointRequestForDocumentAttachmentUpdate(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, info :[String : Any], content :Data,
			authorization :String? = nil) -> MDSJSONHTTPEndpointRequest<[String : Any]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	documentIDUse = documentID.replacingOccurrences(of: "/", with: "_")
		let	attachmentIDUse = attachmentID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest<[String : Any]>(method: .patch,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers, jsonBody: ["info": info, "content": content.base64EncodedString()])
	}

	// MARK: - Document Attachment Remove
	//	=> documentStorageID (path)
	//	=> documentType (path)
	//	=> documentID (path)
	//	=> attachmentID (path)
	//	=> authorization (header) (optional)
	static func httpEndpointRequestForDocumentAttachmentRemove(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	documentIDUse = documentID.replacingOccurrences(of: "/", with: "_")
		let	attachmentIDUse = attachmentID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .delete,
				path: "/v1/document/\(documentStorageIDUse)/\(documentType)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers)
	}

	// MARK: - Index Register
	//	=> documentStorageID (path)
	//	=> json (body)
	//		{
	//			"name" :String,
	//			"documentType" :String,
	//			"relevantProperties" :[String]
	//			"isUpToDate" :Int (0 or 1)
	//			"keysSelector" :String,
	//			"keysSelectorInfo" :{
	//									"key" :Any,
	//									...
	//							    },
	//		}
	//	=> authorization (header) (optional)
	typealias IndexRegisterEndpointInfo =
				(documentStorageID :String, name :String, documentType :String, relevantProperties :[String],
						isUpToDate :Bool, keysSelector :String, keysSelectorInfo: [String : Any],
						authorization :String?)
	static	let	indexRegisterEndpoint =
						JSONHTTPEndpoint<[String : Any], IndexRegisterEndpointInfo>(method: .put,
								path: "/v1/index/:documentStorageID")
								{ (urlComponents, headers, info) -> IndexRegisterEndpointInfo in
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
	static func httpEndpointRequestForIndexRegister(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], isUpToDate :Bool = false, keysSelector :String,
			keysSelectorInfo :[String : Any] = [:], authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .put, path: "/v1/index/\(documentStorageIDUse)", headers: headers,
				jsonBody: [
							"name": name,
							"documentType": documentType,
							"relevantProperties": relevantProperties,
							"isUpToDate": isUpToDate ? 1 : 0,
							"keysSelector": keysSelector,
							"keysSelectorInfo": keysSelectorInfo,
						  ])
	}

	// MARK: - Index Get
	//	=> documentStorageID (path)
	//	=> name (path)
	//	=> key (query) (can specify multiple)
	//	=> fullInfo (query) (optional, default is false)
	//	=> authorization (header) (optional)
	//
	//	<= HTTP Status 409 if collection is out of date => call endpoint again
	//	<= json (fullInfo == 0)
	//		{
	//			key: {String (documentID) : Int (revision)},
	//			...
	//		}
	//	<= json (fullInfo == 1)
	//		{
	//			key:
	//				{
	//					"documentID" :String,
	//					"revision" :Int,
	//					"active" :0/1,
	//					"creationDate" :String,
	//					"modificationDate" :String,
	//					"json" :{
	//								"key" :Any,
	//								...
	//							},
	//					"attachments":
	//							{
	//								id :
	//									{
	//										"revision" :Int,
	//										"info" :{
	//													"key" :Any,
	//													...
	//												},
	//									},
	//									..
	//							}
	//				},
	//			...
	//		}
	class IndexGetDocumentInfoHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[String : [String : Int]]> {}
	class IndexGetDocumentHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[String : [String : Any]]> {}
	typealias IndexDocumentGetInfoEndpointInfo =
				(documentStorageID :String, name :String, keys :[String], authorization :String?)
	static	let	indexGetDocumentInfoEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/index/:documentStorageID/:name")
								{ (urlComponents, headers) -> IndexDocumentGetInfoEndpointInfo in
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
	static func httpEndpointRequestForIndexGetDocumentInfo(documentStorageID :String, name :String, keys :[String],
			authorization :String? = nil) -> IndexGetDocumentInfoHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	nameUse = name.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return IndexGetDocumentInfoHTTPEndpointRequest(method: .get,
				path: "/v1/index/\(documentStorageIDUse)/\(nameUse)", queryComponents: ["fullInfo": 0],
				multiValueQueryComponent: ("key", keys), headers: headers)
	}
	static func httpEndpointRequestForIndexGetDocument(documentStorageID :String, name :String, keys :[String],
			authorization :String? = nil) -> IndexGetDocumentHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	nameUse = name.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return IndexGetDocumentHTTPEndpointRequest(method: .get,
				path: "/v1/index/\(documentStorageIDUse)/\(nameUse)", queryComponents: ["fullInfo": 1],
				multiValueQueryComponent: ("key", keys), headers: headers)
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
	typealias InfoGetEndpointInfo = (documentStorageID :String, keys :[String], authorization :String?)
	static	let	infoGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/info/:documentStorageID")
								{ (urlComponents, headers) -> InfoGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									guard let keys = urlComponents.queryItemsMap.stringArray(for: "key") else {
										// Keys not specified
										throw HTTPEndpointError.badRequest(with: "missing key(s) in query")
									}

									return (documentStorageID, keys, headers["Authorization"])
								}
	static func httpEndpointRequestForInfoGet(documentStorageID :String, keys :[String], authorization :String? = nil)
			-> MDSJSONHTTPEndpointRequest<[String : String]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest(method: .get, path: "/v1/info/\(documentStorageIDUse)",
				multiValueQueryComponent: ("key", keys), headers: headers)
	}

	// MARK: - Info Set
	//	=> documentStorageID (path)
	//	=> json (body)
	//		[
	//			"key" :String
	//			...
	//		]
	//	=> authorization (header) (optional)
	typealias InfoSetEndpointInfo = (documentStorageID :String, info :[String : String], authorization :String?)
	static	let	infoSetEndpoint =
						JSONHTTPEndpoint<[String : String], InfoSetEndpointInfo>(method: .post,
								path: "/v1/info/:documentStorageID")
								{ (urlComponents, headers, info) -> InfoSetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, info, headers["Authorization"])
								}
	static func httpEndpointRequestForInfoSet(documentStorageID :String, info :[String : String],
			authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .post, path: "/v1/info/\(documentStorageIDUse)", headers: headers,
				jsonBody: info)
	}

	// MARK: - Internal Set
	//	=> documentStorageID (path)
	//	=> json (body)
	//		[
	//			"key" :String
	//			...
	//		]
	//	=> authorization (header) (optional)
	typealias InternalSetEndpointInfo = (documentStorageID :String, info :[String : String], authorization :String?)
	static	let	internalSetEndpoint =
						JSONHTTPEndpoint<[String : String], InternalSetEndpointInfo>(method: .post,
								path: "/v1/internal/:documentStorageID")
								{ (urlComponents, headers, info) -> InternalSetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, info, headers["Authorization"])
								}
	static func httpEndpointRequestForInternalSet(documentStorageID :String, info :[String : String],
			authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.replacingOccurrences(of: "/", with: "_")
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .post, path: "/v1/internal/\(documentStorageIDUse)",
				headers: headers, jsonBody: info)
	}
}
