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
						// JS testing when running server in VS Code
//						let	httpEndpointClient =
//									HTTPEndpointClient(scheme: "http", hostName: "localhost", port: 1138,
//											options: [.percentEncodePlusCharacter])

						// Swift testing when running server in Xcode project
						let	httpEndpointClient = HTTPEndpointClient(scheme: "http", hostName: "localhost", port: 34343)

						// Finish setup
						httpEndpointClient.logOptions = [.requestAndResponse]

						return httpEndpointClient
					}()
			let	documentStorageID = "Sandbox"

			let	documentType = "test"
}
