import SwiftUI

struct SearchablePickerSheet: View {
    let title: String
    let items: [String]
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [String] {
        if searchText.isEmpty { return items }
        return items.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered, id: \.self) { item in
                    Button {
                        selection = item
                        dismiss()
                    } label: {
                        HStack {
                            Text(item)
                                .foregroundStyle(.primary)
                            Spacer()
                            if item == selection {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
