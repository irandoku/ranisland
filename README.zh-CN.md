# Ran Island

Ran Island 是 [Open Island](https://github.com/Octane0411/open-vibe-island) 的个人 macOS fork：保留原本的 coding-agent session notch，并加入 Apple Music 的小型播放体验。

这是独立的自用 fork，不是 Open Island 官方 release。`v0.1.0` 先维持原本的 agent 功能，再以简单、连贯的方式加入音乐播放；Hermes 集成刻意延后，不包含在这个版本。

[English README](README.md) · [繁體中文（台灣）](README.zh-TW.md) · [GPL-3.0 License](LICENSE)

## v0.1.0 功能

- 保留 agent session list、状态、批准流程与跳回原 terminal 的工作流。
- notch 收起时：左侧显示当前 Apple Music album artwork，右侧显示 active session 数量。
- notch 展开时：默认仍是 agent session list。
- session list 内提供小型 Music mini-player，可查看曲目与播放／暂停。
- 点击 mini-player 后进入完整 Apple Music 控制面板。
- 曲目信息与播放控制使用 AppleScript；album artwork 在需要时使用随附的 [MediaRemote Adapter](https://github.com/ungive/mediaremote-adapter) fallback。

Swift package 内部仍保留 `OpenIsland*` target 名称，以避免破坏既有 hooks、App Support 数据与本机自动化；公开项目名称则是 Ran Island。

## 需求

- macOS 14 以上
- Xcode 与 Swift toolchain
- Apple Music
- macOS 询问时，允许 Ran Island 控制 Music 或聚焦 terminal 的 Automation 权限

当前 v0.1.0 实测环境是 macOS 27 beta 与 Xcode 27 beta；这是目前已验证的环境，不代表所有 macOS／Xcode 组合都已验证。

## 构建与运行

```bash
git clone https://github.com/irandoku/ranisland.git
cd ranisland

swift build
swift test
swift run OpenIslandApp
```

如需明确使用 beta Xcode：

```bash
DEVELOPER_DIR="/Applications/Xcode-beta.app" xcrun swift build
DEVELOPER_DIR="/Applications/Xcode-beta.app" xcrun swift test
```

## Inspiration 与 attribution

这些项目的角色不同；参考 UI／UX 不等于拷贝代码。

| 项目 | 许可证 | 在 Ran Island 的角色 |
|---|---|---|
| [Open Island](https://github.com/Octane0411/open-vibe-island) | GPLv3 | 直接上游与架构基础；本 repo 是修改后的 fork。 |
| [Atoll](https://github.com/Ebullioscopic/Atoll) | GPLv3 | 收起 notch 与展开 media surface 的 UI／UX 参考；没有带入 Atoll dependency。 |
| [Vibe Notch](https://github.com/farouqaldori/vibe-notch) | Apache-2.0 | notch／session 交互参考；没有带入 Vibe Notch dependency。 |
| [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter) | BSD-3-Clause | 随附的 artwork fallback loader 与 helper framework；许可证文件位于 `Sources/OpenIslandApp/Resources/MediaRemoteAdapter/`。 |
| [MarkdownUI](https://github.com/gonzalezreal/swift-markdown-ui) 2.4.1 | MIT | SwiftUI Markdown rendering dependency。 |
| [Sparkle](https://github.com/sparkle-project/Sparkle) 2.9.4 | MIT 与上游 external notices | automatic-update framework dependency。 |

## License

Ran Island 使用 GNU GPL v3.0。原因是直接上游 Open Island 使用 GPLv3；Apple Music 功能与 MIT／BSD 类依赖本身并不会单独要求 GPL。详见 [LICENSE](LICENSE) 与 MediaRemote fallback 随附的第三方许可证文件。
