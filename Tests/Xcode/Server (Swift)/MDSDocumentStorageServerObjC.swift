//
//  MDSDocumentStorageServerObjC.swift
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/22/23.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSDocumentStorageServerObjC
class MDSDocumentStorageServerObjC : MDSDocumentStorageCore, MDSDocumentStorageServer {

	// MARK: Properties
	private	let	documentStorageObjC :MDSDocumentStorageObjC

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(documentStorageObjC :MDSDocumentStorageObjC) {
		// Store
		self.documentStorageObjC = documentStorageObjC

		// Do super
		super.init()
	}

	// MARK: MDSDocumentStorage methods
	//------------------------------------------------------------------------------------------------------------------
	func associationRegister(named name :String, fromDocumentType :String, toDocumentType :String) throws {
		// Register association
		try self.documentStorageObjC.associationRegisterNamed(name, fromDocumenType: fromDocumentType,
				toDocumentType: toDocumentType)
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGet(for name :String) throws -> [MDSAssociation.Item] {
		// Get association items
//		var	associationItems :NSArray?
//		try self.documentStorageObjC.associationGet(name, associationItems: &associationItems)
//
//		return (associationItems as! [MDSAssociationItem]).map(
//				{ MDSAssociation.Item(fromDocumentID: $0.fromDocumentID, toDocumentID: $0.toDocumentID) })
return []
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterate(for name :String, to toDocumentID :String, fromDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetIntegerValues(for name :String, action :MDSAssociation.GetIntegerValueAction,
			fromDocumentIDs :[String], cacheName :String, cachedValueNames :[String]) throws -> [String : Int64] {
// TODO
return [:]
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
// TODO
	}

	//------------------------------------------------------------------------------------------------------------------
	func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			valueInfos :[MDSCache.ValueInfo]) throws {
// TODO
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String,
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc) throws {
// TODO
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentCount(for name :String) throws -> Int {
// TODO
return 0
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionIterate(name :String, documentType :String, proc :(_ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentCreate(documentType :String, documentCreateInfos :[MDSDocument.CreateInfo],
			proc :MDSDocument.CreateProc) throws ->
			[(document :MDSDocument, documentOverviewInfo :MDSDocument.OverviewInfo?)] {
		// Create documents
		var	documentOverviewInfos :NSArray?
		try self.documentStorageObjC.documentCreateDocumentType(documentType,
				documentCreateInfos:
						documentCreateInfos.map(
								{ MDSDocumentCreateInfo(documentID: $0.documentID, creationDate: $0.creationDate,
										modificationDate: $0.modificationDate, propertyMap: $0.propertyMap) }),
				documentOverviewInfos: &documentOverviewInfos)

		return documentOverviewInfos!.map({
			// Setup
			let	documentOverViewInfo = $0 as! MDSDocumentOverviewInfo

			return (MDSDocument(id: documentOverViewInfo.documentID, documentStorage: self),
						MDSDocument.OverviewInfo(documentID: documentOverViewInfo.documentID,
								revision: documentOverViewInfo.revision,
								creationDate: documentOverViewInfo.creationDate,
								modificationDate: documentOverViewInfo.modificationDate))
		})
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentGetCount(for documentType :String) throws -> Int {
// TODO
return 0
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentIterate(for documentType :String, documentIDs :[String], documentCreateProc :MDSDocument.CreateProc,
			proc :(_ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentIterate(for documentType :String, activeOnly: Bool, documentCreateProc :MDSDocument.CreateProc,
			proc :(_ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentCreationDate(for document :MDSDocument) -> Date {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentModificationDate(for document :MDSDocument) -> Date {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentValue(for property :String, of document :MDSDocument) -> Any? {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentData(for property :String, of document :MDSDocument) -> Data? {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentDate(for property :String, of document :MDSDocument) -> Date? {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentSet<T : MDSDocument>(_ value :Any?, for property :String, of document :T) {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentAdd(for documentType :String, documentID :String, info :[String : Any], content :Data) throws
			-> MDSDocument.AttachmentInfo {
// TODO
return MDSDocument.AttachmentInfo(id: "", revision: 0, info: [:])
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentInfoMap(for documentType :String, documentID :String) throws ->
			MDSDocument.AttachmentInfoMap {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws -> Data {
// TODO
return Data()
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int {
// TODO
return 0
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws {
// TODO
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRemove(_ document :MDSDocument) {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexRegister(name :String, documentType :String, relevantProperties :[String], keysInfo :[String : Any],
			keysSelector :String, keysProc :@escaping MDSDocument.KeysProc) throws {
// TODO
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoGet(for keys :[String]) -> [String : String] {
// TODO
return [:]
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoSet(_ info :[String : String]) {
// TODO
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoRemove(keys :[String]) {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func internalGet(for keys :[String]) -> [String : String] {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func internalSet(_ info :[String : String]) {
// TODO
	}

	//------------------------------------------------------------------------------------------------------------------
	func batch(_ proc :() throws -> MDSBatch<Any>.Result) rethrows {
		fatalError("Unimplemented")
	}

	// MARK: MDSDocumentStorageServer methods
	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
// TODO
return (0, [])
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
// TODO
return (0, [])
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
// TODO
return (0, [])
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
// TODO
return (0, [])
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentRevisionInfos(name :String, startIndex :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
// TODO
return []
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentFullInfos(name :String, startIndex :Int, count :Int?) throws -> [MDSDocument.FullInfo] {
// TODO
return []
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRevisionInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.RevisionInfo] {
// TODO
return []
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRevisionInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
// TODO
return []
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentFullInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.FullInfo] {
// TODO
return []
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentFullInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.FullInfo] {
// TODO
return []
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentIntegerValue(for documentType :String, document :MDSDocument, property :String) -> Int64? {
// TODO
return nil
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentStringValue(for documentType :String, document :MDSDocument, property :String) -> String? {
// TODO
return nil
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo] {
// TODO
return []
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentRevisionInfos(name :String, keys :[String]) throws -> [String : MDSDocument.RevisionInfo] {
// TODO
return [:]
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentFullInfos(name :String, keys :[String]) throws -> [String : MDSDocument.FullInfo] {
// TODO
return [:]
	}
}
