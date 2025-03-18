//
//  MDSDocumentStorageServerObjC.swift
//  Mini Document Storage Tests
//
//  Created by Stevo on 5/22/23.
//

import Foundation

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSAssociation.Update.Action extension
fileprivate extension MDSAssociation.Update.Action {

	// MARK: Properties
	var	associationUpdateAction :MDSAssociationUpdateAction {
				switch (self) {
					case .add:		return MDSAssociationUpdateAction.add
					case .remove:	return MDSAssociationUpdateAction.remove
				}
			}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument.RevisionInfo extension
fileprivate extension MDSDocument.RevisionInfo {

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(_ documentRevisionInfo :MDSDocumentRevisionInfo) {
		// Init
		self.init(documentID: documentRevisionInfo.documentID, revision: documentRevisionInfo.revision)
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocument.FullInfo extension
fileprivate extension MDSDocument.FullInfo {

	// MARK: Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	init(_ documentFullInfo :MDSDocumentFullInfo) {
		// Init
		self.init(documentID: documentFullInfo.documentID, revision: documentFullInfo.revision,
				active: documentFullInfo.active, creationDate: documentFullInfo.creationDate,
				modificationDate: documentFullInfo.modificationDate,
				propertyMap: documentFullInfo.propertyMap as! [String : Any],
				attachmentInfoByID:
						documentFullInfo.attachmentInfoByID
								.mapValues(
										{ MDSDocument.AttachmentInfo(id: $0._id, revision: $0.revision,
												info: $0.info ) }))
	}
}

//----------------------------------------------------------------------------------------------------------------------
// MARK: - MDSDocumentStorageServerObjC
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
		var	associationItems :NSArray?
		try self.documentStorageObjC.associationGetNamed(name, outAssociationItems: &associationItems)

		return (associationItems as! [MDSAssociationItem])
				.map({ MDSAssociation.Item(fromDocumentID: $0.fromDocumentID, toDocumentID: $0.toDocumentID) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterate(for name :String, from fromDocumentID :String, toDocumentType :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationIterate(for name :String, fromDocumentType :String, to toDocumentID :String,
			proc :(_ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetValues(for name :String, action :MDSAssociation.GetValueAction, fromDocumentIDs :[String],
			cacheName :String, cachedValueNames :[String]) throws -> Any {
		// Setup
		let	associationGetValueAction :MDSAssociationGetValueAction
		switch action {
			case .detail:	associationGetValueAction = .detail
			case .sum:		associationGetValueAction = .sum
		}

		// Get values
		var	outInfo :AnyObject?
		try self.documentStorageObjC.associationGetValuesNamed(name,
				associationGetValueAction: associationGetValueAction, fromDocumentIDs: fromDocumentIDs,
				cacheName: cacheName, cachedValueNames: cachedValueNames, outInfo: &outInfo)

		return outInfo!
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationUpdate(for name :String, updates :[MDSAssociation.Update]) throws {
		// Update association
		try self.documentStorageObjC.associationUpdateNamed(name,
				associationUpdates:
						updates.map({
							MDSAssociationUpdate(action: $0.action.associationUpdateAction,
									fromDocumentID: $0.item.fromDocumentID, toDocumentID: $0.item.toDocumentID) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	func cacheRegister(name :String, documentType :String, relevantProperties :[String],
			cacheValueInfos :[(valueInfo :MDSValueInfo, selector :String)]) throws {
		// Register cache
		try self.documentStorageObjC.cacheRegisterNamed(name, documentType: documentType,
				relevantProperties: relevantProperties,
				cacheValueInfos:
						cacheValueInfos
								.map({
									// Setup
									var	valueType :ObjCMDSValueType
									switch $0.valueInfo.type {
										case .integer:	valueType = .integer
									}

									return MDSCacheValueInfo(
										valueInfo:
												ObjCMDSValueInfo(name: $0.valueInfo.name, valueType: valueType),
										documentValueInfo: MDSDocumentValueInfo(selector: $0.selector))
								}))
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionRegister(name :String, documentType :String, relevantProperties :[String], isUpToDate :Bool,
			isIncludedInfo :[String : Any], isIncludedSelector :String,
			documentIsIncludedProc :@escaping MDSDocument.IsIncludedProc, checkRelevantProperties :Bool) throws {
		// Register collection
		try self.documentStorageObjC.collectionRegisterNamed(name, documentType: documentType,
				relevantProperties: relevantProperties, isUpToDate: isUpToDate, isIncludedInfo: isIncludedInfo,
				isIncludedSelector: isIncludedSelector, checkRelevantProperties: checkRelevantProperties)
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentCount(for name :String) throws -> Int {
		// Get document count
		var	documentCount :UInt = 0
		try self.documentStorageObjC.collectionGetDocumentCountNamed(name, outDocumentCount: &documentCount)

		return Int(documentCount)
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
				outDocumentOverviewInfos: &documentOverviewInfos)

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
		// Get count
		var	count :UInt = 0
		try self.documentStorageObjC.documentGetCountDocumentType(documentType, outCount: &count)

		return Int(count)
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
		// Add Attachment
		var	documentAttachmentInfo :MDSDocumentAttachmentInfo?
		try self.documentStorageObjC.documentAttachmentAddDocumentType(documentType, documentID: documentID, info: info,
				content: content, outDocumentAttachmentInfo: &documentAttachmentInfo)

		return MDSDocument.AttachmentInfo(id: documentAttachmentInfo!._id, revision: documentAttachmentInfo!.revision,
				info: documentAttachmentInfo!.info)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentInfoByID(for documentType :String, documentID :String) throws ->
			MDSDocument.AttachmentInfoByID {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentContent(for documentType :String, documentID :String, attachmentID :String) throws -> Data {
		// Get Attachment Content
		var	data :NSData?
		try self.documentStorageObjC.documentAttachmentContentDocumentType(documentType, documentID: documentID,
				attachmentID: attachmentID, outData: &data)

		return data! as Data
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentUpdate(for documentType :String, documentID :String, attachmentID :String,
			updatedInfo :[String : Any], updatedContent :Data) throws -> Int? {
		// Update
		var	revision :NSInteger = 0
		try self.documentStorageObjC.documentAttachmentUpdateDocumentType(documentType, documentID: documentID,
				attachmentID: attachmentID, updatedInfo: updatedInfo, updatedContent: updatedContent,
				outRevision: &revision)

		return revision as Int
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentAttachmentRemove(for documentType :String, documentID :String, attachmentID :String) throws {
		// Remove
		try self.documentStorageObjC.documentAttachmentRemoveDocumentType(documentType, documentID: documentID,
				attachmentID: attachmentID)
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRemove(_ document :MDSDocument) {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexRegister(name :String, documentType :String, relevantProperties :[String], keysInfo :[String : Any],
			keysSelector :String, keysProc :@escaping MDSDocument.KeysProc) throws {
		// Register collection
		try self.documentStorageObjC.indexRegisterNamed(name, documentType: documentType,
				relevantProperties: relevantProperties, keysInfo: keysInfo, keysSelector: keysSelector)
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexIterate(name :String, documentType :String, keys :[String],
			proc :(_ key :String, _ document :MDSDocument) -> Void) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoGet(for keys :[String]) throws -> [String : String] {
		// Get info
		var	info :NSDictionary?
		try self.documentStorageObjC.infoGetKeys(keys, outInfo: &info);

		return info as! [String : String]
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoSet(_ info :[String : String]) throws {
		// Set info
		try self.documentStorageObjC.infoSet(info)
	}

	//------------------------------------------------------------------------------------------------------------------
	func infoRemove(keys :[String]) throws {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func internalGet(for keys :[String]) -> [String : String] {
		fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func internalSet(_ info :[String : String]) throws {
		// Set info
		try self.documentStorageObjC.internalSet(info)
	}

	//------------------------------------------------------------------------------------------------------------------
	func batch(_ proc :() throws -> MDSBatchResult) rethrows {
		fatalError("Unimplemented")
	}

	// MARK: MDSDocumentStorageServer methods
	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
		// Get info
		var	totalCount :NSInteger = 0
		var	documentRevisionInfos :NSArray?
		try self.documentStorageObjC.associationGetDocumentRevisionInfos(withTotalCountNamed: name,
				fromDocumentID: fromDocumentID, start: startIndex, count: count as NSNumber?, totalCount: &totalCount,
				outDocumentRevisionInfos: &documentRevisionInfos)

		return (totalCount,
				(documentRevisionInfos as! [MDSDocumentRevisionInfo])
						.map({ MDSDocument.RevisionInfo(documentID: $0.documentID, revision: $0.revision) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentRevisionInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentRevisionInfos :[MDSDocument.RevisionInfo]) {
		// Get info
		var	totalCount :NSInteger = 0
		var	documentRevisionInfos :NSArray?
		try self.documentStorageObjC.associationGetDocumentRevisionInfos(withTotalCountNamed: name,
				toDocumentID: toDocumentID, start: startIndex, count: count as NSNumber?, totalCount: &totalCount,
				outDocumentRevisionInfos: &documentRevisionInfos)

		return (totalCount,
				(documentRevisionInfos as! [MDSDocumentRevisionInfo])
						.map({ MDSDocument.RevisionInfo(documentID: $0.documentID, revision: $0.revision) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, from fromDocumentID :String, startIndex :Int, count :Int?)
			throws -> (totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
		// Get info
		var	totalCount :NSInteger = 0
		var	documentFullInfos :NSArray?
		try self.documentStorageObjC.associationGetDocumentFullInfos(withTotalCountNamed: name,
				fromDocumentID: fromDocumentID, start: startIndex, count: count as NSNumber?, totalCount: &totalCount,
				outDocumentFullInfos: &documentFullInfos)

		return (totalCount, (documentFullInfos as! [MDSDocumentFullInfo]).map({ MDSDocument.FullInfo($0) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	func associationGetDocumentFullInfos(name :String, to toDocumentID :String, startIndex :Int, count :Int?) throws ->
			(totalCount :Int, documentFullInfos :[MDSDocument.FullInfo]) {
		// Get info
		var	totalCount :NSInteger = 0
		var	documentFullInfos :NSArray?
		try self.documentStorageObjC.associationGetDocumentFullInfos(withTotalCountNamed: name,
				toDocumentID: toDocumentID, start: startIndex, count: count as NSNumber?, totalCount: &totalCount,
				outDocumentFullInfos: &documentFullInfos)

		return (totalCount, (documentFullInfos as! [MDSDocumentFullInfo]).map({ MDSDocument.FullInfo($0) }))
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentRevisionInfos(name :String, startIndex :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
		// Get info
		var	documentRevisionInfos :NSArray?
		try self.documentStorageObjC.collectionGetDocumentRevisionInfosNamed(name, start: startIndex,
				count: count as NSNumber?, outDocumentRevisionInfos: &documentRevisionInfos)

		return (documentRevisionInfos as! [MDSDocumentRevisionInfo])
				.map({ MDSDocument.RevisionInfo(documentID: $0.documentID, revision: $0.revision) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func collectionGetDocumentFullInfos(name :String, startIndex :Int, count :Int?) throws -> [MDSDocument.FullInfo] {
		// Get info
		var	documentFullInfos :NSArray?
		try self.documentStorageObjC.collectionGetDocumentFullInfosNamed(name, start: startIndex,
				count: count as NSNumber?, outDocumentFullInfos: &documentFullInfos)

		return (documentFullInfos as! [MDSDocumentFullInfo]).map({ MDSDocument.FullInfo($0) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRevisionInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.RevisionInfo] {
		// Get info
		var	documentRevisionInfos :NSArray?
		try self.documentStorageObjC.documentRevisionInfosDocumentType(documentType, documentIDs: documentIDs,
				outDocumentRevisionInfos: &documentRevisionInfos)

		return (documentRevisionInfos as! [MDSDocumentRevisionInfo]).map({ MDSDocument.RevisionInfo($0) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentRevisionInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.RevisionInfo] {
		// Get info
		var	documentRevisionInfos :NSArray?
		try self.documentStorageObjC.documentRevisionInfosDocumentType(documentType, sinceRevision: sinceRevision,
				count: count as NSNumber?, outDocumentRevisionInfos: &documentRevisionInfos)

		return (documentRevisionInfos as! [MDSDocumentRevisionInfo]).map({ MDSDocument.RevisionInfo($0) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentFullInfos(for documentType :String, documentIDs :[String]) throws -> [MDSDocument.FullInfo] {
		// Get info
		var	documentFullInfos :NSArray?
		try self.documentStorageObjC.documentFullInfosDocumentType(documentType, documentIDs: documentIDs,
				outDocumentFullInfos: &documentFullInfos)

		return (documentFullInfos as! [MDSDocumentFullInfo]).map({ MDSDocument.FullInfo($0) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentFullInfos(for documentType :String, sinceRevision :Int, count :Int?) throws ->
			[MDSDocument.FullInfo] {
		// Get info
		var	documentFullInfos :NSArray?
		try self.documentStorageObjC.documentFullInfosDocumentType(documentType, sinceRevision: sinceRevision,
				count: count as NSNumber?, outDocumentFullInfos: &documentFullInfos)

		return (documentFullInfos as! [MDSDocumentFullInfo]).map({ MDSDocument.FullInfo($0) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentValue(for documentType :String, documentID :String, property :String) -> Any? {
// TODO
fatalError("Unimplemented")
	}

	//------------------------------------------------------------------------------------------------------------------
	func documentUpdate(for documentType :String, documentUpdateInfos :[MDSDocument.UpdateInfo]) throws ->
			[MDSDocument.FullInfo] {
		// Update
		var	documentFullInfos :NSArray?
		try self.documentStorageObjC.documentUpdateDocumentType(documentType,
				documentUpdateInfos:
						documentUpdateInfos.map(
								{ MDSDocumentUpdateInfo(documentID: $0.documentID, updated: $0.updated,
										removed: $0.removed, active: $0.active) }),
				outDocumentFullInfos: &documentFullInfos)

		return (documentFullInfos as! [MDSDocumentFullInfo]).map({ MDSDocument.FullInfo($0) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentRevisionInfos(name :String, keys :[String]) throws -> [String : MDSDocument.RevisionInfo] {
		// Get Document Revision Infos
		var	documentRevisionInfoDictionary :NSDictionary?
		try self.documentStorageObjC.indexGetDocumentRevisionInfosNamed(name, keys: keys,
				outDocumentRevisionInfoDictionary: &documentRevisionInfoDictionary)

		return (documentRevisionInfoDictionary as! [String : MDSDocumentRevisionInfo])
				.mapValues({ MDSDocument.RevisionInfo($0) })
	}

	//------------------------------------------------------------------------------------------------------------------
	func indexGetDocumentFullInfos(name :String, keys :[String]) throws -> [String : MDSDocument.FullInfo] {
		// Get Document Full Infos
		var	documentFullInfoDictionary :NSDictionary?
		try self.documentStorageObjC.indexGetDocumentFullInfosNamed(name, keys: keys,
				outDocumentFullInfoDictionary: &documentFullInfoDictionary)

		return (documentFullInfoDictionary as! [String : MDSDocumentFullInfo]).mapValues({ MDSDocument.FullInfo($0) })
	}
}
