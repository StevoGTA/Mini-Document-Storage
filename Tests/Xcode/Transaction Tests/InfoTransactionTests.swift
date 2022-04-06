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
	func testSetThenGet() throws {
		// Setup
		let	config = Config.shared

		// Set some info
		let	(infoSetResponse, infoSetInfo, infoSetError) =
					config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID,
							info: [
									"abc": "abc",
									"def": "def",
									"xyz": "xyz",
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
		let	(infoGetResponse, infoGetInfo, infoGetError) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID,
							keys: ["abc", "def", "xyz"])

		// Evaluate results
		XCTAssertNotNil(infoGetResponse, "get did not receive response")
		if infoGetResponse != nil {
			XCTAssertEqual(infoGetResponse!.statusCode, 200, "get unexpected response status")
		}

		XCTAssert(infoGetInfo != nil, "get did not receive info")
		if infoGetInfo != nil {
			XCTAssert(infoGetInfo!["abc"] != nil, "get did not receive abc in info")
			if infoGetInfo!["abc"] != nil {
				XCTAssertEqual(infoGetInfo!["abc"], "abc", "get did not receive expected value for key abc")
			}

			XCTAssert(infoGetInfo!["def"] != nil, "get did not receive def in info")
			if infoGetInfo!["def"] != nil {
				XCTAssertEqual(infoGetInfo!["def"], "def", "get did not receive expected value for key def")
			}

			XCTAssert(infoGetInfo!["xyz"] != nil, "get did not receive xyz in info")
			if infoGetInfo!["xyz"] != nil {
				XCTAssertEqual(infoGetInfo!["xyz"], "xyz", "get did not receive expected value for key xyz")
			}
		}

		XCTAssertNil(infoGetError, "get received error \(infoGetError!)")
	}
}
