import Foundation
import AppKit

/// Zero-dependency update checker and in-app installer using GitHub's public Releases API.
@MainActor
public final class UpdateChecker: ObservableObject {
    public static let shared = UpdateChecker()

    @Published public private(set) var isChecking: Bool = false
    @Published public private(set) var isUpdating: Bool = false
    @Published public private(set) var availableUpdateVersion: String? = nil

    private let repoOwner = "anshulg8"
    private let repoName = "hoist"
    private let appName = "Hoist"
    private var progressWindow: NSWindow?

    private init() {}

    /// Current version from Info.plist (defaults to "0.1.0").
    public var currentVersion: String {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !ver.isEmpty {
            return ver
        }
        return "0.1.0"
    }

    /// Checks for updates against GitHub Releases.
    /// - Parameter explicit: If `true`, shows "Up to date" or error dialogs. If `false`, only alerts when an update is found.
    public func checkForUpdates(explicit: Bool = true) {
        guard !isChecking && !isUpdating else { return }
        isChecking = true

        Task {
            defer { self.isChecking = false }
            do {
                guard let release = try await fetchLatestRelease() else {
                    self.availableUpdateVersion = nil
                    if explicit {
                        showUpToDateAlert(version: cleanVersion(self.currentVersion))
                    }
                    return
                }
                let remoteVersion = cleanVersion(release.tagName)
                let localVersion = cleanVersion(self.currentVersion)

                if isVersion(remoteVersion, newerThan: localVersion) {
                    self.availableUpdateVersion = remoteVersion
                    showUpdateAvailableAlert(
                        newVersion: remoteVersion,
                        releaseName: release.name ?? "\(appName) \(remoteVersion)",
                        releaseUrl: release.htmlUrl,
                        downloadUrl: release.zipAssetUrl
                    )
                } else {
                    self.availableUpdateVersion = nil
                    if explicit {
                        showUpToDateAlert(version: localVersion)
                    }
                }
            } catch {
                if explicit {
                    showErrorAlert(error: error)
                }
            }
        }
    }

    // MARK: - API Fetch

    private struct GitHubRelease: Decodable {
        let tagName: String
        let htmlUrl: String
        let name: String?
        let body: String?
        let assets: [GitHubAsset]?

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlUrl = "html_url"
            case name
            case body
            case assets
        }

