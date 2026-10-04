import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

struct PendingPhoto: Equatable {
    var thumbnailJPEG: Data
    var ocrText: String
    var isRecognizing: Bool
}

enum ImageData {
    static func cgImage(from data: Data, maxPixelSize: CGFloat) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func jpeg(from image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, [
            kCGImageDestinationLossyCompressionQuality: quality,
        ] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static func jpegThumbnail(from data: Data, maxPixelSize: CGFloat) -> Data? {
        guard let image = cgImage(from: data, maxPixelSize: maxPixelSize) else { return nil }
        return jpeg(from: image, quality: 0.72)
    }
}

enum VisionLanguage {
    static func codes(from names: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for name in names {
            for code in codes(for: name) where seen.insert(code).inserted {
                result.append(code)
            }
        }
        return result
    }

    static func codes(for name: String) -> [String] {
        let key = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "japanese", "日本語", "jp", "ja":
            return ["ja-JP"]
        case "english", "en":
            return ["en-US"]
        case "chinese", "mandarin", "simplified chinese", "中文", "zh":
            return ["zh-Hans"]
        case "traditional chinese", "cantonese":
            return ["zh-Hant"]
        case "korean", "한국어", "ko":
            return ["ko-KR"]
        case "french", "français", "fr":
            return ["fr-FR"]
        case "spanish", "español", "es":
            return ["es-ES"]
        case "german", "deutsch", "de":
            return ["de-DE"]
        case "italian", "italiano", "it":
            return ["it-IT"]
        case "portuguese", "português", "pt":
            return ["pt-BR"]
        case "russian", "ru":
            return ["ru-RU"]
        case "arabic", "ar":
            return ["ar-SA"]
        default:
            if key.contains("-") { return [name.trimmingCharacters(in: .whitespacesAndNewlines)] }
            return []
        }
    }
}

enum VisionTextRecognizer {
    static func recognize(image: CGImage, languages: [String]) async throws -> String {
        do {
            return try await run(image: image, languages: languages)
        } catch {
            if languages.isEmpty { throw error }
            return try await run(image: image, languages: [])
        }
    }

    private static func run(image: CGImage, languages: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let lines = (request.results as? [VNRecognizedTextObservation] ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            if !languages.isEmpty {
                request.recognitionLanguages = languages
            }

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
