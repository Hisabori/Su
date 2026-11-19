# PWA device_check synchronization investigation — 2026-11-19

## Scope and evidence

Baseline main: b931e43bb00312d4c1ad90d56e784df175950610. Existing commits 77232db8eea0fd466826e3d896f442ffb5ab476e and b931e43 were fast-forwarded and preserved.

The supplied PWA result 1798 (user 69) has 19 ordinary steps and no device_check. AOS result 1789 belongs to user 53: these are different records, not before/after versions. Neither operational record was modified by this investigation.

## Recording and submission timing

1. A successful manual query creates a work-local device_check only while eligible work is active.
2. A checkpoint stores checks and replay keys in the current user's work draft.
3. Finish waits for manual requests that began during work, flushes the journal, then includes checks with ordinary answers in the single work_result request. Existing receipt and duplicate-submission protections remain in ResultSubmissionService.
4. Completed-work queries are read-only. Checked-out queries remain blocked. Ten-minute monitoring history is separate from the work-result journal.

Previous code could discard a valid observation after checkpoint failure, drop concurrent observations through a boolean busy guard, or exclude an in-flight query when finish set saving/awaitingSave before its response. These are reproducible code paths; without original request logs they cannot conclusively explain the historical result 1798.

## APK static evidence and limits

Existing recovered Dart AOT disassembly under asm/suho_angel shows:

- WorkScreen._openDeviceStatus at 0x436f54 calls KioskCapacityService.fetch at 0x437274. Its success callback at 0x437e74 appends a DeviceCheckRecord to state field_cb.
- No submitWorkResult call appears in that query function or its success callback. _submitWorkResult at 0x2a376c serializes the accumulated list.
- The completed ResultScreen callback at 0x4381fc passes recordForResult:false into _openDeviceStatus.
- KioskCapacity.checkStatus at 0x437fac formats valid available capacity as one decimal percent.
- DeviceCheckRecord.toResultJson at 0x2d1f8c emits type/device_name/기기상태체크/시간/isAvailable. The supplied AOS server record also contains 업무내용:'기기체크'; preserve that field from the user's existing schema fix. Backend enrichment or APK-version differences have not been established.

The recovered inventory identifies package com.innaim.suhoangel, version 1.0.0, APK SHA256 557f34845199aa08eca88f928b917e42253b802a861e306c683f97014fcaedaf. The named suhoangel_261014.apk was not independently rehashed here.

Static evidence supports accumulating checks and submitting with work completion, with read-only completed-screen queries. It does not prove every runtime branch or exclude a separate update endpoint elsewhere. No undocumented endpoint or result_id update was introduced. AOS network capture is still needed for runtime confirmation.

## Admin compatibility

Public original admin main.dart.js renders device_check rows from result_json, reads the percentage string from 기기상태체크, device_name, 시간 and isAvailable. Its list request is PUT /api/admin/list_work_result with packetid, user_id, start_date and end_date. The existing work-result API remains PUT /api/user/work_result; ret:1/result_id is the submission acknowledgement.

The journal emits:

```json
{"type":"device_check","device_name":"여주아울렛04","기기상태체크":"1.2%","시간":"2026-11-19 09:01:35","isAvailable":true,"업무내용":"기기체크"}
```

No privileged admin access, original API session, or DB credentials are available. Thus original DB persistence and actual admin visibility have not been verified. A successful mocked round trip is not operational DB evidence.

## Changes

- Add DeviceCheckJournal: serialize writes; retain observations on local storage failure; retry checkpoint; validate user identity/availability/capacity; deduplicate using user, partner, kiosk and full-precision timestamp. Identity keys stay out of original server JSON.
- Save and restore replay keys alongside checks. Older drafts without keys remain readable.
- Share the manual reading path across modern and legacy views; capture eligibility before network work; drain eligible in-flight reads before freezing the result payload.
- Preserve read-only completed-work behavior and one-result submission. No query-time work_result requests or modifications to historical results.
- Add journal unit tests and an isolated browser integration fixture; register the latter in browser CI. Test credentials and admin responses are mocked.

## Validation

Unit tests cover one query, repeated/replayed query, different devices with identical names/times, concurrent checkpoint writes, local failure/retry/restore, invalid readings, unavailable devices and user isolation. Browser coverage targets manual query/refresh, network retry, reload, finish, completed-work read-only queries, finish/query race and mocked admin JSON comparison.

Record final executed results separately from this scenario inventory. Local recording, mocked submission acknowledgement, and operational DB verification are distinct outcomes.

## Remaining verification

Capture AOS requests for login → work start → manual query → work completion → completed-screen query → logout, with tokens redacted. For an authorized real work session, read back the newly returned result_id via list_work_result under the same user and compare device_check entries. Do not use supplied records 1798/1789 as test targets or create artificial operational work results.

### Executed results

- Flutter analyze: no issues.
- Focused journal/schema/draft/submission tests: 14 passed.
- Full Flutter test suite: 114 passed.
- Flutter release Web build and prepare-pwa.py: passed. Existing Wasm interoperability and Cupertino font warnings remain; this is the JavaScript Web release build.
- New Chromium integration: passed manual reads, same-event replay after reload, network failure/retry, one work submission, post-completion read-only behavior and mocked admin JSON comparison.
- New Chromium race scenario: passed; automatic finish waits for the already-started manual read and sends exactly one result containing that check.
- Operational admin/DB: not verified. User reported admin access, but no connected authenticated session or new result comparison was supplied (latest response: TBD).