        var zipAssetUrl: String? {
            assets?.first(where: { $0.name.lowercased().hasSuffix(".zip") })?.browserDownloadUrl
        }
    }

    private struct GitHubAsset: Decodable {
        let name: String
        let browserDownloadUrl: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadUrl = "browser_download_url"
        }
    }

    private func fetchLatestRelease() async throws -> GitHubRelease? {
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        // GitHub API requires a User-Agent header; requests without it receive HTTP 403 Forbidden
        request.setValue("\(appName)-App/\(currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        // 404 indicates no releases have been published on GitHub yet
        if httpResponse.statusCode == 404 {
            return nil
        }

        guard httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "UpdateChecker",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "Server returned status code \(httpResponse.statusCode)."]
            )
        }

        let decoder = JSONDecoder()
        return try decoder.decode(GitHubRelease.self, from: data)
    }

    // MARK: - In-App Update & Seamless Installation

    public func installUpdate(from downloadUrlString: String, newVersion: String, releaseUrl: String) {
        guard let downloadUrl = URL(string: downloadUrlString) else {
            if let fallback = URL(string: releaseUrl) {
                NSWorkspace.shared.open(fallback)
            }
            return
        }

        isUpdating = true
        showProgressWindow(version: newVersion)

        Task {
            do {
                try await performInAppUpdate(from: downloadUrl)
            } catch {
                hideProgressWindow()
                self.isUpdating = false
                showUpdateFailedAlert(error: error, releaseUrl: releaseUrl)
            }
        }
    }

    private func performInAppUpdate(from url: URL) async throws {
        // 1. Download zip file natively via URLSession (does NOT attach com.apple.quarantine)
        let (tempZipURL, response) = try await URLSession.shared.download(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("hoist_update_\(UUID().uuidString)")
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fileManager.removeItem(at: tempDir)
            try? fileManager.removeItem(at: tempZipURL)
        }

        let zipDestination = tempDir.appendingPathComponent("\(appName).zip")
        try fileManager.moveItem(at: tempZipURL, to: zipDestination)

        // 2. Extract using native ditto (preserves permissions, links, and resource forks)
        let extractedDir = tempDir.appendingPathComponent("extracted")
        try fileManager.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        let dittoResult = runShell("/usr/bin/ditto", ["-x", "-k", zipDestination.path, extractedDir.path])
        guard dittoResult == 0 else {
            throw NSError(
                domain: "UpdateChecker",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to extract update package."]
            )
        }

        let appBundleName = "\(appName).app"
        let extractedAppURL = extractedDir.appendingPathComponent(appBundleName)
        guard fileManager.fileExists(atPath: extractedAppURL.path) else {
            throw NSError(
                domain: "UpdateChecker",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Extracted update is missing \(appBundleName)."]
            )
        }

        // 3. Remove quarantine attribute completely
        _ = runShell("/usr/bin/xattr", ["-cr", extractedAppURL.path])

        // 4. Re-sign ad-hoc on this machine
        _ = runShell("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", extractedAppURL.path])

        // 5. Target install path: prefer current bundle location, or /Applications/Hoist.app
        let currentBundlePath = Bundle.main.bundleURL.path
        let targetAppPath: String
        if currentBundlePath.hasPrefix("/Applications/") {
            targetAppPath = currentBundlePath
        } else if fileManager.fileExists(atPath: "/Applications/\(appBundleName)") {
            targetAppPath = "/Applications/\(appBundleName)"
        } else {
            targetAppPath = currentBundlePath
        }

        // 6. Replace target bundle
        if fileManager.fileExists(atPath: targetAppPath) {
            do {
                try fileManager.removeItem(atPath: targetAppPath)
            } catch {
                _ = runAdminScript("/bin/rm -rf \(quoted(targetAppPath))")
            }
        }

        var copySuccess = false
        do {
            try fileManager.copyItem(atPath: extractedAppURL.path, toPath: targetAppPath)
            copySuccess = true
        } catch {
            let copyScript = "/usr/bin/ditto \(quoted(extractedAppURL.path)) \(quoted(targetAppPath))"
            if runAdminScript(copyScript) {
                copySuccess = true
            }
        }

        guard copySuccess else {
            throw NSError(
                domain: "UpdateChecker",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Could not replace \(targetAppPath)."]
            )
        }

        // 7. Final quarantine clear and ad-hoc sign on destination
        _ = runShell("/usr/bin/xattr", ["-cr", targetAppPath])
        _ = runShell("/usr/bin/codesign", ["--force", "--deep", "--sign", "-", targetAppPath])

        // 8. Spawn relaunch script and exit immediately
        relaunchApp(at: targetAppPath)
    }

    private func relaunchApp(at path: String) {
        let script = "sleep 0.4; open -n \(quoted(path))"
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", script]
        try? process.run()
        exit(0)
    }

    // MARK: - Progress & Alert Windows

    private func showProgressWindow(version: String) {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 110),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        win.center()
        win.title = "Updating \(appName)"
        win.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 110))

        let spinner = NSProgressIndicator(frame: NSRect(x: 24, y: 40, width: 30, height: 30))
        spinner.style = .spinning
        spinner.startAnimation(nil)
        contentView.addSubview(spinner)

        let titleLabel = NSTextField(labelWithString: "Updating to \(appName) \(version)…")
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        titleLabel.frame = NSRect(x: 68, y: 50, width: 195, height: 20)
        contentView.addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: "Downloading and installing…")
        subtitleLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 68, y: 32, width: 195, height: 18)
        contentView.addSubview(subtitleLabel)

        win.contentView = contentView
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.progressWindow = win
    }

    private func hideProgressWindow() {
        progressWindow?.close()
        progressWindow = nil
    }

    // MARK: - Version Comparison

    private func cleanVersion(_ raw: String) -> String {
        raw.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\r\n"))
    }

    public func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let p1 = v1.split(separator: ".").compactMap { Int($0) }
        let p2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(p1.count, p2.count)

        for i in 0..<maxCount {
            let n1 = i < p1.count ? p1[i] : 0
            let n2 = i < p2.count ? p2[i] : 0
            if n1 > n2 { return true }
            if n1 < n2 { return false }
        }
        return false
    }

    // MARK: - User Dialogs

    private func showUpdateAvailableAlert(
        newVersion: String,
        releaseName: String,
        releaseUrl: String,
        downloadUrl: String?
    ) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Update Available"
        alert.informativeText = "\(appName) \(newVersion) is now available (you have \(currentVersion)).\n\nWould you like to install the update now? \(appName) will automatically download, update, and relaunch seamlessly."
        alert.alertStyle = .informational

        if downloadUrl != nil {
            alert.addButton(withTitle: "Install & Relaunch")
        } else {
            alert.addButton(withTitle: "Download from GitHub")
        }
        alert.addButton(withTitle: "View Release Notes")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            if let downloadUrl = downloadUrl {
                installUpdate(from: downloadUrl, newVersion: newVersion, releaseUrl: releaseUrl)
            } else if let notesUrl = URL(string: releaseUrl) {
                NSWorkspace.shared.open(notesUrl)
            }
        case .alertSecondButtonReturn:
            if let notesUrl = URL(string: releaseUrl) {
                NSWorkspace.shared.open(notesUrl)
            }
        default:
            break
        }
    }

    private func showUpToDateAlert(version: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "You're Up to Date!"
        alert.informativeText = "\(appName) \(version) is currently the newest version available."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showErrorAlert(error: Error) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Check for Updates"
        alert.informativeText = "Unable to check for updates right now.\n\nPlease check your internet connection or visit the GitHub releases page directly."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Visit GitHub Releases")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let releasesUrl = URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases") {
                NSWorkspace.shared.open(releasesUrl)
            }
        }
    }

    private func showUpdateFailedAlert(error: Error, releaseUrl: String) {
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "Update Failed"
        alert.informativeText = "Unable to automatically install the update: \(error.localizedDescription)\n\nYou can download the update manually from GitHub."
        alert.alertStyle = .warning

        alert.addButton(withTitle: "Download Manually")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: releaseUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Shell Helpers

    private func quoted(_ string: String) -> String {
        return "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func runAdminScript(_ bashCommand: String) -> Bool {
        let script = "do shell script \"\(bashCommand.replacingOccurrences(of: "\"", with: "\\\""))\" with administrator privileges"
        var error: NSDictionary?
        guard let asObj = NSAppleScript(source: script) else { return false }
        _ = asObj.executeAndReturnError(&error)
        return error == nil
    }

    @discardableResult
    private func runShell(_ launchPath: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.launchPath = launchPath
        task.arguments = args
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus
        } catch {
            return -1
        }
    }
}

