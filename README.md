# PDFMerge

A lightweight macOS app for merging multiple PDF files into one. Built with SwiftUI and PDFKit.

## Features

- **Drag & Drop** — Drop PDF files directly onto the window to add them
- **File Picker** — Or use the Add Files button to browse with an open panel
- **Sort** — Reorder PDFs before merging:
  - Alphabetically by name (A→Z / Z→A)
  - By date modified (newest/oldest first)
  - By page count (fewest/most first)
  - By file size (smallest/largest first)
- **Manual Reorder** — Drag rows in the list to set a custom merge order
- **Delete** — Remove individual files from the list or clear all at once
- **Merge & Save** — Combine all listed PDFs into a single document (⌘S)
- **Auto-Open** — The merged PDF opens automatically after saving

## Requirements

- macOS 14.0+
- Swift 6.2+

## Building

```bash
cd PDFMerge
swift build
```

To run directly:

```bash
swift run PDFMerge
```

## Project Structure

```
Package.swift              – Swift package manifest
Sources/PDFMerge/
  PDFMerge.swift           – App entry point & window configuration
  ContentView.swift        – Main UI: toolbar, file list, drag & drop, sorting
  PDFMerger.swift          – PDF merging logic using PDFKit
```

## License

MIT
