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
	func collectionRegister(named name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedSelector :String, isIncludedSelectorInfo :[String : Any]) ->
			(documentLastRevision: Int, collectionLastDocumentRevision: Int)
	func collectionIterate(name :String, proc :@escaping (_ documentRevisionInfo :MDSDocument.RevisionInfo) -> Void)

	func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo])
	func iterate(documentType :String, documentIDs :[String],
			proc :(_ documentFullInfo :MDSDocument.FullInfo) -> Void)
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :(_ documentFullInfo :MDSDocument.FullInfo) -> Void)
	func documentUpdate(documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo])

	func indexRegister(named name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			keysSelector :String, keysSelectorInfo :[String : Any]) ->
			(documentLastRevision: Int, collectionLastDocumentRevision: Int)
	func indexIterate(name :String, keys :[String],
			proc :@escaping (_ key :String, _ documentRevisionInfo :MDSDocument.RevisionInfo) -> Void)
}
