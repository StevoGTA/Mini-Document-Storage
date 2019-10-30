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
	func newDocument<T : MDSDocument>(documentType :String, creationProc :MDSDocument.CreationProc) -> T

	func document<T : MDSDocument>(for documentID :String, documentType :String, creationProc :MDSDocument.CreationProc)
			-> T?

	func value(for key :String, documentID :String, documentType :String) -> Any?
	func set(_ value :Any?, for key :String, documentID :String, documentType :String)

	func date(for value :Any?) -> Date?
	func value(for date :Date?) -> Any?

	func remove(documentID :String, documentType :String)

	func enumerate<T : MDSDocument>(documentType :String, proc :MDSDocument.ApplyProc<T>,
			creationProc :MDSDocument.CreationProc)

	func batch(_ proc :() -> MDSBatchResult)
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MiniDocumentStorage extension
extension MiniDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func newDocument<T : MDSDocument>(creationProc :MDSDocument.CreationProc) -> T {
		// Use default creation proc
		return newDocument(documentType: T.documentType, creationProc: creationProc)
	}

	//------------------------------------------------------------------------------------------------------------------
	func newDocument<T : MDSDocument>() -> T {
		// Use default creation proc
		return newDocument(documentType: T.documentType) { return T(id: $0, miniDocumentStorage: $1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func document<T : MDSDocument>(for documentID :String) -> T? {
		// Use default creation proc
		return document(for: documentID, documentType: T.documentType) { return T(id: $0, miniDocumentStorage: $1) }
	}

	//------------------------------------------------------------------------------------------------------------------
	func documents<T :MDSDocument>(for documentType :String, creationProc :MDSDocument.CreationProc) -> [T] {
		// Setup
		var	documents = [T]()

		// Enumerate all documents
		enumerate(documentType: documentType, proc: { documents.append($0 as! T) }, creationProc: creationProc)

		return documents
	}

	//------------------------------------------------------------------------------------------------------------------
	func enumerate<T : MDSDocument>(_ proc :(_ mdsDocument :T) -> Void) {
		// Use default creation proc
		return enumerate(documentType: T.documentType, proc: proc) { return T(id: $0, miniDocumentStorage: $1) }
	}
}
