#!/usr/bin/env python3
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]
errors: list[str] = []


def read(relative_path: str) -> str:
    path = ROOT / relative_path
    if not path.is_file():
        errors.append(f"missing file: {relative_path}")
        return ""
    return path.read_text(encoding="utf-8").replace("\r\n", "\n")


def require_all(relative_path: str, tokens: list[str]) -> str:
    text = read(relative_path)
    for token in tokens:
        if token not in text:
            errors.append(f"missing invariant in {relative_path}: {token}")
    return text


require_all(
    "project.yml",
    [
        "type: application",
        'iOS: "17.0"',
        "SWIFT_VERSION",
        "CinaVaultIOSTests",
        "MARKETING_VERSION: 2.0.10",
        "CURRENT_PROJECT_VERSION: 110",
    ],
)
require_all(
    "Podfile",
    ["google-cast-sdk", "'4.8.4'", "platform :ios, '17.0'"],
)
info = require_all(
    "CinaVaultIOS/Info.plist",
    [
        "NSAllowsArbitraryLoads",
        "<false/>",
        "NSLocalNetworkUsageDescription",
        "_googlecast._tcp",
        "_CC1AD845._googlecast._tcp",
        "_airplay._tcp",
        "_raop._tcp",
    ],
)
if "<key>NSAllowsArbitraryLoads</key>\n        <true/>" in info:
    errors.append("iOS must not allow arbitrary network loads")

models = require_all(
    "CinaVaultIOS/Models.swift",
    [
        "mediaKey",
        "artworkUrl",
        "streamUrl",
        "ControlSnapshot",
        "CastGrant",
        "case library",
        "case sources",
        "case downloads",
        'case liveTV = "live-tv"',
        "case server",
        "case security",
        "case remote",
        "case advanced",
        'case cloudNAS = "cloud-nas"',
        "case extensions",
        'case intelligence = "ai-autopilot"',
        "case settings",
    ],
)
media_start = models.find("struct MediaItem")
server_start = models.find("struct ServerInfo")
if media_start < 0 or server_start <= media_start:
    errors.append("MediaItem must be defined before ServerInfo")
else:
    media_model = models[media_start:server_start]
    for forbidden in ("filePath", "file_path", "localPath", "absolutePath"):
        if forbidden in media_model:
            errors.append(f"iOS MediaItem exposes forbidden local path field: {forbidden}")

api = require_all(
    "CinaVaultIOS/CinaVaultAPI.swift",
    [
        "SecureRedirectDelegate",
        "completionHandler(nil)",
        'scheme?.lowercased() == "https"',
        'forHTTPHeaderField: "Authorization"',
        '"/api/auth/password"',
        '"/api/auth/access-key"',
        '"/api/library"',
        '"/api/control/snapshot"',
        '"/api/control/action"',
        '"/api/cast/grant/\\(mediaKey)"',
        "Credentials must not be embedded",
    ],
)
if "http://" in api:
    errors.append("iOS API source must not contain plaintext HTTP endpoints")

require_all(
    "CinaVaultIOS/KeychainSessionStore.swift",
    [
        "kSecClassGenericPassword",
        "kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly",
        "SecItemAdd",
        "SecItemCopyMatching",
        "SecItemDelete",
    ],
)
require_all(
    "CinaVaultIOS/CinaVaultModel.swift",
    [
        "KeychainSessionStore",
        "aiAutopilotEnabled",
        "automaticRefreshEnabled",
        "loadControlSnapshot",
        "runControlAction",
        "createCastGrant",
        "smartSort",
        "Task.sleep",
        "refreshedLibrary",
        "$0.mediaKey == selected.mediaKey",
        "Managed by Windows secure store",
        "Startup readiness synchronized from Windows",
    ],
)
require_all(
    "CinaVaultIOS/CastingSupport.swift",
    [
        "AVRoutePickerView",
        "prioritizesVideoDevices = true",
        "GCKDiscoveryCriteria",
        "GCKUICastButton",
        "GCKMediaInformationBuilder",
        "temporary encrypted grant",
    ],
)

