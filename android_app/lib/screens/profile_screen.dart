import 'dart:io';

import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/classifier_service.dart';
import '../services/cloud_sync.dart';
import '../services/onnx_classifier.dart';
import '../services/scan_store.dart';
import '../widgets/common.dart';
import '../widgets/progress_widgets.dart';
import 'home_screen.dart';
import 'learn_screen.dart';
import 'sign_in_screen.dart';

/// Wipes everything stored on the device (scans, photos, settings).
typedef LocalWipe = Future<void> Function();

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScanStore>();
    final auth = context.watch<AuthService>();
    final sync = context.watch<CloudSync?>();
    final t = Theme.of(context).textTheme;
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 24), children: [
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              const AppLogo(size: 56),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.label ?? 'Guest', style: t.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                    user != null
                        ? (user.email ?? '')
                        : auth.available
                            ? 'Sign in to back up your scans'
                            : 'Scans are stored on this phone only',
                    style: t.bodySmall,
                  ),
                ]),
              ),
            ]),
          ),
        ),
        ProgressSummary(onTapBadges: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen()))),
        Row(children: [
          _Stat(label: 'Scans', value: '${store.scans.length}'),
          _Stat(label: 'Polymers', value: '${store.polymersFound.length}/6'),
          _Stat(label: 'Saved', value: '${store.collection.length}'),
        ]),
        const SectionTitle('Learn'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.school_outlined),
              title: const Text('Learning library'),
              subtitle: const Text('Short lessons and a quiz'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LearnScreen())),
            ),
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: const Text('Badges'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsScreen())),
            ),
          ]),
        ),
        const SectionTitle('Account & sync'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            if (!auth.available)
              const ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('Cloud backup is not set up in this build'),
                subtitle: Text('Everything works offline on this phone.'),
              )
            else if (user == null)
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Sign in or create an account'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SignInScreen())),
              )
            else ...[
              if (sync != null) ...[
                ListTile(
                  leading: sync.busy
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(sync.pendingCount == 0 ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined),
                  title: Text(sync.pendingCount == 0 ? 'All scans backed up' : '${sync.pendingCount} scans waiting to sync'),
                  subtitle: Text(sync.lastError ??
                      (sync.lastSync == null ? 'Not synced yet' : 'Last sync ${DateFormat.jm().format(sync.lastSync!)}')),
                  trailing: TextButton(onPressed: sync.busy ? null : sync.syncNow, child: const Text('Sync now')),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.photo_outlined),
                  title: const Text('Back up photos'),
                  subtitle: const Text('Off by default. Photos stay private to your account.'),
                  value: sync.backupPhotos,
                  onChanged: sync.setBackupPhotos,
                ),
              ],
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  await auth.signOut();
                  if (context.mounted) showSnack(context, 'Signed out. Your scans stay on this phone.');
                },
              ),
            ],
          ]),
        ),
        const SectionTitle('Privacy'),
        Card(
          margin: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('Delete data on this phone'),
              subtitle: const Text('Scans, photos, lessons and settings'),
              onTap: () => _confirmClear(context),
            ),
            if (user != null)
              ListTile(
                leading: Icon(Icons.person_remove_outlined, color: Theme.of(context).colorScheme.error),
                title: Text('Delete my account', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                subtitle: const Text('Removes your account and all cloud data'),
                onTap: () => _confirmDeleteAccount(context),
              ),
            ListTile(
              leading: const Icon(Icons.policy_outlined),
              title: const Text('Privacy summary'),
              onTap: () => _showPrivacy(context),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About PlasticLens'),
              onTap: () => showAbout(context),
            ),
          ]),
        ),
      ]),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(action)),
          ],
        ),
      ) ==
      true;

  Future<void> _confirmClear(BuildContext context) async {
    if (!await _confirm(context, 'Delete data on this phone?',
        'This removes every scan, photo and lesson record stored on this device. Cloud backups are not affected.', 'Delete')) {
      return;
    }
    if (!context.mounted) return;
    await context.read<LocalWipe>()();
    if (context.mounted) showSnack(context, 'Local data deleted');
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    if (!await _confirm(context, 'Delete your account?',
        'Your account, synced scans, backed-up photos and progress will be permanently deleted. This cannot be undone.',
        'Delete account')) {
      return;
    }
    if (!context.mounted) return;
    final auth = context.read<AuthService>();
    final sync = context.read<CloudSync?>();
    final wipe = context.read<LocalWipe>();
    try {
      await auth.deleteAccount((uid) async => sync?.deleteCloudData(uid));
      await wipe();
      if (context.mounted) showSnack(context, 'Account deleted');
    } on AuthException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    } catch (e) {
      if (context.mounted) showSnack(context, 'Could not delete the account: $e');
    }
  }

  void _showPrivacy(BuildContext context) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Your privacy'),
          content: const SingleChildScrollView(
            child: Text(
              '• Photos are analysed on your phone. Nothing is uploaded to identify the plastic.\n'
              '• If you sign in, scan results sync to your private cloud account. Photos are uploaded only if you turn on “Back up photos”.\n'
              '• The optional online second opinion sends the photo to the PlasticLens server, which passes it to an AI service and does not store it.\n'
              '• Material corrections you submit are stored to improve the model.\n'
              '• You can delete local data or your whole account at any time from this screen.',
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );
}

void showAbout(BuildContext context) {
  final classifier = context.read<ClassifierService>();
  final latency = classifier is OnnxClassifier ? classifier.lastLatencyMs : null;
  showAboutDialog(
    context: context,
    applicationName: 'PlasticLens',
    applicationVersion: '1.0.0 · model ${classifier.modelVersion}${latency == null ? '' : ' · last scan $latency ms'}',
    applicationIcon: const AppLogo(size: 40),
    children: [
      const Text('PlasticLens estimates the likely plastic type from a photo. It is a visual estimate, '
          'not a laboratory analysis. Always check the resin code on the item and your local recycling rules.'),
      const SizedBox(height: 12),
      const Text('Training data: PlasticWaste-DB by S. C. Sarkar, J. J. Bushra and M. S. Hossain (Mendeley Data, '
          'doi:10.17632/tvfx5dspf3.1, CC BY 4.0), and TrashNet by G. Thung and M. Yang (MIT licence). '
          'Images were cropped and resized for training.'),
      const SizedBox(height: 12),
      Text('PlasticLens is an independent project and is not affiliated with any other plastic scanner app. '
          'Running on ${Platform.operatingSystem}.'),
    ],
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}
