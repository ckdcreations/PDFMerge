import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    private struct PDFItem: Identifiable, Equatable {
        let id = UUID()
        let url: URL
    }

    @State private var pdfItems: [PDFItem] = []
    @State private var selectedItemID: PDFItem.ID?
    @State private var isTargeted = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isMerging = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Button {
                    addFilesFromPanel()
                } label: {
                    Label("Add Files", systemImage: "plus")
                }

                Menu {
                    Button("Name (A → Z)") { sortByName(ascending: true) }
                    Button("Name (Z → A)") { sortByName(ascending: false) }
                    Divider()
                    Button("Date Modified (Newest First)") { sortByDate(ascending: false) }
                    Button("Date Modified (Oldest First)") { sortByDate(ascending: true) }
                    Divider()
                    Button("Page Count (Fewest First)") { sortByPageCount(ascending: true) }
                    Button("Page Count (Most First)") { sortByPageCount(ascending: false) }
                    Divider()
                    Button("File Size (Smallest First)") { sortByFileSize(ascending: true) }
                    Button("File Size (Largest First)") { sortByFileSize(ascending: false) }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .disabled(pdfItems.count < 2)

                Spacer()

                Button("Clear All", role: .destructive) {
                    pdfItems.removeAll()
                    selectedItemID = nil
                }
                .disabled(pdfItems.isEmpty)

                Button {
                    mergeAndSave()
                } label: {
                    Label("Merge & Save", systemImage: "doc.on.doc")
                }
                .disabled(pdfItems.count < 2 || isMerging)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding()

            Divider()

            // Drop zone / file list
            Group {
                if pdfItems.isEmpty {
                    dropPlaceholder
                } else {
                    fileList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isTargeted ? Color.accentColor.opacity(0.1) : Color.clear)
            .dropDestination(for: URL.self) { items, _ in
                addURLs(items)
                return true
            } isTargeted: { targeted in
                isTargeted = targeted
            }
        }
        .frame(minWidth: 450, minHeight: 350)
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    // MARK: - Subviews

    private var dropPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Drag & drop PDF files here")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("or click Add Files")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private var fileList: some View {
        List {
            ForEach(Array(pdfItems.enumerated()), id: \.element.id) { index, item in
                let isSelected = item.id == selectedItemID

                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text(item.url.lastPathComponent)
                            .lineLimit(1)
                        Text(item.url.deletingLastPathComponent().path(percentEncoded: false))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(pageCount(for: item.url)) pages")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    if isSelected {
                        HStack(spacing: 10) {
                            Button {
                                moveItemUp(id: item.id)
                            } label: {
                                Image(systemName: "arrow.up.circle")
                            }
                            .buttonStyle(.plain)
                            .disabled(index == 0)
                            .help("Move up")

                            Button {
                                moveItemDown(id: item.id)
                            } label: {
                                Image(systemName: "arrow.down.circle")
                            }
                            .buttonStyle(.plain)
                            .disabled(index == pdfItems.count - 1)
                            .help("Move down")

                            Button {
                                removeItems(at: IndexSet(integer: index))
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .help("Remove this file")
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
                }
                .onTapGesture {
                    selectedItemID = item.id
                }
            }
            .onMove { from, to in
                pdfItems.move(fromOffsets: from, toOffset: to)
            }
            .onDelete { offsets in
                removeItems(at: offsets)
            }
        }
    }

    // MARK: - Actions

    private func addFilesFromPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf]
        panel.message = "Select PDF files to merge"

        guard panel.runModal() == .OK else { return }
        addURLs(panel.urls)
    }

    private func addURLs(_ urls: [URL]) {
        let pdfType = UTType.pdf
        let newPDFs = urls.filter { url in
            guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
                return url.pathExtension.lowercased() == "pdf"
            }
            return type.conforms(to: pdfType)
        }
        let newItems = newPDFs.map { PDFItem(url: $0) }

        pdfItems.append(contentsOf: newItems)

        if selectedItemID == nil {
            selectedItemID = newItems.first?.id
        }
    }

    private func mergeAndSave() {
        isMerging = true
        defer { isMerging = false }

        do {
            let merged = try PDFMerger.merge(urls: pdfItems.map(\.url))

            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.pdf]
            savePanel.nameFieldStringValue = "Merged.pdf"

            guard savePanel.runModal() == .OK, let dest = savePanel.url else { return }
            guard merged.write(to: dest) else {
                errorMessage = "Failed to write merged PDF to disk."
                showError = true
                return
            }

            NSWorkspace.shared.open(dest)
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    // MARK: - Sorting

    private func sortByName(ascending: Bool) {
        pdfItems.sort { a, b in
            let result = a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent) == .orderedAscending
            return ascending ? result : !result
        }
    }

    private func sortByDate(ascending: Bool) {
        pdfItems.sort { a, b in
            let dateA = (try? a.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let dateB = (try? b.url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return ascending ? dateA < dateB : dateA > dateB
        }
    }

    private func sortByPageCount(ascending: Bool) {
        pdfItems.sort { a, b in
            let pagesA = pageCount(for: a.url)
            let pagesB = pageCount(for: b.url)
            return ascending ? pagesA < pagesB : pagesA > pagesB
        }
    }

    private func sortByFileSize(ascending: Bool) {
        pdfItems.sort { a, b in
            let sizeA = (try? a.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let sizeB = (try? b.url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return ascending ? sizeA < sizeB : sizeA > sizeB
        }
    }

    private func removeItems(at offsets: IndexSet) {
        let nextSelectionIndex = offsets.min().flatMap { min($0, pdfItems.count - offsets.count - 1) }

        pdfItems.remove(atOffsets: offsets)

        guard let selectedItemID else {
            return
        }

        if pdfItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        if let nextSelectionIndex, pdfItems.indices.contains(nextSelectionIndex) {
            self.selectedItemID = pdfItems[nextSelectionIndex].id
        } else {
            self.selectedItemID = nil
        }
    }

    private func moveItemUp(id: PDFItem.ID) {
        guard let index = pdfItems.firstIndex(where: { $0.id == id }), index > 0 else {
            return
        }

        pdfItems.swapAt(index, index - 1)
    }

    private func moveItemDown(id: PDFItem.ID) {
        guard let index = pdfItems.firstIndex(where: { $0.id == id }), index < pdfItems.count - 1 else {
            return
        }

        pdfItems.swapAt(index, index + 1)
    }

    private func pageCount(for url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }
}
