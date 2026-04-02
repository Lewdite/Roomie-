import Foundation
import Vision
import UIKit

/// On-device OCR using Apple's Vision framework.
/// Extracts text from receipt images to help auto-populate expense fields.
final class OCRService {

    struct OCRResult {
        var rawText: String
        /// Best-guess total amount found in the text, if detectable
        var detectedAmount: Double?
        /// Best-guess vendor name (first line of text, typically)
        var detectedVendor: String?
    }

    func extractText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                let raw = lines.joined(separator: "\n")

                let result = OCRResult(
                    rawText: raw,
                    detectedAmount: Self.extractAmount(from: lines),
                    detectedVendor: lines.first
                )
                continuation.resume(returning: result)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Amount Extraction

    /// Scans lines for currency patterns like "$12.34", "12.34", "TOTAL 12.34"
    private static func extractAmount(from lines: [String]) -> Double? {
        // Look for a line containing "total" (case-insensitive) first
        let totalLine = lines.first {
            $0.lowercased().contains("total") || $0.lowercased().contains("amount")
        }
        let candidates = totalLine.map { [$0] } ?? lines

        let pattern = #"(?:[$£€]?\s*)(\d{1,6}[.,]\d{2})"#
        let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)

        var amounts: [Double] = []
        for line in candidates {
            let range = NSRange(line.startIndex..., in: line)
            if let match = regex?.firstMatch(in: line, range: range),
               let valueRange = Range(match.range(at: 1), in: line) {
                let valueString = line[valueRange].replacingOccurrences(of: ",", with: ".")
                if let value = Double(valueString) {
                    amounts.append(value)
                }
            }
        }
        return amounts.max() // Largest value in a "total" context is usually the total
    }
}

enum OCRError: LocalizedError {
    case invalidImage

    var errorDescription: String? { "Could not process the selected image." }
}
