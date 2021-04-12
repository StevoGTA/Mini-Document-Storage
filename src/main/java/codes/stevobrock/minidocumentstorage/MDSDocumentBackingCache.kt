package codes.stevobrock.minidocumentstorage

import java.util.*
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.collections.ArrayList
import kotlin.concurrent.read
import kotlin.concurrent.timer
import kotlin.concurrent.write

//----------------------------------------------------------------------------------------------------------------------
class MDSDocumentBackingCache<T : Any> {

	// Types
	data class QueryDocumentIDsInfo(val foundDocumentIDs :List<String>, val notFoundDocumentIDs :List<String>)
	data class QueryDocumentBackingInfosInfo<T : Any>(val foundDocumentBackingInfos :List<MDSDocument.BackingInfo<T>>,
				val notFoundDocumentIDs :List<String>)

	// Reference
	//------------------------------------------------------------------------------------------------------------------
	private class Reference<T : Any> {

		// Properties
		val	documentBackingInfo :MDSDocument.BackingInfo<T>

		var	lastReferencedDate :Date

		// Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		constructor(documentBackingInfo :MDSDocument.BackingInfo<T>) {
			// Store
			this.documentBackingInfo = documentBackingInfo

			// Setup
			this.lastReferencedDate = Date()
		}

		// Instance methods
		//--------------------------------------------------------------------------------------------------------------
		fun noteWasReferenced() { this.lastReferencedDate = Date() }
	}

	// Properties
	private	val limit :Int
	private	val lock = ReentrantReadWriteLock()

	private	var	referenceMap = HashMap</* Document ID */ String, Reference<T>>()
	private	var	timer :Timer? = null

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(limit :Int = 1000000) {
		// Store
		this.limit = limit
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	fun add(documentBackingInfos :List<MDSDocument.BackingInfo<T>>) {
		// Update
		this.lock.write() {
			// Do all the document backing infos
			documentBackingInfos.forEach() { this.referenceMap[it.documentID] = Reference((it)) }

			// Reset pruning timer if needed
			resetPruningTimerIfNeeded()
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	fun documentBacking(documentID :String) :T? {
		// Return cached document, if available
		this.lock.read() {
			// Retrieve
			val	reference = this.referenceMap[documentID]
			if (reference != null) {
				// Note was referenced
				reference.noteWasReferenced()

				return reference.documentBackingInfo.documentBacking
			} else
				// Not found
				return null
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	fun queryDocumentIDs(documentIDs :List<String>) :QueryDocumentIDsInfo {
		// Setup
		val	foundDocumentIDs = ArrayList<String>()
		val	notFoundDocumentIDs = ArrayList<String>()

		// Iterate document IDs
		this.lock.read() { documentIDs.forEach() {
			// Look up reference for this document ID
			val	reference = this.referenceMap[it]
			if (reference != null) {
				// Found
				foundDocumentIDs.add(it)
				reference.noteWasReferenced()
			} else
				// Not found
				notFoundDocumentIDs.add(it)
		} }

		return QueryDocumentIDsInfo(foundDocumentIDs, notFoundDocumentIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun queryDocumentBackingInfos(documentIDs :List<String>) :QueryDocumentBackingInfosInfo<T> {
		// Setup
		val foundDocumentInfos = ArrayList<MDSDocument.BackingInfo<T>>()
		val	notFoundDocumentIDs = ArrayList<String>()

		// Iterate document IDs
		this.lock.read() { documentIDs.forEach() {
			// Look up reference for this document ID
			val	reference = this.referenceMap[it]
			if (reference != null) {
				// Found
				foundDocumentInfos.add(reference.documentBackingInfo)
				reference.noteWasReferenced()
			} else
				// Not found
				notFoundDocumentIDs.add(it)
		} }

		return QueryDocumentBackingInfosInfo(foundDocumentInfos, notFoundDocumentIDs)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun remove(documentIDs :List<String>) {
		// Remove from map
		this.lock.write() {
			// Remove from storage
			documentIDs.forEach() { this.referenceMap.remove(it) }

			// Reset pruning timer if needed
			resetPruningTimerIfNeeded()
		}
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	private fun resetPruningTimerIfNeeded() {
		// Invalidate existing timer
		this.timer?.cancel()
		this.timer = null

		// Check if need to prune
		if (this.referenceMap.size > this.limit) {
			// Need to prune
			this.timer = timer(initialDelay = 5000.toLong(), period = 5000) {
				// Prune
				this@MDSDocumentBackingCache.lock.write() {
					// Only need to consider things if we have moved past the document limit
					val	countToRemove =
								this@MDSDocumentBackingCache.referenceMap.size - this@MDSDocumentBackingCache.limit
					if (countToRemove > 0) {
//						// Iterate all references
//						val	referencesToRemove = ArrayList<Reference<T>>()
//						var	earliestReferencedDate = Date
//						this@MDSDocumentBackingCache.referenceMap.values.forEach() {
//							// Compare date
//
//						}
					}
				}

				// Cleanup
				this@MDSDocumentBackingCache.timer = null
			}
		}
	}
}
