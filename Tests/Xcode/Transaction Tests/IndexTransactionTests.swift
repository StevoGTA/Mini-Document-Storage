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
		let	config = Config.shared
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
							isUpToDate: true, keysSelector: "keysForDocumentProperty()",
							keysSelectorInfo: ["property": property1])
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

		// Retrieve documents
		let	(getDocumentInfosIsUpToDate, getDocumentInfosMap, getDocumentInfosError) =
					config.httpEndpointClient.indexGetDocumentInfo(documentStorageID: config.documentStorageID,
							name: indexName, keys: ["abc", "def"])
		XCTAssertNotNil(getDocumentInfosIsUpToDate, "get document infos did not return isUpToDate")
		if getDocumentInfosIsUpToDate != nil {
			XCTAssertTrue(getDocumentInfosIsUpToDate!, "get document infos isUpToDate is not true")
		}
		XCTAssertNotNil(getDocumentInfosMap, "get document infos did not return info map")
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
		let	(getDocumentsIsUpToDate1, getDocumentsMap1, getDocumentsError1) =
					config.httpEndpointClient.indexGetDocument(documentStorageID: config.documentStorageID,
							name: indexName, keys: ["123", "456"])
		XCTAssertNotNil(getDocumentsIsUpToDate1, "get documents (1) did not return isUpToDate")
		if getDocumentsIsUpToDate1 != nil {
			// Check if up to date
			if getDocumentsIsUpToDate1! {
				// Index is up to date
				XCTAssertNotNil(getDocumentsMap1, "get documents (1) did not return info")
				let	getDocumentsDocumentIDs = Set<String>(getDocumentsMap1?.values.map({ $0.documentID }) ?? [])
				XCTAssertEqual(getDocumentsDocumentIDs, Set<String>([document1ID!, document2ID!]),
						"get documents (1) did not return both documents")
				XCTAssertNil(getDocumentsError1, "get documents (1) returned error: \(getDocumentsError1!)")
				guard getDocumentsError1 == nil else { return }
			} else {
				// Index is not up to date
				XCTAssertNil(getDocumentsMap1, "get documents (1) returned info")
				XCTAssertNil(getDocumentsError1, "get documents (1) returned error: \(getDocumentsError1!)")
				guard getDocumentsError1 == nil else { return }

				// Retrieve documents again
				let	(getDocumentsIsUpToDate2, getDocumentsMap2, getDocumentsError2) =
							config.httpEndpointClient.indexGetDocument(documentStorageID: config.documentStorageID,
									name: indexName, keys: ["123", "456"])
				XCTAssertNotNil(getDocumentsIsUpToDate2, "get documents (2) did not return isUpToDate")
				if getDocumentsIsUpToDate2 != nil {
					XCTAssertTrue(getDocumentsIsUpToDate2!, "get documents (2) isUpToDate is not true")
				}
				XCTAssertNotNil(getDocumentsMap2, "get documents (2) did not return info")
				let	getDocumentsDocumentIDs = Set<String>(getDocumentsMap2?.values.map({ $0.documentID }) ?? [])
				XCTAssertEqual(getDocumentsDocumentIDs, Set<String>([document1ID!, document2ID!]),
						"get documents (2) did not return both documents")
				XCTAssertNil(getDocumentsError2, "get documents (2) returned error: \(getDocumentsError2!)")
				guard getDocumentsError2 == nil else { return }
			}
		}
	}
}
