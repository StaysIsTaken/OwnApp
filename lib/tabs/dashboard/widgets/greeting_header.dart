import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:productivity/dataservice/login_service.dart';

class GreetingHeader extends StatefulWidget {
  final int tasksDueToday;
  final int lowPantryItems;

  const GreetingHeader({
    super.key,
    required this.tasksDueToday,
    required this.lowPantryItems,
  });

  @override
  State<GreetingHeader> createState() => _GreetingHeaderState();
}

class _GreetingHeaderState extends State<GreetingHeader> {
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
            children: [
              Expanded(
                child: Text(
                  '${_getGreeting()}${_userName.isNotEmpty ? ', $_userName' : ''}! ${_getEmoji()}',
                  style: text.headlineSmall?.copyWith(
                    color: colors.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            dateFormat.format(DateTime.now()),
            style: text.bodyMedium?.copyWith(
              color: colors.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            color: colors.onPrimaryContainer.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 12),
          Text(
            _buildSummary(),
            style: text.bodyMedium?.copyWith(
              color: colors.onPrimaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
