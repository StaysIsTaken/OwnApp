/// Welche Art von Schnipsel ein Client zum Einrichten braucht.
enum McpSchnipsel {
  /// Ein Befehl fürs Terminal (`claude mcp add …`).
  befehl,

  /// `claude_desktop_config.json` mit `mcp-remote` als Brücke.
  claudeDesktop,

  /// `~/.gemini/settings.json` — spricht HTTP und Header von sich aus.
  geminiCli,

  /// `~/.codex/config.toml` — holt den Schlüssel aus der Umgebung.
  codexToml,

  /// `mcp.json` in VS Code — fragt den Schlüssel beim ersten Start ab.
  vscode,

  /// Irgendein anderer Client, der lokale Server starten darf.
  bruecke,

  /// Nur Adresse eintragen, mehr gibt es nicht.
  keiner,
}

/// Wo ein Client läuft — und damit, ob er überhaupt eine Chance hat.
///
/// **Das ist die Trennlinie, nicht der Hersteller.** Wer einen lokalen
/// Prozess starten darf, kommt an unseren Schlüssel heran: entweder
/// direkt über einen Header oder über `mcp-remote` als Brücke. Wer im
/// Browser eines Anbieters läuft, kann das nicht — dort gibt es nur ein
/// Feld für die Adresse, und ohne Schlüssel antwortet der Zugang mit
/// 404.
enum McpOrt { lokal, browser }

/// Ein Assistent und was er zum Eintragen braucht.
class McpClient {
  final String name;

  /// Ob dieser Client einen eigenen Schlüssel mitgeben kann.
  final bool nimmtSchluessel;

  final McpSchnipsel schnipsel;

  /// Läuft der Client auf diesem Rechner oder im Browser eines
  /// Anbieters? Danach richtet sich, ob es überhaupt einen Weg gibt.
  final McpOrt ort;

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
    this.ort = McpOrt.lokal,
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

  /// Name der Umgebungsvariablen, in der der Schlüssel stehen soll.
  ///
  /// Einer für alle Clients, die ihn von dort holen — sonst heisst er in
  /// jeder Datei anders und niemand findet ihn wieder.
  static const String variable = 'OWNAPP_MCP_TOKEN';

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

  /// Der Eintrag für `claude_desktop_config.json` — und für jeden
  /// anderen Client, der einen lokalen Server startet.
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

  /// `~/.gemini/settings.json` — Gemini CLI spricht HTTP und setzt
  /// Header selbst, es braucht keine Brücke.
  ///
  /// Ohne Schlüssel steht dort der Name der Umgebungsvariablen: Gemini
  /// CLI setzt `${…}` beim Lesen ein, der Schlüssel muss also nicht in
  /// die Datei.
  static String geminiCliKonfig(String adresse, {String? schluessel}) {
    final wert = schluessel ?? '\${$variable}';
    return '{\n'
        '  "mcpServers": {\n'
        '    "ownapp": {\n'
        '      "httpUrl": "$adresse",\n'
        '      "headers": {\n'
        '        "Authorization": "Bearer $wert"\n'
        '      }\n'
        '    }\n'
        '  }\n'
        '}';
  }

  /// `~/.codex/config.toml` — Codex holt den Schlüssel aus der Umgebung.
  ///
  /// Deshalb steht hier **nie** einer im Klartext, auch nicht im Dialog
  /// direkt nach dem Erzeugen: das Format sieht dafür keinen Platz vor,
  /// es nennt nur den Namen der Variablen.
  static String codexKonfig(String adresse) => '[mcp_servers.ownapp]\n'
      'url = "$adresse"\n'
      'bearer_token_env_var = "$variable"';

