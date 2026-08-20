# CinaVault iOS — Build 171 Release Notes

## LumaSift Companion

Build 171 introduces **LumaSift**, the iPhone and iPad command center for exact duplicate resolution on a connected CinaVault Windows host. The new branded tab displays the LumaSift prism mark, an owner-controlled selection menu for **videos, MP3 audio, DOCX documents, PDFs, and images**, live phase and percentage, current media name, processed count, exact duplicate groups, quality evidence, reclaimable storage, and named file dispositions.

The companion starts a review-only scan through the existing authenticated HTTPS session, then lets the owner approve a quarantine-first plan. The app deliberately does not send NAS credentials, local paths, or raw Windows drive details to the device. The Windows host remains responsible for selected local folders, external drives, mounted NAS shares, content hashing, ranking, and file movement.

## Safety and Compatibility

No mobile action permanently deletes files. Plan approval moves only lower-ranked, proven exact duplicates to host-side quarantine after a fresh hash check. Existing CinaVault library, AI, security, and server functions remain unchanged. Rollback is performed on the Windows host by restoring from LumaSift quarantine before it is explicitly emptied.
