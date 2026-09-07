// Services/SecurityManager.swift
import Foundation
import LocalAuthentication
import CryptoKit
import CommonCrypto

@MainActor
final class SecurityManager: ObservableObject {
    // MARK: - 公开类型

    enum LockMode: String, CaseIterable, Identifiable {
        case immediately, after1Min, after5Min, after15Min

        var id: String { rawValue }

        var seconds: TimeInterval {
            switch self {
            case .immediately: return 0
            case .after1Min:   return 60
            case .after5Min:   return 300
            case .after15Min:  return 900
            }
        }

        var label: String {
            switch self {
            case .immediately: return "马上"
            case .after1Min:   return "1 分钟后"
            case .after5Min:   return "5 分钟后"
            case .after15Min:  return "15 分钟后"
            }
        }
    }

    /// 用户可感知到的冷却状态。View 通过 `isInCooldown` 决定键盘是否禁用。
    struct CooldownState: Equatable {
        let until: Date
        var remaining: TimeInterval { max(0, until.timeIntervalSinceNow) }
    }

    // MARK: - 已发布状态

    @Published var isLocked: Bool
    @Published private(set) var hasPassword: Bool
    @Published var isBiometricEnabled: Bool
    @Published var promptForBiometric: Bool
    @Published var lockGrace: LockMode
    @Published private(set) var cooldown: CooldownState?
    @Published private(set) var lastError: String?

    // MARK: - 私有

    private var failedAttempts = 0
    private let defaults = UserDefaults.standard

    private let kPasswordHash     = "security.passwordHash"
    private let kPasswordSalt     = "security.passwordSalt"
    private let kBiometric        = "security.faceIDEnabled"
    private let kPromptBiometric  = "security.promptFaceID"
    private let kGrace            = "security.lockGraceSeconds"
    private let kLastBackground   = "security.lastBackgroundAt"

    private let biometricContext = LAContext()

    // 失败节流阈值
    private let lockoutShort: TimeInterval = 30
    private let lockoutLong:  TimeInterval = 300
    private let attemptThresholdShort = 5
    private let attemptThresholdLong  = 10

    // MARK: - Init

    init() {
        // 读取持久化字段
        let biometric = defaults.object(forKey: kBiometric) as? Bool ?? true
        let promptBio = defaults.object(forKey: kPromptBiometric) as? Bool ?? true
        let savedGrace = defaults.object(forKey: kGrace) as? Double
        let hasPwd = defaults.string(forKey: kPasswordHash) != nil
            && defaults.string(forKey: kPasswordSalt) != nil

        self.isBiometricEnabled = biometric
        self.promptForBiometric = promptBio
        self.hasPassword = hasPwd
        self.lockGrace = Self.lockMode(from: savedGrace) ?? .immediately

        // 启动时即锁屏（若任一防护开启）
        self.isLocked = hasPwd || biometric
    }

    private static func lockMode(from seconds: TimeInterval?) -> LockMode? {
        guard let s = seconds else { return nil }
        switch s {
        case LockMode.immediately.seconds: return .immediately
        case LockMode.after1Min.seconds:   return .after1Min
        case LockMode.after5Min.seconds:   return .after5Min
        case LockMode.after15Min.seconds:  return .after15Min
        default: return nil
        }
    }

    // MARK: - 公开：密码

    /// 设置或修改密码。传入必须为 4 位数字。
    func setPassword(_ pin: String) {
        precondition(pin.count == 4, "PIN 必须是 4 位")
        let salt = Self.randomSalt()
        let hash = Self.derive(pin: pin, salt: salt)
        defaults.set(salt, forKey: kPasswordSalt)
        defaults.set(hash, forKey: kPasswordHash)
        hasPassword = true
        failedAttempts = 0
        cooldown = nil
        // 设置密码后立即锁屏
        isLocked = true
    }

