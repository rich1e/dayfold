// Views/SettingsView.swift
import SwiftUI
import CoreData

struct SettingsView: View {
    @EnvironmentObject private var securityManager: SecurityManager
    @EnvironmentObject private var coreDataStack: CoreDataStack
    @Environment(\.managedObjectContext) private var viewContext

    @State private var defaultNotebookID: UUID? = SettingsStore.loadDefaultNotebookID()
    @State private var showNotebookPicker = false

    private var defaultNotebookName: String {
        guard let defaultNotebookID else { return "未选择" }

        let request: NSFetchRequest<Notebook> = Notebook.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", defaultNotebookID as CVarArg)
        request.fetchLimit = 1
        return (try? viewContext.fetch(request).first)?.wrappedName ?? "未选择"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                securityCard
                defaultNotebookCard
                icloudCard
                aboutCard
            }
            .padding()
        }
        .background(Color.warmPaper.ignoresSafeArea())
        .sheet(isPresented: $showNotebookPicker) {
            NotebookPickerSheet(title: "选择默认笔记本") { notebook in
                SettingsStore.saveDefaultNotebookID(notebook.id)
                defaultNotebookID = notebook.id
            }
        }
    }

    private var securityCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "faceid")
                .foregroundColor(Color.warmAccent)
            Text("Face ID 锁定")
                .font(.warmBody)
                .foregroundColor(Color.warmDark)
            Spacer()
            Toggle(
                "",
                isOn: Binding(
                    get: { securityManager.isEnabled },
                    set: { securityManager.setEnabled($0) }
                )
            )
            .labelsHidden()
            .tint(Color.warmAccent)
        }
        .padding()
        .warmCard()
    }

    private var defaultNotebookCard: some View {
        Button {
            showNotebookPicker = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "book.closed")
                    .foregroundColor(Color.warmAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text("默认笔记本")
                        .font(.warmBody)
                        .foregroundColor(Color.warmDark)
                    Text(defaultNotebookName)
                        .font(.warmCaption)
                        .foregroundColor(Color.warmGray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(Color.warmGray)
            }
            .padding()
            .warmCard()
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var icloudCard: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(coreDataStack.isCloudKitAvailable ? Color.warmAccent : Color.warmGray)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 4) {
                Text("iCloud 同步")
                    .font(.warmBody)
                    .foregroundColor(Color.warmDark)
                Text(coreDataStack.isCloudKitAvailable ? "已连接" : "不可用，数据将保存在本地")
                    .font(.warmCaption)
                    .foregroundColor(Color.warmGray)
            }
            Spacer()
        }
        .padding()
        .warmCard()
    }

    private var aboutCard: some View {
        VStack(spacing: 8) {
            Text(appName)
                .font(.warmHeadline)
                .foregroundColor(Color.warmDark)
            Text("v\(shortVersionString) (\(versionNumber))")
                .font(.warmCaption)
                .foregroundColor(Color.warmGray)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .warmCard()
    }

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "Dayfold"
    }

    private var shortVersionString: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var versionNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

private enum SettingsStore {
    static let defaultNotebookIDKey = "settings.defaultNotebookID"

    static func loadDefaultNotebookID() -> UUID? {
        guard let string = UserDefaults.standard.string(forKey: defaultNotebookIDKey) else {
            return nil
        }
        return UUID(uuidString: string)
    }

    static func saveDefaultNotebookID(_ id: UUID?) {
        if let id {
            UserDefaults.standard.set(id.uuidString, forKey: defaultNotebookIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultNotebookIDKey)
        }
    }
}
