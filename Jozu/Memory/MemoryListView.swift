import SwiftUI

struct MemoryListView: View {
    let items: [MemoryItem]
    var onDelete: (UUID) -> Void

    var body: some View {
        let due = items.filter(\.isDue)
        let later = items.filter { !$0.isDue }

        Group {
            if items.isEmpty {
                Text("Nothing saved yet. Ask something, then Remember — or type “remember this”.")
                    .font(.system(size: 14))
                    .foregroundStyle(JozuTheme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(20)
            } else {
                List {
                    if !due.isEmpty {
                        Section("Due") {
                            ForEach(due, content: row)
                        }
                    }
                    if !later.isEmpty {
                        Section("Later") {
                            ForEach(later, content: row)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .background(JozuTheme.paper)
        .preferredColorScheme(.light)
        .navigationTitle("Memories")
    }

    private func row(_ item: MemoryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.kind.label.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(JozuTheme.vermillion)
                Spacer()
                Button(role: .destructive) {
                    onDelete(item.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Remove")
            }
            Text(item.target)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(JozuTheme.ink)
                .textSelection(.enabled)
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.system(size: 13))
                    .foregroundStyle(JozuTheme.muted)
                    .textSelection(.enabled)
            }
        }
        .padding(.vertical, 4)
    }
}
