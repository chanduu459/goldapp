import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/manage_product.dart';

class ViewModifyProductsViewModel extends ChangeNotifier {
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  bool _isDisposed = false;

  List<ManageProduct> products = const [];
  List<ManageCategoryOption> categories = const [];

  void _notifySafely() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  Future<void> loadData() async {
    if (_isDisposed) {
      return;
    }

    isLoading = true;
    errorMessage = null;
    _notifySafely();

    try {
      final categoryRows = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      categories = (categoryRows as List<dynamic>)
          .map(
            (row) => ManageCategoryOption(
              id: row['id'] as int,
              name: (row['name'] as String? ?? 'Unnamed').trim(),
            ),
          )
          .toList(growable: false);

      final productRows = await Supabase.instance.client
          .from('products')
          .select(
            'id, name, category_id, base_price, image_url, description, is_active, categories(name)',
          )
          .order('id', ascending: false);

      products = (productRows as List<dynamic>)
          .map((row) {
            final categoryData = row['categories'];
            final categoryName = categoryData is Map<String, dynamic>
                ? (categoryData['name'] as String? ?? 'Unknown')
                : 'Unknown';

            return ManageProduct(
              id: row['id'] as int,
              name: (row['name'] as String? ?? '').trim(),
              categoryId: row['category_id'] as int,
              categoryName: categoryName,
              basePrice: ((row['base_price'] as num?) ?? 0).toDouble(),
              imageUrl: (row['image_url'] as String? ?? '').trim(),
              description: (row['description'] as String? ?? '').trim(),
              isActive: row['is_active'] as bool? ?? true,
            );
          })
          .toList(growable: false);
    } on PostgrestException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Unable to load products.';
    }

    isLoading = false;
    _notifySafely();
  }

  Future<bool> updateProduct({
    required int productId,
    required String name,
    required int categoryId,
    required double basePrice,
    required String description,
    required bool isActive,
  }) async {
    if (_isDisposed || isSaving) {
      return false;
    }

    isSaving = true;
    errorMessage = null;
    _notifySafely();

    try {
      await Supabase.instance.client
          .from('products')
          .update({
            'name': name.trim(),
            'category_id': categoryId,
            'base_price': basePrice,
            'description': description.trim(),
            'is_active': isActive,
          })
          .eq('id', productId);

      isSaving = false;
      _notifySafely();
      return true;
    } on PostgrestException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Unable to update product.';
    }

    isSaving = false;
    _notifySafely();
    return false;
  }

  Future<bool> deleteProduct({required int productId}) async {
    if (_isDisposed || isSaving) {
      return false;
    }

    isSaving = true;
    errorMessage = null;
    _notifySafely();

    try {
      final client = Supabase.instance.client;

      // Delete children first to satisfy foreign key constraints.
      await client.from('product_images').delete().eq('product_id', productId);
      await client
          .from('product_variants')
          .delete()
          .eq('product_id', productId);
      await client.from('product_options').delete().eq('product_id', productId);
      await client.from('ring_sizes').delete().eq('product_id', productId);
      await client.from('product_metals').delete().eq('product_id', productId);
      await client.from('products').delete().eq('id', productId);

      await loadData();

      isSaving = false;
      _notifySafely();
      return true;
    } on PostgrestException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Unable to delete product.';
    }

    isSaving = false;
    _notifySafely();
    return false;
  }
}
