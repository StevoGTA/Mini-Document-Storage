//
//  CollectionUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 4/23/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: CollectionUnitTests
class CollectionUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testRegisterInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	error =
					config.httpEndpointClient.collectionRegister(documentStorageID: "ABC", name: "ABC",
							documentType: "ABC", isIncludedSelector: "documentPropertyIsValue()")

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingName() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put, path: "/v1/collection/\(config.documentStorageID)",
							jsonBody: [
										"documentType": config.defaultDocumentType,
										"relevantProperties": [],
										"isUpToDate": 1,
										"isIncludedSelector": "ABC",
										"isIncludedSelectorInfo": [:],
								  ])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing name", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingDocumentType() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/collection/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"relevantProperties": [],
										"isUpToDate": 1,
										"isIncludedSelector": "ABC",
										"isIncludedSelectorInfo": [:],
								  ])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing documentType",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------	//------------------------------------------------------------------------------------------------------------------
	func testRegisterUnknownDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	error =
					config.httpEndpointClient.collectionRegister(documentStorageID: config.documentStorageID,
							name: "ABC", documentType: documentType, isIncludedSelector: "documentPropertyIsValue()")

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentType: \(documentType)",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingRelevantProperties() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/collection/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"isUpToDate": 1,
										"isIncludedSelector": "ABC",
										"isIncludedSelectorInfo": [:],
								  ])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing relevantProperties",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingIsIncludedSelector() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/collection/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [],
										"isUpToDate": 1,
										"isIncludedSelectorInfo": [:],
								  ])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing isIncludedSelector",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingIsIncludedSelectorInfo() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/collection/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [],
										"isUpToDate": 1,
										"isIncludedSelector": "documentPropertyIsValue()",
								  ])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing isIncludedSelectorInfo",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegister() throws {
		// Setup
		let	config = Config.current

		// Create Test document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(createError, "create document received error: \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	error =
					config.httpEndpointClient.collectionRegister(documentStorageID: config.documentStorageID,
							name: "ABC", documentType: config.defaultDocumentType,
							isIncludedSelector: "documentPropertyIsValue()")

		// Evaluate results
		XCTAssertNil(error, "received unexpected error: \(error!)")
	}

	//------------------------------------------------------------------------------------------------------------------	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentCountInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(info, error) = config.httpEndpointClient.collectionGetDocumentCount(documentStorageID: "ABC", name: "ABC")

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.failed(let status):
					// Expected error
					XCTAssertEqual(status, HTTPEndpointStatus.badRequest, "did not receive expected error")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentCountInvalidName() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(info, error) =
					config.httpEndpointClient.collectionGetDocumentCount(documentStorageID: config.documentStorageID,
							name: UUID().uuidString)

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.failed(let status):
					// Expected error
					XCTAssertEqual(status, HTTPEndpointStatus.badRequest, "did not receive expected error")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.collectionGetDocumentRevisionInfos(documentStorageID: "ABC", name: "ABC")

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosUnknownName() throws {
		// Setup
		let	config = Config.current
		let	name = UUID().uuidString

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.collectionGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: name)

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown collection: \(name)",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosInvalidStartIndex() throws {
		// Setup
		let	collectionName = UUID().uuidString
		let	config = Config.current
		let	property1 = UUID().uuidString

		// Create Test document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(createError, "create document received error: \(createError!)")
		guard createError == nil else { return }

		// Register
		let	registerError1 =
					config.httpEndpointClient.collectionRegister(documentStorageID: config.documentStorageID,
							name: collectionName, documentType: config.defaultDocumentType,
							relevantProperties: [property1], isUpToDate: true,
							isIncludedSelector: "documentPropertyIsValue()",
							isIncludedSelectorInfo: ["property": property1, "value": "111"])
		XCTAssertNil(registerError1, "register (1) received error \(registerError1!)")
		guard registerError1 == nil else { return }

		// Get Document Info
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.collectionGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: collectionName, startIndex: -1)

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid startIndex: -1",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosInvalidCount() throws {
		// Setup
		let	collectionName = UUID().uuidString
		let	config = Config.current
		let	property1 = UUID().uuidString

		// Create Test document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(createError, "create document received error: \(createError!)")
		guard createError == nil else { return }

		// Register
		let	registerError1 =
					config.httpEndpointClient.collectionRegister(documentStorageID: config.documentStorageID,
							name: collectionName, documentType: config.defaultDocumentType,
							relevantProperties: [property1], isUpToDate: true,
							isIncludedSelector: "documentPropertyIsValue()",
							isIncludedSelectorInfo: ["property": property1, "value": "111"])
		XCTAssertNil(registerError1, "register (1) received error \(registerError1!)")
		guard registerError1 == nil else { return }

		// Get Document Info
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.collectionGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: collectionName, count: -1)

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid count: -1", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.collectionGetDocumentFullInfos(documentStorageID: "ABC", name: "ABC")

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsUnknownName() throws {
		// Setup
		let	config = Config.current
		let	name = UUID().uuidString

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.collectionGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: name)

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown collection: \(name)",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsInvalidStartIndex() throws {
		// Setup
		let	collectionName = UUID().uuidString
		let	config = Config.current
		let	property1 = UUID().uuidString

		// Create Test document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(createError, "create document received error: \(createError!)")
		guard createError == nil else { return }

		// Register
		let	registerError1 =
					config.httpEndpointClient.collectionRegister(documentStorageID: config.documentStorageID,
							name: collectionName, documentType: config.defaultDocumentType,
							relevantProperties: [property1], isUpToDate: true,
							isIncludedSelector: "documentPropertyIsValue()",
							isIncludedSelectorInfo: ["property": property1, "value": "111"])
		XCTAssertNil(registerError1, "register (1) received error \(registerError1!)")
		guard registerError1 == nil else { return }

		// Get Document Info
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.collectionGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: collectionName, startIndex: -1)

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid startIndex: -1",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsInvalidCount() throws {
		// Setup
		let	collectionName = UUID().uuidString
		let	config = Config.current
		let	property1 = UUID().uuidString

		// Create Test document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(createError, "create document received error: \(createError!)")
		guard createError == nil else { return }

		// Register
		let	registerError1 =
					config.httpEndpointClient.collectionRegister(documentStorageID: config.documentStorageID,
							name: collectionName, documentType: config.defaultDocumentType,
							relevantProperties: [property1], isUpToDate: true,
							isIncludedSelector: "documentPropertyIsValue()",
							isIncludedSelectorInfo: ["property": property1, "value": "111"])
		XCTAssertNil(registerError1, "register (1) received error \(registerError1!)")
		guard registerError1 == nil else { return }

		// Get Document Info
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.collectionGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: collectionName, count: -1)

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid count: -1", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}
}
