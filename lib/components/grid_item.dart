import 'package:flutter/material.dart';
import 'package:swiftlead/shared/theme.dart';

class GridItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const GridItem(
      {super.key, required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      surfaceTintColor: Colors.transparent,
      color: amber50,
      child: InkWell(
        onTap: () {
          onTap();
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48.0, color: blue300),
            const SizedBox(height: 8.0),
            Text(title,
                style: TextStyle(
                  fontSize: 20.0,
                  color: blue500,
                  fontWeight: semiBold,
                ),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
