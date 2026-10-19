<div align="center">

# Peek

> 📖 一个 macOS 划词翻译小工具

[![Version](https://img.shields.io/github/v/tag/yanghuanrong/Peek?label=version)](https://github.com/yanghuanrong/Peek/releases)
[![DMG 体积](https://img.shields.io/badge/DMG%E4%BD%93%E7%A7%AF-2.2MB-blue)](https://github.com/yanghuanrong/Peek/releases/latest)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)](https://github.com/yanghuanrong/Peek)
[![Downloads](https://img.shields.io/github/downloads/yanghuanrong/Peek/total?label=downloads)](https://github.com/yanghuanrong/Peek/releases)

**快捷键呼出 → 读剪贴板 → 中英互译**，一个按键的事。

原生 Swift 编写 · 无 Dock 图标 · 2MB 体积 · 自动更新

</div>

---

## 使用说明

| 快捷键呼出 | 单词查询 | 整句翻译 |
| ---------- | -------- | -------- |
| 复制文字后按下 `⌥D`，面板自动填入并翻译 | 查单词有音标、释义和例句 | 中英自动识别方向，长文分块翻译 |
| <img src="docs/images/word.png" width="280"/> | <img src="docs/images/sentence.png" width="280"/> | |

按 `Esc` 或点其它 App 收起面板；`回车` 重新翻译。

## 特色功能

- [x] 全局快捷键呼出悬浮面板（Carbon 实现，无需辅助功能授权）
- [x] 自动读取剪贴板，复制即译
- [x] 单词词典级信息：音标 / 释义 / 例句
- [x] 多引擎自动调度，失败自动降级
- [x] 译文一键复制，可开启翻译后自动复制
- [x] 开机自启、失焦自动隐藏
- [x] 内置自动更新（Sparkle）
- [x] 原生 SwiftUI + AppKit，内存占用小

## 支持接口

- [x] [有道词典](https://www.youdao.com/) — 单词音标、释义、例句（非官方接口）
- [x] [谷歌翻译](https://translate.google.com) — 整句翻译（非官方接口，需代理）
- [x] [MyMemory](https://mymemory.translated.net/) — 免费备用引擎
- [x] 自动模式 — 单词走有道、整句走谷歌，失败自动降级

## 安装指南

### 通过 Homebrew 安装

```bash
brew tap yanghuanrong/tap
brew install --cask peek
```

更新：

```bash
brew update && brew upgrade --cask peek
```

### 下载安装

1. 从 [Release](https://github.com/yanghuanrong/Peek/releases/latest) 页面下载最新的 `Peek-x.y.z.dmg`
2. 双击挂载，把 Peek 拖入 Applications 文件夹
3. 启动后菜单栏出现书本图标，即可使用

### 故障排除

- **「无法验证开发者」或「文件已损坏」**

    无开发者账号无法公证，从网络下载的包首次打开需手动放行：右键 Peek → 打开；
    或在终端执行后重启 Peek：

    ```bash
    sudo xattr -d com.apple.quarantine /Applications/Peek.app
    ```

- **快捷键无反应**

    设置里重新录制（`⌘0` 等数字组合可用）；可能被其它 App 占用，换一个组合试试。

- **谷歌引擎失败或很慢**

    非官方接口，国内需要系统代理；无代理环境约 5 秒内会自动降级到 MyMemory 出结果。

### 从源码构建

```bash
git clone https://github.com/yanghuanrong/Peek.git
cd Peek
./build.sh
open build/Peek.app
```

需要 macOS 13+ 与 Xcode Command Line Tools。

## 常见问题

| 现象 | 处理 |
| ---- | ---- |
| 一直「翻译中…」 | 网络问题居多；跑 `swift run Peek --selftest` 看引擎连通性 |
| MyMemory 失败 | 免费额度用尽，换引擎 |
| 有道音标/释义缺失 | 网页端接口临时改版或限流；译文不受影响（自动走谷歌/MyMemory） |
| 想换默认快捷键 | 设置（齿轮）→ 快捷键 → 点击录制框按下新组合 |

---

<details>
<summary><strong>For AI agents（维护者阅读）</strong></summary>

本仓库的主要协作者是 AI。改代码前先读本节。

### Goal

只做一件事：**全局快捷键呼出悬浮面板，粘贴/自动填入中英文，给出翻译（单词要有词典级信息）**。不要扩成全能翻译器。

### Hard constraints

- 只支持中英双向；不要加其它语种 UI/路由。
- 不引入新依赖（含 SPM），除非用户明确同意。
- 最小改动；不做顺手重构。
- **禁止直推 `main`**：开 `feature/*` / `fix/*` / `docs/*` 分支 → PR → 等 CI / CodeRabbit → 再合并。
- 钱/权限/支付相关：本项目没有；全局快捷键用 Carbon，**不要**改成需要辅助功能授权的方案。

### Layout (edit here)

```
Sources/Peek/
  main.swift                 # 入口；--selftest / --render / --demo
  App/AppDelegate.swift      # 生命周期、热键、面板显隐（含失焦隐藏）
  App/SelfTest.swift         # 命令行自检
  App/PanelRenderer.swift    # 离屏渲染 PNG
  ViewModels/TranslationViewModel.swift  # 呼出→翻译→复制；须转发 translator 变更
  Translate/Translator.swift # 选路、降级、缓存
  Translate/YoudaoEngine.swift / GoogleEngine.swift / MyMemoryEngine.swift
  HotKey/GlobalHotKeyManager.swift
  Window/FloatingPanel.swift
  Views/TranslationPanelView.swift / SettingsView.swift
  Core/SettingsStore.swift / Language.swift / HTTPClient.swift / ClipboardService.swift / Speaker.swift
```

构建与工程：`Package.swift`、`build.sh`；Xcode 工程由 `scripts/generate_xcodeproj.rb` 生成（已 gitignore）。

### Behavior notes (easy to break)

- UI 只观察 `TranslationViewModel`：`translator` 的 `@Published` 必须转发到 viewModel，否则会卡在「翻译中…」。
- 单词走有道、整句走谷歌（`auto`）；失败降级 MyMemory/有道；有道整句失败是预期，由降级兜住。
- 面板失焦 / 切到其它 App 时按 `hideOnBlur` 隐藏（默认开）。
- 默认不自动写剪贴板；开启「自动复制」后译文会留在剪贴板（不做还原）。
- 快捷键录制仅拦单独 ⇧；⌘+字母/数字等任意组合均可设（用户明确要求随意组合，后果自担）。
- 开机自启用 `SMAppService`（macOS 13+）；启动时以系统登录项实际状态为准修正设置。
- Sparkle 更新器仅在 bundle 含 `SUFeedURL` 时启动（`swift run` 裸二进制不启动，否则挂起）。

### Verify before claiming done

```bash
swift build
swift run Peek --selftest          # 引擎与调度；应几乎全 ✓
swift run Peek --render "serendipity" /tmp/peek-word.png
./build.sh debug && open build/Peek.app
```

交互抽查：`⌥D`（可改）呼出 → 出结果 → 点其它 App 面板应收起。

### 发布新版本

1. 合入 `main` 后打标签：`git tag v0.x.y && git push origin v0.x.y`
2. `release.yml` 自动构建 `Peek-x.y.z.dmg`、签名、生成 appcast.xml 并创建 GitHub Release
3. README 的 DMG 体积徽章会被 workflow 自动更新

### Do not

- 不要把 pot-desktop / Tauri 方案搬进来；本项目是原生 Swift。
- 不要提交 `.build/`、`build/`、`Peek.xcodeproj/`、`xcuserdata`。
- 不要在 README 里堆长篇「如何用 Xcode 下断点」——那些信息应落在代码注释或 PR 里，需要时再搜源码。

</details>
