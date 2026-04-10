// Extensions/View+Extensions.swift
import SwiftUI

extension View {
    func warmCard() -> some View {
        self.modifier(WarmCardModifier())
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct WarmCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(Color.warmLight)
            .cornerRadius(16)
            .shadow(color: Color.warmGray.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}