    /// 清除密码。需要当前密码通过校验。
    func clearPassword(currentPin: String) throws {
        guard verifyPassword(currentPin) else {
            throw NSError(domain: "SecurityManager", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "当前密码错误"
            ])
        }
        defaults.removeObject(forKey: kPasswordHash)
        defaults.removeObject(forKey: kPasswordSalt)
        hasPassword = false
        failedAttempts = 0
        cooldown = nil
        // 关闭密码后立即解锁（让用户回到 App）
        isLocked = false
    }

    /// 校验密码。**调用前请检查 `cooldown == nil`**，否则统一返回 false。
    @discardableResult
    func verifyPassword(_ pin: String) -> Bool {
        if cooldown != nil { return false }
        guard
            let savedSalt = defaults.string(forKey: kPasswordSalt),
            let savedHash = defaults.string(forKey: kPasswordHash)
        else { return false }

        let candidate = Self.derive(pin: pin, salt: savedSalt)
        let ok = constantTimeEqual(candidate, savedHash)

        if ok {
            failedAttempts = 0
            cooldown = nil
            lastError = nil
            isLocked = false
        } else {
            registerFailure()
        }
        return ok
    }

    /// PIN 错误时的副作用：累计 + 进入冷却。
    private func registerFailure() {
        failedAttempts += 1
        lastError = "密码错误"

        if failedAttempts >= attemptThresholdLong {
            cooldown = CooldownState(until: Date().addingTimeInterval(lockoutLong))
        } else if failedAttempts >= attemptThresholdShort {
            cooldown = CooldownState(until: Date().addingTimeInterval(lockoutShort))
        }
    }

    var isInCooldown: Bool {
        guard let c = cooldown else { return false }
        if c.remaining <= 0 {
            cooldown = nil
            return false
        }
        return true
    }

    // MARK: - 公开：生物识别

    func setBiometricEnabled(_ newValue: Bool) {
        defaults.set(newValue, forKey: kBiometric)
        isBiometricEnabled = newValue
        if !newValue {
            // 关闭 Face ID 时同时关闭"提示"
            defaults.set(false, forKey: kPromptBiometric)
            promptForBiometric = false
        }
        // 关闭时立刻解锁
        if !newValue && !hasPassword {
            isLocked = false
        } else if newValue {
            isLocked = true
        }
    }

    func setPromptBiometric(_ newValue: Bool) {
        defaults.set(newValue, forKey: kPromptBiometric)
        promptForBiometric = newValue
    }

    func setLockGrace(_ mode: LockMode) {
        defaults.set(mode.seconds, forKey: kGrace)
        lockGrace = mode
    }

    // MARK: - 公开：解锁入口

    /// 综合解锁入口：LockScreenView 在 onAppear 调用。
    /// - 若 Face ID 开启 + 提示开启 → 自动尝试生物识别。
    /// - 若仅密码 → 不调用生物识别（交给 UI 走 PinKeypadView）。
    @discardableResult
    func attemptBiometricUnlock() async -> Bool {
        guard isBiometricEnabled && promptForBiometric else { return false }
        guard canEvaluateBiometrics else {
            // 设备无生物识别 → 降级为解锁
            isLocked = false
            return true
        }
        do {
            let ok = try await biometricContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "解锁 Dayfold"
            )
            if ok { isLocked = false }
            return ok
        } catch {
            return false
        }
    }

    private var canEvaluateBiometrics: Bool {
        var error: NSError?
        return biometricContext.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )
    }

    var biometricsAvailable: Bool { canEvaluateBiometrics }

    // MARK: - 公开：后台 / 前台

    /// 应用进入后台时记录时间。
    func appDidEnterBackground() {
        defaults.set(Date(), forKey: kLastBackground)
    }

    /// 应用回到前台时，根据 lockGrace 决定是否锁屏。
    func appWillEnterForeground() {
        guard hasPassword || isBiometricEnabled else { return }
        guard let last = defaults.object(forKey: kLastBackground) as? Date else {
            isLocked = true
            return
        }
        let elapsed = Date().timeIntervalSince(last)
        // 立即锁屏：always lock；其他：超过 grace 才锁
        if elapsed >= lockGrace.seconds {
            isLocked = true
        }
    }

    func lock() {
        isLocked = true
    }

    // MARK: - 兼容旧 API（SidebarView / SettingsView / LockScreenView）

    /// 旧版「是否启用任意安全防护」的总开关，保留以兼容已有 UI 调用。
    var isEnabled: Bool { hasPassword || isBiometricEnabled }

    /// 旧版总开关切换。语义：关闭两个子开关；至少打开一个子开关。
    func setEnabled(_ newValue: Bool) {
        if newValue {
            // 打开时：若两者都关则开启生物识别
            if !hasPassword && !isBiometricEnabled {
                setBiometricEnabled(true)
            }
        } else {
            if isBiometricEnabled { setBiometricEnabled(false) }
            // 密码不主动清（保持 hash），仅在用户主动走"关闭密码"流程时清
        }
    }

    /// 旧版生物识别入口（被旧 LockScreenView 调用）。内部转发到 `attemptBiometricUnlock`。
    func authenticate() async -> Bool {
        await attemptBiometricUnlock()
    }

    func toggleSecurity() {
        setEnabled(!isEnabled)
    }

    /// 在 UI 已通过 `verifyPassword` 验证当前密码的前提下，直接清空密码 hash。
    /// 用于 SettingsView 关闭密码的 sheet 流程。
    func forceClearPassword() {
        defaults.removeObject(forKey: kPasswordHash)
        defaults.removeObject(forKey: kPasswordSalt)
        hasPassword = false
        failedAttempts = 0
        cooldown = nil
        // 关闭密码后立即解锁
        isLocked = false
    }

    // MARK: - 私有：密码学

    private static func randomSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// PBKDF2-HMAC-SHA256, 100k iterations. iOS 平台使用 `CCKeyDerivationPBKDF`
    /// 是最标准的做法；这里用 CommonCrypto 桥接。
    private static func derive(pin: String, salt: String) -> String {
        let pinBytes = Array(pin.utf8)
        let saltBytes = Array(salt.utf8)
        var derived = [UInt8](repeating: 0, count: 32)

        let status = pinBytes.withUnsafeBufferPointer { pinPtr -> Int32 in
            saltBytes.withUnsafeBufferPointer { saltPtr in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    pinPtr.baseAddress, pinBytes.count,
                    saltPtr.baseAddress, saltBytes.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    100_000,
                    &derived, derived.count
                )
            }
        }
        precondition(status == kCCSuccess, "PBKDF2 派生失败")
        return derived.map { String(format: "%02x", $0) }.joined()
    }

    /// 长度相同的 hex 字符串做常量时间比较。
    private func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a.utf8, b.utf8) {
            diff |= x ^ y
        }
        return diff == 0
    }
}
