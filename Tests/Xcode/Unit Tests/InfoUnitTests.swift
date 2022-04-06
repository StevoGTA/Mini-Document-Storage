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
		let	(response, info, error) = config.httpEndpointClient.infoGet(documentStorageID: "ABC", keys: ["abc"])

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
	func testInfoFailGet0() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, info, error) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID, keys: [])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(info, "did not receive info")
		if info != nil {
			XCTAssertNotNil(info!["error"], "did not receive error in info")
			if info!["error"] != nil {
				XCTAssertEqual(info!["error"], "Missing key(s)", "did not receive expected error message")
			}
		}

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testInfoGet1() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, info, error) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID, keys: ["abc"])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 200, "unexpected response status")
		}

		XCTAssertNotNil(info, "did not receive info")
		if info != nil {
			XCTAssertNotNil(info!["abc"], "did not receive abc in info")
			if info!["abc"] != nil {
				XCTAssertEqual(info!["abc"], "abc", "did not receive expected value for key abc")
			}

			XCTAssertNil(info!["123"], "did receive 123 in info")
		}

		XCTAssertNil(error, "received error \(error!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testInfoGet2() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, info, error) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID, keys: ["abc", "def"])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 200, "unexpected response status")
		}

		XCTAssertNotNil(info, "did not receive info")
		if info != nil {
			XCTAssert(info!["abc"] != nil, "did not receive abc in info")
			if info!["abc"] != nil {
				XCTAssertEqual(info!["abc"], "abc", "did not receive expected value for key abc")
			}

			XCTAssert(info!["def"] != nil, "did not receive def in info")
			if info!["def"] != nil {
				XCTAssertEqual(info!["def"], "def", "did not receive expected value for key def")
			}

			XCTAssertNil(info!["123"], "did receive 123 in info")
		}

		XCTAssertNil(error, "received error \(error!)")
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
