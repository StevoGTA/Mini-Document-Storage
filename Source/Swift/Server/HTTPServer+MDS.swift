//
//  HTTPServer+MDS.swift
//  Mini Document Storage
//
//  Created by Stevo on 9/6/22.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: Local data
			typealias AuthorizationValidationProc = (_ authorization :String) -> Bool
fileprivate	typealias DocumentStorageInfo =
					(documentStorage :MDSHTTPServicesHandler, authorizationValidationProc :AuthorizationValidationProc)
fileprivate	var	documentStorageInfosByDocumentStorageID = [String : DocumentStorageInfo]()

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSHTTPServices extension
extension MDSHTTPServices {

	// Class methods
	//------------------------------------------------------------------------------------------------------------------
	static func register(documentStorage :MDSHTTPServicesHandler, for documentStorageID :String = "default",
			isIncludedProcs :[(selector :String, isIncludedProc :MDSDocument.IsIncludedProc)] = [],
			keysProcs :[(selector :String, keysProc :MDSDocument.KeysProc)] = [],
			valueProcs :[(selector :String, valueProc :MDSDocument.ValueProc)] = [],
			authorizationValidationProc :@escaping AuthorizationValidationProc = { _ in true }) {
		// Store
		documentStorageInfosByDocumentStorageID[documentStorageID] = (documentStorage, authorizationValidationProc)

		// Register
		documentStorage.register(
				isIncludedProcs:
						[
							("documentPropertyIsValue()",
									{ [unowned documentStorage] documentType, document, info in
										// Setup
										guard let property = info["property"] as? String else { return false }
										guard let value = info["value"] as? String else { return false }
										guard let documentPropertyValue =
												documentStorage.documentStringValue(for: documentType,
														document: document, property: property) else { return false }

										return documentPropertyValue == value
									}),
							("documentPropertyIsOneOfValues()",
									{ [unowned documentStorage] documentType, document, info in
										// Setup
										guard let property = info["property"] as? String else { return false }
										guard let values = info["values"] as? [String] else { return false }
										guard let documentPropertyValue =
												documentStorage.documentStringValue(for: documentType,
														document: document, property: property) else { return false }

										return values.contains(documentPropertyValue)
									}),
						] +
						isIncludedProcs)
		documentStorage.register(
				keysProcs:
						[
							("keysForDocumentProperty()",
									{ [unowned documentStorage] documentType, document, info in
										// Setup
										guard let property = info["property"] as? String else { return [] }
										guard let documentPropertyValue =
												documentStorage.documentStringValue(for: documentType,
														document: document, property: property) else { return [] }

										return [documentPropertyValue]
									}),
						] +
						keysProcs)
		documentStorage.register(
				valueProcs:
						[
							("integerValueForProperty()",
									{ [unowned documentStorage] documentType, document, property in
										// Return integer value
										return documentStorage.documentIntegerValue(for: documentType,
												document: document, property: property) ?? 0
									}),
						] +
						valueProcs)
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - HTTPServer extension
extension HTTPServer {

	// MARK: Types

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func setupMDSEndpoints() {
		// Setup
		setupAssociationEndpoints()
		setupCacheEndpoints()
		setupCollectionEndpoints()
		setupDocumentsEndpoints()
		setupIndexEndpoints()
		setupInfoEndpoints()
		setupInternalEndpoints()
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func setupAssociationEndpoints() {
		// Association register
		var	associationRegisterEndpoint = MDSHTTPServices.associationRegisterEndpoint
		associationRegisterEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let name = info.name else {
				// name missing
				return (.badRequest, nil, .json(["error": "Missing name"]))
			}
			guard let fromDocumentType = info.fromDocumentType else {
				// fromDocumentType missing
				return (.badRequest, nil, .json(["error": "Missing fromDocumentType"]))
			}
			guard let toDocumentType = info.toDocumentType else {
				// toDocumentType missing
				return (.badRequest, nil, .json(["error": "Missing toDocumentType"]))
			}

			// Catch errors
			do {
				// Register association
				try documentStorage!.associationRegister(named: name, fromDocumentType: fromDocumentType,
						toDocumentType: toDocumentType)

				return (.ok, nil, nil)
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(associationRegisterEndpoint)

		// Association update
		var	associationUpdateEndpoint = MDSHTTPServices.associationUpdateEndpoint
		associationUpdateEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			// Compose updates
			var	updates = [MDSAssociation.Update]()
			for updateInfo in info.updateInfos {
				// Get update
				let	(update, error) = MDSHTTPServices.associationUpdateGetUpdate(for: updateInfo)

				// Check results
				if update != nil {
					// Success
					updates.append(update!)
				} else {
					// Error
					return (.badRequest, nil, .json(["error": "\(error!)"]))
				}
			}

			// Catch errors
			do {
				// Update association
				try documentStorage!.associationUpdate(for: info.name, updates: updates)

				return (.ok, nil, nil)
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(associationUpdateEndpoint)

		// Association get
		var	associationGetEndpoint = MDSHTTPServices.associationGetEndpoint
		associationGetEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			// Catch errors
			do {
				// Check requested flavor
				if let fromDocumentID = info.fromDocumentID {
					// From
					if info.fullInfo {
						// Return document full infos
						let	(totalCount, documentFullInfos) =
									try documentStorage!.associationGetDocumentFullInfos(name: info.name,
											from: fromDocumentID, startIndex: info.startIndex, count: info.count)

						return (.ok,
								[HTTPURLResponse.contentRangeHeader(for: "documents", start: Int64(info.startIndex),
										length: Int64(documentFullInfos.count), size: Int64(totalCount))],
								.json(documentFullInfos.map({ $0.httpServicesInfo })))
					} else {
						// Return document revision infos
						let	(totalCount, documentRevisionInfos) =
									try documentStorage!.associationGetDocumentRevisionInfos(name: info.name,
											from: fromDocumentID, startIndex: info.startIndex, count: info.count)

						return (.ok,
								[HTTPURLResponse.contentRangeHeader(for: "documents", start: Int64(info.startIndex),
										length: Int64(documentRevisionInfos.count), size: Int64(totalCount))],
								.json(documentRevisionInfos.map({ $0.httpServicesInfo })))
					}
				} else if let toDocumentID = info.toDocumentID {
					// To
					if info.fullInfo {
						// Return document full infos
						let	(totalCount, documentFullInfos) =
									try documentStorage!.associationGetDocumentFullInfos(name: info.name,
											to: toDocumentID, startIndex: info.startIndex, count: info.count)

						return (.ok,
								[HTTPURLResponse.contentRangeHeader(for: "documents", start: Int64(info.startIndex),
												length: Int64(documentFullInfos.count), size: Int64(totalCount))],
										.json(documentFullInfos.map({ $0.httpServicesInfo })))
					} else {
						// Return document revision infos
						let	(totalCount, documentRevisionInfos) =
									try documentStorage!.associationGetDocumentRevisionInfos(name: info.name,
											to: toDocumentID, startIndex: info.startIndex, count: info.count)

						return (.ok,
								[HTTPURLResponse.contentRangeHeader(for: "documents", start: Int64(info.startIndex),
												length: Int64(documentRevisionInfos.count), size: Int64(totalCount))],
										.json(documentRevisionInfos.map({ $0.httpServicesInfo })))
					}
				} else {
					// Some part of all the associations
					var	associationItems = try documentStorage!.associationGet(for: info.name)
					let	totalCount = associationItems.count
					associationItems =
							(info.count != nil) ?
									Array(associationItems[info.startIndex...(info.startIndex + info.count!)]) :
									Array(associationItems[info.startIndex...])

					return (.ok,
							[HTTPURLResponse.contentRangeHeader(for: "documents", start: Int64(info.startIndex),
											length: Int64(associationItems.count), size: Int64(totalCount))],
									.json(associationItems.map({ $0.httpServicesInfo })))
				}
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(associationGetEndpoint)

		// Association get values
		var	associationGetValuesEndpoint = MDSHTTPServices.associationGetValuesEndpoint
		associationGetValuesEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let fromDocumentIDs = info.fromDocumentIDs else {
				// fromDocumentIDs missing
				return (.badRequest, nil, .json(["error": "Missing fromDocumentIDs"]))
			}
			guard !fromDocumentIDs.isEmpty else {
				// fromDocumentID missing
				return (.badRequest, nil, .json(["error": "Missing fromDocumentID"]))
			}
			guard let cacheName = info.cacheName else {
				// documentType missing
				return (.badRequest, nil, .json(["error": "Missing cacheName"]))
			}
			guard let action = info.action else {
				// action missing
				return (.badRequest, nil, .json(["error": "Invalid action"]))
			}
			guard let cachedValueNames = info.cachedValueNames else {
				// cachedValueName missing
				return (.badRequest, nil, .json(["error": "Missing cachedValueNames"]))
			}
			guard !cachedValueNames.isEmpty else {
				// cachedValueName missing
				return (.badRequest, nil, .json(["error": "Missing cachedValueName"]))
			}

			// Catch errors
			do {
				// Check action
				switch action {
					case .sum:
						// Sum
						let	results :[String : Int64] =
								try documentStorage!.associationGetIntegerValues(for: info.name, action: action,
										fromDocumentIDs: fromDocumentIDs, cacheName: cacheName,
										cachedValueNames: cachedValueNames)

						return (.ok, nil, .json(results))
				}
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(associationGetValuesEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupCacheEndpoints() {
		// Cache register
		var	cacheRegisterEndpoint = MDSHTTPServices.cacheRegisterEndpoint
		cacheRegisterEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let name = info.name else {
				// name missing
				return (.badRequest, nil, .json(["error": "Missing name"]))
			}
			guard let documentType = info.documentType else {
				// documentType missing
				return (.badRequest, nil, .json(["error": "Missing documentType"]))
			}
			guard let relevantProperties = info.relevantProperties else {
				// relevantProperties missing
				return (.badRequest, nil, .json(["error": "Missing relevantProperties"]))
			}
			guard let valueInfoInfos = info.valueInfos else {
				// valueInfoInfos empty
				return (.badRequest, nil, .json(["error": "Missing valueInfos"]))
			}
			guard !valueInfoInfos.isEmpty else {
				// valueInfoInfos empty
				return (.badRequest, nil, .json(["error": "Missing valueInfos"]))
			}

			// Compose valueInfos
			var	valueInfos = [(name :String, valueType :MDSValueType, selector :String, proc :MDSDocument.ValueProc)]()
			for valueInfoInfo in valueInfoInfos {
				// Get update
				let	(valueInfo, error) = MDSHTTPServices.cacheRegisterGetValueInfo(for: valueInfoInfo)

				// Check results
				if valueInfo != nil {
					// Success
					switch valueInfo!.valueType {
						case .integer:
							// Integer
							guard valueInfo!.selector == "integerValueForProperty()" else
									{ return (.badRequest, nil,
											.json(["error": "Invalid value selector: \(valueInfo!.selector)"])) }

							// Append info
							valueInfos.append(
									(valueInfo!.name, valueInfo!.valueType, valueInfo!.selector,
											{ documentStorage!.documentIntegerValue(for: documentType, document: $1,
													property: $2) ?? 0 }))
					}
				} else {
					// Error
					return (.badRequest, nil, .json(["error": "\(error!)"]))
				}
			}

			// Catch errors
			do {
				// Register cache
				try documentStorage!.cacheRegister(name: name, documentType: documentType,
						relevantProperties: relevantProperties, valueInfos: valueInfos)

				return (.ok, nil, nil)
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(cacheRegisterEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupCollectionEndpoints() {
		// Collection Register
		var	collectionRegisterEndpoint = MDSHTTPServices.collectionRegisterEndpoint
		collectionRegisterEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let name = info.name else {
				// name missing
				return (.badRequest, nil, .json(["error": "Missing name"]))
			}
			guard let documentType = info.documentType else {
				// documentType missing
				return (.badRequest, nil, .json(["error": "Missing documentType"]))
			}
			guard let relevantProperties = info.relevantProperties else {
				// relevantProperties missing
				return (.badRequest, nil, .json(["error": "Missing relevantProperties"]))
			}
			guard let isIncludedSelector = info.isIncludedSelector else {
				// isIncludedSelector missing
				return (.badRequest, nil, .json(["error": "Missing isIncludedSelector"]))
			}
			guard let isIncludedSelectorInfo = info.isIncludedSelectorInfo else {
				// isIncludedSelectorInfo missing
				return (.badRequest, nil, .json(["error": "Missing isIncludedSelectorInfo"]))
			}
			guard let isIncludedProc = documentStorage!.documentIsIncludedProc(for: isIncludedSelector) else {
				// isIncludedSelector not found
				return (.badRequest, nil, .json(["error": "Invalid isIncludedSelector"]))
			}

			// Catch errors
			do {
				// Register collection
				try documentStorage!.collectionRegister(name: name, documentType: documentType,
						relevantProperties: relevantProperties, isUpToDate: info.isUpToDate,
						isIncludedInfo: isIncludedSelectorInfo, isIncludedSelector: isIncludedSelector,
						isIncludedProc: isIncludedProc)

				return (.ok, nil, nil)
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(collectionRegisterEndpoint)

		// Collect Get Document Count
		var	collectionGetDocumentCountEndpoint = MDSHTTPServices.collectionGetDocumentCountEndpoint
		collectionGetDocumentCountEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			// Catch errors
			do {
				// Query count
				let	count = try documentStorage!.collectionGetDocumentCount(for: info.name)

				return (.ok,
						[HTTPURLResponse.contentRangeHeader(for: "items", start: 0, length: Int64(count),
								size: Int64(count))],
						nil)
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(collectionGetDocumentCountEndpoint)

		// Collection Get Document Info
		var	collectionGetDocumentInfoEndpoint = MDSHTTPServices.collectionGetDocumentInfoEndpoint
		collectionGetDocumentInfoEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard info.startIndex >= 0 else {
				// Invalid startIndex
				return (.badRequest, nil, .json(["error": "Invalid startIndex: \(info.startIndex)"]))
			}

			guard (info.count == nil) || (info.count! > 0) else {
				// Invalid count
				return (.badRequest, nil, .json(["error": "Invalid count: \(info.count!)"]))
			}

			// Catch errors
			do {
				// Query count
				let	count = try documentStorage!.collectionGetDocumentCount(for: info.name)

				// Check return info type
				if info.fullInfo {
					// Return document full infos
					let	infos =
								try documentStorage!.collectionGetDocumentFullInfos(name: info.name,
												startIndex: info.startIndex, count: info.count)
										.map({ $0.httpServicesInfo })

					return (.ok,
							[HTTPURLResponse.contentRangeHeader(for: "documents", start: Int64(info.startIndex),
									length: Int64(infos.count), size: Int64(count))],
							.json(infos))
				} else {
					// Return document revision infos
					let	infos =
								try documentStorage!.collectionGetDocumentRevisionInfos(name: info.name,
												startIndex: info.startIndex, count: info.count)
										.map({ $0.httpServicesInfo })

					return (.ok,
							[HTTPURLResponse.contentRangeHeader(for: "documents", start: Int64(info.startIndex),
									length: Int64(infos.count), size: Int64(count))],
							.json(infos))
				}
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(collectionGetDocumentInfoEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupDocumentsEndpoints() {
		// Document Create
		var	documentCreateEndpoint = MDSHTTPServices.documentCreateEndpoint
		documentCreateEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard !info.documentCreateInfos.isEmpty else {
				// Missing info(s)
				return (.badRequest, nil, .json(["error": "Missing info(s)"]))
			}

			// Create documents
			let	infos =
						try! documentStorage!.documentCreate(documentType: info.documentType,
										documentCreateInfos: info.documentCreateInfos)
								.map({ $0.httpServicesInfo })

			return (.ok, nil, .json(infos))
		}
		register(documentCreateEndpoint)

		// Document Get Count
		var	documentGetCountEndpoint = MDSHTTPServices.documentGetCountEndpoint
		documentGetCountEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			// Catch errors
			do {
				// Query count
				let	count = try documentStorage!.documentGetCount(for: info.documentType)

				return (.ok,
						[HTTPURLResponse.contentRangeHeader(for: "items", start: 0, length: Int64(count),
								size: Int64(count))],
						nil)
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(documentGetCountEndpoint)

		// Document Get
		var	documentGetEndpoint = MDSHTTPServices.documentGetEndpoint
		documentGetEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			// Catch errors
			do {
				// Query count
				let	count = try documentStorage!.documentGetCount(for: info.documentType)

				// Check requested flavor
				if let documentIDs = info.documentIDs {
					// Check fullInfo
					if info.fullInfo {
						// Get full infos
						let	documentFullInfos =
									try documentStorage!.documentFullInfos(for: info.documentType,
											documentIDs: documentIDs)

						return (.ok, nil, .json(documentFullInfos.map({ $0.httpServicesInfo })))
					} else {
						// Get revision infos
						let	documentRevisionInfos =
									try documentStorage!.documentRevisionInfos(for: info.documentType,
											documentIDs: documentIDs)

						return (.ok, nil, .json(documentRevisionInfos.map({ $0.httpServicesInfo })))
					}
				} else if let revision = info.sinceRevision {
					// Validate info
					guard revision >= 0 else {
						// Invalid revision
						return (.badRequest, nil, .json(["error": "Invalid revision: \(revision)"]))
					}

					guard (info.count == nil) || (info.count! > 0) else {
						// Invalid count
						return (.badRequest, nil, .json(["error": "Invalid count: \(info.count!)"]))
					}

					// Check fullInfo
					if info.fullInfo {
						// Get full infos
						let	documentFullInfos =
									try documentStorage!.documentFullInfos(for: info.documentType,
											sinceRevision: revision, count: info.count)

						return (.ok,
								[HTTPURLResponse.contentRangeHeader(for: "documents", start: 0,
										length: Int64(documentFullInfos.count), size: Int64(count))],
								.json(documentFullInfos.map({ $0.httpServicesInfo })))
					} else {
						// Get revision infos
						let	documentRevisionInfos =
									try documentStorage!.documentRevisionInfos(for: info.documentType,
											sinceRevision: revision, count: info.count)

						return (.ok,
								[HTTPURLResponse.contentRangeHeader(for: "documents", start: 0,
										length: Int64(documentRevisionInfos.count), size: Int64(count))],
								.json(documentRevisionInfos.map({ $0.httpServicesInfo })))
					}
				} else {
					// Must specify one or the other
					return (.badRequest, nil, .json(["error": "Missing id(s)"]))
				}
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(documentGetEndpoint)

		// Document Update
		var	documentUpdateEndpoint = MDSHTTPServices.documentUpdateEndpoint
		documentUpdateEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			// Catch errors
			do {
				// Update documents
				let	infos =
							try documentStorage!.documentUpdate(for: info.documentType,
											documentUpdateInfos: info.documentUpdateInfos)
									.map({ $0.httpServicesInfo })

				return (.ok, nil, .json(infos))
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(documentUpdateEndpoint)

		// Document Attachment Add
		var	documentAttachmentAddEndpoint = MDSHTTPServices.documentAttachmentAddEndpoint
		documentAttachmentAddEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let infoInfo = info.info else {
				// Missing info
				return (.badRequest, nil, .json(["error": "Missing info"]))
			}
			guard let infoContent = info.content else {
				// Missing content
				return (.badRequest, nil, .json(["error": "Missing content"]))
			}

			// Catch errors
			do {
				// Add document attachment
				let	documentAttachmentInfo =
							try documentStorage!.documentAttachmentAdd(for: info.documentType,
									documentID: info.documentID, info: infoInfo, content: infoContent)

				return (.ok, nil, .json(documentAttachmentInfo.httpServicesInfo))
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(documentAttachmentAddEndpoint)

		// Document Attachment Get
		var	documentAttachmentGetEndpoint = MDSHTTPServices.documentAttachmentGetEndpoint
		documentAttachmentGetEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			// Catch errors
			do {
				// Get document attachment content
				let	content =
						try documentStorage!.documentAttachmentContent(for: info.documentType,
								documentID: info.documentID, attachmentID: info.attachmentID)

				return (.ok, nil, .data(content))
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(documentAttachmentGetEndpoint)

		// Document Attachment Update
		var	documentAttachmentUpdateEndpoint = MDSHTTPServices.documentAttachmentUpdateEndpoint
		documentAttachmentUpdateEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let infoInfo = info.info else {
				// Missing info
				return (.badRequest, nil, .json(["error": "Missing info"]))
			}
			guard let infoContent = info.content else {
				// Missing content
				return (.badRequest, nil, .json(["error": "Missing content"]))
			}

			// Catch errors
			do {
				// Update document attachment
				let	revision =
							try documentStorage!.documentAttachmentUpdate(for: info.documentType,
									documentID: info.documentID, attachmentID: info.attachmentID, updatedInfo: infoInfo,
									updatedContent: infoContent)

				return (.ok, nil, .json(["revision": revision]))
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(documentAttachmentUpdateEndpoint)

		// Document Attachment Remove
		var	documentAttachmentRemoveEndpoint = MDSHTTPServices.documentAttachmentRemoveEndpoint
		documentAttachmentRemoveEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			// Catch errors
			do {
				// Remove document attachment
				try documentStorage!.documentAttachmentRemove(for: info.documentType, documentID: info.documentID,
						attachmentID: info.attachmentID)

				return (.ok, nil, nil)
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(documentAttachmentRemoveEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupIndexEndpoints() {
		// Index Register
		var	indexRegisterEndpoint = MDSHTTPServices.indexRegisterEndpoint
		indexRegisterEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let name = info.name else {
				// name missing
				return (.badRequest, nil, .json(["error": "Missing name"]))
			}
			guard let documentType = info.documentType else {
				// documentType missing
				return (.badRequest, nil, .json(["error": "Missing documentType"]))
			}
			guard let relevantProperties = info.relevantProperties else {
				// relevantProperties missing
				return (.badRequest, nil, .json(["error": "Missing relevantProperties"]))
			}
			guard let keysSelector = info.keysSelector else {
				// keysSelector missing
				return (.badRequest, nil, .json(["error": "Missing keysSelector"]))
			}
			guard let keysSelectorInfo = info.keysSelectorInfo else {
				// keysSelectorInfo missing
				return (.badRequest, nil, .json(["error": "Missing keysSelectorInfo"]))
			}
			guard let keysProc = documentStorage!.documentKeysProc(for: keysSelector) else {
				// keysSelector not found
				return (.badRequest, nil, .json(["error": "Invalid keysSelector"]))
			}

			// Catch errors
			do {
				// Register index
				try documentStorage!.indexRegister(name: name, documentType: documentType,
						relevantProperties: relevantProperties, keysInfo: keysSelectorInfo, keysSelector: keysSelector,
						keysProc: keysProc)

				return (.ok, nil, nil)
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(indexRegisterEndpoint)

		// Index Get Document Info
		var	indexGetDocumentInfoEndpoint = MDSHTTPServices.indexGetDocumentInfoEndpoint
		indexGetDocumentInfoEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let keys = info.keys, !keys.isEmpty else {
				// keys missing
				return (.badRequest, nil, .json(["error": "Missing key(s)"]))
			}

			// Catch errors
			do {
				// Check return info type
				if info.fullInfo {
					// Return documents
					let	returnInfo =
								try documentStorage!.indexGetDocumentFullInfos(name: info.name, keys: keys)
										.mapValues({ $0.httpServicesInfo })

					return (.ok, nil, .json(returnInfo))
				} else {
					// Return document info
					let	returnInfo =
								try documentStorage!.indexGetDocumentRevisionInfos(name: info.name, keys: keys)
										.mapValues({ [$0.documentID: $0.revision] })

					return (.ok, nil, .json(returnInfo))
				}
			} catch {
				// Error
				return (.badRequest, nil, .json(["error": "\(error)"]))
			}
		}
		register(indexGetDocumentInfoEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupInfoEndpoints() {
		// Info Get
		var	infoGetEndpoint = MDSHTTPServices.infoGetEndpoint
		infoGetEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard let keys = info.keys, !keys.isEmpty else {
				// keys missing
				return (.badRequest, nil, .json(["error": "Missing key(s)"]))
			}

			return (.ok, nil, .json(try! documentStorage!.info(for: keys)))
		}
		register(infoGetEndpoint)

		// Info Set
		var	infoSetEndpoint = MDSHTTPServices.infoSetEndpoint
		infoSetEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard !info.info.isEmpty else {
				// info missing
				return (.badRequest, nil, .json(["error": "Missing info"]))
			}

			// Update
			try! documentStorage!.infoSet(info.info)

			return (.ok, nil, nil)
		}
		register(infoSetEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func setupInternalEndpoints() {
		// Internal Set
		var	internalSetEndpoint = MDSHTTPServices.internalSetEndpoint
		internalSetEndpoint.performProc = { info in
			// Validate info
			let	(documentStorage, performResult) =
						self.preflight(documentStorageID: info.documentStorageID, authorization: info.authorization)
			guard performResult == nil else { return performResult! }

			guard !info.info.isEmpty else {
				// info missing
				return (.badRequest, nil, .json(["error": "Missing info"]))
			}

			// Update
			try! documentStorage!.internalSet(info.info)

			return (.ok, nil, nil)
		}
		register(internalSetEndpoint)
	}

	//------------------------------------------------------------------------------------------------------------------
	private func preflight(documentStorageID :String, authorization :String?) ->
			(MDSHTTPServicesHandler?, HTTPEndpoint.PerformResult?) {
		// Setup
		guard let (documentStorage, authorizationValidationProc) =
				documentStorageInfosByDocumentStorageID[documentStorageID] else {
			// Document storage not found
			return (nil, (.badRequest, nil, .json(["error": "Invalid documentStorageID: \(documentStorageID)"])))
		}

		// Validate authorization
		if let authorization = authorization, !authorizationValidationProc(authorization) {
			// Not authorized
			return (nil, (.unauthorized, [], .json(["error": "not authorized"])))
		}

		return (documentStorage, nil)
	}
}
