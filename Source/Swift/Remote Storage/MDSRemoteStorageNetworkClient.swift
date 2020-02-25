//
//  MDSRemoteStorageNetworkClient.swift
//  Mini Document Storage
//
//  Created by Stevo on 2/24/20.
//  Copyright © 2020 Stevo Brock. All rights reserved.
//

//----------------------------------------------------------------------------------------------------------------------
// MARK: MDSRemoteStorageNetworkClient
public protocol MDSRemoteStorageNetworkClient {

	// MARK: Instance methods
	//------------------------------------------------------------------------------------------------------------------
	func retrieveInfo(keys :[String], completionProc :@escaping (_ map :[String : Any]?, _ error :Error?) -> Void)
	func updateInfo(info :[String : Any], completionProc :@escaping(_ error :Error?) -> Void)

	//------------------------------------------------------------------------------------------------------------------
	func createDocuments(documentType :String, infos :[[String : Any]],
			completionProc :@escaping (_ infos :[[String : Any]]?, _ error :Error?) -> Void)
	func retrieveDocuments(documentType :String, documentIDs :[String],
			completionProc :@escaping (_ infos :[[String : Any]]?, _ error :Error?) -> Void)
	func retrieveDocuments(documentType :String, sinceRevision revision :Int,
			completionProc :@escaping (_ infos :[[String : Any]]?, _ error :Error?) -> Void)
	func updateDocuments(documentType :String, infos :[(documentID :String, updatedPropertyMap :[String : Any],
			removedKeys :[String], active :Bool)],
			completionProc :@escaping (_ infos :[[String : Any]]?, _ error :Error?) -> Void)

	//------------------------------------------------------------------------------------------------------------------
	func registerCollection(name :String, documentType :String, version :UInt,
			relevantProperties :[String], info :[String : Any], isUpToDate :Bool, isIncludedSelector :String,
			completionProc :@escaping (_ info :[String : Any]?, _ error :Error?) -> Void)
	func updateCollection(name :String, documentCount :UInt,
			completionProc :@escaping (_ info :[String : Any]?, _ error :Error?) -> Void)
	func retrieveCollectionDocumentCount(name :String,
			completionProc :@escaping(_ documentCount :UInt?, _ error :Error?) -> Void)
	func retrieveCollectionDocumentInfos(name :String,
			completionProc :@escaping (_ documentInfos :[[String : Any]]?, _ error :Error?) -> Void)

	//------------------------------------------------------------------------------------------------------------------
	func registerIndex(name :String, documentType :String, version :UInt,
			relevantProperties :[String], keysSelector :String,
			completionProc :@escaping (_ info :[String : Any]?, _ error :Error?) -> Void)
	func updateIndex(name :String, documentCount :UInt,
			completionProc :@escaping (_ info :[String : Any]?, _ error :Error?) -> Void)
	func retrieveIndexDocumentInfosMap(name :String, keys :[String],
			completionProc :@escaping (_ documentInfosMap :[String : Any]?, _ error :Error?) -> Void)
}
