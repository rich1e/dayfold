// Views/Common/ExportShareSheet.swift
import SwiftUI
import UIKit

/// UIViewControllerRepresentable 包裹 UIActivityViewController
/// 用于分享任意 items(URL / String / UIImage 等)
struct ExportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
