//
//  AssociationTransactionTests.swift
//  Transaction Tests
//
//  Created by Stevo on 4/21/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: AssociationTransactionTests
class AssociationTransactionTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testAssociationRegisterUpdateRetrieve() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.shared
		let	documentStorage = MDSEphemeral()

		// Create documents
		let	(parentInfos, parentCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Parent.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(parentCreateError, "create parent document received error: \(parentCreateError!)")
		guard let parentDocumentID = parentInfos?.first?["documentID"] as? String else {
			XCTFail("create parent document did not receive document ID")

			return
		}
		let	parent = Parent(id: parentDocumentID, documentStorage: documentStorage)

		let	(childInfos, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")
		guard let childDocumentID = childInfos?.first?["documentID"] as? String else {
			XCTFail("create child document did not receive document ID")

			return
		}
		let	child = Child(id: childDocumentID, documentStorage: documentStorage)

		// Register
		let	registerError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Add
		let	addErrors =
					config.httpEndpointClient.associationUpdate(documentStorageID: config.documentStorageID,
							name: associationName, updates: [(.add, parent, child)])
		XCTAssertEqual(addErrors.count, 0, "update (add) received errors: \(addErrors)")
		guard addErrors.isEmpty else { return }

		// Retrieve from
		let	(fromInfo1, fromError1) =
					config.httpEndpointClient.associationGetDocumentInfos(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentID: parent.id)
		XCTAssertNotNil(fromInfo1, "get from (1) did not receive infos")
		if fromInfo1 != nil {
			XCTAssertEqual(fromInfo1!.documentRevisionInfos.count, 1, "get from (1) did not receive 1 info")
			if fromInfo1!.documentRevisionInfos.count == 1 {
				XCTAssertEqual(fromInfo1!.documentRevisionInfos.first!.documentID, child.id,
						"get from(1) did not receive correct child id")
			}
		}
		XCTAssertNil(fromError1, "get from (1) received error: \(fromError1!)")

		// Retrieve to
		let	(toInfo1, toError1) =
					config.httpEndpointClient.associationGetDocumentInfos(documentStorageID: config.documentStorageID,
							name: associationName, toDocumentID: child.id)
		XCTAssertNotNil(toInfo1, "get to (1) did not receive infos")
		if toInfo1 != nil {
			XCTAssertEqual(toInfo1!.documentRevisionInfos.count, 1, "get to (1) did not receive 1 info")
			if toInfo1!.documentRevisionInfos.count == 1 {
				XCTAssertEqual(toInfo1!.documentRevisionInfos.first!.documentID, parent.id,
						"get to(1) did not receive correct parent id")
			}
		}
		XCTAssertNil(toError1, "get to (1) received error: \(toError1!)")

		// Remove
		let	removeErrors =
					config.httpEndpointClient.associationUpdate(documentStorageID: config.documentStorageID,
							name: associationName, updates: [(.remove, parent, child)])
		XCTAssertEqual(removeErrors.count, 0, "update (remove) received errors: \(removeErrors)")
		guard removeErrors.isEmpty else { return }

		// Retrieve from
		let	(fromInfo2, fromError2) =
					config.httpEndpointClient.associationGetDocumentInfos(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentID: parent.id)
		XCTAssertNotNil(fromInfo2, "get from (2) did not receive infos")
		if fromInfo2 != nil {
			XCTAssertEqual(fromInfo2!.documentRevisionInfos.count, 0, "get from (2) received info")
		}
		XCTAssertNil(fromError2, "get from (2) received error: \(fromError2!)")

		// Retrieve to
		let	(toInfo2, toError2) =
					config.httpEndpointClient.associationGetDocumentInfos(documentStorageID: config.documentStorageID,
							name: associationName, toDocumentID: child.id)
		XCTAssertNotNil(toInfo2, "get to (2) did not receive infos")
		if toInfo2 != nil {
			XCTAssertEqual(toInfo2!.documentRevisionInfos.count, 0, "get to (2) received info")
		}
		XCTAssertNil(toError2, "get to (2) received error: \(toError2!)")
	}
}
