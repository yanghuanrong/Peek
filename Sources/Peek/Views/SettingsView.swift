import AppKit
import SwiftUI

/// 设置界面：引擎、快捷键、行为开关。
struct SettingsView: View {

    @ObservedObject var settings: SettingsStore
    var onHotKeyChanged: (HotKey) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    engineSection
                    hotKeySection
                    behaviorSection
                    advancedSection
                }
                .padding(18)
            }
            Divider()
            footer
        }
        .frame(width: 460, height: 560)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 15))
                .foregroundStyle(.tint)
            Text("Peek 设置")
                .font(.system(size: 14, weight: .semibold))
            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
    }

    // MARK: - 引擎

    private var engineSection: some View {
        section("翻译引擎", icon: "bolt.horizontal") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Translator.EngineChoice.allCases) { choice in
                    Button {
                        settings.engine = choice
                    } label: {
                        HStack(alignment: .top, spacing: 9) {
                            Image(systemName: settings.engine == choice
                                  ? "largecircle.fill.circle" : "circle")
                                .font(.system(size: 13))
                                .foregroundStyle(settings.engine == choice ? Color.accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 1) {
                                Text(choice.displayName)
                                    .font(.system(size: 12.5, weight: .medium))
                                Text(choice.detail)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - 快捷键

    private var hotKeySection: some View {
        section("全局快捷键", icon: "keyboard") {
            HStack(spacing: 12) {
                HotKeyRecorder(
                    hotKey: Binding(
                        get: { settings.hotKey },
                        set: { settings.hotKey = $0 }
                    ),
                    onChanged: onHotKeyChanged
                )
                .frame(width: 140, height: 28)

                Text("在任意 App 中按下即可呼出翻译面板")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - 行为

    private var behaviorSection: some View {
        section("行为", icon: "slider.horizontal.3") {
            VStack(alignment: .leading, spacing: 9) {
                toggle(
                    "呼出时读取剪贴板",
                    detail: "打开面板自动填入剪贴板内容",
                    isOn: $settings.autoPasteClipboard
                )
                toggle(
                    "监听剪贴板变化",
                    detail: "面板打开时从剪贴板工具选词会自动填入",
                    isOn: $settings.watchClipboard
                )
                toggle(
                    "翻译后自动复制",
                    detail: "出结果后自动写入剪贴板",
                    isOn: $settings.autoCopyResult
                )
                toggle(
                    "保留上次输入",
                    detail: "再次呼出时不自动覆盖输入框",
                    isOn: $settings.keepLastInput
                )
                toggle(
                    "失焦后隐藏面板",
                    detail: "点击其它窗口或切到别的 App 时自动收起",
                    isOn: $settings.hideOnBlur
                )
                toggle(
                    "显示菜单栏图标",
                    detail: "从菜单栏可快速打开与退出",
                    isOn: $settings.showMenuBarItem
                )
                toggle(
                    "开机自动启动",
                    detail: "登录 macOS 后自动运行 Peek",
                    isOn: $settings.launchAtLogin
                )
            }
        }
    }

    // MARK: - 高级

    private var advancedSection: some View {
        section("高级（可选）", icon: "cpu") {
            VStack(alignment: .leading, spacing: 8) {
                Text("MyMemory 邮箱（可选，用于提升免费额度）")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                field("", text: $settings.myMemoryEmail, placeholder: "you@example.com")
            }
        }
    }

    // MARK: - Footer

    /// 从 Info.plist 读取版本号；swift run 等无 bundle 场景回退为 dev
    private static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    private var footer: some View {
        HStack {
            Text("Peek v\(Self.appVersion)")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("完成") { onClose() }
                .keyboardShortcut(.defaultAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
    }

    // MARK: - 组件

    private func section<Content: View>(
        _ title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func toggle(_ title: String, detail: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12.5))
                Text(detail)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func field(
        _ label: String,
        text: Binding<String>,
        placeholder: String,
        isSecure: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if isSecure {
                SecureField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            } else {
                TextField(placeholder, text: text)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
            }
        }
    }
}