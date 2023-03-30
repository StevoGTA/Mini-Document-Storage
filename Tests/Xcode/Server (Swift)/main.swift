//
//  main.swift
//  Server (Swift)
//
//  Created by Stevo on 8/30/22.
//

import ArgumentParser
import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: Server
struct Server : ParsableCommand {

	// MARK: Configuration
	static	var	configuration =
						CommandConfiguration(commandName: "server",
								abstract: "Server for Mini Documnet Storage.  Copyright © 2022, Stevo Brock",
								version: "1.0")

	// MARK: Arguments
	// Document Storage
	enum DocumentStorage :String, ExpressibleByArgument {
		case swiftEphemeral
		case swiftSQLite
	}
    @Option
    var	documentStorage :DocumentStorage

	// MARK: Instance Methods
	//--------------------------------------------------------------------------------------------------------------
	func run() {
		// Setup HTTP Server
		let	httpServer = VaporHTTPServer(port: 34343, maxBodySize: 1_000_000_000)

		// Setup MDS
		httpServer.setupMDSEndpoints()
		switch self.documentStorage {
			case .swiftEphemeral:
				// Swift Ephemeral
				let	documentStorage = MDSEphemeral()

				MDSHTTPServices.register(documentStorage: documentStorage, for: "Sandbox")

			case .swiftSQLite:
				// Swift SQLite
				let	libraryFolder = FileManager.default.folder(for: .libraryDirectory)
				let	applicationFolder = libraryFolder.folder(withSubPath: "Mini Document Storage Test Server (Swift)")
				try! FileManager.default.create(applicationFolder)

				let	documentStorage = try! MDSSQLite(in: applicationFolder)

				MDSHTTPServices.register(documentStorage: documentStorage, for: "Sandbox")
		}

		// Log
		print("Server listening on port 34343")

		// Loop forever
		dispatchMain()
	}
}
Server.main()
