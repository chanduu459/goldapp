import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_action_card.dart';
import 'add_product_view.dart';
import 'view_modify_products_view.dart';

class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  Future<void> _signOut(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to sign out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Admin Dashboard',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF001B49),
                          ),
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final shouldSignOut = await showDialog<bool>(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Sign out?'),
                                content: const Text('Your admin session will end.'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.of(context).pop(true),
                                    child: const Text('Sign Out'),
                                  ),
                                ],
                              );
                            },
                          );

                          if (!context.mounted) {
                            return;
                          }

                          if (shouldSignOut == true) {
                            await _signOut(context);
                          }
                        },
                        tooltip: 'Sign Out',
                        icon: const Icon(Icons.logout),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const _AddProductCard(),
                  const SizedBox(height: 26),
                  const _ViewModifyProductCard(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AddProductCard extends StatelessWidget {
  const _AddProductCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'Add Product',
      subtitle: 'Create and publish a new product in your shop.',
      icon: Icons.add_circle_outline,
      iconBackground: const Color(0xFFDDF5E5),
      iconColor: const Color(0xFF17A34A),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddProductView(),
          ),
        );
      },
    );
  }
}

class _ViewModifyProductCard extends StatelessWidget {
  const _ViewModifyProductCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'View / Modify Product',
      subtitle: 'Edit and update existing product details.',
      icon: Icons.edit_outlined,
      iconBackground: const Color(0xFFDCE8FA),
      iconColor: const Color(0xFF2F6FE6),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ViewModifyProductsView(),
          ),
        );
      },
    );
  }
}
