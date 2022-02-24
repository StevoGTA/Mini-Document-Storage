//
//  HTTPEndpointClient+MDSExtensions.swift
//  Mini Document Storage
//
//  Created by Stevo on 11/27/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: HTTPEndpointClientMDSExtensionsError
enum HTTPEndpointClientMDSExtensionsError : Error {
	case didNotReceiveSizeInHeader
}

extension HTTPEndpointClientMDSExtensionsError : CustomStringConvertible, LocalizedError {

	// MARK: Properties
	public 	var	description :String { self.localizedDescription }
	public	var	errorDescription :String? {
						// What are we
						switch self {
							case .didNotReceiveSizeInHeader: return "Did not receive size in header"
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentCreateReturnInfo
struct MDSDocumentCreateReturnInfo {

	// MARK: Properties
	let	documentID :String
	let	revision :Int
	let	creationDate :Date
	let	modificationDate :Date

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServicesInfo :[String : Any]) {
		// Store
		self.documentID = httpServicesInfo["documentID"] as! String
		self.revision = httpServicesInfo["revision"] as! Int
		self.creationDate = Date(fromRFC3339Extended: httpServicesInfo["creationDate"] as? String)!
		self.modificationDate = Date(fromRFC3339Extended: httpServicesInfo["modificationDate"] as? String)!
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentUpdateReturnInfo
struct MDSDocumentUpdateReturnInfo {

	// MARK: Properties
	let	documentID :String
	let	revision :Int
	let	active :Bool
	let	modificationDate :Date
	let	propertyMap :[String : Any]

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpServicesInfo :[String : Any]) {
		// Store
		self.documentID = httpServicesInfo["documentID"] as! String
		self.revision = httpServicesInfo["revision"] as! Int
		self.active = httpServicesInfo["active"] as! Bool
		self.modificationDate = Date(fromRFC3339Extended: httpServicesInfo["modificationDate"] as? String)!
		self.propertyMap = httpServicesInfo["json"] as! [String : Any]
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - HTTPEndpointClient extension
extension HTTPEndpointClient {

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func queue(documentStorageID :String, type :String, documentCreateInfos :[MDSDocument.CreateInfo],
			authorization :String? = nil,
			partialResultsProc :@escaping (_ documentCreateReturnInfos :[MDSDocumentCreateReturnInfo]) -> Void,
			completionProc :@escaping(_ errors :[Error]) -> Void) {
		// Setup
		let	documentCreateInfosChunks = documentCreateInfos.chunk(by: 100)
		let	pendingCount = LockingNumeric<Int>(documentCreateInfosChunks.count)
		let	errors = LockingArray<Error>()

		// Iterate and queue
		documentCreateInfosChunks.forEach() {
			// Queue this chunk
			queue(
					MDSHTTPServices.httpEndpointRequestForCreateDocuments(documentStorageID: documentStorageID,
							documentType: type, documentCreateInfos: $0, authorization: authorization))
					{ response, infos, error in
						// Handle results
						if infos != nil {
							// Run lean
							autoreleasepool() {
								// Call partial results proc
								partialResultsProc(infos!.map({ MDSDocumentCreateReturnInfo(httpServicesInfo: $0) }))
							}
						} else {
							// Error
							errors.append(error!)
						}

						// One more complete
						if pendingCount.subtract(1) == 0 {
							// All done
							completionProc(errors.values)
						}
					}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(
			_ getDocumentsSinceRevisionHTTPEndpointRequest
					:MDSHTTPServices.GetDocumentsSinceRevisionHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			partialResultsProc :@escaping (_ documentFullInfos :[MDSDocument.FullInfo]) -> Void,
			completionProc :@escaping (_ isComplete :Bool?, _ error :Error?) -> Void) {
		// Setup
		getDocumentsSinceRevisionHTTPEndpointRequest.completionProc = { response, info, error in
			// Handle results
			if info != nil {
				// Check headers
				if let contentRange = response!.contentRange, let size = contentRange.size {
					// Success
					DispatchQueue.global().async() {
						// Process in chunks to control memory usage
						info!.chunk(by: 1000).forEach() { infos in
							// Run lean
							autoreleasepool() {
								// Call partial results proc
								partialResultsProc(infos.map({ MDSDocument.FullInfo(httpServicesInfo: $0) }))
							}
						}

						// Call completion proc
						completionProc(info!.count == size, nil)
					}
				} else {
					// Bad server
					completionProc(nil, HTTPEndpointClientMDSExtensionsError.didNotReceiveSizeInHeader)
				}
			} else {
				// Error
				completionProc(nil,
						error ?? HTTPEndpointStatusError(status: HTTPEndpointStatus(rawValue: response!.statusCode)!))
			}
		}

		// Queue
		queue(getDocumentsSinceRevisionHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(
			_ getDocumentsForDocumentIDsHTTPEndpointRequest
					:MDSHTTPServices.GetDocumentsForDocumentIDsHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			partialResultsProc :@escaping (_ documentFullInfos :[MDSDocument.FullInfo]?, _ error :Error?) -> Void,
			completionProc
					:@escaping
							MDSHTTPServices.GetDocumentsForDocumentIDsHTTPEndpointRequest.MultiResponseCompletionProc) {
		// Setup
		getDocumentsForDocumentIDsHTTPEndpointRequest.multiResponsePartialResultsProc =
			{ partialResultsProc($1?.map({ MDSDocument.FullInfo(httpServicesInfo: $0) }), $2) }
		getDocumentsForDocumentIDsHTTPEndpointRequest.multiResponseCompletionProc = completionProc

		// Queue
		queue(getDocumentsForDocumentIDsHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(documentStorageID :String, type :String, documentUpdateInfos :[MDSDocument.UpdateInfo],
			authorization :String? = nil,
			partialResultsProc :@escaping (_ documentUpdateReturnInfo :[MDSDocumentUpdateReturnInfo]) -> Void,
			completionProc :@escaping(_ errors :[Error]) -> Void) {
		// Setup
		let	documentUpdateInfosChunks = documentUpdateInfos.chunk(by: 100)
		let	pendingCount = LockingNumeric<Int>(documentUpdateInfosChunks.count)
		let	errors = LockingArray<Error>()

		// Iterate and queue
		documentUpdateInfosChunks.forEach() {
			// Queue this chunk
			queue(
					MDSHTTPServices.httpEndpointRequestForUpdateDocuments(documentStorageID: documentStorageID,
							documentType: type, documentUpdateInfos: $0, authorization: authorization))
					{ response, infos, error in
						// Handle results
						if infos != nil {
							// Run lean
							autoreleasepool() {
								// Call partial results proc
								partialResultsProc(infos!.map({ MDSDocumentUpdateReturnInfo(httpServicesInfo: $0) }))
							}
						} else {
							// Error
							errors.append(error!)
						}

						// One more complete
						if pendingCount.subtract(1) == 0 {
							// All done
							completionProc(errors.values)
						}
					}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue<T : MDSDocument, U : MDSDocument>(documentStorageID :String, name :String,
			updates :[(action :MDSAssociationAction, fromDocument :T, toDocument :U)], authorization :String? = nil,
			completionProc :@escaping(_ errors :[Error]) -> Void) {
		// Setup
		let	updatesChunks = updates.chunk(by: 100)
		let	pendingCount = LockingNumeric<Int>(updatesChunks.count)
		let	errors = LockingArray<Error>()

		// Iterate and queue
		updatesChunks.forEach() {
			// Queue this chunk
			queue(
					MDSHTTPServices.httpEndpointRequestForUpdateAssocation(documentStorageID: documentStorageID,
							name: name, updates: $0.map({ ($0.action, $0.fromDocument.id, $0.toDocument.id) }),
							authorization: authorization))
					{ response, error in
						// Handle results
						if error != nil {
							// Error
							errors.append(error!)
						}

						// One more complete
						if pendingCount.subtract(1) == 0 {
							// All done
							completionProc(errors.values)
						}
					}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(
			_ getAssociationDocumentInfosHTTPEndpointRequest
					:MDSHTTPServices.GetAssociationDocumentInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ documentRevisionInfos :[MDSDocument.RevisionInfo]?, _ isComplete :Bool?,
							_ error :Error?) -> Void) {
		// Setup
		getAssociationDocumentInfosHTTPEndpointRequest.completionProc = { response, info, error in
			// Handle results
			if info != nil {
				// Check headers
				if let contentRange = response!.contentRange, let size = contentRange.size {
					// Success
					DispatchQueue.global().async() {
						// Convert
						let	documentRevisionInfos =
									info!.map({ MDSDocument.RevisionInfo(documentID: $0.key, revision: $0.value) })

						// Switch queues to minimize memory usage
						DispatchQueue.global().async() {
							// Call completion proc
							completionProc(documentRevisionInfos, documentRevisionInfos.count == size, nil)
						}
					}
				} else {
					// Bad server
					completionProc(nil, nil, HTTPEndpointClientMDSExtensionsError.didNotReceiveSizeInHeader)
				}
			} else {
				// Error
				completionProc(nil, nil,
						error ?? HTTPEndpointStatusError(status: HTTPEndpointStatus(rawValue: response!.statusCode)!))
			}
		}

		// Queue
		queue(getAssociationDocumentInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ getAssociationValueHTTPEndpointRequest :MDSHTTPServices.GetAssociationValueHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc :@escaping (_ isUpToDate :Bool?, _ count :Int?, _ error :Error?) -> Void) {
		// Setup
		getAssociationValueHTTPEndpointRequest.completionProc = {
			// Handle results
			if $0?.statusCode == 200 {
				// Success
				completionProc(true, $1!, nil)
			} else if $0?.statusCode == 409 {
				// Not up to date
				completionProc(false, nil, nil)
			} else {
				// Error
				completionProc(nil, nil,
						$2 ?? HTTPEndpointStatusError(status: HTTPEndpointStatus(rawValue: $0!.statusCode)!))
			}
		}

		// Queue
		queue(getAssociationValueHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(
			_ getCollectionDocumentCountHTTPEndpointRequest
					:MDSHTTPServices.GetCollectionDocumentCountHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc :@escaping (_ isUpToDate :Bool?, _ count :Int?, _ error :Error?) -> Void) {
		// Setup
		getCollectionDocumentCountHTTPEndpointRequest.completionProc = {
			// Handle results
			if $0?.statusCode == 200 {
				// Success
				if let contentRange = $0?.contentRange, let size = contentRange.size {
					// Success
					completionProc(true, Int(size), nil)
				} else {
					// Bad server
					completionProc(nil, nil, HTTPEndpointClientMDSExtensionsError.didNotReceiveSizeInHeader)
				}
			} else if $0?.statusCode == 409 {
				// Not up to date
				completionProc(false, nil, nil)
			} else {
				// Error
				completionProc(nil, nil,
						$1 ?? HTTPEndpointStatusError(status: HTTPEndpointStatus(rawValue: $0!.statusCode)!))
			}
		}

		// Queue
		queue(getCollectionDocumentCountHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(
			_ getCollectionDocumentInfosHTTPEndpointRequest
					:MDSHTTPServices.GetCollectionDocumentInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ isUpToDate :Bool?, _ documentRevisionInfos :[MDSDocument.RevisionInfo]?,
							_ isComplete :Bool?, _ error :Error?) -> Void) {
		// Setup
		getCollectionDocumentInfosHTTPEndpointRequest.completionProc = { response, info, error in
			// Handle results
			if info != nil {
				// Check headers
				if let contentRange = response!.contentRange, let size = contentRange.size {
					// Success
					let	documentRevisionInfos =
								info!.map({ MDSDocument.RevisionInfo(documentID: $0.key, revision: $0.value) })

					// Call completion proc
					completionProc(true, documentRevisionInfos, documentRevisionInfos.count == size, nil)
				} else {
					// Bad server
					completionProc(nil, nil, nil, HTTPEndpointClientMDSExtensionsError.didNotReceiveSizeInHeader)
				}
			} else if response?.statusCode == 409 {
				// Not up to date
				completionProc(false, nil, nil, nil)
			} else {
				// Error
				completionProc(nil, nil, nil,
						error ?? HTTPEndpointStatusError(status: HTTPEndpointStatus(rawValue: response!.statusCode)!))
			}
		}

		// Queue
		queue(getCollectionDocumentInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ getIndexDocumentInfosHTTPEndpointRequest :MDSHTTPServices.GetIndexDocumentInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			partialResultsProc
					:@escaping
							(_ isUpToDate :Bool?, _ documentRevisionInfoMap :[String : MDSDocument.RevisionInfo]?,
									_ error :Error?) -> Void,
			completionProc
					:@escaping
							MDSHTTPServices.GetIndexDocumentInfosHTTPEndpointRequest.MultiResponseCompletionProc) {
		// Setup
		getIndexDocumentInfosHTTPEndpointRequest.multiResponsePartialResultsProc = { response, info, error in
			// Handle results
			if info != nil {
				// Success
				let	documentRevisionInfoMap =
							info!.mapValues(
									{ MDSDocument.RevisionInfo(documentID: $0.first!.key, revision: $0.first!.value) })

				// Call completion proc
				partialResultsProc(true, documentRevisionInfoMap, nil)
			} else if response?.statusCode == 409 {
				// Not up to date
				partialResultsProc(false, nil, nil)
			} else {
				// Error
				partialResultsProc(nil, nil,
						error ?? HTTPEndpointStatusError(status: HTTPEndpointStatus(rawValue: response!.statusCode)!))
			}
		}
		getIndexDocumentInfosHTTPEndpointRequest.multiResponseCompletionProc = completionProc

		// Queue
		queue(getIndexDocumentInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}
}
