package codes.stevobrock.minidocumentstorage

import java.util.*

//----------------------------------------------------------------------------------------------------------------------
// MDSBatchResult
enum class MDSBatchResult {
	COMMIT,
	CANCEL,
}

//----------------------------------------------------------------------------------------------------------------------
// MDSValueType
enum class MDSValueType {
	INTEGER
}

//----------------------------------------------------------------------------------------------------------------------
// MDSAssociationAction
enum class MDSAssociationAction(val string :String) {
	ADD("add"),
	UPDATE("update"),
	REMOVE("remove"),
}

//----------------------------------------------------------------------------------------------------------------------
// Types

//typealias MDSAssociationUpdate = Triple<MDSAssociationAction, MDSDocument, MDSDocument>

data class MDSCacheValueInfo<T : MDSDocument>(val name :String, val valueType :MDSValueType, val selector :String,
		val proc :(document :T) -> Any)

//----------------------------------------------------------------------------------------------------------------------
// MDSDocumentStorage
interface MDSDocumentStorage {

	// Properties
	var	id :String

	// Instance methods
	fun info(keys :List<String>) :Map<String, String>
	fun set(info :Map<String, String>)
	fun remove(keys :List<String>)

	fun <T : MDSDocument> newDocument(documentInfoForNew :MDSDocument.InfoForNew) :T

	fun <T : MDSDocument> document(documentID :String, documentInfo :MDSDocument.Info) :T?

	fun creationDate(document :MDSDocument) :Date
	fun modificationDate(document :MDSDocument) :Date

	fun value(property :String, document :MDSDocument) :Any?
	fun byteArray(property :String, document :MDSDocument) :ByteArray?
	fun date(property :String, document :MDSDocument) :Date?
	fun set(property :String, value :Any?, document :MDSDocument)

	fun remove(document :MDSDocument)

	fun <T : MDSDocument> iterate(documentInfo :MDSDocument.Info, proc :(document :T) -> Unit)
	fun <T : MDSDocument> iterate(documentInfo :MDSDocument.Info, documentIDs :List<String>,
			proc :(document :T) -> Unit)

	fun batch(proc :() -> MDSBatchResult)

//	fun registerAssociation(name :String, fromDocumentType :String, toDocumentType :String)
//	fun updateAssociations(name :String, updates :List<MDSAssociationUpdate>)
//	fun <T : MDSDocument, U : MDSDocument> iterateAssociationFrom(name :String, fromDocument :T, proc :(document :U) -> Unit)
//	fun <T : MDSDocument, U : MDSDocument> iterateAssociationTo(name :String, toDocument :U, proc :(document :T) -> Unit)

//	fun <T : MDSDocument, U : Any> retrieveAssociationValue(name :String, toDocument :T,
//			summedCachedValueName :String) :U

//	fun <T : MDSDocument> registerCache(name :String, version :Int, relevantProperties :List<String>,
//			valuesInfos :List<MDSCacheValueInfo<T>>)

	fun <T : MDSDocument> registerCollection(name :String, documentInfo :MDSDocument.Info, version :Int,
			relevantProperties :List<String>, isUpToDate :Boolean, isIncludedSelector :String,
			isIncludedSelectorInfo :Map<String, Any>, isIncludedProc :(document :T) -> Boolean)
	fun queryCollectionDocumentCount(name :String) :Int
	fun <T : MDSDocument> iterateCollection(name :String, documentInfo :MDSDocument.Info, proc :(document :T) -> Unit)

	fun <T : MDSDocument> registerIndex(name :String, documentInfo :MDSDocument.Info, version :Int,
			relevantProperties :List<String>, isUpToDate :Boolean, keysSelector :String,
			keysSelectorInfo :Map<String, Any>, keysProc :(document :T) -> List<String>)
	fun <T : MDSDocument> iterateIndex(name :String, documentInfo :MDSDocument.Info, keys :List<String>,
			proc :(key :String, document :T) -> Unit)

	fun registerDocumentChangedProc(documentType :String, proc :MDSDocumentChangedProc)
}

//----------------------------------------------------------------------------------------------------------------------
fun MDSDocumentStorage.string(key :String) :String? { return info(listOf(key))[key] }

//----------------------------------------------------------------------------------------------------------------------
fun <T : MDSDocument> MDSDocumentStorage.documents(documentInfo :MDSDocument.Info) :List<T> {
	// Setup
	val documents = ArrayList<T>()

	// Iterate all documents
	iterate<T>(documentInfo) { documents.add(it) }

	return documents
}

