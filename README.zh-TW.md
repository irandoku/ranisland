# Ran Island

Ran Island 是 [Open Island](https://github.com/Octane0411/open-vibe-island) 的個人 macOS fork：保留原本的 coding-agent session notch，並加入 Apple Music 的小型播放體驗。

這是獨立的自用 fork，不是 Open Island 官方 release。`v0.1.0` 先維持原本的 agent 功能，再以簡單、連貫的方式加入音樂播放；Hermes 整合刻意延後，不包含在這個版本。

[English README](README.md) · [简体中文](README.zh-CN.md) · [GPL-3.0 License](LICENSE)

## v0.1.0 功能

- 保留 agent session list、狀態、核准流程與跳回原 terminal 的工作流。
- notch 收合時：左側顯示目前 Apple Music album artwork，右側顯示 active session 數量。
- notch 展開時：預設仍是 agent session list。
- session list 內提供小型 Music mini-player，可查看曲目與播放／暫停。
- 點選 mini-player 後進入完整 Apple Music 控制面板。
- 曲目資訊與播放控制使用 AppleScript；album artwork 在需要時使用隨附的 [MediaRemote Adapter](https://github.com/ungive/mediaremote-adapter) fallback。

Swift package 內部仍保留 `OpenIsland*` target 名稱，以避免破壞既有 hooks、App Support 資料與本機自動化；公開專案名稱則是 Ran Island。

## 需求

- macOS 14 以上
- Xcode 與 Swift toolchain
- Apple Music
- macOS 詢問時，允許 Ran Island 控制 Music 或聚焦 terminal 的 Automation 權限

目前 v0.1.0 實測環境是 macOS 27 beta 與 Xcode 27 beta；這是目前已驗證的環境，不代表所有 macOS／Xcode 組合都已驗證。

## 建置與執行

```bash
git clone https://github.com/irandoku/ranisland.git
cd ranisland

swift build
swift test
swift run OpenIslandApp
```

若要明確使用 beta Xcode：

```bash
DEVELOPER_DIR="/Applications/Xcode-beta.app" xcrun swift build
DEVELOPER_DIR="/Applications/Xcode-beta.app" xcrun swift test
```

## Inspiration 與 attribution

這些專案的角色不同；參考 UI／UX 不等於拷貝程式碼。

| 專案 | 授權 | 在 Ran Island 的角色 |
|---|---|---|
| [Open Island](https://github.com/Octane0411/open-vibe-island) | GPLv3 | 直接上游與架構基礎；本 repo 是修改後的 fork。 |
| [Atoll](https://github.com/Ebullioscopic/Atoll) | GPLv3 | 收合 notch 與展開 media surface 的 UI／UX 參考；沒有帶入 Atoll dependency。 |
| [Vibe Notch](https://github.com/farouqaldori/vibe-notch) | Apache-2.0 | notch／session 互動參考；沒有帶入 Vibe Notch dependency。 |
| [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) | BSD-3-Clause | 隨附的 artwork fallback loader 與 helper framework；授權檔位於 `Sources/OpenIslandApp/Resources/MediaRemoteAdapter/`。 |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) 2.4.1 | MIT | SwiftUI Markdown rendering dependency。 |
| [Sparkle](https://github.com/sparkle-project/Sparkle) 2.9.4 | MIT 與上游 external notices | automatic-update framework dependency。 |

## License

Ran Island 使用 GNU GPL v3.0。原因是直接上游 Open Island 使用 GPLv3；Apple Music 功能與 MIT／BSD 類依賴本身並不會單獨要求 GPL。詳見 [LICENSE](LICENSE) 與 MediaRemote fallback 隨附的第三方授權檔。
