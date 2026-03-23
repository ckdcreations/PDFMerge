import PDFKit

enum PDFMerger {
    static func merge(urls: [URL]) throws -> PDFDocument {
        let outputDocument = PDFDocument()

        for url in urls {
            guard let document = PDFDocument(url: url) else {
                throw MergeError.unreadableFile(url.lastPathComponent)
            }

            for pageIndex in 0..<document.pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                outputDocument.insert(page, at: outputDocument.pageCount)
            }
        }

        guard outputDocument.pageCount > 0 else {
            throw MergeError.noPages
        }

        return outputDocument
    }

    enum MergeError: LocalizedError {
        case unreadableFile(String)
        case noPages

        var errorDescription: String? {
            switch self {
            case .unreadableFile(let name):
                "Could not read PDF: \(name)"
            case .noPages:
                "The merged document contains no pages."
            }
        }
    }
}
