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