views = require_all(
    "CinaVaultIOS/CinaVaultViews.swift",
    [
        "SpatialShell",
        "NavigationRail",
        "CompactNavigation",
        "CommandPalette",
        'keyboardShortcut("k", modifiers: [.command])',
        "Color(red: 0.008, green: 0.016, blue: 0.051).opacity(0.98)",
        "GridItem(.adaptive",
        "AuthenticatedArtwork",
        "PlayerView",
        "CastingView",
        "ControlDestinationView",
        "IntelligenceView",
        "SettingsView",
        "RecoveryView",
        "CONTROL ENDPOINT PENDING",
        "no action is represented as available",
        "HF token",
        "model.hfTokenStatus",
        "model.metadataProviderStatus",
        "Provider secrets remain in the Windows secure store",
    ],
)
for forbidden in (".blur(", ".scaleEffect(", "ultraThinMaterial", "regularMaterial"):
    if forbidden in views:
        errors.append(f"iOS user shell reintroduces compositor-risk material: {forbidden}")

require_all(
    "CinaVaultIOS/CinaVaultTheme.swift",
    [
        "SpatialBackground",
        "CVColor.ink",
        "electric" if False else "CVColor.cyan",
        "accessibilityReduceMotion" if False else "motionEnabled",
    ],
)
require_all(
    "CinaVaultIOS/CinaVaultIOSApp.swift",
    [
        "RecoveryMonitor",
        "beginLaunch",
        "markCleanBackground",
        "Build109RootView",
        "preferredColorScheme(.dark)",
    ],
)

require_all(
    "docs/CARRY_FORWARD.md",
    [
        "Stable media-key reconciliation",
        "Windows secure store",
        "provider readiness",
        "No registered capability may be removed",
    ],
)

contract_text = read("docs/platform-parity.json")
if contract_text:
    try:
        contract = json.loads(contract_text)
    except json.JSONDecodeError as error:
        errors.append(f"invalid docs/platform-parity.json: {error}")
    else:
        expected_reference = {
            "repository": "johngraven75/CinaVault-Premium",
            "release": "v2-build-1.10",
            "platform": "windows",
        }
        if any(contract.get("reference", {}).get(key) != value for key, value in expected_reference.items()):
            errors.append("iOS parity contract must reference current Windows v2 Build 1.10")
        included = contract.get("includedRepositories")
        expected = [
            "johngraven75/CinaVault-Premium",
            "johngraven75/cinavault-android",
            "johngraven75/Cinavault-Server-Premium-Edition-iOS",
        ]
        if included != expected:
            errors.append("iOS platform contract repository set drifted")
        excluded = contract.get("excludedRepositories", [])
        if len(excluded) != 1 or excluded[0].get("repository") != "johngraven75/Cinavault-Reimagined":
            errors.append("Cinavault-Reimagined must remain explicitly excluded")
        required_destinations = {
            "library", "sources", "downloads", "live-tv", "server", "security",
            "remote", "advanced", "cloud-nas", "extensions", "ai-autopilot", "settings",
        }
        actual_destinations = {entry.get("id") for entry in contract.get("destinations", [])}
        if not required_destinations.issubset(actual_destinations):
            errors.append("iOS contract is missing Windows destinations")
        defect_ids = {entry.get("id") for entry in contract.get("defectParity", [])}
        if defect_ids != {f"CVP-{index:03d}" for index in range(1, 10)}:
            errors.append("iOS contract must track CVP-001 through CVP-009")
        policy = contract.get("changePolicy", {})
        for key in ("fullFileReplacementsOnly", "noRegressions", "crossPlatformAuditRequired"):
            if policy.get(key) is not True:
                errors.append(f"iOS parity policy must keep {key}=true")

adult_provider_root = ROOT / "CinaVaultIOS" / "Resources" / "AdultProviders"
adult_provider_keys = ["tpdb", "stashdb", "pgma", "porn_site_nuxt", "iafd", "phoenixadult"]
for provider_key in adult_provider_keys:
    provider_path = adult_provider_root / f"{provider_key}.json"
    if not provider_path.is_file():
        errors.append(f"missing adult provider config: {provider_path.relative_to(ROOT)}")
        continue
    try:
        provider_config = json.loads(provider_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        errors.append(f"invalid adult provider JSON {provider_key}: {error}")
        continue
    if provider_config.get("_key") != provider_key:
        errors.append(f"adult provider config key mismatch: {provider_key}")
    if provider_config.get("enabled") is not True:
        errors.append(f"adult provider must start enabled: {provider_key}")
    if provider_config.get("poster_download") is not True:
        errors.append(f"adult poster provider must start enabled: {provider_key}")

if errors:
    print("CinaVault iOS end-to-end parity verification failed:")
    for error in errors:
        print(f" - {error}")
    sys.exit(1)

print("CinaVault iOS end-to-end parity verification passed.")
