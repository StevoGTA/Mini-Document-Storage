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
	func testRegisterFailInvalidDocumentStorageID() throws {
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
					XCTAssertEqual(message, "Invalid documentStorageID", "did not receive expected error message")

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
