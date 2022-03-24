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
	func testDocumentCreate() throws {
		// Setup
		let	config = Config.shared

		// Perform
		let	(_, documentInfos, error) =
					config.httpEndpointClient.documentCreate(documentStorageID: config.documentStorageID,
							documentType: "test",
							documentCreateInfos:[MDSDocument.CreateInfo(propertyMap: ["key": "value"])])

		// Handle results
		if documentInfos != nil {
			// Success
			XCTAssert(documentInfos!.count == 1)
			let	documentInfo = documentInfos!.first!

			XCTAssert(documentInfo["documentID"] != nil)
			XCTAssert(documentInfo["documentID"] is String)

			XCTAssert(documentInfo["revision"] != nil)
			XCTAssert(documentInfo["revision"] is Int)

			XCTAssert(documentInfo["creationDate"] != nil)
			XCTAssert(documentInfo["creationDate"] is String)
			XCTAssert(Date(fromRFC3339Extended: documentInfo["creationDate"] as? String) != nil)

			XCTAssert(documentInfo["modificationDate"] != nil)
			XCTAssert(documentInfo["modificationDate"] is String)
			XCTAssert(Date(fromRFC3339Extended: documentInfo["modificationDate"] as? String) != nil)
		} else {
			// Error
			XCTFail("\(error!)")
		}
	}
}
