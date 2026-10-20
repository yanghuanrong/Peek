import AppKit
import Carbon.HIToolbox
import Foundation
import Combine

/// 全局快捷键模型。序列化为整数 keyCode + 修饰键位掩码。
struct HotKey: Codable, Equatable, Hashable {

    var keyCode: UInt16
    var carbonModifiers: UInt32

    static let `default` = HotKey(
        keyCode: UInt16(kVK_ANSI_D),
        carbonModifiers: UInt32(optionKey)
    )

    var isValid: Bool { carbonModifiers != 0 && keyCode != 0 }

    /// 人类可读展示，如 "⌥D"
    var displayString: String {
        var s = ""
        if carbonModifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if carbonModifiers & UInt32(optionKey) != 0 { s += "⌥" }
        if carbonModifiers & UInt32(shiftKey) != 0 { s += "⇧" }
        if carbonModifiers & UInt32(cmdKey) != 0 { s += "⌘" }
        s += Self.keyName(keyCode)
        return s
    }

    /// 把 NSEvent 修饰键转换为 Carbon 掩码
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        return carbon
    }

    /// 从逆事件读出 NSEvent 修饰键（用于录制控件）
    static func eventModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        carbonModifiers(from: flags)
    }

    /// 键码转可读名称。
    /// 直接引用 Carbon 的 kVK_* 常量，避免手写数字表出错。
    static func keyName(_ code: UInt16) -> String {
        let c = Int(code)

        // 数字键
        let digits: [(Int, String)] = [
            (kVK_ANSI_0, "0"), (kVK_ANSI_1, "1"), (kVK_ANSI_2, "2"),
            (kVK_ANSI_3, "3"), (kVK_ANSI_4, "4"), (kVK_ANSI_5, "5"),
            (kVK_ANSI_6, "6"), (kVK_ANSI_7, "7"), (kVK_ANSI_8, "8"),
            (kVK_ANSI_9, "9")
        ]
        for (value, name) in digits where value == c { return name }

        // 字母键
        let letters: [(Int, String)] = [
            (kVK_ANSI_A, "A"), (kVK_ANSI_B, "B"), (kVK_ANSI_C, "C"),
            (kVK_ANSI_D, "D"), (kVK_ANSI_E, "E"), (kVK_ANSI_F, "F"),
            (kVK_ANSI_G, "G"), (kVK_ANSI_H, "H"), (kVK_ANSI_I, "I"),
            (kVK_ANSI_J, "J"), (kVK_ANSI_K, "K"), (kVK_ANSI_L, "L"),
            (kVK_ANSI_M, "M"), (kVK_ANSI_N, "N"), (kVK_ANSI_O, "O"),
            (kVK_ANSI_P, "P"), (kVK_ANSI_Q, "Q"), (kVK_ANSI_R, "R"),
            (kVK_ANSI_S, "S"), (kVK_ANSI_T, "T"), (kVK_ANSI_U, "U"),
            (kVK_ANSI_V, "V"), (kVK_ANSI_W, "W"), (kVK_ANSI_X, "X"),
            (kVK_ANSI_Y, "Y"), (kVK_ANSI_Z, "Z")
        ]
        for (value, name) in letters where value == c { return name }

        // 功能与符号键
        let specials: [(Int, String)] = [
            (kVK_Return, "↩"), (kVK_Escape, "Esc"), (kVK_Space, "Space"),
            (kVK_Delete, "Delete"), (kVK_Tab, "⇥"), (kVK_Space, "Space"),
            (kVK_ANSI_Comma, ","), (kVK_ANSI_Slash, "/"), (kVK_ANSI_Semicolon, ";"),
            (kVK_ANSI_Minus, "-"), (kVK_ANSI_Equal, "="),
            (kVK_ANSI_RightBracket, "]"), (kVK_ANSI_LeftBracket, "["),
            (kVK_ANSI_Backslash, "\\"), (kVK_ANSI_Quote, "'"),
            (kVK_ANSI_Grave, "`"), (kVK_ANSI_Period, ".")
        ]
        for (value, name) in specials where value == c { return name }

        return "键码 \(c)"
    }
}

/// 应用设置，使用 UserDefaults 持久化。
final class SettingsStore: ObservableObject {

    @Published var engine: Translator.EngineChoice {
        didSet { defaults.set(engine.rawValue, forKey: Keys.engine) }
    }
    @Published var hotKey: HotKey {
        didSet {
            defaults.set(hotKey.carbonModifiers, forKey: Keys.hotKeyModifiers)
            defaults.set(Int(hotKey.keyCode), forKey: Keys.hotKeyCode)
        }
    }
    /// 呼出时自动读取剪贴板
    @Published var autoPasteClipboard: Bool {
        didSet { defaults.set(autoPasteClipboard, forKey: Keys.autoPaste) }
    }
    /// 面板打开期间监听剪贴板变化（如从 Maccy 选词后自动填入）
    @Published var watchClipboard: Bool {
        didSet { defaults.set(watchClipboard, forKey: Keys.watchClipboard) }
    }
    /// 翻译成功后自动写入剪贴板
    @Published var autoCopyResult: Bool {
        didSet { defaults.set(autoCopyResult, forKey: Keys.autoCopy) }
    }
    /// 失焦后自动隐藏面板
    @Published var hideOnBlur: Bool {
        didSet { defaults.set(hideOnBlur, forKey: Keys.hideOnBlur) }
    }
    /// 面板再次呼出时保留上次内容
    @Published var keepLastInput: Bool {
        didSet { defaults.set(keepLastInput, forKey: Keys.keepInput) }
    }
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
    /// 显示菜单栏图标
    @Published var showMenuBarItem: Bool {
        didSet { defaults.set(showMenuBarItem, forKey: Keys.showMenuBar) }
    }

    @Published var myMemoryEmail: String {
        didSet { defaults.set(myMemoryEmail, forKey: Keys.myMemoryEmail) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let engine = "engine"
        static let hotKeyModifiers = "hotkey.modifiers"
        static let hotKeyCode = "hotkey.code"
        static let autoPaste = "autoPasteClipboard"
        static let watchClipboard = "watchClipboard"
        static let autoCopy = "autoCopyResult"
        static let hideOnBlur = "hideOnBlur"
        static let keepInput = "keepLastInput"
        static let launchAtLogin = "launchAtLogin"
        static let showMenuBar = "showMenuBarItem"
        static let myMemoryEmail = "mymemory.email"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        engine = Translator.EngineChoice(rawValue: defaults.string(forKey: Keys.engine) ?? "")
            ?? .auto

        let mods = UInt32(defaults.object(forKey: Keys.hotKeyModifiers) as? Int ?? 0)
        let code = UInt16(defaults.object(forKey: Keys.hotKeyCode) as? Int ?? 0)
        if mods != 0 && code != 0 {
            hotKey = HotKey(keyCode: code, carbonModifiers: mods)
        } else {
            hotKey = .default
        }

        autoPasteClipboard = defaults.object(forKey: Keys.autoPaste) as? Bool ?? true
        watchClipboard = defaults.object(forKey: Keys.watchClipboard) as? Bool ?? true
        autoCopyResult = defaults.object(forKey: Keys.autoCopy) as? Bool ?? false
        hideOnBlur = defaults.object(forKey: Keys.hideOnBlur) as? Bool ?? true
        keepLastInput = defaults.object(forKey: Keys.keepInput) as? Bool ?? false
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        showMenuBarItem = defaults.object(forKey: Keys.showMenuBar) as? Bool ?? true

        myMemoryEmail = defaults.string(forKey: Keys.myMemoryEmail) ?? ""
    }
}