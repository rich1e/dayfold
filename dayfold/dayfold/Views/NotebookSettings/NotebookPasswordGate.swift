// Views/NotebookSettings/NotebookPasswordGate.swift
import SwiftUI
import UIKit

/// 笔记本密码 gate。
///
/// 三种 mode：
/// - `.verify` 进入 NotebookDetailView 前的 PIN 验证。
/// - `.set` 首次设置 PIN（两步流：输入 → 重复）。
/// - `.verifyThenClear` 关闭密码前验证当前 PIN。
///
/// 复用现有 `PinKeypadView`（无修改），按 SettingsView 的 disablePasswordSheet 模式包装。
struct NotebookPasswordGate: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    enum Mode {
        case verify
        case set
        case verifyThenClear
    }

    let mode: Mode
    @ObservedObject var notebook: Notebook
    /// 成功回调 — verify 模式进详情 / set 模式保存后关闭 / verifyThenClear 模式清除后关闭
    var onSuccess: () -> Void = {}

    @StateObject private var manager: NotebookPasswordManager
    @State private var firstPin: String = ""
    @State private var errorToken: Int = 0
    @State private var setStep: SetStep = .create

    private enum SetStep { case create, confirm }

    init(mode: Mode, notebook: Notebook, onSuccess: @escaping () -> Void = {}) {
        self.mode = mode
        self.notebook = notebook
        self.onSuccess = onSuccess
        let id = notebook.id ?? UUID()
        _manager = StateObject(wrappedValue: NotebookPasswordManager(notebookID: id))
    }

    /// 1s tick,驱动 cooldown 倒计时重绘。
    @State private var tick: Date = Date()

    var body: some View {
        ZStack {
            theme.backgroundPrimary.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                Spacer(minLength: 0)
                keypad
                Spacer(minLength: 0)
            }
        }
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(mode == .verify)
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { now in
            tick = now
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            if mode != .verify {
                Button {
                    goBackOrDismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .regular))
                        .foregroundColor(theme.textPrimary)
                        .frame(width: 44, height: 44)
                }
            }

            Spacer()

            Text(topBarTitle)
                .font(.warmHeadline)
                .foregroundColor(theme.textPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(theme.textSecondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .frame(height: 56)
    }

    private var topBarTitle: String {
        switch mode {
        case .verify:           return "输入密码"
        case .set:              return setStep == .create ? "设置密码" : "再次输入"
        case .verifyThenClear:  return "关闭密码"
        }
    }

    // MARK: - 键盘

    @ViewBuilder
    private var keypad: some View {
        if manager.isInCooldown(notebook: notebook) {
            VStack(spacing: 16) {
                cooldownSubtitle
                PinKeypadView(
                    title: "",
                    subtitle: nil,
                    onComplete: { _ in /* cooldown 期间不接受输入 */ },
                    isDisabled: true
                )
                .id(errorToken)
                .allowsHitTesting(false)
            }
        } else {
            PinKeypadView(
                title: keypadTitle,
                subtitle: keypadSubtitle,
                onComplete: handleComplete,
                isDisabled: false
            )
            .id(errorToken)
        }
    }

    private var keypadTitle: String {
        switch mode {
        case .verify:           return "请输入 4 位 PIN"
        case .set:
            return setStep == .create ? "输入新密码" : "重新输入新密码"
        case .verifyThenClear:  return "请输入当前密码"
        }
    }

    private var keypadSubtitle: String? {
        switch mode {
        case .verify:           return nil
        case .set:              return nil
        case .verifyThenClear:  return "验证通过后将关闭密码保护"
        }
    }

    /// 冷却中显示剩余秒数。
    @ViewBuilder
    private var cooldownSubtitle: some View {
        // 引用 tick 让 SwiftUI 跟踪依赖，每秒重绘
        let _ = tick
        if manager.isInCooldown(notebook: notebook) {
            let remaining = Int(ceil(max(0, manager.remainingCooldown(notebook: notebook))))
            Text("密码错误，请 \(remaining) 秒后再试")
                .font(.warmBody)
                .foregroundColor(theme.accentDestructive)
                .monospacedDigit()
        } else {
            EmptyView()
        }
    }

    // MARK: - 处理

    private func handleComplete(_ pin: String) {
        precondition(pin.count == 4, "PIN 必须是 4 位")
        switch mode {
        case .verify:
            handleVerify(pin)
        case .set:
            handleSet(pin)
        case .verifyThenClear:
            handleVerifyThenClear(pin)
        }
    }

    private func handleVerify(_ pin: String) {
        if manager.verify(pin: pin, on: notebook) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSuccess()
        } else {
            triggerError()
        }
    }

    private func handleSet(_ pin: String) {
        switch setStep {
        case .create:
            firstPin = pin
            setStep = .confirm
            errorToken += 1   // 重建 PinKeypadView 清空
        case .confirm:
            if pin == firstPin {
                do {
                    try manager.set(pin: pin, on: notebook)
                    try? CoreDataStack.shared.save()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onSuccess()
                } catch {
                    triggerError()
                }
            } else {
                firstPin = ""
                setStep = .create
                triggerError()
            }
        }
    }

    private func handleVerifyThenClear(_ pin: String) {
        if manager.verify(pin: pin, on: notebook) {
            manager.clear(on: notebook)
            try? CoreDataStack.shared.save()
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onSuccess()
        } else {
            triggerError()
        }
    }

    private func triggerError() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        errorToken += 1
    }

    private func goBackOrDismiss() {
        switch mode {
        case .verify:
            // verify 模式下禁止下滑关闭,这里仅响应 dismiss
            break
        case .set:
            if setStep == .confirm {
                firstPin = ""
                setStep = .create
            } else {
                dismiss()
            }
        case .verifyThenClear:
            dismiss()
        }
    }
}
