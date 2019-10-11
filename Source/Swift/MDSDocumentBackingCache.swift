//
//  MDSDocumentBackingCache.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: Reference
fileprivate class Reference<T> {

	// MARK: Properties
	let	documentID :String

	var	documentBacking :T
	var	lastReferencedDate :Date

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(documentID :String, documentBacking :T) {
		// Store
		self.documentID = documentID

		self.documentBacking = documentBacking

		// Setup
		self.lastReferencedDate = Date()
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func noteWasReferenced() { self.lastReferencedDate = Date() }
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentBackingCache
public class MDSDocumentBackingCache<T> {

	// MARK: Properties
	private	let	limit :Int

	private	var	referenceMap = [/* document id */ String : Reference<T>]()
	private	var	references = [Reference<T>]()
	private	var	lock = ReadPreferringReadWriteLock()

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(limit :Int = 1_000_000) {
		// Store
		self.limit = limit
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func documentBacking(for documentID :String) -> T? {
		// Return cached document, if available
		return self.lock.read() { self.referenceMap[documentID]?.documentBacking }
	}

	//------------------------------------------------------------------------------------------------------------------
	public func noteWasReferenced(documentID :String) {
		// Update
		self.lock.write() {
			// Note was referenced
			self.referenceMap[documentID]?.noteWasReferenced()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func noteWasReferenced(documentID :String, documentBacking :T) {
		// Update
		self.lock.write() {
			// Retrieve reference
			if let reference = self.referenceMap[documentID] {
				// Have existing reference in cache
				reference.noteWasReferenced()
			} else {
				// Add to cache
				let	reference = Reference(documentID: documentID, documentBacking: documentBacking)
				self.referenceMap[documentID] = reference
				self.references.append(reference)

				// Refresh references
				refreshReferences()
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func noteWasReferenced(_ documentInfos :[(documentID :String, documentBacking :T)]) {
		// Update
		self.lock.write() {
			// Do all documents
			documentInfos.forEach() {
				// Retrieve document reference
				if let reference = self.referenceMap[$0.documentID] {
					// Have existing reference in cache
					reference.documentBacking = $0.documentBacking
					reference.noteWasReferenced()
				} else {
					// Add to cache
					let	reference = Reference(documentID: $0.documentID, documentBacking: $0.documentBacking)
					self.referenceMap[$0.documentID] = reference
					self.references.append(reference)
				}
			}

			// Refresh references
			refreshReferences()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(_ documentIDs :[String]) {
		// Remove from map
		self.lock.write() {
			// Setup map of document IDs => array offsets
			var	map = [String : Int]()
			self.references.enumerated().forEach() { map[$0.element.documentID] = $0.offset }

			// Compose indexSet of array offsets
			var	indexSet = IndexSet()
			documentIDs.forEach() {
				// Check if this document ID is in the map
				if let index = map[$0] {
					// Add this index
					indexSet.insert(index)
				}
			}

			// Remove from storage
			documentIDs.forEach() { self.referenceMap[$0] = nil }
			self.references.remove(for: indexSet)
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func refreshReferences() {
		// Only need to consider things if we have moved past the document limit
		if self.references.count > self.limit {
			// Sort by last referenced date to move the least referenced documents to the top of the array
			self.references.sort() { $0.lastReferencedDate < $1.lastReferencedDate }

			// Prune to remove documents beyond limit
			let	countToRemove = self.references.count - self.limit
			let	removedReferences = self.references[0..<countToRemove]
			self.references.removeFirst(countToRemove)
			removedReferences.forEach() {
				// Drop from cache
				self.referenceMap[$0.documentID] = nil
			}
		}
	}
}
