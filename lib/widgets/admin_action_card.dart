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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE6E7EB)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
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
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 40 / 2,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF021B44),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 32 / 2,
                  color: Color(0xFF5D6A83),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
