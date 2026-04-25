import SwiftUI

struct ContentView: View {
    private let sections = [
        "Dashboard", "Library", "Sources", "Downloads", "Server",
        "Live TV", "Plugins", "AI", "Cloud", "Settings"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.05, green: 0.09, blue: 0.16), Color(red: 0.1, green: 0.23, blue: 0.38)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Cinavault Server Premium Edition")
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)

                        Text("iOS demo mirror with Emby-inspired layout and Cinavault feature parity sections.")
                            .foregroundStyle(.white.opacity(0.86))

                        ForEach(sections, id: \.self) { section in
                            HStack {
                                Text(section)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding()
                            .background(Color.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }

                        Text("Status: Demo-ready UI shell for App Store build track")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.78))
                            .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Cinavault iOS")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
