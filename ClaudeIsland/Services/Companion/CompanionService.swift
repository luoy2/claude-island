//
//  CompanionService.swift
//  ClaudeIsland
//
//  Reads the user's Claude Code companion (pet) from session JSONL files
//

import Foundation
import os.log

private let logger = Logger(subsystem: "com.claudeisland", category: "Companion")

struct Companion: Equatable, Sendable {
    let name: String
    let species: String
}

actor CompanionService {
    static let shared = CompanionService()

    private var cached: Companion?

    private init() {}

    /// Get the user's companion, reading from JSONL files if needed
    func getCompanion() -> Companion? {
        if let cached { return cached }
        cached = readFromSessionFiles()
        return cached
    }

    /// Force re-read from disk
    func refresh() {
        cached = readFromSessionFiles()
    }

    private func readFromSessionFiles() -> Companion? {
        let projectsDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects")

        guard let projectDirs = try? FileManager.default.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else {
            logger.debug("No .claude/projects directory found")
            return nil
        }

        // Sort by modification date, newest first
        let sortedDirs = projectDirs.sorted { a, b in
            let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            return aDate > bDate
        }

        for projectDir in sortedDirs {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: .skipsHiddenFiles
            ) else { continue }

            let jsonlFiles = files
                .filter { $0.pathExtension == "jsonl" && !$0.lastPathComponent.hasPrefix("agent-") }
                .sorted { a, b in
                    let aDate = (try? a.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    let bDate = (try? b.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
                    return aDate > bDate
                }

            for file in jsonlFiles.prefix(3) {
                if let companion = scanFile(file) {
                    logger.info("Found companion: \(companion.name, privacy: .public) (\(companion.species, privacy: .public))")
                    return companion
                }
            }
        }

        logger.debug("No companion found in session files")
        return nil
    }

    private func scanFile(_ url: URL) -> Companion? {
        guard let handle = FileHandle(forReadingAtPath: url.path) else { return nil }
        defer { try? handle.close() }

        // Only read the first 16KB - companion_intro is always near the start
        let data = handle.readData(ofLength: 16384)
        guard let content = String(data: data, encoding: .utf8) else { return nil }

        for line in content.components(separatedBy: .newlines) where line.contains("companion_intro") {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let attachment = json["attachment"] as? [String: Any],
                  let name = attachment["name"] as? String,
                  let species = attachment["species"] as? String,
                  !name.isEmpty else { continue }
            return Companion(name: name, species: species)
        }

        return nil
    }
}
