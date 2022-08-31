//
//  CollectionUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 4/23/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: CollectionUnitTests
class CollectionUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testRegisterFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error =
					config.httpEndpointClient.collectionRegister(documentStorageID: "ABC", name: "ABC",
							documentType: "ABC", isIncludedSelector: "ABC")

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
	func testGetDocumentCountInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(info, error) = config.httpEndpointClient.collectionGetDocumentCount(documentStorageID: "ABC", name: "ABC")

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.failed(let status):
					// Expected error
					XCTAssertEqual(status, HTTPEndpointStatus.badRequest, "did not receive expected error")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentCountInvalidName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(info, error) =
					config.httpEndpointClient.collectionGetDocumentCount(documentStorageID: config.documentStorageID,
							name: "ABC")

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.failed(let status):
					// Expected error
					XCTAssertEqual(status, HTTPEndpointStatus.badRequest, "did not receive expected error")

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
					config.httpEndpointClient.collectionGetDocumentInfo(documentStorageID: "ABC", name: "ABC")

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
					config.httpEndpointClient.collectionGetDocumentInfo(documentStorageID: config.documentStorageID,
							name: "ABC")

		// Evaluate results
		XCTAssertNil(isUpToDate, "received isUpToDate")

		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					if (message != "No Collections") && (message != "No Collection found with name ABC") {
						XCTFail("did not receive expected error message")
					}

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}
}
