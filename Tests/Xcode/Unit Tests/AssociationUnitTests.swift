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
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	error =
					config.httpEndpointClient.associationRegister(documentStorageID: documentStorageID, name: "ABC",
							fromDocumentType: Parent.documentType, toDocumentType: Child.documentType)

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	documentStorageID = UUID().uuidString
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	errors =
					config.httpEndpointClient.associationUpdate(documentStorageID: documentStorageID, name: "ABC",
							updates: [MDSAssociation.Update.add(from: parent, to: child)])

		// Evaluate results
		XCTAssertEqual(errors.count, 1, "did not receive 1 error")
		if errors.count == 1 {
			switch errors.first! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(errors.first!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateUnknownName() throws {
		// Setup
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	name = UUID().uuidString
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	errors =
					config.httpEndpointClient.associationUpdate(documentStorageID: config.documentStorageID, name: name,
							updates: [MDSAssociation.Update.add(from: parent, to: child)])

		// Evaluate results
		XCTAssertEqual(errors.count, 1, "did not receive 1 error")
		if errors.count == 1 {
			switch errors.first! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: \(name)", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(errors.first!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateNoUpdates() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	errors =
					config.httpEndpointClient.associationUpdate(documentStorageID: UUID().uuidString, name: "ABC",
							updates: [])

		// Evaluate results
		XCTAssertEqual(errors.count, 0, "received errors: \(errors)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateMissingAction() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/association/\(config.documentStorageID)/ABC",
							jsonBody: [["fromID": "ABC", "toID": "ABC"]])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing action", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateInvalidAction() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/association/\(config.documentStorageID)/ABC",
							jsonBody: [["action": "ABC", "fromID": "ABC", "toID": "ABC"]])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid action: ABC", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateMissingFromID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/association/\(config.documentStorageID)/ABC",
							jsonBody: [["action": "add", "toID": "ABC"]])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing fromID", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateMissingToID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSSuccessHTTPEndpointRequest(method: .put,
							path: "/v1/association/\(config.documentStorageID)/ABC",
							jsonBody: [["action": "add", "fromID": "ABC"]])
		let	error =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc($0) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing toID", "did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(info, error) = config.httpEndpointClient.associationGet(documentStorageID: documentStorageID, name: "ABC")

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetUnknownName() throws {
		// Setup
		let	config = Config.current
		let	name = UUID().uuidString

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGet(documentStorageID: config.documentStorageID, name: name)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: \(name)", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosFromInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	documentStorageID = UUID().uuidString
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentRevisionInfos(documentStorageID: documentStorageID,
							name: "ABC", fromDocumentID: parent.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosFromUnknownName() throws {
		// Setup
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	name = UUID().uuidString

		// Perform
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: name, fromDocumentID: parent.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: \(name)", "did not receive expected error message")

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
		let	config = Config.current

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
					config.httpEndpointClient.associationGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: associationName,
							fromDocumentID: documentID )

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
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
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	documentStorageID = UUID().uuidString
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentFullInfos(documentStorageID: documentStorageID,
							name: "ABC", fromDocumentID: parent.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsFromUnknownName() throws {
		// Setup
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	name = UUID().uuidString
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: name, fromDocumentID: parent.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: \(name)", "did not receive expected error message")

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
		let	config = Config.current

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
					config.httpEndpointClient.associationGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: associationName,
							fromDocumentID: documentID)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
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
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	documentStorageID = UUID().uuidString
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentRevisionInfos(documentStorageID: documentStorageID,
							name: "ABC", toDocumentID: child.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentInfosToUnknownName() throws {
		// Setup
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	name = UUID().uuidString
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: name, toDocumentID: child.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: \(name)", "did not receive expected error message")

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
		let	config = Config.current

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
					config.httpEndpointClient.associationGetDocumentRevisionInfos(
							documentStorageID: config.documentStorageID, name: associationName,
							toDocumentID: documentID)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
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
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	documentStorageID = UUID().uuidString
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentFullInfos(documentStorageID: documentStorageID,
							name: "ABC", toDocumentID: child.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetDocumentsToUnknownName() throws {
		// Setup
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	name = UUID().uuidString
		let	child = Child(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: name, toDocumentID: child.id)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: \(name)", "did not receive expected error message")

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
		let	config = Config.current

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
					config.httpEndpointClient.associationGetDocumentFullInfos(
							documentStorageID: config.documentStorageID, name: associationName,
							toDocumentID: documentID)

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
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
	func testDetailGetValueInvalidDocumentStorageID() throws {
		// Test Detail
		try getValueInvalidDocumentStorageID(action: .detail)
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSumGetValueInvalidDocumentStorageID() throws {
		// Test Sum
		try getValueInvalidDocumentStorageID(action: .sum)
	}

	//------------------------------------------------------------------------------------------------------------------
	func getValueInvalidDocumentStorageID(action :MDSAssociation.GetValueAction) throws {
		// Setup
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	documentStorageID = UUID().uuidString
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetValues(documentStorageID: documentStorageID, name: "ABC",
							action: action, fromDocumentIDs: [parent.id], cacheName: "ABC", cachedValueNames: ["ABC"])

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid documentStorageID: \(documentStorageID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDetailGetValueInvalidAssociationName() throws {
		// Test Detail
		try getValueInvalidAssociationName(action: .detail)
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSumGetValueInvalidAssociationName() throws {
		// Test Sum
		try getValueInvalidAssociationName(action: .sum)
	}

	//------------------------------------------------------------------------------------------------------------------
	func getValueInvalidAssociationName(action :MDSAssociation.GetValueAction) throws {
		// Setup
		let	config = Config.current
		let	associationName = UUID().uuidString
		let	documentStorage = MDSEphemeral()
		let	parent = Parent(id: "ABC", documentStorage: documentStorage)

		// Perform
		let	(info, error) =
					config.httpEndpointClient.associationGetValues(documentStorageID: config.documentStorageID,
							name: associationName, action: action, fromDocumentIDs: [parent.id], cacheName: "ABC",
							cachedValueNames: ["ABC"])

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown association: \(associationName)",
							"did not receive expected error message")

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
		let	config = Config.current

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
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[String : Int64]>(method: .get,
							path: "/v1/association/\(config.documentStorageID)/\(associationName)/crashplease",
							queryComponents: [
												"cacheName": "ABC",
												"cachedValueName": "ABC",
											 ],
							multiValueQueryComponent: (key: "fromID", values: ["ABC"]))
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
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid action", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDetailGetValueMissingFromID() throws {
		// Test Detail
		try getValueMissingFromID(action: .detail)
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSumGetValueMissingFromID() throws {
		// Test Sum
		try getValueMissingFromID(action: .sum)
	}

	//------------------------------------------------------------------------------------------------------------------
	func getValueMissingFromID(action :MDSAssociation.GetValueAction) throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(_, error) =
					config.httpEndpointClient.associationGetValues(documentStorageID: config.documentStorageID,
							name: "ABC", action: action, fromDocumentIDs: [], cacheName: "ABC", cachedValueNames: ["ABC"])

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing fromDocumentID",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDetailGetValueInvalidFromID() throws {
		// Test Detail
		try getValueInvalidFromID(action: .detail)
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSumGetValueInvalidFromID() throws {
		// Test Sum
		try getValueInvalidFromID(action: .sum)
	}

	//------------------------------------------------------------------------------------------------------------------
	func getValueInvalidFromID(action :MDSAssociation.GetValueAction) throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	cacheName = UUID().uuidString
		let	config = Config.current

		// Register Association
		let	associationRegisterError =
					config.httpEndpointClient.associationRegister(documentStorageID: config.documentStorageID,
							name: associationName, fromDocumentType: Parent.documentType,
							toDocumentType: Child.documentType)
		XCTAssertNil(associationRegisterError, "association register received error: \(associationRegisterError!)")
		guard associationRegisterError == nil else { return }

		// Register Cache
		let	cacheRegisterError =
					config.httpEndpointClient.cacheRegister(documentStorageID: config.documentStorageID,
							name: cacheName, documentType: Child.documentType, relevantProperties: ["size"],
							valueInfos: [(MDSValueInfo(name: "size", type: .integer), "integerValueForProperty()")])
		XCTAssertNil(cacheRegisterError, "cache register received error: \(cacheRegisterError!)")
		guard cacheRegisterError == nil else { return }

		// Perform - based on other tests and stale data, this may return not up to date
		let	documentID = UUID().base64EncodedString
		var	(info, error) =
					config.httpEndpointClient.associationGetValues(documentStorageID: config.documentStorageID,
							name: associationName, action: action, fromDocumentIDs: [documentID],
							cacheName: cacheName, cachedValueNames: ["size"])
		while (info != nil) && !info!.isUpToDate {
			// Try again
			(info, error) =
					config.httpEndpointClient.associationGetValues(documentStorageID: config.documentStorageID,
							name: associationName, action: action, fromDocumentIDs: [documentID],
							cacheName: cacheName, cachedValueNames: ["size"])
		}

		// Evaluate results
		XCTAssertNil(info, "did receive info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.notFound(let message):
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
	func testGetValueMissingCacheName() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[String : Int64]>(method: .get,
							path: "/v1/association/\(config.documentStorageID)/ABC/sum",
							queryComponents: ["cachedValueName": "ABC"],
							multiValueQueryComponent: (key: "fromID", values: ["ABC"]))
		let	(_, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing cacheName",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDetailGetValueInvalidCacheName() throws {
		// Test Detail
		try getValueInvalidCacheName(action: .detail)
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSumGetValueInvalidCacheName() throws {
		// Test Sum
		try getValueInvalidCacheName(action: .sum)
	}

	//------------------------------------------------------------------------------------------------------------------
	func getValueInvalidCacheName(action :MDSAssociation.GetValueAction) throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	cacheName = UUID().uuidString

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
					config.httpEndpointClient.associationGetValues(documentStorageID: config.documentStorageID,
							name: associationName, action: action, fromDocumentIDs: [parent.id], cacheName: cacheName,
							cachedValueNames: ["ABC"])

		// Evaluate results
		XCTAssertNil(getValueInfo, "did receive info")

		XCTAssertNotNil(getValueError, "did not receive error")
		if getValueError != nil {
			switch getValueError! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown cache: \(cacheName)", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(getValueError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDetailGetValueMissingCachedValueName() throws {
		// Test Detail
		try getValueMissingCachedValueName(action: .detail)
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSumGetValueMissingCachedValueName() throws {
		// Test Sum
		try getValueMissingCachedValueName(action: .sum)
	}

	//------------------------------------------------------------------------------------------------------------------
	func getValueMissingCachedValueName(action :MDSAssociation.GetValueAction) throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(_, error) =
					config.httpEndpointClient.associationGetValues(documentStorageID: config.documentStorageID,
							name: "ABC", action: action, fromDocumentIDs: ["ABC"], cacheName: "ABC",
							cachedValueNames: [])

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.badRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing cachedValueName",
							"did not receive expected error message: \(message)")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDetailGetValueInvalidCachedValueName() throws {
		// Test Detail
		try getValueInvalidCachedValueName(action: .detail)
	}

	//------------------------------------------------------------------------------------------------------------------
	func testSumGetValueInvalidCachedValueName() throws {
		// Test Sum
		try getValueInvalidCachedValueName(action: .sum)
	}

	//------------------------------------------------------------------------------------------------------------------
	func getValueInvalidCachedValueName(action :MDSAssociation.GetValueAction) throws {
		// Setup
		let	associationName = "\(Parent.documentType)To\(Child.documentType.capitalizingFirstLetter)"
		let	cacheName = UUID().uuidString
		let	config = Config.current
		let	documentStorage = MDSEphemeral()
		let	cachedValueName = UUID().uuidString

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

		// Get Association Value
		let	(getValueInfo, getValueError) =
					config.httpEndpointClient.associationGetValues(documentStorageID: config.documentStorageID,
							name: associationName, action: action, fromDocumentIDs: [parent.id], cacheName: cacheName,
							cachedValueNames: [cachedValueName])

		// Evaluate results
		XCTAssertNil(getValueInfo, "did receive info")

		XCTAssertNotNil(getValueError, "did not receive error")
		if getValueError != nil {
			switch getValueError! {
				case MDSError.notFound(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown cache valueName: \(cachedValueName)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(getValueError!)")
			}
		}
	}
}
