import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct WrappedPage: View {
    @EnvironmentObject var model: AppModel
    @State private var exported: String?

    var body: some View {
        let s = model.stats
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .bottom) {
                PageHeader(title: "Ton récap", subtitle: "Ton histoire avec Claude \(s.filter.period.longLabel), en une carte à garder ou à partager.")
                Button {
                    export(s)
                } label: {
                    Label("Exporter en image", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SoftButtonStyle(prominent: true))
            }
            if let exported {
                Text(exported).font(.ui(12)).foregroundStyle(Theme.text2)
            }
            HStack {
                Spacer()
                WrappedCard(stats: s, name: model.dataset.account.displayName)
                    .shadow(color: .black.opacity(0.25), radius: 30, y: 12)
                Spacer()
            }
            .padding(.vertical, 10)
        }
    }

    @MainActor
    private func export(_ s: Stats) {
        let card = WrappedCard(stats: s, name: model.dataset.account.displayName, animated: false)
            .environment(\.colorScheme, .dark)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            exported = "L'image n'a pas pu être générée."
            return
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "Mon récap Claude.png"
        panel.directoryURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try png.write(to: url)
            exported = "Image enregistrée : \(url.lastPathComponent)"
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            exported = "Échec de l'enregistrement : \(error.localizedDescription)"
        }
    }
}

/// The shareable "wrapped" card. Uses fixed colors so the exported image always looks the same.
struct WrappedCard: View {
    var stats: Stats
    var name: String
    var animated = true

    private let ink = Color(hex: 0xF5F5F7)
    private let ink2 = Color(hex: 0xA9A9B0)
    private let ink3 = Color(hex: 0x76767E)
    private let accent = Color(hex: Theme.accentHex)
    private let brand = Color(hex: Theme.brandHex)
    private let tile = Color.white.opacity(0.05)

    var body: some View {
        let s = stats
        let persona = Insights.persona(s)
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 10) {
                ClaudeSpark(size: 26, color: brand, animate: animated)
                Text("Mon récap Claude")
                    .font(.ui(15, .semibold))
                    .foregroundStyle(ink)
                Spacer()
                Text(rangeText(s))
                    .font(.ui(11.5))
                    .foregroundStyle(ink3)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("\(name), tu es")
                    .font(.ui(14))
                    .foregroundStyle(ink2)
                HStack(spacing: 12) {
                    Image(systemName: persona.symbol)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(accent)
                    Text(persona.title)
                        .font(.display(36, .bold))
                        .foregroundStyle(ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                Text(persona.summary)
                    .font(.ui(13.5))
                    .foregroundStyle(ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                big(Fmt.hours(s.activeSeconds), "passées avec Claude")
                big(Fmt.int(s.promptCount), "messages envoyés")
                big(Fmt.int(s.sessionCount), "sessions")
                big(Fmt.int(s.activeDays), "jours actifs")
                big("\(s.streakLongest) j", "série record")
                big(Fmt.compact(s.tokens.output), "tokens générés")
            }
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 9) {
                    Text("TOP PROJETS").font(.ui(10, .semibold)).tracking(0.8).foregroundStyle(ink3)
                    ForEach(Array(s.projects.prefix(3).enumerated()), id: \.offset) { i, p in
                        HStack(spacing: 8) {
                            Text("\(i + 1)").font(.display(15)).foregroundStyle(accent).frame(width: 14)
                            Text(p.name).font(.ui(13, .medium)).foregroundStyle(ink).lineLimit(1)
                            Spacer()
                            Text(Fmt.hours(p.seconds)).font(.ui(11.5)).foregroundStyle(ink3)
                        }
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(tile))
                VStack(alignment: .leading, spacing: 9) {
                    Text("EN BREF").font(.ui(10, .semibold)).tracking(0.8).foregroundStyle(ink3)
                    line("sun.max", "Pic à \(s.peakHour) h, le \(Fmt.weekdayLong[s.peakWeekday])")
                    if let c = s.categories.first { line(c.category.symbol, c.category.label) }
                    if let w = s.style.words.first { line("quote.bubble", "Mot favori : « \(w.name) »") }
                    if let m = s.models.first { line("cpu", "Modèle préféré : \(m.label)") }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(tile))
            }
            HStack(alignment: .bottom) {
                Text(funLine(s))
                    .font(.ui(14))
                    .italic()
                    .foregroundStyle(ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 20)
                PixelMascot(pixel: 5, color: brand, bob: animated)
            }
            Text("Généré avec ClaudeStats · \(Fmt.dayYear(Date()))")
                .font(.ui(10.5))
                .foregroundStyle(ink3)
        }
        .padding(30)
        .frame(width: 640)
        .background(
            ZStack {
                LinearGradient(colors: [Color(hex: 0x1C1C20), Color(hex: 0x0D0D10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [accent.opacity(0.22), .clear], center: .topLeading, startRadius: 10, endRadius: 420)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.white.opacity(0.08)))
        .overlay(TopRim(radius: 24, color: .white.opacity(0.14)))
    }

    private func big(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.display(26)).foregroundStyle(ink).monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.ui(11)).foregroundStyle(ink3)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12).fill(tile))
    }

    private func line(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol).font(.ui(11)).foregroundStyle(accent).frame(width: 16)
            Text(text).font(.ui(12.5)).foregroundStyle(ink).lineLimit(1)
        }
    }

    private func rangeText(_ s: Stats) -> String {
        guard s.hasData else { return "" }
        return "\(Fmt.dayShort(s.firstDate)) – \(Fmt.dayShort(Fmt.ts(s.lastTs)))"
    }

    private func funLine(_ s: Stats) -> String {
        let hp = Double(s.style.claudeWords) / 80_000
        if hp >= 1 {
            return "Claude t'a écrit \(Fmt.compact(s.style.claudeWords)) mots, soit \(Fmt.dec(hp)) tomes de Harry Potter."
        }
        return "Tu as envoyé \(Fmt.int(s.promptCount)) messages et Claude a agi \(Fmt.int(s.toolCalls)) fois pour toi."
    }
}
