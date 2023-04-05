//
//  IndexTransactionTests.swift
//  Transaction Tests
//
//  Created by Stevo on 4/26/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: IndexTransactionTests
class IndexTransactionTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testRegisterUpdateRetrieveRevisionInfo() throws {
		// Setup
		let	indexName = UUID().uuidString
		let	config = Config.current
		let	property1 = UUID().base64EncodedString
		let	property2 = UUID().base64EncodedString

		// Create document
		let	(_, childCreateError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos: [MDSDocument.CreateInfo(propertyMap: [:])])
		XCTAssertNil(childCreateError, "create child document received error: \(childCreateError!)")

		// Register
		let	registerError1 =
					config.httpEndpointClient.indexRegister(documentStorageID: config.documentStorageID,
							name: indexName, documentType: Child.documentType, relevantProperties: [property1],
							keysSelector: "keysForDocumentProperty()", keysSelectorInfo: ["property": property1])
		XCTAssertNil(registerError1, "register (1) received error \(registerError1!)")
		guard registerError1 == nil else { return }

		// Create documents
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos:
									[
										MDSDocument.CreateInfo(propertyMap: [property1: "abc", property2: "123"]),
										MDSDocument.CreateInfo(propertyMap: [property1: "def", property2: "456"]),
									])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		let	document1ID = createDocumentInfos?[0]["documentID"] as? String
		let	document2ID = createDocumentInfos?[1]["documentID"] as? String
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Retrieve documents (may not be up to date - depends on server implementation)
		var	(getDocumentInfosIsUpToDate, getDocumentInfosMap, getDocumentInfosError) =
					config.httpEndpointClient.indexGetDocumentInfos(documentStorageID: config.documentStorageID,
							name: indexName, keys: ["abc", "def"])
		while (getDocumentInfosIsUpToDate != nil) && !getDocumentInfosIsUpToDate! {
			// Try again
			(getDocumentInfosIsUpToDate, getDocumentInfosMap, getDocumentInfosError) =
					config.httpEndpointClient.indexGetDocumentInfos(documentStorageID: config.documentStorageID,
							name: indexName, keys: ["abc", "def"])
		}
		XCTAssertNotNil(getDocumentInfosIsUpToDate, "get document infos did not return isUpToDate")
		guard getDocumentInfosIsUpToDate != nil else { return }
		XCTAssertTrue(getDocumentInfosIsUpToDate!, "get document infos isUpToDate is not true")
		guard getDocumentInfosIsUpToDate! else { return }
		XCTAssertNotNil(getDocumentInfosMap, "get document infos did not return info map")
		guard getDocumentInfosMap != nil else { return }
		let	getDocumentInfosDocumentIDs = Set<String>(getDocumentInfosMap?.values.map({ $0.documentID }) ?? [])
		XCTAssertEqual(getDocumentInfosDocumentIDs, Set<String>([document1ID!, document2ID!]),
				"get document infos did not return both documents")
		XCTAssertNil(getDocumentInfosError, "get document infos returned error: \(getDocumentInfosError!)")
		guard getDocumentInfosError == nil else { return }

		// Update
		let	registerError2 =
					config.httpEndpointClient.indexRegister(documentStorageID: config.documentStorageID,
							name: indexName, documentType: Child.documentType, relevantProperties: [property2],
							keysSelector: "keysForDocumentProperty()", keysSelectorInfo: ["property": property2])
		XCTAssertNil(registerError2, "register (2) received error \(registerError2!)")
		guard registerError2 == nil else { return }

		// Retrieve documents (may not be up to date - depends on server implementation)
		var	(getDocumentsIsUpToDate, getDocumentsMap, getDocumentsError) =
					config.httpEndpointClient.indexGetDocuments(documentStorageID: config.documentStorageID,
							name: indexName, keys: ["123", "456"])
		while (getDocumentsIsUpToDate != nil) && !getDocumentsIsUpToDate! {
			// Try again
			(getDocumentsIsUpToDate, getDocumentsMap, getDocumentsError) =
					config.httpEndpointClient.indexGetDocuments(documentStorageID: config.documentStorageID,
							name: indexName, keys: ["123", "456"])
		}
		XCTAssertNotNil(getDocumentsMap, "get documents (1) did not return info")
		let	getDocumentsDocumentIDs = Set<String>(getDocumentsMap?.values.map({ $0.documentID }) ?? [])
		XCTAssertEqual(getDocumentsDocumentIDs, Set<String>([document1ID!, document2ID!]),
				"get documents (1) did not return both documents")
		XCTAssertNil(getDocumentsError, "get documents (1) returned error: \(getDocumentsError!)")
	}
}
