# TODOs

Open work on the document-changed notification mechanism.

**W1-W10 are implemented** (2026-08-07): the six-callback API, all call-site rewiring, the Ephemeral lock fixes,
removed-before-teardown ordering, post-settle ordering, C++ registration thread-safety, the MDSDocument
value-change gate, attachment notifications, SQLite's missing server notifications, and the `removeBatchQueue`
finalize fix. Swift and C++ both compile clean.

**Also implemented** (2026-08-07): creates now send no property set so collections/indexes/caches evaluate fresh
(updates still send the delta - the union of updated and removed keys). `checkRelevantProperties` has been
**removed entirely** from Swift and C++ in favour of an optional `relevantProperties`: no value means "always
evaluate", a non-empty array filters on intersection, and an empty array is a programmer error. Remaining work
below.

---

## Work items

### Follow-through

**W1 — Tests.** `M`. The mechanism has **zero** coverage. Minimum worth adding: a callback that reads a document
property on each of the six kinds — that single test exercises both the Ephemeral lock fix (a client proc reading a
property used to re-enter a non-reentrant write lock) and the removed-before-teardown ordering (reading a property
in a `removed` callback used to crash under SQLite). Tests live in `Tests/Xcode/`; C++ and Kotlin have no test
harness in this repo.

**W2 — Sync the vendored copy.** `S`.
`Monkey Tools/Software (Rebuild)/Source/3rdParty/Mini Document Storage` carries a full copy of the C++ and Swift
sources and needs the same changes.

**W5 — JS server still has `checkRelevantProperties`.** `S`.
Swift and C++ dropped the flag in favour of an optional `relevantProperties`; the JS server still carries
`checkRelevantProperties` in `collectionIsIncludedSelectorInfo` (`Source/JS/src/Server/DocumentStorage.js:38-71`,
consumed at `Source/JS/src/Server/Collection.js:50-57`), including the lone
`documentDoesNotHaveProperty(): false`. The two servers now diverge on the same wire protocol: a Swift server
treats an absent `relevantProperties` key as "always evaluate" and rejects an empty array, while a JS server
still reads an array and applies its own per-selector flag.

### Deferred

**W3 — `MDSRemoteStorage` never notifies.** `M`, new work.
Inherits `MDSDocumentStorageCore` so registration compiles, but contains zero notification calls — a silent no-op,
now against a six-way API. Entry points: `MDSRemoteStorage.swift:462, 657, 828, 1035`, plus the sync path at
`:1228, 1238, 1425`.

Required-sets was checked against this before being settled, so it isn't boxed out: the previous backing is still
in `documentBackingCache` when `documentBackingCacheUpdate` builds the replacement from `FullInfo`
(`MDSRemoteStorage.swift:1238-1253`), so it can diff old against new. A cold-cache miss has no baseline — but also
no prior state the client could have observed, so it is a `created` or nothing.

**W4 — Kotlin/Android parity.** `M`.
Kotlin still implements the old single-callback mechanism and has now diverged, since W1-W10 landed for Swift and
C++ only. Sites: `ephemeral/MDSEphemeral.kt:133, 257, 290, 367, 392, 412`;
`sqlite/MDSSQLite.kt:118, 257, 297, 380, 405, 425`; registration at `MDSDocumentStorage.kt:89`,
`MDSDocument.kt:10, 26`.
Kotlin's lock is reentrant, so its in-lock notifications (`367, 392, 412`) don't deadlock — but they do hold a
global write lock across client code. It already gets the post-settle ordering right.

**W11 — Remove the `Internal` concept entirely.** `L`. Independent of the notification work.
The storage-private `Internal` key-value store (`internalGet`/`internalSet`, distinct from the client-visible
`Info` store) was invented for a single situation that has since migrated to something else. Rip it out across
every implementation: Swift (`MDSEphemeral`, `MDSSQLite`, `MDSRemoteStorage`, server), C++ (`CMDSEphemeral`,
`CMDSSQLite`), Kotlin, and the JS/Python clients + JS server — including the SQLite internal table and the
wire-protocol endpoints. `Info` stays. Note that this store currently participates in the coarse
`noteChangesMade` signal (`internalSet`), so that call site goes away with it.

---

## Notes

Observations, not scheduled work. Referenced as N1, N2, ...

*(none open)*
