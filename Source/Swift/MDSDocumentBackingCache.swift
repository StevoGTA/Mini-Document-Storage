//
//  MDSDocumentBackingCache.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/9/19.
//  Copyright © 2019 Stevo Brock. All rights reserved.
//

import Foundation

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

	private	var	lock = ReadPreferringReadWriteLock()
	private	var	referenceMap = [/* document id */ String : Reference<T>]()
	private	var	timer :Timer?

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	public init(limit :Int = 1_000_000) {
		// Store
		self.limit = limit
	}

	//------------------------------------------------------------------------------------------------------------------
	deinit {
    	// Cleanup
    	self.timer?.invalidate()
	}

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	public func add(_ documentInfos :[(documentID :String, documentBacking :T)]) {
		// Update
		self.lock.write() {
			// Do all documents
			documentInfos.forEach() {
				// Add to cache
				self.referenceMap[$0.documentID] =
						Reference(documentID: $0.documentID, documentBacking: $0.documentBacking)
			}

			// Reset pruning timer if needed
			resetPruningTimerIfNeeded()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	public func documentBacking(for documentID :String) -> T? {
		// Return cached document, if available
		return self.lock.read() {
			// Retrieve
			if let reference = self.referenceMap[documentID] {
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
	public func query(_ documentIDs :[String]) -> (foundDocumentIDs :Set<String>, notFoundDocumentIDs :Set<String>) {
		// Setup
		var	foundDocumentIDs = Set<String>()
		var	notFoundDocumentIDs = Set<String>()

		// Iterate document IDs
		self.lock.read() { documentIDs.forEach() {
			// Look up reference for this document ID
			if let reference = self.referenceMap[$0] {
				// Found
				foundDocumentIDs.insert($0)
				reference.noteWasReferenced()
			} else {
				// Not found
				notFoundDocumentIDs.insert($0)
			}
		} }

		return (foundDocumentIDs, notFoundDocumentIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	public func remove(_ documentIDs :[String]) {
		// Remove from map
		self.lock.write() {
			// Remove from storage
			documentIDs.forEach() { self.referenceMap[$0] = nil }

			// Reset pruning timer if needed
			resetPruningTimerIfNeeded()
		}
	}

	// MARK: Private methods
	//------------------------------------------------------------------------------------------------------------------
	private func resetPruningTimerIfNeeded() {
		// Invalidate existing timer
		self.timer?.invalidate()
		self.timer = nil

		// Check if need to prune
		if self.referenceMap.count > self.limit {
			// Need to prune
			self.timer = Timer.scheduledTimer(timeInterval: 5.0, runLoop: RunLoop.main) { [weak self] _ in
				// Ensure we are still around
				guard let strongSelf = self else { return }

				// Prune
				strongSelf.lock.write() {
					// Only need to consider things if we have moved past the document limit
					let	countToRemove = strongSelf.referenceMap.count - strongSelf.limit
					if countToRemove > 0 {
						// Iterate all references
						var	referencesToRemove = [Reference<T>]()
						var	earliestReferencedDate = Date.distantFuture
						strongSelf.referenceMap.values.forEach() {
							// Compare date
							if $0.lastReferencedDate < earliestReferencedDate {
								// Update references to remove
								referencesToRemove.append($0)
								referencesToRemove.sort() { $0.lastReferencedDate < $1.lastReferencedDate }
								if referencesToRemove.count > countToRemove {
									// Pop the last
									let	reference = referencesToRemove.popLast()!
									earliestReferencedDate = reference.lastReferencedDate
								}
							}
						}

						// Remove
						referencesToRemove.forEach() { strongSelf.referenceMap[$0.documentID] = nil }
					}
				}

				// Cleanup
				strongSelf.timer = nil
			}
		}
	}
}
