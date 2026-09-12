// Services/CryptoHelpers.swift
import Foundation
import Security
import CommonCrypto

/// 加密原语：随机盐、PIN 派生、常量时间比较。
/// 抽出供 `SecurityManager`（全局 App 锁屏）与 `NotebookPasswordManager`（per-notebook 锁）共用，
/// 保证两端使用同一算法（PBKDF2-HMAC-SHA256 / 100k 迭代）。
enum CryptoHelpers {
    /// 生成 16 字节随机盐，返回 32 字符 hex。
    static func randomSalt() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    /// PBKDF2-HMAC-SHA256，100k 迭代，输出 32 字节 → 64 字符 hex。
    static func derive(pin: String, salt: String) -> String {
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

    /// 长度相同的 hex 字符串做常量时间比较，避免时序侧信道泄露。
    static func constantTimeEqual(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a.utf8, b.utf8) {
            diff |= x ^ y
        }
        return diff == 0
    }
}
