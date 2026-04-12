import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_action_card.dart';
import 'add_category_view.dart';
import 'add_collection_view.dart';
import 'add_metal_price_view.dart';
import 'add_metal_view.dart';
import 'add_model_image_view.dart';
import 'add_product_view.dart';
import 'view_modify_categories_view.dart';
import 'view_modify_collections_view.dart';
import 'view_modify_metal_prices_view.dart';
import 'view_modify_metals_view.dart';
import 'view_modify_model_images_view.dart';
import 'view_modify_products_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int _selectedIndex = 0;

  // String _activeSectionLabel() {
  //   switch (_selectedIndex) {
  //     case 0:
  //       return 'Products';
  //     case 1:
  //       return 'Collections';
  //     case 2:
  //       return 'Model Images';
  //     default:
  //       return 'Products';
  //   }
  // }

  Color _activeSectionColor() {
    switch (_selectedIndex) {
      case 0:
        return const Color(0xFF17A34A);
      case 1:
        return const Color(0xFFB57A00);
      case 2:
        return const Color(0xFF2F6FE6);
      case 3:
        return const Color(0xFF0F766E);
      default:
        return const Color(0xFF17A34A);
    }
  }

  String _sectionSubtitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Manage product creation and product updates.';
      case 1:
        return 'Handle collections and categories from one place.';
      case 2:
        return 'Upload and maintain model image entries.';
      case 3:
        return 'Manage metals and maintain metal pricing details.';
      default:
        return 'Manage your admin actions.';
    }
  }

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

  Future<void> _showSignOutDialog() async {
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

    if (!mounted) {
      return;
    }

    if (shouldSignOut == true) {
      await _signOut(context);
    }
  }

  void _onDestinationSelected(int index) {
    if (index == 4) {
      _showSignOutDialog();
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _activeCard() {
    switch (_selectedIndex) {
      case 0:
        return const Column(
          key: ValueKey<String>('product-options'),
          children: [
            _AddProductCard(),
            SizedBox(height: 26),
            _ViewModifyProductCard(),
          ],
        );
      case 1:
        return const Column(
          key: ValueKey<String>('collection-options'),
          children: [
            _AddCollectionCard(),
            SizedBox(height: 26),
            _AddCategoryCard(),
            SizedBox(height: 26),
            _ViewModifyCollectionCard(),
            SizedBox(height: 26),
            _ViewModifyCategoryCard(),
          ],
        );
      case 2:
        return const Column(
          key: ValueKey<String>('model-image-options'),
          children: [
            _AddModelImageCard(),
            SizedBox(height: 26),
            _ViewModifyModelImageCard(),
          ],
        );
      case 3:
        return const Column(
          key: ValueKey<String>('price-options'),
          children: [
            _AddMetalCard(),
            SizedBox(height: 26),
            _AddMetalPriceCard(),
            SizedBox(height: 26),
            _ViewModifyMetalCard(),
            SizedBox(height: 26),
            _ViewModifyMetalPriceCard(),
          ],
        );
      default:
        return const Column(
          key: ValueKey<String>('product-options-fallback'),
          children: [
            _AddProductCard(),
            SizedBox(height: 26),
            _ViewModifyProductCard(),
          ],
        );
    }
  }

  Widget _buildDashboardHeader(ThemeData theme) {
    final accent = _activeSectionColor();
    // final titleSize = MediaQuery.sizeOf(context).width < 380 ? 52.0 : 56.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -10,
          right: 0,
          child: Container(
            width: 116,
            height: 116,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0x44F2D391), Color(0x11F2D391)],
              ),
            ),
          ),
        ),
        Positioned(
          top: 58,
          left: -14,
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF2D2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.shield_moon_outlined,
                    color: Color(0xFF9A6A00),
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Admin',
                  style: theme.textTheme.titleMedium?.copyWith(
                    letterSpacing: 0.4,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF6A748C),
                  ),
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'View / Modify Metal Prices',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ViewModifyMetalPricesView(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.currency_rupee_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Text(
            //   'Dashboard',
            //   style: theme.textTheme.headlineMedium?.copyWith(
            //     fontSize: titleSize,
            //     fontWeight: FontWeight.w800,
            //     letterSpacing: -1.1,
            //     height: 0.96,
            //     color: const Color(0xFF001B49),
            //   ),
            // ),
            const SizedBox(height: 12),
            Text(
              _sectionSubtitle(),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF5D6A83),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.34),
                    const Color(0x00FFFFFF),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: _onDestinationSelected,
            elevation: 2,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF244C9D),
            unselectedItemColor: const Color(0xFF8A95A8),
            selectedFontSize: 12,
            unselectedFontSize: 12,
            iconSize: 22,
            showUnselectedLabels: true,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.add_circle_outline),
                activeIcon: Icon(Icons.add_circle),
                label: 'Product',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.collections_bookmark_outlined),
                activeIcon: Icon(Icons.collections_bookmark),
                label: 'Collection',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.image_outlined),
                activeIcon: Icon(Icons.image),
                label: 'Images',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.price_change_outlined),
                activeIcon: Icon(Icons.price_change),
                label: 'Price',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.logout_outlined),
                activeIcon: Icon(Icons.logout),
                label: 'Logout',
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDashboardHeader(theme),
                  const SizedBox(height: 26),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey<int>(_selectedIndex),
                      child: _activeCard(),
                    ),
                  ),
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

