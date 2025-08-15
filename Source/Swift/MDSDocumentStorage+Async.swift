//
//  MDSDocumentStorage+Async.swift
//  Mini Document Storage
//
//  Created by Stevo on 8/14/25.
//  Copyright © 2018 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorage extension
public extension MDSDocumentStorage {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func associationDocuments(for name :String, from fromDocumentID :String, toDocumentType :String) throws ->
			AsyncStream<MDSDocument> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate association
				try associationIterate(for: name, from: fromDocumentID, toDocumentType: toDocumentType)
						{ continuation.yield($0) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationDocuments(for name :String, fromDocumentType :String, to toDocumentID :String) throws ->
			AsyncStream<MDSDocument> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate association
				try associationIterate(for: name, fromDocumentType: fromDocumentType, to: toDocumentID)
						{ continuation.yield($0) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationDocuments<T : MDSDocument, U : MDSDocument>(from document :T) throws -> AsyncStream<U> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate association
				try associationIterate(from: document) { continuation.yield($0 as! U) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationDocuments<T : MDSDocument, U : MDSDocument>(to document :U) throws -> AsyncStream<T> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate association
				try associationIterate(to: document) { continuation.yield($0 as! T) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionDocuments(name :String, documentType :String) throws -> AsyncStream<MDSDocument> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate collection
				try collectionIterate(name: name, documentType: documentType) { continuation.yield($0) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionDocuments(name :String) throws -> AsyncStream<MDSDocument> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate collection
				try collectionIterate(name: name) { continuation.yield($0) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documents(for documentType :String, documentIDs :[String],
			documentCreateProc :@escaping MDSDocument.CreateProc) throws -> AsyncStream<MDSDocument> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate documents
				try documentIterate(for: documentType, documentIDs: documentIDs, documentCreateProc: documentCreateProc)
						{ continuation.yield($0) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documents(for documentIDs :[String]) throws -> AsyncStream<MDSDocument> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate documents
				try documentIterate(for: documentIDs) { continuation.yield($0) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documents(for documentType :String, activeOnly: Bool, documentCreateProc :@escaping MDSDocument.CreateProc)
			throws -> AsyncStream<MDSDocument> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate documents
				try documentIterate(for: documentType, activeOnly: activeOnly, documentCreateProc: documentCreateProc)
						{ continuation.yield($0) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documents(activeOnly: Bool) throws -> AsyncStream<MDSDocument> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate documents
				try documentIterate(activeOnly: activeOnly) { continuation.yield($0) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexDocuments(name :String, documentType :String, keys :[String]) throws ->
			AsyncStream<(String, MDSDocument)> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate index
				try indexIterate(name: name, documentType: documentType, keys: keys)
						{ continuation.yield(($0, $1)) }

				// Done
				continuation.finish()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexDocuments(name :String, keys :[String]) throws -> AsyncStream<(String, MDSDocument)> {
		// Return stream
		return AsyncStream() { continuation in
			// Start task
			Task {
				// Iterate index
				try indexIterate(name: name, keys: keys) { continuation.yield(($0, $1)) }

				// Done
				continuation.finish()
			}
		}
	}
}
