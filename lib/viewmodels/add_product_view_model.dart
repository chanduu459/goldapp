import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
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

class ModelImageOption {
  const ModelImageOption({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.categoryId,
  });

  final int id;
  final String title;
  final String imageUrl;
  final int categoryId;
}

class MetalTypeOption {
  const MetalTypeOption({
    required this.id,
    required this.name,
    required this.unit,
  });

  final String id;
  final String name;
  final String unit;
}

enum ProductImageType { primary, hover }

enum ProductImageInputMode { manual, ai }

class AddProductViewModel extends ChangeNotifier {
  AddProductViewModel({this.editProductId}) {
    _attachAutoDescriptionListeners();
    _refreshAutoDescriptions(notify: false);
  }

  final int? editProductId;
  bool get isEditMode => editProductId != null;

  final formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final weightController = TextEditingController();
  final purityController = TextEditingController();
  final basePriceController = TextEditingController(text: '0');
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
  bool _loadedEditProduct = false;
  bool _isHydratingEditProduct = false;

  String? existingPrimaryImageUrl;
  String? existingHoverImageUrl;

  Uint8List? selectedPrimaryImageBytes;
  String? selectedPrimaryImageName;
  Uint8List? selectedHoverImageBytes;
  String? selectedHoverImageName;
  ProductImageInputMode selectedImageInputMode = ProductImageInputMode.manual;

  List<CategoryOption> categories = const [];
  List<CollectionOption> collections = const [];
  List<ModelImageOption> aiModelImages = const [];
  List<MetalTypeOption> metalTypes = const [];
  Map<String, double> _metalPriceByMetalId = const {};
  int? selectedCategoryId;
  int? selectedCollectionId;
  int? selectedAiModelImageId;
  String? selectedAiModelImageUrl;
  bool isLoadingAiModelImages = false;
  bool isGeneratingAiHoverImage = false;

  bool isNew = false;
  bool isBestSeller = false;
  bool isEngravable = false;
  bool isActive = true;
  bool rhodiumFinish = false;
  bool hasDiamond = false;
  String selectedMetalType = 'Gold';
  String selectedDiamondType = 'Natural';

  bool _autoSyncShortDescription = true;
  bool _autoSyncLongDescription = true;
  String _lastAutoShortDescription = '';
  String _lastAutoLongDescription = '';

  void _attachAutoDescriptionListeners() {
    final listenables = <TextEditingController>[
      nameController,
      weightController,
      purityController,
      basePriceController,
      originalPriceController,
      stockQuantityController,
      makingChargeController,
      ringSizeController,
      caratWeightController,
      stockNumberController,
      widthController,
      collectionController,
    ];

    for (final controller in listenables) {
      controller.addListener(_refreshAutoDescriptions);
    }

    // Keep original price in sync with selected metal and entered weight.
    weightController.addListener(_autoFillOriginalPriceFromWeight);
  }

