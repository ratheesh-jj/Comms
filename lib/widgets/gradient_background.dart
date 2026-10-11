import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/theme_provider.dart';

/// A widget that provides a gradient background based on the current theme.
/// Wrap your screen's body content with this widget to get the gradient effect.
class GradientBackground extends StatelessWidget {
  final Widget child;

  const GradientBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: themeProvider.currentGradient),
      child: child,
    );
  }
}
