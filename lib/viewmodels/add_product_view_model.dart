import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/gold_ornament_product.dart';

class CategoryOption {
  const CategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}

class CollectionOption {
  const CollectionOption({required this.id, required this.name});

  final int id;
  final String name;
}

enum ProductImageType { primary, hover }

class AddProductViewModel extends ChangeNotifier {
  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final weightController = TextEditingController();
  final purityController = TextEditingController();
  final basePriceController = TextEditingController();
  final originalPriceController = TextEditingController();
  final stockQuantityController = TextEditingController(text: '0');
  final makingChargeController = TextEditingController();
  final ringSizeController = TextEditingController();
  final caratWeightController = TextEditingController();
  final stockNumberController = TextEditingController();
  final widthController = TextEditingController();
  final descriptionController = TextEditingController();
  final longDescriptionController = TextEditingController();
  final collectionController = TextEditingController();

  bool isSubmitting = false;
  bool isLoadingReferenceData = false;
  String? errorMessage;

  Uint8List? selectedPrimaryImageBytes;
  String? selectedPrimaryImageName;
  Uint8List? selectedHoverImageBytes;
  String? selectedHoverImageName;

  List<CategoryOption> categories = const [];
  List<CollectionOption> collections = const [];
  int? selectedCategoryId;
  int? selectedCollectionId;

  bool isNew = false;
  bool isBestSeller = false;
  bool isEngravable = false;
  bool isActive = true;
  bool rhodiumFinish = false;
  String selectedMetalType = 'Gold';
  String selectedDiamondType = 'Natural';

  Future<void> loadReferenceData() async {
    isLoadingReferenceData = true;
    errorMessage = null;
    notifyListeners();

    try {
      final categoryRows = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      categories = (categoryRows as List<dynamic>)
          .map((row) => CategoryOption(
                id: row['id'] as int,
                name: ((row['name'] as String?) ?? 'Unnamed').trim(),
              ))
          .toList(growable: false);

      final collectionRows = await Supabase.instance.client
          .from('collections')
          .select('id, name')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      collections = (collectionRows as List<dynamic>)
          .map((row) => CollectionOption(
                id: row['id'] as int,
                name: ((row['name'] as String?) ?? 'Unnamed').trim(),
              ))
          .toList(growable: false);

      if (categories.isNotEmpty) {
        selectedCategoryId ??= categories.first.id;
      }

      if (categories.isEmpty) {
        errorMessage = 'No categories found. Create categories first.';
      }
    } catch (_) {
      errorMessage = 'Unable to load categories/collections.';
    }

    isLoadingReferenceData = false;
    notifyListeners();
  }

  void setSelectedCategory(int? value) {
    selectedCategoryId = value;
    notifyListeners();
  }

  void setSelectedCollection(int? value) {
    selectedCollectionId = value;
    if (value != null) {
      final match = collections.where((item) => item.id == value);
      if (match.isNotEmpty) {
        collectionController.text = match.first.name;
      }
    }
    notifyListeners();
  }

  void setCollectionName(String value) {
    collectionController.text = value;

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      notifyListeners();
      return;
    }

    final existing = collections.where(
      (item) => item.name.trim().toLowerCase() == normalized,
    );

    if (existing.isNotEmpty) {
      selectedCollectionId = existing.first.id;
    }

