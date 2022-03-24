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
		let	(_, infoSetError) =
					config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID,
							info: [
									"abc": "abc",
									"def": "def",
									"xyz": "xyz",
								  ])

		// Handle results
		if infoSetError != nil {
			// Error
			XCTFail("\(infoSetError!)")
		}

		// Get some info
		let	(_, info, infoGetError) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID,
							keys: ["abc", "def", "xyz"])

		// Handle results
		if let results = info {
			// Success
			var	value = results["abc"]
			XCTAssert(value != nil)
			XCTAssert(value == "abc")

			value = results["def"]
			XCTAssert(value != nil)
			XCTAssert(value == "def")

			value = results["xyz"]
			XCTAssert(value != nil)
			XCTAssert(value == "xyz")

			value = results["123"]
			XCTAssert(value == nil)
		} else {
			// Error
			XCTFail("\(infoGetError!)")
		}

	}
}
