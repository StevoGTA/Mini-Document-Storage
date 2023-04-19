//
//  Config.swift
//  Common
//
//  Created by Stevo on 2/22/22.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: Config
class Config {

	// MARK: Properties
	static	let	current = server

	// Server testing when running external server
	static	let	server =
						Config(
								httpEndpointClient:
										HTTPEndpointClient(scheme: "http", hostName: "localhost", port: 1138,
												options: [.percentEncodePlusCharacter]),
								documentStorageID: "Sandbox", defaultDocumentType: "test",
								supportsLongDocumentIDs: false)

	// Local testing when running server in Xcode project
	static	let	local =
						Config(
								httpEndpointClient:
										HTTPEndpointClient(scheme: "http", hostName: "localhost", port: 34343),
								documentStorageID: "Sandbox", defaultDocumentType: "test",
								supportsLongDocumentIDs: true)

			let	httpEndpointClient :HTTPEndpointClient
			let	documentStorageID :String
			let	defaultDocumentType :String
			let	supportsLongDocumentIDs :Bool

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(httpEndpointClient :HTTPEndpointClient, documentStorageID :String, defaultDocumentType :String,
			supportsLongDocumentIDs :Bool) {
		// Store
		self.httpEndpointClient = httpEndpointClient
		self.httpEndpointClient.logOptions = [.requestAndResponse]

		self.documentStorageID = documentStorageID
		self.defaultDocumentType = defaultDocumentType
		self.supportsLongDocumentIDs = supportsLongDocumentIDs
	}
}
