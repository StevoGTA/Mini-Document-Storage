package codes.stevobrock.minidocumentstorage.ephemeral

import codes.stevobrock.androidtoolbox.concurrency.LockingArrayHashMap
import codes.stevobrock.androidtoolbox.concurrency.LockingHashMap
import codes.stevobrock.androidtoolbox.extensions.appendSetValue
import codes.stevobrock.androidtoolbox.extensions.base64EncodedString
import codes.stevobrock.androidtoolbox.extensions.update
import codes.stevobrock.minidocumentstorage.*
import java.util.*
import java.util.concurrent.locks.ReentrantReadWriteLock
import kotlin.collections.HashMap
import kotlin.concurrent.read
import kotlin.concurrent.write

//----------------------------------------------------------------------------------------------------------------------
class MDSEphemeral : MDSDocumentStorage {

	// DocumentBacking
	//------------------------------------------------------------------------------------------------------------------
	private class DocumentBacking {

		// Properties
		val	creationDate :Date

		var	revision :Int
		var	modificationDate :Date
		var	propertyMap :HashMap<String, Any>
		var	active = true

		// Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		constructor(revision :Int, creationDate :Date, modificationDate :Date, propertyMap :HashMap<String, Any>) {
			// Store
			this.creationDate = creationDate

			this.revision = revision
			this.modificationDate = modificationDate
			this.propertyMap = propertyMap
		}

