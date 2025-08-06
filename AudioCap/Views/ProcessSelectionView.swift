import SwiftUI

@MainActor
struct ProcessSelectionView: View {
    @State private var processController = AudioProcessController()
    @State private var tap: ProcessTap?
    @State private var recorder: ProcessTapRecorder?
    @State private var realtimeMonitor: RealtimeAudioMonitor?

    @State private var selectedProcess: AudioProcess?

    var body: some View {
        Section {
            Picker("Process", selection: $selectedProcess) {
                Text("Select…")
                    .tag(Optional<AudioProcess>.none)

                ForEach(processController.processGroups) { group in
                    Section {
                        ForEach(group.processes) { process in
                            HStack {
                                Image(nsImage: process.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 16, height: 16)

                                Text(process.name)
                            }
                                .tag(Optional<AudioProcess>.some(process))
                        }
                    } header: {
                        Text(group.title)
                    }
                }
            }
            .disabled(recorder?.isRecording == true)
            .task { processController.activate() }
            .onChange(of: selectedProcess) { oldValue, newValue in
                guard newValue != oldValue else { return }

                if let newValue {
                    setupRecording(for: newValue)
                    setupRealtimeMonitoring(for: newValue)
                } else if oldValue == tap?.process {
                    teardownTap()
                    teardownRealtimeMonitoring()
                }
            }
        } header: {
            Text("Source")
                .font(.headline)
        }

        if let tap {
            if let errorMessage = tap.errorMessage {
                Text(errorMessage)
                    .font(.headline)
                    .foregroundStyle(.red)
            } else if let recorder {
                RecordingView(recorder: recorder)
                    .onChange(of: recorder.isRecording) { wasRecording, isRecording in
                        /// Each recorder instance can only record a single file, so we create a new file/recorder when recording stops.
                        if wasRecording, !isRecording {
                            createRecorder()
                        }
                    }
            }
        }
        
        // Real-time VAD monitoring section
        if let monitor = realtimeMonitor {
            Section {
                VStack(spacing: 12) {
                    HStack {
                        if monitor.isMonitoring {
                            Button("Stop Real-time Analysis") {
                                monitor.stopMonitoring()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Start Real-time Analysis") {
                                handlingErrors {
                                    try monitor.startMonitoring()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Spacer()
                        
                        if monitor.isMonitoring {
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                    .opacity(0.8)
                                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: monitor.isMonitoring)
                                
                                Text("Live")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    
                    if monitor.isMonitoring {
                        RealtimeVADView(vad: monitor.voiceActivityDetector)
                    } else {
                        Text("Real-time voice activity detection analyzes audio in 4800-sample frames (0.1s at 48kHz) using RMS threshold of 0.01")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                    }
                }
            } header: {
                HStack {
                    Image(systemName: "waveform.badge.magnifyingglass")
                        .foregroundColor(.blue)
                    Text("Real-time Analysis")
                        .font(.headline)
                }
            }
            
            if let errorMessage = monitor.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.top, 4)
            }
        }
    }

    private func setupRecording(for process: AudioProcess) {
        let newTap = ProcessTap(process: process)
        self.tap = newTap
        newTap.activate()

        createRecorder()
    }

    private func createRecorder() {
        guard let tap else { return }

        let filename = "\(tap.process.name)-\(Int(Date.now.timeIntervalSinceReferenceDate))"
        let audioFileURL = URL.applicationSupport.appendingPathComponent(filename, conformingTo: .wav)

        let newRecorder = ProcessTapRecorder(fileURL: audioFileURL, tap: tap)
        self.recorder = newRecorder
    }

    private func teardownTap() {
        tap = nil
    }
    
    private func setupRealtimeMonitoring(for process: AudioProcess) {
        let monitor = RealtimeAudioMonitor(process: process)
        self.realtimeMonitor = monitor
    }
    
    private func teardownRealtimeMonitoring() {
        realtimeMonitor?.stopMonitoring()
        realtimeMonitor = nil
    }
    
    private func handlingErrors(perform block: () throws -> Void) {
        do {
            try block()
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}

extension URL {
    static var applicationSupport: URL {
        do {
            let appSupport = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            let subdir = appSupport.appending(path: "AudioCap", directoryHint: .isDirectory)
            if !FileManager.default.fileExists(atPath: subdir.path) {
                try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
            }
            return subdir
        } catch {
            assertionFailure("Failed to get application support directory: \(error)")

            return FileManager.default.temporaryDirectory
        }
    }
}

