import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';

class TechnicianBottomNavigation extends StatelessWidget {
  final int currentIndex;

  const TechnicianBottomNavigation({
    super.key,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) {},
      items: [
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.home_rounded,
            label: 'Home',
            currentIndex: currentIndex,
            itemIndex: 0,
            onTap: () {
              if (currentIndex != 0) {
                Navigator.pushReplacementNamed(context, '/technician-home');
              }
            },
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.assignment,
            label: 'Tasks',
            currentIndex: currentIndex,
            itemIndex: 1,
            onTap: () {
              if (currentIndex != 1) {
                Navigator.pushReplacementNamed(context, '/technician-tasks');
              }
            },
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: CustomBottomNavigationItem(
            icon: Icons.build_circle,
            label: 'Installation',
            currentIndex: currentIndex,
            itemIndex: 2,
            onTap: () {
              if (currentIndex != 2) {
                Navigator.pushReplacementNamed(context, '/technician-installations');
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
