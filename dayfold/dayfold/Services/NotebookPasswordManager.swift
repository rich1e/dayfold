// Services/NotebookPasswordManager.swift
import Foundation
import CoreData

/// 每本笔记本独立的 4 位 PIN 管理器。
///
/// 设计要点：
/// - 与全局 `SecurityManager` 解耦，使用同一套密码学原语（`CryptoHelpers`）。
/// - 状态全部存于 Core Data（`Notebook.passwordHash / passwordSalt / hasPassword`），
///   in-memory 只缓存失败计数器。App 杀死后冷却归零，与现有全局行为对齐。
/// - 失败节流 **per-notebook**：A 本密码爆破不影响 B 本，符合真实威胁模型。
/// - 每次 sheet / gate 入口都 `init(notebookID:)` 一个新实例，避免跨 UI 状态污染。
@MainActor
final class NotebookPasswordManager: ObservableObject {
    private let notebookID: UUID

    /// in-memory 失败计数 + 冷却。key 是 notebookID，多本管理互不干扰。
    private static var failedAttempts: [UUID: Int] = [:]
    private static var cooldownUntil: [UUID: Date] = [:]

    // 失败节流阈值（与 SecurityManager 对齐）
    private let lockoutShort: TimeInterval = 30
    private let lockoutLong:  TimeInterval = 300
    private let attemptThresholdShort = 5
    private let attemptThresholdLong  = 10

    init(notebookID: UUID) {
        self.notebookID = notebookID
    }

    // MARK: - 状态查询

    /// 当前本子是否设了密码。调用方用 `notebook.isPasswordEnabled`（只读别名）;
    /// 内部写操作直接落 Core Data 的 `hasPassword` 字段（codegen 已暴露）。
    func hasPassword(notebook: Notebook) -> Bool {
        notebook.isPasswordEnabled
    }

    func isInCooldown(notebook: Notebook) -> Bool {
        guard let until = Self.cooldownUntil[notebookID] else { return false }
        if until.timeIntervalSinceNow <= 0 {
            Self.cooldownUntil[notebookID] = nil
            Self.failedAttempts[notebookID] = 0
            return false
        }
        return true
    }

    func remainingCooldown(notebook: Notebook) -> TimeInterval {
        guard let until = Self.cooldownUntil[notebookID] else { return 0 }
        return max(0, until.timeIntervalSinceNow)
    }

    // MARK: - 写操作

    /// 设置新密码（PIN 必须是 4 位）。
    /// 调用方负责 `context.save()`。成功后清失败计数与冷却。
    func set(pin: String, on notebook: Notebook) throws {
        precondition(pin.count == 4, "PIN 必须是 4 位")
        let salt = CryptoHelpers.randomSalt()
        let hash = CryptoHelpers.derive(pin: pin, salt: salt)
        notebook.passwordHash = hash
        notebook.passwordSalt = salt
        notebook.hasPassword = true
        Self.failedAttempts[notebookID] = 0
        Self.cooldownUntil[notebookID] = nil
    }

    /// 验证 PIN。失败累计冷却。
    @discardableResult
    func verify(pin: String, on notebook: Notebook) -> Bool {
        if isInCooldown(notebook: notebook) { return false }
        guard let savedSalt = notebook.passwordSalt,
              let savedHash = notebook.passwordHash,
              !savedSalt.isEmpty, !savedHash.isEmpty else {
            return false
        }

        let candidate = CryptoHelpers.derive(pin: pin, salt: savedSalt)
        let ok = CryptoHelpers.constantTimeEqual(candidate, savedHash)

        if ok {
            Self.failedAttempts[notebookID] = 0
            Self.cooldownUntil[notebookID] = nil
        } else {
            registerFailure(notebook: notebook)
        }
        return ok
    }

    /// 清除密码。调用方负责 `context.save()`。
    func clear(on notebook: Notebook) {
        notebook.passwordHash = nil
        notebook.passwordSalt = nil
        notebook.hasPassword = false
        Self.failedAttempts[notebookID] = 0
        Self.cooldownUntil[notebookID] = nil
    }

    // MARK: - 私有

    private func registerFailure(notebook: Notebook) {
        let current = (Self.failedAttempts[notebookID] ?? 0) + 1
        Self.failedAttempts[notebookID] = current

        if current >= attemptThresholdLong {
            Self.cooldownUntil[notebookID] = Date().addingTimeInterval(lockoutLong)
        } else if current >= attemptThresholdShort {
            Self.cooldownUntil[notebookID] = Date().addingTimeInterval(lockoutShort)
        }
    }
}
