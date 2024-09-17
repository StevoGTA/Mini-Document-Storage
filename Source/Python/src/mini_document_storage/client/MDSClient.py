#
# MDSClient.py
#
# Created by Stevo on 5/16/2023.
# Copyright © 2023 Stevo Brock.  All rights reserved
#

# Imports
import aiohttp
import asyncio
import base64
import json
import re

#-----------------------------------------------------------------------------------------------------------------------
# MDSClient
class MDSClient:
    
	# Lifecycle methods
	#-------------------------------------------------------------------------------------------------------------------
	def __init__(self, url_base, loop, document_storage_id = None, headers = {}):
		# Store
		self.document_storage_id = document_storage_id
		self.headers = headers

		# Setup
		self.session = aiohttp.ClientSession(url_base, loop = loop)
	
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
	async def delete(self, subpath, params = {}, headers = {}):
		# Queue request
		async with self.session.delete(subpath, headers = {**self.headers, **headers}, params = params) as response:
			# Process response
			await self.process_response(response)

			return response

	#-------------------------------------------------------------------------------------------------------------------
	async def get_bytes(self, subpath, params = {}, headers = {}):
		# Queue request
		async with self.session.get(subpath, headers = {**self.headers, **headers}, params = params) as response:
			# Process response
			await self.process_response(response)

			# Get Binary
			bytes = await response.read()

			return {'headers': response.headers, 'bytes': bytes}

	#-------------------------------------------------------------------------------------------------------------------
	async def get_json(self, subpath, params = {}, headers = {}):
		# Queue request
		async with self.session.get(subpath, headers = {**self.headers, **headers}, params = params) as response:
			# Process response
			await self.process_response(response)

			# Get JSON
			json = await response.json()

			return {'headers': response.headers, 'json': json}

	#-------------------------------------------------------------------------------------------------------------------
	async def patch(self, subpath, params = {}, body = None, headers = {}):
		# Check body type
		if isinstance(body, (bytes, bytearray)):
			# Bytes
			async with self.session.patch(subpath, headers = {**self.headers, **headers}, params = params,
					data = body) as response:
				# Process response
				await self.process_response(response)

				return response
		else:
			# Assume JSON
			async with self.session.patch(subpath, headers = {**self.headers, **headers}, params = params,
					json = body) as response:
				# Process response
				await self.process_response(response)

				return response

	#-------------------------------------------------------------------------------------------------------------------
	async def post(self, subpath, params = {}, body = None, headers = {}):
		# Check body type
		if isinstance(body, (bytes, bytearray)):
			# Bytes
			async with self.session.post(subpath, headers = {**self.headers, **headers}, params = params,
					data = body) as response:
				# Process response
				await self.process_response(response)

				return response
		else:
			# Assume JSON
			async with self.session.post(subpath, headers = {**self.headers, **headers}, params = params,
					json = body) as response:
				# Process response
				await self.process_response(response)

				return response

	#-------------------------------------------------------------------------------------------------------------------
	async def put(self, subpath, params = {}, body = None, headers = {}):
		# Check body type
		if isinstance(body, (bytes, bytearray)):
			# Bytes
			async with self.session.put(subpath, headers = {**self.headers, **headers}, params = params,
					data = body) as response:
				# Process response
				await self.process_response(response)

				return response
		else:
			# Assume JSON
			async with self.session.put(subpath, headers = {**self.headers, **headers}, params = params,
					json = body) as response:
				# Process response
				await self.process_response(response)

				return response

	#-------------------------------------------------------------------------------------------------------------------
	async def association_register(self, name, from_document_type, to_document_type, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id
		json = {
			'name': name,
			'fromDocumentType': from_document_type,
			'toDocumentType': to_document_type,
		}

		# Queue request
		async with self.session.put(f'/v1/association/{document_storage_id}', headers = self.headers,
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
		document_storage_id = document_storage_id or self.document_storage_id

		# Queue request
		async with self.session.put(f'/v1/association/{document_storage_id}/{name}', headers = self.headers,
				json = updates) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_infos(self, name, start_index = 0, count = None, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'startIndex': start_index}
		if count:
			params['count'] = count

		# Queue request
		async with self.session.get(f'/v1/association/{document_storage_id}/{name}', headers = self.headers,
				params = params) as response:
			# Process response
			await self.process_response(response)

			return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_infos_from(self, name, document, start_index = 0, count = None,
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'fromID': document.document_id, 'startIndex': start_index, 'fullInfo': 0}
		if count:
			params['count'] = count

		# Queue request
		async with self.session.get(f'/v1/association/{document_storage_id}/{name}', headers = self.headers,
				params = params) as response:
			# Process response
			await self.process_response(response)

			return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_documents_from(self, name, document, start_index, count, document_creation_function,
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'fromID': document.document_id, 'startIndex': start_index, 'fullInfo': 1}
		if count:
			params['count'] = count

		# Queue request
		async with self.session.get(f'/v1/association/{document_storage_id}/{name}', headers = self.headers,
				params = params) as response:
			# Process response
			await self.process_response(response)

			# Decode
			infos = await response.json()

			return list(map(document_creation_function, infos))

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_id_map_from(self, name, documents, document_storage_id = None):
		# Retrieve all document infos
		results = await self.association_get_document_infos(name, document_storage_id = document_storage_id)

		# Compose "to" info for those "from" document IDs of interest
		from_document_ids = set(map(lambda document: document.document_id, documents))
		to_document_ids_by_from_document_id = {}
		for result in results:
			# Check if this "from" document is of interest
			from_document_id = result.get('fromDocumentID')
			if from_document_id in from_document_ids:
				# Get info
				to_document_id = result.get('toDocumentID')

				# Update stuffs
				if from_document_id in to_document_ids_by_from_document_id:
					# Another "to" document
					to_document_ids_by_from_document_id[from_document_id].append(to_document_id)
				else:
					# First "to" document
					to_document_ids_by_from_document_id[from_document_id] = [to_document_id]
		
		return to_document_ids_by_from_document_id

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_map_from(self, name, documents, document_type, document_creation_function,
			document_storage_id = None, individual_retrieval_threshold = 5):
		# Setup
		to_documents_by_from_document_id = {}

		# Check how many documents in play
		if len(documents) <= individual_retrieval_threshold:
			# Retrieve associations for each document
			for document in documents:
				# Retrieve "to" documents for this "from" document
				to_documents_by_from_document_id[document.document_id] = await self.association_get_documents_from(name,
						document, 0, None, document_creation_function, document_storage_id)
		else:
			# Retrieve all document infos and go from there
			results = await self.association_get_document_infos(name, document_storage_id = document_storage_id)

			# Compose "to" info for those "from" document IDs of interest
			from_document_ids = set(map(lambda document: document.document_id, documents))
			to_document_ids = set()
			to_document_ids_by_from_document_id = {}
			for result in results:
				# Check if this "from" document is of interest
				from_document_id = result.get('fromDocumentID')
				if from_document_id in from_document_ids:
					# Get info
					to_document_id = result.get('toDocumentID')

					# Update stuffs
					to_document_ids.add(to_document_id)
					if from_document_id in to_document_ids_by_from_document_id:
						# Another "to" document
						to_document_ids_by_from_document_id[from_document_id].append(to_document_id)
					else:
						# First "to" document
						to_document_ids_by_from_document_id[from_document_id] = [to_document_id]
			
			# Retrieve "to" documents of interest and create dict based on document ID
			to_documents = await self.document_get(document_type, list(to_document_ids), document_creation_function,
					document_storage_id)
			to_document_by_document_id = {}
			for to_document in to_documents:
				# Update dict
				to_document_by_document_id[to_document.document_id] = to_document

			# Compose final dict
			for from_document_id in from_document_ids:
				# Update final dict
				to_document_ids = to_document_ids_by_from_document_id.get(from_document_id, [])
				to_documents_by_from_document_id[from_document_id] = list(map(lambda document_id: to_document_by_document_id.get(document_id), to_document_ids))

		return to_documents_by_from_document_id

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_infos_to(self, name, document, start_index = 0, count = None,
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'toID': document.document_id, 'startIndex': start_index, 'fullInfo': 0}
		if count:
			params['count'] = count

		# Queue request
		async with self.session.get(f'/v1/association/{document_storage_id}/{name}', headers = self.headers,
				params = params) as response:
			# Process response
			await self.process_response(response)

			return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_documents_to(self, name, document, start_index, count, document_creation_function,
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'toID': document.document_id, 'startIndex': start_index, 'fullInfo': 1}
		if count:
			params['count'] = count

		# Queue request
		async with self.session.get(f'/v1/association/{document_storage_id}/{name}', headers = self.headers,
				params = params) as response:
			# Process response
			await self.process_response(response)

			# Decode
			infos = await response.json()

			return list(map(document_creation_function, infos))

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_id_map_to(self, name, documents, document_storage_id = None):
		# Retrieve all document infos
		results = await self.association_get_document_infos(name, document_storage_id = document_storage_id)

		# Compose "from" info for those "to" document IDs of interest
		to_document_ids = set(map(lambda document: document.document_id, documents))
		from_document_ids_by_to_document_id = {}
		for result in results:
			# Check if this "to" document is of interest
			to_document_id = result.get('toDocumentID')
			if to_document_id in to_document_ids:
				# Get info
				from_document_id = result.get('fromDocumentID')

				# Update stuffs
				if to_document_id in from_document_ids_by_to_document_id:
					# Another "from" document
					from_document_ids_by_to_document_id[to_document_id].append(from_document_id)
				else:
					# First "from" document
					from_document_ids_by_to_document_id[to_document_id] = [from_document_id]
		
		return from_document_ids_by_to_document_id

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_document_map_to(self, name, documents, document_type, document_creation_function,
			document_storage_id = None, individual_retrieval_threshold = 5):
		# Setup
		from_documents_by_to_document_id = {}

		# Check how many documents in play
		if len(documents) <= individual_retrieval_threshold:
			# Retrieve associations for each document
			for document in documents:
				# Retrieve "from" documents for this "to" document
				from_documents_by_to_document_id[document.document_id] = await self.association_get_documents_to(name,
						document, 0, None, document_creation_function, document_storage_id)
		else:
			# Retrieve all document infos and go from there
			results = await self.association_get_document_infos(name, document_storage_id = document_storage_id)

			# Compose "from" info for those "to" document IDs of interest
			to_document_ids = set(map(lambda document: document.document_id, documents))
			from_document_ids = set()
			from_document_ids_by_to_document_id = {}
			for result in results:
				# Check if this "to" document is of interest
				to_document_id = result.get('toDocumentID')
				if to_document_id in to_document_ids:
					# Get info
					from_document_id = result.get('fromDocumentID')

					# Update stuffs
					from_document_ids.add(from_document_id)
					if to_document_id in from_document_ids_by_to_document_id:
						# Another "from" document
						from_document_ids_by_to_document_id[to_document_id].append(from_document_id)
					else:
						# First "from" document
						from_document_ids_by_to_document_id[to_document_id] = [from_document_id]
			
			# Retrieve "from" documents of interest and create dict based on document ID
			from_documents = await self.document_get(document_type, list(from_document_ids), document_creation_function,
					document_storage_id)
			from_document_by_document_id = {}
			for from_document in from_documents:
				# Update dict
				from_document_by_document_id[from_document.document_id] = from_document

			# Compose final dict
			for to_document_id in to_document_ids:
				# Update final dict
				from_document_ids = from_document_ids_by_to_document_id.get(to_document_id, [])
				from_documents_by_to_document_id[to_document_id] = list(map(lambda document_id: from_document_by_document_id.get(document_id), from_document_ids))

		return from_documents_by_to_document_id

	#-------------------------------------------------------------------------------------------------------------------
	async def association_get_value(self, name, action, from_documents, cache_name, cached_value_names,
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id
		from_document_ids = list(map(lambda document: document.document_id, from_documents))

		params = {
			'cacheName': cache_name,
			'cachedValueName': cached_value_names
		}

		async def worker(document_ids):
			# Setup
			params['fromID'] = document_ids

			# Queue request
			async with self.session.get(f'/v1/association/{document_storage_id}/{name}/{action}',
					headers = self.headers, params = params) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					return await response.json()
				else:
					return None

		# Max each call at 10 documentIDs
		results = {}
		for i in range(0, len(from_document_ids), 10):
			# Setup
			document_ids_slice = from_document_ids[i:i+10]

			# Loop until up-to-date
			while True:
				# Process request
				slice_results = await worker(document_ids_slice)
				if slice_results:
					# Merge results
					for key, value in slice_results.items():
						# Merge entry
						results[key] = results.get(key, 0) + value
					break

		return results

	#-------------------------------------------------------------------------------------------------------------------
	async def cache_register(self, name, document_type, relevant_properties, value_infos, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id
		json = {
			'name': name,
			'documentType': document_type,
			'relevantProperties': relevant_properties,
			'valueInfos': value_infos,
		}

		# Queue request
		async with self.session.put(f'/v1/cache/{document_storage_id}', headers = self.headers,
				json = json) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_register(self, name, document_type, relevant_properties, is_up_to_date, is_included_selector,
			is_included_selector_info, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id
		json = {
			'name': name,
			'documentType': document_type,
			'relevantProperties': relevant_properties,
			'isUpToDate': is_up_to_date,
			'isIncludedSelector': is_included_selector,
			'isIncludedSelectorInfo': is_included_selector_info,
		}

		# Queue request
		async with self.session.put(f'/v1/collection/{document_storage_id}', headers = self.headers,
				json = json) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_get_document_count(self, name, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.head(f'/v1/collection/{document_storage_id}/{name}',
					headers = self.headers) as response:
				# Handle results
				if response.status != 409:
					# Process response
					if not response.ok:
						# Some error, but no additional info
						raise Exception(f'HTTP response: {response.status}')
					
					# Decode header
					content_range = self.decode_content_range(response)

					return content_range['size']

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_get_document_infos(self, name, start_index = 0, count = None, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'startIndex': start_index, 'fullInfo': 0}
		if count:
			params['count'] = count

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.get(f'/v1/collection/{document_storage_id}/{name}', headers = self.headers,
					params = params) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_get_all_document_infos(self, name, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Loop until up-to-date and have all infos
		document_infos = []
		params = {'startIndex': 0, 'fullInfo': 0}
		while True:
			# Queue request
			async with self.session.get(f'/v1/collection/{document_storage_id}/{name}', headers = self.headers,
					params = params) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)
					infos = await response.json()
					document_infos.extend(infos)
					
					# Decode content range
					content_range = self.decode_content_range(response)

					range = content_range['range']
					if range == '*':
						# No range
						return document_infos
					
					next_start_index = content_range['range_end'] + 1
					if next_start_index == content_range['size']:
						# All done
						return document_infos
					else:
						# Prepare next request
						params['startIndex'] = next_start_index

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_get_documents(self, name, start_index, count, document_creation_function,
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'startIndex': start_index, 'fullInfo': 1}
		if count:
			params['count'] = count

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.get(f'/v1/collection/{document_storage_id}/{name}', headers = self.headers,
					params = params) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					# Decode
					infos = await response.json()

					return list(map(document_creation_function, infos))

	#-------------------------------------------------------------------------------------------------------------------
	async def collection_get_all_documents(self, name, document_creation_function, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Loop until up-to-date and have all documents
		documents = []
		params = {'startIndex': 0, 'fullInfo': 1}
		while True:
			# Queue request
			async with self.session.get(f'/v1/collection/{document_storage_id}/{name}', headers = self.headers,
					params = params) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)
					infos = await response.json()
					documents.extend(map(document_creation_function, infos))
					
					# Decode content range
					content_range = self.decode_content_range(response)

					range = content_range['range']
					if range == '*':
						# No range
						return documents
					
					next_start_index = content_range['range_end'] + 1
					if next_start_index == content_range['size']:
						# All done
						return documents
					else:
						# Prepare next request
						params['startIndex'] = next_start_index

	#-------------------------------------------------------------------------------------------------------------------
	async def document_create(self, document_type, documents, document_storage_id = None):
		# Collect documents to create
		documents_to_create = list(filter(lambda document: document.has_create_info, documents))
		if len(documents_to_create) == 0:
			# No documents
			return
		
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id
		json = [document.create_info() for document in documents_to_create]

		# Queue request
		async with self.session.post(f'/v1/document/{document_storage_id}/{document_type}', headers = self.headers,
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
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Queue request
		async with self.session.head(f'/v1/document/{document_storage_id}/{document_type}',
				headers = self.headers) as response:
			# Process response
			if not response.ok:
				# Some error, but no additional info
				raise Exception(f'HTTP response: {response.status}')
			
			# Decode header
			content_range = self.decode_content_range(response)

			return content_range['size']

	#-------------------------------------------------------------------------------------------------------------------
	async def document_get_since_revision(self, document_type, since_revision, count, document_creation_function,
			full_info = True, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'sinceRevision': since_revision, 'fullInfo': 1 if full_info else 0}
		if count:
			params['count'] = count

		# Queue request
		async with self.session.get(f'/v1/document/{document_storage_id}/{document_type}',
				headers = self.headers, params = params) as response:
			# Process response
			await self.process_response(response)

			# Decode info and add Documents
			results = await response.json()

			return list(map(document_creation_function, results))

	#-------------------------------------------------------------------------------------------------------------------
	async def document_get_all_since_revision(self, document_type, since_revision, batch_count,
			document_creation_function, document_storage_id = None, proc = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		params = {'fullInfo': 1}
		if batch_count:
			params['count'] = batch_count

		since_revision_use = since_revision
		total_document_count = None

		# Loop until done
		documents = []
		while True:
			# Retrieve next batch of Documents
			params['sinceRevision'] = since_revision_use
			async with self.session.get(f'/v1/document/{document_storage_id}/{document_type}',
					headers = self.headers, params = params) as response:
				# Process response
				await self.process_response(response)

				# Decode
				infos = await response.json()
				documents_batch = list(map(document_creation_function, infos))
				documents.extend(documents_batch)

				if documents_batch:
					# More Documents
					if not total_document_count:
						# Retrieve total count from header
						content_range = self.decode_content_range(response)
						total_document_count = content_range['size']

					# Check if have proc
					if proc:
						# Call proc
						proc(documents_batch, total_document_count)
					
					# Update
					since_revision_use = max(map(lambda document: document.revision, documents_batch))
				else:
					# Have all Documents
					return documents

	#-------------------------------------------------------------------------------------------------------------------
	async def document_get(self, document_type, document_ids, document_creation_function, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Define worker function
		async def worker(document_ids):
			# Queue request
			async with self.session.get(f'/v1/document/{document_storage_id}/{document_type}',
					headers = self.headers, params = {'id': document_ids, 'fullInfo': 1}) as response:
				# Process response
				await self.process_response(response)

				return await response.json()

		# Max each call at 10 documentIDs
		tasks = []
		for i in range(0, len(document_ids), 10):
			# Add task
			tasks.append(asyncio.ensure_future(worker(document_ids[i:i+10])))
		resultss = await asyncio.gather(*tasks, return_exceptions = True)

		# Compose documents list
		documents = []
		for results in resultss:
			# Decode info and add Documents
			documents.extend(list(map(document_creation_function, results)))

		return documents

	#-------------------------------------------------------------------------------------------------------------------
	async def document_update(self, document_type, documents, document_storage_id = None):
		# Collect documents to update
		documents_to_update = list(filter(lambda document: document.has_update_info, documents))
		if len(documents_to_update) == 0:
			# No documents
			return
		
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		async def worker(documents):
			# Setup
			json = [document.update_info() for document in documents]

			# Queue request
			async with self.session.patch(f'/v1/document/{document_storage_id}/{document_type}',
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
			# Add task
			tasks.append(asyncio.ensure_future(worker(documents_to_update[i:i+50])))
		await asyncio.gather(*tasks, return_exceptions = True)

	#-------------------------------------------------------------------------------------------------------------------
	async def document_attachment_add(self, document_type, document_id, info, content, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		if (type(content) is dict) or (type(content) is list):
			# Convert to string
			content = json.dumps(content)
		if type(content) is str:
			# Convert to bytes
			content = content.encode('utf-8')
		if type(content) is bytes:
			# Convert to Base64 string
			content = base64.b64encode(content).decode('ascii')

		# Queue request
		async with self.session.post(f'/v1/document/{document_storage_id}/{document_type}/{document_id}/attachment',
				headers = self.headers, json = {'info': info, 'content': content}) as response:
			# Process response
			await self.process_response(response)

			return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	document_attachment_get_type_binary = 'application/octet-stream'
	document_attachment_get_type_html = 'text/html'
	document_attachment_get_type_json = 'application/json'
	document_attachment_get_type_text = 'text/plain'
	document_attachment_get_type_xml = 'text/xml'
	async def document_attachment_get(self, document_type, document_id, attachment_id, type,
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Queue request
		async with self.session.get(
				f'/v1/document/{document_storage_id}/{document_type}/{document_id}/attachment/{attachment_id}',
				headers = self.headers) as response:
			# Process response
			await self.process_response(response)

			if type == MDSClient.document_attachment_get_type_binary:
				# Binary
				return await response.read()
			elif type == MDSClient.document_attachment_get_type_json:
				# JSON
				return await response.json()
			else:
				# Text
				return await response.text()

	#-------------------------------------------------------------------------------------------------------------------
	async def document_attachment_update(self, document_type, document_id, attachment_id, info, content,
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		if (type(content) is dict) or (type(content) is list):
			# Convert to string
			content = json.dumps(content)
		if type(content) is str:
			# Convert to bytes
			content = content.encode('utf-8')
		if type(content) is bytes:
			# Convert to Base64 string
			content = base64.b64encode(content).decode('ascii')

		# Queue request
		async with self.session.patch(
				f'/v1/document/{document_storage_id}/{document_type}/{document_id}/attachment/{attachment_id}',
				headers = self.headers, json = {'info': info, 'content': content}) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def document_attachment_remove(self, document_type, document_id, attachment_id, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Queue request
		async with self.session.delete(
				f'/v1/document/{document_storage_id}/{document_type}/{document_id}/attachment/{attachment_id}',
				headers = self.headers) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def index_register(self, name, document_type, relevant_properties, keys_selector, keys_selector_info = {},
			document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id
		json = {
			'name': name,
			'documentType': document_type,
			'relevantProperties': relevant_properties,
			'keysSelector': keys_selector,
			'keysSelectorInfo': keys_selector_info,
		}

		# Queue request
		async with self.session.put(f'/v1/index/{document_storage_id}', headers = self.headers,
				json = json) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def index_get_document_infos(self, name, keys, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.get(f'/v1/index/{document_storage_id}/{name}', headers = self.headers,
					params = {'key': keys, 'fullInfo': 0}) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def index_get_documents(self, name, keys, document_creation_function, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Loop until up-to-date
		while True:
			# Queue request
			async with self.session.get(f'/v1/index/{document_storage_id}/{name}', headers = self.headers,
					params = {'key': keys, 'fullInfo': 1}) as response:
				# Handle results
				if response.status != 409:
					# Process response
					await self.process_response(response)

					results = await response.json()

					return {k: document_creation_function(v) for k, v in results.items()}

	#-------------------------------------------------------------------------------------------------------------------
	async def info_get(self, keys, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Queue request
		async with self.session.get(f'/v1/info/{document_storage_id}', headers = self.headers,
				params = {'key': keys}) as response:
			# Process response
			await self.process_response(response)

			return await response.json()

	#-------------------------------------------------------------------------------------------------------------------
	async def info_set(self, info, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Queue request
		async with self.session.post(f'/v1/info/{document_storage_id}', headers = self.headers,
				json = info) as response:
			# Process response
			await self.process_response(response)

	#-------------------------------------------------------------------------------------------------------------------
	async def internal_set(self, info, document_storage_id = None):
		# Setup
		document_storage_id = document_storage_id or self.document_storage_id

		# Queue request
		async with self.session.post(f'/v1/internal/{document_storage_id}', headers = self.headers,
				json = info) as response:
			# Process response
			await self.process_response(response)

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

	#-------------------------------------------------------------------------------------------------------------------
	def decode_content_range(self, response):
		# Decode header
		groups = re.split('(\w+)[ ](.+)\/(.+)', response.headers.get('content-range', ''))
		if len(groups) == 5:
			# Compose info
			range = groups[2]
			size = groups[3]

			info = {'unit': groups[1], 'range': range, 'size': size if size == '*' else int(size)}
			if range != '*':
				# Decode range components
				range_parts = range.split('-')
				info['range_start'] = int(range_parts[0])
				info['range_end'] = int(range_parts[1])
			
			return info
		else:
			# Don't have count
			raise Exception('Unable to decode content range from response')
