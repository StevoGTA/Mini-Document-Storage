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
//						let	httpEndpointClient =
//									HTTPEndpointClient(scheme: "https",
//											hostName: "g7j7adblvc.execute-api.us-east-1.amazonaws.com/dev")
						httpEndpointClient.logOptions = [.requestAndResponse]

						return httpEndpointClient
					}()
			let	documentStorageID = "Sandbox"
//			let	documentStorageID = "Testing"

			let	documentType = "test"
}
