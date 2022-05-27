//
//  MDSClient.js
//
//  Created by Stevo on 5/18/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
// let fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args));

//----------------------------------------------------------------------------------------------------------------------
// MDSClient
module.exports = class MDSClient {

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(urlBase, documentStorageID, headers) {
		// Store
		this.urlBase = urlBase;
		this.documentStorageID = documentStorageID;
		this.headers = headers || {};
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	async associationRegister(name, fromDocumentType, toDocumentType, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/association/' + documentStorageIDUse;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'PUT',
								headers: headers,
								body:
										JSON.stringify(
												{
													'name': name,
													'fromDocumentType': fromDocumentType,
													'toDocumentType': toDocumentType,
												}),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationUpdate(name, updates, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/association/' + documentStorageIDUse + '/' + name;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'PUT',
								headers: headers,
								body: JSON.stringify(updates),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfosFrom(name, document, startIndex, count, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = document.documentID.replace(/\+/g, '%2B');
		
		var	url =
					this.urlBase + '/v1/association/' + documentStorageIDUse + '/' + name + '?fromID=' + documentID +
							'&fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentsFrom(name, document, startIndex, count, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = document.documentID.replace(/\+/g, '%2B');
		
		var	url =
					this.urlBase + '/v1/association/' + documentStorageIDUse + '/' + name + '?fromID=' + documentID +
							'&fullInfo=1';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		// Decode
		let	infos = await response.json();

		return infos.map(info => documentCreationProc(info));
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfosTo(name, document, startIndex, count, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = document.documentID.replace(/\+/g, '%2B');
		
		var	url =
					this.urlBase + '/v1/association/' + documentStorageIDUse + '/' + name + '?toID=' + documentID +
							'&fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentsTo(name, document, startIndex, count, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = document.documentID.replace(/\+/g, '%2B');
		
		var	url =
					this.urlBase + '/v1/association/' + documentStorageIDUse + '/' + name + '?toID=' + documentID +
							'&fullInfo=1';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		// Decode
		let	infos = await response.json();

		return infos.map(info => documentCreationProc(info));
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetValue(name, fromDocument, action, cacheName, cacheValueName, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = fromDocument.documentID.replace(/\+/g, '%2B');
		
		let	url = this.urlBase + '/v1/association/' + documentStorageIDUse + '/' + name + '/value';

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								headers: headers,
								body:
										JSON.stringify(
												{
													'fromID': documentID,
													'action': action,
													'cacheName': cacheName,
													'cacheValueName': cacheValueName,
												}),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);

		return parseInt(await response.text());
	}

	//------------------------------------------------------------------------------------------------------------------
	async cacheRegister(name, documentType, relevantProperties, valuesInfos, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/cache/' + documentStorageIDUse;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'PUT',
								headers: headers,
								body:
										JSON.stringify(
												{
													'name': name,
													'documentType': documentType,
													'relevantProperties': relevantProperties,
													'valuesInfos': valuesInfos,
												}),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionRegister(name, documentType, relevantProperties, isUpToDate, isIncludedSelector,
			isIncludedSelectorInfo, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/collection/' + documentStorageIDUse;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'PUT',
								headers: headers,
								body:
										JSON.stringify(
												{
													'name': name,
													'documentType': documentType,
													'relevantProperties': relevantProperties,
													'isUpToDate': isUpToDate,
													'isIncludedSelector': isIncludedSelector,
													'isIncludedSelectorInfo': isIncludedSelectorInfo,
												}),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocumentCount(name, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/collection/' + documentStorageIDUse + '/' + name;

		// Make the call
		let	response = await fetch(url, {method: 'HEAD', headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);

		// Decode header
		let	contentRange = response.headers.get('content-range');
		let	contentRangeParts = (contentRange || '').split('/');
		if (contentRangeParts.length == 2)
			// Have count
			return parseInt(contentRangeParts[1]);
		else
			// Don't have count
			throw new Error('Unable to get count from response');
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocumentInfos(name, startIndex, count, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/collection/' + documentStorageIDUse + '/' + name + '?fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocuments(name, startIndex, count, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/collection/' + documentStorageIDUse + '/' + name + '?fullInfo=1';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		// Decode
		let	infos = await response.json();

		return infos.map(info => documentCreationProc(info));
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentCreate(documentType, documents, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'POST',
								headers: headers,
								body: JSON.stringify(documents.map(document => document.createInfo())),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);

		// Decode info
		let	results = await response.json();

		// Update documents
		var	documentsByID = {};
		for (let document of documents)
			// Update info
			documentsByID[document.documentID] = document;
		
		for (let result of results)
			// Update document
			documentsByID[result.documentID].updateFromCreate(result);
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetCount(documentType, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType;

		// Make the call
		let	response = await fetch(url, {method: 'HEAD', headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);

		// Decode header
		let	contentRange = response.headers.get('content-range');
		let	contentRangeParts = (contentRange || '').split('/');
		if (contentRangeParts.length == 2)
			// Have count
			return parseInt(contentRangeParts[1]);
		else
			// Don't have count
			throw new Error('Unable to get count from response');
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetSinceRevision(documentType, sinceRevision, count, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		var	url =
					this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType +
							'?sinceRevision=' + sinceRevision;
		if (count) url += '&count=' + count;

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		// Decode
		let	infos = await response.json();

		return infos.map(info => documentCreationProc(info));
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGet(documentType, documentIDs, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentIDsUse = documentIDs.map(documentID => documentID.replace('+', '%2B'));
		
		// Max each call at 10 documentIDs
		var	documents = [];
		for (let i = 0, length = documentIDsUse.length; i < length; i += 10) {
			// Setup
			let	documentIDsSlice = documentIDsUse.slice(i, i + 10);
			let	url = 
						this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType +
								'?id=' + documentIDsSlice.join('&id=');

			// Make the call
			let	response = await fetch(url, {headers: this.headers});
			if (!response.ok) throw new Error('HTTP error: ' + response.status);

			// Decode
			let	infos = await response.json();

			// Add documents
			documents = documents.concat(infos.map(info => documentCreationProc(info)));
		}

		return documents;
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentUpdate(documentType, documents, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Max each call at 100 updates
		for (let i = 0, length = documents.length; i < length; i += 100) {
			// Setup
			let	documentsSlice = documents.slice(i, i + 100);

			// Make the call
			let	response =
						await fetch(url,
								{
									method: 'PATCH',
									headers: headers,
									body: JSON.stringify(documentsSlice.map(document => document.updateInfo())),
								});
			if (!response.ok) throw new Error('HTTP error: ' + response.status);

			// Decode info
			let	results = await response.json();

			// Update documents
			var	documentsByID = {};
			for (let document of documentsSlice)
				// Update info
				documentsByID[document.documentID] = document;
			
			for (let result of results)
				// Update document
				documentsByID[result.documentID].updateFromUpdate(result);
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAddAttachment(documentType, documentID, info, content, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType + '/' + documentID +
							'/attachment';

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'POST',
								headers: headers,
								body:
										JSON.stringify(
												{
													'info': info,
													'content': content,
												}),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);

		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetAttachment(documentType, documentID, attachmentID, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType + '/' + documentID +
							'/attachment/' + attachmentID;

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);

		return await response.blob();
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentUpdateAttachment(documentType, documentID, attachmentID, info, content, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType + '/' + documentID +
							'/attachment/' + attachmentID;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'POST',
								headers: headers,
								body:
										JSON.stringify(
												{
													'info': info,
													'content': content,
												}),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentRemoveAttachment(documentType, documentID, attachmentID, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + documentStorageIDUse + '/' + documentType + '/' + documentID +
							'/attachment/' + attachmentID;

		// Make the call
		let	response = await fetch(url, {method: 'DELETE', headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexRegister(name, documentType, relevantProperties, isUpToDate, keysSelector, keysSelectorInfo,
			documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/index/' + documentStorageIDUse;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'PUT',
								headers: headers,
								body:
										JSON.stringify(
												{
													'name': name,
													'documentType': documentType,
													'relevantProperties': relevantProperties,
													'isUpToDate': isUpToDate,
													'keysSelector': keysSelector,
													'keysSelectorInfo': keysSelectorInfo,
												}),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocumentInfos(name, keys, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/index/' + documentStorageIDUse + '/' + name + '?fullInfo=0' +
							'?key=' + keys.join('&key=');

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocuments(name, keys, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/index/' + documentStorageIDUse + '/' + name + '?fullInfo=1' +
							'?key=' + keys.join('&key=');


		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		// Decode
		let	results = await response.json();

		return Object.fromEntries(Object.entries(results).map(([k, v]) => [k, documentCreationProc(v)]));
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoGet(keys, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/info/' + documentStorageIDUse + '?key=' + keys.join('&key=');

		// Make the call
		let	response = await fetch(url, {headers: this.headers});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoSet(info, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/info/' + documentStorageIDUse;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Make the call
		let	response =
					await fetch(url,
							{
								method: 'POST',
								headers: headers,
								body: JSON.stringify(info),
							});
		if (!response.ok) throw new Error('HTTP error: ' + response.status);
	}
}
