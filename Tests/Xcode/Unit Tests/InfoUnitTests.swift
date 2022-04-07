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
	func testInfoGetFailInvalidDocumentStorageID() throws {
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
					XCTAssertEqual(message, "Invalid documentStorageID", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testInfoFailGet0() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(info, error) = config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID, keys: [])

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
	func testInfoSetFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, info, error) = config.httpEndpointClient.infoSet(documentStorageID: "ABC", info: ["abc": "abc"])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(info, "did not receive info")
		if info != nil {
			XCTAssertNotNil(info!["error"], "did not receive error in info")
			if info!["error"] != nil {
				XCTAssertEqual(info!["error"], "Invalid documentStorageID", "did not receive expected error message")
			}
		}

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testInfoSet0() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, info, error) =
					config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID, info: [:])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(info, "did not receive info")
		if info != nil {
			XCTAssertNotNil(info!["error"], "did not receive error in info")
			if info!["error"] != nil {
				XCTAssertEqual(info!["error"], "Missing info", "did not receive expected error message")
			}
		}

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testInfoSet3() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, info, error) =
					config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID,
							info: [
									"abc": "abc",
									"def": "def",
									"xyz": "xyz",
								  ])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 200, "unexpected response status")
		}

		XCTAssertNotNil(info, "did not receive info")
		if info != nil {
			XCTAssert(info!.isEmpty, "did not receive empty info")
		}

		XCTAssertNil(error, "received error \(error!)")
	}
}