  String _normalizeMetalKey(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  MetalTypeOption? _findBestMetalOption(String value) {
    final input = value.trim();
    if (input.isEmpty || metalTypes.isEmpty) {
      return null;
    }

    for (final metal in metalTypes) {
      if (metal.name == input) {
        return metal;
      }
    }

    final lowered = input.toLowerCase();
    for (final metal in metalTypes) {
      if (metal.name.toLowerCase() == lowered) {
        return metal;
      }
    }

    final normalized = _normalizeMetalKey(input);
    for (final metal in metalTypes) {
      if (_normalizeMetalKey(metal.name) == normalized) {
        return metal;
      }
    }

    if (normalized.contains('white') && normalized.contains('gold')) {
      for (final metal in metalTypes) {
        final key = _normalizeMetalKey(metal.name);
        if (key.contains('white') && key.contains('gold')) {
          return metal;
        }
      }
    }

    if (normalized.contains('rose') && normalized.contains('gold')) {
      for (final metal in metalTypes) {
        final key = _normalizeMetalKey(metal.name);
        if (key.contains('rose') && key.contains('gold')) {
          return metal;
        }
      }
    }

    if (normalized.contains('platinum')) {
      for (final metal in metalTypes) {
        final key = _normalizeMetalKey(metal.name);
        if (key.contains('platinum')) {
          return metal;
        }
      }
    }

    if (normalized.contains('silver')) {
      for (final metal in metalTypes) {
        final key = _normalizeMetalKey(metal.name);
        if (key.contains('silver')) {
          return metal;
        }
      }
    }

    if (normalized.contains('gold')) {
      for (final metal in metalTypes) {
        final key = _normalizeMetalKey(metal.name);
        if (key.contains('gold')) {
          return metal;
        }
      }
    }

    return null;
  }

  String? _selectedMetalId() {
    return _findBestMetalOption(selectedMetalType)?.id;
  }

  void _autoFillOriginalPriceFromWeight() {
    if (_isHydratingEditProduct) {
      return;
    }

    final weightText = weightController.text.trim();
    if (weightText.isEmpty) {
      _setControllerText(originalPriceController, '');
      return;
    }

    final weightInGrams = double.tryParse(weightText);
    if (weightInGrams == null || weightInGrams <= 0) {
      _setControllerText(originalPriceController, '');
      return;
    }

    final metalId = _selectedMetalId();
    if (metalId == null) {
      _setControllerText(originalPriceController, '');
      return;
    }

    final unitPrice = _metalPriceByMetalId[metalId];
    if (unitPrice == null || unitPrice <= 0) {
      _setControllerText(originalPriceController, '');
      return;
    }

    final calculated = (weightInGrams * unitPrice).toStringAsFixed(2);
    _setControllerText(originalPriceController, calculated);
  }

  String _categoryName() {
    final categoryId = selectedCategoryId;
    if (categoryId == null) {
      return 'Not selected';
    }

    final match = categories.where((item) => item.id == categoryId);
    if (match.isEmpty) {
      return 'Not selected';
    }

    return match.first.name;
  }

  String _collectionName() {
    final typed = collectionController.text.trim();
    if (typed.isNotEmpty) {
      return typed;
    }

    if (selectedCollectionId == null) {
      return 'No collection';
    }

    final match = collections.where((item) => item.id == selectedCollectionId);
    if (match.isEmpty) {
      return 'No collection';
    }

    return match.first.name;
  }

  String _buildAutoShortDescription() {
    final name = nameController.text.trim();
    final purity = purityController.text.trim();
    final weight = weightController.text.trim();

    if (name.isEmpty && purity.isEmpty && weight.isEmpty) {
      return 'Product details will be generated from the form fields.';
    }

    final parts = <String>[];
    if (name.isNotEmpty) {
      parts.add(name);
    }
    if (purity.isNotEmpty) {
      parts.add('${purity}K $selectedMetalType');
    } else {
      parts.add(selectedMetalType);
    }
    if (weight.isNotEmpty) {
      parts.add('${weight}g');
    }

    return parts.join(' | ');
  }

  String _buildAutoLongDescription(String shortDescription) {
    final lines = <String>[shortDescription];

    final categoryName = _categoryName();
    if (categoryName != 'Not selected') {
      lines.add('Category: $categoryName');
    }

    final collectionName = _collectionName();
    if (collectionName != 'No collection') {
      lines.add('Collection: $collectionName');
    }

    final originalPrice = originalPriceController.text.trim();
    if (originalPrice.isNotEmpty) {
      lines.add('Original Price: $originalPrice');
    }

    final stockQuantity = stockQuantityController.text.trim();
    if (stockQuantity.isNotEmpty && stockQuantity != '0') {
      lines.add('Stock Quantity: $stockQuantity');
    }

    final makingCharge = makingChargeController.text.trim();
    if (makingCharge.isNotEmpty) {
      lines.add('Making Charge: $makingCharge');
    }

    final weight = weightController.text.trim();
    if (weight.isNotEmpty) {
      lines.add('Weight: ${weight}g');
    }

    final purity = purityController.text.trim();
    if (purity.isNotEmpty) {
      lines.add('Purity: ${purity}K');
    }

    if (hasDiamond) {
      lines.add('Diamond Type: $selectedDiamondType');
    }

    final caratWeight = caratWeightController.text.trim();
    if (caratWeight.isNotEmpty) {
      lines.add('Total Carat Weight: $caratWeight');
    }

    final width = widthController.text.trim();
    if (width.isNotEmpty) {
      lines.add('Width: ${width}mm');
    }

    if (rhodiumFinish) {
      lines.add('Rhodium Finish: Yes');
    }

    final flags = <String>[];
    if (isNew) {
      flags.add('New Arrival');
    }
    if (isBestSeller) {
      flags.add('Best Seller');
    }
    if (isEngravable) {
      flags.add('Engravable');
    }
    if (!isActive) {
      flags.add('Inactive');
    }
    if (flags.isNotEmpty) {
      lines.add('Flags: ${flags.join(', ')}');
    }

    return lines.join('\n');
  }

  void _setControllerText(TextEditingController controller, String value) {
    if (controller.text == value) {
      return;
    }
    controller.value = controller.value.copyWith(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
      composing: TextRange.empty,
    );
  }

  void _refreshAutoDescriptions({bool notify = true}) {
    final shortDescription = _buildAutoShortDescription();
    final longDescription = _buildAutoLongDescription(shortDescription);

    final currentShort = descriptionController.text.trim();
    final currentLong = longDescriptionController.text.trim();

    if (_autoSyncShortDescription ||
        currentShort.isEmpty ||
        currentShort == _lastAutoShortDescription.trim()) {
      _setControllerText(descriptionController, shortDescription);
      _lastAutoShortDescription = shortDescription;
    }

    if (_autoSyncLongDescription ||
        currentLong.isEmpty ||
        currentLong == _lastAutoLongDescription.trim()) {
      _setControllerText(longDescriptionController, longDescription);
      _lastAutoLongDescription = longDescription;
    }

    if (notify) {
      notifyListeners();
    }
  }

  void onShortDescriptionChanged(String value) {
    final trimmed = value.trim();
    _autoSyncShortDescription =
        trimmed.isEmpty || trimmed == _lastAutoShortDescription.trim();
    if (_autoSyncShortDescription) {
      _refreshAutoDescriptions();
      return;
    }
    notifyListeners();
  }

  void onLongDescriptionChanged(String value) {
    final trimmed = value.trim();
    _autoSyncLongDescription =
        trimmed.isEmpty || trimmed == _lastAutoLongDescription.trim();
    if (_autoSyncLongDescription) {
      _refreshAutoDescriptions();
      return;
    }
    notifyListeners();
  }

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

      final metalRows = await Supabase.instance.client
          .from('metals')
          .select('id, name, unit')
          .order('name', ascending: true);

      metalTypes = (metalRows as List<dynamic>)
          .map((row) => MetalTypeOption(
                id: row['id'] as String,
                name: ((row['name'] as String?) ?? '').trim(),
                unit: ((row['unit'] as String?) ?? '').trim(),
              ))
          .where((item) => item.name.isNotEmpty)
          .toList(growable: false);

      final metalPriceRows = await Supabase.instance.client
          .from('metal_prices')
          .select('metal_id, price, price_date, created_at')
          .order('price_date', ascending: false)
          .order('created_at', ascending: false);

      final latestPriceByMetalId = <String, double>{};
      for (final row in (metalPriceRows as List<dynamic>)) {
        final metalId = row['metal_id'] as String?;
        final price = (row['price'] as num?)?.toDouble();
        if (metalId == null || price == null || price <= 0) {
          continue;
        }
        latestPriceByMetalId.putIfAbsent(metalId, () => price);
      }
      _metalPriceByMetalId = latestPriceByMetalId;

      if (metalTypes.isNotEmpty) {
        final hasCurrentMetal = metalTypes.any(
          (item) => item.name == selectedMetalType,
        );
        if (!hasCurrentMetal) {
          selectedMetalType = metalTypes.first.name;
        }
      }

      _autoFillOriginalPriceFromWeight();

      if (categories.isNotEmpty) {
        selectedCategoryId ??= categories.first.id;
      }

      if (isEditMode && !_loadedEditProduct) {
        await _loadEditProduct();
      }

      await _loadModelImagesForCategory(selectedCategoryId);

      if (categories.isEmpty) {
        errorMessage = 'No categories found. Create categories first.';
      } else if (metalTypes.isEmpty) {
        errorMessage = 'No metals found. Add metals first.';
      }
    } catch (_) {
      errorMessage = 'Unable to load categories/collections.';
    }

