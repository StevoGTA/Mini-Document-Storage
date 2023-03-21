//
//  MDSCache.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/5/22.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSCache
class MDSCache : Equatable {

	// MARK: ValueInfo
	struct ValueInfo {

		// MARK: Properties
		let	name :String
		let	type :MDSValue.Type_
		let	proc :MDSDocument.ValueProc

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(valueInfo :MDSValueInfo, proc :@escaping MDSDocument.ValueProc) {
			// Store
			self.name = valueInfo.name
			self.type = valueInfo.type
			self.proc = proc
		}
	}

	// MARK: Properties
			let	name :String
			let	documentType :String
			let	relevantProperties: Set<String>

			var	lastRevision :Int

	private	let	valueInfos :[ValueInfo]

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, documentType :String, relevantProperties :[String], lastRevision :Int,
			valueInfos :[(valueInfo :MDSValueInfo, proc :MDSDocument.ValueProc)]) {
		// Store
		self.name = name
		self.documentType = documentType
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.valueInfos = valueInfos.map({ ValueInfo(valueInfo: $0, proc: $1) })
	}

	// MARK: Equatable implementation
	//------------------------------------------------------------------------------------------------------------------
	static func == (lhs :MDSCache, rhs :MDSCache) -> Bool { lhs.name == rhs.name }

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func valueInfo(for valueName :String) -> ValueInfo? { self.valueInfos.first(where: { $0.name == valueName }) }
	
	//------------------------------------------------------------------------------------------------------------------
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) ->
			(infosByID :[/* ID */ U : [/* Name */ String : MDSValue.Value]], lastRevision :Int) {
		// Compose results
		var	infosByID = [/* ID */ U : [/* Name */ String : MDSValue.Value]]()
		updateInfos.forEach() { updateInfo in
			// Collect value infos
			var	valuesByName = [/* Name */ String : MDSValue.Value]()
			self.valueInfos.forEach() {
				// Add entry for this value info
				valuesByName[$0.name] = $0.proc(updateInfo.document, $0.name)
			}

			infosByID[updateInfo.id] = valuesByName

			// Update last revision
			self.lastRevision = max(self.lastRevision, updateInfo.revision)
		}

		return (infosByID, self.lastRevision)
	}
}
