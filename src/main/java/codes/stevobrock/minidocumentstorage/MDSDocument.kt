package codes.stevobrock.minidocumentstorage

import java.util.*
import org.apache.commons.codec.binary.Base64

//----------------------------------------------------------------------------------------------------------------------
// Procs
typealias MDSDocumentCreateProc = (id :String, documentStorage :MDSDocumentStorage) -> MDSDocument
typealias MDSDocumentProc = (document :MDSDocument) -> Unit
typealias MDSDocumentChangedProc = (document :MDSDocument, changeKind :MDSDocument.ChangeKind) -> Unit
typealias MDSDocumentIsIncludedProc = (document :MDSDocument) -> Boolean
typealias MDSDocumentKeysProc = (document :MDSDocument) -> List<String>
typealias MDSDocumentKeyProc = (key :String, document :MDSDocument) -> Unit

//----------------------------------------------------------------------------------------------------------------------
// Types
data class MDSUpdateInfo<T>(val document :MDSDocument, val revision :Int, val value :T,
		val changedProperties :Set<String>?)
data class MDSBringUpToDateInfo<T>(val document :MDSDocument, val revision :Int, val value :T)

//----------------------------------------------------------------------------------------------------------------------
// MDSDocument
abstract class MDSDocument(val id :String, val documentStorage :MDSDocumentStorage) {

	// Types
	enum class ChangeKind {
		CREATED,
		UPDATED,
		REMOVED,
	}

	data class BackingInfo<T>(val documentID :String, val documentBacking :T)
	data class RevisionInfo(val documentID :String, val revision :Int)
	data class FullInfo(val documentID :String, val revision :Int, val active :Boolean, val creationDate :Date,
				val modificationDate :Date, val propertyMap :Map<String, Any>)
	data class CreateInfo(val documentID :String, val creationDate :Date?, val modificationDate :Date?,
				val propertyMap :Map<String, Any>)
	data class UpdateInfo(val documentID :String, val updated :Map<String, Any> = mapOf<String, Any>(),
				val removed :List<String> = listOf(), val active :Boolean = true)

	// Info
	//------------------------------------------------------------------------------------------------------------------
	class Info(val documentType :String, private val createProc :MDSDocumentCreateProc) {

		// Instance Methods
		//--------------------------------------------------------------------------------------------------------------
		fun create(id :String, documentStorage :MDSDocumentStorage) :MDSDocument {
			// Call createProc
			return this.createProc(id, documentStorage)
		}
	}

	// InfoForNew
	//------------------------------------------------------------------------------------------------------------------
	abstract class InfoForNew() {

		// Methods
		abstract fun documentType() :String
		abstract fun create(id :String, documentStorage :MDSDocumentStorage) :MDSDocument
	}

	// Properties
	abstract	val	documentType :String

				val creationDate :Date get() = this.documentStorage.creationDate(this)
				val modificationDate :Date get() = this.documentStorage.modificationDate(this)

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	fun list(property :String) :List<Any>? {
		// Return value
		return this.documentStorage.value(property, this) as List<Any>?
	}
	fun <T> set(property :String, value :List<T>) { this.documentStorage.set(property, value, this) }

