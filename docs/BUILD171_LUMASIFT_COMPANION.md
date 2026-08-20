# Build 171 — LumaSift Companion Design (iOS)

## Purpose

**LumaSift** gives CinaVault iOS users a polished, high-contrast duplicate-resolution command center. The owner selects videos, MP3 audio, DOCX documents, PDFs, and/or images before the iOS client monitors and reviews scans performed by the authenticated Windows CinaVault host, displays exact duplicate groups and their quality explanations, and permits the owner to approve a quarantine-first resolution plan.

The feature is designed for a media owner operating an iPhone or iPad away from the Windows machine that holds the local drives and mounted NAS share. It preserves the current application’s server-mediated model rather than pretending that iOS can scan or delete arbitrary remote file systems.

## Architecture

### Front end

A LumaSift tab uses the shared cinematic visual system and the prism brand mark. It presents percentage progress, active phase, current file, per-source status, reclaimable storage, duplicate groups, winner rationale, and a clear state for each losing candidate: pending review, queued for quarantine, quarantined, retained, skipped, or failed. The view uses accessible contrast, VoiceOver labels, dynamic type, and explicit destructive-action language.

### Connector / integration

`CinaVaultAPI` calls the authenticated local-network endpoints exposed by the Windows host: selected-category LumaSift scan start, status, resolution plan, and plan-application. It passes the existing session credential exactly as it does for library requests, observes server cancellation/error responses, and never stores or displays NAS credentials.

### Back end

The iOS application adds only observable state and a small, testable API client adapter. The Windows host remains responsible for directory enumeration, NAS connectivity, content hashing, scoring, file movement, permission errors, audit dispositions, and permanent removal policy.

## Public Contracts

| Contract | Client behavior |
|---|---|
| `GET /api/lumasift/status` | Poll while active; render phase, processed/total count, percentage, current path display name, and source status. |
| `GET /api/lumasift/plan` | Render a read-only quality-ranked plan, including winner and each candidate disposition. |
| `POST /api/lumasift/plan/apply` | Submit only an owner-confirmed quarantine plan identifier. Never submit a permanent-delete action. |

## Safety and Validation

The application disables plan application while the scan is active, while a request is in flight, or if the displayed plan is stale. It requires an explicit confirmation sheet that says files are being moved to quarantine, displays the count and reclaimable bytes, and shows a server result summary afterwards. It treats all server-provided paths as display-only text and does not attempt local file operations.

Validation includes API decoding/error tests, stale-plan and unauthenticated response tests, view-model state tests for each disposition, accessibility review of dynamic type and VoiceOver descriptions, and an authenticated device/simulator user flow against the Windows server contract.

## Brand System

The iOS presentation uses the **LumaSift** name, the three-facet prism/checkmark mark, and the shared obsidian/cyan/violet/magenta/gold palette. CinaVault remains the host product and connection identity; LumaSift names the duplicate-resolution experience.
