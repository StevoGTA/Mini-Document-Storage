package codes.stevobrock.minidocumentstorage

//----------------------------------------------------------------------------------------------------------------------
class MDSIndex<T : Any> {

	// UpdateInfo
	data class UpdateInfoKeysInfo<T : Any>(val keys :List<String>, val value :T)
	data class UpdateInfo<T : Any>(val keysInfos :List<UpdateInfoKeysInfo<T>>, val lastRevision :Int)

	// Properties
			val	name :String
			val	documentType :String

			var	lastRevision :Int

	private	val relevantProperties :Set<String>
	private	val keysProc :(document :MDSDocument) -> List<String>

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(name :String, documentType :String, relevantProperties :List<String>, lastRevision :Int,
			keysProc :(document :MDSDocument) -> List<String>) {
		// Store
		this.name = name
		this.documentType = documentType
		this.relevantProperties = relevantProperties.toSet()

		this.lastRevision = lastRevision

		this.keysProc = keysProc
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	fun update(updateInfos :List<MDSUpdateInfo<T>>) :UpdateInfo<T> {
		// Compose results
		val	keysInfos = ArrayList<UpdateInfoKeysInfo<T>>()
		updateInfos.forEach() {
			// Check if there is something to do
			if ((it.changedProperties == null) || this.relevantProperties.intersect(it.changedProperties).isNotEmpty())
				// Update keys info
				keysInfos.add(UpdateInfoKeysInfo(this.keysProc(it.document), it.value))

			// Update last revision
			this.lastRevision = maxOf(this.lastRevision, it.revision)
		}

		return UpdateInfo(keysInfos, this.lastRevision)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun bringUpToDate(bringUpToDateInfos :List<MDSBringUpToDateInfo<T>>) :UpdateInfo<T> {
		// Compose results
		val	keysInfos = ArrayList<UpdateInfoKeysInfo<T>>()
		bringUpToDateInfos.forEach() {
			// Update keys info
			keysInfos.add(UpdateInfoKeysInfo(this.keysProc(it.document), it.value))

			// Update last revision
			this.lastRevision = maxOf(this.lastRevision, it.revision)
		}

		return UpdateInfo(keysInfos, this.lastRevision)
	}
}
