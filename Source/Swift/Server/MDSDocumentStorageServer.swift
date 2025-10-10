//
//  MDSDocumentStorageServer.swift
//  Mini Document Storage
//
//  Created by Stevo on 8/1/23.
//  Copyright © 2023 Stevo Brock. All rights reserved.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageServer
protocol MDSDocumentStorageServer : MDSDocumentStorageCore, MDSDocumentStorage {

	// MARK: Instance methods
	func associationGetDocumentRevisionInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo])
	func associationGetDocumentRevisionInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo])
	func associationGetDocumentFullInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentFullInfos :[MDSDocument.FullInfo])
	func associationGetDocumentFullInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, documentFullInfos :[MDSDocument.FullInfo])

	func cacheGetStatus(for name :String) throws

	func collectionGetDocumentRevisionInfos(name :String, startIndex :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo]
	func collectionGetDocumentFullInfos(name :String, startIndex :Int, count :Int?) throws -> [MDSDocument.FullInfo]

	func documentRevisionInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.RevisionInfo]
	func documentRevisionInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo]
	func documentFullInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.FullInfo]
	func documentFullInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.FullInfo]

	func documentValue(for documentType :String, documentID :String, property :String) -> Any?
	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo]

	func indexGetStatus(for name :String) throws
	func indexGetDocumentRevisionInfos(name :String, keys :[String]) throws -> [String : MDSDocument.RevisionInfo]
	func indexGetDocumentFullInfos(name :String, keys :[String]) throws -> [String : MDSDocument.FullInfo]
}
