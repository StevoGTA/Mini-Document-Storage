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
	func testRegisterInvalidDocumentStorageID() throws {
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
	func testUpdateInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)
		let	child = Child(id: "ABC", documentStorage: documentStorage)
		let	errors =
					config.httpEndpointClient.associationUpdate(documentStorageID: "ABC", name: "ABC",
							updates: [MDSAssociation.Update.add(from: parent, to: child)])

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
	func testUpdateUnknownName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)
		let	child = Child(id: "ABC", documentStorage: documentStorage)
		let	errors =
					config.httpEndpointClient.associationUpdate(documentStorageID: config.documentStorageID,
							name: "ABC", updates: [MDSAssociation.Update.add(from: parent, to: child)])

		// Evaluate results
		XCTAssertEqual(errors.count, 1, "did not receive 1 error")
		if errors.count == 1 {
			switch errors.first! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: ABC", "did not receive expected error message")

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
	func testGetInvalidDocumentStorageID() throws {
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
	func testGetUnknownName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGet(documentStorageID: config.documentStorageID, name: "ABC")

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosFromInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentInfo(documentStorageID: "ABC", name: "ABC",
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
	func testGetDocumentInfosFromUnknownName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentInfo(documentStorageID: config.documentStorageID,
							name: "ABC", fromDocumentID: parent.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosFromInvalidFromID() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.shared

		// Create documents
		let	(_, parentCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Parent.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(parentCreateError, "create parent document received error: \(parentCreateError!)")

		let	(_, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")

		// Register
		let	registerError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Perform
		let	documentID = UUID().base64EncodedString
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentInfo(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentID: documentID )

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentID: \(documentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsFromInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocument(documentStorageID: "ABC", name: "ABC",
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
	func testGetDocumentsFromUnknownName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocument(documentStorageID: config.documentStorageID,
							name: "ABC", fromDocumentID: parent.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsFromInvalidFromID() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.shared

		// Create documents
		let	(_, parentCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Parent.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(parentCreateError, "create parent document received error: \(parentCreateError!)")

		let	(_, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")

		// Register
		let	registerError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Perform
		let	documentID = UUID().base64EncodedString
		let	(info, error) =
					config.httpEndpointClient.associationGetDocument(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentID: documentID )

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentID: \(documentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosToInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentInfo(documentStorageID: "ABC", name: "ABC",
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
	func testGetDocumentInfosToUnknownName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentInfo(documentStorageID: config.documentStorageID,
							name: "ABC", toDocumentID: child.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosToInvalidToID() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.shared

		// Create documents
		let	(_, parentCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Parent.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(parentCreateError, "create parent document received error: \(parentCreateError!)")

		let	(_, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")

		// Register
		let	registerError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Perform
		let	documentID = UUID().base64EncodedString
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentInfo(documentStorageID: config.documentStorageID,
							name: associationName, toDocumentID: documentID )

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentID: \(documentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsToInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocument(documentStorageID: "ABC", name: "ABC",
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
	func testGetDocumentsToUnknownName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocument(documentStorageID: config.documentStorageID,
							name: "ABC", toDocumentID: child.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsToInvalidToID() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.shared

		// Create documents
		let	(_, parentCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Parent.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(parentCreateError, "create parent document received error: \(parentCreateError!)")

		let	(_, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")

		// Register
		let	registerError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Perform
		let	documentID = UUID().base64EncodedString
		let	(info, error) =
					config.httpEndpointClient.associationGetDocument(documentStorageID: config.documentStorageID,
							name: associationName, toDocumentID: documentID )

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentID: \(documentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValueInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetIntegerValue(documentStorageID: "ABC", name: "ABC",
							action: .sum, fromDocumentID: parent.id, cacheName: "ABC", cachedValueName: "ABC")

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
	func testGetValueInvalidAssociationName() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetIntegerValue(documentStorageID: config.documentStorageID,
							name: "ABC", action: .sum, fromDocumentID: parent.id, cacheName: "ABC",
							cachedValueName: "ABC")

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValueInvalidAction() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.shared

		// Create documents
		let	(_, parentCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Parent.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(parentCreateError, "create parent document received error: \(parentCreateError!)")

		let	(_, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")

		// Register
		let	registerError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSIntegerWithUpToDateHTTPEndpointRequest(method: .get,
							path: "/v1/association/\(config.documentStorageID)/\(name)/crashplease",
							queryComponents: [
												"fromID": "ABC",
												"cacheName": "ABC",
												"cachedValueName": "ABC",
											 ])
		let	(info, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid action", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValueInvalidFromID() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.shared

		// Register
		let	registerError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(registerError, "register received error: \(registerError!)")
		guard registerError == nil else { return }

		// Perform
		let	documentID = UUID().base64EncodedString
		let	(info, error) =
					config.httpEndpointClient.associationGetIntegerValue(documentStorageID: config.documentStorageID,
							name: associationName, action: .sum, fromDocumentID: documentID,
							cacheName: "ABC", cachedValueName: "ABC")

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentID: \(documentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValueInvalidCacheName() throws {
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

		// Get Association Value
		let	(getValueInfo, getValueError) =
					config.httpEndpointClient.associationGetIntegerValue(documentStorageID: config.documentStorageID,
							name: associationName, action: .sum, fromDocumentID: parent.id, cacheName: "ABC",
							cachedValueName: "ABC")

		// Evaluate results
		XCTAssertNil(getValueInfo, "did receive info")

		XCTAssertNotNil(getValueError, "did not receive error")
		if getValueError != nil {
			switch getValueError! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown cache: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(getValueError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetValueInvalidCachedValueName() throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	cacheName = UUID().uuidString
		let	config = Config.shared
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
							valueInfos: [("size", .integer, "integerValueForProperty()")])
		XCTAssertNil(cacheRegisterError, "cache register received error: \(cacheRegisterError!)")
		guard cacheRegisterError == nil else { return }

		// Get Association Value (may not be up to date - depends on server implementation)
		let	(getValueInfo, getValueError) =
					config.httpEndpointClient.associationGetIntegerValue(documentStorageID: config.documentStorageID,
							name: associationName, action: .sum, fromDocumentID: parent.id, cacheName: cacheName,
							cachedValueName: "ABC")

		// Evaluate results
		XCTAssertNil(getValueInfo, "did receive info")

		XCTAssertNotNil(getValueError, "did not receive error")
		if getValueError != nil {
			switch getValueError! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown cache valueName: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(getValueError!)")
			}
		}
	}
}
