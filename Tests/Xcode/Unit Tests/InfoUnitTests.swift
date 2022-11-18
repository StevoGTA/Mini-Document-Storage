//
//  InfoUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 2/22/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: InfoUnitTests
class InfoUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testGetInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(info, error) = config.httpEndpointClient.infoGet(documentStorageID: "ABC", keys: ["abc"])

		// Evaluate results
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
	func testGetNoKeys() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(info, error) = config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID, keys: [])

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing key(s)", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetInvalidKeys() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(info, error) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID,
							keys: ["AaBb", "CcDd"])

		// Evaluate results
		XCTAssertNotNil(info, "did not receive info")
		XCTAssertNil(error, "received error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSetInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error = config.httpEndpointClient.infoSet(documentStorageID: "ABC", info: ["abc": "abc"])

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
	func testSetNoInfo() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error = config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID, info: [:])

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing info", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSet3() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error =
					config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID,
							info: [
									"abc": "abc",
									"def": "def",
									"xyz": "xyz",
								  ])

		// Evaluate results
		XCTAssertNil(error, "received error \(error!)")
	}
}
