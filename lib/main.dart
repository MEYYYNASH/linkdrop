import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/download_provider.dart';
import 'theme/app_theme.dart';
import 'models/update_info.dart';
import 'services/update_service.dart';
import 'screens/home_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/dynamic_nav_bar.dart';
import 'widgets/update_notification_banner.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive system overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider(create: (_) => DownloadProvider()),
      ],
      child: const LinkDropApp(),
    ),
  );
}

class LinkDropApp extends StatelessWidget {
  const LinkDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);

    return MaterialApp(
      title: 'LINKDROP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(settings.themeType),
      home: const MainNavigationShell(),
    );
  }
}

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;
  UpdateInfo? _detectedUpdate;
  bool _dismissedBanner = false;
  Timer? _periodicUpdateTimer;

  final List<Widget> _screens = const [
    HomeScreen(),
    DownloadsScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAppUpdateSilently();
    // Periodically check every 15 minutes for new GitHub releases
    _periodicUpdateTimer = Timer.periodic(const Duration(minutes: 15), (_) {
      _checkAppUpdateSilently();
    });
  }

  @override
  void dispose() {
    _periodicUpdateTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAppUpdateSilently() async {
    // Wait 2 seconds after UI renders before checking in background
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final settings = Provider.of<SettingsProvider>(context, listen: false);
    final update = await settings.checkGitHubUpdate();

    if (mounted && update != null && update.isUpdateAvailable) {
      final isNewDetection = _detectedUpdate?.version != update.version;
      setState(() {
        _detectedUpdate = update;
        _dismissedBanner = false;
      });

      // Send visible in-app notification prompt when a new update is found
      if (isNewDetection && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: AppTheme.accentNeon, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'New update available: v${update.version}!',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: 'UPDATE',
              textColor: AppTheme.cyanGlow,
              onPressed: () => _showUpdateDialog(update),
            ),
            backgroundColor: const Color(0xFF3B0764),
            duration: const Duration(seconds: 8),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        );
      }
    }
  }

  void _showUpdateDialog(UpdateInfo info) {
    final l10n = Provider.of<SettingsProvider>(context, listen: false).l10n;
    showDialog(
      context: context,
      builder: (ctx) => UpdateDialog(
        updateInfo: info,
        currentVersion: SettingsProvider.appVersion,
        l10n: l10n,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final downloads = Provider.of<DownloadProvider>(context);
    final l10n = settings.l10n;

    final activeCount = downloads.activeTasks.length;
    final hasUpdate = _detectedUpdate != null;

    final navItems = [
      DynamicNavBarItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: l10n.get('nav_home'),
      ),
      DynamicNavBarItem(
        icon: Icons.downloading_rounded,
        activeIcon: Icons.download_rounded,
        label: l10n.get('nav_downloads'),
        badgeCount: activeCount,
      ),
      DynamicNavBarItem(
        icon: Icons.video_library_outlined,
        activeIcon: Icons.video_library_rounded,
        label: l10n.get('nav_history'),
      ),
      DynamicNavBarItem(
        icon: Icons.settings_outlined,
        activeIcon: Icons.settings_rounded,
        label: l10n.get('nav_settings'),
        hasUpdateBadge: hasUpdate,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Background ambient gradient glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryViolet.withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyanGlow.withOpacity(0.08),
              ),
            ),
          ),

          // Main screen view
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Top floating in-app update notification banner
                if (hasUpdate && !_dismissedBanner)
                  UpdateNotificationBanner(
                    updateInfo: _detectedUpdate!,
                    l10n: l10n,
                    onInstallTap: () => _showUpdateDialog(_detectedUpdate!),
                    onDismiss: () {
                      setState(() {
                        _dismissedBanner = true;
                      });
                    },
                  ),

                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _screens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // Dynamic Island / Floating Phone Navigation Bar
      bottomNavigationBar: DynamicNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: navItems,
      ),
    );
  }
}
