import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../state/auth/auth_bloc.dart';
import '../../state/auth/auth_state.dart';
import '../../widgets/common/ambient_background.dart';
import '../../widgets/glass/glass_bottom_bar.dart';
import '../collections/collections_screen.dart';
import '../home/home_feed_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../stats/stats_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  // Collections and Stats change when the user acts elsewhere (detail screen...),
  // so they are rebuilt (and reload their data) each time their tab is opened.
  int _collectionsVisit = 0;
  int _statsVisit = 0;

  List<Widget> get _screens => [
        const HomeFeedScreen(), // 0: Khám phá
        CollectionsScreen(key: ValueKey('collections-$_collectionsVisit')), // 1: Bộ sưu tập
        StatsScreen(key: ValueKey('stats-$_statsVisit')), // 2: Thống kê
        const SettingsScreen(), // 3: Cài đặt
        const SearchScreen(), // 4: Tìm kiếm (nút tròn riêng bên phải)
      ];

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    String? userAvatarUrl;
    if (authState is AuthAuthenticated) {
      userAvatarUrl = authState.user.effectiveAvatarUrl;
    }

    // 4 tab chính trong thanh viên nang
    final mainNavItems = [
      const GlassBottomBarItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Khám phá',
      ),
      const GlassBottomBarItem(
        icon: Icons.bookmarks_outlined,
        activeIcon: Icons.bookmarks_rounded,
        label: 'Bộ sưu tập',
      ),
      const GlassBottomBarItem(
        icon: Icons.bar_chart_outlined,
        activeIcon: Icons.bar_chart_rounded,
        label: 'Thống kê',
      ),
      GlassBottomBarItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Cài đặt',
        avatarUrl: userAvatarUrl,
      ),
    ];

    // Nút tròn tìm kiếm độc lập bên phải (Chuẩn ảnh mẫu tham khảo)
    const searchActionItem = GlassBottomBarItem(
      icon: Icons.search_rounded,
      activeIcon: Icons.search_rounded,
      label: 'Tìm kiếm',
    );

    return Scaffold(
      extendBody: true,
      body: AmbientBackground(
        child: IndexedStack(
          index: _currentIndex < _screens.length ? _currentIndex : 0,
          children: _screens,
        ),
      ),
      bottomNavigationBar: GlassBottomBar(
        currentIndex: _currentIndex,
        items: mainNavItems,
        actionItem: searchActionItem,
        actionIndex: 4,
        onTap: (index) {
          setState(() {
            if (index != _currentIndex) {
              if (index == 1) _collectionsVisit++;
              if (index == 2) _statsVisit++;
            }
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
