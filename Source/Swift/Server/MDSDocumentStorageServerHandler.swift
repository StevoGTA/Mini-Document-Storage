//
//  MDSDocumentStorageServerHandler.swift
//  Mini Document Storage
//
//  Created by Stevo on 5/6/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageServerHandler
protocol MDSDocumentStorageServerHandler : MDSDocumentStorage {

	// MARK: Instance methods
	func newDocuments(documentType :String, documentCreateInfos :[MDSDocumentCreateInfo])
	func iterate(documentType :String, documentIDs :[String],
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void)
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void)
	func updateDocuments(documentType :String, documentUpdateInfos :[MDSDocumentUpdateInfo])

	func registerCollection(named name :String, documentType :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, isIncludedSelector :String, isIncludedSelectorInfo :[String : Any]) ->
			(documentLastRevision: Int, collectionLastDocumentRevision: Int)
	func iterateCollection(name :String, proc :@escaping (_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)

	func registerIndex(named name :String, documentType :String, version :UInt, relevantProperties :[String],
			isUpToDate :Bool, keysSelector :String, keysSelectorInfo :[String : Any]) ->
			(documentLastRevision: Int, collectionLastDocumentRevision: Int)
	func iterateIndex(name :String, keys :[String],
			proc :@escaping (_ key :String, _ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
}
