/// Welche Art von Schnipsel ein Client zum Einrichten braucht.
enum McpSchnipsel {
  /// Ein Befehl fürs Terminal (`claude mcp add …`).
  befehl,

  /// Ein Stück `claude_desktop_config.json` mit `mcp-remote` als Brücke.
  konfig,

  /// Nur Adresse eintragen, mehr gibt es nicht.
  keiner,
}

/// Ein Assistent und was er zum Eintragen braucht.
class McpClient {
  final String name;

  /// Ob dieser Client einen eigenen Schlüssel mitgeben kann.
  ///
  /// Das ist die Zeile, an der es hängt: wer nur ein Feld für die
  /// Adresse hat, kann unseren Schlüssel nirgends hinschreiben.
  final bool nimmtSchluessel;

  final McpSchnipsel schnipsel;

  /// Der Weg in der Oberfläche, in Schritten.
  final List<String> schritte;

  /// Wo es der Hersteller selbst erklärt.
  final String doku;

  /// Was man sonst noch wissen muss, bevor man anfängt.
  final String? hinweis;

  const McpClient({
    required this.name,
    required this.nimmtSchluessel,
    required this.schritte,
    required this.doku,
    this.schnipsel = McpSchnipsel.keiner,
    this.hinweis,
  });
}

/// Wie man diesen Zugang in einen Assistenten einträgt.
///
/// Reine Rechnung, damit sie sich prüfen lässt — und weil die Adresse
/// eine Stelle ist, an der man sich leicht vertut: die App kennt die
/// API unter `…/api`, der MCP hängt aber **daneben** und nicht darin.
class McpAnleitung {
  McpAnleitung._();

  /// Platzhalter, wo der Schlüssel hingehört. Nach dem Erzeugen kennen
  /// wir ihn nicht mehr — nur seinen Hash.
  static const String platzhalter = 'DEIN_SCHLUESSEL';

  /// Die vollständige Adresse des eigenen Zugangs.
  ///
  /// Aus der eingestellten API-Adresse abgeleitet, ohne deren `/api`:
  /// der MCP-Router hängt neben `/api`, weil dort die CORS-Regeln und
  /// die JWT-Anmeldung sitzen — und ein MCP-Client ist kein Browser.
  ///
  /// Sie muss **vollständig** dastehen. Ein Client bekommt nur diesen
  /// einen String; mit `/mcp/abc` kann niemand etwas anfangen.
  static String adresse(String apiBasis, String? slug) {
    if (slug == null || slug.isEmpty) return '';
    var basis = apiBasis.trim();
    while (basis.endsWith('/')) {
      basis = basis.substring(0, basis.length - 1);
    }
    if (basis.endsWith('/api')) {
      basis = basis.substring(0, basis.length - '/api'.length);
    }
    return '$basis/mcp/$slug';
  }

  /// Der fertige Befehl für Claude Code.
  static String claudeCodeBefehl(String adresse, {String? schluessel}) =>
      'claude mcp add --transport http ownapp \\\n'
      '  $adresse \\\n'
      '  --header "Authorization: Bearer ${schluessel ?? platzhalter}"';

  /// Der Eintrag für `claude_desktop_config.json`.
  ///
  /// Der Umweg über `mcp-remote`: Claude Desktop kann in seinem
  /// Connector-Dialog keinen Header setzen — aber es kann einen
  /// **lokalen** Server starten, und `mcp-remote` ist genau das: eine
  /// Brücke, die von aussen wie ein lokaler Server aussieht und innen
  /// unsere Adresse mit Header ruft.
  ///
  /// **Warum `Authorization:${...}` ohne Leerzeichen und das Leerzeichen
  /// in der Umgebungsvariablen?** Claude Desktop unter Windows (und
  /// einige andere Clients) reichen Argumente mit Leerzeichen falsch an
  /// `npx` weiter und zerlegen den Header dabei. Über die Variable
  /// kommt er heil an. Das sieht nach Zierde aus und ist der
  /// Unterschied zwischen „läuft" und „läuft nicht".
  static String claudeDesktopKonfig(String adresse, {String? schluessel}) =>
      '{\n'
      '  "mcpServers": {\n'
      '    "ownapp": {\n'
      '      "command": "npx",\n'
      '      "args": [\n'
      '        "-y", "mcp-remote",\n'
      '        "$adresse",\n'
      '        "--header", "Authorization:\${AUTH_HEADER}"\n'
      '      ],\n'
      '      "env": {\n'
      '        "AUTH_HEADER": "Bearer ${schluessel ?? platzhalter}"\n'
      '      }\n'
      '    }\n'
      '  }\n'
      '}';

