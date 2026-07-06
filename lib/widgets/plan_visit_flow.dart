import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/plan_store.dart';
import '../data/social_service.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';

/// Full "plan a visit" flow: date & time, invite friends (they get
/// notified), add to calendar, and reminders before/after.
/// Returns true when a plan was saved.
Future<bool> showPlanVisitFlow(
  BuildContext context, {
  required String restaurantId,
  required String restaurantName,
  required String address,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: DateTime.now(),
    firstDate: DateTime.now(),
    lastDate: DateTime.now().add(const Duration(days: 365)),
    helpText: 'When are you going?',
  );
  if (date == null || !context.mounted) return false;
  final time = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 19, minute: 0),
  );
  if (time == null || !context.mounted) return false;
  final when =
      DateTime(date.year, date.month, date.day, time.hour, time.minute);

  final invited = <String>{};
  var remindBefore = true;
  var remindAfter = true;
  var addToCalendar = false;

  final save = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => StatefulBuilder(
      builder: (context, setSheet) {
        final colors = context.colors;
        final friends = SocialService.friends.value;
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: 20 + MediaQuery.of(context).viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Plan: $restaurantName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.heading(20, color: colors.ink)),
                const SizedBox(height: 2),
                Text(DateFormat.MMMMEEEEd().add_jm().format(when),
                    style: TextStyle(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
                const SizedBox(height: 16),
                Text('Who\'s coming?',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: colors.ink)),
                const SizedBox(height: 4),
                Text(
                    SocialService.cloudMode
                        ? 'Invited friends get a notification with the plan.'
                        : 'Sign in with Google to invite friends.',
                    style: TextStyle(fontSize: 11.5, color: colors.subtle)),
                const SizedBox(height: 8),
                if (friends.isEmpty)
                  Text('No friends yet — add some on the Friends tab.',
                      style: TextStyle(fontSize: 12.5, color: colors.subtle))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: friends.map((f) {
                      final on = invited.contains(f.username);
                      return FilterChip(
                        selected: on,
                        selectedColor:
                            AppTheme.accent.withValues(alpha: 0.18),
                        checkmarkColor: AppTheme.accent,
                        label: Text(f.name),
                        onSelected: (_) => setSheet(() => on
                            ? invited.remove(f.username)
                            : invited.add(f.username)),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: remindBefore,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.accent,
                  title: const Text('Remind me 2 hours before',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  onChanged: (v) => setSheet(() => remindBefore = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: remindAfter,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.accent,
                  title: const Text('Remind me to rate it after',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  onChanged: (v) => setSheet(() => remindAfter = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: addToCalendar,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppTheme.accent,
                  title: const Text('Add to my calendar',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  onChanged: (v) => setSheet(() => addToCalendar = v),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save plan',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (save != true || !context.mounted) return false;

  final plan = await PlanStore.create(
    restaurantId: restaurantId,
    restaurantName: restaurantName,
    address: address,
    when: when,
    friendUsernames: invited.toList(),
  );

  // Invite friends (cloud only).
  if (SocialService.cloudMode) {
    for (final username in invited) {
      SocialService.cloudSendInvite?.call(username, plan);
    }
  }
  // Reminders.
  final baseId = plan.id.hashCode & 0x7ffffff;
  if (remindBefore) {
    final at = when.subtract(const Duration(hours: 2));
    if (at.isAfter(DateTime.now())) {
      await NotificationService.scheduleAt(
          at,
          'Tonight: $restaurantName 🍽️',
          '${DateFormat.jm().format(when)}'
              '${invited.isEmpty ? '' : ' with ${invited.length} friend${invited.length == 1 ? '' : 's'}'} '
              '— get hungry!',
          baseId);
    }
  }
  if (remindAfter) {
    final at = when.add(const Duration(minutes: 90));
    await NotificationService.scheduleAt(
        at.isAfter(DateTime.now())
            ? at
            : DateTime.now().add(const Duration(minutes: 1)),
        'How was $restaurantName? 🍽️',
        'Don\'t forget to rate your visit while it\'s fresh!',
        baseId + 1);
  }
  // Calendar.
  if (addToCalendar) {
    final uri = googleCalendarUrl(plan);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(invited.isEmpty
            ? 'Plan saved for ${DateFormat.MMMd().add_jm().format(when)}'
            : 'Plan saved — ${invited.length} friend${invited.length == 1 ? '' : 's'} invited! 🎉')));
  }
  return true;
}
