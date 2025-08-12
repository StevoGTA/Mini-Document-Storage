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
	async queueDELETE(subPath, headers = {}) {
		// Setup
		let	url = this.urlBase + subPath;
		let	options = {method: 'DELETE', headers: {...this.headers, ...headers}};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return response;
	}

	//------------------------------------------------------------------------------------------------------------------
	async queueGET(subPath, headers = {}) {
		// Setup
		let	url = this.urlBase + subPath;
		let	options = {headers: {...this.headers, ...headers}};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return response;
	}

	//------------------------------------------------------------------------------------------------------------------
	async queuePATCH(subPath, body, headers = {}) {
		// Setup
		let	url = this.urlBase + subPath;

		let	headersUse = {...this.headers, ...headers};
		let	options = {method: 'PATCH', headers: headersUse};
		if ((body instanceof File) || (body instanceof ArrayBuffer)) {
			// Pass through
			headersUse['Content-Type'] = 'application/octet-stream';
			options.body = body;
		} else if (typeof body == 'object') {
			// Object
			headersUse['Content-Type'] = 'application/json';
			options.body = JSON.stringify(body);
		} else {
			// Pass through
			headersUse['Content-Type'] = 'application/octet-stream';
			options.body = body;
		}

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return response;
	}

	//------------------------------------------------------------------------------------------------------------------
	async queuePOST(subPath, body, headers = {}) {
		// Setup
		let	url = this.urlBase + subPath;

		let	headersUse = {...this.headers, ...headers};

		let	options = {method: 'POST', headers: headersUse};
		if ((body instanceof File) || (body instanceof ArrayBuffer)) {
			// Pass through
			headersUse['Content-Type'] = 'application/octet-stream';
			options.body = body;
		} else if (typeof body == 'object') {
			// Object
			headersUse['Content-Type'] = 'application/json';
			options.body = JSON.stringify(body);
		} else {
			// Pass through
			headersUse['Content-Type'] = 'application/octet-stream';
			options.body = body;
		}

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return response;
	}

	//------------------------------------------------------------------------------------------------------------------
	async queuePUT(subPath, body, headers = {}) {
		// Setup
		let	url = this.urlBase + subPath;

		let	headersUse = {...this.headers, ...headers};
		let	options = {method: 'PUT', headers: headersUse};
		if ((body instanceof File) || (body instanceof ArrayBuffer)) {
			// Pass through
			headersUse['Content-Type'] = 'application/octet-stream';
			options.body = body;
		} else if (typeof body == 'object') {
			// Object
			headersUse['Content-Type'] = 'application/json';
			options.body = JSON.stringify(body);
		} else {
			// Pass through
			headersUse['Content-Type'] = 'application/octet-stream';
			options.body = body;
		}

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		return response;
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationRegister(name, fromDocumentType, toDocumentType, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
					{
						method: 'PUT',
						headers,
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
	async associationUpdate(name, updates, documentStorageID = null) {
		// Check if have updates
		if (updates.length == 0)
			// No updates
			return;

		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {method: 'PUT', headers, body: JSON.stringify(updates)};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfos(name, startIndex, count, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		
		var	queryParameters = [];
		if (startIndex) queryParameters.push("startIndex=" + startIndex);
		if (count) queryParameters.push("count=" + count)

		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name);
		if (queryParameters)
			// Add query parameters
			url += "?" + queryParameters.join("&")

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfosFrom(name, document, startIndex, count, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		
		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fromID=' + encodeURIComponent(document.documentID) +
							'&fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentsFrom(name, document, startIndex, count, documentCreationProc,
			documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		
		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fromID=' + encodeURIComponent(document.documentID) +
							'&fullInfo=1';
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
	async associationGetDocumentMapFrom(name, documents, documentType, documentCreationProc, documentStorageID = null,
			individualRetrievalThreshold = 5) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		var	toDocumentsByFromDocumentID = {};

		// Check how many documents in play
		if (documents.length <= individualRetrievalThreshold)
			// Retrieve associations for each document
			for (let document of documents)
				// Retrieve "to" documents for this "from" document
				toDocumentsByFromDocumentID[document.documentID] =
						await this.associationGetDocumentsFrom(name, document, 0, null, documentCreationProc,
								documentStorageIDUse);
		else {
			// Retrieve all document infos and go from there
			let	results = await this.associationGetDocumentInfos(name, 0, null, documentStorageIDUse);

			// Compose "to" info for those "from" document IDs of interest
			let	fromDocumentIDs = new Set(documents.map(document => document.documentID));
			let	toDocumentIDs = new Set();
			let	toDocumentIDsByFromDocumentID = {};
			for (let result of results) {
				// Check if this "from" document is of interest
				let	fromDocumentID = result.fromDocumentID;
				if (fromDocumentIDs.has(fromDocumentID)) {
					// Get info
					let	toDocumentID = result.toDocumentID;

					// Update stuffs
					toDocumentIDs.add(toDocumentID);
					if (toDocumentIDsByFromDocumentID[fromDocumentID])
						// Anther "to" document
						toDocumentIDsByFromDocumentID[fromDocumentID].push(toDocumentID);
					else
						// First "to" document
						toDocumentIDsByFromDocumentID[fromDocumentID] = [toDocumentID];
				}
			}

			// Retrieve "to" documents of interest and create object based on document ID
			let	toDocuments =
						await this.documentGet(documentType, [...toDocumentIDs], documentCreationProc,
								documentStorageIDUse);
			let	toDocumentByDocumentID = {};
			for (let toDocument of toDocuments)
				// Update object
				toDocumentByDocumentID[toDocument.documentID] = toDocument;
			
			// Compose final object
			for (let fromDocumentID of fromDocumentIDs) {
				// Update final object
				let	toDocumentIDs = toDocumentIDsByFromDocumentID[fromDocumentID] || [];
				toDocumentsByFromDocumentID[fromDocumentID] =
						toDocumentIDs.map(toDocumentID => toDocumentByDocumentID[toDocumentID]);
			}
		}

		return toDocumentsByFromDocumentID;
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentInfosTo(name, document, startIndex, count, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		
		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?toID=' + encodeURIComponent(document.documentID) +
							'&fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	
		return await response.json();
	}

	//------------------------------------------------------------------------------------------------------------------
	async associationGetDocumentsTo(name, document, startIndex, count, documentCreationProc, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		
		var	url =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?toID=' + encodeURIComponent(document.documentID) +
							'&fullInfo=1';
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
	async associationGetValue(name, action, fromDocuments, cacheName, cachedValueNames, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	fromDocumentIDs = fromDocuments.map(document => encodeURIComponent(document.documentID));
		let	cachedValueNameQuery =
					cachedValueNames.map(
							cachedValueName => 'cachedValueName=' + encodeURIComponent(cachedValueName)).join('&');
		
		let	urlBase =
					this.urlBase + '/v1/association/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '/' + action +
							'?cacheName=' + encodeURIComponent(cacheName) +
							'&' + cachedValueNameQuery;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {headers};

		// Setup processing function
		var	results = null;
		let	processURL =
					async (url) => {
						// Loop until up-to-date
						while (true) {
							// Queue the call
							let	response = await this.queue.add(() => fetch(url, options));

							// Handle results
							if (response.status != 409) {
								// Process response
								await processResponse(response);

								// Merge results
								let	sliceResults = await response.json();
								if (Array.isArray(sliceResults))
									// Have array
									results = results ? results.concat(sliceResults) : sliceResults;
								else {
									// Have object
									results = results || {};
									for (let key of Object.keys(sliceResults))
										// Merge entry
										results[key] = (results[key] || 0) + sliceResults[key];
								}
								break;
							}
						}
					};

		// Max each call at 10 documentIDs
		let	promises = [];
		for (let i = 0, length = fromDocumentIDs.length; i < length; i += 10) {
			// Setup
			let	documentIDsSlice = fromDocumentIDs.slice(i, i + 10);
			promises.push(processURL(urlBase + '&fromID=' + documentIDsSlice.join('&fromID=')));
		}
		await Promise.all(promises);

		return results || ((action == 'detail') ? [] : {});
	}

	//------------------------------------------------------------------------------------------------------------------
	async cacheRegister(name, documentType, relevantProperties, valueInfos, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/cache/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
					{
						method: 'PUT',
						headers,
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
	async cacheGetStatus(name, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/cache/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name);
		let	options = {method: 'HEAD', headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));

		// Handle results
		if (response.ok)
			// Up-to-date
			return true;
		else if (response.status == 409)
			// Not up-to-date
			return false;
		else
			// Error
			throw new Error('HTTP response: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async cacheGetValues(name, valueNames, documents = null, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	valueNameQuery = valueNames.map(valueName => 'valueName=' + encodeURIComponent(valueName)).join('&');
		let	documentIDs = documents?.map(document => encodeURIComponent(document.documentID));
		
		let	urlBase =
					this.urlBase + '/v1/cache/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?' + valueNameQuery;

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {headers};

		// Setup processing function
		var	results = [];
		let	processURL =
					async (url) => {
						// Loop until up-to-date
						while (true) {
							// Queue the call
							let	response = await this.queue.add(() => fetch(url, options));

							// Handle results
							if (response.status != 409) {
								// Process response
								await processResponse(response);

								// Merge results
								let	sliceResults = await response.json();
								results = results.concat(sliceResults);
								break;
							}
						}
					};

		// Check if have documentIDs
		if (documentIDs?.length > 0) {
			// Max each call at 10 documentIDs
			let	promises = [];
			for (let i = 0, length = documentIDs.length; i < length; i += 10) {
				// Setup
				let	documentIDsSlice = documentIDs.slice(i, i + 10);
				promises.push(processURL(urlBase + '&id=' + documentIDsSlice.join('&id=')));
			}
			await Promise.all(promises);
		} else
			// No documentIDs
			await processURL(urlBase);

		return results;
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionRegister(name, documentType, relevantProperties, isUpToDate, isIncludedSelector,
			isIncludedSelectorInfo, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
					{
						method: 'PUT',
						headers,
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
	async collectionGetDocumentCount(name, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name);
		let	options = {method: 'HEAD', headers: this.headers};

		// Loop until up-to-date
		while (true) {
			// Queue the call
			let	response = await this.queue.add(() => fetch(url, options));

			// Handle results
			if (response.status != 409) {
				// Process response
				if (!response.ok)
					// Some error, but no additional info
					throw new Error('HTTP response: ' + response.status);

				// Decode content range
				let	contentRange = decodeContentRange(response);
				if (contentRange.size != '*')
					// Have count
					return contentRange.size;
				else
					// Don't have count
					throw new Error('Unable to get count from response');
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocumentInfos(name, startIndex, count, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=0';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Loop until up-to-date
		while (true) {
			// Queue the call
			let	response = await this.queue.add(() => fetch(url, options));

			// Handle results
			if (response.status != 409) {
				// Process response
				await processResponse(response);
	
				return await response.json();
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetAllDocumentInfos(name, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	url =
					this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=0';
		let	options = {headers: this.headers};

		// Loop until up-to-date and have all infos
		var	documentInfos = []
		var	startIndex = 0;
		while (true) {
			// Compose URL
			let	urlUse = url + '&startIndex=' + startIndex;

			// Queue the call
			let	response = await this.queue.add(() => fetch(urlUse, options));

			// Handle results
			if (response.status != 409) {
				// Process response
				await processResponse(response);

				let	infos = await response.json();
				documentInfos = documentInfos.concat(infos);

				// Decode content range
				let	contentRange = decodeContentRange(response);
				let	range = contentRange.range;
				if (range == "*")
					// No range
					return documentInfos;
				
				let	nextStartIndex = contentRange.rangeEnd + 1;
				if (nextStartIndex == contentRange.size)
					// All done
					return documentInfos;
				
				// Prepare next request
				startIndex = nextStartIndex;
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetDocuments(name, startIndex, count, documentCreationProc, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=1';
		if (startIndex) url += '&startIndex=' + startIndex;
		if (count) url += '&count=' + count;

		let	options = {headers: this.headers};

		// Loop until up-to-date
		while (true) {
			// Queue the call
			let	response = await this.queue.add(() => fetch(url, options));

			// Handle results
			if (response.status != 409) {
				// Process response
				await processResponse(response);
			
				// Decode
				let	infos = await response.json();

				return infos.map(info => documentCreationProc(info));
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async collectionGetAllDocuments(name, documentCreationProc, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	url =
					this.urlBase + '/v1/collection/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=1&count=1000';
		let	options = {headers: this.headers};

		// Loop until up-to-date and have all infos
		var	documents = []
		var	startIndex = 0;
		while (true) {
			// Compose URL
			let	urlUse = url + '&startIndex=' + startIndex;

			// Queue the call
			let	response = await this.queue.add(() => fetch(urlUse, options));

			// Handle results
			if (response.status != 409) {
				// Process response
				await processResponse(response);

				let	infos = await response.json();
				documents = documents.concat(infos.map(info => documentCreationProc(info)));

				// Decode content range
				let	contentRange = decodeContentRange(response);
				let	range = contentRange.range;
				if (range == "*")
					// No range
					return documents;
				
				let	nextStartIndex = contentRange.rangeEnd + 1;
				if (nextStartIndex == contentRange.size)
					// All done
					return documents;
				
				// Prepare next request
				startIndex = nextStartIndex;
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentCreate(documentType, documents, documentStorageID = null) {
		// Collect documents to create
		let	documentsToCreate = documents.filter(document => document.hasCreateInfo());
		if (documentsToCreate.length == 0)
			// No documents
			return;

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
						headers,
						body: JSON.stringify(documentsToCreate.map(document => document.createInfo())),
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		// Decode info
		let	results = await response.json();

		// Update documents
		var	documentsByID = {};
		for (let document of documentsToCreate)
			// Update info
			documentsByID[document.documentID] = document;
		for (let result of results)
			// Update document
			documentsByID[result.documentID].updateFromCreate(result);
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGetCount(documentType, documentStorageID = null) {
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
			throw new Error('HTTP response: ' + response.status);

		// Decode content range
		let	contentRange = decodeContentRange(response);
		if (contentRange.size != '*')
			// Have count
			return contentRange.size;
		else
			// Don't have count
			throw new Error('Unable to get count from response');
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentGet(documentType, documentIDs, documentCreationProc, documentStorageID = null) {
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
								encodeURIComponent(documentType) +
								'?id=' + documentIDsSlice.join('&id=') +
								'&fullInfo=1';

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
	async documentGetSinceRevision(documentType, sinceRevision, count, documentCreationProc, documentStorageID = null,
			fullInfo = true) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		var	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '?sinceRevision=' + sinceRevision +
							'&fullInfo=' + (fullInfo ? 1 : 0);
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
	async documentGetAllSinceRevision(documentType, sinceRevision, batchCount, documentCreationProc,
			documentStorageID = null, fullInfo = 0, proc = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	urlBase =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '?' +
							(batchCount ? 'count=' + batchCount + '&' : '') +
							'fullInfo=' + (fullInfo ? 1 : 0) + '&' +
							'sinceRevision=';
		let	options = {headers: this.headers};

		var	sinceRevisionUse = sinceRevision;
		var	totalDocumentCount = null;

		// Loop until done
		let	documents = [];
		for (;;) {
			// Retrieve next batch of Documents
			let	response = await this.queue.add(() => fetch(urlBase + sinceRevisionUse, options));
			await processResponse(response);
		
			// Decode
			let	infos = await response.json();
			let	documentsBatch = infos.map(info => documentCreationProc(info));
			documents = documents.concat(documentsBatch);

			if (documentsBatch.length > 0) {
				// More Documents
				if (totalDocumentCount == null) {
					// Decode content range
					let	contentRange = decodeContentRange(response);
					if (contentRange.size != '*')
						// Havea count
						totalDocumentCount = contentRange.size;
				}

				// Check if have proc
				if (proc)
					// Call proc
					proc(documentsBatch, totalDocumentCount);

				// Update
				documentsBatch.forEach(document => sinceRevisionUse = Math.max(sinceRevisionUse, document.revision));
			} else
				// Have all Documents
				return documents;
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentUpdate(documentType, documents, documentStorageID = null) {
		// Collect documents to update
		let	documentsToUpdate = documents.filter(document => document.hasUpdateInfo());
		if (documentsToUpdate.length == 0)
			// No documents
			return;

		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		// Max each call at 50 updates
		for (let i = 0, length = documentsToUpdate.length; i < length; i += 50) {
			// Setup
			let	documentsSlice = documentsToUpdate.slice(i, i + 50);

			let	options =
						{
							method: 'PATCH',
							headers,
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
	async documentAttachmentAdd(documentType, document, info, content, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '/' + encodeURIComponent(document.documentID) +
							'/attachment';

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		if (typeof File == 'function') {
			// Have File in this context
			if (content instanceof File)
				// Convert File => ArrayBuffer
				content = await content.arrayBuffer();
		}
		if (content instanceof ArrayBuffer)
			// Convert ArrayBuffer => Buffer
			content = Buffer.from(content);
		if (content instanceof Buffer)
			// Base64-encode Buffer
			content = content.toString('base64');
		if (typeof content == 'object')
			// Stringify JSON
			content = JSON.stringify(content);

		let	options = 
					{
						method: 'POST',
						headers,
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
	static	documentGetAttachmentTypeBinary = 'application/octet-stream';
	static	documentGetAttachmentTypeHTML = 'text/html';
	static	documentGetAttachmentTypeJSON = 'application/json';
	static	documentGetAttachmentTypeText = 'text/plain';
	static	documentGetAttachmentTypeXML = 'text/xml';
	async documentAttachmentGet(documentType, document, attachmentID, type, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '/' + encodeURIComponent(document.documentID) +
							'/attachment/' + encodeURIComponent(attachmentID);
		let	options = {headers: {...this.headers, Accept: type}};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);

		switch (type) {
			case MDSClient.documentGetAttachmentTypeBinary:	return await response.blob();
			case MDSClient.documentGetAttachmentTypeJSON:	return await response.json();
			default:										return await response.text();
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async documentAttachmentUpdate(documentType, document, attachmentID, info, content, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '/' + encodeURIComponent(document.documentID) +
							'/attachment/' + encodeURIComponent(attachmentID);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		if (content instanceof File)
			// Convert File => ArrayBuffer
			content = await content.arrayBuffer();
		if (content instanceof ArrayBuffer)
			// Convert ArrayBuffer => Buffer
			content = Buffer.from(content);
		if (content instanceof Buffer)
			// Base64-encode Buffer
			content = content.toString('base64');
		if (typeof content == 'object')
			// Stringify JSON
			content = JSON.stringify(content);

		let	options =
					{
						method: 'PATCH',
						headers,
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
	async documentAttachmentRemove(documentType, document, attachmentID, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/document/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(documentType) + '/' + encodeURIComponent(document.documentID) +
							'/attachment/' + encodeURIComponent(attachmentID);
		let	options = {method: 'DELETE', headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexRegister(name, documentType, relevantProperties, keysSelector, keysSelectorInfo,
			documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/index/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options =
					{
						method: 'PUT',
						headers,
						body:
								JSON.stringify(
										{
											'name': name,
											'documentType': documentType,
											'relevantProperties': relevantProperties,
											'keysSelector': keysSelector,
											'keysSelectorInfo': keysSelectorInfo,
										}),
					};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetStatus(name, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url =
					this.urlBase + '/v1/index/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name);
		let	options = {method: 'HEAD', headers: this.headers};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));

		// Handle results
		if (response.ok)
			// Up-to-date
			return true;
		else if (response.status == 409)
			// Not up-to-date
			return false;
		else
			// Error
			throw new Error('HTTP response: ' + response.status);
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocumentInfos(name, keys, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	keysUse = keys.map(key => encodeURIComponent(key));

		let	url =
					this.urlBase + '/v1/index/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=0' + '?key=' + keysUse.join('&key=');
		let	options = {headers: this.headers};

		// Loop until up-to-date
		while (true) {
			// Queue the call
			let	response = await this.queue.add(() => fetch(url, options));

			// Handle results
			if (response.status != 409) {
				// Process response
				await processResponse(response);
			
				return await response.json();
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async indexGetDocuments(name, keys, documentCreationProc, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;
		let	keysUse = keys.map(key => encodeURIComponent(key));

		let	url =
					this.urlBase + '/v1/index/' + encodeURIComponent(documentStorageIDUse) + '/' +
							encodeURIComponent(name) + '?fullInfo=1' + '?key=' + keysUse.join('&key=');
		let	options = {headers: this.headers};

		// Loop until up-to-date
		while (true) {
			// Queue the call
			let	response = await this.queue.add(() => fetch(url, options));

			// Handle results
			if (response.status != 409) {
				// Process response
				await processResponse(response);
			
				// Decode
				let	results = await response.json();

				return Object.fromEntries(Object.entries(results).map(([k, v]) => [k, documentCreationProc(v)]));
			}
		}
	}

	//------------------------------------------------------------------------------------------------------------------
	async infoGet(keys, documentStorageID = null) {
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
	async infoSet(info, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/info/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {method: 'POST', headers, body: JSON.stringify(info)};

		// Queue the call
		let	response = await this.queue.add(() => fetch(url, options));
		await processResponse(response);
	}

	//------------------------------------------------------------------------------------------------------------------
	async internalSet(info, documentStorageID = null) {
		// Setup
		let	documentStorageIDUse = documentStorageID || this.documentStorageID;

		let	url = this.urlBase + '/v1/internal/' + encodeURIComponent(documentStorageIDUse);

		let	headers = {...this.headers};
		headers['Content-Type'] = 'application/json';

		let	options = {method: 'POST', headers, body: JSON.stringify(info)};

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
		if (info?.error)
			// Have error in response
			throw new Error('HTTP response: ' + response.status + ', error: ' + info.error);
		else if (info?.message)
			// Have message in response
			throw new Error('HTTP response: ' + response.status + ', message: ' + info.message);
		else
			// Other
			throw new Error('HTTP response: ' + response.status);
	}
}

//----------------------------------------------------------------------------------------------------------------------
function decodeContentRange(response) {
	// Get content range
	let	contentRange = response.headers.get('content-range');
	if (!contentRange)
		// No content range
		throw new Error('No content-range in response headers');

	// Decode content range
	let	result = contentRange.match(/(\w+)[ ](.+)\/(.+)/);
	if (result.length != 4)
		// Unable to decode
		throw new Error('Unable to decode content range from response');

	// Compose info
	let	range = result[2];
	let	size = result[3];

	var	info = {'unit': result[1], 'range': range, 'size': (size != '*') ? parseInt(size) : size};
	if (range != '*') {
		// Decode range components
		let	rangeParts = range.split('-');
		info['rangeStart'] = parseInt(rangeParts[0]);
		info['rangeEnd'] = parseInt(rangeParts[1]);
	}

	return info;
}
module.exports = MDSClient;
