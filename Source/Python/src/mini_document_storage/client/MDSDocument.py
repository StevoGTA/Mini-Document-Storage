#
# MDSDocument.py
#
# Created by Stevo on 5/16/2023.
# Copyright © 2023 Stevo Brock.  All rights reserved
#

# Imports
import base64
from datetime import datetime
import uuid

#-----------------------------------------------------------------------------------------------------------------------
# MDSDocument
class MDSDocument:
    
	# Properties
	@property
	def document_id(self):																# str
		return self.info['documentID']
	@property
	def revision(self):																	# int (None if not yet created)
		return self.info.get('revision')
	
	@property
	def is_active(self):																# bool
		return self.info['active'] == 1
	def set_active(self, active):
		# Update
		self.info['active'] = 1 if active else 0
	
		# Note updated
		self.active_changed = True
	def toggle_is_active(self):
		# Update
		self.info['active'] = 1 - self.info['active']

		# Note updated
		self.active_changed = True
	
	@property
	def creation_date(self):															# datetime (None if not yet created)
		value = self.info.get('creationDate')

		return datetime.fromisoformat(value.replace('Z', '+00:00')) if value else None
	
	@property
	def modification_date(self):														# datetime (None if not yet created)
		value = self.info.get('modificationDate')

		return datetime.fromisoformat(value.replace('Z', '+00:00')) if value else None
	
	@property
	def	has_create_info(self):															# bool
		return self.creation_date == None
	
	@property
	def has_update_info(self):															# bool
		return self.updated or self.removed or self.active_changed
	
	# Lifecycle methods
	#-------------------------------------------------------------------------------------------------------------------
	def __init__(self, info = None):
		# Check situation
		if info == None:
			# New
			document_id = base64.urlsafe_b64encode(uuid.uuid4().bytes).decode('utf-8').strip('=')

			self.info = {'documentID': document_id, 'active': 1, 'json': {}, 'attachments': {}}
			self.is_new = True
		else:
			# Store
			self.info = info
			self.is_new = False
		
		# Finish setup
		self.updated = {}
		self.removed = set()
		self.active_changed = False
	
	# Python methods
	#-------------------------------------------------------------------------------------------------------------------
	def __eq__(self, other):
		return self.document_id == other.document_id

	#-------------------------------------------------------------------------------------------------------------------
	def __hash__(self):
		return hash(self.document_id)

	# Instance methods
	#-------------------------------------------------------------------------------------------------------------------
	def attachments(self, type):
		return {id: info for (id, info) in self.info['attachments'].items() if info['info']['type'] == type}
	
	# Subclass methods
	#-------------------------------------------------------------------------------------------------------------------
	def value(self, property):
		# Check situation
		if property in self.updated:
			# Have updated value
			return self.updated[property]
		elif property in self.removed:
			# Was removed
			return None
		elif property in self.info['json']:
			# Not updated
			return self.info['json'][property]
		else:
			# Not present
			return None

	#-------------------------------------------------------------------------------------------------------------------
	def set(self, property, value = None):
		# Check value
		if value != None:
			# Have value
			self.updated[property] = value
			self.removed.discard(property)
		else:
			# Don't have value
			self.updated.pop(property, None)
			self.removed.add(property)

	#-------------------------------------------------------------------------------------------------------------------
	def note_property_changed(self, property):
		# Updated
		self.updated[property] = self.info['json'][property]
		self.removed.discard(property)

	# Internal methods
	#-------------------------------------------------------------------------------------------------------------------
	def create_info(self):
		# Return info
		return {'documentID': self.document_id, 'json': self.updated}

	#-------------------------------------------------------------------------------------------------------------------
	def update_from_create(self, info):
		# Update
		self.info['revision'] = info['revision']
		self.info['creationDate'] = info['creationDate']
		self.info['modificationDate'] = info['modificationDate']
		self.info['json'] = self.updated

		self.is_new = False

		# Reset
		self.updated = {}
		self.removed.clear()

	#-------------------------------------------------------------------------------------------------------------------
	def update_info(self):
		# Setup
		update_info = {'documentID': self.document_id}

		# Check if have updated properties
		if self.updated:
			# Have updated properties
			update_info['updated'] = self.updated
		
		# Check if have removed properties
		if self.removed:
			# Have removed properties
			update_info['removed'] = list(self.removed)
		
		# Check if active changed
		if self.active_changed:
			# Active changed
			update_info['active'] = self.info['active']
		
		return update_info

	#-------------------------------------------------------------------------------------------------------------------
	def update_from_update(self, info):
		# Update
		self.info['revision'] = info['revision']
		self.info['active'] = info['active']
		self.info['modificationDate'] = info['modificationDate']

		self.info['json'] = info['json']

		# Reset
		self.updated.clear()
		self.removed.clear()
		self.active_changed = False
