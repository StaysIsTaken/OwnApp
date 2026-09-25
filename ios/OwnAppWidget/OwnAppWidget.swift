// Das Widget auf dem Startbildschirm: nächste Termine und offene Aufgaben.
//
// WARUM ES NICHT SELBST BEIM SERVER FRAGT:
// Es läuft in einem eigenen Prozess, den iOS startet, wann es will. Dort
// gibt es kein gültiges Token (das JWT hält 60 Minuten) und keinen Weg,
// eines zu holen. Die App legt deshalb bei jedem Erinnerungs-Abgleich einen
// fertigen Stand in die App Group (lib/dataservice/widget_stand.dart), und
// hier wird er nur gezeichnet.
//
// Der Stand reicht sieben Tage voraus. Die Zeitleiste unten rückt an jedem
// Terminende nach, damit Vergangenes verschwindet, auch wenn die App
// tagelang geschlossen bleibt.

import SwiftUI
import WidgetKit

// Muss mit `WidgetBruecke.appGroup` in Dart und mit beiden
// .entitlements-Dateien übereinstimmen. Weicht einer ab, liest das Widget
// ins Leere und zeigt dauerhaft „App öffnen".
private let appGroup = "group.de.jpanft.homeapp"
private let schluessel = "ownapp_widget_stand"
private let bekannteFassung = 1

// MARK: - Der Stand, wie die App ihn schreibt

struct Stand: Decodable {
  struct Termin: Decodable {
    let titel: String
    let beginn: TimeInterval
    let ende: TimeInterval
    let ganztag: Bool
    let farbe: String?

    var beginnDatum: Date { Date(timeIntervalSince1970: beginn) }
    var endeDatum: Date { Date(timeIntervalSince1970: ende) }
  }

  struct Aufgabe: Decodable {
    let titel: String
    let faellig: String?
    let prioritaet: String?
  }

  let fassung: Int
  let stand: TimeInterval
  let abgemeldet: Bool?
  let termine: [Termin]
  let aufgaben: [Aufgabe]
  let aufgabenOffen: Int

  static func laden() -> Stand? {
    guard
      let text = UserDefaults(suiteName: appGroup)?.string(forKey: schluessel),
      let daten = text.data(using: .utf8),
      let stand = try? JSONDecoder().decode(Stand.self, from: daten),
      stand.fassung == bekannteFassung
    else { return nil }
    return stand
  }
}

// MARK: - Zeitleiste

struct Eintrag: TimelineEntry {
  let date: Date
  let stand: Stand?

  /// Was zum Zeitpunkt dieses Eintrags noch nicht vorbei ist.
  var termine: [Stand.Termin] {
    (stand?.termine ?? []).filter { $0.endeDatum > date }
  }
}

struct Anbieter: TimelineProvider {
  func placeholder(in context: Context) -> Eintrag {
    Eintrag(date: Date(), stand: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (Eintrag) -> Void) {
    completion(Eintrag(date: Date(), stand: Stand.laden()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Eintrag>) -> Void) {
    let jetzt = Date()
    let stand = Stand.laden()

    // Ein Eintrag jetzt und einer an jedem kommenden Terminende: so fällt
    // ein Termin genau dann weg, wenn er vorbei ist. Um Mitternacht kommt
    // einer dazu, damit „heute" und „morgen" umspringen.
    var zeiten: [Date] = [jetzt]
    for termin in stand?.termine ?? [] where termin.endeDatum > jetzt {
      zeiten.append(termin.endeDatum)
    }
    if let mitternacht = Calendar.current.nextDate(
      after: jetzt, matching: DateComponents(hour: 0, minute: 0),
      matchingPolicy: .nextTime)
    {
      zeiten.append(mitternacht)
    }
    let eintraege = Array(Set(zeiten)).sorted().prefix(20).map {
      Eintrag(date: $0, stand: stand)
    }

    // Danach neu fragen. Ein frischer Stand kommt ohnehin über
    // `updateWidget` aus der App; das hier ist nur der Rückfall.
    let naechste = Calendar.current.date(byAdding: .hour, value: 6, to: jetzt) ?? jetzt
    completion(Timeline(entries: Array(eintraege), policy: .after(naechste)))
  }
}

// MARK: - Darstellung

private func farbe(_ hex: String?) -> Color {
  guard var text = hex?.trimmingCharacters(in: .whitespaces) else { return .blue }
  if text.hasPrefix("#") { text.removeFirst() }
  guard text.count == 6, let wert = UInt32(text, radix: 16) else { return .blue }
  return Color(
    red: Double((wert >> 16) & 0xFF) / 255,
    green: Double((wert >> 8) & 0xFF) / 255,
    blue: Double(wert & 0xFF) / 255)
}

private let uhrzeit: DateFormatter = {
  let f = DateFormatter()
  f.locale = Locale(identifier: "de_DE")
  f.dateFormat = "HH:mm"
  return f
}()

private let wochentag: DateFormatter = {
  let f = DateFormatter()
  f.locale = Locale(identifier: "de_DE")
  f.dateFormat = "EE"
  return f
}()

private let tagFormat: DateFormatter = {
  let f = DateFormatter()
  f.locale = Locale(identifier: "de_DE")
  f.dateFormat = "yyyy-MM-dd"
  return f
}()

/// „09:30", „morgen 09:30", „Di 09:30" — oder „ganztägig".
private func wann(_ t: Stand.Termin, bezug: Date) -> String {
  let kalender = Calendar.current
  let beginn = t.beginnDatum
  // Ein laufender mehrtägiger Termin (Schulferien) gilt als heute.
  let tag = beginn < bezug ? bezug : beginn
  let vorsatz: String
  if kalender.isDate(tag, inSameDayAs: bezug) {
    vorsatz = ""
  } else if let morgen = kalender.date(byAdding: .day, value: 1, to: bezug),
    kalender.isDate(tag, inSameDayAs: morgen)
  {
    vorsatz = "morgen "
  } else {
    vorsatz = wochentag.string(from: tag) + " "
  }
  if t.ganztag { return vorsatz.isEmpty ? "ganztägig" : vorsatz + "ganztägig" }
  if beginn < bezug { return "läuft bis " + uhrzeit.string(from: t.endeDatum) }
  return vorsatz + uhrzeit.string(from: beginn)
}

private func istUeberfaellig(_ a: Stand.Aufgabe, bezug: Date) -> Bool {
  guard let faellig = a.faellig else { return false }
  // Als Text vergleichen geht, weil beide JJJJ-MM-TT sind.
  return faellig <= tagFormat.string(from: bezug)
}

struct TerminZeile: View {
  let termin: Stand.Termin
  let bezug: Date

  var body: some View {
    HStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 2)
        .fill(farbe(termin.farbe))
        .frame(width: 4)
      VStack(alignment: .leading, spacing: 0) {
        Text(termin.titel).font(.caption).bold().lineLimit(1)
        Text(wann(termin, bezug: bezug))
          .font(.caption2).foregroundColor(.secondary).lineLimit(1)
      }
    }
    .frame(maxHeight: 30)
  }
}

