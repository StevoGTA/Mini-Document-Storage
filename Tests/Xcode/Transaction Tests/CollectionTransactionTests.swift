//
//  CollectionTransactionTests.swift
//  Transaction Tests
//
//  Created by Stevo on 4/26/22.
//

import XCTest

//----------------------------------------------------------------------------------------------------------------------
// MARK: CollectionTransactionTests
class CollectionTransactionTests : XCTestCase {

	// MARK: Test methods
	//------------------------------------------------------------------------------------------------------------------
	func testRegisterUpdateRetrieveRevisionInfo() throws {
		// Setup
		let	collectionName = UUID().uuidString
		let	config = Config.current
		let	property1 = UUID().base64EncodedString
		let	property2 = UUID().base64EncodedString

		// Register
		let	registerError1 =
					config.httpEndpointClient.collectionRegister(documentStorageID: config.documentStorageID,
							name: collectionName, documentType: Child.documentType,
							relevantProperties: [property1], isUpToDate: true,
							isIncludedSelector: "documentPropertyIsValue()",
							isIncludedSelectorInfo: ["property": property1, "value": "111"])
		XCTAssertNil(registerError1, "register (1) received error \(registerError1!)")
		guard registerError1 == nil else { return }

		// Create documents
		let	(createDocumentInfos, createError) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: Child.documentType,
							documentCreateInfos:
									[
										MDSDocument.CreateInfo(propertyMap: [property1: "111"]),
										MDSDocument.CreateInfo(propertyMap: [property1: "111", property2: "222"]),
									])
		XCTAssertNotNil(createDocumentInfos, "create did not receive documentInfos")
		let	document1ID = createDocumentInfos?[0]["documentID"] as? String
		let	document2ID = createDocumentInfos?[1]["documentID"] as? String
		XCTAssertNil(createError, "create received error \(createError!)")
		guard createError == nil else { return }

		// Retrieve documents
		let	(getDocumentInfosIsUpToDate, getDocumentInfosInfo, getDocumentInfosError) =
					config.httpEndpointClient.collectionGetDocumentInfos(documentStorageID: config.documentStorageID,
							name: collectionName)
		XCTAssertNotNil(getDocumentInfosIsUpToDate, "get document infos did not return isUpToDate")
		if getDocumentInfosIsUpToDate != nil {
			XCTAssertTrue(getDocumentInfosIsUpToDate!, "get document infos isUpToDate is not true")
		}
		XCTAssertNotNil(getDocumentInfosInfo, "get document infos did not return info")
		let	getDocumentInfosDocumentIDs =
					Set<String>((getDocumentInfosInfo?.documentRevisionInfos ?? []).map({ $0.documentID }))
		XCTAssertEqual(getDocumentInfosDocumentIDs, Set<String>([document1ID!, document2ID!]),
				"get document infos did not return both documents")
		XCTAssertNil(getDocumentInfosError, "get document infos received error \(getDocumentInfosError!)")
		guard getDocumentInfosError == nil else { return }

		// Update
		let	registerError2 =
					config.httpEndpointClient.collectionRegister(documentStorageID: config.documentStorageID,
							name: collectionName, documentType: Child.documentType, relevantProperties: [property2],
							isIncludedSelector: "documentPropertyIsValue()",
							isIncludedSelectorInfo: ["property": property2, "value": "222"])
		XCTAssertNil(registerError2, "register (2) received error \(registerError2!)")
		guard registerError2 == nil else { return }

		// Retrieve documents (may not be up to date - depends on server implementation)
		var	(getDocumentsIsUpToDate, getDocumentsInfo, getDocumentsError) =
					config.httpEndpointClient.collectionGetDocuments(documentStorageID: config.documentStorageID,
							name: collectionName)
		while (getDocumentsIsUpToDate != nil) && !getDocumentsIsUpToDate! {
			// Try again
			(getDocumentsIsUpToDate, getDocumentsInfo, getDocumentsError) =
					config.httpEndpointClient.collectionGetDocuments(documentStorageID: config.documentStorageID,
							name: collectionName)
		}
		XCTAssertNotNil(getDocumentsInfo, "get documents did not return info")
		let	getDocumentsDocumentIDs =
					Set<String>((getDocumentsInfo?.documentFullInfos ?? []).map({ $0.documentID }))
		XCTAssertEqual(getDocumentsDocumentIDs, Set<String>([document2ID!]),
				"get documents did not return expected document")
		XCTAssertNil(getDocumentsError, "get documents received error \(getDocumentsError!)")
	}
}
