/// Eine Übersichtsseite, wie sie vom Backend kommt.
///
/// `mode` trennt zwei Welten: die Seiten der App und die des
/// Küchen-Tablets. Sonst tauchte die Küchenansicht im Telefonmenü auf.
class DashboardSeite {
  final int id;
  final String key;
  final String name;
  final String? icon;
  final String mode;
  final int orderIndex;

  const DashboardSeite({
    required this.id,
    required this.key,
    required this.name,
    required this.mode,
    required this.orderIndex,
    this.icon,
  });

  static const String modeApp = 'app';
  static const String modeTablet = 'tablet';

  bool get istTablet => mode == modeTablet;

  factory DashboardSeite.fromJson(Map<String, dynamic> j) => DashboardSeite(
        id: (j['id'] as num).toInt(),
        key: j['key'] as String,
        name: j['name'] as String,
        icon: j['icon'] as String?,
        mode: j['mode'] as String? ?? modeApp,
        orderIndex: (j['order_index'] as num?)?.toInt() ?? 0,
      );
}
