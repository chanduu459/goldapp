import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/manage_product.dart';

class ViewModifyProductsViewModel extends ChangeNotifier {
  bool isLoading = false;
  bool isSaving = false;
  String? errorMessage;
  bool _isDisposed = false;

  List<ManageProduct> products = const [];
  List<ManageCategoryOption> categories = const [];
  List<ManageCollectionOption> collections = const [];

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
      final collectionRows = await Supabase.instance.client
          .from('collections')
          .select('id, name')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      collections = (collectionRows as List<dynamic>)
          .map(
            (row) => ManageCollectionOption(
              id: row['id'] as int,
              name: (row['name'] as String? ?? 'Unnamed').trim(),
            ),
          )
          .toList(growable: false);

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
          'id, name, category_id, collection_id, base_price, original_price, image_url, hover_image_url, description, long_description, stock_quantity, is_new, is_best_seller, is_engravable, is_active, metaltype, categories(name), collections(name), product_metals(metal_type,purity), ring_sizes(size_label,size_number), product_variants(carat,diamond_type,ring_size,barcode,stock_quantity)',
          )
          .order('id', ascending: false);

      products = (productRows as List<dynamic>)
          .map((row) {
            final categoryData = row['categories'];
          final collectionData = row['collections'];
          final metalData = _firstMap(row['product_metals']);
          final ringSizeData = _firstMap(row['ring_sizes']);
          final variantData = _firstMap(row['product_variants']);

            final categoryName = categoryData is Map<String, dynamic>
                ? (categoryData['name'] as String? ?? 'Unknown')
                : 'Unknown';

          final collectionName = collectionData is Map<String, dynamic>
            ? (collectionData['name'] as String? ?? 'No Collection').trim()
            : null;

            return ManageProduct(
              id: row['id'] as int,
              name: (row['name'] as String? ?? '').trim(),
              categoryId: row['category_id'] as int,
              categoryName: categoryName,
            collectionId: row['collection_id'] as int?,
            collectionName: collectionName,
            basePrice: ((row['base_price'] as num?) ?? 0).toDouble(),
              originalPrice: ((row['original_price'] as num?) ??
                      (row['base_price'] as num?) ??
                      0)
                  .toDouble(),
              imageUrl: (row['image_url'] as String? ?? '').trim(),
            hoverImageUrl: (row['hover_image_url'] as String? ?? '').trim(),
              description: (row['description'] as String? ?? '').trim(),
            longDescription: (row['long_description'] as String? ?? '').trim(),
            stockQuantity: ((row['stock_quantity'] as num?) ??
                (variantData?['stock_quantity'] as num?) ??
                0)
              .toInt(),
            isNew: row['is_new'] as bool? ?? false,
            isBestSeller: row['is_best_seller'] as bool? ?? false,
            isEngravable: row['is_engravable'] as bool? ?? false,
              isActive: row['is_active'] as bool? ?? true,
            metalType:
              ((row['metaltype'] as String?) ??
                  (metalData?['metal_type'] as String?) ??
                  'Gold')
                .trim(),
            purity: (metalData?['purity'] as String? ?? '').trim(),
            ringSize: ((ringSizeData?['size_label'] as String?) ??
                (variantData?['ring_size'] as String?) ??
                '')
              .trim(),
            caratWeight:
              ((variantData?['carat'] as num?) ?? 0).toDouble(),
            diamondType:
              (variantData?['diamond_type'] as String? ?? 'None').trim(),
            stockNumber:
              (variantData?['barcode'] as String? ?? '').trim(),
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

  Map<String, dynamic>? _firstMap(dynamic value) {
    if (value is List && value.isNotEmpty && value.first is Map<String, dynamic>) {
      return value.first as Map<String, dynamic>;
    }
    return null;
  }

  String get _productBucket {
    final configuredBucket = dotenv.env['SUPABASE_PRODUCT_BUCKET']?.trim();
    if (configuredBucket != null && configuredBucket.isNotEmpty) {
      return configuredBucket;
    }
    return 'goldJEWELLERY';
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  Future<String> _uploadImageToStorage({
    required Uint8List bytes,
    required String originalName,
    required String productName,
    required String imageType,
  }) async {
    final extParts = originalName.split('.');
    final extension = extParts.length > 1 ? extParts.last.toLowerCase() : 'jpg';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$ts-${_slugify(productName)}-$imageType.$extension';
    final filePath = 'products/$fileName';

    await Supabase.instance.client.storage.from(_productBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return Supabase.instance.client.storage.from(_productBucket).getPublicUrl(filePath);
  }

  String? _extractStoragePath(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      return null;
    }

    final bucketIndex = uri.pathSegments.indexOf(_productBucket);
    if (bucketIndex < 0 || bucketIndex >= uri.pathSegments.length - 1) {
      return null;
    }

    return uri.pathSegments.skip(bucketIndex + 1).join('/');
  }

  Future<void> _deleteUploadedImage(String? imageUrl) async {
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }

    final path = _extractStoragePath(imageUrl);
    if (path == null || path.isEmpty) {
      return;
    }

    try {
      await Supabase.instance.client.storage.from(_productBucket).remove([path]);
    } catch (_) {
      // Best effort cleanup.
    }
  }

  Future<bool> updateProduct({
    required int productId,
    required String name,
    required int categoryId,
    required int? collectionId,
    required double basePrice,
    required double originalPrice,
    required int stockQuantity,
    required String imageUrl,
    required String hoverImageUrl,
    required String description,
    required String longDescription,
    required bool isNew,
    required bool isBestSeller,
    required bool isEngravable,
    required String metalType,
    required String purity,
    required String ringSize,
    required double caratWeight,
    required String diamondType,
    required String stockNumber,
    required bool isActive,
    Uint8List? newPrimaryImageBytes,
    String? newPrimaryImageName,
    Uint8List? newHoverImageBytes,
    String? newHoverImageName,
    bool notifyUi = true,
  }) async {
    if (_isDisposed || isSaving) {
      return false;
    }

    errorMessage = null;
    if (notifyUi) {
      isSaving = true;
      _notifySafely();
    }

    String resolvedImageUrl = imageUrl.trim();
    String resolvedHoverImageUrl = hoverImageUrl.trim();
    String? uploadedPrimaryImageUrl;
    String? uploadedHoverImageUrl;

    try {
      final client = Supabase.instance.client;
      final normalizedMetalType = metalType.trim().isEmpty ? 'Gold' : metalType.trim();
      final normalizedDiamondType =
          diamondType.trim().isEmpty ? 'None' : diamondType.trim();

      if (newPrimaryImageBytes != null &&
          newPrimaryImageName != null &&
          newPrimaryImageName.trim().isNotEmpty) {
        uploadedPrimaryImageUrl = await _uploadImageToStorage(
          bytes: newPrimaryImageBytes,
          originalName: newPrimaryImageName,
          productName: name,
          imageType: 'main',
        );
        resolvedImageUrl = uploadedPrimaryImageUrl;
      }

      if (newHoverImageBytes != null &&
          newHoverImageName != null &&
          newHoverImageName.trim().isNotEmpty) {
        uploadedHoverImageUrl = await _uploadImageToStorage(
          bytes: newHoverImageBytes,
          originalName: newHoverImageName,
          productName: name,
          imageType: 'hover',
        );
        resolvedHoverImageUrl = uploadedHoverImageUrl;
      }

      await Supabase.instance.client
          .from('products')
          .update({
            'name': name.trim(),
            'category_id': categoryId,
            'collection_id': collectionId,
            'base_price': basePrice,
            'original_price': originalPrice,
            'metaltype': normalizedMetalType,
            'stock_quantity': stockQuantity,
            'image_url': resolvedImageUrl.isEmpty ? null : resolvedImageUrl,
            'hover_image_url':
              resolvedHoverImageUrl.isEmpty ? null : resolvedHoverImageUrl,
            'description': description.trim(),
            'long_description': longDescription.trim().isEmpty
                ? description.trim()
                : longDescription.trim(),
            'is_new': isNew,
            'is_best_seller': isBestSeller,
            'is_engravable': isEngravable,
            'is_active': isActive,
          })
          .eq('id', productId);

      await _upsertProductMetal(
        client: client,
        productId: productId,
        metalType: normalizedMetalType,
        purity: purity,
      );

      await _upsertRingSize(
        client: client,
        productId: productId,
        ringSize: ringSize,
      );

      await _upsertVariant(
        client: client,
        productId: productId,
        metalType: normalizedMetalType,
        caratWeight: caratWeight,
        diamondType: normalizedDiamondType,
        ringSize: ringSize,
        stockQuantity: stockQuantity,
        stockNumber: stockNumber,
        isActive: isActive,
      );

      await _upsertProductOption(
        client: client,
        productId: productId,
        optionType: 'metal',
        optionName: 'Metal Type',
        optionValue: normalizedMetalType,
        sortOrder: 1,
      );

      if (normalizedDiamondType.toLowerCase() == 'none') {
        await client
            .from('product_options')
            .delete()
            .eq('product_id', productId)
            .eq('option_type', 'diamond_type');
      } else {
        await _upsertProductOption(
          client: client,
          productId: productId,
          optionType: 'diamond_type',
          optionName: 'Diamond Type',
          optionValue: normalizedDiamondType,
          sortOrder: 2,
        );
      }

      if (uploadedPrimaryImageUrl != null &&
          imageUrl.trim().isNotEmpty &&
          imageUrl.trim() != uploadedPrimaryImageUrl) {
        await _deleteUploadedImage(imageUrl.trim());
      }

      if (uploadedHoverImageUrl != null &&
          hoverImageUrl.trim().isNotEmpty &&
          hoverImageUrl.trim() != uploadedHoverImageUrl) {
        await _deleteUploadedImage(hoverImageUrl.trim());
      }

      if (notifyUi) {
        isSaving = false;
        _notifySafely();
      }
      return true;
    } on PostgrestException catch (e) {
      await _deleteUploadedImage(uploadedPrimaryImageUrl);
      await _deleteUploadedImage(uploadedHoverImageUrl);
      errorMessage = e.message;
    } catch (_) {
      await _deleteUploadedImage(uploadedPrimaryImageUrl);
      await _deleteUploadedImage(uploadedHoverImageUrl);
      errorMessage = 'Unable to update product.';
    }

    if (notifyUi) {
      isSaving = false;
      _notifySafely();
    }
    return false;
  }

  Future<void> _upsertProductMetal({
    required SupabaseClient client,
    required int productId,
    required String metalType,
    required String purity,
  }) async {
    final rows = await client
        .from('product_metals')
        .select('id')
        .eq('product_id', productId)
        .limit(1);

    final normalizedPurity = purity.trim().isEmpty ? '22K' : purity.trim();

    if ((rows as List<dynamic>).isEmpty) {
      await client.from('product_metals').insert({
        'product_id': productId,
        'metal_type': metalType,
        'purity': normalizedPurity,
        'is_available': true,
      });
      return;
    }

    final id = rows.first['id'] as int;
    await client.from('product_metals').update({
      'metal_type': metalType,
      'purity': normalizedPurity,
      'is_available': true,
    }).eq('id', id);
  }

  Future<void> _upsertRingSize({
    required SupabaseClient client,
    required int productId,
    required String ringSize,
  }) async {
    final rows = await client
        .from('ring_sizes')
        .select('id')
        .eq('product_id', productId)
        .limit(1);

    final normalizedRingSize = ringSize.trim().isEmpty ? 'N/A' : ringSize.trim();

    if ((rows as List<dynamic>).isEmpty) {
      await client.from('ring_sizes').insert({
        'product_id': productId,
        'size_label': normalizedRingSize,
        'size_number': double.tryParse(normalizedRingSize),
        'is_available': true,
      });
      return;
    }

    final id = rows.first['id'] as int;
    await client.from('ring_sizes').update({
      'size_label': normalizedRingSize,
      'size_number': double.tryParse(normalizedRingSize),
      'is_available': true,
    }).eq('id', id);
  }

  Future<void> _upsertVariant({
    required SupabaseClient client,
    required int productId,
    required String metalType,
    required double caratWeight,
    required String diamondType,
    required String ringSize,
    required int stockQuantity,
    required String stockNumber,
    required bool isActive,
  }) async {
    final rows = await client
        .from('product_variants')
        .select('id, sku')
        .eq('product_id', productId)
        .limit(1);

    final normalizedRingSize = ringSize.trim().isEmpty ? 'N/A' : ringSize.trim();
    final normalizedStockNumber =
        stockNumber.trim().isEmpty ? 'N/A' : stockNumber.trim();

    if ((rows as List<dynamic>).isEmpty) {
      await client.from('product_variants').insert({
        'product_id': productId,
        'sku': '$productId-V1',
        'metal': metalType,
        'carat': caratWeight,
        'diamond_type': diamondType,
        'ring_size': normalizedRingSize,
        'stock_quantity': stockQuantity,
        'barcode': normalizedStockNumber,
        'is_active': isActive,
      });
      return;
    }

    final id = rows.first['id'] as int;
    await client.from('product_variants').update({
      'metal': metalType,
      'carat': caratWeight,
      'diamond_type': diamondType,
      'ring_size': normalizedRingSize,
      'stock_quantity': stockQuantity,
      'barcode': normalizedStockNumber,
      'is_active': isActive,
    }).eq('id', id);
  }

  Future<void> _upsertProductOption({
    required SupabaseClient client,
    required int productId,
    required String optionType,
    required String optionName,
    required String optionValue,
    required int sortOrder,
  }) async {
    final rows = await client
        .from('product_options')
        .select('id')
        .eq('product_id', productId)
        .eq('option_type', optionType)
        .limit(1);

    if ((rows as List<dynamic>).isEmpty) {
      await client.from('product_options').insert({
        'product_id': productId,
        'option_type': optionType,
        'option_name': optionName,
        'option_value': optionValue,
        'is_available': true,
        'sort_order': sortOrder,
      });
      return;
    }

    final id = rows.first['id'] as int;
    await client.from('product_options').update({
      'option_name': optionName,
      'option_value': optionValue,
      'is_available': true,
      'sort_order': sortOrder,
    }).eq('id', id);
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
