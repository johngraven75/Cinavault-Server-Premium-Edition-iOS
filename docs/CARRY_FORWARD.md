# CinaVault iOS Carry-Forward Registry

Every release must retain these capabilities unless the owner explicitly approves removal and replacement validation is merged with the change.

## Premium mobile parity

- HTTPS-only communication with the CinaVault Premium Windows server.
- Apple Keychain storage for the authenticated mobile session.
- Opaque remote media keys; server paths and provider credentials never enter client models.
- Authenticated library, artwork, metadata, playback, AirPlay, and Google Cast access.
- Stable media-key reconciliation after every refresh so enriched metadata and posters update the visible media card and current selection.
- HF token ownership remains in the Windows secure store; iOS displays only server-reported readiness.
- Metadata provider readiness is synchronized from Windows at startup and after remote control actions.
- AI Autopilot actions refresh the library and preserve the current media context.

## Change policy

- No registered capability may be removed or weakened unless the repository owner explicitly requests its removal.
- Build-to-build changes must preserve all prior contracts and regression gates.
- Fix the implementation or environment; never delete functionality merely to make a build pass.
- Windows Premium is the credential and metadata authority for Android and iOS parity.
