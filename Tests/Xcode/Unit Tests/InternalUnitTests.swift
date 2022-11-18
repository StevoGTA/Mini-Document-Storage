//
//  InternalUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 8/24/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: InternalUnitTests
class InternalUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testSetInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error = config.httpEndpointClient.internalSet(documentStorageID: "ABC", info: ["abc": "abc"])

		// Evaluate results
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
	func testSetNoInfo() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error = config.httpEndpointClient.internalSet(documentStorageID: config.documentStorageID, info: [:])

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
					config.httpEndpointClient.internalSet(documentStorageID: config.documentStorageID,
							info: [
									"abc": "abc",
									"def": "def",
									"xyz": "xyz",
								  ])

		// Evaluate results
		XCTAssertNil(error, "received error \(error!)")
	}
}
