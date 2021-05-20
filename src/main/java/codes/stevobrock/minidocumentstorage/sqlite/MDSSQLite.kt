package codes.stevobrock.minidocumentstorage.sqlite

import android.content.Context
import android.util.Base64
import codes.stevobrock.androidtoolbox.concurrency.LockingArrayHashMap
import codes.stevobrock.androidtoolbox.concurrency.LockingHashMap
import codes.stevobrock.androidtoolbox.extensions.base64EncodedString
import codes.stevobrock.androidtoolbox.extensions.dateFromRFC3339Extended
import codes.stevobrock.androidtoolbox.extensions.rfc3339Extended
import codes.stevobrock.androidtoolbox.extensions.update
import codes.stevobrock.androidtoolbox.model.BatchQueue
import codes.stevobrock.androidtoolbox.sqlite.SQLiteDatabase
import codes.stevobrock.androidtoolbox.sqlite.SQLiteInnerJoin
import codes.stevobrock.androidtoolbox.sqlite.SQLiteResultsRow
import codes.stevobrock.androidtoolbox.sqlite.SQLiteWhere
import codes.stevobrock.minidocumentstorage.*
import java.sql.SQLWarning
import java.util.*
import kotlin.collections.HashMap

//----------------------------------------------------------------------------------------------------------------------
class MDSSQLite : MDSDocumentStorage {

	// Document Info
	data class DocumentInfo(val documentType :String, val documentID :String, val creationDate :Date? = null,
							val modificationDate :Date? = null, val propertyMap :HashMap<String, Any>)

	// Properties
	override			var	id = UUID.randomUUID().toString()

						var	logErrorMessageProc :(errorMessage :String) -> Unit = {}

				private	val databaseManager :MDSSQLiteDatabaseManager

				private	val batchInfoMap = LockingHashMap<Thread, MDSBatchInfo<MDSSQLiteDocumentBacking>>()

				private	val documentBackingCache = MDSDocumentBackingCache<MDSSQLiteDocumentBacking>()
				private	val documentChangedProcsMap =
									LockingArrayHashMap</* Document Type */ String, MDSDocumentChangedProc>()
				private	val documentInfoMap = LockingHashMap<String, MDSDocument.Info>()
				private	val	documentsBeingCreatedPropertyMapMap = LockingHashMap<String, HashMap<String, Any>>()

				private	val	collectionsByNameMap = LockingHashMap</* Name */ String, MDSCollection<Long>>()
				private	val	collectionsByDocumentTypeMap =
									LockingArrayHashMap</* Document type */ String, MDSCollection<Long>>()

				private	val	indexesByNameMap = LockingHashMap</* Name */ String, MDSIndex<Long>>()
				private	val	indexesByDocumentTypeMap = LockingArrayHashMap</* Document type */ String, MDSIndex<Long>>()

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(context :Context, name :String = "database") {
		// Setup database
		val	database = SQLiteDatabase(context, name)

		// Setup database manager
		this.databaseManager = MDSSQLiteDatabaseManager(database)
	}

