import SwiftUI

struct BadgesPage: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        let s = model.allTime
        let langs = s.style.languages.filter { $0.count >= 3 }.count
        let list = Insights.achievements(s, langs: langs)
            .sorted { ($0.unlocked ? 1 : 0, $0.progress) > ($1.unlocked ? 1 : 0, $1.progress) }
        let unlocked = list.filter(\.unlocked).count

        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Tes badges", subtitle: "Des petits défis débloqués au fil de tes sessions. Calculés sur toute ton histoire avec Claude.")
            Card(padding: 22, featured: true) {
                HStack(spacing: 24) {
                    ZStack {
                        ProgressRing(progress: Double(unlocked) / Double(max(1, list.count)), lineWidth: 10)
                            .frame(width: 96, height: 96)
                        VStack(spacing: 0) {
                            Text("\(unlocked)").font(.display(30)).foregroundStyle(Theme.text)
                            Text("sur \(list.count)").font(.ui(10.5)).foregroundStyle(Theme.text3)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(unlocked == list.count ? "Collection complète !" : "\(unlocked) badges débloqués")
                            .font(.display(26)).foregroundStyle(Theme.text)
                        if let next = list.first(where: { !$0.unlocked }) {
                            Text("Le plus proche : « \(next.title) », \(Fmt.uncap(next.detail)) (\(Fmt.pct(next.progress))).")
                                .font(.ui(13)).foregroundStyle(Theme.text2)
                        }
                    }
                    Spacer()
                    PixelMascot(pixel: 6)
                }
            }
            TileGrid(columns: 4) {
                ForEach(list) { a in BadgeCard(a: a) }
            }
        }
    }
}

struct BadgeCard: View {
    var a: Achievement
    @State private var hovering = false

    var body: some View {
        Card(padding: 16) {
            VStack(spacing: 10) {
                ZStack {
                    ProgressRing(progress: a.progress, tint: a.unlocked ? Theme.accent : Theme.text3, lineWidth: 4)
                        .frame(width: 66, height: 66)
                    Circle()
                        .fill(a.unlocked ? Theme.fill3 : Theme.fill1)
                        .frame(width: 52, height: 52)
                    Image(systemName: a.symbol)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(a.unlocked ? Theme.text : Theme.text3)
                    if !a.unlocked {
                        Image(systemName: "lock.fill")
                            .font(.ui(9, .bold))
                            .foregroundStyle(Theme.text3)
                            .padding(4)
                            .background(Circle().fill(Theme.cardRaised))
                            .offset(x: 24, y: 24)
                    }
                }
                .rotationEffect(.degrees(hovering && a.unlocked ? -6 : 0))
                Text(a.title)
                    .font(.ui(13, .semibold))
                    .foregroundStyle(a.unlocked ? Theme.text : Theme.text2)
                    .multilineTextAlignment(.center)
                Text(a.detail)
                    .font(.ui(11))
                    .foregroundStyle(Theme.text3)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Label(a.unlocked ? "Débloqué" : "\(Fmt.compact(a.current)) / \(Fmt.compact(a.goal)) \(a.unit)",
                      systemImage: a.unlocked ? "checkmark" : "lock")
                    .font(.ui(11, .medium))
                    .foregroundStyle(a.unlocked ? Theme.text2 : Theme.text3)
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .frame(height: 20)
                    .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Theme.fill2))
            }
            .frame(maxWidth: .infinity)
        }
        .opacity(a.unlocked ? 1 : 0.75)
        .onHover { h in withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { hovering = h } }
    }
}
