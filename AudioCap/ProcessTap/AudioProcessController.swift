import SwiftUI
import AudioToolbox
import OSLog
import Combine

struct AudioProcess: Identifiable, Hashable {
    var id: pid_t
    var name: String
    var bundleURL: URL?
    var objectID: AudioObjectID
}

extension AudioProcess {
    static let defaultIcon = NSWorkspace.shared.icon(for: .application)

    var icon: NSImage {
        guard let bundleURL else { return Self.defaultIcon }
        let image = NSWorkspace.shared.icon(forFile: bundleURL.path)
        image.size = NSSize(width: 32, height: 32)
        return image
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
            .map { $0.filter({ $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) }
            .sink { [weak self] apps in
                guard let self else { return }
                self.reload(apps: apps)
            }
            .store(in: &cancellables)
    }

    fileprivate func reload(apps: [NSRunningApplication]) {
        logger.debug(#function)

        do {
            let objectIdentifiers = try AudioObjectID.readProcessList()
            
            let updatedProcesses: [AudioProcess] = objectIdentifiers.compactMap { objectID in
                do {
                    let pid: pid_t = try objectID.read(kAudioProcessPropertyPID, defaultValue: -1)

                    guard let app = apps.first(where: { $0.processIdentifier == pid }) else { return nil }

                    return AudioProcess(app: app, objectID: objectID)
                } catch {
                    logger.warning("Failed to initialize process with object ID #\(objectID, privacy: .public): \(error, privacy: .public)")
                    return nil
                }
            }

            self.processes = updatedProcesses
                .sorted(by: { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        } catch {
            logger.error("Error reading process list: \(error, privacy: .public)")
        }
    }

}

private extension AudioProcess {
    init(app: NSRunningApplication, objectID: AudioObjectID) {
        let name = app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? app.bundleIdentifier?.components(separatedBy: ".").last ?? "Unknown \(app.processIdentifier)"

        self.init(
            id: app.processIdentifier,
            name: name,
            bundleURL: app.bundleURL,
            objectID: objectID
        )
    }
}