		// Instance Methods
		//--------------------------------------------------------------------------------------------------------------
		fun update(revision :Int, updatedPropertyMap :Map<String, Any>? = null,
				removedProperties :Set<String>? = null) {
			// Update
			this.revision = revision
			this.modificationDate = Date()
			this.propertyMap.putAll(updatedPropertyMap ?: mapOf())
			removedProperties?.forEach() { this.propertyMap.remove(it) }
		}
	}

	// Properties
	override			var	id = UUID.randomUUID().toString()

				private	val info = HashMap<String, String>()

				private	val batchInfoMap = LockingHashMap<Thread, MDSBatchInfo<HashMap<String, Any>>>()

				private	val documentBackingByIDMap = HashMap<String, DocumentBacking>()
				private	val documentChangedProcsMap =
									LockingArrayHashMap</* Document Type */ String, MDSDocumentChangedProc>()
				private	val documentInfoMap = LockingHashMap<String, MDSDocument.Info>()
				private	val	documentIDsByTypeMap = HashMap</* Document Type */ String, /* Document IDs */ Set<String>>()
				private	val	documentLastRevisionMap = LockingHashMap</* Document type */ String, Int>()
				private	val	documentMapsLock = ReentrantReadWriteLock()
				private	val	documentsBeingCreatedPropertyMapMap = LockingHashMap<String, HashMap<String, Any>>()

				private	val	collectionsByNameMap = LockingHashMap</* Name */ String, MDSCollection<String>>()
				private	val	collectionsByDocumentTypeMap =
									LockingArrayHashMap</* Document type */ String, MDSCollection<String>>()
				private	val	collectionValuesMap = LockingHashMap</* Name */ String, /* Document IDs */ Set<String>>()

				private	val	indexesByNameMap = LockingHashMap</* Name */ String, MDSIndex<String>>()
				private	val	indexesByDocumentTypeMap =
									LockingArrayHashMap</* Document type */ String, MDSIndex<String>>()
				private	val	indexValuesMap =
									LockingHashMap</* Name */ String,
											HashMap</* Key */ String, /* Document ID */ String>>()

	// MDSDocumentStorage methods
	//------------------------------------------------------------------------------------------------------------------
	override fun info(keys :List<String>) :Map<String, String> { return this.info.filterKeys() { keys.contains(it) } }

	//------------------------------------------------------------------------------------------------------------------
	override fun set(info :Map<String, String>) { this.info.putAll(info) }

	//------------------------------------------------------------------------------------------------------------------
	override fun remove(keys :List<String>) { keys.forEach() { this.info.remove(it) } }

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> newDocument(documentInfoForNew :MDSDocument.InfoForNew) :T {
		// Setup
		val	documentID = UUID.randomUUID().base64EncodedString

		// Check for batch
		val	date = Date()
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo != null) {
			// In batch
			batchInfo.addDocument(documentInfoForNew.documentType(), documentID, creationDate = date,
					modificationDate = date)

			return documentInfoForNew.create(documentID, this) as T
		} else {
			// Will be creating document
			val	propertyMap = HashMap<String, Any>()
			this.documentsBeingCreatedPropertyMapMap.set(documentID, propertyMap)

			// Create
			val	document = documentInfoForNew.create(documentID, this)

			// Remove property map
			this.documentsBeingCreatedPropertyMapMap.remove(documentID)

			// Add document
			val	documentBacking =
						DocumentBacking(nextRevision(documentInfoForNew.documentType()), date, date, propertyMap)
			this.documentMapsLock.write() {
				// Update maps
				this.documentBackingByIDMap[documentID] = documentBacking
				this.documentIDsByTypeMap.appendSetValue(documentInfoForNew.documentType(), documentID)
			}

			// Update collections and indexes
			val	updateInfos =
						listOf(MDSUpdateInfo(document, documentBacking.revision, documentID, null))
			updateCollections(documentInfoForNew.documentType(), updateInfos)
			updateIndexes(documentInfoForNew.documentType(), updateInfos)

			// Call document changed procs
			this.documentChangedProcsMap.values(documentInfoForNew.documentType())?.forEach()
				{ it(document, MDSDocument.ChangeKind.CREATED) }

			return document as T
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> document(documentID :String, documentInfo :MDSDocument.Info) :T? {
		// Return document
		return documentInfo.create(documentID, this) as T
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun creationDate(document :MDSDocument) :Date {
		// Check for batch
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		val	batchDocumentInfo = batchInfo?.documentInfo(document.id)
		if (batchDocumentInfo != null)
			// In batch
			return batchDocumentInfo.creationDate
		else if (this.documentsBeingCreatedPropertyMapMap.value(document.id) != null)
			// Being created
			return Date()
		else
			// "Idle"
			return this.documentMapsLock.read() { this.documentBackingByIDMap[document.id]?.creationDate ?: Date() }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun modificationDate(document :MDSDocument) :Date {
		// Check for batch
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		val	batchDocumentInfo = batchInfo?.documentInfo(document.id)
		if (batchDocumentInfo != null)
			// In batch
			return batchDocumentInfo.modificationDate
		else if (this.documentsBeingCreatedPropertyMapMap.value(document.id) != null)
			// Being created
			return Date()
		else
			// "Idle"
			return this.documentMapsLock.read() { this.documentBackingByIDMap[document.id]?.modificationDate ?: Date() }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun value(property :String, document :MDSDocument) :Any? {
		// Check for batch
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		val	batchDocumentInfo = batchInfo?.documentInfo(document.id)
		if (batchDocumentInfo != null)
			// In batch
			return batchDocumentInfo.value(property)

		// Check if being created
		val	propertyMap = this.documentsBeingCreatedPropertyMapMap.value(document.id)
		if (propertyMap != null)
			// Being created
			return propertyMap[property]

		// "Idle"
		return this.documentMapsLock.read() { this.documentBackingByIDMap[document.id]?.propertyMap?.get(property) }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun byteArray(property :String, document :MDSDocument) :ByteArray? {
		// Return ByteArray
		return value(property, document) as? ByteArray
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun date(property :String, document :MDSDocument) :Date? {
		// Return Date
		return value(property, document) as? Date
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun set(property :String, value :Any?, document :MDSDocument) {
		// Setup
		val documentType = document.documentType

		// Check for batch
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo != null) {
			// In batch
			val	batchDocumentInfo = batchInfo.documentInfo(document.id)
			if (batchDocumentInfo != null)
				// Have document in batch
				batchDocumentInfo.set(property, value)
			else {
				// Don't have document in batch
				val	date = Date()
				batchInfo.addDocument(documentType, document.id, hashMapOf(), date, date) {
						// Play nice with others
						this.documentMapsLock.read()
							{ this.documentBackingByIDMap[document.id]?.propertyMap?.get(property) }
					}
					.set(property, value)
			}
		} else {
			// Check if being created
			val	propertyMap = this.documentsBeingCreatedPropertyMapMap.value(document.id)
			if (propertyMap != null)
				// Being created
				propertyMap.update(property, value)
			else {
				// Update document
				val	documentBacking =
							this.documentMapsLock.write() {
								// Setup
								val documentBacking = this.documentBackingByIDMap[document.id]!!

								// Update
								documentBacking.propertyMap.update(property, value)

								documentBacking
							}

				// Update collections and indexes
				val	updateInfos = listOf(MDSUpdateInfo(document, documentBacking.revision, document.id, setOf(property)))
				updateCollections(documentType, updateInfos)
				updateIndexes(documentType, updateInfos)

				// Call document changed procs
				this.documentChangedProcsMap.values(documentType)?.forEach()
					{ it(document, MDSDocument.ChangeKind.UPDATED) }
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun remove(document :MDSDocument) {
		// Setup
		val documentType = document.documentType

		// Check for batch
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo != null) {
			// In batch
			val	batchDocumentInfo = batchInfo.documentInfo(document.id)
			if (batchDocumentInfo != null)
				// Have document in batch
				batchDocumentInfo.remove()
			else {
				// Don't have document in batch
				val date = Date()
				batchInfo.addDocument(documentType, document.id, hashMapOf(), date, date).remove()
			}
		} else {
			// Not in batch
			this.documentMapsLock.write() { this.documentBackingByIDMap[document.id]?.active = false }

			// Remove from collections and indexes
			removeFromCollections(setOf(document.id))
			removeFromIndexes(setOf(document.id))

			// Call document changed procs
			this.documentChangedProcsMap.values(documentType)?.forEach()
				{ it(document, MDSDocument.ChangeKind.REMOVED) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> iterate(documentInfo :MDSDocument.Info, proc :(document :T) -> Unit) {
		// Collect document IDs
		val	documentIDs =
					this.documentMapsLock.read() {
						// Return IDs filtered by active
						(this.documentIDsByTypeMap[documentInfo.documentType] ?: setOf())!!
							.filter() { this.documentBackingByIDMap[it]!!.active }
					}

		// Call proc on each document
		documentIDs.forEach() { proc(documentInfo.create(it, this) as T) }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> iterate(documentInfo :MDSDocument.Info, documentIDs :List<String>,
			proc :(document :T) -> Unit) {
		// Iterate all
		documentIDs.forEach() { proc(documentInfo.create(it, this) as T) }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun batch(proc :() -> MDSBatchResult) {
		// Setup
		val	batchInfo = MDSBatchInfo<HashMap<String, Any>>()

		// Store
		this.batchInfoMap.set(Thread.currentThread(), batchInfo)

		// Call proc
		val	result = proc()

		// Check result
		if (result == MDSBatchResult.COMMIT) {
			// Iterate all document changes
			batchInfo.forEach() { documentType, batchDocumentInfosMap ->
				// Setup
				val	updateInfos = ArrayList<MDSUpdateInfo<String>>()
				val	removedDocumentIDs = HashSet<String>()

				// Update documents
				batchDocumentInfosMap.forEach() {
					// Setup
					val	documentID = it.key
					val batchDocumentInfo = it.value

					// Check removed
					if (!batchDocumentInfo.removed) {
						// Add/update document
						this.documentMapsLock.write() {
							// Retrieve existing document
							var documentBacking = this.documentBackingByIDMap[documentID]
							if (documentBacking != null) {
								// Update document backing
								documentBacking.update(nextRevision(documentType), batchDocumentInfo.updatedPropertyMap,
										batchDocumentInfo.removedProperties)

								// Check if we have document info
								val	documentInfo = this.documentInfoMap.value(documentType)
								if (documentInfo != null) {
									// Create document
									val	document = documentInfo.create(documentID, this)

									// Update collections and indexes
									val	changedProperties =
												(batchDocumentInfo.updatedPropertyMap ?: hashMapOf()).keys
														.plus(batchDocumentInfo.removedProperties ?: setOf())
									updateInfos.add(
											MDSUpdateInfo(document, documentBacking.revision, documentID,
													changedProperties))

									// Call document changed procs
									this.documentChangedProcsMap.values(documentType)?.forEach()
										{ it(document, MDSDocument.ChangeKind.UPDATED) }
								}
							} else {
								// Add document
								documentBacking =
										DocumentBacking(nextRevision(documentType), batchDocumentInfo.creationDate,
												batchDocumentInfo.modificationDate,
												batchDocumentInfo.updatedPropertyMap ?: hashMapOf())
								this.documentBackingByIDMap[documentID] = documentBacking
								this.documentIDsByTypeMap.appendSetValue(batchDocumentInfo.documentType, documentID)

								// Check if we have document info
								val	documentInfo = this.documentInfoMap.value(documentType)
								if (documentInfo != null) {
									// Create document
									val	document = documentInfo.create(documentID, this)

									// Update collections and indexes
									updateInfos.add(
										MDSUpdateInfo(document, documentBacking.revision, documentID,
													null)
									)

									// Call document changed procs
									this.documentChangedProcsMap.values(documentType)?.forEach()
										{ it(document, MDSDocument.ChangeKind.CREATED) }
								}
							}
						}
					} else {
						// Remove document
						removedDocumentIDs.add(documentID)

						this.documentMapsLock.write() {
							// Update maps
							this.documentBackingByIDMap[documentID]?.active = false

							// Check if we have document info
							val	documentInfo = this.documentInfoMap.value(documentType)
							if (documentInfo != null) {
								// Create document
								val	document = documentInfo.create(documentID, this)

								// Call document changed procs
								this.documentChangedProcsMap.values(documentType)?.forEach()
									{ it(document, MDSDocument.ChangeKind.REMOVED) }
							}
						}
					}
				}

				// Update collections and indexes
				removeFromCollections(removedDocumentIDs)
				updateCollections(documentType, updateInfos)

				removeFromIndexes(removedDocumentIDs)
				updateIndexes(documentType, updateInfos)
			}
		}

		// Remove
		this.batchInfoMap.remove(Thread.currentThread())
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> registerCollection(name :String, documentInfo :MDSDocument.Info, version :Int,
			relevantProperties :List<String>, isUpToDate :Boolean, isIncludedSelector :String,
			isIncludedSelectorInfo :Map<String, Any>, isIncludedProc :(document :T) -> Boolean) {
		// Ensure this collection has not already been registered
		if (this.collectionsByNameMap.value(name) != null) return

		// Create collection
		val	collection =
					MDSCollection<String>(name, documentInfo.documentType, relevantProperties, 0,
							isIncludedProc as (MDSDocument) -> Boolean)

		// Add to maps
		this.collectionsByNameMap.set(name, collection)
		this.collectionsByDocumentTypeMap.addArrayValue(documentInfo.documentType, collection)

		// Update document info map
		this.documentInfoMap.set(documentInfo.documentType, documentInfo)
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun queryCollectionDocumentCount(name :String) :Int {
		// Return count
		return this.collectionValuesMap.value(name)?.size ?: 0
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> iterateCollection(name :String, documentInfo :MDSDocument.Info,
			proc :(document :T) -> Unit) {
		// Iterate
		this.collectionValuesMap.value(name)?.forEach() { proc(documentInfo.create(it, this) as T) }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> registerIndex(name :String, documentInfo :MDSDocument.Info, version :Int,
			relevantProperties :List<String>, isUpToDate :Boolean, keysSelector :String,
			keysSelectorInfo :Map<String, Any>, keysProc :(document :T) -> List<String>) {
		// Ensure this index has not already been registered
		if (this.indexesByNameMap.value(name) != null) return

		// Create index
		val index =
					MDSIndex<String>(name, documentInfo.documentType, relevantProperties, 0,
							keysProc as (MDSDocument) -> List<String>)

		// Add to maps
		this.indexesByNameMap.set(name, index)
		this.indexesByDocumentTypeMap.addArrayValue(documentInfo.documentType, index)

		// Update document info map
		this.documentInfoMap.set(documentInfo.documentType, documentInfo)
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> iterateIndex(name :String, documentInfo :MDSDocument.Info, keys :List<String>,
			proc :(key :String, document :T) -> Unit) {
		// Setup
		val	indexValues = this.indexValuesMap.value(name) ?: return

		// Iterate keys
		keys.forEach() {
			// Retrieve documentID
			val	documentID = indexValues[it]
			if (documentID != null)
				// Call proc
				proc(it, documentInfo.create(documentID, this) as T)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun registerDocumentChangedProc(documentType :String, proc :MDSDocumentChangedProc) {
		// Add
		this.documentChangedProcsMap.addArrayValue(documentType, proc)
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	private fun nextRevision(documentType :String) :Int {
		// Compose next revision
		val	nextRevision = (this.documentLastRevisionMap.value(documentType) ?: 0) + 1

		// Store
		this.documentLastRevisionMap.set(documentType, nextRevision)

		return nextRevision
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun updateCollections(documentType :String, updateInfos :List<MDSUpdateInfo<String>>) {
		// Iterate all collections for this document type
		this.collectionsByDocumentTypeMap.values(documentType)?.forEach() { collection ->
			// Query update info
			val	(includedIDs, notIncludedIDs, _) = collection.update(updateInfos)

			// Update storage
			this.collectionValuesMap.update(collection.name) {
				// Compose updated values
				val	updatedValues = (it ?: setOf())!!.minus(notIncludedIDs).plus(includedIDs)

				// Return updated values
				if (updatedValues.isNotEmpty()) updatedValues else null
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun removeFromCollections(documentIDs :Set<String>) {
		// Iterate all collections for this document type
		this.collectionValuesMap.keys.forEach()
			{ collectionName -> this.collectionValuesMap.update(collectionName) { it?.minus(documentIDs) } }
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun updateIndexes(documentType :String, updateInfos :List<MDSUpdateInfo<String>>) {
		// Iterate all indexes for this document type
		this.indexesByDocumentTypeMap.values(documentType)?.forEach() { index ->
			// Query update info
			val	(keysInfos, _) = index.update(updateInfos)
			if (keysInfos.isEmpty()) return

			// Update storage
			val	documentIDs = keysInfos.map() { it.value }.toSet()
			this.indexValuesMap.update(index.name) { valueInfo ->
				// Filter out document IDs included in update
				val	updatedValueInfo =
							HashMap((valueInfo ?: hashMapOf())!!.filterValues() { !documentIDs.contains(valueInfo) })

				// Add/Update keys => documentIDs
				keysInfos.forEach() { keysInfo -> keysInfo.keys.forEach() { updatedValueInfo[it] = keysInfo.value } }

				// Return updated valueInfo
				if (updatedValueInfo.isNotEmpty()) updatedValueInfo else null
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun removeFromIndexes(documentIDs :Set<String>) {
		// Iterate all indexes for this document type
		this.indexValuesMap.keys.forEach()
			{ indexName ->
				this.indexValuesMap.update(indexName) {
					// Filter
					val	updatedValueInfo = it?.filter() { !documentIDs.contains(it.value) }

					// Return updated valueInfo or null
					if ((updatedValueInfo != null) && updatedValueInfo.isNotEmpty()) HashMap(updatedValueInfo) else null
				}
			}
	}
}
