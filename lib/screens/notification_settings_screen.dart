import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/notification_service.dart';
import '../theme/app_theme.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _notif = NotificationService.instance;

  bool _loading = true;
  bool _enabled = false;
  List<TimeOfDay> _times = const [
    TimeOfDay(hour: 12, minute: 0),
    TimeOfDay(hour: 18, minute: 0),
    TimeOfDay(hour: 22, minute: 0),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _notif.isEnabled();
    final times = await _notif.times();
    if (!mounted) return;
    setState(() {
      _enabled = enabled;
      _times = times;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      // Ask the OS for permission before turning reminders on.
      final granted = await _notif.requestPermissions();
      if (!granted) {
        if (mounted) {
          _toast('Notifications are blocked. Enable them in system settings.');
        }
        return;
      }
    }
    await _notif.setEnabled(value);
    if (!mounted) return;
    setState(() => _enabled = value);
  }

  Future<void> _pickTime(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _times[index],
      helpText: 'Reminder ${index + 1}',
    );
    if (picked == null) return;
    await _notif.setTime(index, picked);
    if (!mounted) return;
    setState(() {
      final next = List<TimeOfDay>.of(_times);
      next[index] = picked;
      _times = next;
    });
    _toast('Reminder ${index + 1} set for ${picked.format(context)}');
  }

  Future<void> _sendTest() async {
    try {
      await _notif.showTest();
      if (mounted) _toast('Test notification sent — check your shade.');
    } catch (e) {
      if (mounted) _toast(e.toString());
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.lora(color: AppTheme.light)),
        backgroundColor: AppTheme.dark,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.light,
      appBar: AppBar(title: const Text('Reminders')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.orange))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              children: [
                Text(
                  'Get a gentle nudge three times a day to record your '
                  'income and expenses so your balances stay accurate.',
                  style: GoogleFonts.lora(
                      fontSize: 14, color: AppTheme.midGray, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.lightGray),
                  ),
                  child: SwitchListTile.adaptive(
                    value: _enabled,
                    activeColor: AppTheme.orange,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    title: Text('Daily reminders',
                        style: GoogleFonts.poppins(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _enabled ? 'On' : 'Off',
                      style: GoogleFonts.lora(
                          fontSize: 13, color: AppTheme.midGray),
                    ),
                    onChanged: _toggle,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _sendTest,
                    icon: const Icon(Icons.notifications_active_outlined,
                        size: 18),
                    label: const Text('Send a test notification'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.dark,
                      side: const BorderSide(color: AppTheme.lightGray),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'TIMES',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.4,
                      color: AppTheme.midGray,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.lightGray),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < _times.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppTheme.lightGray),
                        _TimeRow(
                          label: 'Reminder ${i + 1}',
                          time: _times[i],
                          enabled: _enabled,
                          onTap: () => _pickTime(i),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _TimeRow extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeRow({
    required this.label,
    required this.time,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.dark : AppTheme.midGray;
    return ListTile(
      enabled: enabled,
      onTap: enabled ? onTap : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(Icons.schedule_rounded, color: color, size: 20),
      title: Text(label,
          style: GoogleFonts.poppins(
              fontSize: 14, fontWeight: FontWeight.w500, color: color)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? AppTheme.orangeTint : AppTheme.lightGray,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          time.format(context),
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: enabled ? AppTheme.orange : AppTheme.midGray,
          ),
        ),
      ),
    );
  }
}
