import AppKit
import AstraCore
import Foundation
import Observation

/// Looks for a newer release on GitHub. It only reports one: Homebrew installs update with
/// `brew upgrade`, others download the DMG from the release page.
@Observable
final class UpdateChecker {
    struct Release {
        let version: AppVersion
        let url: URL
    }

    /// App Store builds update through the App Store and mustn't check on their own.
    static let isSupported: Bool = {
        #if APP_STORE
        false
        #else
        true
        #endif
    }()

    static let repo = "retr0ripper/astra-dial"
    private static let interval: TimeInterval = 24 * 60 * 60

    private(set) var available: Release?
    private(set) var isChecking = false
    private(set) var lastError: String?
    private(set) var lastChecked: Date?

    /// This build's version, or nil when it never checks: unbundled (`swift run`) or App Store.
    let current = isSupported
        ? (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String).flatMap(AppVersion.init)
        : nil

    @ObservationIgnored private var timer: Timer?

    /// Checks now and then once a day while `enabled`.
    func setAutomatic(_ enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled, current != nil else { return }
        check()
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in self?.check() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func check() {
        guard let current, !isChecking else { return }
        isChecking = true
        Task { @MainActor in
            defer { isChecking = false; lastChecked = Date() }
            do {
                let release = try await Self.latestRelease()
                lastError = nil
                available = release.version > current ? release : nil
            } catch {
                lastError = "Couldn't check for updates: \(error.localizedDescription)"
            }
        }
    }

    func openReleasePage() {
        if let url = available?.url { NSWorkspace.shared.open(url) }
    }

    private struct LatestRelease: Decodable {
        let tag_name: String
        let html_url: URL
        let draft: Bool
        let prerelease: Bool
    }

    private static func latestRelease() async throws -> Release {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repo)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        let latest = try JSONDecoder().decode(LatestRelease.self, from: data)
        guard !latest.draft, !latest.prerelease, let version = AppVersion(latest.tag_name) else {
            throw URLError(.cannotParseResponse)
        }
        return Release(version: version, url: latest.html_url)
    }
}