    isLoadingReferenceData = false;
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  double? _extractDecimalFromDescription(String source, String label) {
    final pattern = RegExp(
      '$label\\s*:\\s*([0-9]+(?:\\.[0-9]+)?)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(source);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(1) ?? '');
  }

  int? _extractIntFromPurity(String value) {
    final match = RegExp(r'(\d{1,2})').firstMatch(value);
    if (match == null) {
      return null;
    }
    return int.tryParse(match.group(1) ?? '');
  }

  Future<void> _loadEditProduct() async {
    final id = editProductId;
    if (id == null) {
      return;
    }

    final row = await Supabase.instance.client
        .from('products')
        .select(
          'id, name, category_id, collection_id, base_price, original_price, image_url, hover_image_url, description, long_description, stock_quantity, is_new, is_best_seller, is_engravable, is_active, metaltype, product_metals(metal_type,purity), ring_sizes(size_label,size_number), product_variants(metal,carat,diamond_type,ring_size,barcode), product_options(option_type,option_value)',
        )
        .eq('id', id)
        .single();

    final metalRows = row['product_metals'] as List<dynamic>? ?? const [];
    final ringSizeRows = row['ring_sizes'] as List<dynamic>? ?? const [];
    final variantRows = row['product_variants'] as List<dynamic>? ?? const [];
    final optionRows = row['product_options'] as List<dynamic>? ?? const [];

    final metalData = metalRows.isNotEmpty && metalRows.first is Map<String, dynamic>
        ? metalRows.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final ringSizeData = ringSizeRows.isNotEmpty && ringSizeRows.first is Map<String, dynamic>
        ? ringSizeRows.first as Map<String, dynamic>
        : const <String, dynamic>{};
    final variantData = variantRows.isNotEmpty && variantRows.first is Map<String, dynamic>
        ? variantRows.first as Map<String, dynamic>
        : const <String, dynamic>{};

    Map<String, dynamic>? firstOptionByType(String type) {
      for (final row in optionRows) {
        if (row is Map<String, dynamic>) {
          final optionType = (row['option_type'] as String? ?? '').trim().toLowerCase();
          if (optionType == type.toLowerCase()) {
            return row;
          }
        }
      }
      return null;
    }

    final metalOption = firstOptionByType('metal');
    final diamondOption = firstOptionByType('diamond_type');

    final longDescription = (row['long_description'] as String? ?? '').trim();
    final purityRaw = (metalData['purity'] as String? ?? '').trim();
    final purityKarat = _extractIntFromPurity(purityRaw);
    final weightFromDescription =
        _extractDecimalFromDescription(longDescription, 'Weight');
    final makingChargeFromDescription =
        _extractDecimalFromDescription(longDescription, 'Making Charge');
    final widthFromDescription =
        _extractDecimalFromDescription(longDescription, 'Width');
    final originalPriceFromDescription =
      _extractDecimalFromDescription(longDescription, 'Original Price');

    _isHydratingEditProduct = true;
    try {
      nameController.text = (row['name'] as String? ?? '').trim();
      selectedCategoryId = row['category_id'] as int?;
      selectedCollectionId = row['collection_id'] as int?;
      if (selectedCollectionId != null) {
        final match = collections.where((item) => item.id == selectedCollectionId);
        if (match.isNotEmpty) {
          collectionController.text = match.first.name;
        }
      }

      basePriceController.text =
          ((row['base_price'] as num?) ?? 0).toDouble().toStringAsFixed(2);
        final rawOriginalPrice =
          ((row['original_price'] as num?) ?? (row['base_price'] as num?) ?? 0)
            .toDouble();
        final resolvedOriginalPrice = rawOriginalPrice > 0
          ? rawOriginalPrice
          : (originalPriceFromDescription ?? 0);
        originalPriceController.text = resolvedOriginalPrice.toStringAsFixed(2);
      stockQuantityController.text =
          (((row['stock_quantity'] as num?) ?? 0).toInt()).toString();

      descriptionController.text = (row['description'] as String? ?? '').trim();
      longDescriptionController.text = longDescription;

        final metalType = (metalData['metal_type'] as String? ?? '').trim();
        final metalTypeFromOption =
          (metalOption?['option_value'] as String? ?? '').trim();
        final metalTypeFromVariant =
          (variantData['metal'] as String? ?? '').trim();
        final metalTypeFromProduct = (row['metaltype'] as String? ?? '').trim();
        final resolvedMetalType = metalTypeFromProduct.isNotEmpty
          ? metalTypeFromProduct
          : (metalTypeFromOption.isNotEmpty
            ? metalTypeFromOption
            : (metalTypeFromVariant.isNotEmpty
              ? metalTypeFromVariant
              : (metalType.isNotEmpty ? metalType : selectedMetalType)));
        selectedMetalType = _findBestMetalOption(resolvedMetalType)?.name ??
          resolvedMetalType;

      if (!metalTypes.any((item) => item.name == selectedMetalType)) {
        metalTypes = [
          ...metalTypes,
          MetalTypeOption(
            id: 'legacy-${_slugify(selectedMetalType)}',
            name: selectedMetalType,
            unit: 'gram',
          ),
        ];
      }

      purityController.text = (purityKarat ?? 22).toString();
      weightController.text = (weightFromDescription ?? 1).toStringAsFixed(3);
      makingChargeController.text =
          (makingChargeFromDescription ?? 1).toStringAsFixed(2);

      ringSizeController.text =
          ((ringSizeData['size_label'] as String?) ??
                  (variantData['ring_size'] as String?) ??
                  '')
              .trim();
      final carat = (variantData['carat'] as num?)?.toDouble() ?? 0;
      caratWeightController.text = carat == 0 ? '' : carat.toString();
      final diamondType =
          (variantData['diamond_type'] as String? ?? '').trim();
      final diamondTypeFromOption =
          (diamondOption?['option_value'] as String? ?? '').trim();
      final resolvedDiamondType = diamondType.isNotEmpty
          ? diamondType
          : (diamondTypeFromOption.isNotEmpty ? diamondTypeFromOption : 'None');
      selectedDiamondType = resolvedDiamondType;
      hasDiamond = selectedDiamondType.toLowerCase() != 'none';

      stockNumberController.text =
          (variantData['barcode'] as String? ?? '').trim();
      widthController.text = widthFromDescription == null
          ? ''
          : widthFromDescription.toStringAsFixed(2);

      isNew = row['is_new'] as bool? ?? false;
      isBestSeller = row['is_best_seller'] as bool? ?? false;
      isEngravable = row['is_engravable'] as bool? ?? false;
      isActive = row['is_active'] as bool? ?? true;

      existingPrimaryImageUrl = (row['image_url'] as String?)?.trim();
      existingHoverImageUrl = (row['hover_image_url'] as String?)?.trim();
    } finally {
      _isHydratingEditProduct = false;
    }

    _loadedEditProduct = true;
    _autoFillOriginalPriceFromWeight();
    _refreshAutoDescriptions(notify: false);
  }

  void setSelectedCategory(int? value) {
    selectedCategoryId = value;
    selectedAiModelImageId = null;
    selectedAiModelImageUrl = null;
    selectedHoverImageBytes = null;
    selectedHoverImageName = null;
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
    _loadModelImagesForCategory(value);
  }

  void setSelectedCollection(int? value) {
    selectedCollectionId = value;
    if (value != null) {
      final match = collections.where((item) => item.id == value);
      if (match.isNotEmpty) {
        collectionController.text = match.first.name;
      }
    }
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setCollectionName(String value) {
    collectionController.text = value;

    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      _refreshAutoDescriptions(notify: false);
      notifyListeners();
      return;
    }

    final existing = collections.where(
      (item) => item.name.trim().toLowerCase() == normalized,
    );

    if (existing.isNotEmpty) {
      selectedCollectionId = existing.first.id;
    }

    _refreshAutoDescriptions(notify: false);
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
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setIsBestSeller(bool value) {
    isBestSeller = value;
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setIsEngravable(bool value) {
    isEngravable = value;
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setIsActive(bool value) {
    isActive = value;
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setRhodiumFinish(bool value) {
    rhodiumFinish = value;
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setHasDiamond(bool value) {
    hasDiamond = value;
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setSelectedMetalType(String? value) {
    if (value == null) {
      return;
    }

    final bestMatch = _findBestMetalOption(value);
    selectedMetalType = bestMatch?.name ?? value;
    _autoFillOriginalPriceFromWeight();
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setSelectedDiamondType(String? value) {
    if (value == null) {
      return;
    }
    selectedDiamondType = value;
    _refreshAutoDescriptions(notify: false);
    notifyListeners();
  }

  void setSelectedImageInputMode(ProductImageInputMode mode) {
    selectedImageInputMode = mode;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> _loadModelImagesForCategory(int? categoryId) async {
    if (categoryId == null) {
      aiModelImages = const [];
      isLoadingAiModelImages = false;
      notifyListeners();
      return;
    }

    isLoadingAiModelImages = true;
    notifyListeners();

    try {
      final rows = await Supabase.instance.client
          .from('model_images')
          .select('id, title, image_url, category_id')
          .eq('category_id', categoryId)
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: false);

      aiModelImages = (rows as List<dynamic>)
          .where((row) {
            final url = (row['image_url'] as String?)?.trim() ?? '';
            return url.isNotEmpty;
          })
          .map(
            (row) => ModelImageOption(
              id: row['id'] as int,
              title: ((row['title'] as String?) ?? 'Model Image').trim(),
              imageUrl: ((row['image_url'] as String?) ?? '').trim(),
              categoryId: row['category_id'] as int,
            ),
          )
          .toList(growable: false);
    } catch (_) {
      aiModelImages = const [];
    } finally {
      if (selectedAiModelImageId != null) {
        final stillExists = aiModelImages.any(
          (item) => item.id == selectedAiModelImageId,
        );
        if (!stillExists) {
          selectedAiModelImageId = null;
          selectedAiModelImageUrl = null;
        }
      }
      isLoadingAiModelImages = false;
      notifyListeners();
    }
  }

  void setSelectedAiModelImage(ModelImageOption option) {
    selectedAiModelImageId = option.id;
    selectedAiModelImageUrl = option.imageUrl;
    selectedHoverImageBytes = null;
    selectedHoverImageName = null;
    errorMessage = null;
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
      if (selectedImageInputMode == ProductImageInputMode.ai) {
        selectedHoverImageBytes = null;
        selectedHoverImageName = null;
      }
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

  Future<Uint8List> _downloadImageBytesFromUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw StateError('Selected model image URL is invalid.');
    }
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('Unable to download selected model image.');
    }
    if (response.bodyBytes.isEmpty) {
      throw StateError('Selected model image is empty.');
    }
    return response.bodyBytes;
  }

  Uint8List? _decodeGeneratedImage(String value) {
    final input = value.trim();
    if (input.isEmpty) {
      return null;
    }

    final dataUrlPattern = RegExp(r'data:image\/[^;]+;base64,([A-Za-z0-9+/=\n\r]+)');
    final dataUrlMatch = dataUrlPattern.firstMatch(input);
    if (dataUrlMatch != null) {
      try {
        return base64Decode(dataUrlMatch.group(1)!.replaceAll(RegExp(r'\s+'), ''));
      } catch (_) {
        return null;
      }
    }

    try {
      final compact = input.replaceAll(RegExp(r'\s+'), '');
      if (compact.length < 100) {
        return null;
      }
      return base64Decode(compact);
    } catch (_) {
      return null;
    }
  }

  String? _extractHttpImageUrl(String text) {
    final pattern = RegExp(
      r'https?:\/\/[^\s\)\]]+\.(?:png|jpg|jpeg|webp)(?:\?[^\s\)\]]*)?',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(text);
    if (match == null) {
      return null;
    }
    return match.group(0);
  }

  Future<Uint8List?> _extractGeneratedBytesFromOpenRouter(dynamic decoded) async {
    if (decoded is! Map<String, dynamic>) {
      return null;
    }

    final choices = decoded['choices'];
    if (choices is! List || choices.isEmpty) {
      return null;
    }

    final firstChoice = choices.first;
    if (firstChoice is! Map<String, dynamic>) {
      return null;
    }

    final message = firstChoice['message'];
    if (message is! Map<String, dynamic>) {
      return null;
    }

    Future<Uint8List?> readPotentialImage(dynamic value) async {
      if (value == null) {
        return null;
      }

      if (value is String) {
        final bytesFromText = _decodeGeneratedImage(value);
        if (bytesFromText != null) {
          return bytesFromText;
        }

        final remoteUrl = _extractHttpImageUrl(value);
        if (remoteUrl != null) {
          try {
            return await _downloadImageBytesFromUrl(remoteUrl);
          } catch (_) {
            return null;
          }
        }
        return null;
      }

      if (value is Map<String, dynamic>) {
        final imageUrlValue = value['image_url'];
        if (imageUrlValue is Map<String, dynamic>) {
          final url = (imageUrlValue['url'] as String?)?.trim() ?? '';
          final bytes = await readPotentialImage(url);
          if (bytes != null) {
            return bytes;
          }
        } else if (imageUrlValue is String) {
          final bytes = await readPotentialImage(imageUrlValue);
          if (bytes != null) {
            return bytes;
          }
        }

        final b64 = (value['b64_json'] as String?)?.trim() ?? '';
        if (b64.isNotEmpty) {
          final bytes = _decodeGeneratedImage(b64);
          if (bytes != null) {
            return bytes;
          }
        }

        final imageBase64 = (value['image_base64'] as String?)?.trim() ?? '';
        if (imageBase64.isNotEmpty) {
          final bytes = _decodeGeneratedImage(imageBase64);
          if (bytes != null) {
            return bytes;
          }
        }

        final url = (value['url'] as String?)?.trim() ?? '';
        if (url.isNotEmpty) {
          final bytes = await readPotentialImage(url);
          if (bytes != null) {
            return bytes;
          }
        }

        final text = (value['text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) {
          final bytes = await readPotentialImage(text);
          if (bytes != null) {
            return bytes;
          }
        }
      }

      if (value is List) {
        for (final item in value) {
          final bytes = await readPotentialImage(item);
          if (bytes != null) {
            return bytes;
          }
        }
      }

      return null;
    }

    final content = message['content'];
    if (content is List) {
      for (final part in content) {
        final bytes = await readPotentialImage(part);
        if (bytes != null) {
          return bytes;
        }
      }
    }

    final contentText = message['content'];
    final fromText = await readPotentialImage(contentText);
    if (fromText != null) {
      return fromText;
    }

    final messageImages = message['images'];
    final fromImages = await readPotentialImage(messageImages);
    if (fromImages != null) {
      return fromImages;
    }

    final topLevelData = decoded['data'];
    final fromData = await readPotentialImage(topLevelData);
    if (fromData != null) {
      return fromData;
    }

    return null;
  }

  Future<Uint8List> _generateHoverImageWithOpenRouter({
    required Uint8List normalImageBytes,
    required Uint8List modelImageBytes,
    required String productName,
  }) async {
    var apiKey = dotenv.env['OPENROUTER_API_KEY']?.trim() ?? '';
    if (apiKey.startsWith('"') && apiKey.endsWith('"') && apiKey.length > 1) {
      apiKey = apiKey.substring(1, apiKey.length - 1).trim();
    }
    if (apiKey.toLowerCase().startsWith('bearer ')) {
      apiKey = apiKey.substring(7).trim();
    }
    if (apiKey.isEmpty) {
      throw StateError('Missing OPENROUTER_API_KEY in .env');
    }

    final configuredModel = dotenv.env['OPENROUTER_IMAGE_MODEL']?.trim() ?? '';
    final configuredMaxTokens =
        int.tryParse(dotenv.env['OPENROUTER_MAX_TOKENS']?.trim() ?? '') ?? 512;
    final tokenCandidates = {
      if (configuredMaxTokens > 0) configuredMaxTokens,
      512,
      256,
      128,
    }.toList(growable: false);

    final modelCandidates = [
      if (configuredModel.isNotEmpty) configuredModel,
      'openai/gpt-image-1',
      'openrouter/auto',
    ];

    final normalBase64 = base64Encode(normalImageBytes);
    final modelBase64 = base64Encode(modelImageBytes);
    final prompt =
        'Generate a single realistic hover product image for a jewelry catalog. '
        'Use the first image as the main product reference and the second image as model/style reference. '
        'Keep the jewelry details from the first image, blend naturally for hover state, clean background, '
      'high quality e-commerce output. '
      'Return image output directly (either as an image data URL or image URL), not plain explanation text. '
      'Product name: $productName.';

    final runtimeOrigin = kIsWeb ? Uri.base.origin : '';
    final configuredSiteUrl = dotenv.env['OPENROUTER_SITE_URL']?.trim() ?? '';
    final configuredAppTitle = dotenv.env['OPENROUTER_APP_TITLE']?.trim() ?? '';

    final headers = <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    // These headers are optional for OpenRouter; include only when explicitly set.
    if (configuredSiteUrl.isNotEmpty) {
      headers['HTTP-Referer'] = configuredSiteUrl;
    } else if (runtimeOrigin.isNotEmpty) {
      headers['HTTP-Referer'] = runtimeOrigin;
    }

    if (configuredAppTitle.isNotEmpty) {
      headers['X-Title'] = configuredAppTitle;
    }

    String? lastRecoverableError;

    for (final model in modelCandidates.toSet()) {
      for (final maxTokens in tokenCandidates) {
        final response = await http.post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: headers,
          body: jsonEncode({
            'model': model,
            'max_tokens': maxTokens,
            'modalities': ['text', 'image'],
            'messages': [
              {
                'role': 'user',
                'content': [
                  {'type': 'text', 'text': prompt},
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$normalBase64'}
                  },
                  {
                    'type': 'image_url',
                    'image_url': {'url': 'data:image/jpeg;base64,$modelBase64'}
                  }
                ],
              }
            ],
          }),
        );

        if (response.statusCode < 200 || response.statusCode >= 300) {
          String details = '';
          try {
            final parsed = jsonDecode(response.body);
            if (parsed is Map<String, dynamic>) {
              final err = parsed['error'];
              if (err is Map<String, dynamic>) {
                final msg = (err['message'] as String?)?.trim() ?? '';
                if (msg.isNotEmpty) {
                  details = msg;
                }
              }
            }
          } catch (_) {
            // Keep fallback generic message when response body is not JSON.
          }

          if (response.statusCode == 401) {
            final lowered = details.toLowerCase();
            if (lowered.contains('user not found')) {
              throw StateError(
                'OpenRouter user not found for this API key. Generate a new API key in your OpenRouter account and update OPENROUTER_API_KEY in .env.',
              );
            }
            throw StateError(
              details.isNotEmpty
                  ? 'OpenRouter auth failed (401): $details'
                  : 'OpenRouter authentication failed (401). Check OPENROUTER_API_KEY in .env and restart the app.',
            );
          }

          final lowered = details.toLowerCase();
          final isNoEndpoint = response.statusCode == 404 &&
              (lowered.contains('no endpoints found') ||
                  lowered.contains('model issue'));
          if (isNoEndpoint) {
            lastRecoverableError = 'Model "$model" unavailable: $details';
            break;
          }

          final isCreditIssue = response.statusCode == 402 &&
              (lowered.contains('requires more credits') ||
                  lowered.contains('max_tokens'));
          if (isCreditIssue) {
            lastRecoverableError =
                'Credits/token limit hit for model "$model" at max_tokens=$maxTokens. Retrying with lower budget.';
            continue;
          }

          throw StateError(
            details.isNotEmpty
                ? 'OpenRouter request failed (${response.statusCode}): $details'
                : 'OpenRouter request failed (${response.statusCode}).',
          );
        }

        final decoded = jsonDecode(response.body);
        final generatedBytes = await _extractGeneratedBytesFromOpenRouter(decoded);
        if (generatedBytes != null && generatedBytes.isNotEmpty) {
          return generatedBytes;
        }

        lastRecoverableError =
            'Model "$model" returned no image payload. Trying fallback model.';
      }
    }

    throw StateError(
      lastRecoverableError ??
          'OpenRouter did not return a generated image. Set OPENROUTER_IMAGE_MODEL in .env to an image-capable model and try again.',
    );
  }

  Future<bool> generateAiHoverImage() async {
    if (selectedImageInputMode != ProductImageInputMode.ai) {
      return false;
    }
    if (isGeneratingAiHoverImage) {
      return false;
    }

    final normalBytes = selectedPrimaryImageBytes;
    final normalName = selectedPrimaryImageName;
    if (normalBytes == null || normalName == null) {
      errorMessage = 'Upload normal image first before generating hover image.';
      notifyListeners();
      return false;
    }

    final modelUrl = selectedAiModelImageUrl;
    if (modelUrl == null || modelUrl.isEmpty) {
      errorMessage = 'Select a model image for this category first.';
      notifyListeners();
      return false;
    }

    isGeneratingAiHoverImage = true;
    errorMessage = null;
    notifyListeners();

    try {
      final modelBytes = await _downloadImageBytesFromUrl(modelUrl);
      final productName = nameController.text.trim().isEmpty
          ? 'gold-jewelry'
          : nameController.text.trim();
      final generatedBytes = await _generateHoverImageWithOpenRouter(
        normalImageBytes: normalBytes,
        modelImageBytes: modelBytes,
        productName: productName,
      );
      final ts = DateTime.now().millisecondsSinceEpoch;
      setSelectedImage(
        type: ProductImageType.hover,
        bytes: generatedBytes,
        name: 'hover-generated-$ts.png',
      );
      return true;
    } on StateError catch (e) {
      errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      errorMessage = 'Failed to generate hover image. Please try again.';
      notifyListeners();
      return false;
    } finally {
      isGeneratingAiHoverImage = false;
      notifyListeners();
    }
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

  String? _legacyProductMetalType(String selectedType) {
    final normalized = selectedType.trim().toLowerCase();
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains('white') && normalized.contains('gold')) {
      return 'White Gold';
    }
    if (normalized.contains('rose') && normalized.contains('gold')) {
      return 'Rose Gold';
    }
    if (normalized.contains('platinum')) {
      return 'Platinum';
    }
    if (normalized.contains('silver')) {
      return 'Silver';
    }
    if (normalized.contains('gold')) {
      return 'Gold';
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

    try {
      await Supabase.instance.client.storage.from(_productBucket).remove([path]);
    } catch (_) {
      // Best effort cleanup.
    }
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

    if ((rows as List<dynamic>).isEmpty) {
      await client.from('product_metals').insert({
        'product_id': productId,
        'metal_type': metalType,
        'purity': purity,
        'is_available': true,
      });
      return;
    }

    final id = rows.first['id'] as int;
    await client.from('product_metals').update({
      'metal_type': metalType,
      'purity': purity,
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
    required String sku,
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
        'sku': '$sku-V1',
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

  Future<void> _upsertProductImage({
    required SupabaseClient client,
    required int productId,
    required String imageUrl,
    required String altText,
    required int sortOrder,
  }) async {
    final rows = await client
        .from('product_images')
        .select('id')
        .eq('product_id', productId)
        .eq('sort_order', sortOrder)
        .limit(1);

    if ((rows as List<dynamic>).isEmpty) {
      await client.from('product_images').insert({
        'product_id': productId,
        'image_url': imageUrl,
        'alt_text': altText,
        'sort_order': sortOrder,
      });
      return;
    }

    final id = rows.first['id'] as int;
    await client.from('product_images').update({
      'image_url': imageUrl,
      'alt_text': altText,
    }).eq('id', id);
  }

  Future<GoldOrnamentProduct?> _submitUpdate() async {
    final productId = editProductId;
    if (productId == null) {
      errorMessage = 'Missing product id for update.';
      notifyListeners();
      return null;
    }

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    String? uploadedPrimaryImageUrl;
    String? uploadedHoverImageUrl;

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        errorMessage = 'You must be signed in to update products.';
        isSubmitting = false;
        notifyListeners();
        return null;
      }

      final draft = buildProduct();
      final legacyMetalType = _legacyProductMetalType(draft.metalType);
      if (legacyMetalType == null) {
        errorMessage =
            'Selected metal "${draft.metalType}" is not supported by product_metal constraint. Use Gold, White Gold, Rose Gold, Platinum or Silver naming.';
        isSubmitting = false;
        notifyListeners();
        return null;
      }

      String imageUrl = (existingPrimaryImageUrl ?? '').trim();
      String hoverImageUrl = (existingHoverImageUrl ?? '').trim();

      if (selectedPrimaryImageBytes != null && selectedPrimaryImageName != null) {
        uploadedPrimaryImageUrl = await _uploadImageToStorage(
          type: ProductImageType.primary,
          productName: draft.name,
        );
        imageUrl = uploadedPrimaryImageUrl;
      }

      if (selectedHoverImageBytes != null && selectedHoverImageName != null) {
        uploadedHoverImageUrl = await _uploadImageToStorage(
          type: ProductImageType.hover,
          productName: draft.name,
        );
        hoverImageUrl = uploadedHoverImageUrl;
      }

      final formattedLongDescription =
          draft.longDescription.isEmpty ? draft.description : draft.longDescription;

      final client = Supabase.instance.client;
      await client
          .from('products')
          .update({
            'name': draft.name,
            'category_id': draft.categoryId,
            'collection_id': draft.collectionId,
            'description': draft.description,
            'long_description': formattedLongDescription,
            'base_price': draft.basePrice,
            'original_price': draft.originalPrice,
            'metaltype': draft.metalType,
            'image_url': imageUrl.isEmpty ? null : imageUrl,
            'hover_image_url': hoverImageUrl.isEmpty ? null : hoverImageUrl,
            'stock_quantity': draft.stockQuantity,
            'is_new': draft.isNew,
            'is_best_seller': draft.isBestSeller,
            'is_engravable': draft.isEngravable,
            'is_active': draft.isActive,
          })
          .eq('id', productId);

      await _upsertProductMetal(
        client: client,
        productId: productId,
        metalType: legacyMetalType,
        purity: '${draft.purityKarat}K',
      );

      await _upsertRingSize(
        client: client,
        productId: productId,
        ringSize: draft.ringSize,
      );

      await _upsertVariant(
        client: client,
        productId: productId,
        sku: _buildSku(draft.name),
        metalType: draft.metalType,
        caratWeight: draft.caratWeight,
        diamondType: hasDiamond ? draft.diamondType : 'None',
        ringSize: draft.ringSize,
        stockQuantity: draft.stockQuantity,
        stockNumber: draft.stockNumber,
        isActive: draft.isActive,
      );

      await _upsertProductOption(
        client: client,
        productId: productId,
        optionType: 'metal',
        optionName: 'Metal Type',
        optionValue: draft.metalType,
        sortOrder: 1,
      );

      if (hasDiamond) {
        await _upsertProductOption(
          client: client,
          productId: productId,
          optionType: 'diamond_type',
          optionName: 'Diamond Type',
          optionValue: draft.diamondType,
          sortOrder: 2,
        );
      } else {
        await client
            .from('product_options')
            .delete()
            .eq('product_id', productId)
            .eq('option_type', 'diamond_type');
      }

      if (imageUrl.isNotEmpty) {
        await _upsertProductImage(
          client: client,
          productId: productId,
          imageUrl: imageUrl,
          altText: '${draft.name} main image',
          sortOrder: 1,
        );
      }

      if (hoverImageUrl.isNotEmpty) {
        await _upsertProductImage(
          client: client,
          productId: productId,
          imageUrl: hoverImageUrl,
          altText: '${draft.name} hover image',
          sortOrder: 2,
        );
      }

      final oldPrimary = (existingPrimaryImageUrl ?? '').trim();
      final oldHover = (existingHoverImageUrl ?? '').trim();
      if (uploadedPrimaryImageUrl != null &&
          oldPrimary.isNotEmpty &&
          oldPrimary != uploadedPrimaryImageUrl) {
        await _deleteUploadedImage(oldPrimary);
      }
      if (uploadedHoverImageUrl != null &&
          oldHover.isNotEmpty &&
          oldHover != uploadedHoverImageUrl) {
        await _deleteUploadedImage(oldHover);
      }

      existingPrimaryImageUrl = imageUrl;
      existingHoverImageUrl = hoverImageUrl;

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
      await _deleteUploadedImage(uploadedPrimaryImageUrl);
      await _deleteUploadedImage(uploadedHoverImageUrl);
      errorMessage = e.message;
    } on StorageException catch (e) {
      await _deleteUploadedImage(uploadedPrimaryImageUrl);
      await _deleteUploadedImage(uploadedHoverImageUrl);
      errorMessage = e.message;
    } on StateError catch (e) {
      await _deleteUploadedImage(uploadedPrimaryImageUrl);
      await _deleteUploadedImage(uploadedHoverImageUrl);
      errorMessage = e.message;
    } catch (_) {
      await _deleteUploadedImage(uploadedPrimaryImageUrl);
      await _deleteUploadedImage(uploadedHoverImageUrl);
      errorMessage = 'Unable to update product. Check schema and RLS policies.';
    }

    isSubmitting = false;
    notifyListeners();
    return null;
  }

  GoldOrnamentProduct buildProduct() {
    final categoryId = selectedCategoryId;
    if (categoryId == null) {
      throw StateError('Please select a category.');
    }

    final ringSizeValue = ringSizeController.text.trim();
    final caratWeightValue = caratWeightController.text.trim();
    final stockNumberValue = stockNumberController.text.trim();
    final widthValue = widthController.text.trim();

    return GoldOrnamentProduct(
      productId: -1,
      name: nameController.text.trim(),
      categoryId: categoryId,
      collectionId: selectedCollectionId,
      weightInGrams: double.parse(weightController.text.trim()),
      purityKarat: int.parse(purityController.text.trim()),
      basePrice: double.tryParse(basePriceController.text.trim()) ?? 0,
      originalPrice: originalPriceController.text.trim().isEmpty
          ? null
          : double.parse(originalPriceController.text.trim()),
      stockQuantity: int.tryParse(stockQuantityController.text.trim()) ?? 0,
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
        ringSize: ringSizeValue.isEmpty ? 'N/A' : ringSizeValue,
        caratWeight: double.tryParse(caratWeightValue) ?? 0,
        diamondType: hasDiamond ? selectedDiamondType : 'None',
        stockNumber: stockNumberValue.isEmpty ? 'N/A' : stockNumberValue,
        widthMm: double.tryParse(widthValue) ?? 0,
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

    if (selectedImageInputMode == ProductImageInputMode.manual) {
      final hasPrimaryImage =
          selectedPrimaryImageBytes != null ||
          ((existingPrimaryImageUrl ?? '').trim().isNotEmpty);
      final hasHoverImage =
          selectedHoverImageBytes != null ||
          ((existingHoverImageUrl ?? '').trim().isNotEmpty);

      if (!hasPrimaryImage) {
        errorMessage = 'Normal image is required for manual upload mode';
        notifyListeners();
        return null;
      }

      if (!hasHoverImage) {
        errorMessage = 'Hover image is required for manual upload mode';
        notifyListeners();
        return null;
      }
    } else {
      final hasPrimaryUpload =
          selectedPrimaryImageBytes != null && selectedPrimaryImageName != null;

      if (!hasPrimaryUpload) {
        errorMessage = 'AI mode requires a normal image upload.';
        notifyListeners();
        return null;
      }

      if (selectedAiModelImageUrl == null || selectedAiModelImageUrl!.isEmpty) {
        errorMessage =
            'Please select a model image for the selected category in AI mode.';
        notifyListeners();
        return null;
      }

      if (selectedHoverImageBytes == null || selectedHoverImageName == null) {
        final generated = await generateAiHoverImage();
        if (!generated) {
          return null;
        }
      }
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

    if (isEditMode) {
      return _submitUpdate();
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
      final legacyMetalType = _legacyProductMetalType(draft.metalType);
      if (legacyMetalType == null) {
        errorMessage =
            'Selected metal "${draft.metalType}" is not supported by product_metal constraint. Use Gold, White Gold, Rose Gold, Platinum or Silver naming.';
        isSubmitting = false;
        notifyListeners();
        return null;
      }

      final slug = '${_slugify(draft.name)}-${DateTime.now().millisecondsSinceEpoch}';
      final sku = _buildSku(draft.name);
      late final String imageUrl;
      late final String hoverImageUrl;

      if (selectedImageInputMode == ProductImageInputMode.manual) {
        imageUrl = await _uploadImageToStorage(
          type: ProductImageType.primary,
          productName: draft.name,
        );
        uploadedPrimaryImageUrl = imageUrl;
        hoverImageUrl = await _uploadImageToStorage(
          type: ProductImageType.hover,
          productName: draft.name,
        );
        uploadedHoverImageUrl = hoverImageUrl;
      } else {
        imageUrl = await _uploadImageToStorage(
          type: ProductImageType.primary,
          productName: draft.name,
        );
        uploadedPrimaryImageUrl = imageUrl;
        hoverImageUrl = await _uploadImageToStorage(
          type: ProductImageType.hover,
          productName: draft.name,
        );
        uploadedHoverImageUrl = hoverImageUrl;
      }

        final formattedLongDescription =
          draft.longDescription.isEmpty ? draft.description : draft.longDescription;

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
            'metaltype': draft.metalType,
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
        'metal_type': legacyMetalType,
        'purity': '${draft.purityKarat}K',
        'is_available': true,
      });

      await Supabase.instance.client.from('ring_sizes').insert({
        'product_id': productId,
        'size_label': draft.ringSize,
        'size_number': double.tryParse(draft.ringSize),
        'is_available': true,
      });

      final productOptions = <Map<String, dynamic>>[
        {
          'product_id': productId,
          'option_type': 'metal',
          'option_name': 'Metal Type',
          'option_value': draft.metalType,
          'is_available': true,
          'sort_order': 1,
        },
      ];

      if (hasDiamond) {
        productOptions.add({
          'product_id': productId,
          'option_type': 'diamond_type',
          'option_name': 'Diamond Type',
          'option_value': draft.diamondType,
          'is_available': true,
          'sort_order': 2,
        });
      }

      await Supabase.instance.client.from('product_options').insert(productOptions);

      await Supabase.instance.client.from('product_variants').insert({
        'product_id': productId,
        'sku': '$sku-V1',
        'metal': draft.metalType,
        'carat': draft.caratWeight,
        'diamond_type': hasDiamond ? draft.diamondType : 'None',
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
