//
//  MDSClient.js
//
//  Created by Stevo on 5/18/2022.
//  Copyright © 2022 Stevo Brock. All rights reserved.
//

// Imports
let	PQueue = require('p-queue').default;
// import PQueue from 'p-queue';

//----------------------------------------------------------------------------------------------------------------------
// MDSClient
class MDSClient {

	// Lifecycle methods
	//------------------------------------------------------------------------------------------------------------------
	constructor(urlBase, documentStorageID, headers, concurrentRequestLimit = 4) {
		// Store
		this.urlBase = urlBase;
		this.documentStorageID = documentStorageID;
		this.headers = headers || {};

		// Setup
		this.queue = new PQueue({concurrency: concurrentRequestLimit});
	}

	// Instance methods
	//------------------------------------------------------------------------------------------------------------------
	setDocumentStorageID(documentStorageID) { this.documentStorageID = documentStorageID; }

	//------------------------------------------------------------------------------------------------------------------
	setHeaders(headers) { this.headers = headers || {}; }

	//------------------------------------------------------------------------------------------------------------------
	async queueGET(subPath) {
		// Setup
		let	url = this.urlBase + subPath;
		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return response;
	}

	//------------------------------------------------------------------------------------------------------------------
	async queuePATCH(subPath, bodyObject) {
		// Setup
		let	url = this.urlBase + subPath;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {method: 'PATCH', headers: headers};
		if (bodyObject)
			options.body = JSON.stringify(bodyObject);

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return response;
	}

