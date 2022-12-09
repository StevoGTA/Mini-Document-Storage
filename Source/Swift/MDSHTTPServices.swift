//
//  MDSHTTPServices.swift
//  Mini Document Storage
//
//  Created by Stevo on 4/2/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSAssociation.Item extension
extension MDSAssociation.Item {

	// MARK: Properties
	var	httpServicesInfo :[String : String] {
				[
					"fromDocumentID": self.fromDocumentID,
					"toDocumentID": self.toDocumentID,
				]
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init?(httpServicesInfo :[String : String]) {
		// Setup
		guard let fromDocumentID = httpServicesInfo["fromDocumentID"],
				let toDocumentID = httpServicesInfo["toDocumentID"]
				else { return nil }

		// Store
		self.fromDocumentID = fromDocumentID
		self.toDocumentID = toDocumentID
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument.AttachmentInfo extension
extension MDSDocument.AttachmentInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"id": self.id,
					"revision": self.revision,
				]
			}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument.RevisionInfo extension
extension MDSDocument.RevisionInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"documentID": self.documentID,
					"revision": self.revision,
				]
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init?(httpServicesInfo :[String : Any]) {
		// Setup
		guard let documentID = httpServicesInfo["documentID"] as? String,
				let revision = httpServicesInfo["revision"] as? Int
				else { return nil }

		// Store
		self.documentID = documentID
		self.revision = revision
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument.OverviewInfo extension
extension MDSDocument.OverviewInfo {

	// MARK: Properties
	var	httpServicesInfo :[String : Any] {
				[
					"documentID": self.documentID,
					"revision": self.revision,
					"active": self.active,
					"creationDate": self.creationDate.rfc3339Extended,
					"modificationDate": self.modificationDate.rfc3339Extended,
				]
			}

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init?(httpServicesInfo :[String : Any]) {
		// Setup
		guard let documentID = httpServicesInfo["documentID"] as? String,
				let revision = httpServicesInfo["revision"] as? Int,
				let active = httpServicesInfo["active"] as? Bool,
				let creationDate = Date(fromRFC3339Extended: httpServicesInfo["creationDate"] as? String),
				let modificationDate = Date(fromRFC3339Extended: httpServicesInfo["modificationDate"] as? String)
				else { return nil }

		// Store
		self.documentID = documentID
		self.revision = revision
		self.active = active
		self.creationDate = creationDate
		self.modificationDate = modificationDate
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument.FullInfo extension
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
	init?(httpServicesInfo :[String : Any]) {
		// Setup
		guard let documentID = httpServicesInfo["documentID"] as? String,
				let revision = httpServicesInfo["revision"] as? Int,
				let active = httpServicesInfo["active"] as? Bool,
				let creationDate = Date(fromRFC3339Extended: httpServicesInfo["creationDate"] as? String),
				let modificationDate = Date(fromRFC3339Extended: httpServicesInfo["modificationDate"] as? String),
				let propertyMap = httpServicesInfo["json"] as? [String : Any],
				let	attachmentInfoMapInfo = httpServicesInfo["attachments"] as? [String : [String : Any]],
				attachmentInfoMapInfo.values.first(
						where: { (($0["revision"] as? Int) != nil) && (($0["info"] as? [String : Any]) != nil) }) ==
								nil
				else { return nil }

		// Store
		self.documentID = documentID
		self.revision = revision
		self.active = active
		self.creationDate = creationDate
		self.modificationDate = modificationDate
		self.propertyMap = propertyMap
		self.attachmentInfoMap =
				attachmentInfoMapInfo
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
		self.propertyMap = (httpServicesInfo["json"] as? [String : Any]) ?? [:]
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
	init?(httpServicesInfo :[String : Any]) {
		// Setup
		guard let documentID = httpServicesInfo["documentID"] as? String else { return nil }

		// Store
		self.documentID = documentID
		self.updated = (httpServicesInfo["updated"] as? [String : Any]) ?? [:]
		self.removed = Set<String>((httpServicesInfo["removed"] as? [String]) ?? [])
		self.active = (httpServicesInfo["active"] as? Bool) ?? true
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSError
enum MDSError : Error {
	case invalidRequest(error :String)
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
							case .invalidRequest(let error):			return error
							case .responseWasEmpty:						return "Server response was empty"
							case .didNotReceiveSizeInHeader:			return "Did not receive size in header"
							case .failed(let status):					return "Failed: \(status)"
							case .internalError:						return "Server internal error"
							case .unknownResponseStatus(let status):	return "Unknown reponse status: \(status)"
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSHTTPServicesHandler
protocol MDSHTTPServicesHandler : MDSDocumentStorage {

	// MARK: Instance methods
	func associationGetDocumentRevisionInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo])
	func associationGetDocumentRevisionInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo])
	func associationGetDocumentFullInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentFullInfos :[MDSDocument.FullInfo])
	func associationGetDocumentFullInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, documentFullInfos :[MDSDocument.FullInfo])

	func collectionGetDocumentRevisionInfos(name :String, startIndex :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo]
	func collectionGetDocumentFullInfos(name :String, startIndex :Int, count :Int?) throws -> [MDSDocument.FullInfo]

	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo]

	func indexGetDocumentRevisionInfos(name :String, keys :[String]) throws -> [String : MDSDocument.RevisionInfo]
	func indexGetDocumentFullInfos(name :String, keys :[String]) throws -> [String : MDSDocument.FullInfo]
}

