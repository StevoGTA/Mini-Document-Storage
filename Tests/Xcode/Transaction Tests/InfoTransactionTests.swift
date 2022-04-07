//
//  InfoTransactionTests.swift
//  Transaction Tests
//
//  Created by Stevo on 2/23/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: InfoTransactionTests
class InfoTransactionTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testSetThenGet1() throws {
		// Setup
		let	config = Config.shared

		// Set some info
		let	(infoSetResponse, infoSetInfo, infoSetError) =
					config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID,
							info: ["abc": "abc" ])

		// Evaluate results
		XCTAssertNotNil(infoSetResponse, "set did not receive response")
		if infoSetResponse != nil {
			XCTAssertEqual(infoSetResponse!.statusCode, 200, "set unexpected response status")
		}

		XCTAssertNotNil(infoSetInfo, "set did not receive info")
		if infoSetInfo != nil {
			XCTAssert(infoSetInfo!.isEmpty, "set did not receive empty info")
		}

		XCTAssertNil(infoSetError, "set received error \(infoSetError!)")

		// Get some info
		let	(infoGetInfo, infoGetError) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID, keys: ["abc", "def"])

		// Evaluate results
		XCTAssertNotNil(infoGetInfo, "get did not receive info")
		if infoGetInfo != nil {
			XCTAssertNotNil(infoGetInfo!["abc"], "get did not receive abc in info")
			if infoGetInfo!["abc"] != nil {
				XCTAssertEqual(infoGetInfo!["abc"], "abc", "get did not receive expected value for key abc")
			}

			XCTAssertNil(infoGetInfo!["123"], "did receive 123 in info")
		}

		XCTAssertNil(infoGetError, "get received error \(infoGetError!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSetThenGet2() throws {
		// Setup
		let	config = Config.shared

		// Set some info
		let	(infoSetResponse, infoSetInfo, infoSetError) =
					config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID,
							info: [
									"abc": "abc",
									"def": "def",
								  ])

		// Evaluate results
		XCTAssertNotNil(infoSetResponse, "set did not receive response")
		if infoSetResponse != nil {
			XCTAssertEqual(infoSetResponse!.statusCode, 200, "set unexpected response status")
		}

		XCTAssertNotNil(infoSetInfo, "set did not receive info")
		if infoSetInfo != nil {
			XCTAssert(infoSetInfo!.isEmpty, "set did not receive empty info")
		}

		XCTAssertNil(infoSetError, "set received error \(infoSetError!)")

		// Get some info
		let	(infoGetInfo, infoGetError) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID, keys: ["abc", "def"])

		// Evaluate results
		XCTAssertNotNil(infoGetInfo, "get did not receive info")
		if infoGetInfo != nil {
			XCTAssertNotNil(infoGetInfo!["abc"], "get did not receive abc in info")
			if infoGetInfo!["abc"] != nil {
				XCTAssertEqual(infoGetInfo!["abc"], "abc", "get did not receive expected value for key abc")
			}

			XCTAssertNotNil(infoGetInfo!["def"], "get did not receive def in info")
			if infoGetInfo!["def"] != nil {
				XCTAssertEqual(infoGetInfo!["def"], "def", "get did not receive expected value for key def")
			}

			XCTAssertNil(infoGetInfo!["123"], "did receive 123 in info")
		}

		XCTAssertNil(infoGetError, "get received error \(infoGetError!)")
	}
}
