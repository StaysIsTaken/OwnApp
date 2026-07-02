import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

/// WMO-Wettercode -> (Emoji, deutscher Kurztext). Gemeinsam von Wetter-Widget
/// und Begrüßungs-Header genutzt.
(String, String) weatherInfo(int c) {
  if (c == 0) return ('☀️', 'Klar');
  if (c <= 2) return ('🌤️', 'Leicht bewölkt');
  if (c == 3) return ('☁️', 'Bewölkt');
  if (c == 45 || c == 48) return ('🌫️', 'Nebel');
  if (c >= 51 && c <= 57) return ('🌦️', 'Niesel');
  if (c >= 61 && c <= 67) return ('🌧️', 'Regen');
  if (c >= 71 && c <= 77) return ('🌨️', 'Schnee');
  if (c >= 80 && c <= 82) return ('🌧️', 'Schauer');
  if (c >= 85 && c <= 86) return ('🌨️', 'Schneeschauer');
  if (c >= 95) return ('⛈️', 'Gewitter');
  return ('☁️', '');
}

class WeatherDay {
  final DateTime date;
  final double tempMax;
  final double tempMin;
  final int code;
  WeatherDay(
      {required this.date,
      required this.tempMax,
      required this.tempMin,
      required this.code});
}

class WeatherForecast {
  final String place;
  final double? currentTemp;
  final int? currentCode;
  final List<WeatherDay> days;
  WeatherForecast(
      {required this.place,
      this.currentTemp,
      this.currentCode,
      required this.days});
}

/// Wetter über Open-Meteo (kostenlos, kein API-Key, metrisch/°C).
/// Nutzt – wenn erlaubt – den aktuellen Standort, sonst die angegebene Stadt.
class WeatherService {
  WeatherService._();
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static Future<({double lat, double lon})?> _currentPosition() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (lat: pos.latitude, lon: pos.longitude);
    } catch (_) {
      return null;
    }
  }

  static Future<({double lat, double lon, String name})?> _geocode(
      String city) async {
    final r = await _dio.get(
      'https://geocoding-api.open-meteo.com/v1/search',
      queryParameters: {
        'name': city,
        'count': 1,
        'language': 'de',
        'format': 'json',
      },
    );
    final results = (r.data['results'] as List?) ?? const [];
    if (results.isEmpty) return null;
    final g = results.first as Map;
    return (
      lat: (g['latitude'] as num).toDouble(),
      lon: (g['longitude'] as num).toDouble(),
      name: (g['name'] ?? city).toString(),
    );
  }

  /// Lädt die 7-Tage-Vorhersage. Standort zuerst, sonst [city].
  /// Gibt null zurück, wenn weder Standort noch gültige Stadt verfügbar.
  static Future<WeatherForecast?> load({String? city}) async {
    double? lat;
    double? lon;
    String place = 'Aktueller Standort';

    final pos = await _currentPosition();
    if (pos != null) {
      lat = pos.lat;
      lon = pos.lon;
    } else if (city != null && city.trim().isNotEmpty) {
      final g = await _geocode(city.trim());
      if (g != null) {
        lat = g.lat;
        lon = g.lon;
        place = g.name;
      }
    }
    if (lat == null || lon == null) return null;

    final r = await _dio.get(
      'https://api.open-meteo.com/v1/forecast',
      queryParameters: {
        'latitude': lat,
        'longitude': lon,
        'daily': 'weather_code,temperature_2m_max,temperature_2m_min',
        'current': 'temperature_2m,weather_code',
        'timezone': 'auto',
        'forecast_days': 7,
        'temperature_unit': 'celsius',
        'wind_speed_unit': 'kmh',
        'precipitation_unit': 'mm',
      },
    );

    final daily = r.data['daily'] as Map;
    final times = (daily['time'] as List);
    final maxs = (daily['temperature_2m_max'] as List);
    final mins = (daily['temperature_2m_min'] as List);
    final codes = (daily['weather_code'] as List);
    final days = <WeatherDay>[];
    for (var i = 0; i < times.length; i++) {
      days.add(WeatherDay(
        date: DateTime.parse(times[i].toString()),
        tempMax: (maxs[i] as num).toDouble(),
        tempMin: (mins[i] as num).toDouble(),
        code: (codes[i] as num).toInt(),
      ));
    }
    final cur = r.data['current'] as Map?;
    return WeatherForecast(
      place: place,
      currentTemp: cur != null ? (cur['temperature_2m'] as num?)?.toDouble() : null,
      currentCode: cur != null ? (cur['weather_code'] as num?)?.toInt() : null,
      days: days,
    );
  }
}
