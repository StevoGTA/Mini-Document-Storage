//
//  DocumentUnitTests.swift
//  Unit Tests
//
//  Created by Stevo on 3/17/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: DocumentUnitTests
class DocumentUnitTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testCreateInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: ["key": "value"])])

		// Evaluate results
		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
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
	func testCreateMissingInfos() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentCreateInfos: [])

		// Evaluate results
		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing info(s)", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testCreateLongDocumentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().uuidString

		// Create document
		let	(documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(documentID: documentID, propertyMap: [:])])

		// Evaluate results
		if config.supportsLongDocumentIDs {
			// Should not get error
			XCTAssertNotNil(documentInfos, "did not receive documentInfos")
			XCTAssertNil(error, "received error \(error!)")
		} else {
			// Should get error
			XCTAssertNil(documentInfos, "received documentInfos")

			XCTAssertNotNil(error, "did not receive error")
			if error != nil {
				switch error! {
					case MDSError.invalidRequest(let message):
						// Expected error
						XCTAssertEqual(message, "Invalid documentID: \(documentID) (exceeds max length of 22)",
								"did not receive expected error message")

					default:
						// Other error
						XCTFail("received unexpected error: \(error!)")
				}
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testCreate1() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: ["key": "value"])])

		// Evaluate results
		XCTAssertNotNil(documentInfos, "did not receive documentInfos")
		if documentInfos != nil {
			XCTAssertEqual(documentInfos!.count, 1, "did not receive 1 documentInfo")
			if documentInfos!.count > 0 {
				let	documentInfo = documentInfos![0]

				XCTAssertNotNil(documentInfo["documentID"], "did not receive documentID")
				XCTAssert(documentInfo["documentID"] is String, "documentID is not a String")

				XCTAssertNotNil(documentInfo["revision"], "did not receive revision")
				XCTAssert(documentInfo["revision"] is Int, "revision is not an Int")

				XCTAssertNotNil(documentInfo["creationDate"], "did not receive creationDate")
				XCTAssert(documentInfo["creationDate"] is String, "creationDate is not a String")
				if let string = documentInfo["creationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string), "creationDate could not be decoded to a Date")
				}

				XCTAssertNotNil(documentInfo["modificationDate"], "did not receive modificationDate")
				XCTAssert(documentInfo["modificationDate"] is String, "modificationDate is not a String")
				if let string = documentInfo["modificationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string),
							"modificationDate could not be decoded to a Date")
				}
			}
		}

		XCTAssertNil(error, "received error \(error!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testCreate2() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[
										MDSDocument.CreateInfo(propertyMap: ["key": "value1"]),
										MDSDocument.CreateInfo(propertyMap: ["key": "value2"]),
									])

		// Evaluate results
		XCTAssertNotNil(documentInfos, "did not receive documentInfos")
		if documentInfos != nil {
			XCTAssertEqual(documentInfos!.count, 2, "did not receive 2 documentInfos")
			if documentInfos!.count > 0 {
				let	documentInfo = documentInfos![0]

				XCTAssertNotNil(documentInfo["documentID"], "did not receive documentID")
				XCTAssert(documentInfo["documentID"] is String, "documentID is not a String")

				XCTAssertNotNil(documentInfo["revision"], "did not receive revision")
				XCTAssert(documentInfo["revision"] is Int, "revision is not an Int")

				XCTAssertNotNil(documentInfo["creationDate"], "did not receive creationDate")
				XCTAssert(documentInfo["creationDate"] is String, "creationDate is not a String")
				if let string = documentInfo["creationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string), "creationDate could not be decoded to a Date")
				}

				XCTAssertNotNil(documentInfo["modificationDate"], "did not receive modificationDate")
				XCTAssert(documentInfo["modificationDate"] is String, "modificationDate is not a String")
				if let string = documentInfo["modificationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string),
							"modificationDate could not be decoded to a Date")
				}
			}

			if documentInfos!.count > 1 {
				let	documentInfo = documentInfos![1]

				XCTAssertNotNil(documentInfo["documentID"], "did not receive documentID")
				XCTAssert(documentInfo["documentID"] is String, "documentID is not a String")

				XCTAssertNotNil(documentInfo["revision"], "did not receive revision")
				XCTAssert(documentInfo["revision"] is Int, "revision is not an Int")

				XCTAssertNotNil(documentInfo["creationDate"], "did not receive creationDate")
				XCTAssert(documentInfo["creationDate"] is String, "creationDate is not a String")
				if let string = documentInfo["creationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string), "creationDate could not be decoded to a Date")
				}

				XCTAssertNotNil(documentInfo["modificationDate"], "did not receive modificationDate")
				XCTAssert(documentInfo["modificationDate"] is String, "modificationDate is not a String")
				if let string = documentInfo["modificationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string),
							"modificationDate could not be decoded to a Date")
				}
			}
		}

		XCTAssertNil(error, "received error \(error!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetCountInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(count, error) =
					config.httpEndpointClient.documentGetCount(documentStorageID: UUID().uuidString,
							documentType: config.defaultDocumentType)

		// Evaluate results
		XCTAssertNil(count, "received count")

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
	func testGetCountInvalidDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	(count, error) =
					config.httpEndpointClient.documentGetCount(documentStorageID: config.documentStorageID,
							documentType: documentType)

		// Evaluate results
		XCTAssertNil(count, "received count")

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
	func testGetSinceRevisionInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentGetDocumentFullInfos(documentStorageID: documentStorageID,
							documentType: config.defaultDocumentType, sinceRevision: 0)

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
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
	func testGetSinceRevisionUnknownDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentGetDocumentFullInfos(documentStorageID: config.documentStorageID,
							documentType: documentType, sinceRevision: 0)

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentType: \(documentType)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetSinceRevisionInvalidRevision() throws {
		// Setup
		let	config = Config.current

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Get since revision
		let	(info, error) =
					config.httpEndpointClient.documentGetDocumentFullInfos(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, sinceRevision: -1)

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid revision: -1", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetSinceRevisionInvalidCount() throws {
		// Setup
		let	config = Config.current

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Get since revision
		let	(info, error) =
					config.httpEndpointClient.documentGetDocumentFullInfos(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, sinceRevision: 0, count: -1)

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Invalid count: -1", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetIDsInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(documentFullInfos, error) =
					config.httpEndpointClient.documentGetDocumentFullInfos(documentStorageID: documentStorageID,
							documentType: config.defaultDocumentType, documentIDs: ["ABC"])

		// Evaluate results
		XCTAssertNil(documentFullInfos, "received documentFullInfos")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
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
	func testGetIDsUnknownDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	(documentFullInfos, error) =
					config.httpEndpointClient.documentGetDocumentFullInfos(documentStorageID: config.documentStorageID,
							documentType: documentType, documentIDs: ["ABC"])

		// Evaluate results
		XCTAssertNil(documentFullInfos, "received documentFullInfos")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentType: \(documentType)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetIDsNoIDs() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(documentFullInfos, error) =
					config.httpEndpointClient.documentGetDocumentFullInfos(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentIDs: [])

		// Evaluate results
		XCTAssertNil(documentFullInfos, "received documentFullInfos")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing id(s)", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testGetIDsUnknownID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create Test document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(createError, "create document received error: \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	(documentFullInfos, error) =
					config.httpEndpointClient.documentGetDocumentFullInfos(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentIDs: [documentID])

		// Evaluate results
		XCTAssertNil(documentFullInfos, "received documentFullInfos")

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
	func testUpdateInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(documentInfos, error) =
					config.httpEndpointClient.documentUpdate(documentStorageID: documentStorageID, documentType: "ABC",
							documentUpdateInfos: [MDSDocument.UpdateInfo(documentID: "ABC", active: true)])

		// Evaluate results
		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
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
	func testUpdateUnknownDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	(documentInfos, error) =
					config.httpEndpointClient.documentUpdate(documentStorageID: config.documentStorageID,
							documentType: documentType,
							documentUpdateInfos: [MDSDocument.UpdateInfo(documentID: "ABC")])

		// Evaluate results
		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentType: \(documentType)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateMissingDocumentID() throws {
		// Setup
		let	config = Config.current

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[[String : Any]]>(method: .patch,
							path: "/v1/document/\(config.documentStorageID)/\(config.defaultDocumentType)",
							jsonBody: [
										[
											"updated": [String:Any](),
											"removed": [String](),
											"active": 1,
										] as [String : Any]
									  ])
		let	(documentInfos, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing documentID", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateMissingUpdated() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID,
											propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[[String : Any]]>(method: .patch,
							path: "/v1/document/\(config.documentStorageID)/\(config.defaultDocumentType)",
							jsonBody: [
										[
											"documentID": documentID,
											"removed": [String](),
											"active": 1,
										] as [String : Any]
									  ])
		let	(documentInfos, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNotNil(documentInfos, "did not receive documentInfos")
		XCTAssertNil(error, "received unexpected error: \(error!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateMissingRemoved() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID,
											propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[[String : Any]]>(method: .patch,
							path: "/v1/document/\(config.documentStorageID)/\(config.defaultDocumentType)",
							jsonBody: [
										[
											"documentID": documentID,
											"updated": [String:Any](),
											"active": 1,
										] as [String : Any]
									  ])
		let	(documentInfos, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNotNil(documentInfos, "did not receive documentInfos")
		XCTAssertNil(error, "received unexpected error: \(error!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testUpdateMissingActive() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID,
											propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[[String : Any]]>(method: .patch,
							path: "/v1/document/\(config.documentStorageID)/\(config.defaultDocumentType)",
							jsonBody: [
										[
											"documentID": documentID,
											"updated": [String:Any](),
											"removed": [String](),
										] as [String : Any]
									  ])
		let	(documentInfos, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNotNil(documentInfos, "did not receive documentInfos")
		XCTAssertNil(error, "received unexpected error: \(error!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentAddInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentAttachmentAdd(documentStorageID: documentStorageID,
							documentType: config.defaultDocumentType, documentID: "ABC", info: [:],
							content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
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
	func testAttachmentAddUnknownDocumentType() throws {
		// Setup
		let	config = Config.current

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentAttachmentAdd(documentStorageID: config.documentStorageID,
							documentType: "ABC", documentID: "ABC", info: [:], content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentType: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentAddUnknownDocumentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentAttachmentAdd(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID, info: [:],
							content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNil(info, "received info")

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
	func testAttachmentAddMissingInfo() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID,
											propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	documentIDUse =
					documentID.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "/").inverted)!
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[String : Any]>(method: .post,
							path: "/v1/document/\(config.documentStorageID)/\(config.defaultDocumentType)/\(documentIDUse)/attachment",
							jsonBody: ["content": Data(capacity: 0).base64EncodedString()])
		let	(info, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing info", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentAddMissingContent() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID,
											propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	documentIDUse =
					documentID.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "/").inverted)!
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[String : Any]>(method: .post,
							path: "/v1/document/\(config.documentStorageID)/\(config.defaultDocumentType)/\(documentIDUse)/attachment",
							jsonBody: ["info": [String:Any]()] as [String : Any])

		let	(info, error) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing content", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentGetInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(content, error) =
					config.httpEndpointClient.documentAttachmentGet(documentStorageID: documentStorageID,
							documentType: config.defaultDocumentType, documentID: "ABC", attachmentID: "ABC")

		// Evaluate results
		XCTAssertNil(content, "received content")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
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
	func testAttachmentGetUnknownDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	(content, error) =
					config.httpEndpointClient.documentAttachmentGet(documentStorageID: config.documentStorageID,
							documentType: documentType, documentID: "ABC", attachmentID: "ABC")

		// Evaluate results
		XCTAssertNil(content, "received content")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentType: \(documentType)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentGetUnknownDocumentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Document create
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: ["key": "value"])])
		XCTAssertNil(createError, "received unexpected error: \(createError!)")
		guard createError == nil else { return }

		// Document attachment get
		let	(attachmentGetContent, attachmentGetError) =
					config.httpEndpointClient.documentAttachmentGet(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID, attachmentID: "ABC")

		// Evaluate results
		XCTAssertNil(attachmentGetContent, "received content")

		XCTAssertNotNil(attachmentGetError, "did not receive error")
		if attachmentGetError != nil {
			switch attachmentGetError! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentID: \(documentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(attachmentGetError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentGetUnknownAttachmentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID, propertyMap: ["key": "value"])])
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	(content, error) =
					config.httpEndpointClient.documentAttachmentGet(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID, attachmentID: "ABC")

		// Evaluate results
		XCTAssertNil(content, "received content")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown attachmentID: ABC", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentUpdateInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentAttachmentUpdate(documentStorageID: documentStorageID,
							documentType: config.defaultDocumentType, documentID: "ABC", attachmentID: "ABC", info: [:],
							content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
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
	func testAttachmentUpdateUnknownDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentAttachmentUpdate(documentStorageID: config.documentStorageID,
							documentType: documentType, documentID: "ABC", attachmentID: "ABC", info: [:],
							content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentType: \(documentType)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentUpdateUnknownDocumentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: ["key": "value"])])
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentAttachmentUpdate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID, attachmentID: "ABC",
							info: [:], content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNil(info, "received info")

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
	func testAttachmentUpdateUnknownAttachmentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString
		let	attachmentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID, propertyMap: ["key": "value"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	(info, error) =
					config.httpEndpointClient.documentAttachmentUpdate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID,
							attachmentID: attachmentID, info: [:], content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNil(info, "received info")

		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown attachmentID: \(attachmentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentUpdateMissingInfo() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID,
											propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Add attachment
		let	(addAttachmentInfo, addAttachmentError) =
					config.httpEndpointClient.documentAttachmentAdd(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID,
							info: ["key1": "value1"], content: "content1".data(using: .utf8)!)
		XCTAssertNotNil(addAttachmentInfo, "add attachment did not receive info")
		XCTAssertNil(addAttachmentError, "add attachment received error \(addAttachmentError!)")
		guard addAttachmentError == nil else { return }

		let	attachmentID = addAttachmentInfo!["id"] as? String
		XCTAssertNotNil(attachmentID, "add attachment did not receive attachment ID")
		guard attachmentID != nil else { return }

		// Update attachment
		let	documentIDUse =
					documentID.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "/").inverted)!
		let	attachmentIDUse =
					attachmentID!.addingPercentEncoding(
							withAllowedCharacters: CharacterSet(charactersIn: "/").inverted)!
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[String : Any]>(method: .patch,
							path: "/v1/document/\(config.documentStorageID)/\(config.defaultDocumentType)/\(documentIDUse)/attachment/\(attachmentIDUse)",
							jsonBody: ["content": "content2".data(using: .utf8)!.base64EncodedString()])
		let	(updateAttachmentInfo, updateAttachmentError) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNil(updateAttachmentInfo, "received info")

		XCTAssertNotNil(updateAttachmentError, "did not receive error")
		if updateAttachmentError != nil {
			switch updateAttachmentError! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing info", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(updateAttachmentError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentUpdateMissingContent() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID,
											propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Add attachment
		let	(addAttachmentInfo, addAttachmentError) =
					config.httpEndpointClient.documentAttachmentAdd(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID,
							info: ["key1": "value1"], content: "content1".data(using: .utf8)!)
		XCTAssertNotNil(addAttachmentInfo, "add attachment did not receive info")
		XCTAssertNil(addAttachmentError, "add attachment received error \(addAttachmentError!)")
		guard addAttachmentError == nil else { return }

		let	attachmentID = addAttachmentInfo!["id"] as? String
		XCTAssertNotNil(attachmentID, "add attachment did not receive attachment ID")
		guard attachmentID != nil else { return }

		// Update attachment
		let	documentIDUse =
					documentID.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "/").inverted)!
		let	attachmentIDUse =
					attachmentID!.addingPercentEncoding(
							withAllowedCharacters: CharacterSet(charactersIn: "/").inverted)!
		let	httpEndpointRequest =
					MDSHTTPServices.MDSJSONHTTPEndpointRequest<[String : Any]>(method: .patch,
							path: "/v1/document/\(config.documentStorageID)/\(config.defaultDocumentType)/\(documentIDUse)/attachment/\(attachmentIDUse)",
							jsonBody: ["info": [String:Any]()] as [String : Any])

		let	(updateAttachmentInfo, updateAttachmentError) =
					DispatchQueue.performBlocking() { completionProc in
						// Queue
						config.httpEndpointClient.queue(httpEndpointRequest) { completionProc(($0, $1)) }
					}

		// Evaluate results
		XCTAssertNil(updateAttachmentInfo, "received info")

		XCTAssertNotNil(updateAttachmentError, "did not receive error")
		if updateAttachmentError != nil {
			switch updateAttachmentError! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Missing content", "did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(updateAttachmentError!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentRemoveInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.current
		let	documentStorageID = UUID().uuidString

		// Perform
		let	error =
					config.httpEndpointClient.documentAttachmentRemove(documentStorageID: documentStorageID,
							documentType: config.defaultDocumentType, documentID: "ABC", attachmentID: "ABC")

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
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
	func testAttachmentRemoveUnknownDocumentType() throws {
		// Setup
		let	config = Config.current
		let	documentType = UUID().uuidString

		// Perform
		let	error =
					config.httpEndpointClient.documentAttachmentRemove(documentStorageID: config.documentStorageID,
							documentType: documentType, documentID: "ABC", attachmentID: "ABC")

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown documentType: \(documentType)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func testAttachmentRemoveUnknownDocumentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString

		// Create Test document
		let	(_, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(createError, "create document received error: \(createError!)")
		guard createError == nil else { return }
		// Perform
		let	error =
					config.httpEndpointClient.documentAttachmentRemove(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID, attachmentID: "ABC")

		// Evaluate results
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
	func testAttachmentRemoveUnknownAttachmentID() throws {
		// Setup
		let	config = Config.current
		let	documentID = UUID().base64EncodedString
		let	attachmentID = UUID().base64EncodedString

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(documentID: documentID,
											propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Perform
		let	error =
					config.httpEndpointClient.documentAttachmentRemove(documentStorageID: config.documentStorageID,
							documentType: config.defaultDocumentType, documentID: documentID,
							attachmentID: attachmentID)

		// Evaluate results
		XCTAssertNotNil(error, "did not receive error")
		if error != nil {
			switch error! {
				case MDSError.invalidRequest(let message):
					// Expected error
					XCTAssertEqual(message, "Unknown attachmentID: \(attachmentID)",
							"did not receive expected error message")

				default:
					// Other error
					XCTFail("received unexpected error: \(error!)")
			}
		}
	}
}
