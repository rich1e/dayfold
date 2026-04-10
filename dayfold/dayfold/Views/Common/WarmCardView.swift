// Views/Common/WarmCardView.swift
import SwiftUI

struct WarmCardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .warmCard()
    }
}
