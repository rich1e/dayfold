// Views/Map/MapView.swift
import SwiftUI
import CoreData

struct MapView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Binding var showingNewEntry: Bool

    @StateObject private var viewModel: MapViewModel
    @State private var selectedEntries: [Entry] = []
    @State private var detailEntry: EntryRef?

    struct EntryRef: Identifiable {
        let entry: Entry
        var id: NSManagedObjectID { entry.objectID }
    }

    init(showingNewEntry: Binding<Bool>,
         context: NSManagedObjectContext = CoreDataStack.shared.viewContext) {
        self._showingNewEntry = showingNewEntry
        self._viewModel = StateObject(wrappedValue: MapViewModel(context: context))
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.warmPaper.ignoresSafeArea()

            // 地图本体
            MapKitView(
                entries: viewModel.visibleEntries,
                onSelect: { entries in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedEntries = entries
                    }
                },
                onDeselect: {
                    withAnimation { selectedEntries = [] }
                }
            )
            .ignoresSafeArea(edges: .bottom)

            // 顶部条：扩展高度并包裹左侧 gearshape 抽屉按钮（按钮由 MainTabView 渲染在上层）
            VStack(spacing: 0) {
                Color.warmPaper
                    .frame(height: 96)
                    .ignoresSafeArea(edges: .top)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.warmCream)
                            .frame(height: 0.5)
                    }
                    .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 3)
                Spacer()
            }

            // 空态
            if viewModel.entries.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea(edges: .bottom)
            } else if viewModel.visibleEntries.isEmpty {
                VStack {
                    Spacer()
                    Text("无匹配结果")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                        .padding(.bottom, selectedEntries.isEmpty ? 100 : 280)
                }
            }

            // 底部：搜索框 + 添加按钮同一行；上浮卡片在其之下
            VStack(spacing: 12) {
                Spacer()

                HStack(spacing: 12) {
                    MapSearchBar(query: $viewModel.query)

                    Button {
                        showingNewEntry = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                Circle()
                                    .fill(Color(hex: "1C1C24"))
                                    .shadow(color: Color.black.opacity(0.35), radius: 10, x: 0, y: 4)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                if !selectedEntries.isEmpty {
                    MapEntryCard(
                        entries: selectedEntries,
                        onOpen: { entry in detailEntry = EntryRef(entry: entry) },
                        onDismiss: {
                            withAnimation { selectedEntries = [] }
                        }
                    )
                    .padding(.horizontal, 12)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.bottom, 24)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedEntries.isEmpty)
        }
        .fullScreenCover(item: $detailEntry) { ref in
            NavigationView {
                EntryDetailView(entry: ref.entry)
                    .environment(\.managedObjectContext, viewContext)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("关闭") { detailEntry = nil }
                                .foregroundColor(Color.warmAccent)
                        }
                    }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "mappin.slash")
                    .font(.system(size: 36))
                    .foregroundColor(Color.warmBrown)
                Text("还没有带位置的日记")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Color.warmDark)
                Text("点击 ＋ 添加第一条")
                    .font(.system(size: 13))
                    .foregroundColor(Color.warmBrown)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.warmLight.opacity(0.95))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
            )
            Spacer()
        }
    }
}
