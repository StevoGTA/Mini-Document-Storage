//
//  AssociationUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 4/5/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: AssociationUnitTests
class AssociationUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testAssociationRegisterFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	error =
					config.httpEndpointClient.associationRegister(documentStorageID: "ABC", name: "ABC",
							fromDocumentType: config.parentDocumentType, toDocumentType: config.childDocumentType)

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

//	//------------------------------------------------------------------------------------------------------------------
//	func testAssociationUpdateFailInvalidDocumentStorageID() throws {
//		// Setup
//		let	config = Config.shared
//
//		// Perform
//		let	errors = config.httpEndpointClient.associationUpdate(documentStorageID: "ABC", name: "ABC", updates: [])
//
//		// Evaluate results
//		XCTAssertNotNil(response, "did not receive response")
//		if response != nil {
//			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
//		}
//
//		XCTAssertNotNil(error, "did not receive error")
//	}
}
