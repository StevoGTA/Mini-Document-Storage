package codes.stevobrock.minidocumentstorage

//----------------------------------------------------------------------------------------------------------------------
class MDSCollection<T : Any> {

	// UpdateInfo
	data class UpdateInfo<T : Any>(val includedValues :ArrayList<T>, val notIncludedValues :ArrayList<T>,
				val lastRevision :Int)

	// Properties
			val name :String
			val documentType :String

			var lastRevision :Int

	private	val relevantProperties :Set<String>
	private	val isIncludedProc :(document :MDSDocument) -> Boolean

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(name :String, documentType :String, relevantProperties :List<String>, lastRevision :Int,
			isIncludedProc :(document :MDSDocument) -> Boolean) {
		// Store
		this.name = name
		this.documentType = documentType
		this.relevantProperties = relevantProperties.toSet()

		this.lastRevision = lastRevision

		this.isIncludedProc = isIncludedProc
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	fun update(updateInfos :List<MDSUpdateInfo<T>>) :UpdateInfo<T> {
		// Compose results
		val	includedValues = ArrayList<T>()
		val notIncludedValues = ArrayList<T>()
		updateInfos.forEach() {
			// Check if there is something to do
			if ((it.changedProperties == null) ||
					this.relevantProperties.intersect(it.changedProperties).isNotEmpty()) {
				// Query
				if (this.isIncludedProc(it.document))
					// Included
					includedValues.add(it.value)
				else
					// Not included
					notIncludedValues.add(it.value)
			}

			// Update last revision
			this.lastRevision = maxOf(this.lastRevision, it.revision)
		}

		return UpdateInfo(includedValues, notIncludedValues, this.lastRevision)
	}

	//------------------------------------------------------------------------------------------------------------------
	fun bringUpToDate(bringUpToDateInfos :List<MDSBringUpToDateInfo<T>>) :UpdateInfo<T> {
		// Compose results
		val	includedValues = ArrayList<T>()
		val notIncludedValues = ArrayList<T>()
		bringUpToDateInfos.forEach() {
			// Query
			if (this.isIncludedProc(it.document))
				// Included
				includedValues.add(it.value)
			else
				// Not included
				notIncludedValues.add(it.value)

			// Update last revision
			this.lastRevision = maxOf(this.lastRevision, it.revision)
		}

		return UpdateInfo(includedValues, notIncludedValues, this.lastRevision)
	}
}