  /// Der Schnipsel, den dieser Client braucht — oder null.
  static String? schnipselFuer(McpClient client, String adresse,
      {String? schluessel}) {
    switch (client.schnipsel) {
      case McpSchnipsel.befehl:
        return claudeCodeBefehl(adresse, schluessel: schluessel);
      case McpSchnipsel.konfig:
        return claudeDesktopKonfig(adresse, schluessel: schluessel);
      case McpSchnipsel.keiner:
        return null;
    }
  }

  /// Die Assistenten, in der Reihenfolge, in der sie hier nützen.
  static const List<McpClient> clients = [
    McpClient(
      name: 'Claude Code',
      nimmtSchluessel: true,
      schnipsel: McpSchnipsel.befehl,
      schritte: [
        'Den Befehl unten kopieren und im Terminal ausführen.',
        'Der Schlüssel steht darin — er landet in der Konfiguration von '
            'Claude Code, also nicht in ein geteiltes Verzeichnis legen.',
      ],
      doku: 'https://code.claude.com/docs/en/mcp',
    ),
    McpClient(
      name: 'Claude Desktop',
      nimmtSchluessel: true,
      schnipsel: McpSchnipsel.konfig,
      hinweis: 'Nicht über „Connectors" — dort gibt es kein Feld für den '
          'Schlüssel. Stattdessen über die Konfigurationsdatei und '
          '`mcp-remote`, eine kleine Brücke, die Claude lokal startet und '
          'die unsere Adresse mit dem Schlüssel ruft. Dafür muss Node.js '
          'auf dem Rechner sein (`npx`).',
      schritte: [
        'Einstellungen → Entwickler → „Konfiguration bearbeiten" öffnet '
            'claude_desktop_config.json. Von Hand: macOS unter '
            '~/Library/Application Support/Claude/, Windows unter '
            '%APPDATA%\\Claude\\.',
        'Den Abschnitt unten hineinkopieren. Gibt es "mcpServers" schon, '
            'nur den Eintrag "ownapp" dazusetzen.',
        'Claude Desktop vollständig beenden und neu starten.',
        'Hängt es beim Verbinden, hilft meist ein zusätzliches '
            '"--transport", "http-only" in den args.',
      ],
      doku: 'https://www.npmjs.com/package/mcp-remote',
    ),
    McpClient(
      name: 'claude.ai im Browser',
      nimmtSchluessel: false,
      hinweis: 'Dort gibt es nur ein Feld für die Adresse und optional '
          'OAuth — ein eigener Schlüssel lässt sich nicht eintragen, und '
          'eine lokale Brücke gibt es im Browser nicht. Der Zugang '
          'antwortet dann mit 404, weil der Schlüssel fehlt; das ist kein '
          'Fehler dieser App.',
      schritte: [
        'Einstellungen → Connectors → „Add custom connector".',
        'Geht heute nur, wenn dieser Zugang OAuth könnte — kann er nicht.',
      ],
      doku: 'https://support.claude.com/en/articles/'
          '11175166-getting-started-with-custom-connectors-using-remote-mcp',
    ),
    McpClient(
      name: 'ChatGPT',
      nimmtSchluessel: false,
      hinweis: 'Braucht den Entwicklermodus und ein bezahltes Konto '
          '(Plus, Pro, Business, Enterprise oder Edu). Läuft im Browser, '
          'also hilft auch hier keine lokale Brücke.',
      schritte: [
        'Einstellungen → Sicherheit und Anmeldung → Entwicklermodus an.',
        'Apps → Plus-Knopf → die Adresse eintragen.',
      ],
      doku: 'https://help.openai.com/en/articles/'
          '12584461-developer-mode-and-mcp-apps-in-chatgpt',
    ),
    McpClient(
      name: 'Gemini',
      nimmtSchluessel: false,
      hinweis: 'Nur in der Web-App, und der Server braucht ein '
          'Zertifikat einer öffentlich anerkannten Stelle — das hat '
          'dieser hier.',
      schritte: [
        'Gemini im Browser öffnen → Connected Apps.',
        'Eigene App hinzufügen und die Adresse eintragen.',
      ],
      doku: 'https://support.google.com/gemini/answer/17209137',
    ),
  ];

  /// Ob überhaupt ein Client den Schlüssel entgegennimmt.
  static bool gibtEsEinenWegMitSchluessel() =>
      clients.any((c) => c.nimmtSchluessel);
}
