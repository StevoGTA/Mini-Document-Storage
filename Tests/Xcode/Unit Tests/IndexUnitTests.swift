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
		let	documentStorageID = UUID().uuidString

		// Perform
		let	error =
					config.httpEndpointClient.indexRegister(documentStorageID: documentStorageID, name: "ABC",
							documentType: "ABC", keysSelector: "keysForDocumentProperty()")

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

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
										"relevantProperties": [String](),
										"isUpToDate": 1,
										"keysSelector": "ABC",
										"keysSelectorInfo": [String:Any](),
									  ] as [String : Any])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
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
										"relevantProperties": [String](),
										"isUpToDate": 1,
										"keysSelector": "ABC",
										"keysSelectorInfo": [String:Any](),
									  ] as [String : Any])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
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
										"keysSelectorInfo": [String:Any](),
									  ] as [String : Any])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
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
										"relevantProperties": [String](),
										"isUpToDate": 1,
										"keysSelectorInfo": [String:Any](),
									  ] as [String : Any])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
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
										"relevantProperties": [String](),
										"isUpToDate": 1,
										"keysSelector": "keysForDocumentProperty()",
									  ] as [String : Any])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
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
	func testGetStatusInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(isUpToDate, error) =
					config.httpEndpointClient.indexGetStatus(documentStorageID: UUID().uuidString, name: "ABC")

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

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
	func testGetStatusUnknownName() throws {
		// Setup
		let	config = Config.current
		let	name = UUID().uuidString

		// Perform
		let	(isUpToDate, error) =
					config.httpEndpointClient.indexGetStatus(documentStorageID: config.documentStorageID, name: name)

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.failed(let status):
					// Expected error
					XCTAssertEqual(status, HTTPEndpointStatus.notFound, "did not receive expected error")

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
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.indexGetDocumentInfos(documentStorageID: documentStorageID, name: "ABC",
							keys: ["ABC"])

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

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
				case MDSError.notFound(let message):
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
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.indexGetDocuments(documentStorageID: documentStorageID, name: "ABC",
							keys: ["ABC"])

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

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
				case MDSError.notFound(let message):
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
