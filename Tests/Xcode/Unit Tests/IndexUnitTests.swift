//
//  IndexUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 4/22/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: IndexUnitTests
class IndexUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testRegisterFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error =
					config.httpEndpointClient.indexRegister(documentStorageID: "ABC", name: "ABC", documentType: "ABC",
							keysSelector: "ABC")

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
	func testGetDocumentInfosInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.indexGetDocumentInfo(documentStorageID: "ABC", name: "ABC",
							keys: ["ABC"])

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

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
	func testGetDocumentInfosInvalidName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(isUpToDate, info, error) =
					config.httpEndpointClient.indexGetDocumentInfo(documentStorageID: config.documentStorageID,
							name: "ABC", keys: ["ABC"])

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					if (message != "No Indexes") && (message != "No Index found with name ABC") {
						XCTFail("did not receive expected error message")
					}

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}
}
