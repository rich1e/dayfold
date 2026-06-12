// Extensions/Transitions+Warm.swift
import SwiftUI

struct PaperDropModifier: ViewModifier {
    let progress: Double // 0 = 起始（倾斜+偏移），1 = 落定

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .rotation3DEffect(
                .degrees(-8 * (1 - progress)),
                axis: (x: 1, y: 0, z: 0),
                perspective: 0.5
            )
            .offset(y: 12 * (1 - progress))
    }
}

extension AnyTransition {
    static var paperDrop: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: PaperDropModifier(progress: 0),
                identity: PaperDropModifier(progress: 1)
            ),
            removal: .opacity
        )
    }
}