	// MDSDocumentStorage methods
	//------------------------------------------------------------------------------------------------------------------
	override fun info(keys :List<String>) :Map<String, String> {
		// Setup
		val	map = HashMap<String, String>()
		keys.forEach() { map.update(it, this.databaseManager.string(it)) }

		return map
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun set(info :Map<String, String>) { info.forEach() { this.databaseManager.set(it.key, it.value) } }

	//------------------------------------------------------------------------------------------------------------------
	override fun remove(keys :List<String>) { keys.forEach() { this.databaseManager.set(it, null) } }

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> newDocument(documentInfoForNew :MDSDocument.InfoForNew) :T {
		// Setup
		val	documentID = UUID.randomUUID().base64EncodedString

		// Check for batch
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo != null) {
			// In batch
			val	date = Date()
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
			val documentBacking =
						MDSSQLiteDocumentBacking(documentInfoForNew.documentType(), documentID,
								propertyMap = propertyMap, databaseManager = this.databaseManager)
			this.documentBackingCache.add(
					listOf(MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>(documentID, documentBacking)))

			// Update collections and indexes
			val	updateInfos =
						listOf(
								MDSUpdateInfo(document, documentBacking.revision, documentBacking.id,
										null))
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
		// Check for batch
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo?.documentInfo(documentID) != null)
			// Have document in batch
			return documentInfo.create(documentID, this) as T
		else if (documentBacking(documentInfo.documentType, documentID) != null)
			// Have document backing
			return documentInfo.create(documentID, this) as T
		else
			// Don't have document backing
			return null
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
			return documentBacking(document.documentType, document.id)!!.creationDate
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
			return documentBacking(document.documentType, document.id)!!.modificationDate
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
		return documentBacking(document.documentType, document.id)!!.value(property)
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun byteArray(property :String, document :MDSDocument) :ByteArray? {
		// Retrieve Base64-encoded string
		val	string = value(property, document) as? String ?: return null

		return Base64.decode(string, Base64.DEFAULT)
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun date(property :String, document :MDSDocument) :Date? {
		// Return date
		return dateFromRFC3339Extended(value(property, document) as? String)
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun set(property :String, value :Any?, document :MDSDocument) {
		// Setup
		val	documentType = document.documentType
		val	documentID = document.id

		// Transform
		val	valueUse :Any?
		if (value is ByteArray)
			// ByteArray
			valueUse = Base64.encodeToString(value, Base64.DEFAULT)
		else if (value is Date)
			// Date
			valueUse = value.rfc3339Extended
		else
			// Everything else
			valueUse = value

		// Check for batch
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())
		if (batchInfo != null) {
			// In batch
			val	batchDocumentInfo = batchInfo.documentInfo(document.id)
			if (batchDocumentInfo != null)
				// Have document in batch
				batchDocumentInfo.set(property, valueUse)
			else {
				// Don't have document in batch
				val	documentBacking = documentBacking(documentType, documentID)!!
				batchInfo.addDocument(documentType, documentID, documentBacking, documentBacking.creationDate,
						documentBacking.modificationDate) { documentBacking.value(it) }
					.set(property, valueUse)
			}
		} else {
			// Check if being created
			val	propertyMap = this.documentsBeingCreatedPropertyMapMap.value(document.id)
			if (propertyMap != null)
				// Being created
				propertyMap.update(property, value)
			else {
				// Update document
				val	documentBacking = documentBacking(documentType, documentID)!!
				documentBacking.set(property, valueUse, documentType, this.databaseManager)

				// Update collections and indexes
				val	updateInfos =
							listOf(MDSUpdateInfo(document, documentBacking.revision, documentBacking.id,
									setOf(property)))
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
		val	documentType = document.documentType
		val	documentID = document.id

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
				val	documentBacking = documentBacking(documentType, documentID)!!
				batchInfo.addDocument(documentType, documentID, documentBacking, Date(), Date()).remove()
			}
		} else {
			// Not in batch
			val	documentBacking = documentBacking(documentType, documentID)!!

			// Remove from collections and indexes
			removeFromCollections(documentType, listOf(documentBacking.id))
			removeFromIndexes(documentType, listOf(documentBacking.id))

			// Remove
			this.databaseManager.remove(documentType, documentBacking.id)

			// Remove from cache
			this.documentBackingCache.remove(listOf(documentID))

			// Call document changed procs
			this.documentChangedProcsMap.values(documentType)?.forEach()
				{ it(document, MDSDocument.ChangeKind.REMOVED) }
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> iterate(documentInfo :MDSDocument.Info, proc :(document :T) -> Unit) {
		// Collect document IDs
		val	documentIDs = ArrayList<String>()
		iterateDocumentBackingInfos(documentInfo.documentType,
				this.databaseManager.innerJoin(documentInfo.documentType), this.databaseManager.where(true))
				{ info, _ -> documentIDs.add(info.documentID) }

		// Iterate document IDs
		documentIDs.forEach() { proc(documentInfo.create(it, this) as T) }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> iterate(documentInfo :MDSDocument.Info, documentIDs :List<String>,
			proc :(document :T) -> Unit) {
		// Iterate document backing infos to ensure they are in the cache
		iterateDocumentBackingInfos(documentInfo.documentType, documentIDs) {}

		// Iterate document IDs
		documentIDs.forEach() { proc(documentInfo.create(it, this) as T) }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun batch(proc :() -> MDSBatchResult) {
		// Setup
		val	batchInfo = MDSBatchInfo<MDSSQLiteDocumentBacking>()

		// Store
		this.batchInfoMap.set(Thread.currentThread(), batchInfo)

		// Call proc
		val	result = proc()

		// Check result
		if (result == MDSBatchResult.COMMIT) {
			// Batch changes
			this.databaseManager.batch() {
				// Iterate all document changes
				batchInfo.forEach() { documentType, batchDocumentInfosMap ->
					// Setup
					val	updatedBatchQueue =
								BatchQueue<MDSUpdateInfo<Long>>() {
									// Update collections and indexes
									updateCollections(documentType, it)
									updateIndexes(documentType, it)
								}
					val removedDocumentBackingIDs = ArrayList<Long>()

					// Update documents
					batchDocumentInfosMap.entries.forEach() {
						// Setup
						val	documentID = it.key
						val batchDocumentInfo = it.value

						// Check removed
						if (!batchDocumentInfo.removed) {
							// Add/update document
							var	documentBacking = batchDocumentInfo.reference
							if (documentBacking != null) {
								// Update document
								documentBacking.update(documentType, batchDocumentInfo.updatedPropertyMap,
										batchDocumentInfo.removedProperties, this.databaseManager)

								// Check if we have document info
								val	documentInfo = this.documentInfoMap.value(documentType)
								if (documentInfo != null) {
									// Create document
									val	document = documentInfo.create(documentID, this)

									// Update collections and indexes
									val	changedProperties =
												(batchDocumentInfo.updatedPropertyMap ?: hashMapOf()).keys
														.plus(batchDocumentInfo.removedProperties ?: setOf())
									updatedBatchQueue.add(
											MDSUpdateInfo(document, documentBacking.revision, documentBacking.id,
													changedProperties))

									// Call document changed procs
									this.documentChangedProcsMap.values(documentType)?.forEach()
										{ it(document, MDSDocument.ChangeKind.UPDATED) }
								}
							} else {
								// Add documeent
								documentBacking =
										MDSSQLiteDocumentBacking(documentType, documentID,
												batchDocumentInfo.creationDate, batchDocumentInfo.modificationDate,
												batchDocumentInfo.updatedPropertyMap ?: hashMapOf(),
												this.databaseManager)
								this.documentBackingCache.add(
										listOf(MDSDocument.BackingInfo(documentID, documentBacking)))

								// Check if we have document info
								val	documentInfo = this.documentInfoMap.value(documentType)
								if (documentInfo != null) {
									// Create document
									val	document = documentInfo.create(documentID, this)

									// Update collections and indexes
									updatedBatchQueue.add(
											MDSUpdateInfo(document, documentBacking.revision, documentBacking.id,
													null))

									// Call document changed procs
									this.documentChangedProcsMap.values(documentType)?.forEach()
										{ it(document, MDSDocument.ChangeKind.CREATED) }
								}
							}
						} else if (batchDocumentInfo.reference != null) {
							// Remove document
							val	documentBacking = batchDocumentInfo.reference
							this.databaseManager.remove(documentType, documentBacking.id)
							this.documentBackingCache.remove(listOf(documentID))

							// Remove from collections and indexes
							removedDocumentBackingIDs.add(documentBacking.id)

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

					// Finalize updates
					updatedBatchQueue.finalize()
					removeFromCollections(documentType, removedDocumentBackingIDs)
					removeFromIndexes(documentType, removedDocumentBackingIDs)
				}
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

		// Note this document type
		this.databaseManager.note(documentInfo.documentType)

		// Register collection
		val	lastRevision =
					this.databaseManager.registerCollection(documentInfo.documentType, name, version , isUpToDate)

		// Create collection
		val	collection =
					MDSCollection<Long>(name, documentInfo.documentType, relevantProperties, lastRevision,
							isIncludedProc as (MDSDocument) -> Boolean)

		// Add to maps
		this.collectionsByNameMap.set(name, collection)
		this.collectionsByDocumentTypeMap.addArrayValue(documentInfo.documentType, collection)

		// Update document info map
		this.documentInfoMap.set(documentInfo.documentType, documentInfo)
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun queryCollectionDocumentCount(name :String) :Int {
		// Bring collection up to date
		bringCollectionUpToDate(name)

		return this.databaseManager.queryCollectionDocumentCount(name)
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> iterateCollection(name :String, documentInfo :MDSDocument.Info,
			proc :(document :T) -> Unit) {
		// Collect document IDs
		val	documentIDs = ArrayList<String>()
		iterateCollection(name) { documentIDs.add(it.documentID) }

		// Iterate document IDs
		documentIDs.forEach() { proc(documentInfo.create(it, this) as T) }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun <T : MDSDocument> registerIndex(name :String, documentInfo :MDSDocument.Info, version :Int,
			relevantProperties :List<String>, isUpToDate :Boolean, keysSelector :String,
			keysSelectorInfo :Map<String, Any>, keysProc :(document :T) -> List<String>) {
		// Ensure this index has not already been registered
		if (this.indexesByNameMap.value(name) != null) return

		// Note this document type
		this.databaseManager.note(documentInfo.documentType)

		// Register index
		val	lastRevision = this.databaseManager.registerIndex(documentInfo.documentType, name, version, isUpToDate)

		// Create index
		val	index =
					MDSIndex<Long>(name, documentInfo.documentType, relevantProperties, lastRevision,
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
		// Compose map
		val	documentIDMap = HashMap<String, String>()
		iterateIndex(name, keys) { key, documentBackingInfo -> documentIDMap[key] = documentBackingInfo.documentID }

		// Iterate map
		documentIDMap.entries.forEach() { proc(it.key, documentInfo.create(it.value, this) as T) }
	}

	//------------------------------------------------------------------------------------------------------------------
	override fun registerDocumentChangedProc(documentType :String, proc :MDSDocumentChangedProc) {
		// Add
		this.documentChangedProcsMap.addArrayValue(documentType, proc)
	}

	// Private methods
	//------------------------------------------------------------------------------------------------------------------
	private fun documentBacking(documentType :String, documentID :String) :MDSSQLiteDocumentBacking? {
		// Try to retrieve from cache
		val	documentBacking = this.documentBackingCache.documentBacking(documentID)
		if (documentBacking != null) return documentBacking

		// Try to retrieve from database
		var	documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>? = null
		iterateDocumentBackingInfos(documentType, listOf(documentID)) { documentBackingInfo = it }

		// Check results
		if (documentBackingInfo != null)
			// Update cache
			this.documentBackingCache.add(listOf(documentBackingInfo!!))
		else
			// Not found
			this.logErrorMessageProc(
					"MDSSQLite - Cannot find document of type $documentType with documentID $documentID")

		return documentBackingInfo?.documentBacking
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun iterateDocumentBackingInfos(documentType :String, innerJoin :SQLiteInnerJoin? = null,
			where :SQLiteWhere? = null,
			proc
					:(documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>,
							resultsRow :SQLiteResultsRow) -> Unit) {
		// Iterate
		this.databaseManager.iterate(documentType, innerJoin, where) { info, resultsRow ->
			// Try to retrieve document backing
			val	documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>
			val	documentBacking = this.documentBackingCache.documentBacking(info.documentRevisionInfo.documentID)
			if (documentBacking != null)
				// Have document backing
				documentBackingInfo = MDSDocument.BackingInfo(info.documentRevisionInfo.documentID, documentBacking)
			else
				// Read
				documentBackingInfo = MDSSQLiteDatabaseManager.documentBackingInfo(info, resultsRow)

			// Note referenced
			this.documentBackingCache.add(listOf(documentBackingInfo))

			// Call proc
			proc(documentBackingInfo, resultsRow)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun iterateDocumentBackingInfos(documentType :String, documentIDs :List<String>,
			proc :(documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Unit) {
		// Iterate
		iterateDocumentBackingInfos(documentType, this.databaseManager.innerJoin(documentType),
				this.databaseManager.whereForDocumentIDs(documentIDs)) { info, _ -> proc(info) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun iterateDocumentBackingInfos(documentType :String, revision :Int, includeInactive :Boolean,
			proc :(documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Unit) {
		// Iterate
		iterateDocumentBackingInfos(documentType, this.databaseManager.innerJoin(documentType),
				this.databaseManager.where(revision, includeInactive = includeInactive)) { info, _ -> proc(info) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun iterateCollection(name :String,
			proc :(documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Unit) {
		// Bring up to date
		val	collection = bringCollectionUpToDate(name)

		// Iterate
		iterateDocumentBackingInfos(collection.documentType,
				this.databaseManager.innerJoinForCollection(collection.documentType, name))
				{ documentBacking, _ -> proc(documentBacking) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun updateCollections(documentType :String, updateInfos :List<MDSUpdateInfo<Long>>,
			processNotIncluded :Boolean = true) {
		// Get collections
		val collections = this.collectionsByDocumentTypeMap.values(documentType) ?: return

		// Setup
		val	minRevision = updateInfos.minOf() { it.revision }

		// Iterate collections
		collections.forEach() {
			// Check revision state
			if ((it.lastRevision + 1) == minRevision) {
				// Update collection
				val (includedIDs, notIncludedIDs, lastRevision) = it.update(updateInfos)

				// Update database
				this.databaseManager.updateCollection(it.name, includedIDs,
						if (processNotIncluded) notIncludedIDs else listOf(), lastRevision)
			} else
				// Bring up to date
				bringUpToDate(it)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun bringCollectionUpToDate(name :String) :MDSCollection<Long> {
		// Setup
		val collection = this.collectionsByNameMap.value(name)!!

		// Bring up to date
		bringUpToDate(collection)

		return collection
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun bringUpToDate(collection :MDSCollection<Long>) {
		// Setup
		val documentInfo = this.documentInfoMap.value(collection.documentType)!!
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())

		// Collect infos
		val	bringUpToDateInfos = ArrayList<MDSBringUpToDateInfo<Long>>()
		iterateDocumentBackingInfos(collection.documentType, collection.lastRevision, false) {
			// Query batch info
			val	batchDocumentInfo = batchInfo?.documentInfo(it.documentID)

			// Ensure we want to process this document
			if ((batchDocumentInfo == null) || !batchDocumentInfo.removed)
				// Append info
				bringUpToDateInfos.add(
						MDSBringUpToDateInfo(documentInfo.create(it.documentID, this),
								it.documentBacking.revision, it.documentBacking.id))
		}

		// Bring up to date
		val	(includedIDs, notIncludedIDs, lastRevision) = collection.bringUpToDate(bringUpToDateInfos)

		// Update database
		this.databaseManager.updateCollection(collection.name, includedIDs, notIncludedIDs, lastRevision)
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun removeFromCollections(documentType :String, documentBackingIDs :List<Long>) {
		// Iterate all collections for this document type
		this.collectionsByDocumentTypeMap.values(documentType)?.forEach()
				{ this.databaseManager.updateCollection(it.name, listOf(), documentBackingIDs, it.lastRevision) }
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun iterateIndex(name :String, keys :List<String>,
			proc :(key :String, documentBackingInfo :MDSDocument.BackingInfo<MDSSQLiteDocumentBacking>) -> Unit) {
		// Bring up to date
		val index = bringIndexUpToDate(name)

		// Iterate
		iterateDocumentBackingInfos(index.documentType,
				this.databaseManager.innerJoinForIndex(index.documentType, name),
				this.databaseManager.whereForIndexKeys(keys)) { documentBackingInfo, resultsRow ->
					// Call proc
					proc(MDSSQLiteDatabaseManager.indexContentsKey(resultsRow), documentBackingInfo)
				}
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun updateIndexes(documentType :String, updateInfos :List<MDSUpdateInfo<Long>>) {
		// Get indexes
		val indexes = this.indexesByDocumentTypeMap.values(documentType) ?: return

		// Setup
		val minRevision = updateInfos.minOf() { it.revision }

		// Iterate indexes
		indexes.forEach() {
			// Check revision state
			if ((it.lastRevision + 1) == minRevision) {
				// Update index
				val (keysInfos, lastRevision) = it.update(updateInfos)

				// Update database
				this.databaseManager.updateIndex(it.name, keysInfos, listOf(), lastRevision)
			} else
				// Bring up to date
				bringUpToDate(it)
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun bringIndexUpToDate(name :String) : MDSIndex<Long> {
		// Setup
		val index = this.indexesByNameMap.value(name)!!

		// Bring up to date
		bringUpToDate(index)

		return index
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun bringUpToDate(index :MDSIndex<Long>) {
		// Setup
		val documentInfo = this.documentInfoMap.value(index.documentType)!!
		val	batchInfo = this.batchInfoMap.value(Thread.currentThread())

		// Collect infos
		val	bringUpToDateInfos = ArrayList<MDSBringUpToDateInfo<Long>>()
		iterateDocumentBackingInfos(index.documentType, index.lastRevision, false) {
			// Query batch info
			val	batchDocumentInfo = batchInfo?.documentInfo(it.documentID)

			// Ensure we want to process this document
			if ((batchDocumentInfo == null) || !batchDocumentInfo.removed)
				// Append info
				bringUpToDateInfos.add(
						MDSBringUpToDateInfo(documentInfo.create(it.documentID, this),
								it.documentBacking.revision, it.documentBacking.id))
		}

		// Bring up to date
		val (keysInfos, lastRevision) = index.bringUpToDate(bringUpToDateInfos)

		// Update database
		this.databaseManager.updateIndex(index.name, keysInfos, listOf(), lastRevision)
	}

	//------------------------------------------------------------------------------------------------------------------
	private fun removeFromIndexes(documentType :String, documentBackingIDs :List<Long>) {
		// Iterate all indexes for this documewnt type
		this.indexesByDocumentTypeMap.values(documentType)?.forEach()
				{ this.databaseManager.updateIndex(it.name, listOf(), documentBackingIDs, it.lastRevision) }
	}
}
