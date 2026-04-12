import 'package:flutter/material.dart';

class AdminActionCard extends StatelessWidget {
  const AdminActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cardGradientStart = Color.lerp(iconBackground, Colors.white, 0.42)!;
    final cardGradientEnd = Color.lerp(iconBackground, Colors.white, 0.9)!;
    final borderColor = Color.lerp(iconColor, Colors.white, 0.7)!;
    final actionColor = Color.lerp(iconColor, const Color(0xFF021B44), 0.28)!;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
        highlightColor: theme.colorScheme.primary.withValues(alpha: 0.06),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cardGradientStart, cardGradientEnd],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.08),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Color(0x140A2A43),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -18,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconBackground.withValues(alpha: 0.35),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: iconColor, size: 34),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF021B44),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      color: const Color(0xFF5D6A83),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(
                        'Tap to open',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: actionColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 18,
                        color: actionColor,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
