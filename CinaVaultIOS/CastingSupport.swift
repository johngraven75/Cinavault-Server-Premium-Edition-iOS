import AVKit
import SwiftUI
import UIKit
#if canImport(GoogleCast)
import GoogleCast
#endif

final class CinaVaultAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if canImport(GoogleCast)
        let criteria = GCKDiscoveryCriteria(applicationID: kGCKDefaultMediaReceiverApplicationID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        GCKCastContext.setSharedInstanceWith(options)
        GCKCastContext.sharedInstance().useDefaultExpandedMediaControls = true
        #endif
        return true
    }
}

struct AirPlayRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = true
        picker.tintColor = UIColor(CVColor.text)
        picker.activeTintColor = UIColor(CVColor.cyan)
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(CVColor.text)
        uiView.activeTintColor = UIColor(CVColor.cyan)
    }
}

#if canImport(GoogleCast)
struct GoogleCastRouteButton: UIViewRepresentable {
    func makeUIView(context: Context) -> GCKUICastButton {
        let button = GCKUICastButton(frame: .zero)
        button.tintColor = UIColor(CVColor.text)
        return button
    }

    func updateUIView(_ uiView: GCKUICastButton, context: Context) {
        uiView.tintColor = UIColor(CVColor.text)
    }
}
#else
struct GoogleCastRouteButton: View {
    var body: some View {
        Image(systemName: "dot.radiowaves.left.and.right")
            .foregroundStyle(CVColor.muted)
            .accessibilityLabel("Google Cast SDK unavailable")
    }
}
#endif

@MainActor
final class CastCoordinator: ObservableObject {
    @Published private(set) var statusMessage = "Choose an AirPlay or Google Cast receiver"

    func cast(media: MediaItem, grant: CastGrant, session: RemoteSession) {
        #if canImport(GoogleCast)
        guard let streamURL = resolve(grant.streamUrl, baseURL: session.endpoint) else {
            statusMessage = "The temporary cast stream URL was invalid"
            return
        }

        let metadata = GCKMediaMetadata(metadataType: .movie)
        metadata.setString(media.title, forKey: kGCKMetadataKeyTitle)
        if let year = media.year {
            metadata.setString(String(year), forKey: kGCKMetadataKeyReleaseDate)
        }
        if let artworkPath = grant.artworkUrl,
           let artworkURL = resolve(artworkPath, baseURL: session.endpoint) {
            metadata.addImage(GCKImage(url: artworkURL, width: 480, height: 720))
        }

        let informationBuilder = GCKMediaInformationBuilder(contentURL: streamURL)
        informationBuilder.streamType = .buffered
        informationBuilder.contentType = contentType(for: media)
        informationBuilder.metadata = metadata

        let loadBuilder = GCKMediaLoadRequestDataBuilder()
        loadBuilder.mediaInformation = informationBuilder.build()
        guard let client = GCKCastContext.sharedInstance()
            .sessionManager
            .currentCastSession?
            .remoteMediaClient else {
            statusMessage = "Select a Google Cast receiver first"
            return
        }
        client.loadMedia(with: loadBuilder.build())
        statusMessage = "Casting \(media.title) with a temporary encrypted grant"
        #else
        statusMessage = "Google Cast support is unavailable in this build; AirPlay remains available"
        #endif
    }

    private func resolve(_ path: String, baseURL: URL) -> URL? {
        if let absolute = URL(string: path), absolute.scheme != nil {
            return absolute.scheme?.lowercased() == "https" ? absolute : nil
        }
        let normalized = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard let url = URL(string: normalized, relativeTo: baseURL.appendingPathComponent("/"))?.absoluteURL,
              url.scheme?.lowercased() == "https" else {
            return nil
        }
        return url
    }

    private func contentType(for media: MediaItem) -> String {
        switch media.codec?.lowercased() {
        case "hevc", "h265": "video/mp4"
        case "vp9": "video/webm"
        case "aac": "audio/mp4"
        case "mp3": "audio/mpeg"
        case "flac": "audio/flac"
        default: media.mediaType.lowercased().contains("audio") ? "audio/mp4" : "video/mp4"
        }
    }
}
