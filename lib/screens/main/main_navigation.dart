import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../main.dart';
import '../../services/fcm_service.dart';
import '../home/home_screen.dart';
import '../production/production_screen.dart';
import '../feed/feed_screen.dart';
import '../cashbook/cashbook_screen.dart';
import '../profile/profile_screen.dart';

/// Widget utama navigasi 5 tab (Bottom Navigation Bar).
/// Mengelola perpindahan antar tab dan notifikasi foreground.
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _dayRolloverTimer;
  DateTime _displayedDay = _calendarDay(DateTime.now());

  // Daftar 5 halaman utama sesuai PRD
  List<Widget> get _screens => [
    HomeScreen(
      onOpenHarvest: () => setState(() => _currentIndex = 1),
      onOpenFeed: () => setState(() => _currentIndex = 2),
      onOpenCashbook: () => setState(() => _currentIndex = 3),
    ),
    const ProductionScreen(),
    const FeedScreen(),
    const CashBookScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayRollover();
    _setupFCMForegroundHandler();
    FCMService.instance.onMessageTapped = _openFromNotification;
  }

  static DateTime _calendarDay(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  void _scheduleDayRollover() {
    _dayRolloverTimer?.cancel();
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    _dayRolloverTimer = Timer(tomorrow.difference(now), () {
      if (!mounted) return;
      setState(() => _displayedDay = _calendarDay(DateTime.now()));
      _scheduleDayRollover();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = _calendarDay(DateTime.now());
    if (today != _displayedDay && mounted) {
      setState(() => _displayedDay = today);
    }
    _scheduleDayRollover();
  }

  void _openFromNotification(RemoteMessage message) {
    if (!mounted) return;
    final target = (message.data['screen'] ?? message.data['target'] ?? '').toString().toLowerCase();
    final index = switch (target) {
      'panen' || 'production' || 'harvest' => 1,
      'pakan' || 'feed' || 'stock' => 2,
      'kas' || 'cashbook' || 'finance' => 3,
      'profil' || 'profile' => 4,
      _ => 0,
    };
    setState(() => _currentIndex = index);
    final notification = message.notification;
    if (notification != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${notification.title ?? 'Notifikasi'}: ${notification.body ?? 'Dibuka'}')),
      );
    }
  }

  /// Pasang handler notifikasi foreground → tampilkan SnackBar.
  void _setupFCMForegroundHandler() {
    FCMService.instance.onForegroundMessage = (RemoteMessage message) {
      if (!mounted) return;

      final notification = message.notification;
      if (notification == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: MarkasEndogApp.primaryOrange,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                notification.title ?? 'Notifikasi',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              if (notification.body != null)
                Text(
                  notification.body!,
                  style: const TextStyle(color: Colors.white70),
                ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey.shade200),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.grid_view_outlined),
              activeIcon: Icon(Icons.grid_view_rounded),
              label: 'Beranda',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.egg_outlined),
              activeIcon: Icon(Icons.egg_rounded),
              label: 'Panen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.warehouse_outlined),
              activeIcon: Icon(Icons.warehouse_rounded),
              label: 'Pakan',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Buku Kas',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profil',
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dayRolloverTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    FCMService.instance.onForegroundMessage = null;
    FCMService.instance.onMessageTapped = null;
    super.dispose();
  }
}
