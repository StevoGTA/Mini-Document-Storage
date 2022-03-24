//
//  InfoUnitTetsts.swift
//  Unit Tests
//
//  Created by Stevo on 2/22/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: InfoUnitTetsts
class InfoUnitTetsts : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testInfoGet() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(_, info, error) =
					config.httpEndpointClient.infoGet(documentStorageID: config.documentStorageID, keys: ["abc"])

		// Handle results
		if info != nil {
			// Success
			let	value = info!["abc"]
			XCTAssert(value != nil)
			XCTAssert(value == "abc")
		} else {
			// Error
			XCTFail("\(error!)")
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testInfoSet() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(_, error) =
					config.httpEndpointClient.infoSet(documentStorageID: config.documentStorageID,
							info: [
									"abc": "abc",
									"def": "def",
									"xyz": "xyz",
								  ])

		// Handle results
		if error != nil {
			// Error
			XCTFail("\(error!)")
		}
	}
}
