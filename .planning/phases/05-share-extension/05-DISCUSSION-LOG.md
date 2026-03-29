# Phase 5: Share Extension - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-03-29
**Phase:** 05-share-extension
**Areas discussed:** Extension UI, File handoff strategy, Main app refresh, Duplicate detection

---

## Extension UI

| Option | Description | Selected |
|--------|-------------|----------|
| Minimal — auto-dismiss | Show "Adding to SonicMerge..." HUD with filename and spinner, auto-dismiss on completion. No user confirmation. | ✓ |
| Confirm view with Add button | Show filename, file size, Add / Cancel buttons. User explicitly confirms before copy. | |

**User's choice:** Minimal auto-dismiss
**Notes:** Fastest path, matches iOS share extension conventions for utility apps. No extra tap required from the user.

---

## File Handoff Strategy

| Option | Description | Selected |
|--------|-------------|----------|
| Copy to App Group + open main app via URL scheme | Extension copies raw file → App Group, then calls `extensionContext.open(sonicmerge://import?file=...)`. Main app handles via `onOpenURL`. | ✓ |
| Write SwiftData from extension | Extension writes AudioClip record directly to shared SwiftData store. Main app refreshes on foreground. | |
| Pending file marker only | Extension copies file + writes JSON marker. Main app imports on next foreground. | |

**User's choice:** Copy to App Group + open main app via URL scheme
**Notes:** Clean handoff — no SwiftData writes from extension process. File path embedded in URL as query parameter (`sonicmerge://import?file=<filename>`).

Follow-up — embed file path in URL:

| Option | Description | Selected |
|--------|-------------|----------|
| Yes — embed file path in URL | `sonicmerge://import?file=clips%2Fuuid.m4a` — main app reads path, calls `importFiles([url])`. Precise and immediate. | ✓ |
| No — generic signal, app scans folder | `sonicmerge://import` — main app scans App Group folder and diffs against known clips. | |

**User's choice:** Embed file path in URL

---

## Main App Refresh

| Option | Description | Selected |
|--------|-------------|----------|
| onOpenURL covers it | iOS delivers the URL to running app via `onOpenURL` — same code path for cold and hot launch. No extra mechanism needed. | ✓ |
| Also add scenePhase refresh | Add scenePhase `.active` scan as belt-and-suspenders. | |

**User's choice:** `onOpenURL` covers it
**Notes:** Handles both cold launch and hot launch (app already in foreground). No additional polling needed.

---

## Duplicate Detection

| Option | Description | Selected |
|--------|-------------|----------|
| Filename-based dedup | Check `displayName` against existing AudioClips in SwiftData before normalization. Fast, no extra I/O. | ✓ |
| Content hash (SHA256) | Hash first 64KB as fingerprint. Accurate across renames but adds I/O cost. | |

**User's choice:** Filename-based dedup
**Notes:** Good enough for v1 voice memo use case. Edge case (two different files with same name deduplicated) is acceptable.

Follow-up — where does the check run:

| Option | Description | Selected |
|--------|-------------|----------|
| Main app inside `importFiles()` | Dedup co-located with import pipeline. No SwiftData access in extension. | ✓ |
| Extension before copy | Extension reads SwiftData before even copying. More responsive but adds complexity. | |

**User's choice:** Main app inside `importFiles()`

---

## Claude's Discretion

- NSExtensionPrincipalClass implementation approach (UIViewController subclass vs SwiftUI hosting)
- Extension error handling (silent dismiss on failure)
- Memory-safe file loading for large files (`loadFileRepresentation` over `loadDataRepresentation`)
- HUD layout details and animation
- Extension target configuration (bundle ID suffix, deployment target, entitlements)

## Deferred Ideas

None raised during discussion.
