import SwiftUI
import Charts

struct LimitsPage: View {
    @EnvironmentObject var model: AppModel
    var s: Stats { model.stats }

    var samples: [UsageSample] {
        let all = model.dataset.usage
        guard let days = s.filter.period.days else { return all }
        let lower = Date().timeIntervalSince1970 - Double(days) * 86400
        return all.filter { $0.ts >= lower }
    }

    struct DayUsage: Identifiable {
        var id: Int
        var date: Date
        var fiveHour: Double
        var weekly: Double
    }

    /// Highest five-hour and weekly levels recorded each day.
    private func dailyUsage(_ sm: [UsageSample]) -> [DayUsage] {
        var acc: [Int: DayUsage] = [:]
        for x in sm {
            let d = StatsEngine.local(x.ts).day
            var u = acc[d] ?? DayUsage(id: d, date: StatsEngine.date(ofDay: d), fiveHour: 0, weekly: 0)
            u.fiveHour = max(u.fiveHour, x.fiveHour)
            u.weekly = max(u.weekly, x.weekly)
            acc[d] = u
        }
        return acc.values.sorted { $0.id < $1.id }
    }

    private func legend(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(c).frame(width: 7, height: 7)
            Text(t).font(.ui(11)).foregroundStyle(Theme.text2)
        }
    }

    var body: some View {
        let sm = samples
        let fullHits = countHits(sm)
        let peakWeekly = sm.map(\.weekly).max() ?? 0
        let avg5h = sm.isEmpty ? 0 : sm.map(\.fiveHour).reduce(0, +) / Double(sm.count)
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Limites d'usage", subtitle: "Comment tu consommes ton forfait \(model.dataset.account.plan.isEmpty ? "Claude" : model.dataset.account.plan) : fenêtre de 5 heures et plafond hebdomadaire.")
            HStack(spacing: 14) {
                StatTile(symbol: "gauge.with.dots.needle.100percent", value: Fmt.int(fullHits), label: "Fenêtres de 5 h saturées",
                         detail: "Fois où tu as atteint 100 %")
                StatTile(symbol: "calendar.badge.clock", value: "\(Fmt.int(peakWeekly)) %", label: "Pic hebdomadaire",
                         detail: "Plus haute part du quota de la semaine")
                StatTile(symbol: "speedometer", value: "\(Fmt.int(avg5h)) %", label: "Fenêtre 5 h moyenne",
                         detail: "Niveau moyen relevé")
                StatTile(symbol: "exclamationmark.octagon", value: Fmt.int(s.usageLimitHits), label: "Messages « limite atteinte »",
                         detail: "Dans tes transcripts")
            }
            if sm.isEmpty {
                Card {
                    EmptyHint(text: "L'app Claude n'a pas encore enregistré d'historique d'usage sur cette période.")
                }
            } else {
                Panel(title: "Ta consommation jour par jour", subtitle: "Pic de la fenêtre de 5 h (barres) et niveau du quota hebdomadaire (ligne), d'après \(Fmt.int(sm.count)) relevés de l'app Claude", symbol: "waveform.path.ecg") {
                    let daily = dailyUsage(sm)
                    Chart {
                        ForEach(daily) { d in
                            BarMark(x: .value("Jour", d.date, unit: .day), y: .value("5 h", d.fiveHour))
                                .foregroundStyle(d.fiveHour >= 99.5 ? Theme.accent : Theme.chartNeutral)
                                .cornerRadius(3)
                        }
                        ForEach(daily) { d in
                            LineMark(x: .value("Jour", d.date, unit: .day), y: .value("Semaine", d.weekly))
                                .foregroundStyle(Theme.palette[1])
                                .lineStyle(StrokeStyle(lineWidth: 2))
                                .interpolationMethod(.linear)
                            PointMark(x: .value("Jour", d.date, unit: .day), y: .value("Semaine", d.weekly))
                                .foregroundStyle(Theme.palette[1])
                                .symbolSize(18)
                        }
                        RuleMark(y: .value("Limite", 100))
                            .foregroundStyle(Theme.text3)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            .annotation(position: .top, alignment: .leading) {
                                Text("100 %").font(.ui(10)).foregroundStyle(Theme.text3)
                            }
                    }
                    .chartYScale(domain: 0...110)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 8)) { _ in
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.ui(11)).foregroundStyle(Theme.text3)
                        }
                    }
                    .chartYAxisStyle()
                    .frame(height: 250)
                    HStack(spacing: 16) {
                        legend(Theme.chartNeutral, "Pic de la fenêtre de 5 h")
                        legend(Theme.accent, "Limite de 5 h atteinte")
                        legend(Theme.palette[1], "Quota de la semaine")
                        Spacer()
                        Text("Seuls les jours où l'app Claude était ouverte ont des relevés.")
                            .font(.ui(11)).foregroundStyle(Theme.text3)
                    }
                }
                Panel(title: "Par heure de la journée", subtitle: "Niveau moyen de la fenêtre de 5 h selon l'heure du relevé", symbol: "clock") {
                    let byHour = hourly(sm)
                    Chart(byHour, id: \.0) { h in
                        BarMark(x: .value("Heure", "\(h.0)"), y: .value("%", h.1), width: .ratio(0.7))
                            .foregroundStyle(h.1 >= 50 ? Theme.accent : Theme.chartNeutral)
                            .cornerRadius(3)
                    }
                    .chartXAxis {
                        AxisMarks(values: ["0", "3", "6", "9", "12", "15", "18", "21"]) { v in
                            AxisValueLabel { if let h = v.as(String.self) { Text("\(h) h") } }.font(.ui(10)).foregroundStyle(Theme.text3)
                        }
                    }
                    .chartYAxisStyle()
                    .frame(height: 170)
                }
            }
            HStack(alignment: .top, spacing: 14) {
                Callout(symbol: "clock.arrow.circlepath", title: "La fenêtre de 5 heures",
                        text: "Ton usage est compté sur une fenêtre glissante de 5 heures qui démarre à ton premier message. Quand elle atteint 100 %, il faut attendre qu'elle se réinitialise.")
                Callout(symbol: "calendar", title: "Le plafond hebdomadaire",
                        text: "En plus de la fenêtre de 5 h, un quota sur 7 jours limite l'usage total. Les modèles les plus puissants et les longues sessions le consomment plus vite.")
                Callout(symbol: "leaf", title: "Économiser son quota",
                        text: "Démarre une nouvelle session pour un nouveau sujet, utilise /compact sur les longues conversations et réserve les modèles les plus puissants aux tâches difficiles.")
            }
        }
    }

    private func countHits(_ sm: [UsageSample]) -> Int {
        var hits = 0
        var above = false
        for x in sm {
            if x.fiveHour >= 99.5 {
                if !above { hits += 1 }
                above = true
            } else if x.fiveHour < 90 {
                above = false
            }
        }
        return hits
    }

    private func hourly(_ sm: [UsageSample]) -> [(Int, Double)] {
        var sum = [Double](repeating: 0, count: 24)
        var n = [Int](repeating: 0, count: 24)
        for x in sm {
            let h = StatsEngine.local(x.ts).hour
            sum[h] += x.fiveHour
            n[h] += 1
        }
        return (0..<24).map { ($0, n[$0] > 0 ? sum[$0] / Double(n[$0]) : 0) }
    }
}
