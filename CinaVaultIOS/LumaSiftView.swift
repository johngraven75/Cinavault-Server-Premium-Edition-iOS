import SwiftUI

struct LumaSiftView: View {
    @ObservedObject var model: CinaVaultModel
    @State private var showQuarantineConfirmation = false
    @State private var selectedTypes: Set<String> = ["video", "audio", "document", "image"]

    private var plan: LumaSiftPlan? { model.lumaSiftPlan }
    private var queuedCount: Int {
        plan?.groups.flatMap(\.candidates).filter { $0.disposition == "queued_for_quarantine" }.count ?? 0
    }
    private var canApply: Bool {
        plan?.status == "ready_for_review" && queuedCount > 0 && model.runningControlAction == nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    hero
                    typeSelection
                    progressPanel
                    metrics
                    planSection
                    if let plan, !plan.dispositions.isEmpty {
                        dispositionLog(plan)
                    }
                }
                .padding()
            }
            .background(SpatialBackground(motionEnabled: model.preferences.motionEnabled))
            .navigationTitle("LumaSift")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        model.refreshLumaSift()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityLabel("Refresh LumaSift status")
                }
            }
            .task {
                model.refreshLumaSift()
            }
            .task(id: model.lumaSiftProgress.scanning) {
                while model.lumaSiftProgress.scanning && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(900))
                    guard !Task.isCancelled else { break }
                    model.refreshLumaSift()
                }
            }
            .confirmationDialog(
                "Move lower-ranked copies to quarantine?",
                isPresented: $showQuarantineConfirmation,
                titleVisibility: .visible
            ) {
                Button("Move \(queuedCount) file(s) to quarantine") {
                    if let plan { model.applyLumaSiftPlan(plan.id) }
                }
                Button("Keep reviewing", role: .cancel) {}
            } message: {
                Text("The Windows host will revalidate every file and move—not permanently delete—the lower-ranked exact duplicates. You can review quarantine before any permanent erase.")
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Image("LumaSiftLogo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 66, height: 66)
                    .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(.white.opacity(0.24), lineWidth: 1) }
                    .shadow(color: CVColor.cyan.opacity(0.35), radius: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text("EXACT MEDIA RESOLUTION")
                        .font(.system(size: 9, weight: .black))
                        .tracking(1.3)
                        .foregroundStyle(CVColor.cyan)
                    Text("LumaSift")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Keep the luminous best copy. Every candidate is proven before it is ranked.")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                Button {
                    model.startLumaSift(selectedTypes: selectedTypes.sorted())
                } label: {
                    Label(
                        model.lumaSiftProgress.scanning ? "Mapping duplicates…" : "Build exact plan",
                        systemImage: "sparkles"
                    )
                }
                .buttonStyle(.borderedProminent)
                .tint(CVColor.cyan)
                .disabled(model.lumaSiftProgress.scanning || model.runningControlAction != nil || selectedTypes.isEmpty)
                Button {
                    model.refreshLumaSift()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .tint(CVColor.orchid)
                .disabled(model.runningControlAction != nil)
            }
        }
        .padding(18)
        .background(
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.12, blue: 0.24), Color(red: 0.17, green: 0.06, blue: 0.35), Color(red: 0.32, green: 0.03, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 25, style: .continuous)
        )
        .overlay { RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(CVColor.cyan.opacity(0.28), lineWidth: 1) }
    }

    private var typeSelection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHOOSE FILE TYPES").font(.caption.weight(.black)).tracking(1).foregroundStyle(CVColor.text)
                    Text("LumaSift scans only these categories. Every candidate still requires a complete content digest.").font(.caption).foregroundStyle(CVColor.muted)
                }
                Spacer()
                Text("\(selectedTypes.count) selected").font(.caption.weight(.black)).foregroundStyle(CVColor.cyan)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(["video", "audio", "document", "image"], id: \.self) { type in
                    let selected = selectedTypes.contains(type)
                    Button {
                        if selected { selectedTypes.remove(type) } else { selectedTypes.insert(type) }
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(selectionTitle(type)).font(.system(size: 10, weight: .black)).tracking(0.6)
                            Text(selectionDetail(type)).font(.system(size: 9)).lineLimit(1)
                            Text(selected ? "SELECTED" : "NOT SELECTED").font(.system(size: 8, weight: .black)).tracking(0.5)
                        }
                        .foregroundStyle(selected ? CVColor.cyan : CVColor.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background((selected ? CVColor.cyan : CVColor.ink).opacity(selected ? 0.12 : 0.5), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke((selected ? CVColor.cyan : CVColor.muted).opacity(selected ? 0.35 : 0.15), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
            if selectedTypes.isEmpty {
                Text("Choose at least one category to build an exact plan.").font(.caption.weight(.bold)).foregroundStyle(CVColor.solar)
            }
        }
        .padding(16)
        .cvPanel(accent: CVColor.cyan)
    }

    private func selectionTitle(_ type: String) -> String {
        switch type { case "video": "VIDEOS"; case "audio": "MP3 AUDIO"; case "document": "DOCX + PDF"; default: "IMAGES" }
    }

    private func selectionDetail(_ type: String) -> String {
        switch type { case "video": "MP4, MKV, MOV and more"; case "audio": "MP3 files only"; case "document": "Documents and ebooks"; default: "JPG, PNG, HEIC and more" }
    }

    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(model.lumaSiftProgress.phase.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(CVColor.text)
                    Text(model.lumaSiftProgress.message)
                        .font(.caption)
                        .foregroundStyle(CVColor.muted)
                        .lineLimit(2)
                }
                Spacer()
                Text("\(model.lumaSiftProgress.percentage)%")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundStyle(CVColor.cyan)
            }
            ProgressView(value: Double(model.lumaSiftProgress.percentage), total: 100)
                .tint(CVColor.cyan)
            HStack {
                Text("\(model.lumaSiftProgress.current) / \(model.lumaSiftProgress.total) processed")
                Spacer()
                Text("\(model.lumaSiftProgress.filesConsidered) indexed")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(CVColor.muted)
            if let name = model.lumaSiftProgress.currentDisplayName {
                Label(name, systemImage: "doc.text.magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CVColor.text)
                    .lineLimit(1)
            }
            if let error = model.lumaSiftProgress.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
        .padding(16)
        .cvPanel(accent: CVColor.cyan)
    }

    private var metrics: some View {
        HStack(spacing: 8) {
            metric(value: "\(plan?.groups.count ?? 0)", label: "Exact groups", accent: CVColor.cyan)
            metric(value: byteText(plan?.reclaimableBytes ?? 0), label: "Recoverable", accent: CVColor.solar)
            metric(value: "\(queuedCount)", label: "Queued", accent: CVColor.magenta)
        }
    }

    private func metric(value: String, label: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased()).font(.system(size: 8, weight: .black)).tracking(0.8).foregroundStyle(accent)
            Text(value).font(.system(size: 16, weight: .black, design: .rounded)).foregroundStyle(CVColor.text).lineLimit(1).minimumScaleFactor(0.6)
            Text(label == "Recoverable" ? "after quarantine" : "content proof").font(.system(size: 8)).foregroundStyle(CVColor.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .cvPanel(accent: accent, radius: 17)
    }

    @ViewBuilder
    private var planSection: some View {
        if let plan {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RESOLUTION PLAN").font(.caption.weight(.black)).tracking(1).foregroundStyle(CVColor.text)
                        Text("Names, score evidence, and disposition remain visible before any file moves.").font(.caption).foregroundStyle(CVColor.muted)
                    }
                    Spacer()
                    if canApply {
                        Button("Quarantine") { showQuarantineConfirmation = true }
                            .buttonStyle(.borderedProminent)
                            .tint(CVColor.solar)
                    }
                }
                if plan.groups.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: plan.status == "cancelled" ? "pause.circle.fill" : "checkmark.seal.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(plan.status == "cancelled" ? CVColor.solar : CVColor.emerald)
                        Text(plan.status == "cancelled" ? "The last scan stopped safely." : "No exact duplicates are in this plan.")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(CVColor.text)
                        Text("Only complete content matches can enter a cleanup plan.").font(.caption).foregroundStyle(CVColor.muted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                } else {
                    ForEach(plan.groups) { group in groupCard(group) }
                }
            }
            .padding(16)
            .cvPanel(accent: CVColor.orchid)
        } else {
            VStack(spacing: 9) {
                Image(systemName: "sparkles.rectangle.stack.fill").font(.system(size: 38)).foregroundStyle(CVColor.cyan.opacity(0.65))
                Text("Ready to resolve").font(.headline.weight(.black)).foregroundStyle(CVColor.text)
                Text("Ask the connected Windows host to build a review-only exact-media plan.").font(.caption).multilineTextAlignment(.center).foregroundStyle(CVColor.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .cvPanel(accent: CVColor.cyan)
        }
    }

    private func groupCard(_ group: LumaSiftGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXACT CONTENT GROUP").font(.system(size: 8, weight: .black)).tracking(1).foregroundStyle(CVColor.cyan)
                    Text("\(group.candidates.count) matching files").font(.subheadline.weight(.black)).foregroundStyle(CVColor.text)
                }
                Spacer()
                Text(byteText(group.reclaimableBytes)).font(.caption.weight(.black)).foregroundStyle(CVColor.solar)
            }
            ForEach(group.candidates) { candidate in candidateRow(candidate, retained: candidate.id == group.winnerId) }
        }
        .padding(12)
        .background(CVColor.ink.opacity(0.55), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 17, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1) }
    }

    private func candidateRow(_ candidate: LumaSiftCandidate, retained: Bool) -> some View {
        let accent = retained ? CVColor.cyan : CVColor.magenta
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: candidate.mediaKind == "image" || candidate.mediaKind == "photo" ? "photo.fill" : "film.fill")
                .foregroundStyle(accent)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(candidate.displayName).font(.caption.weight(.bold)).foregroundStyle(CVColor.text).lineLimit(1)
                    Text(candidate.disposition.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.system(size: 7, weight: .black)).tracking(0.6).foregroundStyle(accent)
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(accent.opacity(0.12), in: Capsule())
                }
                if !candidate.quality.reasons.isEmpty {
                    Text(candidate.quality.reasons.prefix(3).joined(separator: " · "))
                        .font(.system(size: 9)).foregroundStyle(CVColor.muted).lineLimit(2)
                }
                Text(candidate.dispositionDetail).font(.system(size: 9)).foregroundStyle(.white.opacity(0.78)).lineLimit(2)
            }
            Spacer(minLength: 2)
            Text("\(candidate.qualityScore)").font(.system(size: 11, weight: .black, design: .monospaced)).foregroundStyle(CVColor.text)
        }
        .padding(10)
        .background((retained ? CVColor.cyan : CVColor.magenta).opacity(retained ? 0.08 : 0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(accent.opacity(retained ? 0.28 : 0.12), lineWidth: 1) }
    }

    private func dispositionLog(_ plan: LumaSiftPlan) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("FILES & DISPOSITIONS", systemImage: "list.bullet.rectangle")
                .font(.caption.weight(.black)).tracking(1).foregroundStyle(CVColor.text)
            ForEach(Array(plan.dispositions.suffix(12).reversed())) { event in
                HStack(alignment: .top, spacing: 8) {
                    Text(event.disposition.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.system(size: 7, weight: .black)).tracking(0.55).foregroundStyle(dispositionColor(event.disposition))
                        .frame(width: 105, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(event.displayName).font(.caption.weight(.semibold)).foregroundStyle(CVColor.text).lineLimit(1)
                        Text(event.detail).font(.system(size: 9)).foregroundStyle(CVColor.muted).lineLimit(1)
                    }
                }
            }
        }
        .padding(16)
        .cvPanel(accent: CVColor.orchid)
    }

    private func dispositionColor(_ value: String) -> Color {
        switch value {
        case "retain": CVColor.cyan
        case "quarantined": CVColor.orchid
        case "queued_for_quarantine": CVColor.solar
        case "failed": .red
        default: CVColor.muted
        }
    }

    private func byteText(_ bytes: UInt64) -> String {
        guard bytes > 0 else { return "0 B" }
        let units = ["B", "KB", "MB", "GB", "TB"]
        let index = min(Int(log(Double(bytes)) / log(1024)), units.count - 1)
        return String(format: "%.1f %@", Double(bytes) / pow(1024, Double(index)), units[index])
    }
}
