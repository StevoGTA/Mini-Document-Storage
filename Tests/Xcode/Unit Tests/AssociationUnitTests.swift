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
							fromDocumentType: Parent.documentType, toDocumentType: Child.documentType)

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
	func testAssociationUpdateFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)
		let	child = Child(id: "ABC", documentStorage: documentStorage)
		let	errors =
					config.httpEndpointClient.associationUpdate(documentStorageID: "ABC", name: "ABC",
							updates: [(action: .add, fromDocument: parent, toDocument: child)])

		// Evaluate results
		XCTAssertEqual(errors.count, 1, "did not receive 1 error")
		if errors.count == 1 {
			switch errors.first! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(errors.first!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAssociationUpdateNoUpdates() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	errors = config.httpEndpointClient.associationUpdate(documentStorageID: "ABC", name: "ABC", updates: [])

		// Evaluate results
		XCTAssertEqual(errors.count, 0, "received errors: \(errors)")
	}
}
