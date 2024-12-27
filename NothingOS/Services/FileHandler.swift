import Foundation
import PDFKit
import UniformTypeIdentifiers
import ZIPFoundation
import Cocoa

class FileHandler {
    private let openAIAPIKey: String
    
    init(apiKey: String) {
        self.openAIAPIKey = "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"
    }
    
    func searchFiles(withNameContaining query: String, in directory: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let directoryContents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: .skipsHiddenFiles
        )
        return directoryContents.filter {
            $0.lastPathComponent.lowercased().contains(query.lowercased())
        }
    }

    func readFileContents(at url: URL) throws -> String? {
        if url.pathExtension.lowercased() == "pdf" {
            return extractTextFromPDF(at: url)
        } else {
            return "DOCX" // TODO: Implement DOCX reading
        }
    }

    private func extractTextFromPDF(at url: URL) -> String? {
        guard let pdfDocument = PDFDocument(url: url) else { return nil }
        let documentContent = NSMutableAttributedString()
        
        for i in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: i),
                  let pageContent = page.attributedString else { continue }
            documentContent.append(pageContent)
        }
        return documentContent.string
    }
}
