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

  final List<Widget> _screens = const [
    HomeFeedScreen(), // 0: Khám phá
    CollectionsScreen(), // 1: Bộ sưu tập
    StatsScreen(), // 2: Thống kê
    SettingsScreen(), // 3: Cài đặt (Giao diện màn hình riêng biệt, KHÔNG PHẢI POPUP)
    SearchScreen(), // 4: Tìm kiếm (Kích hoạt qua nút tròn riêng biệt bên phải)
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
        badgeText: '4',
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
        badgeText: '!',
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
            _currentIndex = index;
          });
        },
      ),
    );
  }
}
