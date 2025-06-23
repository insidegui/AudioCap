import SwiftUI

@MainActor
struct RealtimeVADView: View {
    let vad: VoiceActivityDetector
    
    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                // Current Status
                HStack {
                    Circle()
                        .fill(vad.isSpeechDetected ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .animation(.easeInOut(duration: 0.2), value: vad.isSpeechDetected)
                    
                    Text(vad.isSpeechDetected ? "Speech Detected" : "No Speech")
                        .font(.headline)
                        .foregroundColor(vad.isSpeechDetected ? .green : .secondary)
                    
                    Spacer()
                    
                    Text("RMS: \(String(format: "%.4f", vad.currentRMS))")
                        .font(.caption)
                        .monospaced()
                        .foregroundColor(.secondary)
                }
                
                // Statistics
                HStack {
                    VStack(alignment: .leading) {
                        Text("Frames Processed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(vad.totalFramesProcessed)")
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing) {
                        Text("Speech Activity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(String(format: "%.1f", vad.speechActivityPercentage))%")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(vad.speechActivityPercentage > 0 ? .green : .secondary)
                    }
                }
                .padding(.vertical, 4)
                
                // RMS Level Indicator
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("RMS Level")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Threshold: 0.01")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            // Threshold line
                            Rectangle()
                                .fill(Color.orange)
                                .frame(width: 2, height: 12)
                                .offset(x: geometry.size.width * (0.01 / 0.1)) // Assuming max scale of 0.1
                            
                            // Current level
                            Rectangle()
                                .fill(vad.isSpeechDetected ? Color.green : Color.blue)
                                .frame(width: max(2, geometry.size.width * min(1.0, Double(vad.currentRMS) / 0.1)), height: 8)
                                .cornerRadius(4)
                                .animation(.easeOut(duration: 0.1), value: vad.currentRMS)
                        }
                    }
                    .frame(height: 12)
                }
                
                // Frame List
                if !vad.recentFrames.isEmpty {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Frames")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(vad.recentFrames.suffix(15).reversed()) { frame in
                                    FrameAnalysisRow(frame: frame)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(vad.isSpeechDetected ? .green : .secondary)
                    .animation(.easeInOut(duration: 0.2), value: vad.isSpeechDetected)
                
                Text("Real-time Voice Activity Detection")
                    .font(.headline)
            }
        }
    }
}

struct FrameAnalysisRow: View {
    let frame: AudioFrameAnalysis
    
    var body: some View {
        HStack(spacing: 8) {
            // Speech indicator
            Circle()
                .fill(frame.isSpeech ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 6, height: 6)
            
            // RMS value
            Text(String(format: "%.4f", frame.rmsValue))
                .font(.caption)
                .monospaced()
                .frame(width: 60, alignment: .trailing)
                .foregroundColor(frame.isSpeech ? .primary : .secondary)
            
            // Speech status
            Text(frame.isSpeech ? "SPEECH" : "SILENCE")
                .font(.caption)
                .fontWeight(frame.isSpeech ? .medium : .regular)
                .frame(width: 60, alignment: .leading)
                .foregroundColor(frame.isSpeech ? .green : .secondary)
            
            Spacer()
            
            // Frame info
            Text("\(frame.frameSize) samples")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(frame.isSpeech ? Color.green.opacity(0.1) : Color.clear)
        )
    }
}

#if DEBUG
#Preview {
    Form {
        RealtimeVADView(vad: VoiceActivityDetector())
    }
    .formStyle(.grouped)
}
#endif 