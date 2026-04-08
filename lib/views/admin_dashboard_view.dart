import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/admin_action_card.dart';
import 'add_category_view.dart';
import 'add_collection_view.dart';
import 'add_model_image_view.dart';
import 'add_product_view.dart';
import 'view_modify_categories_view.dart';
import 'view_modify_collections_view.dart';
import 'view_modify_model_images_view.dart';
import 'view_modify_products_view.dart';

class AdminDashboardView extends StatefulWidget {
  const AdminDashboardView({super.key});

  @override
  State<AdminDashboardView> createState() => _AdminDashboardViewState();
}

class _AdminDashboardViewState extends State<AdminDashboardView> {
  int _selectedIndex = 0;

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
    if (index == 3) {
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
            _ViewModifyCategoryCard(),
            SizedBox(height: 26),
            _ViewModifyCollectionCard(),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Add Product',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            label: 'Collection',
          ),
          NavigationDestination(
            icon: Icon(Icons.image_outlined),
            label: 'Model Images',
          ),
          NavigationDestination(
            icon: Icon(Icons.logout),
            label: 'Logout',
          ),
        ],
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
                  Center(
                    child: Text(
                      'Admin Dashboard',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF001B49),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
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
      iconBackground: const Color(0xFFFDE8D8),
      iconColor: const Color(0xFFBC4C00),
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
      iconBackground: const Color(0xFFFDE8D8),
      iconColor: const Color(0xFFBC4C00),
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
