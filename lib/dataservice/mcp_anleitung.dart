/// Ein Assistent und was er zum Eintragen braucht.
class McpClient {
  final String name;

  /// Ob dieser Client einen eigenen Schlüssel mitgeben kann.
  ///
  /// Das ist die Zeile, an der es hängt: wer nur ein Feld für die
  /// Adresse hat, kann unseren Schlüssel nirgends hinschreiben.
  final bool nimmtSchluessel;

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
  ///
  /// [schluessel] ist nur direkt nach dem Erzeugen bekannt — danach steht
  /// hier ein Platzhalter. Das ist kein Mangel, sondern der Grund, warum
  /// der Befehl im Schlüssel-Dialog steht: dort ist er einmal komplett.
  static String claudeCodeBefehl(String adresse, {String? schluessel}) =>
      'claude mcp add --transport http ownapp \\\n'
      '  $adresse \\\n'
      '  --header "Authorization: Bearer ${schluessel ?? 'DEIN_SCHLUESSEL'}"';

  /// Die Assistenten, in der Reihenfolge, in der sie hier nützen.
  ///
  /// Claude Code steht oben, weil es der einzige ist, der den Schlüssel
  /// heute entgegennimmt. Das ist keine Vorliebe, sondern der Stand der
  /// Clients.
  static const List<McpClient> clients = [
    McpClient(
      name: 'Claude Code',
      nimmtSchluessel: true,
      schritte: [
        'Den Befehl unten kopieren und im Terminal ausführen.',
        'Der Schlüssel steht darin — er landet in der Konfiguration von '
            'Claude Code, also nicht in ein geteiltes Verzeichnis legen.',
      ],
      doku: 'https://code.claude.com/docs/en/mcp',
    ),
    McpClient(
      name: 'Claude Desktop / claude.ai',
      nimmtSchluessel: false,
      hinweis: 'Dort gibt es nur ein Feld für die Adresse und optional '
          'OAuth — ein eigener Schlüssel lässt sich nicht eintragen. '
          'Solange das so ist, führt der Weg über Claude Code.',
      schritte: [
        'Einstellungen → Connectors → „Add custom connector".',
        'Adresse eintragen.',
        'Der Zugang antwortet dann mit 404, weil der Schlüssel fehlt — '
            'das ist kein Fehler dieser App.',
      ],
      doku: 'https://support.claude.com/en/articles/'
          '11175166-getting-started-with-custom-connectors-using-remote-mcp',
    ),
    McpClient(
      name: 'ChatGPT',
      nimmtSchluessel: false,
      hinweis: 'Braucht den Entwicklermodus und ein bezahltes Konto '
          '(Plus, Pro, Business, Enterprise oder Edu), und er lässt sich '
          'nur im Browser einschalten.',
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
  ///
  /// Wird das einmal `false`, ist der Zugang für niemanden benutzbar und
  /// die Seite muss etwas anderes sagen als eine Liste von Wegen.
  static bool gibtEsEinenWegMitSchluessel() =>
      clients.any((c) => c.nimmtSchluessel);
}
