//
//  MiniDocumentStorage.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/18.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSBatchResult
enum MDSBatchResult {
	case commit
	case cancel
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MiniDocumentStorage protocol
protocol MiniDocumentStorage : class {

	// MARK: Instance methods
	func newDocument<T : MDSDocument>(_ creationProc :MDSDocument.CreationProc) -> T
	func enumerate<T : MDSDocument>(_ proc :MDSDocument.ApplyProc<T>, _ creationProc :MDSDocument.CreationProc)

	func batch(_ proc :() -> MDSBatchResult)

	func value(for key :String, documentType :String, documentID :String) -> Any?
	func set(_ value :Any?, for key :String, documentType :String, documentID :String)

	func date(for value :Any?) -> Date?
	func value(for date :Date?) -> Any?

	func remove(documentType :String, documentID :String)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MiniDocumentStorage extension
extension MiniDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func newDocument<T : MDSDocument>() -> T {
		// Use default creation proc
		return newDocument() { return T(id: $0, miniDocumentStorage: $1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(_ proc :(_ mdsDocument :T) -> Void) {
		// Use default creation proc
		return enumerate(proc) { return T(id: $0, miniDocumentStorage: $1) }
	}
}
