//
//  MDSDocumentStorageServerBacking.swift
//  Mini Document Storage
//
//  Created by Stevo on 5/6/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageServerBacking
protocol MDSDocumentStorageServerBacking : MDSDocumentStorage {

	// MARK: Instance methods
	func newDocuments(documentType :String, documentCreateInfos :[MDSDocumentCreateInfo])
	func iterate(documentType :String, documentIDs :[String],
			proc :@escaping (_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
	func iterate(documentType :String, documentIDs :[String],
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void)
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :@escaping (_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
	func iterate(documentType :String, sinceRevision revision :Int,
			proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void)
	func updateDocuments(documentType :String, documentUpdateInfos :[MDSDocumentUpdateInfo])

	func registerCollection(named name :String, documentType :String, version :UInt, isIncludedSelector :String,
			relevantProperties :[String], info :MDSDocument.PropertyMap, isUpToDate :Bool)
	func iterateCollection(name :String, proc :@escaping (_ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
	func iterateCollection(name :String, proc :(_ documentFullInfo :MDSDocumentFullInfo) -> Void)

	func registerIndex(named name :String, documentType :String, version :UInt, keySelector :String,
			relevantProperties :[String])
	func iterateIndex(name :String, keys :[String],
			proc :@escaping (_ key :String, _ documentRevisionInfo :MDSDocumentRevisionInfo) -> Void)
	func iterateIndex(name :String, keys :[String],
			proc :(_ key :String, _ documentFullInfo :MDSDocumentFullInfo) -> Void)
}
