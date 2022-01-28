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
class MDSDocumentBackingCache<T> {

	// MARK: Reference
	private class Reference<T> {

		// MARK: Properties
		let	documentBackingInfo :MDSDocument.BackingInfo<T>

		var	lastReferencedDate :Date

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(documentBackingInfo :MDSDocument.BackingInfo<T>) {
			// Store
			self.documentBackingInfo = documentBackingInfo

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

	private	var	referenceMap = [/* Document ID */ String : Reference<T>]()
	private	var	timer :Timer?

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(limit :Int = 1_000_000) {
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
	func add(_ documentBackingInfos :[MDSDocument.BackingInfo<T>]) {
		// Update
		self.lock.write() {
			// Do all document backing infos
			documentBackingInfos.forEach() { self.referenceMap[$0.documentID] = Reference(documentBackingInfo: $0) }

			// Reset pruning timer if needed
//			resetPruningTimerIfNeeded()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentBacking(for documentID :String) -> T? {
		// Return cached document, if available
		return self.lock.read() {
			// Retrieve
			if let reference = self.referenceMap[documentID] {
				// Note was referenced
				reference.noteWasReferenced()

				return reference.documentBackingInfo.documentBacking
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
			if let reference = self.referenceMap[$0] {
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
	func queryDocumentBackingInfos(_ documentIDs :[String]) ->
			(foundDocumentBackingInfos :[MDSDocument.BackingInfo<T>], notFoundDocumentIDs :[String]) {
		// Setup
		var	foundDocumentInfos = [MDSDocument.BackingInfo<T>]()
		var	notFoundDocumentIDs = [String]()

		// Iterate document IDs
		self.lock.read() { documentIDs.forEach() {
			// Look up reference for this document ID
			if let reference = self.referenceMap[$0] {
				// Found
				foundDocumentInfos.append(reference.documentBackingInfo)
				reference.noteWasReferenced()
			} else {
				// Not found
				notFoundDocumentIDs.append($0)
			}
		} }

		return (foundDocumentInfos, notFoundDocumentIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	func remove(_ documentIDs :[String]) {
		// Remove from map
		self.lock.write() {
			// Remove from storage
			documentIDs.forEach() { self.referenceMap[$0] = nil }

			// Reset pruning timer if needed
//			resetPruningTimerIfNeeded()
		}
	}

//	// MARK: Private methods
//	//------------------------------------------------------------------------------------------------------------------
//	private func resetPruningTimerIfNeeded() {
//		// Invalidate existing timer
//		self.timer?.invalidate()
//		self.timer = nil
//
//		// Check if need to prune
//		if self.referenceMap.count > self.limit {
//			// Need to prune
//			self.timer = Timer.scheduledTimer(timeInterval: 5.0, runLoop: RunLoop.main) { [weak self] _ in
//				// Ensure we are still around
//				guard let strongSelf = self else { return }
//
//				// Prune
//				strongSelf.lock.write() {
//					// Only need to consider things if we have moved past the document limit
//					let	countToRemove = strongSelf.referenceMap.count - strongSelf.limit
//					if countToRemove > 0 {
//						// Iterate all references
//						var	referencesToRemove = [Reference<T>]()
//						var	earliestReferencedDate = Date.distantFuture
//						strongSelf.referenceMap.values.forEach() {
//							// Compare date
//// This is broken.  It's possible to miss a reference that needs to be removed simply because the order of dates
////	seen is random.
////							if $0.lastReferencedDate < earliestReferencedDate {
////								// Update references to remove
////								referencesToRemove.append($0)
////								referencesToRemove.sort() { $0.lastReferencedDate < $1.lastReferencedDate }
////								if referencesToRemove.count > countToRemove {
////									// Pop the last
////									let	reference = referencesToRemove.popLast()!
////									earliestReferencedDate = reference.lastReferencedDate
////								}
////							}
//_ = $0
//						}
//
//						// Remove
//						referencesToRemove.forEach()
//								{ strongSelf.referenceMap[$0.documentBackingInfo.documentID] = nil }
//					}
//				}
//
//				// Cleanup
//				strongSelf.timer = nil
//			}
//		}
//	}
}
