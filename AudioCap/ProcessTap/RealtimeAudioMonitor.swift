import SwiftUI
import AudioToolbox
import AVFoundation
import OSLog

/// Real-time audio monitor for Voice Activity Detection
@Observable
final class RealtimeAudioMonitor {
    
    let process: AudioProcess
    private let logger: Logger
    private let vad = VoiceActivityDetector()
    
    @ObservationIgnored
    private var tap: ProcessTap?
    
    private(set) var isMonitoring = false
    private(set) var errorMessage: String?
    
    init(process: AudioProcess) {
        self.process = process
        self.logger = Logger(subsystem: kAppSubsystem, category: "\(String(describing: RealtimeAudioMonitor.self))(\(process.name))")
    }
    
    /// Get the VAD instance for UI binding
    var voiceActivityDetector: VoiceActivityDetector {
        return vad
    }
    
    /// Start real-time monitoring
    @MainActor
    func startMonitoring() throws {
        guard !isMonitoring else {
            logger.warning("Already monitoring")
            return
        }
        
        logger.debug("Starting real-time monitoring for \(self.process.name)")
        
        errorMessage = nil
        
        // Create a new tap for monitoring (separate from recording)
        let monitorTap = ProcessTap(process: process, muteWhenRunning: false)
        self.tap = monitorTap
        
        // Activate the tap
        monitorTap.activate()
        
        if let error = monitorTap.errorMessage {
            throw error
        }
        
        // Start the monitoring process
        let queue = DispatchQueue(label: "RealtimeAudioMonitor", qos: .userInitiated)
        
        guard let streamDescription = monitorTap.tapStreamDescription else {
            throw "Tap stream description not available"
        }
        
        var mutableStreamDescription = streamDescription
        guard let format = AVAudioFormat(streamDescription: &mutableStreamDescription) else {
            throw "Failed to create AVAudioFormat"
        }
        
        logger.info("Monitoring with audio format: \(format)")
        
        try monitorTap.run(on: queue) { [weak self] inNow, inInputData, inInputTime, outOutputData, inOutputTime in
            guard let self = self else { return }
            
            do {
                // Create PCM buffer from input data
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, bufferListNoCopy: inInputData, deallocator: nil) else {
                    throw "Failed to create PCM buffer"
                }
                
                // Process buffer through VAD (ensure this runs on main thread for @Observable updates)
                DispatchQueue.main.async {
                    self.vad.processAudioBuffer(buffer)
                }
                
            } catch {
                self.logger.error("Error processing audio buffer: \(error)")
            }
        } invalidationHandler: { [weak self] tap in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.handleMonitoringStop()
            }
        }
        
        isMonitoring = true
        logger.debug("Real-time monitoring started successfully")
    }
    
    /// Stop real-time monitoring
    @MainActor
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        logger.debug("Stopping real-time monitoring")
        
        tap?.invalidate()
        tap = nil
        
        handleMonitoringStop()
    }
    
    private func handleMonitoringStop() {
        isMonitoring = false
        vad.reset()
        logger.debug("Real-time monitoring stopped")
    }
    
    deinit {
        tap?.invalidate()
    }
} 