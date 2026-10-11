import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';
import '../theme.dart';

class ThemeSelectionScreen extends StatelessWidget {
  const ThemeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 1),
              const Text(
                'Choose Your Theme',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Select a theme to personalize your experience',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const Spacer(flex: 1),
              _ThemeCard(
                title: 'Dark',
                description: 'Classic black and white theme',
                themeKey: ThemeProvider.themeDark,
                previewColors: [
                  AppColors.black,
                  AppColors.darkGrey,
                  AppColors.white,
                ],
              ),
              const SizedBox(height: 16),
              _ThemeCard(
                title: 'Deep Blue',
                description: 'Elegant navy blue theme',
                themeKey: ThemeProvider.themeDeepBlue,
                previewColors: [
                  AppColors.deepNavy,
                  AppColors.darkBlue,
                  AppColors.accentBlue,
                ],
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String title;
  final String description;
  final String themeKey;
  final List<Color> previewColors;

  const _ThemeCard({
    required this.title,
    required this.description,
    required this.themeKey,
    required this.previewColors,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        final themeProvider = Provider.of<ThemeProvider>(
          context,
          listen: false,
        );
        themeProvider.setTheme(themeKey);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            // Color preview circles
            Row(
              children: previewColors.map((color) {
                return Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 8),
            // Text content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
            // Arrow indicator
            Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 18),
          ],
        ),
      ),
    );
  }
}
