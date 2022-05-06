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
		let	config = Config.shared
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

		// Retrieve documents (should be not up to date)
		let	(getDocumentsIsUpToDate1, getDocumentsInfo1, getDocumentsError1) =
					config.httpEndpointClient.collectionGetDocuments(documentStorageID: config.documentStorageID,
							name: collectionName)
		XCTAssertNotNil(getDocumentsIsUpToDate1, "get documents (1) did not return isUpToDate")
		if getDocumentsIsUpToDate1 != nil {
			XCTAssertFalse(getDocumentsIsUpToDate1!, "get documents (1) isUpToDate is not false")
		}
		XCTAssertNil(getDocumentsInfo1, "get documents (1) returned info")
		XCTAssertNil(getDocumentsError1, "get documents (1) received error \(getDocumentsError1!)")
		guard getDocumentsError1 == nil else { return }

		// Retrieve documents again
		let	(getDocumentsIsUpToDate2, getDocumentsInfo2, getDocumentsError2) =
					config.httpEndpointClient.collectionGetDocuments(documentStorageID: config.documentStorageID,
							name: collectionName)
		XCTAssertNotNil(getDocumentsIsUpToDate2, "get documents (2) did not return isUpToDate")
		if getDocumentsIsUpToDate2 != nil {
			XCTAssertTrue(getDocumentsIsUpToDate2!, "get documents (2) isUpToDate is not true")
		}
		XCTAssertNotNil(getDocumentsInfo2, "get documents (2) did not return info")
		let	getDocumentsDocumentIDs = Set<String>((getDocumentsInfo2?.documentFullInfos ?? []).map({ $0.documentID }))
		XCTAssertEqual(getDocumentsDocumentIDs, Set<String>([document2ID!]),
				"get documents (2) did not return expected document")
		XCTAssertNil(getDocumentsError2, "get documents (2) received error \(getDocumentsError2!)")
		guard getDocumentsError2 == nil else { return }
	}
}
