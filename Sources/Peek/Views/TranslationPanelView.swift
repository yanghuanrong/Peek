import AppKit
import SwiftUI

/// 主面板：输入区 + 结果区 + 状态栏。
struct TranslationPanelView: View {

    @ObservedObject var viewModel: TranslationViewModel
    @ObservedObject var settings: SettingsStore
    var onClose: () -> Void
    var onOpenSettings: () -> Void
    var onHideRequest: () -> Void

    @FocusState private var inputFocused: Bool
    @State private var hoverCopy = false
    @StateObject private var speaker = Speaker()

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            Divider().opacity(0.6)

            inputArea
                .padding(.horizontal, 14)
                .padding(.top, 12)

            Divider().opacity(0.4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            resultArea
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 14)
                .padding(.bottom, 10)

            statusBar
                .fixedSize(horizontal: false, vertical: true)
        }
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, x: 0, y: 8)
        .onAppear {
            inputFocused = true
            viewModel.startObserving()
        }
    }

    // MARK: - 标题栏

    private var titleBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 12))
                .foregroundStyle(.tint)

            Text("Peek")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(viewModel.directionText)
                .font(.system(size: 10.5, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                .foregroundStyle(Color.accentColor)

            Spacer(minLength: 8)

            Button {
                onHideRequest()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("隐藏面板")
            .keyboardShortcut(.escape, modifiers: [])

            Button {
                onOpenSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("设置")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            // 仅空白区域可拖动窗口，按钮与标签区域不受影响
            WindowDragArea()
        )
    }

    // MARK: - 输入区

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 4) {
                TextField("", text: $viewModel.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .lineLimit(1...4)
                    .focused($inputFocused)
                    .onSubmit { viewModel.translate() }

                // 发音按钮：朗读输入内容；朗读中再点则停止
                Button {
                    speaker.speakOrStop(viewModel.inputText)
                } label: {
                    Image(systemName: speaker.isSpeaking ? "speaker.wave.2.fill" : "speaker.wave.2")
                        .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundStyle(speaker.isSpeaking ? Color.accentColor : Color.secondary)
                .disabled(viewModel.inputText.isEmpty)
                .help("朗读输入内容")
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
            )

            if viewModel.inputText.isEmpty {
                Text("粘贴或输入要翻译的中英文内容…")
                    .font(.system(size: 15))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 11)
                    .allowsHitTesting(false)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 22)
                    .overlay(alignment: .topLeading) {
                        Color.clear.frame(height: 0)
                    }
            }
        }
    }

    // MARK: - 结果区

    @ViewBuilder
    private var resultArea: some View {
        if let error = viewModel.errorMessage {
            errorView(error)
        } else if viewModel.isTranslating && viewModel.output == nil {
            loadingView()
        } else if let output = viewModel.output, output.hasContent {
            resultView(output)
        } else if viewModel.inputText.isEmpty {
            hintView()
        } else {
            emptyView()
        }
    }

    private func loadingView() -> some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
            Text("翻译中…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 46)
    }

    private func errorView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.system(size: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("翻译失败")
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            Button("重试") { viewModel.translate() }
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private func resultView(_ output: TranslationOutput) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 9) {
            // 音标
            if let phonetic = output.phoneticDisplay {
                HStack(spacing: 6) {
                    Text(phonetic)
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                    if output.phonetics.count > 1 {
                        Text(output.phonetics[1])
                            .font(.system(size: 12.5))
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // 主译文
            if !output.translated.isEmpty {
                Text(output.translated)
                    .font(.system(size: 15, weight: .medium))
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().opacity(0.4)

            // 词性释义
            if !output.entries.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(output.groupedEntries) { group in
                        VStack(alignment: .leading, spacing: 3) {
                            if let pos = group.partOfSpeech {
                                Text(pos)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.accentColor.opacity(0.13))
                                    )
                            }
                            ForEach(group.definitions) { entry in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.definition)
                                        .font(.system(size: 12.5))
                                        .textSelection(.enabled)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let example = entry.example {
                                        Text(example)
                                            .font(.system(size: 11))
                                            .italic()
                                            .foregroundStyle(.secondary)
                                            .textSelection(.enabled)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
            }

            // 例句
            if !output.examples.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(output.examples) { example in
                        VStack(alignment: .leading, spacing: 1) {
                            Text(example.source)
                                .font(.system(size: 11.5))
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(example.target)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }

            // 词形变化
            if !output.forms.isEmpty {
                HStack(spacing: 6) {
                    ForEach(output.forms, id: \.self) { form in
                        Text(form)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(Color.primary.opacity(0.06))
                            )
                    }
                    Spacer(minLength: 0)
                }
            }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(11)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(nsColor: .underPageBackgroundColor).opacity(0.55))
            )
        }
    }

    private func hintView() -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("全局呼出", systemImage: "command")
                .font(.system(size: 11.5, weight: .medium))
            HStack(spacing: 6) {
                Text(settings.hotKey.displayString)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.accentColor.opacity(0.16))
                    )
                    .foregroundStyle(Color.accentColor)
                Text("在任意位置按下，然后 ⌘V 粘贴")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
            Text("输入后按 ↵翻译 · ⇥切换 · Esc 隐藏")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func emptyView() -> some View {
        Text("没有可显示的结果")
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack(spacing: 8) {
            if let output = viewModel.output {
                Text(output.engineName)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.tertiary)
            }

            if viewModel.copiedFlash {
                Label("已复制", systemImage: "checkmark")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.green)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)

            if viewModel.output?.hasContent == true {
                Button {
                    viewModel.copyResult()
                } label: {
                    Label("复制译文", systemImage: "doc.on.doc")
                        .font(.system(size: 11))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("复制译文到剪贴板 (⌘⇧C)")
            }

            Button {
                viewModel.clear()
                inputFocused = true
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 10.5))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.tertiary)
            .help("清空")
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.025))
    }

    // MARK: - 样式

    private var panelBackground: some View {
        NSVisualEffectViewRepresentable(material: .popover, blending: .withinWindow)
            .overlay(Color(nsColor: .windowBackgroundColor).opacity(0.35))
    }
}

/// 用原生 NSVisualEffectView 做毛玻璃背景
struct NSVisualEffectViewRepresentable: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blending
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}