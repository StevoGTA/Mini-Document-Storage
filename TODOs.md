# TODOs

Open, forward-looking work. Each item has a referenceable ID.

## Work items

### Follow-through

**W5 — JS server still has `checkRelevantProperties`.** `S`.
Swift and C++ dropped the flag in favour of an optional `relevantProperties`; the JS server still carries
`checkRelevantProperties` in `collectionIsIncludedSelectorInfo` (`Source/JS/src/Server/DocumentStorage.js:38-71`,
consumed at `Source/JS/src/Server/Collection.js:50-57`), including the lone
`documentDoesNotHaveProperty(): false`. The two servers diverge on the same wire protocol: a Swift server treats
an absent `relevantProperties` key as "always evaluate" and rejects an empty array, while a JS server still reads
an array and applies its own per-selector flag.

### Deferred

**W1 — Tests.** `M`. Likely folds into a much larger effort to introduce unit tests across the project.
The notification mechanism has zero coverage. Minimum worth adding: a callback that reads a document property on
each of the six kinds — that single test exercises both the Ephemeral non-reentrant-lock path (a client proc
reading a property from inside a callback) and the removed-before-teardown ordering (reading a property in a
`removed` callback under SQLite). Tests live in `Tests/Xcode/`; C++ and Kotlin have no test harness in this repo.

**W3 — `MDSRemoteStorage` never notifies.** `M`.
Inherits `MDSDocumentStorageCore` so registration compiles, but contains zero notification calls — a silent no-op
against the six-callback API. Entry points: `MDSRemoteStorage.swift:462, 657, 828, 1035`, plus the sync path at
`:1228, 1238, 1425`.

Required-sets is available: the previous backing is still in `documentBackingCache` when
`documentBackingCacheUpdate` builds the replacement from `FullInfo` (`MDSRemoteStorage.swift:1238-1253`), so it can
diff old against new. A cold-cache miss has no baseline — but also no prior state the client could have observed,
so it is a `created` or nothing.

**W4 — Kotlin/Android parity.** `M`.
Kotlin still implements the old single-callback mechanism and has diverged from Swift and C++.
Sites: `ephemeral/MDSEphemeral.kt:133, 257, 290, 367, 392, 412`;
`sqlite/MDSSQLite.kt:118, 257, 297, 380, 405, 425`; registration at `MDSDocumentStorage.kt:89`,
`MDSDocument.kt:10, 26`.
Kotlin's lock is reentrant, so its in-lock notifications (`367, 392, 412`) don't deadlock — but they do hold a
global write lock across client code. It already gets the post-settle ordering right.

**W11 — Remove the `Internal` concept entirely.** `L`. Independent of the notification work.
The storage-private `Internal` key-value store (`internalGet`/`internalSet`, distinct from the client-visible
`Info` store) was invented for a single situation that has since migrated to something else. Rip it out across
every implementation: Swift (`MDSEphemeral`, `MDSSQLite`, `MDSRemoteStorage`, server), C++ (`CMDSEphemeral`,
`CMDSSQLite`), Kotlin, and the JS/Python clients + JS server — including the SQLite internal table and the
wire-protocol endpoints. `Info` stays. This store currently participates in the coarse `noteChangesMade` signal
(`internalSet`), so that call site goes away with it.

## Notes

Observations, not scheduled work. Referenced as N1, N2, ...

*(none open)*
