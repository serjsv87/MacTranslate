import Foundation
import AppKit

public struct GitHubReleaseInfo: Sendable {
    public let tagName: String
    public let htmlUrl: String
    public let name: String
    public let body: String
}

@MainActor
public final class UpdateChecker: Sendable {
    public static let shared = UpdateChecker()
    
    public static let currentVersion: String = {
        if let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String, !ver.isEmpty {
            return ver
        }
        return "1.0.3"
    }()
    
    private let repoOwner = "serjsv87"
    private let repoName = "MacTranslate"
    private let lastCheckKey = "com.mactranslate.lastUpdateCheckTimestamp"
    
    private init() {}
    
    /// Checks for a newer GitHub release. If `force` is false, runs at most once every 24 hours.
    public func checkForUpdates(force: Bool = false, showUpToDateAlert: Bool = false) {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        let lastCheck = defaults.double(forKey: lastCheckKey)
        let oneDay: TimeInterval = 24 * 60 * 60
        
        if !force && (now - lastCheck < oneDay) {
            return
        }
        
        guard let url = URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.setValue("MacTranslate-App/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 10.0
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    return
                }
                
                defaults.set(now, forKey: self.lastCheckKey)
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tagName = json["tag_name"] as? String,
                      let htmlUrl = json["html_url"] as? String else {
                    return
                }
                
                let releaseName = (json["name"] as? String) ?? tagName
                let body = (json["body"] as? String) ?? ""
                let releaseInfo = GitHubReleaseInfo(tagName: tagName, htmlUrl: htmlUrl, name: releaseName, body: body)
                
                await MainActor.run {
                    self.handleReleaseResult(releaseInfo, showUpToDateAlert: showUpToDateAlert)
                }
            } catch {
                if showUpToDateAlert {
                    await MainActor.run {
                        let alert = NSAlert()
                        alert.messageText = L10n("update.check_failed_title")
                        alert.informativeText = L10n("update.check_failed_desc")
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func handleReleaseResult(_ release: GitHubReleaseInfo, showUpToDateAlert: Bool) {
        let latestVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let current = Self.currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        
        if isVersion(latestVersion, newerThan: current) {
            promptUpdateAvailable(release: release)
        } else if showUpToDateAlert {
            let alert = NSAlert()
            alert.messageText = L10n("update.up_to_date_title")
            alert.informativeText = "\(L10n("update.up_to_date_desc")) (v\(current))"
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func promptUpdateAvailable(release: GitHubReleaseInfo) {
        let alert = NSAlert()
        alert.messageText = "\(L10n("update.new_version_title")) (\(release.tagName))"
        alert.informativeText = "\(L10n("update.new_version_desc"))\n\n\(release.name)"
        alert.addButton(withTitle: L10n("update.btn_download"))
        alert.addButton(withTitle: L10n("update.btn_later"))
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: release.htmlUrl) {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    public func isVersion(_ v1: String, newerThan v2: String) -> Bool {
        let parts1 = v1.split(separator: ".").compactMap { Int($0) }
        let parts2 = v2.split(separator: ".").compactMap { Int($0) }
        let maxCount = max(parts1.count, parts2.count)
        
        for i in 0..<maxCount {
            let p1 = i < parts1.count ? parts1[i] : 0
            let p2 = i < parts2.count ? parts2[i] : 0
            if p1 > p2 { return true }
            if p1 < p2 { return false }
        }
        return false
    }
}
