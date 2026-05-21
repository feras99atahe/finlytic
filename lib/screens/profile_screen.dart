import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart' show firebaseAvailable;
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/finance_service.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _currency = 'USD';

  final _backup = BackupService();
  DateTime? _lastBackup;
  bool _backupLoading = false;
  bool _restoreLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadLastBackup();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameCtrl.text = prefs.getString('profile_name') ?? '';
      _phoneCtrl.text = prefs.getString('profile_phone') ?? '';
      _currency = prefs.getString('profile_currency') ?? 'USD';
    });
  }

  Future<void> _loadLastBackup() async {
    try {
      final t = await _backup.lastBackupTime();
      if (mounted) setState(() => _lastBackup = t);
    } catch (_) {}
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_name', _nameCtrl.text);
    await prefs.setString('profile_phone', _phoneCtrl.text);
    await prefs.setString('profile_currency', _currency);
    if (mounted) {
      _snack('Profile saved.', color: AppTheme.green);
    }
  }

  Future<void> _doBackup() async {
    setState(() => _backupLoading = true);
    try {
      final svc = context.read<FinanceService>();
      await _backup.backupAndTouch(
        accounts: svc.accounts.toList(),
        transactions: svc.transactions.toList(),
        goals: svc.goals.toList(),
        debts: svc.debts.toList(),
      );
      await _loadLastBackup();
      if (mounted) _snack('Backup complete!', color: AppTheme.green);
    } catch (e) {
      if (mounted) _snack('Backup failed: $e', color: AppTheme.orange);
    } finally {
      if (mounted) setState(() => _backupLoading = false);
    }
  }

  Future<void> _doRestore() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Restore from backup?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'This will replace all local data with your cloud backup. This cannot be undone.',
          style: GoogleFonts.lora(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _restoreLoading = true);
    try {
      await _backup.restore();
      if (mounted) {
        await context.read<FinanceService>().load();
        _snack('Restore complete!', color: AppTheme.green);
      }
    } catch (e) {
      if (mounted) _snack('Restore failed: $e', color: AppTheme.orange);
    } finally {
      if (mounted) setState(() => _restoreLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Sign out?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Your local data stays on this device.',
            style: GoogleFonts.lora(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AuthService>().logout();
      if (mounted) Navigator.pop(context);
    }
  }

  void _snack(String msg, {required Color color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;

    return Scaffold(
      backgroundColor: AppTheme.light,
      appBar: AppBar(
        title: Text('Profile',
            style: GoogleFonts.poppins(
                fontSize: 20, fontWeight: FontWeight.w600)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar + email
            Center(
              child: Column(
                children: [
                  Container(
                    width: 88, height: 88,
                    decoration: BoxDecoration(
                      color: AppTheme.orangeTint,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.orange, width: 2.5),
                    ),
                    child: const Icon(Icons.person_rounded,
                        size: 44, color: AppTheme.orange),
                  ),
                  if (firebaseAvailable && user != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      user.email ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.dark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.greenTint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('Signed in',
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.green)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            _sectionLabel('PERSONAL INFORMATION'),
            const SizedBox(height: 16),

            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 32),

            _sectionLabel('PREFERENCES'),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.lightGray),
              ),
              child: Row(
                children: [
                  const Icon(Icons.attach_money_rounded,
                      color: AppTheme.midGray),
                  const SizedBox(width: 12),
                  Text('Currency',
                      style: GoogleFonts.lora(
                          fontSize: 14, color: AppTheme.midGray)),
                  const Spacer(),
                  DropdownButton<String>(
                    value: _currency,
                    underline: const SizedBox(),
                    items: ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD']
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c,
                                  style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600)),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _currency = val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProfile,
                child: const Text('Save Profile'),
              ),
            ),
            const SizedBox(height: 32),

            if (firebaseAvailable) ...[
              // ---- CLOUD BACKUP ----
              _sectionLabel('CLOUD BACKUP'),
              const SizedBox(height: 8),

              if (_lastBackup != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_done_rounded,
                          size: 16, color: AppTheme.green),
                      const SizedBox(width: 6),
                      Text(
                        'Last backup: ${DateFormat('MMM d, yyyy – HH:mm').format(_lastBackup!)}',
                        style: GoogleFonts.poppins(
                            fontSize: 12, color: AppTheme.midGray),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.cloud_upload_outlined,
                      label: 'Backup Now',
                      sublabel: 'Save data to cloud',
                      color: AppTheme.blue,
                      loading: _backupLoading,
                      onTap: _doBackup,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionTile(
                      icon: Icons.cloud_download_outlined,
                      label: 'Restore',
                      sublabel: 'Load from cloud',
                      color: AppTheme.green,
                      loading: _restoreLoading,
                      onTap: _doRestore,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ---- SIGN OUT ----
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign Out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.orange,
                    side: const BorderSide(color: AppTheme.orange),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            Center(
              child: Column(
                children: [
                  Text('Finlytic v1.0.0',
                      style: GoogleFonts.poppins(
                          fontSize: 12, color: AppTheme.midGray)),
                  const SizedBox(height: 4),
                  Text('Smart Personal Finance Tracker',
                      style: GoogleFonts.lora(
                          fontSize: 11,
                          color: AppTheme.midGray,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
          color: AppTheme.midGray,
        ),
      );
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final bool loading;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.lightGray),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            loading
                ? SizedBox(
                    width: 24, height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: color))
                : Icon(icon, color: color, size: 24),
            const SizedBox(height: 10),
            Text(label,
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.dark)),
            const SizedBox(height: 2),
            Text(sublabel,
                style: GoogleFonts.lora(
                    fontSize: 11, color: AppTheme.midGray)),
          ],
        ),
      ),
    );
  }
}
