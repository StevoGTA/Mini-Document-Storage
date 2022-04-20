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
	static	let	shared = Config()

			let	httpEndpointClient :HTTPEndpointClient = {
						// Setup
						let	httpEndpointClient = HTTPEndpointClient(scheme: "http", hostName: "localhost", port: 1138)
						httpEndpointClient.logOptions = [.requestAndResponse]

						return httpEndpointClient
					}()
			let	documentStorageID = "Sandbox"

			let	documentType = "test"
			let	parentDocumentType = "parent"
			let	childDocumentType = "child"
}
