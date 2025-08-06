import Foundation
import AVFoundation
import Accelerate
import OSLog

/// Represents a single audio frame analysis result
struct AudioFrameAnalysis: Identifiable, Sendable {
    let id = UUID()
    let timestamp: TimeInterval
    let rmsValue: Float
    let isSpeech: Bool
    let frameSize: Int
    let sampleRate: Double
    
    var description: String {
        "Frame: RMS=\(String(format: "%.4f", rmsValue)), Speech=\(isSpeech ? "YES" : "NO"), Size=\(frameSize)"
    }
}

/// Voice Activity Detector using RMS analysis
@Observable
final class VoiceActivityDetector {
    
    private let logger = Logger(subsystem: kAppSubsystem, category: String(describing: VoiceActivityDetector.self))
    
    // VAD Configuration
    private let rmsThreshold: Float = 0.01
    private let targetFrameSize: Int = 4800 // For 48kHz sample rate (0.1 seconds)
    
    // Real-time analysis results
    private(set) var recentFrames: [AudioFrameAnalysis] = []
    private(set) var currentRMS: Float = 0.0
    private(set) var isSpeechDetected: Bool = false
    private(set) var totalFramesProcessed: Int = 0
    private(set) var speechFrameCount: Int = 0
    
    // Audio buffer management
    private var accumulatedSamples: [Float] = []
    private var lastProcessTime = CFAbsoluteTimeGetCurrent()
    
    // Configuration
    private let maxRecentFrames = 50 // Keep last 50 frames for UI display
    
    init() {
        logger.debug("Initialized VAD with RMS threshold: \(self.rmsThreshold)")
    }
    
    /// Process audio buffer and perform VAD analysis
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let floatChannelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            logger.warning("Invalid audio buffer received")
            return
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        let sampleRate = buffer.format.sampleRate
        
        // Convert to mono if stereo (mix channels)
        var monoSamples: [Float]
        if channelCount == 1 {
            monoSamples = Array(UnsafeBufferPointer(start: floatChannelData[0], count: frameLength))
        } else {
            // Mix stereo to mono
            monoSamples = []
            monoSamples.reserveCapacity(frameLength)
            
            for i in 0..<frameLength {
                var sum: Float = 0.0
                for channel in 0..<channelCount {
                    sum += floatChannelData[channel][i]
                }
                monoSamples.append(sum / Float(channelCount))
            }
        }
        
        // Add samples to accumulation buffer
        accumulatedSamples.append(contentsOf: monoSamples)
        
        // Process complete frames
        let actualFrameSize = min(targetFrameSize, accumulatedSamples.count)
        
        while accumulatedSamples.count >= actualFrameSize {
            let frameData = Array(accumulatedSamples.prefix(actualFrameSize))
            accumulatedSamples.removeFirst(actualFrameSize)
            
            analyzeFrame(frameData, sampleRate: sampleRate)
        }
    }
    
    /// Analyze a single frame of audio data
    private func analyzeFrame(_ samples: [Float], sampleRate: Double) {
        let rms = calculateRMS(samples)
        let isSpeech = rms > rmsThreshold
        let timestamp = CFAbsoluteTimeGetCurrent()
        
        // Update current state
        currentRMS = rms
        isSpeechDetected = isSpeech
        totalFramesProcessed += 1
        
        if isSpeech {
            speechFrameCount += 1
        }
        
        // Create analysis result
        let analysis = AudioFrameAnalysis(
            timestamp: timestamp,
            rmsValue: rms,
            isSpeech: isSpeech,
            frameSize: samples.count,
            sampleRate: sampleRate
        )
        
        // Add to recent frames (keep only latest frames)
        recentFrames.append(analysis)
        if recentFrames.count > maxRecentFrames {
            recentFrames.removeFirst()
        }
        
        logger.debug("Frame analyzed: \(analysis.description)")
    }
    
    /// Calculate RMS (Root Mean Square) of audio samples
    private func calculateRMS(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0.0 }
        
        var rms: Float = 0.0
        
        // Use Accelerate framework for efficient computation
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        
        return rms
    }
    
    /// Reset analysis state
    func reset() {
        accumulatedSamples.removeAll()
        recentFrames.removeAll()
        currentRMS = 0.0
        isSpeechDetected = false
        totalFramesProcessed = 0
        speechFrameCount = 0
        logger.debug("VAD state reset")
    }
    
    /// Get speech activity percentage
    var speechActivityPercentage: Float {
        guard totalFramesProcessed > 0 else { return 0.0 }
        return Float(speechFrameCount) / Float(totalFramesProcessed) * 100.0
    }
} 