//----------------------------------------------------------------------------------------------------------------------
fun <T : MDSDocument> MDSDocumentStorage.documents(documentInfo :MDSDocument.Info, documentIDs :List<String>) :List<T> {
	// Setup
	val documents = ArrayList<T>()

	// Iterate all documents
	iterate<T>(documentInfo, documentIDs) { documents.add(it) }

	return documents
}

////------------------------------------------------------------------------------------------------------------------
//fun MDSDocumentStorage.registerAssociation(fromDocumentType :String, toDocumentType :String) {
//	// Register association
//	registerAssociation(associationName(fromDocumentType, toDocumentType), fromDocumentType, toDocumentType)
//}

////------------------------------------------------------------------------------------------------------------------
//inline fun <reified T : MDSDocument, U : MDSDocument> MDSDocumentStorage.updateAssociation(updates :List<MDSAssociationUpdate>) {
//	// Update association
//	updateAssociation(associationName(T.documentType, U.documentType), updates)
//}
//
////------------------------------------------------------------------------------------------------------------------
//fun <T : MDSDocument, U : MDSDocument> MDSDocumentStorage.iterateAssociationFrom(fromDocument :T,
//		proc :(document :U) -> Unit) {
//	// Iterate association
//	iterateAssociation(associationName(T.documentType, U.documentType), document, proc)
//}
//
////------------------------------------------------------------------------------------------------------------------
//fun <T : MDSDocument, U : MDSDocument> MDSDocumentStorage.iterateAssociationTo(toDocument :U,
//		proc :(document :T) -> Unit) {
//	// Iterate association
//	iterateAssociation(associationName(T.documentType, U.documentType), document, proc)
//}
//
////------------------------------------------------------------------------------------------------------------------
//fun <T : MDSDocument, U> MDSDocumentStorage.retrieveAssociationValue(fromDocumentType :String, toDocument :T,
//			summedCachedValueName :String) :U {
//	// Return value
//	return retrieveAssociationValue(associationName(fromDocumentType, T.documentType), toDocument,
//			summedCachedValueName)
//}
//
////------------------------------------------------------------------------------------------------------------------
//fun <T : MDSDocument> MDSDocumentStorage.registerCache(version :Int = 1, relevantProperties :List<String> = listOf(),
//		valuesInfos :List<MDSCacheValueInfo<T>>) {
//	// Register cache
//	registerCache(T.documentType, version, relevantProperties, valuesInfos)
//}

//------------------------------------------------------------------------------------------------------------------
fun <T : MDSDocument> MDSDocumentStorage.registerCollection(name :String, documentInfo :MDSDocument.Info,
		version :Int = 1, relevantProperties :List<String>, isUpToDate :Boolean = false,
		isIncludedSelector :String = "", isIncludedSelectorInfo :Map<String, Any> = mapOf(),
		isIncludedProc :(document :T) -> Boolean) {
	// Register collection
	registerCollection(name, documentInfo, version, relevantProperties, isUpToDate, isIncludedSelector,
			isIncludedSelectorInfo, isIncludedProc)
}

//------------------------------------------------------------------------------------------------------------------
fun <T : MDSDocument> MDSDocumentStorage.documents(collectionName :String, documentInfo :MDSDocument.Info) :List<T> {
	// Setup
	val documents = ArrayList<T>()

	// Iterate
	iterateCollection<T>(collectionName, documentInfo) { documents.add(it) }

	return documents
}

//------------------------------------------------------------------------------------------------------------------
fun <T : MDSDocument> MDSDocumentStorage.registerIndex(name :String, documentInfo :MDSDocument.Info, version :Int = 1,
		relevantProperties :List<String>, isUpToDate :Boolean = false, keysSelector :String = "",
		keysSelectorInfo :Map<String, Any> = mapOf(), keysProc :(document :T) -> List<String>) {
	// Register index
	registerIndex(name, documentInfo, version, relevantProperties, isUpToDate, keysSelector, keysSelectorInfo, keysProc)
}

//------------------------------------------------------------------------------------------------------------------
fun <T : MDSDocument> MDSDocumentStorage.documentMap(indexName :String, documentInfo :MDSDocument.Info,
		keys :List<String>) :Map<String, T> {
	// Setup
	val documentMap = HashMap<String, T>()

	iterateIndex<T>(indexName, documentInfo, keys) { key, document -> documentMap[key] = document }

	return documentMap
}

////----------------------------------------------------------------------------------------------------------------------
//private fun MDSDocumentStorage.associationName(fromDocumentType :String, toDocumentType :String) :String {
//	// Return
//	return fromDocumentType + "To" + toDocumentType.capitalize(Locale.ROOT)
//}
