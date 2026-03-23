import SwiftUI
import PDFKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var pdfURLs: [URL] = []
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
                .disabled(pdfURLs.count < 2)

                Spacer()

                Button("Clear All", role: .destructive) {
                    pdfURLs.removeAll()
                }
                .disabled(pdfURLs.isEmpty)

                Button {
                    mergeAndSave()
                } label: {
                    Label("Merge & Save", systemImage: "doc.on.doc")
                }
                .disabled(pdfURLs.count < 2 || isMerging)
                .keyboardShortcut("s", modifiers: .command)
            }
            .padding()

            Divider()

            // Drop zone / file list
            Group {
                if pdfURLs.isEmpty {
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
            ForEach(Array(pdfURLs.enumerated()), id: \.offset) { index, url in
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundStyle(.red)
                    VStack(alignment: .leading) {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                        Text(url.deletingLastPathComponent().path(percentEncoded: false))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("\(pageCount(for: url)) pages")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }
                .padding(.vertical, 2)
            }
            .onMove { from, to in
                pdfURLs.move(fromOffsets: from, toOffset: to)
            }
            .onDelete { offsets in
                pdfURLs.remove(atOffsets: offsets)
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
        pdfURLs.append(contentsOf: newPDFs)
    }

    private func mergeAndSave() {
        isMerging = true
        defer { isMerging = false }

        do {
            let merged = try PDFMerger.merge(urls: pdfURLs)

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
        pdfURLs.sort { a, b in
            let result = a.lastPathComponent.localizedStandardCompare(b.lastPathComponent) == .orderedAscending
            return ascending ? result : !result
        }
    }

    private func sortByDate(ascending: Bool) {
        pdfURLs.sort { a, b in
            let dateA = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let dateB = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return ascending ? dateA < dateB : dateA > dateB
        }
    }

    private func sortByPageCount(ascending: Bool) {
        pdfURLs.sort { a, b in
            let pagesA = pageCount(for: a)
            let pagesB = pageCount(for: b)
            return ascending ? pagesA < pagesB : pagesA > pagesB
        }
    }

    private func sortByFileSize(ascending: Bool) {
        pdfURLs.sort { a, b in
            let sizeA = (try? a.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            let sizeB = (try? b.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return ascending ? sizeA < sizeB : sizeA > sizeB
        }
    }

    private func pageCount(for url: URL) -> Int {
        PDFDocument(url: url)?.pageCount ?? 0
    }
}
