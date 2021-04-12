package codes.stevobrock.minidocumentstorage.sqlite

import java.util.*
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.collections.HashMap
import kotlin.concurrent.read
import kotlin.concurrent.write

//----------------------------------------------------------------------------------------------------------------------
class MDSSQLiteDocumentBacking {

	// Properties
	val	id :Long
	val	creationDate :Date

	var	revision :Int
	var	modificationDate :Date
	val	propertyMap :HashMap<String, Any> get() = this.propertiesLock.read() { this.propertyMapInternal }
	var	active :Boolean

	private	val propertyMapInternal :HashMap<String, Any>
	private	val propertiesLock = ReentrantReadWriteLock()

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(id :Long, revision :Int, creationDate :Date, modificationDate :Date, propertyMap :HashMap<String, Any>,
			active :Boolean) {
		// Store
		this.id = id
		this.creationDate = creationDate

		this.revision = revision
		this.modificationDate = modificationDate
		this.propertyMapInternal = propertyMap
		this.active = active
	}

	//------------------------------------------------------------------------------------------------------------------
	constructor(documentType :String, documentID :String, creationDate :Date? = null, modificationDate :Date? = null,
			propertyMap :HashMap<String, Any>, databaseManager :MDSSQLiteDatabaseManager) {
		// Setup
		val (id, revision, creationDateUse, modificationDateUse) =
					databaseManager.new(documentType, documentID, creationDate, modificationDate, propertyMap)

		// Store
		this.id = id
		this.creationDate = creationDateUse

		this.revision = revision
		this.modificationDate = modificationDateUse
		this.propertyMapInternal = propertyMap
		this.active = true
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	fun value(property :String) :Any? { return this.propertiesLock.read() { this.propertyMapInternal[property] } }

	//------------------------------------------------------------------------------------------------------------------
	fun set(property :String, value :Any?, documentType :String, databaseManager :MDSSQLiteDatabaseManager,
			commitChange :Boolean = true) {
		// Update
		update(documentType, if (value != null) hashMapOf(property to value) else null,
			if (value == null) setOf(property) else null, databaseManager, commitChange)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun update(documentType :String, updatedPropertyMap :HashMap<String, Any>? = null,
			removedProperties :Set<String>? = null, databaseManager :MDSSQLiteDatabaseManager,
			commitChange :Boolean = true) {
		// Update
		this.propertiesLock.write() {
			// Store
			updatedPropertyMap?.forEach() { this.propertyMapInternal[it.key] = it.value }
			removedProperties?.forEach() { this.propertyMapInternal.remove(it) }

			// Check if committing change
			if (commitChange) {
				// Get info
				val (revision, modificationDate) =
							databaseManager.update(documentType, this.id, this.propertyMapInternal)

				// Store
				this.revision = revision
				this.modificationDate = modificationDate
			}
		}
	}
}
