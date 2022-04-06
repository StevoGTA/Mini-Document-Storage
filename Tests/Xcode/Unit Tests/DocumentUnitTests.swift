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
	func testDocumentCreateFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: "ABC",
							documentType: config.documentType, documentCreateInfos:[])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNil(documentInfos, "did not receive documentInfos")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentCreate0() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.documentType, documentCreateInfos:[])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNil(documentInfos, "did not receive documentInfos")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentCreate1() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.documentType,
							documentCreateInfos:[MDSDocument.CreateInfo(propertyMap: ["key": "value"])])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 200, "unexpected response status")
		}

		XCTAssertNotNil(documentInfos, "did not receive documentInfos")
		if documentInfos != nil {
			XCTAssertEqual(documentInfos!.count, 1, "did not receive 1 documentInfo")
			if let documentInfo = documentInfos!.first {
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
	func testDocumentGetSinceRevisionFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentGet(documentStorageID: "ABC", documentType: config.documentType,
							sinceRevision: 0)

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNil(documentInfos, "did not receive documentInfos")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentGetSinceRevisionFailInvalidDocumentType() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentGet(documentStorageID: config.documentStorageID,
							documentType: "ABC", sinceRevision: 0)

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 200, "unexpected response status")
		}

		XCTAssertNotNil(documentInfos, "did not receive documentInfos")

		XCTAssertNil(error, "received error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentGetIDsFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentGet(documentStorageID: "ABC",
							documentType: config.documentType, documentIDs: ["ABC"])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentGetIDsFailInvalidDocumentType() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentGet(documentStorageID: config.documentStorageID,
							documentType: "ABC", documentIDs: ["ABC"])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentGetIDsFailNoIDs() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentGet(documentStorageID: config.documentStorageID,
							documentType: config.documentType, documentIDs: [])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentUpdateFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentUpdate(documentStorageID: "ABC", documentType: "ABC",
							documentUpdateInfos:
									[
										MDSDocument.UpdateInfo(documentID: "ABC", active: true, updated: [:],
												removed: Set<String>())
									])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNil(documentInfos, "did not receive documentInfos")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentUpdateFailInvalidDocumentType() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, documentInfos, error) =
					config.httpEndpointClient.documentUpdate(documentStorageID: config.documentStorageID,
							documentType: "ABC", documentUpdateInfos: [])

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNil(documentInfos, "received documentInfos")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentAddAttachmentFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, info, error) =
					config.httpEndpointClient.documentAddAttachment(documentStorageID: "ABC",
							documentType: config.documentType, documentID: "ABC", info: [:], content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(info, "did not receive info")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentAddAttachmentFailInvalidDocumentType() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, info, error) =
					config.httpEndpointClient.documentAddAttachment(documentStorageID: config.documentStorageID,
							documentType: "ABC", documentID: "ABC", info: [:], content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(info, "did not receive info")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentGetAttachmentFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, content, error) =
					config.httpEndpointClient.documentGetAttachment(documentStorageID: "ABC",
							documentType: config.documentType, documentID: "ABC", attachmentID: "ABC")

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(content, "did not receive content")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentGetAttachmentFailInvalidDocumentType() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, content, error) =
					config.httpEndpointClient.documentGetAttachment(documentStorageID: config.documentStorageID,
							documentType: "ABC", documentID: "ABC", attachmentID: "ABC")

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(content, "did not receive content")

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentUpdateAttachmentFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, error) =
					config.httpEndpointClient.documentUpdateAttachment(documentStorageID: "ABC",
							documentType: config.documentType, documentID: "ABC", attachmentID: "ABC", info: [:],
							content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentUpdateAttachmentFailInvalidDocumentType() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, error) =
					config.httpEndpointClient.documentUpdateAttachment(documentStorageID: config.documentStorageID,
							documentType: "ABC", documentID: "ABC", attachmentID: "ABC", info: [:],
							content: Data(capacity: 0))

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentRemoveAttachmentFailInvalidDocumentStorageID() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, error) =
					config.httpEndpointClient.documentRemoveAttachment(documentStorageID: "ABC",
							documentType: config.documentType, documentID: "ABC", attachmentID: "ABC")

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(error, "did not receive error")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testDocumentRemoveAttachmentFailInvalidDocumentType() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(response, error) =
					config.httpEndpointClient.documentRemoveAttachment(documentStorageID: config.documentStorageID,
							documentType: "ABC", documentID: "ABC", attachmentID: "ABC")

		// Evaluate results
		XCTAssertNotNil(response, "did not receive response")
		if response != nil {
			XCTAssertEqual(response!.statusCode, 400, "unexpected response status")
		}

		XCTAssertNotNil(error, "did not receive error")
	}
}
