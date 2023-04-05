//
//  IndexUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 4/22/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: IndexUnitTests
class IndexUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testRegisterInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	error =
					config.httpEndpointClient.indexRegister(documentStorageID: "ABC", name: "ABC", documentType: "ABC",
							keysSelector: "keysForDocumentProperty()")

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
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/index/\(config.documentStorageID)",
							jsonBody: [
										"documentType": config.defaultDocumentType,
										"relevantProperties": [],
										"isUpToDate": 1,
										"keysSelector": "ABC",
										"keysSelectorInfo": [:],
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
							path: "/v1/index/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"relevantProperties": [],
										"isUpToDate": 1,
										"keysSelector": "ABC",
										"keysSelectorInfo": [:],
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

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterUnknownDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	error =
					config.httpEndpointClient.indexRegister(documentStorageID: config.documentStorageID, name: "ABC",
							documentType: documentType, keysSelector: "keysForDocumentProperty()")

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
							path: "/v1/index/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"isUpToDate": 1,
										"keysSelector": "ABC",
										"keysSelectorInfo": [:],
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
	func testRegisterMissingKeysSelector() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/index/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [],
										"isUpToDate": 1,
										"keysSelectorInfo": [:],
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
					XCTAssertEqual(message, "Missing keysSelector",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingKeysSelectorInfo() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/index/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [],
										"isUpToDate": 1,
										"keysSelector": "keysForDocumentProperty()",
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
					XCTAssertEqual(message, "Missing keysSelectorInfo",
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
					config.httpEndpointClient.indexRegister(documentStorageID: config.documentStorageID,
							name: UUID().uuidString, documentType: config.defaultDocumentType,
							keysSelector: "keysForDocumentProperty()")

		// Evaluate results
		XCTAssertNil(error, "received unexpected error: \(error!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.indexGetDocumentInfos(documentStorageID: "ABC", name: "ABC", keys: ["ABC"])

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
					config.httpEndpointClient.indexGetDocumentInfos(documentStorageID: config.documentStorageID,
							name: name, keys: ["ABC"])

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown index: \(name)",
							"did not receive expected error message: \(message)")

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
					config.httpEndpointClient.indexGetDocuments(documentStorageID: "ABC", name: "ABC", keys: ["ABC"])

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
					config.httpEndpointClient.indexGetDocuments(documentStorageID: config.documentStorageID, name: name,
							keys: ["ABC"])

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown index: \(name)",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}
}
