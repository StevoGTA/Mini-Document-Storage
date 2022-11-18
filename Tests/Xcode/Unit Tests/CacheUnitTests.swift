//
//  CacheUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 5/10/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: CacheUnitTests
class CacheUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testRegisterInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error =
					config.httpEndpointClient.cacheRegister(documentStorageID: "ABC", name: "ABC",
							documentType: Child.documentType, valueInfos: [("ABC", .integer, "ABC")])

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
		let	config = Config.shared

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"documentType": config.documentType,
										"relevantProperties": [],
										"valueInfos":
												[
													"name": "ABC",
													"valueType": "integer",
													"selector": "ABC",
												],
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
		let	config = Config.shared

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"relevantProperties": [],
										"valueInfos":
												[
													"name": "ABC",
													"valueType": "integer",
													"selector": "ABC",
												],
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
		let	config = Config.shared
		let	documentType = UUID().uuidString

		// Perform
		let	error =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID, name: "ABC",
							documentType: documentType, valueInfos: [("ABC", .integer, "ABC")])

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
		let	config = Config.shared

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.documentType,
										"valueInfos":
												[
													"name": "ABC",
													"valueType": "integer",
													"selector": "ABC",
												],
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
	func testRegisterMissingValueInfos() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.documentType,
										"relevantProperties": [],
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
					XCTAssertEqual(message, "Missing valueInfos", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterInvalidValueInfos() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.documentType,
										"relevantProperties": [],
										"valueInfos":
												[
													"name": "ABC",
													"valueType": "ABC",
													"selector": "ABC",
												],
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
					XCTAssertEqual(message, "Missing valueInfos", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegister() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID, name: "ABC",
							documentType: Child.documentType, valueInfos: [("ABC", .integer, "ABC")])

		// Evaluate results
		XCTAssertNil(error, "received error")
	}
}
