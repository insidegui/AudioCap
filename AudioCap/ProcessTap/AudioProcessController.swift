import SwiftUI
import AudioToolbox
import OSLog
import Combine

struct AudioProcess: Identifiable, Hashable {
    var id: pid_t
    var name: String
    var bundleURL: URL?
}

extension AudioProcess {
    static let defaultIcon = NSWorkspace.shared.icon(for: .application)

    var icon: NSImage {
        guard let bundleURL else { return Self.defaultIcon }
        let image = NSWorkspace.shared.icon(forFile: bundleURL.path)
        image.size = NSSize(width: 32, height: 32)
        return image
    }

    var audioObjectID: AudioObjectID {
        get throws { try readAudioObjectID() }
    }
}

extension String: LocalizedError {
    public var errorDescription: String? { self }
}

@MainActor
@Observable
final class AudioProcessController {

    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: AudioProcessController.self))

    private(set) var processes = [AudioProcess]()

    private var cancellables = Set<AnyCancellable>()

    func activate() {
        logger.debug(#function)

        NSWorkspace.shared
            .publisher(for: \.runningApplications, options: [.initial, .new])
            .map { $0.filter({ $0.activationPolicy == .regular && $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) }
            .sink { [weak self] apps in
                guard let self else { return }
                self.reload(apps: apps)
            }
            .store(in: &cancellables)
    }

    fileprivate func reload(apps: [NSRunningApplication]) {
        logger.debug(#function)

        let updatedProcesses: [AudioProcess] = apps.map(AudioProcess.init)

        self.processes = updatedProcesses
            .sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
    }

}

private extension AudioProcess {
    init(app: NSRunningApplication) {
        let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? app.bundleIdentifier?.components(separatedBy: ".").last ?? "Unknown \(app.processIdentifier)"

        self.init(
            id: app.processIdentifier,
            name: name,
            bundleURL: app.bundleURL
        )
    }

    func readAudioObjectID() throws -> AudioObjectID {
        try AudioObjectID.translatePIDToProcessObjectID(pid: id)
    }
}