  /// `mcp.json` für VS Code — fragt den Schlüssel beim ersten Start ab
  /// und legt ihn in den Anmeldedaten des Systems ab, nicht in der Datei.
  ///
  /// Von den lokalen Wegen der sauberste, und deshalb steht auch hier
  /// nie ein Schlüssel im Schnipsel.
  static String vscodeKonfig(String adresse) => '{\n'
      '  "inputs": [\n'
      '    {\n'
      '      "type": "promptString",\n'
      '      "id": "ownapp-schluessel",\n'
      '      "description": "Schlüssel des Assistent-Zugangs",\n'
      '      "password": true\n'
      '    }\n'
      '  ],\n'
      '  "servers": {\n'
      '    "ownapp": {\n'
      '      "type": "http",\n'
      '      "url": "$adresse",\n'
      '      "headers": {\n'
      '        "Authorization": "Bearer \${input:ownapp-schluessel}"\n'
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
      case McpSchnipsel.claudeDesktop:
      case McpSchnipsel.bruecke:
        return claudeDesktopKonfig(adresse, schluessel: schluessel);
      case McpSchnipsel.geminiCli:
        return geminiCliKonfig(adresse, schluessel: schluessel);
      case McpSchnipsel.codexToml:
        return codexKonfig(adresse);
      case McpSchnipsel.vscode:
        return vscodeKonfig(adresse);
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
      schnipsel: McpSchnipsel.claudeDesktop,
      hinweis: 'Nicht über „Connectors" — dort gibt es kein Feld für den '
          'Schlüssel. Stattdessen über die Konfigurationsdatei und '
          'mcp-remote, eine kleine Brücke, die Claude lokal startet und '
          'die unsere Adresse mit dem Schlüssel ruft. Dafür muss Node.js '
          'auf dem Rechner sein (npx).',
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
      name: 'Gemini CLI',
      nimmtSchluessel: true,
      schnipsel: McpSchnipsel.geminiCli,
      hinweis: 'Braucht keine Brücke — Gemini CLI spricht HTTP und setzt '
          'Header selbst. Der Schlüssel kommt aus einer '
          'Umgebungsvariablen, damit er nicht in der Datei steht.',
      schritte: [
        'Den Schlüssel in die Umgebung legen, etwa in ~/.zshrc: '
            'export $variable="mcp_…"',
        'Den Abschnitt unten nach ~/.gemini/settings.json kopieren — '
            'oder .gemini/settings.json im Projekt.',
        'Kürzer geht es mit: gemini mcp add --transport http ownapp '
            '<Adresse> -H "Authorization: Bearer …"',
      ],
      doku:
          'https://google-gemini.github.io/gemini-cli/docs/tools/mcp-server.html',
    ),
    McpClient(
      name: 'Codex CLI (OpenAI)',
      nimmtSchluessel: true,
      schnipsel: McpSchnipsel.codexToml,
      hinweis: 'Codex nennt in seiner Konfiguration nur den NAMEN der '
          'Variablen — der Schlüssel selbst steht nie in der Datei. '
          'Deshalb steht er auch im Dialog nach dem Erzeugen nicht in '
          'diesem Schnipsel.',
      schritte: [
        'Den Schlüssel in die Umgebung legen: export $variable="mcp_…"',
        'Den Abschnitt unten an ~/.codex/config.toml anhängen.',
      ],
      doku: 'https://developers.openai.com/codex/mcp',
    ),
    McpClient(
      name: 'VS Code (Copilot)',
      nimmtSchluessel: true,
      schnipsel: McpSchnipsel.vscode,
      hinweis: 'Fragt den Schlüssel beim ersten Start ab und legt ihn in '
          'den Anmeldedaten des Systems ab — in der Datei steht er nicht. '
          'Von den lokalen Wegen der sauberste.',
      schritte: [
        'Befehlspalette → „MCP: Add Server" → HTTP. Oder die Datei von '
            'Hand anlegen: .vscode/mcp.json im Projekt.',
        'Den Abschnitt unten hineinkopieren.',
        'Beim ersten Verbinden fragt VS Code nach dem Schlüssel.',
      ],
      doku:
          'https://code.visualstudio.com/docs/agents/reference/mcp-configuration',
    ),
    McpClient(
      name: 'Ein anderer Client mit lokalem Start',
      nimmtSchluessel: true,
      schnipsel: McpSchnipsel.bruecke,
      hinweis: 'Cursor, Windsurf, Cline, Zed und die meisten anderen '
          'nehmen dieselbe Form wie Claude Desktop: ein Eintrag unter '
          '"mcpServers", der einen Befehl startet. Läuft der Client auf '
          'deinem Rechner, geht der Weg über mcp-remote.',
      schritte: [
        'In der MCP-Konfiguration des Clients einen Server unter '
            '"mcpServers" anlegen.',
        'Den Abschnitt unten als Vorlage nehmen; manche Clients nennen '
            'die Datei anders, der Inhalt ist derselbe.',
      ],
      doku: 'https://www.npmjs.com/package/mcp-remote',
    ),
    McpClient(
      name: 'claude.ai im Browser',
      nimmtSchluessel: false,
      ort: McpOrt.browser,
      hinweis: 'Dort gibt es nur ein Feld für die Adresse und optional '
          'OAuth — ein eigener Schlüssel lässt sich nicht eintragen, und '
          'eine lokale Brücke gibt es im Browser nicht. Der Zugang '
          'antwortet dann mit 404, weil der Schlüssel fehlt; das ist kein '
          'Fehler dieser App. Nimm Claude Desktop oder Claude Code.',
      schritte: [
        'Einstellungen → Connectors → „Add custom connector".',
        'Ginge nur, wenn dieser Zugang OAuth könnte — kann er nicht.',
      ],
      doku: 'https://support.claude.com/en/articles/'
          '11175166-getting-started-with-custom-connectors-using-remote-mcp',
    ),
    McpClient(
      name: 'ChatGPT im Browser',
      nimmtSchluessel: false,
      ort: McpOrt.browser,
      hinweis: 'Braucht den Entwicklermodus und ein bezahltes Konto '
          '(Plus, Pro, Business, Enterprise oder Edu) — und auch dann '
          'gibt es kein Feld für den Schlüssel. Für OpenAI führt der Weg '
          'über Codex CLI.',
      schritte: [
        'Einstellungen → Sicherheit und Anmeldung → Entwicklermodus an.',
        'Apps → Plus-Knopf → die Adresse eintragen.',
      ],
      doku: 'https://help.openai.com/en/articles/'
          '12584461-developer-mode-and-mcp-apps-in-chatgpt',
    ),
    McpClient(
      name: 'Gemini im Browser',
      nimmtSchluessel: false,
      ort: McpOrt.browser,
      hinweis: 'Nur die Adresse, kein Schlüssel. Für Google führt der Weg '
          'über Gemini CLI.',
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

  /// Die Clients an diesem Ort, in der Reihenfolge der Liste.
  static List<McpClient> an(McpOrt ort) =>
      clients.where((c) => c.ort == ort).toList();
}
