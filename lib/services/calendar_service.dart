import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/app_prefs.dart';
import '../data/plan_store.dart';
import '../theme/app_theme.dart';
import 'web_bridge/web_bridge.dart';

/// "Add to my calendar" with a choice of Google or Apple Calendar. The
/// first pick becomes the default (changeable in Settings).
class CalendarService {
  static String labelFor(String provider) => switch (provider) {
        'google' => 'Google Calendar',
        'apple' => 'Apple Calendar',
        _ => 'Ask on first use',
      };

  /// ICS file content — Apple Calendar (and most others) opens these.
  static String icsFor(Plan p) {
    String fmt(DateTime d) {
      final u = d.toUtc();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${u.year}${two(u.month)}${two(u.day)}'
          'T${two(u.hour)}${two(u.minute)}00Z';
    }

    String esc(String s) =>
        s.replaceAll(',', r'\,').replaceAll(';', r'\;');
    return [
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//YUMS//EN',
      'BEGIN:VEVENT',
      'UID:${p.id}@yums',
      'DTSTAMP:${fmt(DateTime.now())}',
      'DTSTART:${fmt(p.when)}',
      'DTEND:${fmt(p.when.add(const Duration(hours: 2)))}',
      'SUMMARY:${esc('🍽️ ${p.restaurantName}')}',
      'LOCATION:${esc(p.address)}',
      'DESCRIPTION:Planned with YUMS — don\'t forget to rate it after!',
      'END:VEVENT',
      'END:VCALENDAR',
    ].join('\r\n');
  }

  /// Google / Apple picker. Returns 'google', 'apple', or null (dismissed).
  static Future<String?> showChooser(BuildContext context,
      {bool firstTime = true}) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) {
        final colors = dialogContext.colors;
        Widget option(String value, String emoji, String label) => ListTile(
              leading: Text(emoji, style: const TextStyle(fontSize: 22)),
              title: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: AppPrefs.calendarProvider.value == value
                  ? Icon(Icons.check_circle, color: AppTheme.accent)
                  : null,
              onTap: () => Navigator.pop(dialogContext, value),
            );
        return AlertDialog(
          title: const Text('Which calendar do you use?'),
          contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              option('google', '📅', 'Google Calendar'),
              option('apple', '🍎', 'Apple Calendar'),
              if (firstTime)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Text(
                      'We\'ll remember this — change it anytime in '
                      'Settings.',
                      style:
                          TextStyle(fontSize: 12, color: colors.subtle)),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Add [plan] to the user's preferred calendar, asking (and remembering)
  /// on first use.
  static Future<void> addToCalendar(BuildContext context, Plan plan) async {
    var provider = AppPrefs.calendarProvider.value;
    if (provider != 'google' && provider != 'apple') {
      final choice = await showChooser(context);
      if (choice == null) return;
      provider = choice;
      await AppPrefs.setCalendarProvider(choice);
    }

    if (provider == 'apple') {
      // Apple Calendar has no add-event URL; an .ics download does it.
      if (saveIcsFile(icsFor(plan), 'yums-plan.ics')) return;
      // Not in a browser (Android app): fall back to the Google link.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Apple Calendar works on the iPhone/web version '
                '— opening Google Calendar here.')));
      }
    }

    try {
      await launchUrl(googleCalendarUrl(plan),
          mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}