class _AddCollectionCard extends StatelessWidget {
  const _AddCollectionCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'Add Collection',
      subtitle: 'Create a collection that you can assign to products.',
      icon: Icons.collections_bookmark_outlined,
      iconBackground: const Color(0xFFFFF1D6),
      iconColor: const Color(0xFFCC8A00),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddCollectionView(),
          ),
        );
      },
    );
  }
}

class _ViewModifyCollectionCard extends StatelessWidget {
  const _ViewModifyCollectionCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'View / Modify Collection',
      subtitle: 'Edit and update existing collection details.',
      icon: Icons.edit_note_outlined,
      iconBackground: const Color(0xFFFFF1D6),
      iconColor: const Color(0xFFCC8A00),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ViewModifyCollectionsView(),
          ),
        );
      },
    );
  }
}

class _ViewModifyCategoryCard extends StatelessWidget {
  const _ViewModifyCategoryCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'View / Modify Category',
      subtitle: 'Edit and update existing category details.',
      icon: Icons.edit_note_outlined,
      iconBackground: const Color(0xFFDDF5E5),
      iconColor: const Color(0xFF1A8F5A),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ViewModifyCategoriesView(),
          ),
        );
      },
    );
  }
}

class _AddCategoryCard extends StatelessWidget {
  const _AddCategoryCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'Add Category',
      subtitle: 'Create product categories that appear in Add Product.',
      icon: Icons.category_outlined,
      iconBackground: const Color(0xFFDDF5E5),
      iconColor: const Color(0xFF1A8F5A),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddCategoryView(),
          ),
        );
      },
    );
  }
}

class _AddModelImageCard extends StatelessWidget {
  const _AddModelImageCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'Add Model Images',
      subtitle: 'Create model image entries with title and category.',
      icon: Icons.image_outlined,
      iconBackground: const Color(0xFFE9E4FF),
      iconColor: const Color(0xFF5A38D6),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddModelImageView(),
          ),
        );
      },
    );
  }
}

class _ViewModifyModelImageCard extends StatelessWidget {
  const _ViewModifyModelImageCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'View / Modify Model Images',
      subtitle: 'Edit and update existing model image details.',
      icon: Icons.photo_library_outlined,
      iconBackground: const Color(0xFFE5F0FF),
      iconColor: const Color(0xFF1E63D6),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ViewModifyModelImagesView(),
          ),
        );
      },
    );
  }
}

class _AddMetalCard extends StatelessWidget {
  const _AddMetalCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'Add Metal',
      subtitle: 'Create a new metal type used in product pricing.',
      icon: Icons.hardware_outlined,
      iconBackground: const Color(0xFFE0F6F3),
      iconColor: const Color(0xFF0F766E),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddMetalView(),
          ),
        );
      },
    );
  }
}

class _AddMetalPriceCard extends StatelessWidget {
  const _AddMetalPriceCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'Add Metal Price',
      subtitle: 'Add a fresh price entry for a metal type.',
      icon: Icons.currency_rupee_outlined,
      iconBackground: const Color(0xFFE7F4FF),
      iconColor: const Color(0xFF1F63C8),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const AddMetalPriceView(),
          ),
        );
      },
    );
  }
}

class _ViewModifyMetalCard extends StatelessWidget {
  const _ViewModifyMetalCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'View / Update Metal',
      subtitle: 'Review and edit existing metal records.',
      icon: Icons.edit_note_outlined,
      iconBackground: const Color(0xFFFFF1D6),
      iconColor: const Color(0xFFB57A00),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ViewModifyMetalsView(),
          ),
        );
      },
    );
  }
}

class _ViewModifyMetalPriceCard extends StatelessWidget {
  const _ViewModifyMetalPriceCard();

  @override
  Widget build(BuildContext context) {
    return AdminActionCard(
      title: 'View / Modify Metal Prices',
      subtitle: 'Update or remove existing metal price entries.',
      icon: Icons.price_change_outlined,
      iconBackground: const Color(0xFFE9E4FF),
      iconColor: const Color(0xFF5A38D6),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const ViewModifyMetalPricesView(),
          ),
        );
      },
    );
  }
}
