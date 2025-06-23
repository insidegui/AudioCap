import SwiftUI

struct FileProxyView: View {
    let url: URL
    private let icon: NSImage

    @State private var hovered = false

    init(url: URL) {
        self.url = url
        self.icon = NSWorkspace.shared.icon(forFile: url.path)
        self.icon.size = NSSize(width: 32, height: 32)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)

            Text(url.lastPathComponent)
        }
        .padding(6)
        .contentShape(shape)
        .onHover { hovered = $0 }
        .background {
            shape
                .foregroundStyle(.quaternary)
                .opacity(hovered ? 1 : 0)
        }
        .draggable(url)
        .onTapGesture {
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
        }
        .padding(-6)
    }

    private var shape: some InsettableShape {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
    }
}

#if DEBUG
#Preview("File Proxy") {
    FileProxyView(url: URL(filePath: "/System/Library/PrivateFrameworks/AudioPasscode.framework/Versions/A/Resources/Lighthouse.wav"))
        .padding()
}
#endif
