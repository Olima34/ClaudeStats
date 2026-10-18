import SwiftUI
import Charts

struct RhythmPage: View {
    @EnvironmentObject var model: AppModel
    @State private var punchByTime = true
    @State private var hoverHour: Int?
    @State private var hoursByTime = true

    var s: Stats { model.stats }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PageHeader(title: "Ton rythme", subtitle: "Quand est-ce que tu travailles avec Claude ? Heures, jours, séries et nuits blanches.")
            chronotype
            Panel(title: "Ta semaine type", subtitle: "Activité par jour de la semaine et par heure", symbol: "square.grid.3x3") {
                PillPicker(options: [true, false].map(BoolOption.init), selection: Binding(get: { BoolOption(punchByTime) }, set: { punchByTime = $0.value }),
                           label: { $0.value ? "Temps" : "Messages" })
            } content: {
                PunchCard(cells: s.punch, useTime: punchByTime)
            }
            HStack(alignment: .top, spacing: 18) {
                hoursChart.frame(maxWidth: .infinity)
                weekdayChart.frame(width: 400)
            }
            .fixedSize(horizontal: false, vertical: true)
            timeline
            HStack(alignment: .top, spacing: 18) {
                topDays.frame(maxWidth: .infinity)
                VStack(spacing: 18) {
                    streaks
                    nights
                }
                .frame(width: 400)
            }
        }
    }

    private var chronotype: some View {
        let (label, text) = Insights.chronotypeDetail(s)
        let night = s.peakHour < 5 || s.peakHour >= 22
        return Card(padding: 22) {
            HStack(spacing: 22) {
                ZStack {
                    Circle().fill(Theme.accent.opacity(0.13)).frame(width: 74, height: 74)
                    Image(systemName: night ? "moon.stars.fill" : (s.peakHour < 12 ? "sunrise.fill" : (s.peakHour < 18 ? "sun.max.fill" : "sunset.fill")))
                        .font(.system(size: 30))
                        .foregroundStyle(Theme.accent)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ton chronotype").font(.ui(11.5)).foregroundStyle(Theme.text3)
                    Text(label).font(.serif(30)).foregroundStyle(Theme.text)
                    Text(text).font(.ui(13)).foregroundStyle(Theme.text2)
                }
                Spacer()
                HStack(spacing: 26) {
                    MiniStat(value: "\(s.peakHour) h", label: "Heure de pointe")
                    MiniStat(value: Fmt.int(s.nightPrompts), label: "Messages après minuit")
                    MiniStat(value: Fmt.pct(s.weekendShare), label: "Le week-end")
                    MiniStat(value: Fmt.duration(s.avgTurnSeconds), label: "Réponse moyenne")
                }
            }
        }
    }

    private func bandColor(_ h: Int) -> Color {
        switch h {
        case 0..<6: return Theme.palette[4]
        case 6..<12: return Theme.palette[7]
        case 12..<18: return Theme.palette[0]
        default: return Theme.palette[1]
        }
    }

    private var hoursChart: some View {
        Panel(title: "Heures de la journée", subtitle: hoursByTime ? "Temps d'activité cumulé par heure" : "Messages envoyés par heure", symbol: "clock") {
            PillPicker(options: [true, false].map(BoolOption.init), selection: Binding(get: { BoolOption(hoursByTime) }, set: { hoursByTime = $0.value }),
                       label: { $0.value ? "Temps" : "Messages" })
        } content: {
            Chart(s.hours) { h in
                BarMark(x: .value("Heure", "\(h.hour)"), y: .value("Valeur", hoursByTime ? h.seconds / 3600 : Double(h.prompts)), width: .ratio(0.72))
                    .foregroundStyle(bandColor(h.hour).opacity(hoverHour == nil || hoverHour == h.hour ? 1 : 0.4))
                    .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: ["0", "3", "6", "9", "12", "15", "18", "21"]) { v in
                    AxisValueLabel { if let h = v.as(String.self) { Text("\(h) h") } }
                        .font(.ui(10)).foregroundStyle(Theme.text3)
                }
            }
            .chartYAxisStyle()
            .chartOverlay { proxy in
                GeometryReader { g in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let p):
                                if let plot = proxy.plotFrame {
                                    let x = p.x - g[plot].origin.x
                                    if let h: String = proxy.value(atX: x), let v = Int(h) { hoverHour = v }
                                }
                            case .ended: hoverHour = nil
                            }
                        }
                }
            }
            .frame(height: 200)
            HStack(spacing: 14) {
                if let h = hoverHour {
                    let st = s.hours[h]
                    Text("\(h) h – \(h + 1) h : \(Fmt.hours(st.seconds)), \(Fmt.plural(st.prompts, "message", "messages"))")
                        .font(.ui(11.5)).foregroundStyle(Theme.text2)
                } else {
                    ForEach([("Nuit", 0), ("Matin", 6), ("Après-midi", 12), ("Soir", 18)], id: \.0) { item in
                        HStack(spacing: 5) {
                            Circle().fill(bandColor(item.1)).frame(width: 7, height: 7)
                            Text(item.0).font(.ui(11)).foregroundStyle(Theme.text3)
                        }
                    }
                }
                Spacer()
            }
        }
    }

    private var weekdayChart: some View {
        Panel(title: "Jours de la semaine", subtitle: "Temps moyen par jour actif", symbol: "calendar") {
            Chart(s.weekdays) { w in
                BarMark(x: .value("Jour", w.name), y: .value("Heures", w.activeDays > 0 ? w.seconds / 3600 / Double(w.activeDays) : 0), width: .ratio(0.6))
                    .foregroundStyle(w.weekday >= 5 ? Theme.palette[1] : Theme.accent)
                    .cornerRadius(4)
                    .annotation(position: .top) {
                        Text(w.activeDays > 0 ? Fmt.hours(w.seconds / Double(w.activeDays)) : "")
                            .font(.ui(9.5)).foregroundStyle(Theme.text3)
                    }
            }
            .chartXAxisStyle()
            .chartYAxis(.hidden)
            .frame(height: 200)
            let busiest = s.weekdays.max(by: { $0.seconds < $1.seconds })?.weekday ?? 0
            Text("Le \(Fmt.weekdayLong[busiest]) est le jour où tu cumules le plus de temps.")
                .font(.ui(11.5)).foregroundStyle(Theme.text3)
        }
    }

    private var timeline: some View {
        Panel(title: "Chronologie", subtitle: "Heures d'activité par jour", symbol: "chart.xyaxis.line") {
            Chart {
                ForEach(s.days) { d in
                    BarMark(x: .value("Jour", d.date, unit: .day), y: .value("Heures", d.seconds / 3600))
                        .foregroundStyle(d.seconds / 3600 > 6 ? Theme.accentDeep : Theme.accent.opacity(0.8))
                        .cornerRadius(2)
                }
                if s.secondsPerActiveDay > 0 {
                    RuleMark(y: .value("Moyenne", s.secondsPerActiveDay / 3600))
                        .foregroundStyle(Theme.text3)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("moyenne \(Fmt.hours(s.secondsPerActiveDay))")
                                .font(.ui(10)).foregroundStyle(Theme.text3)
                        }
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 8)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated)).font(.ui(10)).foregroundStyle(Theme.text3)
                }
            }
            .chartYAxisStyle()
            .frame(height: 200)
        }
    }

    private var topDays: some View {
        Panel(title: "Tes 10 journées les plus intenses", symbol: "trophy") {
            let maxP = Double(s.topDays.first?.prompts ?? 1)
            VStack(spacing: 11) {
                ForEach(Array(s.topDays.enumerated()), id: \.offset) { i, d in
                    RankRow(rank: i + 1, name: Fmt.cap(Fmt.weekday(d.date)),
                            value: "\(Fmt.plural(d.prompts, "message", "messages")) · \(Fmt.hours(d.seconds))",
                            fraction: Double(d.prompts) / maxP, tint: i == 0 ? Theme.accent : Theme.accent.opacity(0.7))
                }
            }
        }
    }

    private var streaks: some View {
        Panel(title: "Séries", subtitle: "Jours consécutifs avec au moins une session", symbol: "flame") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(s.streakCurrent)").font(.serif(46)).foregroundStyle(Theme.accent)
                    Text(s.streakCurrent > 1 ? "jours d'affilée en ce moment" : "jour d'affilée en ce moment")
                        .font(.ui(12.5)).foregroundStyle(Theme.text2)
                }
                Divider().overlay(Theme.border)
                HStack {
                    MiniStat(value: Fmt.plural(s.streakLongest, "jour", "jours"), label: "Record")
                    Spacer()
                    MiniStat(value: s.streakLongestEnd.map { Fmt.dayShort($0) } ?? "–", label: "Terminé le")
                    Spacer()
                    MiniStat(value: Fmt.pct(Double(s.activeDays) / Double(max(1, s.spanDays))), label: "Régularité")
                }
                Text(s.streakCurrent >= s.streakLongest && s.streakCurrent > 1
                     ? "Tu es en train de battre ton record, continue !"
                     : "Encore \(max(1, s.streakLongest - s.streakCurrent + 1)) jours pour battre ton record.")
                    .font(.ui(11.5)).foregroundStyle(Theme.text3)
            }
        }
    }
}

