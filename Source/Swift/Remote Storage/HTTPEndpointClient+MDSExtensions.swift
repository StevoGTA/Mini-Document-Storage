//
//  HTTPEndpointClient+MDSExtensions.swift
//  Mini Document Storage
//
//  Created by Stevo on 11/27/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocument extension
extension MDSDocument {

	// MARK: CreateReturnInfo
	struct CreateReturnInfo {

		// MARK: Properties
		let	documentID :String
		let	revision :Int
		let	creationDate :Date
		let	modificationDate :Date

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(httpServicesInfo :[String : Any]) {
			// Store
			self.documentID = httpServicesInfo["documentID"] as! String
			self.revision = httpServicesInfo["revision"] as! Int
			self.creationDate = Date(fromRFC3339Extended: httpServicesInfo["creationDate"] as? String)!
			self.modificationDate = Date(fromRFC3339Extended: httpServicesInfo["modificationDate"] as? String)!
		}
	}

	// MARK: UpdateReturnInfo
	struct UpdateReturnInfo {

		// MARK: Properties
		let	documentID :String
		let	revision :Int
		let	active :Bool
		let	modificationDate :Date
		let	propertyMap :[String : Any]

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(httpServicesInfo :[String : Any]) {
			// Store
			self.documentID = httpServicesInfo["documentID"] as! String
			self.revision = httpServicesInfo["revision"] as! Int
			self.active = httpServicesInfo["active"] as! Bool
			self.modificationDate = Date(fromRFC3339Extended: httpServicesInfo["modificationDate"] as? String)!
			self.propertyMap = httpServicesInfo["json"] as! [String : Any]
		}
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - HTTPEndpointClient extension for convenience queue methods
extension HTTPEndpointClient {

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func queue(_ dataHTTPEndpointRequest :MDSHTTPServices.MDSDataHTTPEndpointRequest, identifier :String = "",
			priority :Priority = .normal,
			completionProc :@escaping MDSHTTPServices.MDSDataHTTPEndpointRequest.CompletionProc) {
		// Setup
		dataHTTPEndpointRequest.completionProc = completionProc

		// Queue
		queue(dataHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ headHTTPEndpointRequest :MDSHTTPServices.MDSHeadHTTPEndpointRequest, identifier :String = "",
			priority :Priority = .normal,
			completionProc :@escaping MDSHTTPServices.MDSHeadHTTPEndpointRequest.CompletionProc) {
		// Setup
		headHTTPEndpointRequest.completionProc = completionProc

		// Queue
		queue(headHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ headWithUpToDateHTTPEndpointRequest :MDSHTTPServices.MDSHeadWithUpToDateHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionWithUpToDateProc
					:@escaping MDSHTTPServices.MDSHeadWithUpToDateHTTPEndpointRequest.CompletionWithUpToDateProc) {
		// Setup
		headWithUpToDateHTTPEndpointRequest.completionWithUpToDateProc = completionWithUpToDateProc

		// Queue
		queue(headWithUpToDateHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ integerWithUpToDateHTTPEndpointRequest :MDSHTTPServices.MDSIntegerWithUpToDateHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionWithUpToDateProc
					:@escaping MDSHTTPServices.MDSIntegerWithUpToDateHTTPEndpointRequest.CompletionWithUpToDateProc) {
		// Setup
		integerWithUpToDateHTTPEndpointRequest.completionWithUpToDateProc = completionWithUpToDateProc

		// Queue
		queue(integerWithUpToDateHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue<T>(_ jsonHTTPEndpointRequest :MDSHTTPServices.MDSJSONHTTPEndpointRequest<T>, identifier :String = "",
			priority :Priority = .normal,
			completionProc :@escaping MDSHTTPServices.MDSJSONHTTPEndpointRequest<T>.SingleResponseCompletionProc) {
		// Setup
		jsonHTTPEndpointRequest.completionProc = completionProc

		// Queue
		queue(jsonHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ successHTTPEndpointRequest :MDSHTTPServices.MDSSuccessHTTPEndpointRequest, identifier :String = "",
			priority :Priority = .normal,
			completionProc :@escaping MDSHTTPServices.MDSSuccessHTTPEndpointRequest.CompletionProc) {
		// Setup
		successHTTPEndpointRequest.completionProc = completionProc

		// Queue
		queue(successHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ associationGetHTTPEndpointRequest :MDSHTTPServices.AssociationGetHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (
							_ info :(associations :[(fromDocumentID :String, toDocumentID :String)],
									isComplete :Bool)?,
							_ error :Error?) -> Void) {
		// Setup
		associationGetHTTPEndpointRequest.completionWithCountProc = { info, error in
			// Handle results
			if info != nil {
				// Success
				let	associations = info!.info.map({ ($0["fromDocumentID"]!, $0["toDocumentID"]!) })

				// Call completion
				completionProc((associations, info!.isComplete), nil)
			} else {
				// Error
				completionProc(nil, error)
			}
		}

		// Queue
		queue(associationGetHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ collectionGetDocumentInfoHTTPEndpointRequest
					:MDSHTTPServices.CollectionGetDocumentInfoHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ isUpToDate :Bool?,
							_ info: (documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?,
							_ error :Error?) -> Void) {
		// Setup
		collectionGetDocumentInfoHTTPEndpointRequest.completionWithUpToDateAndCountProc = { isUpToDate, info, error in
			// Handle results
			if info != nil {
				// Success
				DispatchQueue.global().async() {
					// Convert
					let	documentRevisionInfos =
								info!.info.map(
										{ MDSDocument.RevisionInfo(documentID: $0["documentID"] as! String,
												revision: $0["revision"] as! Int) })

					// Switch queues to minimize memory usage
					DispatchQueue.global().async() {
						// Call completion proc
						completionProc(isUpToDate, (documentRevisionInfos, info!.isComplete), nil)
					}
				}
			} else {
				// Error
				completionProc(isUpToDate, nil, error)
			}
		}

		// Queue
		queue(collectionGetDocumentInfoHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ collectionGetDocumentHTTPEndpointRequest :MDSHTTPServices.CollectionGetDocumentHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ isUpToDate :Bool?,
							_ info: (documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, _ error :Error?) ->
							Void) {
		// Setup
		collectionGetDocumentHTTPEndpointRequest.completionWithUpToDateAndCountProc = { isUpToDate, info, error in
			// Handle results
			if info != nil {
				// Success
				DispatchQueue.global().async() {
					// Convert
					let	documentFullInfos = info!.info.map({ MDSDocument.FullInfo(httpServicesInfo: $0) })

					// Switch queues to minimize memory usage
					DispatchQueue.global().async() {
						// Call completion proc
						completionProc(isUpToDate, (documentFullInfos, info!.isComplete), nil)
					}
				}
			} else {
				// Error
				completionProc(isUpToDate, nil, error)
			}
		}

		// Queue
		queue(collectionGetDocumentHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ getDocumentInfosHTTPEndpointRequest :MDSHTTPServices.GetDocumentInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ info: (documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?,
							_ error :Error?) -> Void) {
		// Setup
		getDocumentInfosHTTPEndpointRequest.completionWithCountProc = { info, error in
			// Handle results
			if info != nil {
				// Success
				DispatchQueue.global().async() {
					// Convert
					let	documentRevisionInfos =
								info!.info.map(
										{ MDSDocument.RevisionInfo(documentID: $0["documentID"] as! String,
												revision: $0["revision"] as! Int) })

					// Switch queues to minimize memory usage
					DispatchQueue.global().async() {
						// Call completion proc
						completionProc((documentRevisionInfos, info!.isComplete), nil)
					}
				}
			} else {
				// Error
				completionProc(nil, error)
			}
		}

		// Queue
		queue(getDocumentInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ getDocumentsHTTPEndpointRequest :MDSHTTPServices.GetDocumentsHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ info: (documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, _ error :Error?)
							-> Void) {
		// Setup
		getDocumentsHTTPEndpointRequest.completionWithCountProc = { info, error in
			// Handle results
			if info != nil {
				// Success
				DispatchQueue.global().async() {
					// Convert
					let	documentFullInfos = info!.info.map({ MDSDocument.FullInfo(httpServicesInfo: $0) })

					// Switch queues to minimize memory usage
					DispatchQueue.global().async() {
						// Call completion proc
						completionProc((documentFullInfos, info!.isComplete), nil)
					}
				}
			} else {
				// Error
				completionProc(nil, error)
			}
		}

		// Queue
		queue(getDocumentsHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(documentStorageID :String, name :String,
			updates :[(action :MDSAssociationAction, fromDocumentID :String, toDocumentID :String)],
			authorization :String? = nil, completionProc :@escaping(_ errors :[Error]) -> Void) {
		// Setup
		guard !updates.isEmpty else {
			// No updates
			completionProc([])

			return
		}

		let	updatesChunks = updates.chunk(by: 100)
		let	pendingCount = LockingNumeric<Int>(updatesChunks.count)
		let	errors = LockingArray<Error>()

		// Iterate and queue
		updatesChunks.forEach() {
			// Queue this chunk
			queue(
					MDSHTTPServices.httpEndpointRequestForAssocationUpdate(documentStorageID: documentStorageID,
							name: name, updates: $0, authorization: authorization))
					{ error in
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
	func queue(documentStorageID :String, type :String, documentCreateInfos :[MDSDocument.CreateInfo],
			authorization :String? = nil,
			partialResultsProc :@escaping (_ documentCreateReturnInfos :[MDSDocument.CreateReturnInfo]) -> Void,
			completionProc :@escaping(_ errors :[Error]) -> Void) {
		// Setup
		let	documentCreateInfosChunks = documentCreateInfos.chunk(by: 100)
		let	pendingCount = LockingNumeric<Int>(documentCreateInfosChunks.count)
		let	errors = LockingArray<Error>()

		// Iterate and queue
		documentCreateInfosChunks.forEach() {
			// Queue this chunk
			queue(
					MDSHTTPServices.httpEndpointRequestForDocumentCreate(documentStorageID: documentStorageID,
							documentType: type, documentCreateInfos: $0, authorization: authorization))
					{ infos, error in
						// Handle results
						if infos != nil {
							// Run lean
							autoreleasepool() {
								// Call partial results proc
								partialResultsProc(infos!.map({ MDSDocument.CreateReturnInfo(httpServicesInfo: $0) }))
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
			_ documentGetSinceRevisionHTTPEndpointRequest
					:MDSHTTPServices.DocumentGetSinceRevisionHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			partialResultsProc :@escaping (_ documentFullInfos :[MDSDocument.FullInfo]) -> Void,
			completionProc :@escaping (_ isComplete :Bool?, _ error :Error?) -> Void) {
		// Setup
		documentGetSinceRevisionHTTPEndpointRequest.completionWithCountProc = { info, error in
			// Handle results
			if let (infos, isComplete) = info {
				// Success
				DispatchQueue.global().async() {
					// Process in chunks to control memory usage
					infos.chunk(by: 1000).forEach() { infos in
						// Run lean
						autoreleasepool() {
							// Call partial results proc
							partialResultsProc(infos.map({ MDSDocument.FullInfo(httpServicesInfo: $0) }))
						}
					}

					// Call completion proc
					completionProc(isComplete, nil)
				}
			} else {
				// Error
				completionProc(nil, error)
			}
		}

		// Queue
		queue(documentGetSinceRevisionHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(
			_ documentGetForDocumentIDsHTTPEndpointRequest
					:MDSHTTPServices.DocumentGetForDocumentIDsHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			partialResultsProc :@escaping (_ documentFullInfos :[MDSDocument.FullInfo]?, _ error :Error?) -> Void,
			completionProc
					:@escaping
							MDSHTTPServices.DocumentGetForDocumentIDsHTTPEndpointRequest.MultiResponseCompletionProc) {
		// Setup
		documentGetForDocumentIDsHTTPEndpointRequest.multiResponsePartialResultsProc =
			{ partialResultsProc($0?.map({ MDSDocument.FullInfo(httpServicesInfo: $0) }), $1) }
		documentGetForDocumentIDsHTTPEndpointRequest.multiResponseCompletionProc = completionProc

		// Queue
		queue(documentGetForDocumentIDsHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(documentStorageID :String, type :String, documentUpdateInfos :[MDSDocument.UpdateInfo],
			authorization :String? = nil,
			partialResultsProc :@escaping (_ documentUpdateReturnInfo :[MDSDocument.UpdateReturnInfo]) -> Void,
			completionProc :@escaping(_ errors :[Error]) -> Void) {
		// Setup
		let	documentUpdateInfosChunks = documentUpdateInfos.chunk(by: 100)
		let	pendingCount = LockingNumeric<Int>(documentUpdateInfosChunks.count)
		let	errors = LockingArray<Error>()

		// Iterate and queue
		documentUpdateInfosChunks.forEach() {
			// Queue this chunk
			queue(
					MDSHTTPServices.httpEndpointRequestForDocumentUpdate(documentStorageID: documentStorageID,
							documentType: type, documentUpdateInfos: $0, authorization: authorization))
					{ infos, error in
						// Handle results
						if infos != nil {
							// Run lean
							autoreleasepool() {
								// Call partial results proc
								partialResultsProc(infos!.map({ MDSDocument.UpdateReturnInfo(httpServicesInfo: $0) }))
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
	func queue(_ indexGetDocumentInfoHTTPEndpointRequest :MDSHTTPServices.IndexGetDocumentInfoHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			partialResultsProc
					:@escaping
							(_ documentRevisionInfoMap :[String : MDSDocument.RevisionInfo]?, _ error :Error?) -> Void,
			completionProc :@escaping (_ isUpToDate :Bool?, _ errors :[Error]) -> Void) {
		// Setup
		indexGetDocumentInfoHTTPEndpointRequest.multiResponsePartialResultsProc = { info, error in
			// Handle results
			if info != nil {
				// Success
				let	documentRevisionInfoMap =
							info!.mapValues(
									{ MDSDocument.RevisionInfo(documentID: $0.first!.key, revision: $0.first!.value) })

				// Call completion proc
				partialResultsProc(documentRevisionInfoMap, nil)
			} else if (error as? HTTPEndpointStatusError)?.status == HTTPEndpointStatus.conflict {
				// Not up to date
			} else {
				// Error
				partialResultsProc(nil, error)
			}
		}
		indexGetDocumentInfoHTTPEndpointRequest.multiResponseCompletionProc = {
			// Setup
			let	nonConflictErrors =
						$0.filter({
							(!($0 is HTTPEndpointStatusError)) ||
									(($0 as! HTTPEndpointStatusError).status != .conflict) })

			completionProc((nonConflictErrors.count > 0) ? nil : ($0.count == 0), nonConflictErrors)
		}

		// Queue
		queue(indexGetDocumentInfoHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ indexGetDocumentHTTPEndpointRequest :MDSHTTPServices.IndexGetDocumentHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			partialResultsProc
					:@escaping (_ documentFullInfosMap :[String : MDSDocument.FullInfo]?, _ error :Error?) -> Void,
			completionProc :@escaping (_ isUpToDate :Bool?, _ errors :[Error]) -> Void) {
		// Setup
		indexGetDocumentHTTPEndpointRequest.multiResponsePartialResultsProc = { info, error in
			// Handle results
			if info != nil {
				// Success
				let	documentRevisionInfoMap = info!.mapValues({ MDSDocument.FullInfo(httpServicesInfo: $0) })

				// Call completion proc
				partialResultsProc(documentRevisionInfoMap, nil)
			} else if (error as? HTTPEndpointStatusError)?.status == HTTPEndpointStatus.conflict {
				// Not up to date
			} else {
				// Error
				partialResultsProc(nil, error)
			}
		}
		indexGetDocumentHTTPEndpointRequest.multiResponseCompletionProc = {
			// Setup
			let	nonConflictErrors =
						$0.filter({
							(!($0 is HTTPEndpointStatusError)) ||
									(($0 as! HTTPEndpointStatusError).status != .conflict) })

			completionProc((nonConflictErrors.count > 0) ? nil : ($0.count == 0), nonConflictErrors)
		}

		// Queue
		queue(indexGetDocumentHTTPEndpointRequest, identifier: identifier, priority: priority)
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - HTTPEndpointClient extension for synchronous methods
extension HTTPEndpointClient {

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func associationRegister(documentStorageID :String, name :String, fromDocumentType :String, toDocumentType :String,
			authorization :String? = nil) -> Error? {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationRegister(documentStorageID: documentStorageID,
							name: name, fromDocumentType: fromDocumentType, toDocumentType: toDocumentType,
							authorization: authorization))
					{ completionProc($0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationUpdate(documentStorageID :String, name :String,
			updates :[(action :MDSAssociationAction, fromDocumentID :String, toDocumentID :String)],
			authorization :String? = nil) -> [Error] {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(documentStorageID: documentStorageID, name: name, updates: updates, authorization: authorization)
					{ completionProc($0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGet(documentStorageID :String, name :String, startIndex :Int = 0, count :Int? = nil,
			authorization :String? = nil) ->
			(info :(associations :[(fromDocumentID :String, toDocumentID :String)], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGet(documentStorageID: documentStorageID,
							name: name, startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentInfo(documentStorageID :String, name :String, fromDocumentID :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			(info :(documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetDocumentInfos(
							documentStorageID: documentStorageID, name: name, fromDocumentID: fromDocumentID,
							startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocument(documentStorageID :String, name :String, fromDocumentID :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			(info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetDocuments(
							documentStorageID: documentStorageID, name: name, fromDocumentID: fromDocumentID,
							startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentInfo(documentStorageID :String, name :String, toDocumentID :String, startIndex :Int = 0,
			count :Int? = nil, authorization :String? = nil) ->
			(info :(documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetDocumentInfos(
							documentStorageID: documentStorageID, name: name, toDocumentID: toDocumentID,
							startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocument(documentStorageID :String, name :String, toDocumentID :String, startIndex :Int = 0,
			count :Int? = nil, authorization :String? = nil) ->
			(info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetDocuments(
							documentStorageID: documentStorageID, name: name, toDocumentID: toDocumentID,
							startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetIntegerValue(documentStorageID :String, name :String, fromID :String,
			action :MDSHTTPServices.AssociationGetValueAction, cacheName :String, cacheValueName :String,
			authorization :String? = nil) -> (info :(isUpToDate :Bool, value :Int?)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssocationGetIntegerValue(
							documentStorageID: documentStorageID, name: name, fromID: fromID, action: action,
							cacheName: cacheName, cacheValueName: cacheValueName, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func cacheRegister(documentStorageID :String, name :String, documentType :String, relevantProperties :[String] = [],
			valueInfos :[MDSHTTPServices.CacheRegisterEndpointValueInfo], authorization :String? = nil) -> Error? {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCacheRegister(documentStorageID: documentStorageID,
							name: name, documentType: documentType, relevantProperties: relevantProperties,
							valueInfos: valueInfos, authorization: authorization))
					{ completionProc($0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionRegister(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], isUpToDate :Bool = false, isIncludedSelector :String,
			isIncludedSelectorInfo :[String : Any] = [:], authorization :String? = nil) -> Error? {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCollectionRegister(documentStorageID: documentStorageID,
							name: name, documentType: documentType, relevantProperties: relevantProperties,
							isUpToDate: isUpToDate, isIncludedSelector: isIncludedSelector,
							isIncludedSelectorInfo: isIncludedSelectorInfo, authorization: authorization))
					{ completionProc($0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentCount(documentStorageID :String, name :String, authorization :String? = nil) ->
			(info :(isUpToDate :Bool, count :Int?)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCollectionGetDocumentCount(
							documentStorageID: documentStorageID, name: name, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentInfo(documentStorageID :String, name :String, startIndex :Int = 0, count :Int? = nil,
			authorization :String? = nil) ->
			(isUpToDate :Bool?, info :(documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?,
					error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCollectionGetDocumentInfo(
							documentStorageID: documentStorageID, name: name, startIndex: startIndex, count: count,
							authorization: authorization))
					{ completionProc(($0, $1, $2)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocument(documentStorageID :String, name :String, startIndex :Int = 0, count :Int? = nil,
			authorization :String? = nil) ->
			(isUpToDate :Bool?, info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCollectionGetDocument(documentStorageID: documentStorageID,
							name: name, startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1, $2)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentCreate(documentStorageID :String, documentType :String,
			documentCreateInfos :[MDSDocument.CreateInfo], authorization :String? = nil) ->
			(documentInfos :[[String : Any]]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentCreate(documentStorageID: documentStorageID,
							documentType: documentType, documentCreateInfos: documentCreateInfos,
							authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGetCount(documentStorageID :String, documentType :String, authorization :String? = nil) ->
			(count :Int?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentGetCount(documentStorageID: documentStorageID,
							documentType: documentType, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGet(documentStorageID :String, documentType :String, sinceRevision :Int,
			authorization :String? = nil) ->
			(info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Setup
			var	documentFullInfos :[MDSDocument.FullInfo]?

			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentGet(documentStorageID: documentStorageID,
							documentType: documentType, sinceRevision: sinceRevision, authorization: authorization),
					partialResultsProc: { documentFullInfos = $0 },
					completionProc:
							{ completionProc((($1 == nil) ? (documentFullInfos ?? [MDSDocument.FullInfo](), $0!) : nil,
									$1)) })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGet(documentStorageID :String, documentType :String, documentIDs :[String],
			authorization :String? = nil) -> (documentInfos :[[String : Any]]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentGet(documentStorageID: documentStorageID,
							documentType: documentType, documentIDs: documentIDs, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdate(documentStorageID :String, documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo],
			authorization :String? = nil) -> (documentInfos :[[String : Any]]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentUpdate(documentStorageID: documentStorageID,
							documentType: documentType, documentUpdateInfos: documentUpdateInfos,
							authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAddAttachment(documentStorageID :String, documentType :String, documentID :String,
			info :[String : Any], content :Data, authorization :String? = nil) ->
			(info :[String : Any]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentAttachmentAdd(documentStorageID: documentStorageID,
							documentType: documentType, documentID: documentID, info: info, content: content,
							authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGetAttachment(documentStorageID :String, documentType :String, documentID :String,
			attachmentID :String, authorization :String? = nil) -> (content :Data?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentAttachmentGet(documentStorageID: documentStorageID,
							documentType: documentType, documentID: documentID, attachmentID: attachmentID,
							authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdateAttachment(documentStorageID :String, documentType :String, documentID :String,
			attachmentID :String, info :[String : Any], content :Data, authorization :String? = nil) ->
			(info :[String : Any]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentAttachmentUpdate(documentStorageID: documentStorageID,
							documentType: documentType, documentID: documentID, attachmentID: attachmentID,
							info: info, content: content, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRemoveAttachment(documentStorageID :String, documentType :String, documentID :String,
			attachmentID :String, authorization :String? = nil) -> Error? {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// QueuehttpEndpointRequestForRemoveDocumentAttachment
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentAttachmentRemove(documentStorageID: documentStorageID,
							documentType: documentType, documentID: documentID, attachmentID: attachmentID,
							authorization: authorization))
					{ completionProc($0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexRegister(documentStorageID :String, name :String, documentType :String,
			relevantProperties :[String] = [], isUpToDate :Bool = false, keysSelector :String,
			keysSelectorInfo :[String : Any] = [:], authorization :String? = nil) -> Error? {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForIndexRegister(documentStorageID: documentStorageID,
							name: name, documentType: documentType, relevantProperties: relevantProperties,
							isUpToDate: isUpToDate, keysSelector: keysSelector, keysSelectorInfo: keysSelectorInfo,
							authorization: authorization))
					{ completionProc($0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentInfo(documentStorageID :String, name :String, keys :[String], authorization :String? = nil) ->
			(isUpToDate :Bool?, documentRevisionInfosMap :[String : MDSDocument.RevisionInfo]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Setup
			var	documentRevisionMap :[String : MDSDocument.RevisionInfo]?
			var	error :Error?

			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForIndexGetDocumentInfo(documentStorageID: documentStorageID,
							name: name, keys: keys, authorization: authorization),
					partialResultsProc: { documentRevisionMap = $0; error = $1 },
					completionProc: { completionProc(($0, documentRevisionMap, error)); _ = $1 })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocument(documentStorageID :String, name :String, keys :[String], authorization :String? = nil) ->
			(isUpToDate :Bool?, documentFullInfosMap :[String : MDSDocument.FullInfo]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Setup
			var	documentFullInfosMap :[String : MDSDocument.FullInfo]?
			var	error :Error?

			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForIndexGetDocument(documentStorageID: documentStorageID,
							name: name, keys: keys, authorization: authorization),
					partialResultsProc: { documentFullInfosMap = $0; error = $1 },
					completionProc: { completionProc(($0, documentFullInfosMap, error)); _ = $1 })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoGet(documentStorageID :String, keys :[String], authorization :String? = nil) ->
			(info :[String : String]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForInfoGet(documentStorageID: documentStorageID, keys: keys,
							authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoSet(documentStorageID :String, info :[String : String], authorization :String? = nil) -> Error? {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForInfoSet(documentStorageID: documentStorageID, info: info,
							authorization: authorization))
					{ completionProc($0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func internalSet(documentStorageID :String, info :[String : String], authorization :String? = nil) -> Error? {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForInternalSet(documentStorageID: documentStorageID, info: info,
							authorization: authorization))
					{ completionProc($0) }
		}
	}
}
