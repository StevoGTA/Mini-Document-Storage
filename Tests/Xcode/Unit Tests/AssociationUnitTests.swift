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
	func testRegisterFailInvalidDocumentStorageID() throws {
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
	func testUpdateFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)
		let	child = Child(id: "ABC", documentStorage: documentStorage)
		let	errors =
					config.httpEndpointClient.associationUpdate(documentStorageID: "ABC", name: "ABC",
							updates: [(action: .add, fromDocumentID: parent.id, toDocumentID: child.id)])

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
	func testUpdateNoUpdates() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	errors = config.httpEndpointClient.associationUpdate(documentStorageID: "ABC", name: "ABC", updates: [])

		// Evaluate results
		XCTAssertEqual(errors.count, 0, "received errors: \(errors)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(info, error) = config.httpEndpointClient.associationGet(documentStorageID: "ABC", name: "ABC")

		// Evaluate results
		XCTAssertNil(info, "did receive info")

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
	func testGetDocumentInfosFromFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentInfos(documentStorageID: "ABC", name: "ABC",
							fromDocumentID: parent.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

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
	func testGetDocumentsFromFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocuments(documentStorageID: "ABC", name: "ABC",
							fromDocumentID: parent.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

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
	func testGetDocumentInfosToFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentInfos(documentStorageID: "ABC", name: "ABC",
							toDocumentID: child.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

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
	func testGetDocumentsToFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocuments(documentStorageID: "ABC", name: "ABC",
							toDocumentID: child.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

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
}