	//------------------------------------------------------------------------------------------------------------------
	async queuePOST(subPath, bodyObject) {
		// Setup
		let	url = this.urlBase + subPath;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {method: 'POST', headers: headers, body: JSON.stringify(bodyObject)};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return response;
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationRegister(name, fromDocumentType, toDocumentType, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
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
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationUpdate(name, updates, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {method: 'PUT', headers: headers, body: JSON.stringify(updates)};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfos(name, startIndex, count, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		
		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name);
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfosFrom(name, document, startIndex, count, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = document.documentID.replace(/\+/g, '%2B');
		
		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fromID=' + encodeURIComponent(documentID) + '&fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentsFrom(name, document, startIndex, count, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = document.documentID.replace(/\+/g, '%2B');
		
		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fromID=' + encodeURIComponent(documentID) + '&fullInfo=1';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
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
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?toID=' + encodeURIComponent(documentID) + '&fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentsTo(name, document, startIndex, count, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = document.documentID.replace(/\+/g, '%2B');
		
		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?toID=' + encodeURIComponent(documentID) + '&fullInfo=1';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		// Decode
		let	infos = await response.json();

		return infos.map(info => documentCreationProc(info));
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetValue(name, action, fromDocument, cacheName, cachedValueName, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentID = fromDocument.documentID.replace(/\+/g, '%2B');
		
		let	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '/' + action +
							'?fromID=' + encodeURIComponent(fromDocument.documentID) +
							'&cacheName=' + encodeURIComponent(cacheName) +
							'&cachedValueName=' + encodeURIComponent(cachedValueName);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {headers: headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return parseInt(await response.text());
	}

	//------------------------------------------------------------------------------------------------------------------
	async cacheRegister(name, documentType, relevantProperties, valueInfos, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/cache/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
					{
						method: 'PUT',
						headers: headers,
						body:
								JSON.stringify(
										{
											'name': name,
											'documentType': documentType,
											'relevantProperties': relevantProperties,
											'valueInfos': valueInfos,
										}),
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionRegister(name, documentType, relevantProperties, isUpToDate, isIncludedSelector,
			isIncludedSelectorInfo, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
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
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocumentCount(name, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name);
		let	options = {method: 'HEAD', headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		if (!response.ok)
			// Some error, but no additional info
			throw new Error('Unable to get count');

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

		let	url =
					this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocuments(name, startIndex, count, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=1';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		// Decode
		let	infos = await response.json();

		return infos.map(info => documentCreationProc(info));
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentCreate(documentType, documents, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
					{
						method: 'POST',
						headers: headers,
						body: JSON.stringify(documents.map(document => document.createInfo())),
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

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

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType);
		let	options = {method: 'HEAD', headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		if (!response.ok)
			// Some error, but no additional info
			throw new Error('Unable to get count');

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
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '?sinceRevision=' + sinceRevision;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		// Decode
		let	infos = await response.json();

		return infos.map(info => documentCreationProc(info));
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetAllSinceRevision(documentType, sinceRevision, batchCount, documentCreationProc, documentStorageID,
			proc) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	urlBase =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '?count=' + batchCount + '&sinceRevision=';
		let	options = {headers: this.headers};

		var	sinceRevisionUse = sinceRevision;
		var	totalDocumentCount = null;

		// Loop until done
		for (;;) {
			// Retrieve next batch of documents
			let	response = await this.queue.add(() => fetch(urlBase + sinceRevisionUse, options));
			await processResponse(response);
		
			// Decode
			let	infos = await response.json();
			let	documents = infos.map(info => documentCreationProc(info));

			if (documents.length > 0) {
				// More Documents
				if (totalDocumentCount == null) {
					// Retrieve total count from header
					let	contentRange = response.headers.get('content-range');
					let	contentRangeParts = (contentRange || '').split('/');
					totalDocumentCount = (contentRangeParts.length == 2) ? parseInt(contentRangeParts[1]) : null;
				}

				// Call proc
				proc(documents, totalDocumentCount);

				// Update
				documents.forEach(document => sinceRevisionUse = Math.max(sinceRevisionUse, document.revision));
			} else
				// Have all Documents
				break;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGet(documentType, documentIDs, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	documentIDsUse = documentIDs.map(documentID => encodeURIComponent(documentID));

		let	options = {headers: this.headers};
		
		// Max each call at 10 documentIDs
		var	documents = [];
		for (let i = 0, length = documentIDsUse.length; i < length; i += 10) {
			// Setup
			let	documentIDsSlice = documentIDsUse.slice(i, i + 10);
			let	url = 
						this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
								encodeURIComponent(documentType) + '?id=' + documentIDsSlice.join('&id=');

			// Queue the call
			let	response = await this.queue.add(() => fetch(url, options));
			await processResponse(response);

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

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Collect updates
		let	documentsToUpdate = documents.filter(document => document.hasUpdateInfo());
		if (documentsToUpdate.length == 0)
			// No updates
			return;

		// Max each call at 50 updates
		for (let i = 0, length = documentsToUpdate.length; i < length; i += 50) {
			// Setup
			let	documentsSlice = documentsToUpdate.slice(i, i + 50);

			let	options =
						{
							method: 'PATCH',
							headers: headers,
							body: JSON.stringify(documentsSlice.map(document => document.updateInfo())),
						};

			// Queue the call
			let	response = await this.queue.add(() => fetch(url, options));
			await processResponse(response);

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
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '/' + encodeURIComponent(documentID) + '/attachment';

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = 
					{
						method: 'POST',
						headers: headers,
						body:
								JSON.stringify(
										{
											'info': info,
											'content': content,
										}),
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetAttachment(documentType, documentID, attachmentID, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '/' + encodeURIComponent(documentID) + '/attachment/' +
							encodeURIComponent(attachmentID);
		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return await response.blob();
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentUpdateAttachment(documentType, documentID, attachmentID, info, content, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '/' + encodeURIComponent(documentID) + '/attachment/' +
							encodeURIComponent(attachmentID);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
					{
						method: 'POST',
						headers: headers,
						body:
								JSON.stringify(
										{
											'info': info,
											'content': content,
										}),
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentRemoveAttachment(documentType, documentID, attachmentID, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '/' + encodeURIComponent(documentID) + '/attachment/' +
							encodeURIComponent(attachmentID);
		let	options = {method: 'DELETE', headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexRegister(name, documentType, relevantProperties, isUpToDate, keysSelector, keysSelectorInfo,
			documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/index/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
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
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocumentInfos(name, keys, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	keysUse = keys.map(key => encodeURIComponent(key));

		let	url =
					this.urlBase + '/v1/index/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=0' + '?key=' + keysUse.join('&key=');
		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocuments(name, keys, documentCreationProc, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	keysUse = keys.map(key => encodeURIComponent(key));

		let	url =
					this.urlBase + '/v1/index/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=1' + '?key=' + keysUse.join('&key=');
		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		// Decode
		let	results = await response.json();

		return Object.fromEntries(Object.entries(results).map(([k, v]) => [k, documentCreationProc(v)]));
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoGet(keys, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	keysUse = keys.map(key => encodeURIComponent(key));

		let	url =
					this.urlBase + '/v1/info/' + encodeURIComponent(documentStorageIDUse) +
							'?key=' + keysUse.join('&key=');
		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoSet(info, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/info/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {method: 'POST', headers: headers, body: JSON.stringify(info)};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async internalSet(info, documentStorageID) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/internal/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {method: 'POST', headers: headers, body: JSON.stringify(info)};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}
}

// Private methods
//----------------------------------------------------------------------------------------------------------------------
async function processResponse(response) {
	// Check status
	if (!response.ok) {
		// Catch errors
		var	info;
		try {
			// Try to get results
			info = await response.json();
		} catch (error) {
			// Don't worry about these errors
		}

		// Process results
		if (info.error)
			// Have error in response
			throw new Error('HTTP response: ' + response.status + ', error: ' + info.error);
		else if (info.message)
			// Have message in response
			throw new Error('HTTP response: ' + response.status + ', message: ' + info.message);
		else
			// Other
			throw new Error('HTTP response: ' + response.status);
	}
}

module.exports = MDSClient;
