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

extension HTTPEndpointClientMDSExtensionsError : LocalizedError {

	// MARK: Properties
	public	var	errorDescription :String? {
						// What are we
						switch self {
							case .didNotReceiveSizeInHeader: return "Did not receive size in header"
						}
					}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - HTTPEndpointClient extension
extension HTTPEndpointClient {

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func queue(
			_ getDocumentsSinceRevisionHTTPEndpointRequest
					:MDSHTTPServices.GetDocumentsSinceRevisionHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ documentFullInfos :[MDSDocumentFullInfo]?, _ isComplete :Bool?,
							_ error :Error?) -> Void) {
		// Setup
		getDocumentsSinceRevisionHTTPEndpointRequest.completionProc = { response, info, error in
			// Handle results
			if info != nil {
				// Check headers
				if let contentRange = response!.contentRange, let size = contentRange.size {
					// Success
					DispatchQueue.global().async() {
						// Convert
						let	documentFullInfos = info!.map({ MDSDocumentFullInfo(httpServicesInfo: $0) })

						// Switch queues to minimize memory usage
						DispatchQueue.global().async() {
							// Call completion proc
							completionProc(documentFullInfos, documentFullInfos.count == size, nil)
						}
					}
				} else {
					// Bad server
					completionProc(nil, nil, HTTPEndpointClientMDSExtensionsError.didNotReceiveSizeInHeader)
				}
			} else {
				// Error
				completionProc(nil, nil,
						error ?? HTTPEndpointStatusError.for(HTTPEndpointStatus(rawValue: response!.statusCode)!))
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
			partialResultsProc :@escaping (_ documentFullInfos :[MDSDocumentFullInfo]?, _ error :Error?) -> Void,
			completionProc
					:@escaping
							MDSHTTPServices.GetDocumentsForDocumentIDsHTTPEndpointRequest.MultiResponseCompletionProc) {
		// Setup
		getDocumentsForDocumentIDsHTTPEndpointRequest.multiResponsePartialResultsProc =
			{ partialResultsProc($1?.map({ MDSDocumentFullInfo(httpServicesInfo: $0) }), $2) }
		getDocumentsForDocumentIDsHTTPEndpointRequest.multiResponseCompletionProc = completionProc

		// Queue
		queue(getDocumentsForDocumentIDsHTTPEndpointRequest, identifier: identifier, priority: priority)
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
						$2 ?? HTTPEndpointStatusError.for(HTTPEndpointStatus(rawValue: $0!.statusCode)!))
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
					:@escaping (_ isUpToDate :Bool?, _ documentRevisionInfos :[MDSDocumentRevisionInfo]?,
							_ isComplete :Bool?, _ error :Error?) -> Void) {
		// Setup
		getCollectionDocumentInfosHTTPEndpointRequest.completionProc = { response, info, error in
			// Handle results
			if info != nil {
				// Check headers
				if let contentRange = response!.contentRange, let size = contentRange.size {
					// Success
					DispatchQueue.global().async() {
						// Convert
						let	documentRevisionInfos =
									info!.map({ MDSDocumentRevisionInfo(documentID: $0.key, revision: $0.value) })

						// Switch queues to minimize memory usage
						DispatchQueue.global().async() {
							// Call completion proc
							completionProc(true, documentRevisionInfos, documentRevisionInfos.count == size, nil)
						}
					}
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
						error ?? HTTPEndpointStatusError.for(HTTPEndpointStatus(rawValue: response!.statusCode)!))
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
							(_ isUpToDate :Bool?, _ documentRevisionInfoMap :[String : MDSDocumentRevisionInfo]?,
									_ error :Error?) -> Void,
			completionProc
					:@escaping
							MDSHTTPServices.GetIndexDocumentInfosHTTPEndpointRequest.MultiResponseCompletionProc) {
		// Setup
		getIndexDocumentInfosHTTPEndpointRequest.multiResponsePartialResultsProc = { response, info, error in
			// Handle results
			if info != nil {
				// Success
				DispatchQueue.global().async() {
					// Convert
					let	documentRevisionInfoMap =
								info!.mapValues(
										{ MDSDocumentRevisionInfo(documentID: $0.first!.key,
												revision: $0.first!.value) })

					// Switch queues to minimize memory usage
					DispatchQueue.global().async() {
						// Call completion proc
						partialResultsProc(true, documentRevisionInfoMap, nil)
					}
				}
			} else if response?.statusCode == 409 {
				// Not up to date
				partialResultsProc(false, nil, nil)
			} else {
				// Error
				partialResultsProc(nil, nil,
						error ?? HTTPEndpointStatusError.for(HTTPEndpointStatus(rawValue: response!.statusCode)!))
			}
		}
		getIndexDocumentInfosHTTPEndpointRequest.multiResponseCompletionProc = completionProc

		// Queue
		queue(getIndexDocumentInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}
}
