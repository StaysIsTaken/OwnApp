import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/dataservice/login_service.dart';
import 'package:productivity/dataservice/weather_service.dart';

class GreetingHeader extends StatefulWidget {
  final int tasksDueToday;
  final int lowPantryItems;
  final WeatherForecast? forecast;
  final bool weatherLoading;
  final VoidCallback? onRefreshWeather;

  const GreetingHeader({
    super.key,
    required this.tasksDueToday,
    required this.lowPantryItems,
    this.forecast,
    this.weatherLoading = false,
    this.onRefreshWeather,
  });

  @override
  State<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<GreetingHeader> {
  static const _weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final user = await LoginService.currentUser;
      if (mounted) {
        setState(() {
          _userName = user.firstname.isNotEmpty ? user.firstname : user.username;
        });
      }
    } catch (_) {
      // Silent fail
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Gute Nacht';
    if (hour < 11) return 'Guten Morgen';
    if (hour < 14) return 'Guten Mittag';
    if (hour < 18) return 'Guten Tag';
    if (hour < 22) return 'Guten Abend';
    return 'Gute Nacht';
  }

  String _getEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 5) return '🌙';
    if (hour < 11) return '☀️';
    if (hour < 14) return '🌤️';
    if (hour < 18) return '☀️';
    if (hour < 22) return '🌅';
    return '🌙';
  }

  String _buildSummary() {
    final parts = <String>[];
    if (widget.tasksDueToday > 0) {
      parts.add('${widget.tasksDueToday} ${widget.tasksDueToday == 1 ? "Task heute fällig" : "Tasks heute fällig"}');
    }
    if (widget.lowPantryItems > 0) {
      parts.add('${widget.lowPantryItems} ${widget.lowPantryItems == 1 ? "niedriger Vorrat" : "niedrige Vorräte"}');
    }
    if (parts.isEmpty) {
      return 'Alles im Griff! Genieße deinen Tag. 🎉';
    }
    return parts.join(' • ');
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final dateFormat = DateFormat('EEEE, d. MMMM yyyy', 'de_DE');
    final onBg = colors.onPrimaryContainer;
    final forecast = widget.forecast;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colors.primaryContainer,
            colors.primaryContainer.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${_getGreeting()}${_userName.isNotEmpty ? ', $_userName' : ''}! ${_getEmoji()}',
                  style: text.headlineSmall?.copyWith(
                    color: onBg,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (widget.weatherLoading && forecast == null)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: onBg),
                )
              else if (forecast?.currentTemp != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${forecast!.currentCode != null ? weatherInfo(forecast.currentCode!).$1 : ''} ${forecast.currentTemp!.round()}°',
                      style: text.titleLarge
                          ?.copyWith(color: onBg, fontWeight: FontWeight.bold),
                    ),
                    if (widget.onRefreshWeather != null)
                      IconButton(
                        icon: Icon(Icons.refresh, size: 18, color: onBg),
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Wetter aktualisieren',
                        onPressed: widget.onRefreshWeather,
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateFormat.format(DateTime.now()),
            style: text.bodyMedium?.copyWith(color: onBg.withValues(alpha: 0.8)),
          ),
          if ((forecast?.place ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.place_outlined, size: 14, color: onBg.withValues(alpha: 0.8)),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    forecast!.place,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelSmall?.copyWith(color: onBg.withValues(alpha: 0.8)),
                  ),
                ),
              ],
            ),
          ],
          // 7-Tage-Wetter
          if (forecast != null && forecast.days.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: forecast.days.map((d) {
                  final wx = weatherInfo(d.code);
                  return Container(
                    width: 54,
                    margin: const EdgeInsets.only(right: 2),
                    child: Column(
                      children: [
                        Text(_weekdays[(d.date.weekday - 1) % 7],
                            style: text.labelSmall?.copyWith(color: onBg)),
                        const SizedBox(height: 2),
                        Text(wx.$1, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 2),
                        Text('${d.tempMax.round()}°',
                            style: text.bodySmall?.copyWith(
                                color: onBg, fontWeight: FontWeight.bold)),
                        Text('${d.tempMin.round()}°',
                            style: text.labelSmall
                                ?.copyWith(color: onBg.withValues(alpha: 0.7))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Container(height: 1, color: onBg.withValues(alpha: 0.2)),
          const SizedBox(height: 12),
          Text(
            _buildSummary(),
            style: text.bodyMedium?.copyWith(
              color: onBg,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
