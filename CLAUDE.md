# Mini Document Storage

Fast, inexpensive document storage. The same document-storage model is implemented independently in
**Swift, C++, Kotlin/Android, JavaScript, and Python** — this repo holds all of them side by side.

## The one rule that matters

**Changes to the document-storage model must be mirrored across every language that implements it.** There is no
shared core and no code generation — the implementations are hand-kept in parallel. Before changing an API,
determine which of the five languages actually implement the thing you're touching (the matrix below), then change
all of them or explicitly note which were deferred and why.

Drift between implementations is the primary source of bugs in this repo. When you find drift, say so — don't
silently match whichever one you read first.

## Layout

```
Source/Swift/          Swift: Ephemeral, SQLite, Remote client, Remote server
Source/C++/            C++: Ephemeral, SQLite
Source/JS/src/         JS: thin HTTP client + Node/MySQL server
Source/JS/AWS Lambda/  JS: Lambda handlers
Source/JS/Express/     JS: Express server
Source/Python/src/     Python: thin HTTP client
src/main/java/...      Kotlin/Android: Ephemeral, SQLite
Tests/Xcode/           Xcode test project (Unit, Transaction, Performance) — the only automated tests
```

Depends on sibling toolbox repos, expected as peers of this one:
[Swift Toolbox](https://github.com/StevoGTA/SwiftToolbox), [C++ Toolbox](https://github.com/StevoGTA/CppToolbox),
[Android Toolbox](https://github.com/StevoGTA/AndroidToolbox). They supply the collection, concurrency, and SQLite
primitives (`CString`, `TNArray`, `LockingDictionary`, `CReadPreferringLock`, …).

## Model

A **DocumentStorage** holds **Documents** — an id, a revision, creation/modification dates, a property map, and
attachments. Documents are typed by a `documentType` string. Layered on top:

| Concept | What it does |
|---|---|
| **Association** | Many-to-many links between two document types |
| **Collection** | Filtered subset of a document type, maintained by an `isIncluded` proc |
| **Index** | Key → document mapping, maintained by a `keys` proc |
| **Cache** | Precomputed values per document, maintained by `value` procs |
| **Batch** | Thread-scoped buffer of changes applied atomically at commit |
| **Info / Internal** | Key-value stores (client-visible / storage-private) |

Collections, indexes, and caches each declare `relevantProperties` and are brought up to date lazily by revision.
`MDSUpdateInfo.changedProperties` drives that filtering, where **`nil` means "unknown — assume everything changed"**.
Preserve that convention in any new API carrying a property set.

Coalescing to the minimal set of work is the *point* of a batch, and the notification behavior follows from that by
design: outside a batch, N property writes produce N `updated` callbacks; inside one, they collapse to a single
callback carrying the union. Both sides are correct — don't "fix" the asymmetry.

**Create vs. update is deliberately asymmetric**, and the rule rests on one contract: `isIncluded` / `keys` /
`value` procs are pure functions of the document's declared `relevantProperties`.

- **Create sends no property set** (`nil` in Swift, the 3-arg `TMDSUpdateInfo` ctor in C++). There is no prior
  state, so nothing can be safely excluded — everything must evaluate fresh. Sending the new document's key set
  here is *unsound*, because absence is meaningful: a proc keyed on `status` must still run for a document created
  without a `status`. Filtering it out is permanent, since `lastRevision` advances outside the relevance check.
- **Update sends the delta** — the union of updated and removed keys. The prior result was correct against the
  prior state, and the proc reads only relevant properties, so if the delta doesn't intersect `relevantProperties`
  no input moved and the earlier result still stands. Skipping is provably safe.

Attachments are deliberately outside this: they are not properties, they never appear in a delta, and clients that
need to react to them use the attachment callbacks rather than collection/index/cache relevance.

`relevantProperties` is **optional**, and that single parameter carries the whole contract - there is no separate
"check" flag:

| value | meaning |
|---|---|
| non-empty | filter - re-evaluate only when the delta intersects |
| `nil` (Swift) / no value (C++) | the proc is not pure over a property set - always evaluate |
| empty array | **programmer error** - `fatalError` in Swift, `AssertFailIf` in C++ |

It is not persisted as an optional: SQLite stores the empty string for "no value" and the read maps that back to
`nil`, so what a debugger shows matches what was passed in. Over the wire, "no value" is sent by **omitting** the
`relevantProperties` key; a server receiving the key with an empty array returns `.badRequest` rather than
asserting.

### Storage implementations

| | Ephemeral | SQLite | Remote client | Server |
|---|---|---|---|---|
| Swift | ✔ | ✔ | ✔ | ✔ |
| C++ | ✔ | ✔ | — | header only |
| Kotlin | ✔ | ✔ | — | — |
| JS | — | — | ✔ (client) | ✔ (MySQL) |
| Python | — | — | ✔ (client) | — |

Kotlin is a generation behind: no associations, no caches, no `MDSDocumentStorageCore` equivalent. JS and Python
clients are thin HTTP wrappers with no local storage and no change notification.

Swift: `MDSDocumentStorage` (protocol) + `MDSDocumentStorageCore` (shared registration/ephemeral-value base);
`MDSEphemeral`, `MDSSQLite`, `MDSRemoteStorage` all inherit Core and conform to the protocol.
C++: `CMDSDocumentStorage` abstract base with `CMDSEphemeral` and `CMDSSQLite` subclasses.

### Locking and callbacks

Ephemeral implementations guard their document maps with a **non-reentrant** read-write lock
(`ReadPreferringReadWriteLock` / `CReadPreferringLock`, both `pthread_rwlock_t`). Kotlin uses a reentrant one.
Never invoke a client-supplied proc while holding that lock — a callback that reads a document property will
re-enter and deadlock. Collect the notifications inside the lock, drain them after release.

SQLite's `databaseManager.batch()` is **not a transaction** — it is a per-thread write-deferral buffer that flushes
collection/index/cache tables *after* the proc returns. Work done inside it does not see settled storage.

Deferred notifications are collected into **per-kind lists** and drained in a fixed order:
**created → updated → attachment created → attachment updated → attachment removed** (removed documents notify
immediately, before teardown, so they are not in this list). This guarantees a document's `created`/`updated`
callback precedes any of its attachment callbacks — clients relying on that ordering (e.g. "document created before
its attachments") stay correct. Swift and C++ must keep the same grouping and order; do not revert to a single
insertion-ordered list.

## Conventions

Follow the surrounding code exactly; it is highly uniform.

- **Tabs**, 4-wide. Lines wrap at 120 columns, continuation lines aligned under the construct.
- 120-dash banner comment above every function/method definition; `// MARK: Section` for grouping.
- Nearly every statement gets a short comment above it (`// Setup`, `// Check for batch`, `// Call proc`).
- C++ prefixes: `C` class, `T` template, `S` struct/scalar, `E` enum, `k` enum constant, `m` member.
  Wrappers: `I<>` instance ref, `OV<>` optional value, `OR<>` optional reference, `TVResult<>` value-or-error.
- C++ classes use the `Internals` pimpl pattern behind `mInternals`.
- Swift: space before the type colon (`let	x :String`), tabs between keyword and name.
- Errors: C++ returns `OV<SError>` / `TVResult<>` rather than throwing; Swift throws `MDSDocumentStorageError`.

## Build & test

- **Tests:** open `Tests/Xcode/Mini Document Storage Tests.xcodeproj`. Unit and Transaction tests run against a
  local server; `Tests/Xcode/Common/Config.swift` selects `local` (server hosted in the Xcode project, port 34343)
  or `server` (external, port 1138). No CI is configured.
- **Android:** `build.gradle` (library, `com.android.library`), expects `:AndroidToolbox` in the same Gradle build.
- **JS:** `Source/JS`, published to npm as `mini-document-storage` (version in `package.json`).
- **Python:** `Source/Python`, published to PyPI as `mini-document-storage` (version in `pyproject.toml`).
- **Swift/C++:** no package manifest here — consumed by including the sources in the host project.

Bump the JS/Python version in the same commit that changes their sources; commit messages in this repo lead with
the language (`C++ - …`, `Swift - …`, `Python - … Published as 1.11.3.`).

## Notes

- `Source/JS/node_modules` is committed despite `.gitignore` — leave it alone.
- Monkey Tools vendors a copy of this repo at
  `Monkey Tools/Software (Rebuild)/Source/3rdParty/Mini Document Storage`. Changes here need syncing there.
- Open work and pending design decisions live in [TODOs.md](TODOs.md).
