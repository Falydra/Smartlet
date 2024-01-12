import 'package:flutter/material.dart';
import 'package:swiftlead/shared/theme.dart';

class CustomBottomNavigationItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int currentIndex;
  final int itemIndex;
  final VoidCallback onTap;

  const CustomBottomNavigationItem({super.key, 
    required this.icon,
    required this.label,
    required this.currentIndex,
    required this.itemIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: currentIndex == itemIndex ? amber50 : Colors.transparent,
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Container(
          width: 72.0,
          padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: currentIndex == itemIndex ? blue500 : blue300),
              const SizedBox(
                height: 4.0,
              ),
              Text(
                label,
                style: TextStyle(
                  color: currentIndex == itemIndex ? blue500 : blue300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
