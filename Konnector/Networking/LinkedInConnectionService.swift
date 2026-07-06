import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum LinkedInConnectionError: LocalizedError, Equatable {
    case invalidProfileURL
    case appUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidProfileURL:
            "That LinkedIn profile link isn’t valid."
        case .appUnavailable:
            "LinkedIn isn’t installed on this device."
        }
    }
}

enum LinkedInConnectionService {
    static let appStoreURL = URL(string: "https://apps.apple.com/app/linkedin/id288429040")!

    /// Best-effort deep links that open LinkedIn’s in-app QR scanner. LinkedIn does not
    /// document these publicly, so several candidates are tried before falling back to the app.
    private static let qrScannerCandidateURLs: [URL] = [
        URL(string: "linkedin://qrcode?mode=scan")!,
        URL(string: "linkedin://qrcode/scan")!,
        URL(string: "linkedin://scan")!,
        URL(string: "linkedin://qrcode")!,
        URL(string: "linkedin://")!
    ]

    static func normalizedProfileURL(from rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let candidate: String
        if trimmed.lowercased().hasPrefix("http") {
            candidate = trimmed
        } else if trimmed.lowercased().hasPrefix("linkedin.com") {
            candidate = "https://\(trimmed)"
        } else if trimmed.lowercased().hasPrefix("www.linkedin.com") {
            candidate = "https://\(trimmed)"
        } else {
            candidate = "https://www.linkedin.com/in/\(trimmed)"
        }

        guard let url = URL(string: candidate),
              let host = url.host?.lowercased(),
              host.contains("linkedin.com"),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }

        var normalized = url.absoluteString
        if normalized.hasSuffix("/") {
            normalized.removeLast()
        }
        return normalized
    }

    static func profileSlug(from profileURL: String) -> String? {
        guard let url = URL(string: profileURL),
              let host = url.host?.lowercased(),
              host.contains("linkedin.com")
        else {
            return nil
        }

        let pathComponents = url.pathComponents.filter { $0 != "/" }
        guard let markerIndex = pathComponents.firstIndex(where: { $0 == "in" || $0 == "pub" }),
              pathComponents.indices.contains(markerIndex + 1)
        else {
            return nil
        }

        return pathComponents[markerIndex + 1]
    }

    static func isLinkedInAppInstalled() -> Bool {
        #if canImport(UIKit)
        guard let url = URL(string: "linkedin://") else { return false }
        return UIApplication.shared.canOpenURL(url)
        #else
        false
        #endif
    }

    @discardableResult
    static func openQRScanner() -> Bool {
        #if canImport(UIKit)
        for url in qrScannerCandidateURLs where UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return true
        }
        #endif
        return false
    }

    static func openQRScannerOrAppStore() throws {
        if openQRScanner() {
            return
        }

        #if canImport(UIKit)
        UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
        #else
        throw LinkedInConnectionError.appUnavailable
        #endif
    }

    static func openProfile(_ profileURL: String) throws {
        guard let normalized = normalizedProfileURL(from: profileURL),
              let webURL = URL(string: normalized)
        else {
            throw LinkedInConnectionError.invalidProfileURL
        }

        #if canImport(UIKit)
        if let slug = profileSlug(from: normalized),
           let appURL = URL(string: "linkedin://profile/\(slug)"),
           UIApplication.shared.canOpenURL(appURL) {
            UIApplication.shared.open(appURL, options: [:], completionHandler: nil)
            return
        }

        UIApplication.shared.open(webURL, options: [:], completionHandler: nil)
        #else
        throw LinkedInConnectionError.appUnavailable
        #endif
    }
}
