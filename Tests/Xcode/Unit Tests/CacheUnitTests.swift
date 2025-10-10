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
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	error =
					config.httpEndpointClient.cacheRegister(documentStorageID: documentStorageID, name: "ABC",
							documentType: Child.documentType,
							valueInfos: [(MDSValueInfo(name: "ABC", type: .integer), "integerValueForProperty()")])

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
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"documentType": config.defaultDocumentType,
										"relevantProperties": [String](),
										"valueInfos":
												[
													"name": "ABC",
													"valueType": "integer",
													"selector": "ABC",
												],
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
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"relevantProperties": [String](),
										"valueInfos":
												[
													"name": "ABC",
													"valueType": "integer",
													"selector": "ABC",
												],
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
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"valueInfos":
												[
													"name": "ABC",
													"valueType": "integer",
													"selector": "ABC",
												],
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
	func testRegisterMissingValueInfos() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [String](),
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
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [String](),
										"valueInfos": [String : Any](),
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
					XCTAssertEqual(message, "Missing valueInfos", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingValueInfoName() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [String](),
										"valueInfos": [["valueType": "ABC", "selector": "ABC"]],
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
					XCTAssertEqual(message, "Missing value name", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingValueInfoValueType() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [String](),
										"valueInfos": [["name": "ABC", "selector": "ABC"]],
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
					XCTAssertEqual(message, "Missing value valueType",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterInvalidValueInfoValueType() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [String](),
										"valueInfos": [["name": "ABC", "valueType": "ABC", "selector": "ABC"]],
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
					XCTAssertEqual(message, "Invalid value valueType: ABC",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterMissingValueInfoSelector() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [String](),
										"valueInfos": [["name": "ABC", "valueType": "integer"]],
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
					XCTAssertEqual(message, "Missing value selector",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterInvalidValueInfoSelector() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/cache/\(config.documentStorageID)",
							jsonBody: [
										"name": "ABC",
										"documentType": config.defaultDocumentType,
										"relevantProperties": [String](),
										"valueInfos": [["name": "ABC", "valueType": "integer", "selector": "ABC"]],
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
					XCTAssertEqual(message, "Invalid value selector: ABC",
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

		// Create document
		let	(_, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")

		// Perform
		let	registerError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID, name: "ABC",
							documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])

		// Evaluate results
		XCTAssertNil(registerError, "received error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetStatusInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(isUpToDate, error) =
					config.httpEndpointClient.cacheGetStatus(documentStorageID: UUID().uuidString, name: "ABC")

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

		// Register
		let	registerError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID,
							name: UUID().uuidString, documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])

		// Evaluate results
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Get values
		let	(getStatusIsUpToDate, getStatusError) =
					config.httpEndpointClient.cacheGetStatus(documentStorageID: config.documentStorageID, name: "DEF")

		// Evaluate results
		XCTAssertNil(getStatusIsUpToDate, "received isUpToDate")

		XCTAssertNotNil(getStatusError, "did not receive error")
		if getStatusError != nil {
			switch getStatusError! {
				case MDSError.failed(let status):
					// Expected error
					XCTAssertEqual(status, HTTPEndpointStatus.notFound, "did not receive expected error")

				default:
					// Other error
					XCTFail("received unexpected error: \(getStatusError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValuesInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(_, error) =
					config.httpEndpointClient.cacheGetValues(documentStorageID: documentStorageID, name: "ABC",
							valueNames: ["ABC"])

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
	func testGetValuesUnknownName() throws {
		// Setup
		let	config = Config.current

		// Register
		let	registerError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID, name: "ABC",
							documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])

		// Evaluate results
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Get values
		let	(_, getValuesError) =
					config.httpEndpointClient.cacheGetValues(documentStorageID: config.documentStorageID, name: "DEF",
							valueNames: ["ABC"])

		// Evaluate results
		XCTAssertNotNil(getValuesError, "did not receive error")
		if getValuesError != nil {
			switch getValuesError! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown cache: DEF", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(getValuesError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValuesMissingValueName() throws {
		// Setup
		let	config = Config.current

		// Register
		let	registerError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID, name: "ABC",
							documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])

		// Evaluate results
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }


		// Get values
		let	(_, getValuesError) =
					config.httpEndpointClient.cacheGetValues(documentStorageID: config.documentStorageID, name: "ABC",
							valueNames: [])

		// Evaluate results
		XCTAssertNotNil(getValuesError, "did not receive error")
		if getValuesError != nil {
			switch getValuesError! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing valueNames", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(getValuesError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValuesInvalidValueName() throws {
		// Setup
		let	config = Config.current

		// Register
		let	registerError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID,
							name: UUID().uuidString, documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])

		// Evaluate results
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }


		// Get values
		let	(_, getValuesError) =
					config.httpEndpointClient.cacheGetValues(documentStorageID: config.documentStorageID, name: "ABC",
							valueNames: ["DEF"])

		// Evaluate results
		XCTAssertNotNil(getValuesError, "did not receive error")
		if getValuesError != nil {
			switch getValuesError! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown cache valueName: DEF", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(getValuesError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValuesInvalidDocumentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Register
		let	registerError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID, name: "ABC",
							documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])

		// Evaluate results
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }


		// Get values
		let	(_, getValuesError) =
					config.httpEndpointClient.cacheGetValues(documentStorageID: config.documentStorageID, name: "ABC",
							valueNames: ["size"], documentIDs: [documentID])

		// Evaluate results
		XCTAssertNotNil(getValuesError, "did not receive error")
		if getValuesError != nil {
			switch getValuesError! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentID: \(documentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(getValuesError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValues() throws {
		// Setup
		let	config = Config.current

		// Register
		let	registerError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID, name: "ABC",
							documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])

		// Evaluate results
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Create document
		let	documentID = UUID().base64EncodedString
		let	(_, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID, propertyMap: ["size": 123])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")

		// Get values (1)
		let	(getValues1Info, getValues1Error) =
					config.httpEndpointClient.cacheGetValues(documentStorageID: config.documentStorageID, name: "ABC",
							valueNames: ["size"])

		// Evaluate results
		XCTAssertNotNil(getValues1Info, "get values (1) did not return results")
		guard getValues1Info != nil else { return }

		XCTAssertNotNil(getValues1Info!.info, "get values (1) did not return info")
		guard getValues1Info!.info != nil else { return }

		XCTAssertNil(getValues1Error, "get values (1) received error: \(registerError!)")

		let	info1 = getValues1Info!.info!.first(where: { ($0["documentID"] as? String) == documentID })
		XCTAssertNotNil(info1, "get values (1) did not return info for documentID \(documentID)")
		guard info1 != nil else { return }

		XCTAssertEqual(info1!["size"] as? Int, 123, "get values (1) did not return correct size for documentID \(documentID)")

		// Get values (2)
		let	(getValues2Info, getValues2Error) =
					config.httpEndpointClient.cacheGetValues(documentStorageID: config.documentStorageID, name: "ABC",
							valueNames: ["size"], documentIDs: [documentID])

		// Evaluate results
		XCTAssertNotNil(getValues2Info, "get values (2) did not return results")
		guard getValues2Info != nil else { return }

		XCTAssertNotNil(getValues2Info!.info, "get values (2) did not return info")
		guard getValues2Info!.info != nil else { return }

		XCTAssertNil(getValues2Error, "get values (2) received error: \(registerError!)")

		let	info2 = getValues2Info!.info!.first(where: { ($0["documentID"] as? String) == documentID })
		XCTAssertNotNil(info2, "get values (2) did not return info for documentID \(documentID)")
		guard info2 != nil else { return }

		XCTAssertEqual(info2!["size"] as? Int, 123, "get values (2) did not return correct size for documentID \(documentID)")
	}
}
