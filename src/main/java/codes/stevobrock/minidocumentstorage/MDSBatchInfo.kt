package codes.stevobrock.minidocumentstorage

import org.w3c.dom.Document
import java.util.*
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.concurrent.read
import kotlin.concurrent.write

//----------------------------------------------------------------------------------------------------------------------
class MDSBatchInfo<T : Any> {

	// DocumentInfo
	class DocumentInfo<T : Any> {

		// Properties
				val documentType :String
				val reference :T?
				val creationDate :Date

				var	updatedPropertyMap :HashMap<String, Any>? = null
					private set
				var	removedProperties :HashSet<String>? = null
					private set
				var	modificationDate :Date
					private set
				var	removed = false
					private set

		private	val valueProc :(property :String) -> Any?
		private	val lock = ReentrantReadWriteLock()

		// Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		constructor(documentType :String, reference :T?, creationDate :Date, modificationDate :Date,
				valueProc :(property :String) -> Any?) {
			// Store
			this.documentType = documentType
			this.reference = reference
			this.creationDate = creationDate

			this.modificationDate = modificationDate

			this.valueProc = valueProc
		}

		// Instance Methods
		//--------------------------------------------------------------------------------------------------------------
		fun value(property :String) :Any? {
			// Check for document removed
			if (this.removed)
				// Document removed
				return null

			// Check for value
			val	valueProc :() -> Pair<Any?, Boolean>? = {
						// Check the deal
						if (this.removedProperties?.contains(property) ?: false)
							// Property removed
							Pair<Any?, Boolean>(null, true)
						else if (this.updatedPropertyMap?.containsKey(property) ?: false)
							// Property updated
							Pair(this.updatedPropertyMap!![property], false)
						else
							// Property neither removed nor updated
							null
					}
			this.lock.read() { valueProc() }.also() { return it?.first ?: this.valueProc(property) }
		}

		//--------------------------------------------------------------------------------------------------------------
		fun set(property :String, value :Any?) {
			// Write
			this.lock.write() {
				// Check if have value
				if (value != null) {
					// Have value
					if (this.updatedPropertyMap != null)
						// Have updated info
						this.updatedPropertyMap!![property] = value
					else
						// First updated info
						this.updatedPropertyMap = hashMapOf(property to value)

					this.removedProperties?.remove(property)
				} else {
					// Removing value
					this.updatedPropertyMap?.remove(property)

					if (this.removedProperties != null)
						// Have removed properties
						this.removedProperties!!.add(property)
					else
						// First removed property
						this.removedProperties = hashSetOf(property)
				}

				// Modified
				this.modificationDate = Date()
			}
		}

		//--------------------------------------------------------------------------------------------------------------
		fun remove() { this.lock.write() { this.removed = true; this.modificationDate = Date() } }
	}

	// Properties
	private	val documentInfoMap = HashMap</* Document ID */ String, DocumentInfo<T>>()
	private	val documentInfoMapLock = ReentrantReadWriteLock()

	// Instance Methods
	//------------------------------------------------------------------------------------------------------------------
	fun addDocument(documentType :String, documentID :String, reference :T? = null, creationDate :Date,
			modificationDate :Date, valueProc :(property :String) -> Any? = { null }) :DocumentInfo<T> {
		// Setup
		val	documentInfo = DocumentInfo<T>(documentType, reference, creationDate, modificationDate, valueProc)

		// Store
		this.documentInfoMapLock.write() { this.documentInfoMap[documentID] = documentInfo }

		return documentInfo
	}

	//------------------------------------------------------------------------------------------------------------------
	fun documentInfo(documentID :String) :DocumentInfo<T>? {
		// Return document info
		return this.documentInfoMapLock.read() { this.documentInfoMap[documentID] }
	}

	//------------------------------------------------------------------------------------------------------------------
	fun forEach(proc :(documentType :String, documentInfoMap :Map</* Document ID */ String, DocumentInfo<T>>) -> Unit) {
		// Collate
		val	map = HashMap</* Document Type */ String, HashMap</* Document ID */ String, DocumentInfo<T>>>()
		this.documentInfoMapLock.read() {
			// Collect info
			this.documentInfoMap.forEach() {
				// Retrieve already collated batch document infos
				var	documentInfoMap = map[it.value.documentType]
				if (documentInfoMap != null) {
					// Next document of this type
					documentInfoMap[it.key] = it.value
					map[it.value.documentType] = documentInfoMap
				} else
					// First document of this type
					map[it.value.documentType] = hashMapOf(it.key to it.value)
			}
		}

		// Iterate and call proc
		map.forEach() { proc(it.key, it.value) }
	}
}