// MARK: - String extension
//----------------------------------------------------------------------------------------------------------------------
extension String {

	// MARK: Properties
	static	private		let	pathTransformCharacterSet = CharacterSet(charactersIn: "/").inverted

			fileprivate	var	transformedForPath :String
								{ self.addingPercentEncoding(withAllowedCharacters: Self.pathTransformCharacterSet)! }
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
					if let error = info?["error"] {
						// Received error
						return MDSError.invalidRequest(error: error)
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
						self.completionWithUpToDateProc(nil, mdsError(for: data))
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
		typealias SingleResponseWithCountCompletionProc =
					(_ info :(info :T, isComplete :Bool)?, _ error :Error?) -> Void
		typealias SingleResponseWithUpToDateAndCountCompletionProc =
					(_ isUpToDate :Bool?, _ info :(info :T, isComplete :Bool)?, _ error :Error?) -> Void
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
							if let contentRange = response!.contentRange {
								// Got contentRange
								let	isComplete =
											(contentRange.range == nil) ||
													((contentRange.range!.start + contentRange.range!.length) ==
															contentRange.size!)
								self.completionWithCountProc!((info!, isComplete), nil)
							} else {
								// Did not get size
								self.completionWithCountProc!(nil,
										MDSError.invalidRequest(error: "Missing content range size"))
							}
						} else {
							// No info
							self.completionWithCountProc!(nil, localError);
						}
					} else if self.completionWithUpToDateAndCountProc != nil {
						// Single response expected with count, but could be not up to date
						if info != nil {
							// Got info
							if let contentRange = response!.contentRange {
								// Got contentRange
								let	isComplete =
											(contentRange.range == nil) ||
													((contentRange.range!.start + contentRange.range!.length) ==
															contentRange.size!)
								self.completionWithUpToDateAndCountProc!(true, (info!, isComplete), nil)
							} else {
								// Did not get size
								self.completionWithUpToDateAndCountProc!(nil, nil,
										MDSError.invalidRequest(error: "Missing content range size"))
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
	typealias AssociationRegisterEndpointInfo =
			(documentStorageID :String, name :String?, fromDocumentType :String?, toDocumentType :String?,
					authorization :String?)
	static	let	associationRegisterEndpoint =
						JSONHTTPEndpoint<[String : Any], AssociationRegisterEndpointInfo>(method: .put,
								path: "/v1/association/:documentStorageID")
								{ (urlComponents, headers, info) -> AssociationRegisterEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!

									return (documentStorageID, info["name"] as? String,
											info["fromDocumentType"] as? String,
											info["toDocumentType"] as? String,
											headers["Authorization"])
								}
	static func httpEndpointRequestForAssociationRegister(documentStorageID :String, name :String,
			fromDocumentType :String, toDocumentType :String, authorization :String? = nil) ->
			MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
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
	typealias AssociationUpdateEndpointInfo =
				(documentStorageID :String, name :String, updates :[MDSAssociation.Update], authorization :String?)
	static	let	associationUpdateEndpoint =
						JSONHTTPEndpoint<[[String : Any]], AssociationUpdateEndpointInfo>(method: .put,
								path: "/v1/association/:documentStorageID/:name")
								{ (urlComponents, headers, infos) -> AssociationUpdateEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	name = pathComponents[3].removingPercentEncoding!

									let	updates :[MDSAssociation.Update] =
												infos.compactMap() {
													// Get info
													guard let action =
															MDSAssociation.Update.Action(
																	rawValue: ($0["action"] as? String) ?? ""),
															let fromDocumentID = $0["fromID"] as? String,
															let toDocumentID = $0["toID"] as? String else { return nil }

													return MDSAssociation.Update(action: action,
															fromDocumentID: fromDocumentID, toDocumentID: toDocumentID)
												}

									return (documentStorageID, name, updates, headers["Authorization"])
								}
	static func httpEndpointRequestForAssociationUpdate(documentStorageID :String, name :String,
			updates :[MDSAssociation.Update], authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .put,
				path: "/v1/association/\(documentStorageIDUse)/\(nameUse)", headers: headers,
				jsonBody:
						updates.map() {
							[
								"action": $0.action.rawValue,
								"fromID": $0.item.fromDocumentID,
								"toID": $0.item.toDocumentID,
							]
						})
	}

	// MARK: - Association Get
	class AssociationGetHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[[String : String]]> {}
	typealias AssociationGetEndpointInfo =
				(documentStorageID :String, name :String, fromDocumentID :String?, toDocumentID :String?,
						startIndex :Int, count :Int?, fullInfo :Bool, authorization :String?)
	static	let	associationGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/association/:documentStorageID/:name")
								{ (urlComponents, headers) -> AssociationGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	name = pathComponents[3].removingPercentEncoding!

									let	queryItemsMap = urlComponents.queryItemsMap

									return (documentStorageID, name, queryItemsMap["fromID"] as? String,
											queryItemsMap["toID"] as? String,
											Int(queryItemsMap["startIndex"] as? String) ?? 0,
											Int(queryItemsMap["count"] as? String),
											(Int(queryItemsMap["fullInfo"] as? String) ?? 0) == 1,
											headers["Authorization"])
								}
	static func httpEndpointRequestForAssociationGet(documentStorageID :String, name :String, startIndex :Int = 0,
			count :Int? = nil, authorization :String? = nil) -> AssociationGetHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] = ["startIndex": startIndex]
		queryComponents["count"] = count

		// Return endpoint request
		return AssociationGetHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageIDUse)/\(nameUse)", queryComponents: queryComponents,
				headers: headers)
	}
	static func httpEndpointRequestForAssociationGetDocumentInfos(documentStorageID :String, name :String,
			fromDocumentID :String, startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			GetDocumentInfosHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
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
				path: "/v1/association/\(documentStorageIDUse)/\(nameUse)", queryComponents: queryComponents,
				headers: headers)
	}
	static func httpEndpointRequestForAssociationGetDocuments(documentStorageID :String, name :String,
			fromDocumentID :String, startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			GetDocumentsHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] =
					[
						"fromID": fromDocumentID,
						"startIndex": startIndex,
						"fullInfo": 1,
					]
		queryComponents["count"] = count

		// Return endpoint request
		return GetDocumentsHTTPEndpointRequest(method: .get, path: "/v1/association/\(documentStorageIDUse)/\(nameUse)",
				queryComponents: queryComponents, headers: headers)
	}
	static func httpEndpointRequestForAssociationGetDocumentInfos(documentStorageID :String, name :String,
			toDocumentID :String, startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			GetDocumentInfosHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
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
				path: "/v1/association/\(documentStorageIDUse)/\(nameUse)", queryComponents: queryComponents,
				headers: headers)
	}
	static func httpEndpointRequestForAssociationGetDocuments(documentStorageID :String, name :String,
			toDocumentID :String, startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			GetDocumentsHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] =
					[
						"toID": toDocumentID,
						"startIndex": startIndex,
						"fullInfo": 1,
					]
		queryComponents["count"] = count

		// Return endpoint request
		return GetDocumentsHTTPEndpointRequest(method: .get, path: "/v1/association/\(documentStorageIDUse)/\(nameUse)",
				queryComponents: queryComponents, headers: headers)
	}

	// MARK: - Association Get Value
	typealias AssociationGetValueEndpointInfo =
				(documentStorageID :String, name :String, action :MDSAssociation.GetIntegerValueAction?,
						fromDocumentID :String?, cacheName :String?, cachedValueName :String?, authorization :String?)
	static	let	associationGetValueEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/association/:documentStorageID/:name/:action")
								{ (urlComponents, headers) -> AssociationGetValueEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	name = pathComponents[3].removingPercentEncoding!
									let	action = pathComponents[4]

									let	queryItemsMap = urlComponents.queryItemsMap

									return (documentStorageID, name,
											MDSAssociation.GetIntegerValueAction(rawValue: action),
											queryItemsMap["fromID"] as? String,
											queryItemsMap["cacheName"] as? String,
											queryItemsMap["cachedValueName"] as? String, headers["Authorization"])
								}
	static func httpEndpointRequestForAssociationGetIntegerValue(documentStorageID :String, name :String,
			action :MDSAssociation.GetIntegerValueAction, fromDocumentID :String, cacheName :String,
			cachedValueName :String, authorization :String? = nil) -> MDSIntegerWithUpToDateHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSIntegerWithUpToDateHTTPEndpointRequest(method: .get,
				path: "/v1/association/\(documentStorageIDUse)/\(nameUse)/\(action.rawValue)",
				queryComponents: [
									"fromID": fromDocumentID,
									"cacheName": cacheName,
									"cachedValueName": cachedValueName,
								 ],
				headers: headers)
	}

	// MARK: - Cache Register
	typealias CacheRegisterEndpointValueInfo = (name :String, valueType :MDSValue.`Type`, selector :String)
	typealias CacheRegisterEndpointInfo =
				(documentStorageID :String, name :String?, documentType :String?, relevantProperties :[String]?,
						valueInfos :[CacheRegisterEndpointValueInfo]?, authorization :String?)
	static	let	cacheRegisterEndpoint =
						JSONHTTPEndpoint<[String : Any], CacheRegisterEndpointInfo>(method: .put,
								path: "/v1/cache/:documentStorageID")
								{ (urlComponents, headers, info) -> CacheRegisterEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!

									let valueInfosInfo = info["valueInfos"] as? [[String : Any]]
									let	valueInfos =
												valueInfosInfo?.compactMap({ info -> CacheRegisterEndpointValueInfo? in
													// Setup
													guard let name = info["name"] as? String,
															let valueType = info["valueType"] as? String,
															valueType == "integer",
															let selector = info["selector"] as? String else
														{ return nil }

													return CacheRegisterEndpointValueInfo(name, .integer, selector)
												})

									return (documentStorageID, info["name"] as? String, info["documentType"] as? String,
											info["relevantProperties"] as? [String], valueInfos,
											headers["Authorization"])
								}
	static func httpEndpointRequestForCacheRegister(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], valueInfos :[CacheRegisterEndpointValueInfo],
			authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil
		let	valueInfosTransformed =
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
							"valueInfos": valueInfosTransformed,
						  ])
	}

	// MARK: - Collection Register
	typealias CollectionRegisterEndpointInfo =
				(documentStorageID :String, name :String?, documentType :String?, relevantProperties :[String]?,
						isUpToDate :Bool, isIncludedSelector :String?, isIncludedSelectorInfo :[String : Any]?,
						authorization :String?)
	static	let	collectionRegisterEndpoint =
						JSONHTTPEndpoint<[String : Any], CollectionRegisterEndpointInfo>(method: .put,
								path: "/v1/collection/:documentStorageID")
								{ (urlComponents, headers, info) -> CollectionRegisterEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!

									return (documentStorageID, info["name"] as? String, info["documentType"] as? String,
											info["relevantProperties"] as? [String],
											((info["isUpToDate"] as? Int) ?? 0) == 1,
											info["isIncludedSelector"] as? String,
											info["isIncludedSelectorInfo"] as? [String : Any], headers["Authorization"])
								}
	static func httpEndpointRequestForCollectionRegister(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], isUpToDate :Bool = false, isIncludedSelector :String,
			isIncludedSelectorInfo :[String : Any] = [:], authorization :String? = nil) ->
			MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
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
	typealias CollectionGetDocumentCountEndpointInfo = (documentStorageID :String, name :String, authorization :String?)
	static	let	collectionGetDocumentCountEndpoint =
						BasicHTTPEndpoint(method: .head, path: "/v1/collection/:documentStorageID/:name")
								{ (urlComponents, headers) -> CollectionGetDocumentCountEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	name = pathComponents[3].removingPercentEncoding!

									return (documentStorageID, name, headers["Authorization"])
								}
	static func httpEndpointRequestForCollectionGetDocumentCount(documentStorageID :String, name :String,
			authorization :String? = nil) -> MDSHeadWithUpToDateHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSHeadWithUpToDateHTTPEndpointRequest(method: .head,
				path: "/v1/collection/\(documentStorageIDUse)/\(nameUse)", headers: headers)
	}

	// MARK: - Collection Get
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
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	name = pathComponents[3].removingPercentEncoding!

									let	queryItemsMap = urlComponents.queryItemsMap

									return (documentStorageID, name, Int(queryItemsMap["startIndex"] as? String) ?? 0,
											Int(queryItemsMap["count"] as? String),
											(Int(queryItemsMap["fullInfo"] as? String) ?? 0) == 1,
											headers["Authorization"])
								}
	static func httpEndpointRequestForCollectionGetDocumentInfos(documentStorageID :String, name :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			CollectionGetDocumentInfoHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
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
	static func httpEndpointRequestForCollectionGetDocuments(documentStorageID :String, name :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			CollectionGetDocumentHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
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
	typealias DocumentCreateEndpointInfo =
				(documentStorageID :String, documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
						authorization :String?)
	static	let	documentCreateEndpoint =
						JSONHTTPEndpoint<[[String : Any]], DocumentCreateEndpointInfo>(method: .post,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> DocumentCreateEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	documentType = pathComponents[3].removingPercentEncoding!

									return (documentStorageID, documentType,
											info.map({ MDSDocument.CreateInfo(httpServicesInfo: $0) }),
											headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentCreate(documentStorageID :String, documentType :String,
			documentCreateInfos :[MDSDocument.CreateInfo], authorization :String? = nil) ->
			MDSJSONHTTPEndpointRequest<[[String : Any]]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest<[[String : Any]]>(method: .post,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)", headers: headers,
				jsonBody: documentCreateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: - Document Get Count
	typealias DocumentGetCountEndpointInfo = (documentStorageID :String, documentType :String, authorization :String?)
	static	let	documentGetCountEndpoint =
						BasicHTTPEndpoint<DocumentGetCountEndpointInfo>(method: .head,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers) -> DocumentGetCountEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]

									return (documentStorageID, documentType, headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentGetCount(documentStorageID :String, documentType :String,
			authorization :String? = nil) -> MDSHeadHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSHeadHTTPEndpointRequest(method: .head,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)", headers: headers)
	}

	// MARK: - Document Get
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
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	documentType = pathComponents[3].removingPercentEncoding!

									let	queryItemsMap = urlComponents.queryItemsMap

									return (documentStorageID, documentType, queryItemsMap.stringArray(for: "id"),
											Int(queryItemsMap["sinceRevision"] as? String),
											Int(queryItemsMap["count"] as? String), headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentGet(documentStorageID :String, documentType :String, sinceRevision :Int,
			count :Int? = nil, authorization :String? = nil) -> DocumentGetSinceRevisionHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		var	queryComponents :[String : Any] = ["sinceRevision": sinceRevision]
		queryComponents["count"] = count

		return DocumentGetSinceRevisionHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)", queryComponents: queryComponents,
				headers: headers)
	}
	static func httpEndpointRequestForDocumentGet(documentStorageID :String, documentType :String,
			documentIDs :[String], authorization :String? = nil) -> DocumentGetForDocumentIDsHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return DocumentGetForDocumentIDsHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)",
				multiValueQueryComponent: ("id", documentIDs), headers: headers)
	}

	// MARK: - Document Update
	typealias DocumentUpdateEndpointInfo =
				(documentStorageID :String, documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo],
						authorization :String?)
	static	let	documentUpdateEndpoint =
						JSONHTTPEndpoint<[[String : Any]], DocumentUpdateEndpointInfo>(method: .patch,
								path: "/v1/document/:documentStorageID/:type")
								{ (urlComponents, headers, info) -> DocumentUpdateEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	documentType = pathComponents[3].removingPercentEncoding!

									if info.first(where: { $0["documentID"] == nil }) != nil {
										// Missing documemtID
										throw HTTPEndpointError.badRequest(with: "Missing documentID")
									}

									return (documentStorageID, documentType,
											info.compactMap({ MDSDocument.UpdateInfo(httpServicesInfo: $0) }),
											headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentUpdate(documentStorageID :String, documentType :String,
			documentUpdateInfos :[MDSDocument.UpdateInfo], authorization :String? = nil) ->
			MDSJSONHTTPEndpointRequest<[[String : Any]]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest<[[String : Any]]>(method: .patch,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)", headers: headers,
				jsonBody: documentUpdateInfos.map({ $0.httpServicesInfo }))
	}

	// MARK: - Document Attachment Add
	typealias DocumentAttachmentAddEndpointInfo =
				(documentStorageID :String, documentType :String, documentID :String, info :[String : Any]?,
						content :Data?, authorization :String?)
	static	let	documentAttachmentAddEndpoint =
						JSONHTTPEndpoint<[String : Any], DocumentAttachmentAddEndpointInfo>(method: .post,
								path: "/v1/document/:documentStorageID/:documentType/:documentID/attachment")
								{ (urlComponents, headers, info) -> DocumentAttachmentAddEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]
									let	documentID = pathComponents[4].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, documentType, documentID,
											info["info"] as? [String : Any],
											Data(base64Encoded: (info["content"] as? String) ?? " "),
											headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentAttachmentAdd(documentStorageID :String, documentType :String,
			documentID :String, info :[String : Any], content :Data, authorization :String? = nil) ->
			MDSJSONHTTPEndpointRequest<[String : Any]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	documentIDUse = documentID.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest<[String : Any]>(method: .post,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)/\(documentIDUse)/attachment",
				headers: headers, jsonBody: ["info": info, "content": content.base64EncodedString()])
	}

	// MARK: - Document Attachment Get
	typealias DocumentAttachmentGetEndpointInfo =
				(documentStorageID :String, documentType :String, documentID :String, attachmentID :String,
						authorization :String?)
	static	let	documentAttachmentGetEndpoint =
						BasicHTTPEndpoint<DocumentAttachmentGetEndpointInfo>(method: .get,
								path: "/v1/document/:documentStorageID/:documentType/:documentID/attachment/:attachmentID")
								{ (urlComponents, headers) -> DocumentAttachmentGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]
									let	documentID = pathComponents[4].replacingOccurrences(of: "_", with: "/")
									let	attachmentID = pathComponents[6].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, documentType, documentID, attachmentID,
											headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentAttachmentGet(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, authorization :String? = nil) -> MDSDataHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	documentIDUse = documentID.transformedForPath
		let	attachmentIDUse = attachmentID.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSDataHTTPEndpointRequest(method: .get,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers)
	}

	// MARK: - Document Attachment Update
	typealias DocumentAttachmentUpdateEndpointInfo =
				(documentStorageID :String, documentType :String, documentID :String, attachmentID :String,
						info :[String : Any]?, content :Data?, authorization :String?)
	static	let	documentAttachmentUpdateEndpoint =
						JSONHTTPEndpoint<[String : Any], DocumentAttachmentUpdateEndpointInfo>(method: .patch,
								path: "/v1/document/:documentStorageID/:documentType/:documentID/attachment/:attachmentID")
								{ (urlComponents, headers, info) -> DocumentAttachmentUpdateEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]
									let	documentID = pathComponents[4].replacingOccurrences(of: "_", with: "/")
									let	attachmentID = pathComponents[6].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, documentType, documentID, attachmentID,
											info["info"] as? [String : Any],
											Data(base64Encoded: (info["content"] as? String) ?? " "),
											headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentAttachmentUpdate(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, info :[String : Any], content :Data,
			authorization :String? = nil) -> MDSJSONHTTPEndpointRequest<[String : Any]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	documentIDUse = documentID.transformedForPath
		let	attachmentIDUse = attachmentID.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest<[String : Any]>(method: .patch,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers, jsonBody: ["info": info, "content": content.base64EncodedString()])
	}

	// MARK: - Document Attachment Remove
	typealias DocumentAttachmentRemoveEndpointInfo =
				(documentStorageID :String, documentType :String, documentID :String, attachmentID :String,
						authorization :String?)
	static	let	documentAttachmentRemoveEndpoint =
						BasicHTTPEndpoint<DocumentAttachmentRemoveEndpointInfo>(method: .delete,
								path: "/v1/document/:documentStorageID/:documentType/:documentID/attachment/:attachmentID")
								{ (urlComponents, headers) -> DocumentAttachmentRemoveEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].replacingOccurrences(of: "_", with: "/")
									let	documentType = pathComponents[3]
									let	documentID = pathComponents[4].replacingOccurrences(of: "_", with: "/")
									let	attachmentID = pathComponents[6].replacingOccurrences(of: "_", with: "/")

									return (documentStorageID, documentType, documentID, attachmentID,
											headers["Authorization"])
								}
	static func httpEndpointRequestForDocumentAttachmentRemove(documentStorageID :String, documentType :String,
			documentID :String, attachmentID :String, authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	documentTypeUse = documentType.transformedForPath
		let	documentIDUse = documentID.transformedForPath
		let	attachmentIDUse = attachmentID.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .delete,
				path: "/v1/document/\(documentStorageIDUse)/\(documentTypeUse)/\(documentIDUse)/attachment/\(attachmentIDUse)",
				headers: headers)
	}

	// MARK: - Index Register
	typealias IndexRegisterEndpointInfo =
				(documentStorageID :String, name :String?, documentType :String?, relevantProperties :[String]?,
						isUpToDate :Bool, keysSelector :String?, keysSelectorInfo: [String : Any]?,
						authorization :String?)
	static	let	indexRegisterEndpoint =
						JSONHTTPEndpoint<[String : Any], IndexRegisterEndpointInfo>(method: .put,
								path: "/v1/index/:documentStorageID")
								{ (urlComponents, headers, info) -> IndexRegisterEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!

									return (documentStorageID, info["name"] as? String, info["documentType"] as? String,
											info["relevantProperties"] as? [String],
											((info["isUpToDate"] as? Int) ?? 0) == 1, info["keysSelector"] as? String,
											info["keysSelectorInfo"] as? [String : Any], headers["Authorization"])
								}
	static func httpEndpointRequestForIndexRegister(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], isUpToDate :Bool = false, keysSelector :String,
			keysSelectorInfo :[String : Any] = [:], authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
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
	class IndexGetDocumentInfoHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[String : [String : Int]]> {}
	class IndexGetDocumentHTTPEndpointRequest : MDSJSONHTTPEndpointRequest<[String : [String : Any]]> {}
	typealias IndexDocumentGetInfoEndpointInfo =
				(documentStorageID :String, name :String, fullInfo :Bool, keys :[String]?, authorization :String?)
	static	let	indexGetDocumentInfoEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/index/:documentStorageID/:name")
								{ (urlComponents, headers) -> IndexDocumentGetInfoEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!
									let	name = pathComponents[3].removingPercentEncoding!

									let	queryItemsMap = urlComponents.queryItemsMap

									return (documentStorageID, name,
											(Int(queryItemsMap["fullInfo"] as? String) ?? 0) == 1,
											queryItemsMap.stringArray(for: "key"), headers["Authorization"])
								}
	static func httpEndpointRequestForIndexGetDocumentInfos(documentStorageID :String, name :String, keys :[String],
			authorization :String? = nil) -> IndexGetDocumentInfoHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return IndexGetDocumentInfoHTTPEndpointRequest(method: .get,
				path: "/v1/index/\(documentStorageIDUse)/\(nameUse)", queryComponents: ["fullInfo": 0],
				multiValueQueryComponent: ("key", keys), headers: headers)
	}
	static func httpEndpointRequestForIndexGetDocuments(documentStorageID :String, name :String, keys :[String],
			authorization :String? = nil) -> IndexGetDocumentHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	nameUse = name.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return IndexGetDocumentHTTPEndpointRequest(method: .get,
				path: "/v1/index/\(documentStorageIDUse)/\(nameUse)", queryComponents: ["fullInfo": 1],
				multiValueQueryComponent: ("key", keys), headers: headers)
	}

	// MARK: - Info Get
	typealias InfoGetEndpointInfo = (documentStorageID :String, keys :[String]?, authorization :String?)
	static	let	infoGetEndpoint =
						BasicHTTPEndpoint(method: .get, path: "/v1/info/:documentStorageID")
								{ (urlComponents, headers) -> InfoGetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!

									let	queryItemsMap = urlComponents.queryItemsMap

									return (documentStorageID, queryItemsMap.stringArray(for: "key"),
											headers["Authorization"])
								}
	static func httpEndpointRequestForInfoGet(documentStorageID :String, keys :[String], authorization :String? = nil)
			-> MDSJSONHTTPEndpointRequest<[String : String]> {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSJSONHTTPEndpointRequest(method: .get, path: "/v1/info/\(documentStorageIDUse)",
				multiValueQueryComponent: ("key", keys), headers: headers)
	}

	// MARK: - Info Set
	typealias InfoSetEndpointInfo = (documentStorageID :String, info :[String : String], authorization :String?)
	static	let	infoSetEndpoint =
						JSONHTTPEndpoint<[String : String], InfoSetEndpointInfo>(method: .post,
								path: "/v1/info/:documentStorageID")
								{ (urlComponents, headers, info) -> InfoSetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!

									return (documentStorageID, info, headers["Authorization"])
								}
	static func httpEndpointRequestForInfoSet(documentStorageID :String, info :[String : String],
			authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .post, path: "/v1/info/\(documentStorageIDUse)", headers: headers,
				jsonBody: info)
	}

	// MARK: - Internal Set
	typealias InternalSetEndpointInfo = (documentStorageID :String, info :[String : String], authorization :String?)
	static	let	internalSetEndpoint =
						JSONHTTPEndpoint<[String : String], InternalSetEndpointInfo>(method: .post,
								path: "/v1/internal/:documentStorageID")
								{ (urlComponents, headers, info) -> InternalSetEndpointInfo in
									// Retrieve and validate
									let	pathComponents = urlComponents.path.pathComponents
									let	documentStorageID = pathComponents[2].removingPercentEncoding!

									return (documentStorageID, info, headers["Authorization"])
								}
	static func httpEndpointRequestForInternalSet(documentStorageID :String, info :[String : String],
			authorization :String? = nil) -> MDSSuccessHTTPEndpointRequest {
		// Setup
		let	documentStorageIDUse = documentStorageID.transformedForPath
		let	headers = (authorization != nil) ? ["Authorization" : authorization!] : nil

		return MDSSuccessHTTPEndpointRequest(method: .post, path: "/v1/internal/\(documentStorageIDUse)",
				headers: headers, jsonBody: info)
	}
}