struct AufgabenZeile: View {
  let aufgabe: Stand.Aufgabe
  let bezug: Date

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: "circle")
        .font(.caption2)
        .foregroundColor(istUeberfaellig(aufgabe, bezug: bezug) ? .red : .secondary)
      Text(aufgabe.titel).font(.caption).lineLimit(1)
    }
  }
}

struct Hinweis: View {
  let text: String
  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: "calendar")
      Text(text).font(.caption).multilineTextAlignment(.center)
    }
    .foregroundColor(.secondary)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct Fusszeile: View {
  let stand: Stand
  var body: some View {
    Text("Stand " + uhrzeit.string(from: Date(timeIntervalSince1970: stand.stand)))
      .font(.system(size: 9)).foregroundColor(.secondary)
  }
}

struct WidgetAnsicht: View {
  @Environment(\.widgetFamily) var familie
  let eintrag: Eintrag

  var body: some View {
    inhalt.widgetHintergrund()
  }

  @ViewBuilder
  var inhalt: some View {
    if let stand = eintrag.stand {
      if stand.abgemeldet == true {
        Hinweis(text: "Abgemeldet")
      } else {
        switch familie {
        case .systemSmall: klein(stand)
        default: mittel(stand)
        }
      }
    } else {
      Hinweis(text: "App einmal öffnen")
    }
  }

  func klein(_ stand: Stand) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text("Als Nächstes").font(.caption2).foregroundColor(.secondary)
      if eintrag.termine.isEmpty {
        Text("Keine Termine").font(.caption).foregroundColor(.secondary)
      }
      ForEach(Array(eintrag.termine.prefix(2).enumerated()), id: \.offset) { _, t in
        TerminZeile(termin: t, bezug: eintrag.date)
      }
      Spacer(minLength: 0)
      HStack {
        Image(systemName: "checklist")
        Text("\(stand.aufgabenOffen) offen")
      }
      .font(.caption2).foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  func mittel(_ stand: Stand) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Termine").font(.caption2).foregroundColor(.secondary)
        if eintrag.termine.isEmpty {
          Text("Keine").font(.caption).foregroundColor(.secondary)
        }
        ForEach(Array(eintrag.termine.prefix(3).enumerated()), id: \.offset) { _, t in
          TerminZeile(termin: t, bezug: eintrag.date)
        }
        Spacer(minLength: 0)
        Fusszeile(stand: stand)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      VStack(alignment: .leading, spacing: 5) {
        Text("Aufgaben · \(stand.aufgabenOffen)").font(.caption2).foregroundColor(.secondary)
        if stand.aufgaben.isEmpty {
          Text("Alles erledigt").font(.caption).foregroundColor(.secondary)
        }
        ForEach(Array(stand.aufgaben.prefix(4).enumerated()), id: \.offset) { _, a in
          AufgabenZeile(aufgabe: a, bezug: eintrag.date)
        }
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
}

extension View {
  /// Ab iOS 17 verlangt WidgetKit einen ausdrücklichen Hintergrund, sonst
  /// steht dort „Please adopt containerBackground API". Die App läuft ab
  /// iOS 14, deshalb die Weiche.
  @ViewBuilder
  func widgetHintergrund() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      self.containerBackground(.fill.tertiary, for: .widget)
    } else {
      self.padding()
    }
  }
}

// MARK: - Widget

@main
struct OwnAppWidget: Widget {
  // Derselbe Name wie `WidgetBruecke.iosName` in Dart — über ihn stößt die
  // App das Neuzeichnen an.
  let kind = "OwnAppWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Anbieter()) { eintrag in
      WidgetAnsicht(eintrag: eintrag)
    }
    .configurationDisplayName("Heute")
    .description("Nächste Termine und offene Aufgaben.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}