	//------------------------------------------------------------------------------------------------------------------
	fun bool(property :String) :Boolean? { return this.documentStorage.value(property, this) as Boolean? }
	fun set(property :String, value :Boolean?) :Boolean? {
		// Check if different
		val	previousValue = bool(property)
		if (value != previousValue)
			// Set
			this.documentStorage.set(property, value, this)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	fun byteArray(property :String) :ByteArray? { return this.documentStorage.byteArray(property, this) }
	fun set(property :String, value :ByteArray?) :ByteArray? {
		// Check if different
		val previousValue = byteArray(property)
		if (!value.contentEquals(previousValue))
			// Set
			this.documentStorage.set(property, value, this)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	fun date(property :String) :Date? { return this.documentStorage.date(property, this) }
	fun set(property :String, value :Date?) :Date? {
		// Check if different
		val previousValue = date(property)
		if (value != previousValue)
			// Set
			this.documentStorage.set(property, value, this)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	fun double(property :String) :Double? { return this.documentStorage.value(property, this) as Double? }
	fun set(property :String, value :Double?) :Double? {
		// Check if different
		val previousValue = double(property)
		if (value != previousValue)
			// Set
			this.documentStorage.set(property, value, this)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	fun int(property :String) :Int? { return this.documentStorage.value(property, this) as Int? }
	fun set(property :String, value :Int?) :Int? {
		// Check if different
		val previousValue = int(property)
		if (value != previousValue)
			// Set
			this.documentStorage.set(property, value, this)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	fun long(property :String) :Long? { return this.documentStorage.value(property, this) as Long? }
	fun set(property :String, value :Long?) :Long? {
		// Check if different
		val previousValue = long(property)
		if (value != previousValue)
			// Set
			this.documentStorage.set(property, value, this)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	fun map(property :String) :Map<String, Any>? {
		// Return value
		return this.documentStorage.value(property, this) as? Map<String, Any>
	}
	fun set(property :String, value :Map<String, Any>?) { this.documentStorage.set(property, value, this) }

	//------------------------------------------------------------------------------------------------------------------
	fun set(property :String) :Set<Any>? {
		// Return value
		return (this.documentStorage.value(property, this) as? List<Any>)?.toSet()
	}
	fun <T> set(property :String, value :Set<T>?) {
		// Store value
		this.documentStorage.set(property, value?.toList(), this)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun string(property :String) :String? { return this.documentStorage.value(property, this) as String? }
	fun set(property :String, value :String?) :String? {
		// Check if different
		val previousValue = string(property)
		if (value != previousValue)
			// Set
			this.documentStorage.set(property, value, this)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	fun uint(property :String) :UInt? { return this.documentStorage.value(property, this) as UInt? }
	fun set(property :String, value :UInt?) :UInt? {
		// Check if different
		val previousValue = uint(property)
		if (value != previousValue)
			// Set
			this.documentStorage.set(property, value, this)

		return previousValue
	}

	//------------------------------------------------------------------------------------------------------------------
	fun <T : MDSDocument> document(property :String, info :Info) :T? {
		// Retrieve documentID
		val	documentID = string(property) ?: return null

		return this.documentStorage.document(documentID, info)
	}
	fun <T : MDSDocument> set(property :String, document :T?) {
		// Set
		this.documentStorage.set(property, document?.id, this)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun <T : MDSDocument> documents(property :String, info :Info) :List<T>? {
		// Retrieve documentIDs
		val	documentIDs = list(property) as? List<String> ?: return null

		return this.documentStorage.documents(info, documentIDs)
	}
	@JvmName("setDocuments")
	fun <T : MDSDocument> set(property :String, documents :List<T>?) {
		// Set
		this.documentStorage.set(property, documents?.map() { it.id }, this)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun <T : MDSDocument> documentMap(property :String, info :Info) : Map<String, T>? {
		// Retrieve documentIDs map
		val storedMap = map(property) as? Map<String, String> ?: return null

		// Retrieve documents
		val	documents = this.documentStorage.documents<T>(info, storedMap.values.toList())
		if (documents.size != storedMap.size) return null;

		// Prepare map from documentID to document
		val	documentMap = HashMap<String, T>()
		documents.forEach() { documentMap[it.id] = it }

		return storedMap.mapValues() { documentMap[it]!! }
	}
	@JvmName("setDocumentMap")
	fun <T : MDSDocument> set(property :String, documentMap :Map<String, T>?) {
		// Set value
		this.documentStorage.set(property, documentMap?.mapValues() { it.value.id }, this)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun remove(property :String) { this.documentStorage.set(property, null, this) }

	//------------------------------------------------------------------------------------------------------------------
	fun remove() { this.documentStorage.remove(this) }
}