extension RhythmPage {
    var nights: some View {
        Panel(title: "Records d'horaires", symbol: "moon.stars") {
            VStack(alignment: .leading, spacing: 12) {
                if let l = s.records.latestPrompt {
                    recordLine(symbol: "moon.fill", title: "Le plus tard", date: Fmt.ts(l.ts), text: l.text)
                }
                if let e = s.records.earliestPrompt {
                    recordLine(symbol: "sunrise.fill", title: "Le plus tôt", date: Fmt.ts(e.ts), text: e.text)
                }
                if let t = s.records.longestTurn {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "hourglass").font(.ui(12)).foregroundStyle(Theme.accent).frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Plus longue réponse de Claude : \(Fmt.duration(t.seconds))").font(.ui(12, .medium)).foregroundStyle(Theme.text)
                            Text(t.title).font(.ui(11)).foregroundStyle(Theme.text3).lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    func recordLine(symbol: String, title: String, date: Date, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol).font(.ui(12)).foregroundStyle(Theme.accent).frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(title) : \(Fmt.clock(date))").font(.ui(12, .medium)).foregroundStyle(Theme.text)
                Text("\(Fmt.cap(Fmt.weekday(date))) · « \(Dataset.snippet(text, 50)) »").font(.ui(11)).foregroundStyle(Theme.text3).lineLimit(1)
            }
        }
    }
}

struct MiniStat: View {
    var value: String
    var label: String
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.serif(19)).foregroundStyle(Theme.text).lineLimit(1)
            Text(label).font(.ui(10.5)).foregroundStyle(Theme.text3).lineLimit(1)
        }
    }
}
