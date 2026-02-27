import 'package:flutter/material.dart';
import 'package:swiftlead/shared/theme.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';

class AdminBottomNavigation extends StatelessWidget {
  final int currentIndex;

  const AdminBottomNavigation({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) {

      },
      items: [
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.dashboard,
            label: 'Dashboard',
            currentIndex: currentIndex,
            itemIndex: 0,
            onTap: () {
              if (currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/admin-home');
              }
            },
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.home_work,
            label: 'RBW',
            currentIndex: currentIndex,
            itemIndex: 1,
            onTap: () {
              if (currentIndex != 1) {
                Navigator.pushReplacementNamed(context, '/admin-rbw');
              }
            },
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.build,
            label: 'Installation',
            currentIndex: currentIndex,
            itemIndex: 2,
            onTap: () {
              if (currentIndex != 2) {
                Navigator.pushReplacementNamed(context, '/installation-manager');
              }
            },
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.person,
            label: 'Profile',
            currentIndex: currentIndex,
            itemIndex: 3,
            onTap: () {
              if (currentIndex != 3) {
                Navigator.pushReplacementNamed(context, '/profile-page');
              }
            },
          ),
          label: '',
        ),
      ],
    );
  }
}
