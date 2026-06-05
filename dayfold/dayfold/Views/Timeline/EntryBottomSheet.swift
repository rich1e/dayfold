// Views/Timeline/EntryBottomSheet.swift
import SwiftUI

private enum SheetHeight {
    static let collapsed: CGFloat = 80
    static let medium: CGFloat = 320
    static let expanded: CGFloat = UIScreen.main.bounds.height * 0.85
}

struct EntryBottomSheet: View {
    let selectedDate: Date?
    let entries: [Entry]
    @Binding var viewMode: TimelineViewMode
    @Binding var photoWallScrollTarget: UUID?
    var onCreateEntry: (Date) -> Void

    @State private var sheetHeight: CGFloat = SheetHeight.collapsed
    @GestureState private var dragOffset: CGFloat = 0

    private var currentHeight: CGFloat {
        min(SheetHeight.expanded, max(SheetHeight.collapsed, sheetHeight - dragOffset))
    }

    var body: some View {
        VStack(spacing: 0) {
            // 拖拽把手
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.warmGray)
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // 摘要条
            summaryBar

            // 条目列表（中档/全屏时显示）
            if sheetHeight > SheetHeight.collapsed + 20 {
                Divider().padding(.horizontal)
                entryList
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: currentHeight)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.warmLight)
                .shadow(color: Color.warmGray.opacity(0.4), radius: 12, x: 0, y: -4)
        )
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    state = value.translation.height
                }
                .onEnded { value in
                    snapSheet(translation: value.translation.height)
                }
        )
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: sheetHeight)
    }

    private var summaryBar: some View {
        HStack {
            if let date = selectedDate {
                Text(formatSelectedDate(date))
                    .font(.warmHeadline)
                    .foregroundColor(.warmDark)
                if !entries.isEmpty {
                    Text("·")
                        .foregroundColor(.warmBrown)
                    Text("\(entries.count)条记录")
                        .font(.warmBody)
                        .foregroundColor(.warmBrown)
                } else {
                    Text("这天还没有记录")
                        .font(.warmBody)
                        .foregroundColor(.warmBrown)
                }
            } else {
                Text("选择一天查看记录")
                    .font(.warmBody)
                    .foregroundColor(.warmBrown)
            }
            Spacer()
            if let date = selectedDate {
                Button {
                    onCreateEntry(date)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.warmAccent)
                }
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                sheetHeight = sheetHeight <= SheetHeight.collapsed + 20
                    ? SheetHeight.medium
                    : SheetHeight.collapsed
            }
        }
    }

    private var entryList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(entries, id: \.id) { entry in
                    NavigationLink(destination: EntryDetailView(entry: entry)) {
                        sheetEntryCard(entry: entry)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding()
        }
    }

    private func sheetEntryCard(entry: Entry) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                if !entry.wrappedTitle.isEmpty {
                    Text(entry.wrappedTitle)
                        .font(.warmHeadline)
                        .foregroundColor(.warmDark)
                        .lineLimit(1)
                }
                Text(entry.wrappedContent)
                    .font(.warmBody)
                    .foregroundColor(.warmBrown)
                    .lineLimit(2)
                if let createdAt = entry.createdAt {
                    Text(createdAt, format: .dateTime.hour().minute())
                        .font(.warmCaption)
                        .foregroundColor(.warmGray)
                }
            }
            Spacer()
            if !entry.mediaAssetsArray.isEmpty {
                Button {
                    photoWallScrollTarget = entry.id
                    viewMode = .photoWall
                } label: {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.warmAccent)
                }
            }
        }
        .padding(12)
        .background(Color.warmPaper)
        .cornerRadius(12)
    }

    private func snapSheet(translation: CGFloat) {
        let anchors: [CGFloat] = [SheetHeight.collapsed, SheetHeight.medium, SheetHeight.expanded]
        let target = sheetHeight - translation
        let nearest = anchors.min(by: { abs($0 - target) < abs($1 - target) }) ?? SheetHeight.collapsed
        sheetHeight = nearest
    }

    private func formatSelectedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }
}
