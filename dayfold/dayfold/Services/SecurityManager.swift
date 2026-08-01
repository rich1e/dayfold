// Services/SecurityManager.swift
import Foundation
import LocalAuthentication

class SecurityManager: ObservableObject {
    @Published var isLocked = true
    @Published var isEnabled = true

    private let context = LAContext()
    private let defaults = UserDefaults.standard
    private let isEnabledKey = "security.faceIDEnabled"

    init() {
        self.isEnabled = defaults.object(forKey: isEnabledKey) as? Bool ?? true
    }

    func authenticate() async -> Bool {
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("Biometric authentication not available: \(error?.localizedDescription ?? "Unknown error")")
            await MainActor.run {
                isLocked = false
            }
            return true
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "解锁 Dayfold"
            )

            await MainActor.run {
                if success {
                    isLocked = false
                }
            }

            return success
        } catch {
            print("Authentication failed: \(error.localizedDescription)")
            return false
        }
    }

    func lock() {
        isLocked = true
    }

    func setEnabled(_ newValue: Bool) {
        defaults.set(newValue, forKey: isEnabledKey)
        isEnabled = newValue
        if !newValue {
            isLocked = false
        }
    }

    func toggleSecurity() {
        setEnabled(!isEnabled)
    }
}
