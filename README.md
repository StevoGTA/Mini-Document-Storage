# Mini-Document-Storage
Mini Document Storage reference implementation

See https://docs.google.com/document/d/1zgMAzYLemHA05F_FR4QZP_dn51cYcVfKMcUfai60FXE/edit?usp=sharing for overview

Summary:
  Info table
    Columns: key, value
  Documents table
    Columns: type, lastRevision
  Collections table
    Columns: id, name, type, version, lastRevision
  {DOCUMENTTYPE}s
    Columns: id, documentID, revision
  {DOCUMENTTYPE}Contents
    Columns: id, json
  Collection-{COLLECTIONNAME}
    Columns: id

Will be adding "Associations" soon...

Remote Manifesto
All remote queries that are not requesting full info for specific document IDs will be "minimal" queries, meaning document ID and revision only.  The expectation is that over time, most documents will be cached locally and it is important to minimize data transfer size as some server implementations have a limit on the amount of data that can be passed back and forth in a single call.  Returning full document info, in some circumstances, can approach that limit quickly.
It may be a future optimization to return the current document payload size as part of the minimal return info so that clients can better optimize subsequent queries for payloads to avoid payload size limitations, though there may be more efficient ways of ensuring reliable interactions.

