import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart';
import '../../services/auth_service.dart';
import '../../services/fcm_service.dart';
import '../../widgets/app_page_header.dart';

/// Tab Profil — Info akun, pengaturan, FCM token, dan logout.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final displayName = user?.displayName?.trim() ?? '';
    final email = user?.email?.trim() ?? '';
    return Scaffold(
      backgroundColor: MarkasEndogApp.surfaceWhite,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            const AppPageHeader(title: 'Profil'),
            const SizedBox(height: 28),

            // Avatar & info user
            Center(child: Column(children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: MarkasEndogApp.primaryOrange,
                child: Text(
                  'AD',
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              Text(displayName.isNotEmpty ? displayName : 'Pemilik Peternakan', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(email.isNotEmpty ? email : '-', style: TextStyle(fontSize: 13, color: MarkasEndogApp.textGrey)),
            ])),
            const SizedBox(height: 28),

            // Informasi Peternakan
            _sectionTitle('Informasi Peternakan'),
            _infoTile(Icons.home_work_outlined, 'Nama Peternakan', 'Markas Endog Farm'),
            _infoTile(Icons.egg_outlined, 'Butir per Tray', '30 butir (default)'),
            _infoTile(Icons.warning_amber_outlined, 'Ambang Peringatan Pakan', '7 hari'),
            const SizedBox(height: 20),

            // FCM Token (untuk testing)
            _sectionTitle('FCM Token (Testing)'),
            ValueListenableBuilder<String?>(
              valueListenable: FCMService.instance.tokenNotifier,
              builder: (context, token, _) {
                final fcmToken = token ?? FCMService.instance.token ?? 'Token belum tersedia';
                return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fcmToken, style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), maxLines: 3, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: fcmToken));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('FCM Token disalin!'), duration: Duration(seconds: 2)),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Salin Token', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: MarkasEndogApp.textDark),
                  ),
                ),
              ]),
                );
              },
            ),
            const SizedBox(height: 20),
            _sectionTitle('Notifikasi Terbaru'),
            ValueListenableBuilder(
              valueListenable: FCMService.instance.recentMessages,
              builder: (context, messages, _) => messages.isEmpty
                  ? const Text('Belum ada notifikasi yang diterima di aplikasi.')
                  : Column(
                      children: messages.take(8).map((message) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(message.notification?.title ?? 'Notifikasi', style: const TextStyle(fontWeight: FontWeight.w600)),
                          if (message.notification?.body != null) Text(message.notification!.body!),
                          if (message.data.isNotEmpty) Text('Tujuan: ${message.data['screen'] ?? message.data['target'] ?? 'Beranda'}', style: TextStyle(fontSize: 11, color: MarkasEndogApp.textGrey)),
                        ]),
                      )).toList(),
                    ),
            ),
            const SizedBox(height: 28),

            // Tombol Logout
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _confirmLogout(context),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Keluar dari Akun'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: MarkasEndogApp.dangerRed,
                  side: const BorderSide(color: MarkasEndogApp.dangerRed),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: Text('Markas Endog v1.0.0', style: TextStyle(fontSize: 11, color: MarkasEndogApp.textGrey.withValues(alpha: 0.6)))),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: MarkasEndogApp.textDark)),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: Row(children: [
        Icon(icon, size: 20, color: MarkasEndogApp.primaryOrange),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: MarkasEndogApp.textGrey)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        ])),
      ]),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Logout', style: TextStyle(fontSize: 16)),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.instance.signOut();
            },
            style: ElevatedButton.styleFrom(backgroundColor: MarkasEndogApp.dangerRed),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }
}
