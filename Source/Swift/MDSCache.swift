//
//  MDSCache.swift
//  Mini Document Storage
//
//  Created by Stevo on 10/5/22.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSCache
public class MDSCache : Equatable {

	// MARK: ValueInfo
	public struct ValueInfo {

		// MARK: Properties
					let	valueInfo :MDSValueInfo
					let	selector :String

		fileprivate	let	proc :MDSDocument.ValueProc

		// MARK: Lifecycle methods
		//--------------------------------------------------------------------------------------------------------------
		init(valueInfo :MDSValueInfo, selector :String, proc :@escaping MDSDocument.ValueProc) {
			// Store
			self.valueInfo = valueInfo
			self.selector = selector
			
			self.proc = proc
		}
	}

	// MARK: Properties
			let	name :String
			let	documentType :String
			let	relevantProperties: Set<String>

	private	let	valueInfos :[ValueInfo]

	private	var	lastRevision :Int

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(name :String, documentType :String, relevantProperties :[String], valueInfos :[ValueInfo], lastRevision :Int) {
		// Store
		self.name = name
		self.documentType = documentType
		self.relevantProperties = Set<String>(relevantProperties)

		self.lastRevision = lastRevision

		self.valueInfos = valueInfos
	}

	// MARK: Equatable implementation
	//------------------------------------------------------------------------------------------------------------------
	public static func == (lhs :MDSCache, rhs :MDSCache) -> Bool { lhs.name == rhs.name }

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func hasValueInfo(for valueName :String) -> Bool {
		// Return first match
		self.valueInfos.first(where: { $0.valueInfo.name == valueName }) != nil
	}
	
	//------------------------------------------------------------------------------------------------------------------
	func update<U>(_ updateInfos :[MDSUpdateInfo<U>]) ->
			(valueInfoByID :[/* ID */ U : [/* Name */ String : Any]]?, lastRevision :Int?) {
		// Compose results
		var	valueInfoByID = [/* ID */ U : [/* Name */ String : Any]]()
		var	lastRevision :Int?
		updateInfos.forEach() { updateInfo in
			// Check if there is something to do
			if (updateInfo.changedProperties == nil) ||
					!self.relevantProperties.intersection(updateInfo.changedProperties!).isEmpty {
				// Collect value infos
				var	valueByName = [/* Name */ String : Any]()
				self.valueInfos.forEach() {
					// Add entry for this ValueInfo
					valueByName[$0.valueInfo.name] = $0.proc(self.documentType, updateInfo.document, $0.valueInfo.name)
				}

				// Update
				valueInfoByID[updateInfo.id] = valueByName
			}

			// Update last revision
			self.lastRevision = max(self.lastRevision, updateInfo.revision)
			lastRevision = self.lastRevision
		}

		return (!valueInfoByID.isEmpty ? valueInfoByID : nil, lastRevision)
	}
}
