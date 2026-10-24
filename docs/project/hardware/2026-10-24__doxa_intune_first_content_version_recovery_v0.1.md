# Doxa Intune — recover failed initial content version without creating another app

**Date:** 2026-10-24 | **Branch:** doxa/installer-clean-pr-20261024 | **PR:** #78

## Actual live attempt (after owner-approved Microsoft sign-in)
- Existing DMR Intune pilot app `5ebf4ee9-0e28-4a2d-913c-82c4ac5495a4`, created by this run series, is *unpublished* and has **no assignments**.
- Existing dedicated group `3f74c6a3-d470-4d78-8c17-756381465095` targets only `MARIUS-DELL`.
- The owner authorised the same delegated scopes again; Microsoft Graph again confirmed `MARIUS-DELL` uniquely managed and compliant, and the correct unpublished Doxa app was reused.
- Graph POST to its `microsoft.graph.win32LobApp/contentVersions` failed HTTP 400: `The mobile app content cannot be updated before the first content version is committed.`
- The first version's file had earlier reached `commitFileFailed`. The latest attempt **never reached the newly implemented block upload**. Therefore the block-upload repair remains LIVE_UNVERIFIED.
- No new app, no deployment assignment, no software install, no Doxa driver change, no policy expansion.

## Narrow recovery implementation
Microsoft Graph v1.0 documents listing and deleting uncommitted `mobileAppContentFile` records. The publisher now reuses the original first content version (rather than attempting to create a second one) under these strict controls:
1. Verify exact previously recorded Doxa app ID/name/type/publisher/command, `notPublished`, no committed content and **zero assignments**.
2. Verify the original version set contains **exactly one** version with a numeric ID, or create the first version if none exist. Refuse multiple versions.
3. Inspect its file collection. If it contains exactly one uncommitted `IntunePackage.intunewin` with `uploadState=commitFileFailed` and exact original/encrypted byte sizes, delete **only that failed file** and verify absence. Never delete a committed/unknown file or the app itself.
4. Reuse that same first version to upload a new file using Azure Put Block + Put Block List, verify blob size and request a fresh Graph cryptographic commit.
5. If an interruption occurs after deletion but before new file creation, continue with the same empty first version rather than creating a duplicate.
6. Assign only after Graph reports content committed and app `published`, and only if the private group still contains exactly Dell.

The recovery is *not a proven Microsoft live success* until an owner-approved new delegated sign-in and a real Graph test. The associated `Test-DoxaIntunePublish.py` mocks verified the strict existing-version recovery, refused unknown/committed files, and ensured no second-version POST in these cases. Existing encrypted bundle is unchanged and vendor driver redistribution remains NOT_APPROVED.

### Sources
- https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontentfile-list?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontentfile-delete?view=graph-rest-1.0
- https://learn.microsoft.com/en-us/graph/api/intune-apps-mobileappcontentfile-commit?view=graph-rest-1.0

## Stopping conditions
If Intune reports unexpected version/file state, failure to delete that one known failed file, or publication/assignment mismatch, stop and preserve evidence. Never escalate to deleting the entire app or enrolling unrelated devices automatically.
