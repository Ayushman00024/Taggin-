// lib/bottombar.dart (🌙 True Dark Mode + Scroll-to-Top on Home & Campus)
import 'package:flutter/material.dart';

import 'homescreenui.dart';
import 'uploadscreenui.dart';
import 'profilescreenui.dart';
import 'campuspostscreen.dart';
import 'searchscreen.dart';

class BottomBar extends StatefulWidget {
  const BottomBar({Key? key}) : super(key: key);

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  int _selectedIndex = 0;
  final PageStorageBucket _bucket = PageStorageBucket();

  // 🏠 Home GlobalKey (for scroll control)
  final GlobalKey<HomeScreenUIState> _homeKey = GlobalKey<HomeScreenUIState>();

  Future<bool> _onWillPop() async {
    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      return false;
    }
    return true;
  }

  void _onItemTapped(int index) {
    // 🏠 Home tapped again → scroll-to-top only (no refresh)
    if (index == _selectedIndex && index == 0) {
      HomeScreenUIState.scrollHomeToTop();
      return;
    }

    // 🎓 Campus tapped again → scroll-to-top only (no refresh)
    if (index == _selectedIndex && index == 1) {
      CampusPostScreen.scrollToTop();
      return;
    }

    // ✅ Switch between tabs normally
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      // 🏠 Home Screen
      KeyedSubtree(
        key: const PageStorageKey('home'),
        child: HomeScreenUI(key: _homeKey),
      ),

      // 🎓 Campus Posts
      const KeyedSubtree(
        key: PageStorageKey('campus'),
        child: CampusPostScreen(),
      ),

      // ⬆️ Upload
      const KeyedSubtree(
        key: PageStorageKey('upload'),
        child: UploadScreenUI(),
      ),

      // 🔍 Search
      const KeyedSubtree(
        key: PageStorageKey('search'),
        child: SearchScreen(),
      ),

      // 👤 Profile
      const KeyedSubtree(
        key: PageStorageKey('profile'),
        child: ProfileScreenUI(),
      ),
    ];

    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: PageStorage(
          bucket: _bucket,
          child: IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),
        ),
        bottomNavigationBar: Container(
          color: Colors.black,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black,
                border: const Border(
                  top: BorderSide(color: Colors.black, width: 0),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.05),
                    blurRadius: 6,
                    spreadRadius: -1,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.home_outlined,
                    label: "Home",
                    selected: _selectedIndex == 0,
                    onTap: () => _onItemTapped(0),
                  ),
                  _NavItem(
                    icon: Icons.school_outlined,
                    label: "Students",
                    selected: _selectedIndex == 1,
                    onTap: () => _onItemTapped(1),
                  ),
                  _NavItem(
                    icon: Icons.add_circle_outline,
                    label: "Upload",
                    selected: _selectedIndex == 2,
                    onTap: () => _onItemTapped(2),
                    isCenter: true,
                  ),
                  _NavItem(
                    icon: Icons.search,
                    label: "Search",
                    selected: _selectedIndex == 3,
                    onTap: () => _onItemTapped(3),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    label: "Profile",
                    selected: _selectedIndex == 4,
                    onTap: () => _onItemTapped(4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ------------------------
   NAV ITEM (Dark Mode)
   ------------------------ */
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isCenter;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isCenter = false,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF38BDF8); // 💎 Cyan-blue accent
    const inactiveColor = Colors.white70;
    const textColor = Colors.white;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      splashColor: Colors.white10,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        decoration: selected
            ? BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isCenter
              ? [
            BoxShadow(
              color: activeColor.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, 0),
            ),
          ]
              : null,
        )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isCenter ? 30 : 24,
              color: selected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? activeColor : textColor.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
