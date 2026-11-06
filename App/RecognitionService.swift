import Foundation
import Vision
import CoreGraphics

struct RecognitionService {
    func analyze(image: CGImage, isScreenshot: Bool, learned: [String: [String: Int]]) throws -> Classification {
        let classification = VNClassifyImageRequest()
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = true
        text.automaticallyDetectsLanguage = true
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([classification, text])
        let labels: [(String, Double)] = (classification.results ?? []).prefix(8).map { ($0.identifier, Double($0.confidence)) }
        let recognized = (text.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
        return RuleEngine.suggest(labels: labels, ocr: recognized, isScreenshot: isScreenshot, learned: learned)
    }
}
