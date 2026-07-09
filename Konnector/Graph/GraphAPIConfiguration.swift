import Foundation

enum GraphAPIConfiguration {
    private static let defaultBaseURL = URL(string: "http://127.0.0.1:3000")!

    static var baseURL: URL {
        if let value = Bundle.main.object(forInfoDictionaryKey: "GraphAPIBaseURL") as? String,
           let url = URL(string: value) {
            return url
        }
        return defaultBaseURL
    }

    static var isEnabled: Bool {
        if Bundle.main.object(forInfoDictionaryKey: "GraphAPIBaseURL") is String {
            return true
        }
        #if targetEnvironment(simulator)
        return true
        #else
        return Bundle.main.object(forInfoDictionaryKey: "GraphAPIBaseURL") != nil
        #endif
    }
}
