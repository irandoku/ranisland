# Ran Island

Ran Island is a personal macOS fork of [Open Island](https://github.com/Octane0411/open-vibe-island): a small, local-first notch companion for coding-agent sessions with an Apple Music surface.

This repository is an independent fork, not an official Open Island release. Version `0.1.0` focuses on the parts that are useful in daily use: the existing agent session surface plus a deliberately small music experience.

[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square)](LICENSE)

## v0.1.0

- Keeps the existing agent session list, status display, approvals, and jump-back workflow.
- Closed notch: current Apple Music album artwork on the left and the active session count on the right.
- Expanded notch: the agent session list remains the default surface.
- Agent list: compact Apple Music mini-player with track information and play/pause.
- Music surface: click the mini-player to open the full Apple Music control panel.
- Metadata and playback control use AppleScript; the bundled [MediaRemote Adapter](https://github.com/ungive/mediaremote-adapter) is used as an artwork fallback.
- Hermes integration is intentionally not included in v0.1.0.

The package and executable targets still use the upstream `OpenIsland*` names internally. Keeping those identifiers avoids breaking existing hook paths, app-support data, and local automation while the public project name becomes Ran Island.

## Requirements

- macOS 14 or later
- Xcode and the Swift toolchain
- Apple Music for the music surface
- Automation permission when macOS asks Ran Island to control Music or focus a terminal

The current personal validation environment is macOS 27 beta with Xcode 27 beta. This is the tested environment for v0.1.0; it is not a claim that every macOS/Xcode combination has been validated.

## Build and run

```bash
git clone https://github.com/irandoku/ranisland.git
cd ranisland

swift build
swift test
swift run OpenIslandApp
```

When selecting a beta Xcode explicitly:

```bash
DEVELOPER_DIR="/Applications/Xcode-beta.app" xcrun swift build
DEVELOPER_DIR="/Applications/Xcode-beta.app" xcrun swift test
```

The app target is `OpenIslandApp` because the internal Swift package target names are intentionally retained for v0.1.0 compatibility.

## How it is arranged

```text
Agent hook
  -> OpenIslandHooks
  -> local Unix socket
  -> BridgeServer / AppModel
  -> agent notch surface

Apple Music
  -> AppleScript metadata and controls
  -> MediaRemote Adapter artwork fallback
  -> music mini-player or full music surface
```

## Inspiration and attribution

The projects below have different roles; inspiration is not the same as copied code.

| Project | License | Role in Ran Island |
|---|---|---|
| [Open Island](https://github.com/Octane0411/open-vibe-island) | GPLv3 | Direct upstream source and architectural basis. This fork contains modifications. |
| [Atoll](https://github.com/Ebullioscopic/Atoll) | GPLv3 | UI/UX reference for a compact notch that expands into a focused media surface; no Atoll dependency is bundled. |
| [Vibe Notch](https://github.com/farouqaldori/vibe-notch) | Apache-2.0 | Notch/session interaction reference; no Vibe Notch dependency is bundled. |
| [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) | BSD-3-Clause | Bundled artwork fallback loader and helper framework. Its license is included in `Sources/OpenIslandApp/Resources/MediaRemoteAdapter/`. |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) 2.4.1 | MIT | SwiftUI Markdown rendering dependency. |
| [Sparkle](https://github.com/sparkle-project/Sparkle) 2.9.4 | MIT plus upstream external notices | Automatic-update framework dependency; its upstream license and external notices remain authoritative. |
| [NetworkImage](https://github.com/gonzalezreal/NetworkImage) 6.0.1 | MIT | Transitive MarkdownUI dependency resolved by Swift Package Manager. |
| [swift-cmark](https://github.com/swiftlang/swift-cmark) 0.8.0 | BSD-2-Clause | Transitive MarkdownUI dependency resolved by Swift Package Manager. |

## License

Ran Island is distributed under the GNU General Public License v3.0. The GPL choice follows the direct Open Island source, which is GPLv3; the Apple Music work and the permissively licensed dependencies do not independently require GPL.

This is a modified fork for personal use. The v0.1.0 fork changes were made in 2026. See [LICENSE](LICENSE) and the third-party license file shipped with the MediaRemote fallback.
