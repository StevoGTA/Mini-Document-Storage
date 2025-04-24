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

	// MARK: Instance methods for core HTTPEndpointRequests
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
	func queue(_ headWithCountHTTPEndpointRequest :MDSHTTPServices.MDSHeadWithCountHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionWithCountProc
					:@escaping MDSHTTPServices.MDSHeadWithCountHTTPEndpointRequest.CompletionWithCountProc) {
		// Setup
		headWithCountHTTPEndpointRequest.completionWithCountProc = completionWithCountProc

		// Queue
		queue(headWithCountHTTPEndpointRequest, identifier: identifier, priority: priority)
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
	func queue<T>(_ jsonHTTPEndpointRequest :MDSHTTPServices.MDSJSONHTTPEndpointRequest<T>, identifier :String = "",
			priority :Priority = .normal,
			completionProc :@escaping MDSHTTPServices.MDSJSONHTTPEndpointRequest<T>.SingleResponseCompletionProc) {
		// Setup
		jsonHTTPEndpointRequest.completionProc = completionProc

		// Queue
		queue(jsonHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue<T>(_ jsonHTTPEndpointRequest :MDSHTTPServices.MDSJSONHTTPEndpointRequest<T>, identifier :String = "",
			priority :Priority = .normal,
			partialResultsProc :@escaping MDSHTTPServices.MDSJSONHTTPEndpointRequest<T>.MultiResponsePartialResultsProc,
			completionProc :@escaping MDSHTTPServices.MDSJSONHTTPEndpointRequest<T>.MultiResponseCompletionProc) {
		// Setup
		jsonHTTPEndpointRequest.multiResponsePartialResultsProc = partialResultsProc
		jsonHTTPEndpointRequest.multiResponseCompletionProc = completionProc

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

	// MARK: Instance methods for specialized HTTPEndpointRequests
	//------------------------------------------------------------------------------------------------------------------
	func queue(_ associationGetHTTPEndpointRequest :MDSHTTPServices.AssociationGetHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ info :(associationItems :[MDSAssociation.Item], isComplete :Bool)?,
							_ error :Error?) -> Void) {
		// Setup
		associationGetHTTPEndpointRequest.completionWithCountProc = { info, error in
			// Handle results
			if info != nil {
				// Success
				let	associations = info!.info.compactMap({ MDSAssociation.Item(httpServicesInfo: $0) })

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
	func queue(_ documentRevisionInfosHTTPEndpointRequest :MDSHTTPServices.DocumentRevisionInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ isUpToDate :Bool?,
							_ info: (documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?,
							_ error :Error?) -> Void) {
		// Setup
		documentRevisionInfosHTTPEndpointRequest.completionWithUpToDateAndCountProc = { isUpToDate, info, error in
			// Handle results
			if info != nil {
				// Success
				DispatchQueue.global().async() {
					// Convert
					let	documentRevisionInfos =
								info!.info.compactMap({ MDSDocument.RevisionInfo(httpServicesInfo: $0) })

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
		queue(documentRevisionInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ documentRevisionInfosHTTPEndpointRequest :MDSHTTPServices.DocumentRevisionInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ info: (documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?,
							_ error :Error?) -> Void) {
		// Setup
		documentRevisionInfosHTTPEndpointRequest.completionWithCountProc = { info, error in
			// Handle results
			if let (infos, isComplete) = info {
				// Success
				DispatchQueue.global().async() {
					// Convert
					let	documentRevisionInfos =
								autoreleasepool()
										{ infos.compactMap({ MDSDocument.RevisionInfo(httpServicesInfo: $0) }) }

					// Call completion proc
					completionProc((documentRevisionInfos, isComplete), nil)
				}
			} else {
				// Error
				completionProc(nil, error)
			}
		}

		// Queue
		queue(documentRevisionInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ documentRevisionInfosHTTPEndpointRequest :MDSHTTPServices.DocumentRevisionInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ documentRevisionInfos :[MDSDocument.RevisionInfo]?, _ errors :[Error]) -> Void) {
		// Setup
		var	documentRevisionInfos = [MDSDocument.RevisionInfo]()
		documentRevisionInfosHTTPEndpointRequest.multiResponsePartialResultsProc = {
			// Process results
			documentRevisionInfos += $0?.compactMap({ MDSDocument.RevisionInfo(httpServicesInfo: $0) }) ?? []

			_ = $1
		}
		documentRevisionInfosHTTPEndpointRequest.multiResponseCompletionProc =
			{ completionProc($0.isEmpty ? documentRevisionInfos : nil, $0) }

		// Queue
		queue(documentRevisionInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ documentFullInfosHTTPEndpointRequest :MDSHTTPServices.DocumentFullInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			partialResultsProc :@escaping (_ documentFullInfos :[MDSDocument.FullInfo]) -> Void,
			completionProc
					:@escaping (_ info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, _ error :Error?)
							-> Void) {
		// Setup
		documentFullInfosHTTPEndpointRequest.completionWithCountProc = { info, error in
			// Handle results
			if let (infos, isComplete) = info {
				// Success
				DispatchQueue.global().async() {
					// Process in chunks to control memory usage
					var	documentFullInfos = [MDSDocument.FullInfo]()
					infos.chunked(by: 1000).forEach() { infos in
						// Run lean
						autoreleasepool() {
							// Call partial results proc
							documentFullInfos += infos.compactMap({ MDSDocument.FullInfo(httpServicesInfo: $0) })
						}
					}

					// Call completion proc
					completionProc((documentFullInfos, isComplete), nil)
				}
			} else {
				// Error
				completionProc(nil, error)
			}
		}

		// Queue
		queue(documentFullInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ documentFullInfosHTTPEndpointRequest :MDSHTTPServices.DocumentFullInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			documentFullInfosProc :@escaping (_ documentFullInfos :[MDSDocument.FullInfo]) -> Void,
			completionProc :@escaping (_ errors :[Error]) -> Void) {
		// Setup
		documentFullInfosHTTPEndpointRequest.multiResponsePartialResultsProc = {
			// Process results
			let	documentFullInfos = $0?.compactMap({ MDSDocument.FullInfo(httpServicesInfo: $0) }) ?? []
			if !documentFullInfos.isEmpty {
				// Call proc
				documentFullInfosProc(documentFullInfos)
			}

			_ = $1
		}
		documentFullInfosHTTPEndpointRequest.multiResponseCompletionProc = completionProc

		// Queue
		queue(documentFullInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ documentFullInfosHTTPEndpointRequest :MDSHTTPServices.DocumentFullInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ isUpToDate :Bool?,
							_ info: (documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, _ error :Error?) ->
							Void) {
		// Setup
		documentFullInfosHTTPEndpointRequest.completionWithUpToDateAndCountProc = { isUpToDate, info, error in
			// Handle results
			if info != nil {
				// Success
				DispatchQueue.global().async() {
					// Convert
					let	documentFullInfos = info!.info.compactMap({ MDSDocument.FullInfo(httpServicesInfo: $0) })

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
		queue(documentFullInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(_ documentFullInfosHTTPEndpointRequest :MDSHTTPServices.DocumentFullInfosHTTPEndpointRequest,
			identifier :String = "", priority :Priority = .normal,
			completionProc
					:@escaping (_ info: (documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, _ error :Error?)
							-> Void) {
		// Setup
		documentFullInfosHTTPEndpointRequest.completionWithCountProc = { info, error in
			// Handle results
			if info != nil {
				// Success - perform conversion in background
				DispatchQueue.global().async() {
					// Convert
					let	documentFullInfos = info!.info.compactMap({ MDSDocument.FullInfo(httpServicesInfo: $0) })

					// Switch queue for completion proc
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
		queue(documentFullInfosHTTPEndpointRequest, identifier: identifier, priority: priority)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queue(documentStorageID :String, name :String, updates :[MDSAssociation.Update], authorization :String? = nil,
			completionProc :@escaping(_ errors :[Error]) -> Void) {
		// Setup
		guard !updates.isEmpty else {
			// No updates
			completionProc([])

			return
		}

		let	updatesChunks = updates.chunked(by: 100)
		let	pendingCount = LockingNumeric<Int>(updatesChunks.count)
		let	errors = LockingArray<Error>()

		// Iterate and queue
		updatesChunks.forEach() {
			// Queue this chunk
			queue(
					MDSHTTPServices.httpEndpointRequestForAssociationUpdate(documentStorageID: documentStorageID,
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
		let	documentCreateInfosChunks = documentCreateInfos.chunked(by: 100)
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
	func queue(documentStorageID :String, type :String, documentUpdateInfos :[MDSDocument.UpdateInfo],
			authorization :String? = nil,
			partialResultsProc :@escaping (_ documentUpdateReturnInfo :[MDSDocument.UpdateReturnInfo]) -> Void,
			completionProc :@escaping(_ errors :[Error]) -> Void) {
		// Setup
		let	documentUpdateInfosChunks = documentUpdateInfos.chunked(by: 10)
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
				let	documentRevisionInfoMap = info!.compactMapValues({ MDSDocument.FullInfo(httpServicesInfo: $0) })

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
	func associationUpdate(documentStorageID :String, name :String, updates :[MDSAssociation.Update],
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
			(info :(associationItems :[MDSAssociation.Item], isComplete :Bool)?, error :Error?) {
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
	func associationGetDocumentRevisionInfos(documentStorageID :String, name :String, fromDocumentID :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			(info :(documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetDocumentRevisionInfos(
							documentStorageID: documentStorageID, name: name, fromDocumentID: fromDocumentID,
							startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(documentStorageID :String, name :String, fromDocumentID :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			(info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetDocumentFullInfos(
							documentStorageID: documentStorageID, name: name, fromDocumentID: fromDocumentID,
							startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(documentStorageID :String, name :String, toDocumentID :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			(info :(documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetDocumentRevisionInfos(
							documentStorageID: documentStorageID, name: name, toDocumentID: toDocumentID,
							startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(documentStorageID :String, name :String, toDocumentID :String,
			startIndex :Int = 0, count :Int? = nil, authorization :String? = nil) ->
			(info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetDocumentFullInfos(
							documentStorageID: documentStorageID, name: name, toDocumentID: toDocumentID,
							startIndex: startIndex, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetValues(documentStorageID :String, name :String, action :MDSAssociation.GetValueAction,
			fromDocumentIDs :[String], cacheName :String, cachedValueNames :[String], authorization :String? = nil) ->
			(info :(info :Any?, isUpToDate :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Setup
			var	info :Any
			switch action {
				case .detail:	info = LockingArray<[String : Any]>()
				case .sum:		info = LockingDictionary<String, Int64>()
			}

			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForAssociationGetValues(documentStorageID: documentStorageID,
							name: name, action: action, fromDocumentIDs: fromDocumentIDs, cacheName: cacheName,
							cachedValueNames: cachedValueNames, authorization: authorization),
					partialResultsProc: { partialResults, _ in
						// Check action
						switch action {
							case .detail:
								// Detail
								(info as! LockingArray<[String : Any]>).append(
										(partialResults as? [[String : Any]]) ?? [])

							case .sum:
								// Sum
								(partialResults as? [String : Int64])?.forEach() { cachedValueName, cachedValue in
									// Update return info
									(info as! LockingDictionary<String, Int64>)
											.update(for: cachedValueName, with: { ($0 ?? 0) + cachedValue })
								}
						}
					}, completionProc: {
						// Handle results
						if $0.isEmpty {
							// All good
							switch action {
								case .detail:
									// Detail
									completionProc((((info as! LockingArray<[String : Any]>).values, true), nil))

								case .sum:
									// Sum
									completionProc((((info as! LockingDictionary<String, Int64>).dictionary, true),
											nil))
							}
						} else {
							// Error
							let	error = $0.first!
							if (error as? HTTPEndpointStatusError)?.status == HTTPEndpointStatus.conflict {
								// Not up to date
								completionProc(((nil, false), nil))
							} else {
								// Other error
								completionProc((nil, error))
							}
						}
					})
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
	func cacheGetStatus(documentStorageID :String, name :String, authorization :String? = nil) ->
			(isUpToDate :Bool?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCacheGetStatus(documentStorageID: documentStorageID,
							name: name, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func cacheGetValues(documentStorageID :String, name :String, valueNames :[String], documentIDs :[String]? = nil,
			authorization :String? = nil) -> (info :(info :[[String : Any]]?, isUpToDate :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			let	infos = LockingArray<[String : Any]>()
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCacheGetValues(documentStorageID: documentStorageID,
							name: name, valueNames: valueNames, documentIDs: documentIDs, authorization: authorization),
					partialResultsProc: { partialResults, _ in
						// Check action
						infos.append(partialResults ?? [])
					}, completionProc: {
						// Handle results
						if $0.isEmpty {
							// All good
							completionProc(((infos.values, true), nil))
						} else {
							// Error
							let	error = $0.first!
							if (error as? HTTPEndpointStatusError)?.status == HTTPEndpointStatus.conflict {
								// Not up to date
								completionProc(((nil, false), nil))
							} else {
								// Other error
								completionProc((nil, error))
							}
						}
					})
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
	func collectionGetDocumentRevisionInfos(documentStorageID :String, name :String, startIndex :Int = 0,
			count :Int? = nil, authorization :String? = nil) ->
			(isUpToDate :Bool?, info :(documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?,
					error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCollectionGetDocumentRevisionInfos(
							documentStorageID: documentStorageID, name: name, startIndex: startIndex, count: count,
							authorization: authorization))
					{ completionProc(($0, $1, $2)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentFullInfos(documentStorageID :String, name :String, startIndex :Int = 0, count :Int? = nil,
			authorization :String? = nil) ->
			(isUpToDate :Bool?, info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForCollectionGetDocumentFullInfos(
							documentStorageID: documentStorageID, name: name, startIndex: startIndex, count: count,
							authorization: authorization))
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
	func documentGetDocumentRevisionInfos(documentStorageID :String, documentType :String, sinceRevision :Int,
			count :Int? = nil, authorization :String? = nil) ->
			(info :(documentRevisionInfos :[MDSDocument.RevisionInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentGetDocumentRevisionInfos(
							documentStorageID: documentStorageID, documentType: documentType,
							sinceRevision: sinceRevision, count: count, authorization: authorization))
							{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGetDocumentRevisionInfos(documentStorageID :String, documentType :String, documentIDs :[String],
			authorization :String? = nil) -> (documentRevisionInfos :[MDSDocument.RevisionInfo]?, errors :[Error]) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentGetDocumentRevisionInfos(
							documentStorageID: documentStorageID, documentType: documentType, documentIDs: documentIDs,
							authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGetDocumentFullInfos(documentStorageID :String, documentType :String, sinceRevision :Int,
			count :Int? = nil, authorization :String? = nil) ->
			(info :(documentFullInfos :[MDSDocument.FullInfo], isComplete :Bool)?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentGetDocumentFullInfos(
							documentStorageID: documentStorageID, documentType: documentType,
							sinceRevision: sinceRevision, count: count, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGetDocumentFullInfos(documentStorageID :String, documentType :String, documentIDs :[String],
			authorization :String? = nil) -> (documentFullInfos :[MDSDocument.FullInfo]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForDocumentGetDocumentFullInfos(
							documentStorageID: documentStorageID, documentType: documentType, documentIDs: documentIDs,
							authorization: authorization))
					{ completionProc(($0?.documentFullInfos, $1)) }
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
	func documentAttachmentAdd(documentStorageID :String, documentType :String, documentID :String,
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
	func documentAttachmentGet(documentStorageID :String, documentType :String, documentID :String,
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
	func documentAttachmentUpdate(documentStorageID :String, documentType :String, documentID :String,
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
	func documentAttachmentRemove(documentStorageID :String, documentType :String, documentID :String,
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
			relevantProperties :[String] = [], keysSelector :String, keysSelectorInfo :[String : Any] = [:],
			authorization :String? = nil) -> Error? {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForIndexRegister(documentStorageID: documentStorageID,
							name: name, documentType: documentType, relevantProperties: relevantProperties,
							keysSelector: keysSelector, keysSelectorInfo: keysSelectorInfo,
							authorization: authorization))
					{ completionProc($0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetStatus(documentStorageID :String, name :String, authorization :String? = nil) ->
			(isUpToDate :Bool?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForIndexGetStatus(documentStorageID: documentStorageID,
							name: name, authorization: authorization))
					{ completionProc(($0, $1)) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentInfos(documentStorageID :String, name :String, keys :[String], authorization :String? = nil) ->
			(isUpToDate :Bool?, documentRevisionInfosMap :[String : MDSDocument.RevisionInfo]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Setup
			var	documentRevisionMap :[String : MDSDocument.RevisionInfo]?
			var	error :Error?

			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForIndexGetDocumentInfos(documentStorageID: documentStorageID,
							name: name, keys: keys, authorization: authorization),
					partialResultsProc: { documentRevisionMap = $0; error = $1 },
					completionProc: { completionProc(($0, documentRevisionMap, error)); _ = $1 })
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocuments(documentStorageID :String, name :String, keys :[String], authorization :String? = nil) ->
			(isUpToDate :Bool?, documentFullInfosMap :[String : MDSDocument.FullInfo]?, error :Error?) {
		// Perform
		return DispatchQueue.performBlocking() { completionProc in
			// Setup
			var	documentFullInfosMap :[String : MDSDocument.FullInfo]?
			var	error :Error?

			// Queue
			self.queue(
					MDSHTTPServices.httpEndpointRequestForIndexGetDocuments(documentStorageID: documentStorageID,
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
