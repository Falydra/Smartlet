import 'package:flutter/material.dart';
import 'package:swiftlead/components/custom_bottom_navigation.dart';

class UserManagerPage extends StatelessWidget {
  const UserManagerPage({super.key});

  @override
  Widget build(BuildContext context) {
    int currentIndex = 2;
    Widget adminBottomNav() {
      return BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex,
        onTap: (index) {
          // Use pushReplacementNamed so navigation matches other admin pages
          if (index == 0) Navigator.pushReplacementNamed(context, '/home-page');
          if (index == 1) Navigator.pushReplacementNamed(context, '/installation-manager');
          if (index == 2) Navigator.pushReplacementNamed(context, '/user-manager');
          if (index == 3) Navigator.pushReplacementNamed(context, '/profile-page');
        },
        items: [
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.home,
                label: 'Beranda',
                currentIndex: currentIndex,
                itemIndex: 0,
                onTap: () => Navigator.pushReplacementNamed(context, '/home-page'),
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.build_circle,
                label: 'Installation',
                currentIndex: currentIndex,
                itemIndex: 1,
                onTap: () => Navigator.pushReplacementNamed(context, '/installation-manager'),
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.group,
                label: 'Users',
                currentIndex: currentIndex,
                itemIndex: 2,
                onTap: () => Navigator.pushReplacementNamed(context, '/user-manager'),
              ),
              label: ''),
          BottomNavigationBarItem(
              icon: CustomBottomNavigationItem(
                icon: Icons.person,
                label: 'Profil',
                currentIndex: currentIndex,
                itemIndex: 3,
                onTap: () => Navigator.pushReplacementNamed(context, '/profile-page'),
              ),
              label: ''),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('User Manager')),
      body: const Center(
        child: Text('User management coming soon — list users, create, edit, roles.'),
      ),
      bottomNavigationBar: adminBottomNav(),
    );
  }
}
