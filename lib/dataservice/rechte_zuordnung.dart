/// Welcher Teil der App welches Recht braucht — an einer Stelle.
///
/// Die Rechte selbst kommen aus dem Backend (dort steht der Katalog im
/// Code). Hier steht nur, welcher Menüpunkt und welche Kachel wozu gehört.
/// Eine Zuordnung an einer Stelle statt verstreuter `if`-Abfragen: sonst
/// vergisst man beim nächsten Bereich die Hälfte.
///
/// Fehlt ein Eintrag, gilt der Punkt als frei zugänglich. Das ist der
/// gutmütige Fall — sichtbar, aber vom Server geprüft.
library;

/// Menüpunkt (Route) → Recht, das man dafür braucht.
const Map<String, String> rechtJeRoute = {
  '/calendar': 'planner:read',
  '/planner': 'planner:read',
  '/planner-types': 'planner:write',
  '/recipes': 'recipes:read',
  '/categories': 'recipes:write',
  '/ingredients': 'recipes:write',
  '/units': 'recipes:write',
  '/time': 'time:read',
  '/tasks': 'tasks:read',
  '/chat': 'chat:use',
  '/assistant': 'chat:use',
  '/pantry': 'pantry:read',
  '/storage-locations': 'pantry:write',
  '/shopping-list': 'shopping:read',
  '/meal-plan': 'mealplan:read',
  '/notes': 'notes:read',
  '/journal': 'journal:read',
};

/// Dashboard-Kachel → Recht. Deckt beide Übersichtsseiten ab.
const Map<String, String> rechtJeKachel = {
  'tasks': 'tasks:read',
  'taskstats': 'tasks:read',
  'tasksdue': 'tasks:read',
  'pantry': 'pantry:read',
  'time': 'time:read',
  'shopping': 'shopping:read',
  'mealplan': 'mealplan:read',
  'journal': 'journal:read',
  'notes': 'notes:read',
};

/// Datenquelle des Dashboards → Recht. Die Schlüssel sind dieselben, die
/// beim Laden benutzt werden, damit gesperrte Bereiche gar nicht erst
/// abgefragt werden.
const Map<String, String> rechtJeQuelle = {
  'tasks': 'tasks:read',
  'shopping': 'shopping:read',
  'pantry': 'pantry:read',
  'ingredients': 'recipes:read',
  'time': 'time:read',
  'mealplan': 'mealplan:read',
  'recipes': 'recipes:read',
  'shops': 'shopping:read',
  'notes': 'notes:read',
  'journal': 'journal:read',
  'planner': 'planner:read',
};

/// Kachel → Datenquelle. Zwei Kacheln koennen aus derselben Quelle kommen
/// ("Aufgaben-Statistik" und "Bald faellig" beide aus den Aufgaben), deshalb
/// ist das nicht dasselbe wie `rechtJeKachel`.
const Map<String, String> quelleJeKachel = {
  'tasks': 'tasks',
  'taskstats': 'tasks',
  'tasksdue': 'tasks',
  'pantry': 'pantry',
  'time': 'time',
  'shopping': 'shopping',
  'mealplan': 'mealplan',
  'journal': 'journal',
  'notes': 'notes',
};
