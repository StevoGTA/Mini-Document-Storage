#
# MDSClient.py
#
# Created by Stevo on 5/16/2023.
# Copyright © 2023 Stevo Brock.  All rights reserved
#

# Imports
import aiohttp
import asyncio

#-----------------------------------------------------------------------------------------------------------------------
# MDSClient
class MDSClient:
    
	# Lifecycle methods
	#-------------------------------------------------------------------------------------------------------------------
	def __init__(self, url_base, document_storage_id = None, headers = {}):
		# Store
		self.document_storage_id = document_storage_id
		self.headers = headers

		# Setup
		self.session = aiohttp.ClientSession(url_base)
	
	#-------------------------------------------------------------------------------------------------------------------
	async def close(self):
		# Close session
		await self.session.close()

	# Instance methods
	#-------------------------------------------------------------------------------------------------------------------
	def set_document_storage_id(self, document_storage_id):
		# Store
		self.document_storage_id = document_storage_id

	#-------------------------------------------------------------------------------------------------------------------
	def set_headers(self, headers = {}):
		# Store
		self.headers = headers

	#-------------------------------------------------------------------------------------------------------------------
	# async def delete(self, subpath, params = {}):
	# 	# Queue request
	# 	async with self.session.delete(subpath, headers = self.headers, params = params) as response:
	# 		# Process response
	# 		await self.process_response(response)

	# 		return {'headers': response.headers}

	#-------------------------------------------------------------------------------------------------------------------
	async def getJSON(self, subpath, params = {}):
		# Queue request
		async with self.session.get(subpath, headers = self.headers, params = params) as response:
			# Process response
			await self.process_response(response)

			# Get JSON
			json = await response.json()

			return {'headers': response.headers, 'json': json}

	#-------------------------------------------------------------------------------------------------------------------
	async def patch(self, subpath, params = {}, json = {}):
		# Queue request
		async with self.session.patch(subpath, headers = self.headers, params = params, json = json) as response:
			# Process response
			await self.process_response(response)

			return response

	# #-------------------------------------------------------------------------------------------------------------------
	# async def post(self, subpath, params = {}, json = {}):
	# 	# Queue request
	# 	async with self.session.post(subpath, headers = self.headers, params = params, json = json) as response:
	# 		# Process response
	# 		await self.process_response(response)

	# 		return response

	# #-------------------------------------------------------------------------------------------------------------------
	# async def put(self, subpath, params = {}, json = {}):
	# 	# Queue request
	# 	async with self.session.put(subpath, headers = self.headers, params = params, json = json) as response:
	# 		# Process response
	# 		await self.process_response(response)

	# 		return response

	#-------------------------------------------------------------------------------------------------------------------
	async def association_register(self, name, from_document_type, to_document_type, document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id
		json = {
			'name': name,
			'fromDocumentType': from_document_type,
			'toDocumentType': to_document_type,
		}

		# Queue request
		async with self.session.put(f'/v1/association/{document_storage_id_use}', headers = self.headers,
				json = json) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def association_update(self, name, updates, document_storage_id = None):
		# Check if have updates
		if len(updates) == 0:
			# No updates
			return

		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		# Queue request
		async with self.session.put(f'/v1/association/{document_storage_id_use}/{name}', headers = self.headers,
				json = updates) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_infos(self, name, start_index = 0, count = None, full_info = False,
			document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		params = {'startIndex': start_index, 'fullInfo': 1 if full_info else 0}
		if count:
			params['count'] = count

		# Queue request
		async with self.session.get(f'/v1/association/{document_storage_id_use}/{name}', headers = self.headers,
				params = params) as response:
			# Handle results
			if response.status != 409:
				# Process response
				await self.process_response(response)

				return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_infos_from(self, name, document, start_index = 0, count = None,
			document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_documents_from(self, name, document, start_index, count, document_creation_function,
			document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_infos_to(self, name, document, start_index = 0, count = None,
			document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_documents_to(self, name, document, start_index, count, document_creation_function,
			document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_value(self, name, action, from_documents, cache_name, cached_value_name,
			document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def cache_register(self, name, document_type, relevant_properties, value_infos, document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_register(self, name, document_type, relevant_properties, is_up_to_date, is_included_selector,
			is_included_selector_info, document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id
		json = {
			'name': name,
			'documentType': document_type,
			'relevantProperties': relevant_properties,
			'isUpToDate': is_up_to_date,
			'isIncludedSelector': is_included_selector,
			'isIncludedSelectorInfo': is_included_selector_info,
		}

		# Queue request
		async with self.session.put(f'/v1/collection/{document_storage_id_use}', headers = self.headers,
				json = json) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_get_document_count(self, name, document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.head(f'/v1/collection/{document_storage_id_use}/{name}',
					headers = self.headers) as response:
				# Handle results
				if response.status != 409:
					# Process response
					if not response.ok:
						# Some error, but no additional info
						raise Exception(f'HTTP response: {response.status}')
					
					# Decode header
					content_range = response.headers.get('content-range', '')
					content_range_parts = content_range.split('/')
					if len(content_range_parts) == 2:
						# Have count
						return int(content_range_parts[1])
					else:
						# Don't have count
						raise Exception('Unable to get count from response')

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_get_document_infos(self, name, start_index = 0, count = None, document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		params = {'startIndex': start_index, 'fullInfo': 0}
		if count:
			params['count'] = count

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.get(f'/v1/collection/{document_storage_id_use}/{name}', headers = self.headers,
					params = params) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_get_documents(self, name, start_index, count, document_creation_function,
			document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		params = {'startIndex': start_index, 'fullInfo': 1}
		if count:
			params['count'] = count

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.get(f'/v1/collection/{document_storage_id_use}/{name}', headers = self.headers,
					params = params) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					# Decode
					infos = await response.json()

					return list(map(lambda info: document_creation_function(info), infos))

	#-------------------------------------------------------------------------------------------------------------------
	async def document_create(self, document_type, documents, document_storage_id = None):
		# Collect documents to create
		documents_to_create = list(filter(lambda document: document.has_create_info, documents))
		if len(documents_to_create) == 0:
			# No documents
			return
		
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id
		json = [document.create_info() for document in documents_to_create]

		# Queue request
		async with self.session.post(f'/v1/document/{document_storage_id_use}/{document_type}', headers = self.headers,
				json = json) as response:
			# Process response
			await self.process_response(response)

			# Decode info
			results = await response.json()

			# Update documents
			documents_by_id = dict(map(lambda document: (document.document_id, document), documents_to_create))
			for result in results:
				# Update document
				documents_by_id[result['documentID']].update_from_create(result)

	#-------------------------------------------------------------------------------------------------------------------
	async def document_get_count(self, document_type, document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def document_get_since_revision(self, document_type, since_revision, count, document_creation_function,
			full_info = True, document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		params = {'sinceRevision': since_revision, 'fullInfo': 1 if full_info else 0}
		if count:
			params['count'] = count

		# Queue request
		async with self.session.get(f'/v1/document/{document_storage_id_use}/{document_type}',
				headers = self.headers, params = params) as response:
			# Process response
			await self.process_response(response)

			# Decode info and add Documents
			results = await response.json()

			return list(map(lambda result: document_creation_function(result), results))

	#-------------------------------------------------------------------------------------------------------------------
	async def document_get_all_since_revision(self, document_type, since_revision, batchCount,
			document_creation_function, full_info = True, document_storage_id = None, proc = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def document_get(self, document_type, document_ids, document_creation_function, document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		documents = []
		async def worker(document_ids):
			# Queue request
			async with self.session.get(f'/v1/document/{document_storage_id_use}/{document_type}',
					headers = self.headers, params = {'id': document_ids, 'fullInfo': 1}) as response:
				# Process response
				await self.process_response(response)

				# Decode info and add Documents
				results = await response.json()
				documents.extend(list(map(lambda result: document_creation_function(result), results)))

		# Max each call at 10 documentIDs
		tasks = []
		for i in range(0, len(document_ids), 10):
			# Query for existing Folder
			tasks.append(asyncio.ensure_future(worker(document_ids[i:i+10])))
		await asyncio.gather(*tasks, return_exceptions = True)

		return documents

	#-------------------------------------------------------------------------------------------------------------------
	async def document_update(self, document_type, documents, document_storage_id = None):
		# Collect documents to update
		documents_to_update = list(filter(lambda document: document.has_update_info, documents))
		if len(documents_to_update) == 0:
			# No documents
			return
		
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		async def worker(documents):
			# Setup
			json = [document.update_info() for document in documents]

			# Queue request
			async with self.session.patch(f'/v1/document/{document_storage_id_use}/{document_type}',
					headers = self.headers, json = json) as response:
				# Process response
				await self.process_response(response)

				# Decode info and add Documents
				results = await response.json()

				# Update documents
				documents_by_id = {}
				for document in documents:
					# Update
					documents_by_id[document.document_id] = document
				
				for result in results:
					# Update document
					documents_by_id[result['documentID']].update_from_update(result)

		# Max each call at 50 updates
		tasks = []
		for i in range(0, len(documents_to_update), 50):
			# Query for existing Folder
			tasks.append(asyncio.ensure_future(worker(documents_to_update[i:i+10])))
		await asyncio.gather(*tasks, return_exceptions = True)

	#-------------------------------------------------------------------------------------------------------------------
	async def document_attachment_add(self, document_type, document_id, info, content, document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def document_attachment_get(self, document_type, document_id, attachment_id, document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def document_attachment_update(self, document_type, document_id, attachment_id, info, content,
			document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def document_attachment_remove(self, document_type, document_id, attachment_id, document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def index_register(self, name, document_type, relevant_properties, keys_selector, keys_selector_info = {},
			document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id
		json = {
			'name': name,
			'documentType': document_type,
			'relevantProperties': relevant_properties,
			'keysSelector': keys_selector,
			'keysSelectorInfo': keys_selector_info,
		}

		# Queue request
		async with self.session.put(f'/v1/index/{document_storage_id_use}', headers = self.headers,
				json = json) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def index_get_document_infos(self, name, keys, document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.get(f'/v1/index/{document_storage_id_use}/{name}', headers = self.headers,
					params = {'key': keys, 'fullInfo': 0}) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def index_get_documents(self, name, keys, document_creation_function, document_storage_id = None):
		# Setup
		document_storage_id_use = document_storage_id if document_storage_id else self.document_storage_id

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.get(f'/v1/index/{document_storage_id_use}/{name}', headers = self.headers,
					params = {'key': keys, 'fullInfo': 1}) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					results = await response.json()

					return {k: document_creation_function(v) for k, v in results.items()}

	#-------------------------------------------------------------------------------------------------------------------
	async def info_get(self, keys, document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def info_set(self, info, document_storage_id = None):
		pass

	#-------------------------------------------------------------------------------------------------------------------
	async def internals_set(self, info, document_storage_id = None):
		pass

	# Private methods
	#-------------------------------------------------------------------------------------------------------------------
	async def process_response(self, response):
		# Check status
		if not response.ok:
			# Catch errors
			info = {}
			try:
				# Try to get results
				info = await response.json()
			except:
				# Don't worry about errors
				pass

			# Process results
			if ('error' in info):
				# Have error
				raise Exception(f'HTTP response: {response.status}, error: {info["error"]}')
			elif ('message' in info):
				# Have message
				raise Exception(f'HTTP reponse: {response.status}, message: {info["message"]}')
			else:
				# Other
				raise Exception(f'HTTP response: {response.status}')
