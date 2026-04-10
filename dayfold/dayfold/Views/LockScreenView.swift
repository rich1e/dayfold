// Views/LockScreenView.swift
import SwiftUI

struct LockScreenView: View {
    @EnvironmentObject var securityManager: SecurityManager
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                colors: [Color.warmCream, Color.warmPaper],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // 应用图标和名称
                VStack(spacing: 16) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.warmAccent)

                    Text("Dayfold")
                        .font(.warmTitle)
                        .foregroundColor(.warmDark)
                }

                Spacer()

                // 解锁按钮
                Button {
                    authenticateUser()
                } label: {
                    HStack(spacing: 12) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "faceid")
                                .font(.title2)
                            Text("解锁")
                                .font(.warmBody)
                                .fontWeight(.medium)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.warmAccent)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)
                .padding(.horizontal, 48)
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            if securityManager.isEnabled {
                authenticateUser()
            }
        }
    }

    private func authenticateUser() {
        isAuthenticating = true

        Task {
            let success = await securityManager.authenticate()
            await MainActor.run {
                isAuthenticating = false
                if !success {
                    print("Authentication failed")
                }
            }
        }
    }
}

#Preview {
    LockScreenView()
        .environmentObject(SecurityManager())
}
