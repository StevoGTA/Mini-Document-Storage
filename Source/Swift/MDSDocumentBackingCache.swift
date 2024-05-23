//
//  MDSDocumentBackingCache.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentBackingCache
class MDSDocumentBackingCache<T : MDSDocumentBacking> {

	// MARK: Reference
	private class Reference {

		// MARK: Properties
		let	documentBacking :T

		var	lastReferencedDate :Date

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(documentBacking :T) {
			// Store
			self.documentBacking = documentBacking

			// Setup
			self.lastReferencedDate = Date()
		}

		// MARK: Instance methods
		//--------------------------------------------------------------------------------------------------------------
		func noteWasReferenced() { self.lastReferencedDate = Date() }
	}

	// MARK: Properties
	private	let	limit :Int
	private	let	lock = ReadPreferringReadWriteLock()

	private	var	referenceByDocumentID = [/* Document ID */ String : Reference]()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(limit :Int = 1_000_000) {
		// Store
		self.limit = limit
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func add(_ documentBackings :[T]) {
		// Update
		self.lock.write() {
			// Do all document backing infos
			documentBackings.forEach() { self.referenceByDocumentID[$0.documentID] = Reference(documentBacking: $0) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentBacking(for documentID :String) -> T? {
		// Return cached document, if available
		return self.lock.read() {
			// Retrieve
			if let reference = self.referenceByDocumentID[documentID] {
				// Note was referenced
				reference.noteWasReferenced()

				return reference.documentBacking
			} else {
				// Not found
				return nil
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func queryDocumentIDs(_ documentIDs :[String]) -> (foundDocumentIDs :[String], notFoundDocumentIDs :[String]) {
		// Setup
		var	foundDocumentIDs = [String]()
		var	notFoundDocumentIDs = [String]()

		// Iterate document IDs
		self.lock.read() { documentIDs.forEach() {
			// Look up reference for this document ID
			if let reference = self.referenceByDocumentID[$0] {
				// Found
				foundDocumentIDs.append($0)
				reference.noteWasReferenced()
			} else {
				// Not found
				notFoundDocumentIDs.append($0)
			}
		} }

		return (foundDocumentIDs, notFoundDocumentIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	func queryDocumentBackings(_ documentIDs :[String]) -> (foundDocumentBackings :[T], notFoundDocumentIDs :[String]) {
		// Setup
		var	foundDocumentBackings = [T]()
		var	notFoundDocumentIDs = [String]()

		// Iterate document IDs
		self.lock.read() { documentIDs.forEach() {
			// Look up reference for this document ID
			if let reference = self.referenceByDocumentID[$0] {
				// Found
				foundDocumentBackings.append(reference.documentBacking)
				reference.noteWasReferenced()
			} else {
				// Not found
				notFoundDocumentIDs.append($0)
			}
		} }

		return (foundDocumentBackings, notFoundDocumentIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove(_ documentIDs :[String]) {
		// Remove from map
		self.lock.write() {
			// Remove from storage
			documentIDs.forEach() { self.referenceByDocumentID[$0] = nil }
		}
	}
}
