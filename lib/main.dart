import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/settings_provider.dart';
import 'providers/download_provider.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/library_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set immersive system overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.darkBg,
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

  final List<Widget> _screens = const [
    HomeScreen(),
    DownloadsScreen(),
    LibraryScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final downloads = Provider.of<DownloadProvider>(context);
    final l10n = settings.l10n;

    final activeCount = downloads.activeTasks.length;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1F1F3D), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home_rounded),
              label: l10n.get('nav_home'),
            ),
            BottomNavigationBarItem(
              icon: Badge(
                isLabelVisible: activeCount > 0,
                label: Text('$activeCount'),
                backgroundColor: AppTheme.primaryViolet,
                child: const Icon(Icons.downloading_rounded),
              ),
              activeIcon: Badge(
                isLabelVisible: activeCount > 0,
                label: Text('$activeCount'),
                backgroundColor: AppTheme.primaryViolet,
                child: const Icon(Icons.download_rounded),
              ),
              label: l10n.get('nav_downloads'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.video_library_outlined),
              activeIcon: const Icon(Icons.video_library_rounded),
              label: l10n.get('nav_history'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings_outlined),
              activeIcon: const Icon(Icons.settings_rounded),
              label: l10n.get('nav_settings'),
            ),
          ],
        ),
      ),
    );
  }
}