    notifyListeners();
  }

  Future<int?> _resolveCollectionId() async {
    final text = collectionController.text.trim();
    if (text.isEmpty) {
      return selectedCollectionId;
    }

    final existing = collections.where(
      (item) => item.name.trim().toLowerCase() == text.toLowerCase(),
    );
    if (existing.isNotEmpty) {
      return existing.first.id;
    }

    final inserted = await Supabase.instance.client
        .from('collections')
        .insert({'name': text})
        .select('id, name')
        .single();

    final created = CollectionOption(
      id: inserted['id'] as int,
      name: ((inserted['name'] as String?) ?? text).trim(),
    );

    collections = [...collections, created]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    selectedCollectionId = created.id;
    collectionController.text = created.name;
    notifyListeners();
    return created.id;
  }

  void setIsNew(bool value) {
    isNew = value;
    notifyListeners();
  }

  void setIsBestSeller(bool value) {
    isBestSeller = value;
    notifyListeners();
  }

  void setIsEngravable(bool value) {
    isEngravable = value;
    notifyListeners();
  }

  void setIsActive(bool value) {
    isActive = value;
    notifyListeners();
  }

  void setRhodiumFinish(bool value) {
    rhodiumFinish = value;
    notifyListeners();
  }

  void setSelectedMetalType(String? value) {
    if (value == null) {
      return;
    }
    selectedMetalType = value;
    notifyListeners();
  }

  void setSelectedDiamondType(String? value) {
    if (value == null) {
      return;
    }
    selectedDiamondType = value;
    notifyListeners();
  }

  void setSelectedImage({
    required ProductImageType type,
    required Uint8List bytes,
    required String name,
  }) {
    errorMessage = null;
    if (type == ProductImageType.primary) {
      selectedPrimaryImageBytes = bytes;
      selectedPrimaryImageName = name;
    } else {
      selectedHoverImageBytes = bytes;
      selectedHoverImageName = name;
    }
    notifyListeners();
  }

  void clearSelectedImage(ProductImageType type) {
    if (type == ProductImageType.primary) {
      selectedPrimaryImageBytes = null;
      selectedPrimaryImageName = null;
    } else {
      selectedHoverImageBytes = null;
      selectedHoverImageName = null;
    }
    notifyListeners();
  }

  Future<void> pickImage(ProductImageType type) async {
    errorMessage = null;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      errorMessage = 'Could not read selected image.';
      notifyListeners();
      return;
    }

    setSelectedImage(type: type, bytes: bytes, name: file.name);
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\\s-]'), '')
        .replaceAll(RegExp(r'\\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  String _buildSku(String name) {
    final normalized = name
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .padRight(6, 'X')
        .substring(0, 6);
    final ts = DateTime.now().millisecondsSinceEpoch;
    return 'GLD-$normalized-$ts';
  }

  String? validateRequired(String? value, String fieldName) {
    if ((value ?? '').trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  String? validatePositiveNumber(String? value, String fieldName) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '$fieldName is required';
    }
    final number = double.tryParse(text);
    if (number == null || number <= 0) {
      return 'Enter a valid $fieldName';
    }
    return null;
  }

  String? validateOptionalPositiveNumber(String? value, String fieldName) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    final number = double.tryParse(text);
    if (number == null || number <= 0) {
      return 'Enter a valid $fieldName';
    }
    return null;
  }

  String? validateNonNegativeInt(String? value, String fieldName) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return '$fieldName is required';
    }
    final number = int.tryParse(text);
    if (number == null || number < 0) {
      return '$fieldName must be 0 or greater';
    }
    return null;
  }

  String? validatePurity(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) {
      return 'Purity (Karat) is required';
    }
    final karat = int.tryParse(text);
    if (karat == null || karat < 8 || karat > 24) {
      return 'Purity must be between 8K and 24K';
    }
    return null;
  }

  String? validateSelectedCategory(int? value) {
    if (value == null) {
      return 'Category is required';
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

  Future<String> _uploadImageToStorage({
    required ProductImageType type,
    required String productName,
  }) async {
    final bytes = type == ProductImageType.primary
        ? selectedPrimaryImageBytes
        : selectedHoverImageBytes;
    final originalName = type == ProductImageType.primary
        ? selectedPrimaryImageName
        : selectedHoverImageName;

    if (bytes == null || originalName == null) {
      throw StateError(
        type == ProductImageType.primary
            ? 'Please select the main image before saving product.'
            : 'Please select the hover image before saving product.',
      );
    }

    final bucket = _productBucket;

    final extParts = originalName.split('.');
    final extension = extParts.length > 1 ? extParts.last.toLowerCase() : 'jpg';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final imageType = type == ProductImageType.primary ? 'main' : 'hover';
    final fileName = '$ts-${_slugify(productName)}-$imageType.$extension';
    final filePath = 'products/$fileName';

    await Supabase.instance.client.storage.from(bucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return Supabase.instance.client.storage.from(bucket).getPublicUrl(filePath);
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

    await Supabase.instance.client.storage.from(_productBucket).remove([path]);
  }

  Future<void> _rollbackProductData(int productId) async {
    final client = Supabase.instance.client;
    await client.from('product_images').delete().eq('product_id', productId);
    await client.from('product_variants').delete().eq('product_id', productId);
    await client.from('product_options').delete().eq('product_id', productId);
    await client.from('ring_sizes').delete().eq('product_id', productId);
    await client.from('product_metals').delete().eq('product_id', productId);
    await client.from('products').delete().eq('id', productId);
  }

  GoldOrnamentProduct buildProduct() {
    final categoryId = selectedCategoryId;
    if (categoryId == null) {
      throw StateError('Please select a category.');
    }

    return GoldOrnamentProduct(
      productId: -1,
      name: nameController.text.trim(),
      categoryId: categoryId,
      collectionId: selectedCollectionId,
      weightInGrams: double.parse(weightController.text.trim()),
      purityKarat: int.parse(purityController.text.trim()),
      basePrice: double.parse(basePriceController.text.trim()),
      originalPrice: originalPriceController.text.trim().isEmpty
          ? null
          : double.parse(originalPriceController.text.trim()),
      stockQuantity: int.parse(stockQuantityController.text.trim()),
      makingCharge: double.parse(makingChargeController.text.trim()),
      imageUrl: '',
      hoverImageUrl: '',
      description: descriptionController.text.trim(),
      longDescription: longDescriptionController.text.trim(),
      isNew: isNew,
      isBestSeller: isBestSeller,
      isEngravable: isEngravable,
      isActive: isActive,
        metaTitle: null,
        metaDescription: null,
        metaKeywords: null,
        metalType: selectedMetalType,
        ringSize: ringSizeController.text.trim(),
        caratWeight: double.parse(caratWeightController.text.trim()),
        diamondType: selectedDiamondType,
        stockNumber: stockNumberController.text.trim(),
        widthMm: double.parse(widthController.text.trim()),
        rhodiumFinish: rhodiumFinish,
    );
  }

  Future<GoldOrnamentProduct?> submit() async {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid || isSubmitting) {
      if (!isValid) {
        errorMessage = 'Please complete all required fields correctly.';
        notifyListeners();
      }
      return null;
    }

    if (selectedPrimaryImageBytes == null || selectedPrimaryImageName == null) {
      errorMessage = 'Main image is required';
      notifyListeners();
      return null;
    }

    if (selectedHoverImageBytes == null || selectedHoverImageName == null) {
      errorMessage = 'Hover image is required';
      notifyListeners();
      return null;
    }

    if (selectedCategoryId == null) {
      errorMessage = 'Please choose a valid category.';
      notifyListeners();
      return null;
    }

    try {
      selectedCollectionId = await _resolveCollectionId();
    } on PostgrestException catch (e) {
      errorMessage =
          'Unable to create collection. Please verify permissions and try again. ${e.message}';
      notifyListeners();
      return null;
    } catch (_) {
      errorMessage = 'Unable to create collection. Please try again.';
      notifyListeners();
      return null;
    }

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    int? createdProductId;
    String? uploadedPrimaryImageUrl;
    String? uploadedHoverImageUrl;

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        errorMessage = 'You must be signed in to add products.';
        isSubmitting = false;
        notifyListeners();
        return null;
      }

      final draft = buildProduct();
      final slug = '${_slugify(draft.name)}-${DateTime.now().millisecondsSinceEpoch}';
      final sku = _buildSku(draft.name);
      final imageUrl = await _uploadImageToStorage(
        type: ProductImageType.primary,
        productName: draft.name,
      );
      uploadedPrimaryImageUrl = imageUrl;
      final hoverImageUrl = await _uploadImageToStorage(
        type: ProductImageType.hover,
        productName: draft.name,
      );
      uploadedHoverImageUrl = hoverImageUrl;

      final formattedLongDescription =
          '${draft.longDescription.isEmpty ? draft.description : draft.longDescription}\nWeight: ${draft.weightInGrams}g, Purity: ${draft.purityKarat}K, Making Charge: ${draft.makingCharge}, Metal: ${draft.metalType}, Ring Size: ${draft.ringSize}, Carat: ${draft.caratWeight}, Width: ${draft.widthMm}mm, Rhodium Finish: ${draft.rhodiumFinish ? 'Yes' : 'No'}, Stock Number: ${draft.stockNumber}, Diamond Type: ${draft.diamondType}';

      final inserted = await Supabase.instance.client
          .from('products')
          .insert({
            'name': draft.name,
            'slug': slug,
            'sku': sku,
            'category_id': draft.categoryId,
            'collection_id': draft.collectionId,
            'description': draft.description,
            'long_description': formattedLongDescription,
            'base_price': draft.basePrice,
            'original_price': draft.originalPrice,
            'image_url': imageUrl,
            'hover_image_url': hoverImageUrl,
            'stock_quantity': draft.stockQuantity,
            'is_new': draft.isNew,
            'is_best_seller': draft.isBestSeller,
            'is_engravable': draft.isEngravable,
            'is_active': draft.isActive,
          })
          .select('id')
          .single();

      final productId = inserted['id'] as int;
      createdProductId = productId;

      await Supabase.instance.client.from('product_metals').insert({
        'product_id': productId,
        'metal_type': draft.metalType,
        'purity': '${draft.purityKarat}K',
        'is_available': true,
      });

      await Supabase.instance.client.from('ring_sizes').insert({
        'product_id': productId,
        'size_label': draft.ringSize,
        'size_number': double.tryParse(draft.ringSize),
        'is_available': true,
      });

      await Supabase.instance.client.from('product_options').insert([
        {
          'product_id': productId,
          'option_type': 'metal',
          'option_name': 'Metal Type',
          'option_value': draft.metalType,
          'is_available': true,
          'sort_order': 1,
        },
        {
          'product_id': productId,
          'option_type': 'diamond_type',
          'option_name': 'Diamond Type',
          'option_value': draft.diamondType,
          'is_available': true,
          'sort_order': 2,
        },
        {
          'product_id': productId,
          'option_type': 'carat',
          'option_name': 'Total Carat Weight',
          'option_value': draft.caratWeight.toString(),
          'is_available': true,
          'sort_order': 3,
        },
        {
          'product_id': productId,
          'option_type': 'size',
          'option_name': 'Ring Size',
          'option_value': draft.ringSize,
          'is_available': true,
          'sort_order': 4,
        },
      ]);

      await Supabase.instance.client.from('product_variants').insert({
        'product_id': productId,
        'sku': '$sku-V1',
        'metal': draft.metalType,
        'carat': draft.caratWeight,
        'diamond_type': draft.diamondType,
        'ring_size': draft.ringSize,
        'stock_quantity': draft.stockQuantity,
        'barcode': draft.stockNumber,
        'is_active': draft.isActive,
      });

      await Supabase.instance.client.from('product_images').insert([
        {
          'product_id': productId,
          'image_url': imageUrl,
          'alt_text': '${draft.name} main image',
          'sort_order': 1,
        },
        {
          'product_id': productId,
          'image_url': hoverImageUrl,
          'alt_text': '${draft.name} hover image',
          'sort_order': 2,
        }
      ]);

      final product = GoldOrnamentProduct(
        productId: productId,
        name: draft.name,
        categoryId: draft.categoryId,
        collectionId: draft.collectionId,
        weightInGrams: draft.weightInGrams,
        purityKarat: draft.purityKarat,
        basePrice: draft.basePrice,
        originalPrice: draft.originalPrice,
        stockQuantity: draft.stockQuantity,
        makingCharge: draft.makingCharge,
        imageUrl: imageUrl,
        hoverImageUrl: hoverImageUrl,
        description: draft.description,
        longDescription: draft.longDescription,
        isNew: draft.isNew,
        isBestSeller: draft.isBestSeller,
        isEngravable: draft.isEngravable,
        isActive: draft.isActive,
        metaTitle: draft.metaTitle,
        metaDescription: draft.metaDescription,
        metaKeywords: draft.metaKeywords,
        metalType: draft.metalType,
        ringSize: draft.ringSize,
        caratWeight: draft.caratWeight,
        diamondType: draft.diamondType,
        stockNumber: draft.stockNumber,
        widthMm: draft.widthMm,
        rhodiumFinish: draft.rhodiumFinish,
      );

      isSubmitting = false;
      notifyListeners();
      return product;
    } on PostgrestException catch (e) {
      try {
        if (createdProductId != null) {
          await _rollbackProductData(createdProductId);
        }
        await _deleteUploadedImage(uploadedPrimaryImageUrl);
        await _deleteUploadedImage(uploadedHoverImageUrl);
      } catch (_) {
        // Intentionally ignore rollback failures to preserve original error message.
      }

      final raw = e.message.toLowerCase();
      if (raw.contains('row-level security') || raw.contains('permission')) {
        errorMessage =
            'Your account does not have permission to add products. Add this user to admin_users.';
      } else if (raw.contains('foreign key')) {
        errorMessage =
            'Invalid relation data. Verify category/collection and related records.';
      } else {
        errorMessage = e.message;
      }
    } on StorageException catch (e) {
      try {
        if (createdProductId != null) {
          await _rollbackProductData(createdProductId);
        }
        await _deleteUploadedImage(uploadedPrimaryImageUrl);
        await _deleteUploadedImage(uploadedHoverImageUrl);
      } catch (_) {
        // Intentionally ignore rollback failures to preserve original error message.
      }
      errorMessage = e.message;
    } on StateError catch (e) {
      try {
        if (createdProductId != null) {
          await _rollbackProductData(createdProductId);
        }
        await _deleteUploadedImage(uploadedPrimaryImageUrl);
        await _deleteUploadedImage(uploadedHoverImageUrl);
      } catch (_) {
        // Intentionally ignore rollback failures to preserve original error message.
      }
      errorMessage = e.message;
    } catch (_) {
      try {
        if (createdProductId != null) {
          await _rollbackProductData(createdProductId);
        }
        await _deleteUploadedImage(uploadedPrimaryImageUrl);
        await _deleteUploadedImage(uploadedHoverImageUrl);
      } catch (_) {
        // Intentionally ignore rollback failures to preserve original error message.
      }
      errorMessage = 'Unable to save product. Check schema and RLS policies.';
    }

    isSubmitting = false;
    notifyListeners();
    return null;
  }

  @override
  void dispose() {
    nameController.dispose();
    weightController.dispose();
    purityController.dispose();
    basePriceController.dispose();
    originalPriceController.dispose();
    stockQuantityController.dispose();
    makingChargeController.dispose();
    ringSizeController.dispose();
    caratWeightController.dispose();
    stockNumberController.dispose();
    widthController.dispose();
    descriptionController.dispose();
    longDescriptionController.dispose();
    collectionController.dispose();
    super.dispose();
  }
}
