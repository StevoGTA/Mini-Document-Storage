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
	func testRegisterUpdateRetrieveDocumentInfo() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.current
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
							name: associationName, updates: [MDSAssociation.Update.add(from: parent, to: child)])
		XCTAssertEqual(addErrors.count, 0, "update (add) received errors: \(addErrors)")
		guard addErrors.isEmpty else { return }

		// Retrieve all
		let	(getInfo1, getError1) =
					config.httpEndpointClient.associationGet(documentStorageID: config.documentStorageID,
							name: associationName)
		XCTAssertNotNil(getInfo1, "get (1) did not receive info")
		XCTAssertNil(getError1, "get (1) received error: \(getError1!)")

		// Retrieve from
		let	(fromInfo1, fromError1) =
					config.httpEndpointClient.associationGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: associationName, fromDocumentID: parent.id)
		XCTAssertNotNil(fromInfo1, "get from (1) did not receive info")
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
					config.httpEndpointClient.associationGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: associationName, toDocumentID: child.id)
		XCTAssertNotNil(toInfo1, "get to (1) did not receive info")
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
							name: associationName, updates: [MDSAssociation.Update.remove(from: parent, to: child)])
		XCTAssertEqual(removeErrors.count, 0, "update (remove) received errors: \(removeErrors)")
		guard removeErrors.isEmpty else { return }

		// Retrieve from
		let	(fromInfo2, fromError2) =
					config.httpEndpointClient.associationGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: associationName, fromDocumentID: parent.id)
		XCTAssertNotNil(fromInfo2, "get from (2) did not receive info")
		if fromInfo2 != nil {
			XCTAssertEqual(fromInfo2!.documentRevisionInfos.count, 0, "get from (2) received info")
		}
		XCTAssertNil(fromError2, "get from (2) received error: \(fromError2!)")

		// Retrieve to
		let	(toInfo2, toError2) =
					config.httpEndpointClient.associationGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: associationName, toDocumentID: child.id)
		XCTAssertNotNil(toInfo2, "get to (2) did not receive info")
		if toInfo2 != nil {
			XCTAssertEqual(toInfo2!.documentRevisionInfos.count, 0, "get to (2) received info")
		}
		XCTAssertNil(toError2, "get to (2) received error: \(toError2!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testRegisterUpdateRetrieveDocuments() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.current
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
							name: associationName, updates: [MDSAssociation.Update.add(from: parent, to: child)])
		XCTAssertEqual(addErrors.count, 0, "update (add) received errors: \(addErrors)")
		guard addErrors.isEmpty else { return }

		// Retrieve all
		let	(getInfo1, getError1) =
					config.httpEndpointClient.associationGet(documentStorageID: config.documentStorageID,
							name: associationName)
		XCTAssertNotNil(getInfo1, "get (1) did not receive info")
		XCTAssertNil(getError1, "get (1) received error: \(getError1!)")

		// Retrieve from
		let	(fromInfo1, fromError1) =
					config.httpEndpointClient.associationGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: associationName,
							fromDocumentID: parent.id)
		XCTAssertNotNil(fromInfo1, "get from (1) did not receive info")
		if fromInfo1 != nil {
			XCTAssertEqual(fromInfo1!.documentFullInfos.count, 1, "get from (1) did not receive 1 info")
			if fromInfo1!.documentFullInfos.count == 1 {
				XCTAssertEqual(fromInfo1!.documentFullInfos.first!.documentID, child.id,
						"get from(1) did not receive correct child id")
			}
		}
		XCTAssertNil(fromError1, "get from (1) received error: \(fromError1!)")

		// Retrieve to
		let	(toInfo1, toError1) =
					config.httpEndpointClient.associationGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: associationName, toDocumentID: child.id)
		XCTAssertNotNil(toInfo1, "get to (1) did not receive info")
		if toInfo1 != nil {
			XCTAssertEqual(toInfo1!.documentFullInfos.count, 1, "get to (1) did not receive 1 info")
			if toInfo1!.documentFullInfos.count == 1 {
				XCTAssertEqual(toInfo1!.documentFullInfos.first!.documentID, parent.id,
						"get to(1) did not receive correct parent id")
			}
		}
		XCTAssertNil(toError1, "get to (1) received error: \(toError1!)")

		// Remove
		let	removeErrors =
					config.httpEndpointClient.associationUpdate(documentStorageID: config.documentStorageID,
							name: associationName, updates: [MDSAssociation.Update.remove(from: parent, to: child)])
		XCTAssertEqual(removeErrors.count, 0, "update (remove) received errors: \(removeErrors)")
		guard removeErrors.isEmpty else { return }

		// Retrieve from
		let	(fromInfo2, fromError2) =
					config.httpEndpointClient.associationGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: associationName,
							fromDocumentID: parent.id)
		XCTAssertNotNil(fromInfo2, "get from (2) did not receive info")
		if fromInfo2 != nil {
			XCTAssertEqual(fromInfo2!.documentFullInfos.count, 0, "get from (2) received info")
		}
		XCTAssertNil(fromError2, "get from (2) received error: \(fromError2!)")

		// Retrieve to
		let	(toInfo2, toError2) =
					config.httpEndpointClient.associationGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: associationName, toDocumentID: child.id)
		XCTAssertNotNil(toInfo2, "get to (2) did not receive info")
		if toInfo2 != nil {
			XCTAssertEqual(toInfo2!.documentFullInfos.count, 0, "get to (2) received info")
		}
		XCTAssertNil(toError2, "get to (2) received error: \(toError2!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValue() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	cacheName = UUID().uuidString
		let	config = Config.current
		let	documentStorage = MDSEphemeral()

		// Create documents
		let	(parentInfos, parentCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Parent.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(parentCreateError, "create parent document received error: \(parentCreateError!)")
		XCTAssertNotNil(parentInfos, "create parent document did not receive info")
		guard parentInfos != nil else { return }
		let	parent = Parent(id: parentInfos![0]["documentID"] as! String, documentStorage: documentStorage)

		let	(childInfos1, childCreateError1) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos:
									[
										MDSDocument.CreateInfo(propertyMap: ["size": 123]),
										MDSDocument.CreateInfo(propertyMap: ["size": 456]),
									])
		XCTAssertNil(childCreateError1, "create child documents received error: \(childCreateError1!)")
		XCTAssertNotNil(childInfos1, "create child documents did not receive infos")
		guard childInfos1 != nil else { return }
		let	child1 = Child(id: childInfos1![0]["documentID"] as! String, documentStorage: documentStorage)
		let	child2 = Child(id: childInfos1![1]["documentID"] as! String, documentStorage: documentStorage)

		// Register Association
		let	associationRegisterError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(associationRegisterError, "association register received error: \(associationRegisterError!)")
		guard associationRegisterError == nil else { return }

		// Add Associations (Parent -> 1, 2)
		let	addErrors1 =
					config.httpEndpointClient.associationUpdate(documentStorageID: config.documentStorageID,
							name: associationName,
							updates:
									[
										MDSAssociation.Update.add(from: parent, to: child1),
										MDSAssociation.Update.add(from: parent, to: child2),
									])
		XCTAssertEqual(addErrors1.count, 0, "update (add) (1) received errors: \(addErrors1)")
		guard addErrors1.isEmpty else { return }

		// Register Cache
		let	cacheRegisterError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID,
							name: cacheName, documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])
		XCTAssertNil(cacheRegisterError, "cache register received error: \(cacheRegisterError!)")
		guard cacheRegisterError == nil else { return }

		// Get Association Value (may not be up to date - depends on server implementation)
		var	(getValueInfo1, getValueError1) =
					config.httpEndpointClient.associationGetIntegerValues(documentStorageID: config.documentStorageID,
							name: associationName, action: .sum, fromDocumentIDs: [parent.id], cacheName: cacheName,
							cachedValueNames: ["size"])
		while (getValueInfo1 != nil) && !getValueInfo1!.isUpToDate {
			// Try again
			(getValueInfo1, getValueError1) =
					config.httpEndpointClient.associationGetIntegerValues(documentStorageID: config.documentStorageID,
							name: associationName, action: .sum, fromDocumentIDs: [parent.id], cacheName: cacheName,
							cachedValueNames: ["size"])
		}
		XCTAssertNotNil(getValueInfo1, "get value (1) did not receive info")
		guard getValueInfo1 != nil else { return }
		XCTAssertNotNil(getValueInfo1!.cachedValues, "get value (1) did not receive cachedValues")
		guard getValueInfo1!.cachedValues != nil else { return }
		XCTAssertEqual(getValueInfo1!.cachedValues!["size"]!, 123 + 456, "get value (1) did not receive correct value")
		XCTAssertNil(getValueError1, "get value (1) received error: \(getValueError1!)")

		// Create another document
		let	(childInfos2, childCreateError2) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos:
									[
										MDSDocument.CreateInfo(propertyMap: ["size": 789]),
									])
		XCTAssertNil(childCreateError2, "create child documents received error: \(childCreateError2!)")
		XCTAssertNotNil(childInfos2, "create child documents did not receive infos")
		guard childInfos2 != nil else { return }
		let	child3 = Child(id: childInfos2![0]["documentID"] as! String, documentStorage: documentStorage)

		// Add Association (Parent -> 3)
		let	addErrors2 =
					config.httpEndpointClient.associationUpdate(documentStorageID: config.documentStorageID,
							name: associationName, updates: [MDSAssociation.Update.add(from: parent, to: child3)])
		XCTAssertEqual(addErrors2.count, 0, "update (add) (2) received errors: \(addErrors2)")
		guard addErrors2.isEmpty else { return }

		// Get Association Value (up to date)
		let	(getValueInfo2, getValueError2) =
					config.httpEndpointClient.associationGetIntegerValues(documentStorageID: config.documentStorageID,
							name: associationName, action: .sum, fromDocumentIDs: [parent.id], cacheName: cacheName,
							cachedValueNames: ["size"])
		XCTAssertNotNil(getValueInfo2, "get value (2) did not receive info")
		guard getValueInfo2 != nil else { return }
		XCTAssertTrue(getValueInfo2!.isUpToDate, "get value (2) is not up to date")
		guard getValueInfo2!.isUpToDate else { return }
		XCTAssertNotNil(getValueInfo2!.cachedValues, "get value (2) did not receive cachedValues")
		guard getValueInfo2!.cachedValues != nil else { return }
		XCTAssertEqual(getValueInfo2!.cachedValues!["size"]!, 123 + 456 + 789,
				"get value (2) did not receive correct value")
		XCTAssertNil(getValueError2, "get value (2) received error: \(getValueError2!)")
	}
}
