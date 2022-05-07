//
//  DocumentTransactionTests.swift
//  Transaction Tests
//
//  Created by Stevo on 3/30/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: DocumentTransactionTests
class DocumentTransactionTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testCreateRetrieveUpdate() throws {
		// Setup
		let	config = Config.shared

		var	documentID :String?
		var	revision :Int?
		var	creationDate :Date?
		var	modificationDate :Date?

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.documentType,
							documentCreateInfos:
									[MDSDocument.CreateInfo(propertyMap: ["key1": "value1", "key2": "value2"])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		if createDocumentInfos != nil {
			XCTAssertEqual(createDocumentInfos!.count, 1, "create did not receive 1 documentInfo")
			if let createDocumentInfo = createDocumentInfos!.first {
				XCTAssertNotNil(createDocumentInfo["documentID"], "create did not receive documentID")
				XCTAssert(createDocumentInfo["documentID"] is String, "create documentID is not a String")
				documentID = createDocumentInfo["documentID"] as? String

				XCTAssertNotNil(createDocumentInfo["revision"], "create did not receive revision")
				XCTAssert(createDocumentInfo["revision"] is Int, "create revision is not an Int")
				revision = createDocumentInfo["revision"] as? Int

				XCTAssertNotNil(createDocumentInfo["creationDate"], "create did not receive creationDate")
				XCTAssert(createDocumentInfo["creationDate"] is String, "create creationDate is not a String")
				if let string = createDocumentInfo["creationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string),
							"create creationDate could not be decoded to a Date")
					creationDate = Date(fromRFC3339Extended: string)
				}

				XCTAssertNotNil(createDocumentInfo["modificationDate"], "create did not receive modificationDate")
				XCTAssert(createDocumentInfo["modificationDate"] is String, "create modificationDate is not a String")
				if let string = createDocumentInfo["modificationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string),
							"create modificationDate could not be decoded to a Date")
					modificationDate = Date(fromRFC3339Extended: string)
				}
			}
		}
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Get document count
		let	(getDocumentCount, getDocumentCountError) =
					config.httpEndpointClient.documentGetCount(documentStorageID: config.documentStorageID,
							documentType: config.documentType)
		XCTAssertNotNil(getDocumentCount, "get document count did not receive count")
		if getDocumentCount != nil {
			XCTAssertGreaterThan(getDocumentCount!, 0, "get document count returned count of 0")
		}
		XCTAssertNil(getDocumentCountError, "get document count returned error: \(getDocumentCountError!)")

		// Get documents since revision 0
		let	(getSinceRevisionDocumentInfo, getSinceRevisionError) =
					config.httpEndpointClient.documentGet(documentStorageID: config.documentStorageID,
							documentType: config.documentType, sinceRevision: 0)
		XCTAssertNotNil(getSinceRevisionDocumentInfo, "get since revision did not receive info")
		if getSinceRevisionDocumentInfo != nil {
			XCTAssert(getSinceRevisionDocumentInfo!.documentFullInfos.count > 0,
					"get since revision did not receive any documentInfos")

			let	document =
						getSinceRevisionDocumentInfo!.documentFullInfos.first(where: { $0.documentID == documentID! })
			XCTAssertNotNil(document, "get since revision did not receive expected document")
		}
		XCTAssertNil(getSinceRevisionError, "get since revision received error \(getSinceRevisionError!)")

		// Update document
		let	(updateDocumentInfos, updateError) =
					config.httpEndpointClient.documentUpdate(documentStorageID: config.documentStorageID,
							documentType: config.documentType,
							documentUpdateInfos:
									[
										MDSDocument.UpdateInfo(documentID: documentID!, active: true,
												updated: ["key1": "value2"], removed: Set<String>(["key2"]))
									])
		XCTAssertNotNil(updateDocumentInfos, "update did not receive documentInfos")
		if updateDocumentInfos != nil {
			XCTAssertEqual(updateDocumentInfos!.count, 1, "update did not receive 1 documentInfo")
			if let updateDocumentInfo = updateDocumentInfos!.first {
				XCTAssertNotNil(updateDocumentInfo["documentID"], "update did not receive documentID")
				XCTAssert(updateDocumentInfo["documentID"] is String, "update documentID is not a String")
				if documentID != nil, let string = updateDocumentInfo["documentID"] as? String {
					XCTAssertEqual(documentID!, string, "update documentID doesn't match")
				}

				XCTAssertNotNil(updateDocumentInfo["revision"], "update did not receive revision")
				XCTAssert(updateDocumentInfo["revision"] is Int, "update revision is not an Int")
				if revision != nil, let value = updateDocumentInfo["revision"] as? Int {
					XCTAssertEqual(revision! + 1, value, "update revision not expected value")
				}

				XCTAssertNotNil(updateDocumentInfo["modificationDate"], "update did not receive modificationDate")
				XCTAssert(updateDocumentInfo["modificationDate"] is String, "update modificationDate is not a String")
				if let string = updateDocumentInfo["modificationDate"] as? String {
					XCTAssertNotNil(Date(fromRFC3339Extended: string),
							"update modificationDate could not be decoded to a Date")
					XCTAssertNotEqual(modificationDate, Date(fromRFC3339Extended: string),
							"update modificationDate did not change")
				}

				XCTAssertNotNil(updateDocumentInfo["json"], "update did not receive json")
				XCTAssert(updateDocumentInfo["json"] is [String : Any], "update json is not a PropertyMap")
				if let updatePropertyMap = updateDocumentInfo["json"] as? [String : Any] {
					XCTAssertNotNil(updatePropertyMap["key1"], "update property map does not have key1")
					XCTAssert(updatePropertyMap["key1"] is String, "update property map key1 is not a String")
					if let string = updatePropertyMap["key1"] as? String {
						XCTAssertEqual(string, "value2", "update property map key1 is not value2")
					}

					XCTAssertNil(updatePropertyMap["key2"], "update property map has key2")
				}
			}
		}
		XCTAssertNil(updateError, "update received error \(updateError!)")

		// Get documents by ID
		let	(getDocumentIDsDocumentInfos, getDocumentIDsError) =
					config.httpEndpointClient.documentGet(documentStorageID: config.documentStorageID,
							documentType: config.documentType, documentIDs: [documentID!])
		XCTAssertNotNil(getDocumentIDsDocumentInfos, "get documents by ID did not receive documentInfos")
		if getDocumentIDsDocumentInfos != nil {
			XCTAssertEqual(getDocumentIDsDocumentInfos!.count, 1, "get documents by ID did not receive 1 documentInfos")
			if let getDocumentByIDDocumentInfo = getDocumentIDsDocumentInfos!.first {
				XCTAssertNotNil(getDocumentByIDDocumentInfo["documentID"],
						"get documents by ID did not receive documentID")
				XCTAssert(getDocumentByIDDocumentInfo["documentID"] is String,
						"get documents by ID documentID is not a String")
				if documentID != nil, let string = getDocumentByIDDocumentInfo["documentID"] as? String {
					XCTAssertEqual(documentID, string, "get documents by ID documentID doesn't match")
				}

				XCTAssertNotNil(getDocumentByIDDocumentInfo["revision"], "get documents by ID did not receive revision")
				XCTAssert(getDocumentByIDDocumentInfo["revision"] is Int, "get documents by ID revision is not an Int")
				if revision != nil, let value = getDocumentByIDDocumentInfo["revision"] as? Int {
					XCTAssertEqual(revision! + 1, value, "get documents by ID revision not expected value")
				}

				XCTAssertNotNil(getDocumentByIDDocumentInfo["creationDate"],
						"get documents by ID did not receive creationDate")
				XCTAssert(getDocumentByIDDocumentInfo["creationDate"] is String,
						"get documents by ID creationDate is not a String")
				XCTAssertNotNil(Date(fromRFC3339Extended: getDocumentByIDDocumentInfo["creationDate"] as? String),
						"get documents by ID creationDate could not be decoded to a Date")
				if creationDate != nil, let string = getDocumentByIDDocumentInfo["creationDate"] as? String {
					XCTAssertEqual(creationDate!, Date(fromRFC3339Extended: string)!,
							"get documents by ID creationDate changed")
				}

				XCTAssertNotNil(getDocumentByIDDocumentInfo["modificationDate"],
						"get documents by ID did not receive modificationDate")
				XCTAssert(getDocumentByIDDocumentInfo["modificationDate"] is String,
						"get documents by ID modificationDate is not a String")
				XCTAssertNotNil(Date(fromRFC3339Extended: getDocumentByIDDocumentInfo["modificationDate"] as? String),
						"get documents by ID modificationDate could not be decoded to a Date")
				if modificationDate != nil, let string = getDocumentByIDDocumentInfo["modificationDate"] as? String {
					XCTAssertNotEqual(modificationDate, Date(fromRFC3339Extended: string),
							"get documents by ID modificationDate did not change")
				}
			}
		}
		XCTAssertNil(getDocumentIDsError, "get documents by ID received error \(getDocumentIDsError!)")
	}

	//------------------------------------------------------------------------------------------------------------------
	func testCreateRetrieveUpdateRemoveAttachment() throws {
		// Setup
		let	config = Config.shared

		var	documentID :String?
		var	attachmentID :String?

		// Create document
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: config.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		if createDocumentInfos != nil {
			XCTAssertEqual(createDocumentInfos!.count, 1, "create did not receive 1 documentInfo")
			if let createDocumentInfo = createDocumentInfos!.first {
				XCTAssertNotNil(createDocumentInfo["documentID"], "create did not receive documentID")
				XCTAssert(createDocumentInfo["documentID"] is String, "create documentID is not a String")
				documentID = createDocumentInfo["documentID"] as? String
			}
		}
		XCTAssertNil(createError, "create received error \(createError!)")

		// Ensure we have a document ID
		guard documentID != nil else { return }

		// Add attachment
		let	(addAttachmentInfo, addAttachmentError) =
					config.httpEndpointClient.documentAddAttachment(documentStorageID: config.documentStorageID,
							documentType: config.documentType, documentID: documentID!,
							info: ["key1": "value1"], content: "content1".data(using: .utf8)!)
		XCTAssertNotNil(addAttachmentInfo, "add attachment did not receive info")
		if addAttachmentInfo != nil {
			XCTAssertNotNil(addAttachmentInfo!["id"], "add attachment did not receive attachmentID")
			XCTAssert(addAttachmentInfo!["id"] is String, "add attachment attachmentID is not a String")
			attachmentID = addAttachmentInfo!["id"] as? String
		}
		XCTAssertNil(addAttachmentError, "add attachment received error \(addAttachmentError!)")

		// Ensure we have an attachment ID
		guard attachmentID != nil else { return }

		// Update attachment
		let	updateAttachmentError =
					config.httpEndpointClient.documentUpdateAttachment(documentStorageID: config.documentStorageID,
							documentType: config.documentType, documentID: documentID!, attachmentID: attachmentID!,
							info: ["key2": "value2"], content: "content2".data(using: .utf8)!)
		XCTAssertNil(updateAttachmentError, "update attachment received error \(updateAttachmentError!)")

		// Get attachment
		let	(getAttachmentContent, getAttachmentError) =
					config.httpEndpointClient.documentGetAttachment(documentStorageID: config.documentStorageID,
							documentType: config.documentType, documentID: documentID!, attachmentID: attachmentID!)
		XCTAssertNotNil(getAttachmentContent, "get attachment did not receive content")
		if getAttachmentContent != nil {
			XCTAssertNotNil(String(data: getAttachmentContent!, encoding: .utf8),
					"get attachment could not convert content to String")
			if let string = String(data: getAttachmentContent!, encoding: .utf8) {
				XCTAssertEqual(string, "content2", "get attachment unexpected content value: \(string)")
			}
		}
		XCTAssertNil(getAttachmentError, "get attachment received error \(getAttachmentError!)")

		// Remove attachment
		let	removeAttachmentError =
					config.httpEndpointClient.documentRemoveAttachment(documentStorageID: config.documentStorageID,
							documentType: config.documentType, documentID: documentID!, attachmentID: attachmentID!)
		XCTAssertNil(removeAttachmentError, "remove attachment received error \(removeAttachmentError!)")
	}
}
