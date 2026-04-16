import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../viewmodels/add_product_view_model.dart';

class AddProductView extends StatefulWidget {
  const AddProductView({
    super.key,
    this.editProductId,
    this.preloadedViewModel,
  });

  final int? editProductId;
  final AddProductViewModel? preloadedViewModel;

  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  static const Color _ink = Color(0xFF172C52);
  static const Color _inkMuted = Color(0xFF5B6B86);
  static const Color _gold = Color(0xFFC88B10);
  static const Color _goldSoft = Color(0xFFF3E6C9);
  static const Color _surface = Color(0xFFFFFEFB);
  static const Color _surfaceAlt = Color(0xFFFAF6EE);

  late final AddProductViewModel _viewModel;
  bool _isDraggingPrimary = false;
  bool _isDraggingHover = false;

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.preloadedViewModel ?? AddProductViewModel(editProductId: widget.editProductId);
    if (widget.preloadedViewModel == null) {
      _viewModel.loadReferenceData();
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final product = await _viewModel.submit();
    if (!mounted) {
      return;
    }

    if (product == null) {
      final message =
          _viewModel.errorMessage ?? 'Unable to save product. Please retry.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _viewModel.isEditMode
              ? 'Product "${product.name}" updated successfully'
              : 'Product "${product.name}" added successfully',
        ),
      ),
    );

    Navigator.of(context).pop(true);
  }

  Future<void> _onDrop({
    required DropDoneDetails details,
    required ProductImageType type,
  }) async {
    if (details.files.isEmpty) {
      return;
    }

    try {
      final file = details.files.first;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('Dropped file is empty');
      }

      _viewModel.setSelectedImage(type: type, bytes: bytes, name: file.name);
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read dropped image file')),
      );
    }
  }

  InputDecoration _fieldDecoration(
    String label, {
    IconData? icon,
    String? hintText,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      helperText: helperText,
      labelStyle: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: _ink,
      ),
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 15,
        color: const Color(0xFF7E8AA3),
      ),
      helperStyle: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        color: _inkMuted,
      ),
      filled: true,
      fillColor: const Color(0xFFFFFEFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      prefixIcon: icon == null
          ? null
          : Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _goldSoft),
                ),
                child: Icon(icon, size: 20, color: _gold),
              ),
            ),
      prefixIconConstraints: const BoxConstraints(minHeight: 38, minWidth: 52),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE8D9BD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE8D9BD)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFC88B10), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFB3261E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFB3261E), width: 1.6),
      ),
    );
  }

  Widget _buildImageUploader({
    required String title,
    required bool isDragging,
    required ProductImageType type,
    required String? fileName,
    required Uint8List? bytes,
    required String? existingImageUrl,
    required VoidCallback onEnter,
    required VoidCallback onExit,
  }) {
    final existingUrl = (existingImageUrl ?? '').trim();
    final hasExistingUrl = existingUrl.isNotEmpty;

    return DropTarget(
      onDragEntered: (_) => onEnter(),
      onDragExited: (_) => onExit(),
      onDragDone: (details) async {
        onExit();
        await _onDrop(details: details, type: type);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDragging
              ? const Color(0xFFFFF1D7)
              : const Color(0xFFFFF9EC),
          border: Border.all(
            color: isDragging
                ? const Color(0xFFC88B10)
                : const Color(0xFFE6D2A9),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag and drop image here or choose from files',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _viewModel.isSubmitting
                      ? null
                      : () => _viewModel.pickImage(type),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Choose Image'),
                ),
                OutlinedButton.icon(
                  onPressed: bytes == null
                      ? null
                      : () => _viewModel.clearSelectedImage(type),
                  icon: const Icon(Icons.delete),
                  label: const Text('Clear'),
                ),
              ],
            ),
            if (fileName != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Selected: $fileName',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _inkMuted,
                  ),
                ),
              ),
            if (bytes != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    bytes,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            if (bytes == null && hasExistingUrl)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    existingUrl,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 170,
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    String? subtitle,
    IconData? icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null)
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _surfaceAlt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _goldSoft),
                ),
                child: Icon(icon, size: 20, color: _gold),
              ),
            if (icon != null) const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: _inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 1.2,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _gold,
                _gold.withValues(alpha: 0.45),
                _gold.withValues(alpha: 0.1),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFDF9), Color(0xFFFBF7EE), Color(0xFFFFFEFC)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: _surface,
                    border: Border.all(color: const Color(0xFFF0E3CC)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: AnimatedBuilder(
                      animation: _viewModel,
                      builder: (context, _) {
                        return LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 560;
                            final isTablet = constraints.maxWidth < 860;

                            double adaptiveWidth({
                              required double desktop,
                              required double tablet,
                            }) {
                              if (isNarrow) {
                                return constraints.maxWidth;
                              }
                              if (isTablet) {
                                return tablet;
                              }
                              return desktop;
                            }

                            return Form(
                              key: _viewModel.formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isNarrow)
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _viewModel.isEditMode
                                                        ? 'Update Ornament'
                                                        : 'Add Ornament',
                                                    maxLines: 1,
                                                    softWrap: false,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.playfairDisplay(
                                                      fontSize: 30,
                                                      height: 1,
                                                      fontWeight: FontWeight.w700,
                                                      color: _ink,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                 
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFFFFE9BC),
                                                    Color(0xFFF0C868),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                boxShadow: const [
                                                  BoxShadow(
                                                    color: Color(0x33000000),
                                                    blurRadius: 14,
                                                    offset: Offset(0, 7),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.diamond_outlined,
                                                size: 26,
                                                color: Color(0xFF8A5A00),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _viewModel.isEditMode
                                                    ? 'Update Ornament'
                                                    : 'Add Ornament',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.playfairDisplay(
                                                  fontSize: 44,
                                                  height: 1,
                                                  fontWeight: FontWeight.w700,
                                                  color: _ink,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _viewModel.isEditMode
                                                    ? 'Edit existing product details, images, and specifications.'
                                                    : 'Create a new product with dual images and detailed specifications.',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 14,
                                                  color: _inkMuted,
                                                  height: 1.35,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Container(
                                          width: 96,
                                          height: 96,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [
                                                Color(0xFFFFE9BC),
                                                Color(0xFFF0C868),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Color(0x33000000),
                                                blurRadius: 20,
                                                offset: Offset(0, 9),
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.diamond_outlined,
                                            size: 44,
                                            color: Color(0xFF8A5A00),
                                          ),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 14),
                              _buildSectionCard(
                                title: 'Product Details',
                                subtitle:
                                    'Enter essential information like category, pricing, material, and attributes.',
                                icon: Icons.inventory_2_outlined,
                                child: Wrap(
                                  runSpacing: 14,
                                  spacing: 14,
                                  children: [
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 430, tablet: 360),
                                    child: TextFormField(
                                      controller: _viewModel.nameController,
                                      decoration: _fieldDecoration(
                                        'Product Name *',
                                        icon: Icons.workspace_premium_outlined,
                                        hintText:
                                            'e.g., Floral Gold Ring with Diamond',
                                      ),
                                      validator: (value) => _viewModel
                                          .validateRequired(value, 'Product Name'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 220, tablet: 200),
                                    child: DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      initialValue: _viewModel.selectedCategoryId,
                                      items: _viewModel.categories
                                          .map(
                                            (category) => DropdownMenuItem<int>(
                                              value: category.id,
                                              child: Text(
                                                category.name,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: _viewModel.isSubmitting
                                          ? null
                                          : _viewModel.setSelectedCategory,
                                      decoration: _fieldDecoration(
                                        'Category *',
                                        icon: Icons.diamond_outlined,
                                      ),
                                      validator:
                                          _viewModel.validateSelectedCategory,
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 220, tablet: 200),
                                    child: DropdownButtonFormField<int?>(
                                      isExpanded: true,
                                      initialValue: _viewModel.selectedCollectionId,
                                      items: [
                                        const DropdownMenuItem<int?>(
                                          value: null,
                                          child: Text('No Collection'),
                                        ),
                                        ..._viewModel.collections.map(
                                          (collection) => DropdownMenuItem<int?>(
                                            value: collection.id,
                                            child: Text(
                                              collection.name,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: _viewModel.isSubmitting ||
                                              _viewModel.collections.isEmpty
                                          ? null
                                          : _viewModel.setSelectedCollection,
                                      decoration: _fieldDecoration(
                                        'Collection',
                                        icon: Icons.bookmark_border_rounded,
                                        helperText: _viewModel.collections.isEmpty
                                            ? 'No collection added. Add your first collection below.'
                                            : 'Select an existing collection or leave empty.',
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 220, tablet: 200),
                                    child: DropdownButtonFormField<String>(
                                      key: ValueKey<String>(
                                        'metal-${_viewModel.metalTypes.length}-${_viewModel.selectedMetalType}',
                                      ),
                                      initialValue: _viewModel.metalTypes.any(
                                        (item) =>
                                            item.name ==
                                            _viewModel.selectedMetalType,
                                      )
                                          ? _viewModel.selectedMetalType
                                          : null,
                                      items: _viewModel.metalTypes
                                          .map(
                                            (item) => DropdownMenuItem<String>(
                                              value: item.name,
                                              child: Text(item.name),
                                            ),
                                          )
                                          .toList(growable: false),
                                      onChanged: _viewModel.isSubmitting ||
                                              _viewModel.metalTypes.isEmpty
                                          ? null
                                          : _viewModel.setSelectedMetalType,
                                      decoration: _fieldDecoration(
                                        'Metal Type *',
                                        icon: Icons.palette_outlined,
                                      ),
                                      validator: (value) {
                                        if (_viewModel.metalTypes.isEmpty) {
                                          return 'Add metals first';
                                        }
                                        if ((value ?? '').trim().isEmpty) {
                                          return 'Metal Type is required';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 170, tablet: 165),
                                    child: TextFormField(
                                      controller: _viewModel.purityController,
                                      keyboardType: TextInputType.number,
                                      decoration: _fieldDecoration(
                                        'Purity (Karat)',
                                        icon: Icons.shield_outlined,
                                        hintText: 'e.g., 22 (optional)',
                                      ),
                                      validator: _viewModel.validatePurity,
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 170, tablet: 165),
                                    child: TextFormField(
                                      controller: _viewModel.weightController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: _fieldDecoration(
                                        'Weight (grams) *',
                                        icon: Icons.scale_outlined,
                                        hintText: '0.000',
                                      ),
                                      validator: (value) => _viewModel
                                          .validatePositiveNumber(
                                              value, 'Weight'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 170, tablet: 165),
                                    child: TextFormField(
                                      controller: _viewModel.originalPriceController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: _fieldDecoration(
                                        'Original Price (Rs) *',
                                        icon: Icons.currency_rupee_rounded,
                                        hintText: '0.00',
                                      ),
                                      validator: (value) => _viewModel
                                          .validateOptionalPositiveNumber(
                                              value, 'Original Price'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 170, tablet: 165),
                                    child: TextFormField(
                                      controller:
                                          _viewModel.makingChargeController,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                      decoration: _fieldDecoration(
                                        'Making Charge (Rs) *',
                                        icon: Icons.handyman_outlined,
                                        hintText: '0.00',
                                      ),
                                      validator: (value) => _viewModel
                                          .validatePositiveNumber(
                                              value, 'Making Charge'),
                                    ),
                                  ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSectionCard(
                                title: 'Product Flags',
                                subtitle: 'Set badges and visibility options.',
                                icon: Icons.flag_outlined,
                                child: Wrap(
                                  spacing: 12,
                                  runSpacing: 12,
                                  children: [
                                  FilterChip(
                                    selected: _viewModel.isNew,
                                    label: const Text('New Arrival'),
                                    onSelected: _viewModel.setIsNew,
                                  ),
                                  FilterChip(
                                    selected: _viewModel.isBestSeller,
                                    label: const Text('Best Seller'),
                                    onSelected: _viewModel.setIsBestSeller,
                                  ),
                                  FilterChip(
                                    selected: _viewModel.isEngravable,
                                    label: const Text('Engravable'),
                                    onSelected: _viewModel.setIsEngravable,
                                  ),
                                  FilterChip(
                                    selected: _viewModel.isActive,
                                    label: const Text('Active'),
                                    onSelected: _viewModel.setIsActive,
                                  ),
                                  FilterChip(
                                    selected: _viewModel.rhodiumFinish,
                                    label: const Text('Rhodium Finish'),
                                    onSelected: _viewModel.setRhodiumFinish,
                                  ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSectionCard(
                                title: 'Product Images',
                                subtitle:
                                    'Upload normal and hover images, or generate hover image using AI.',
                                icon: Icons.photo_library_outlined,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Image Upload Mode',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF17355C),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SegmentedButton<ProductImageInputMode>(
                                      segments: const [
                                        ButtonSegment<ProductImageInputMode>(
                                          value: ProductImageInputMode.manual,
                                          label: Text('Manual'),
                                          icon: Icon(Icons.upload_file_outlined),
                                        ),
                                        ButtonSegment<ProductImageInputMode>(
                                          value: ProductImageInputMode.ai,
                                          label: Text('AI'),
                                          icon: Icon(Icons.auto_awesome_outlined),
                                        ),
                                      ],
                                      selected: {_viewModel.selectedImageInputMode},
                                      onSelectionChanged: _viewModel.isSubmitting
                                          ? null
                                          : (selection) {
                                              final mode = selection.first;
                                              _viewModel.setSelectedImageInputMode(mode);
                                            },
                                    ),
                                    const SizedBox(height: 12),
                                    if (_viewModel.selectedImageInputMode ==
                                        ProductImageInputMode.manual)
                                      if (isNarrow)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            _buildImageUploader(
                                              title: 'Normal Image',
                                              isDragging: _isDraggingPrimary,
                                              type: ProductImageType.primary,
                                              fileName: _viewModel.selectedPrimaryImageName,
                                              bytes: _viewModel.selectedPrimaryImageBytes,
                                              existingImageUrl:
                                                  _viewModel.existingPrimaryImageUrl,
                                              onEnter: () {
                                                setState(() {
                                                  _isDraggingPrimary = true;
                                                });
                                              },
                                              onExit: () {
                                                setState(() {
                                                  _isDraggingPrimary = false;
                                                });
                                              },
                                            ),
                                            const SizedBox(height: 16),
                                            _buildImageUploader(
                                              title: 'Hover Image',
                                              isDragging: _isDraggingHover,
                                              type: ProductImageType.hover,
                                              fileName: _viewModel.selectedHoverImageName,
                                              bytes: _viewModel.selectedHoverImageBytes,
                                              existingImageUrl:
                                                  _viewModel.existingHoverImageUrl,
                                              onEnter: () {
                                                setState(() {
                                                  _isDraggingHover = true;
                                                });
                                              },
                                              onExit: () {
                                                setState(() {
                                                  _isDraggingHover = false;
                                                });
                                              },
                                            ),
                                          ],
                                        )
                                      else
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: _buildImageUploader(
                                                title: 'Normal Image',
                                                isDragging: _isDraggingPrimary,
                                                type: ProductImageType.primary,
                                                fileName: _viewModel.selectedPrimaryImageName,
                                                bytes: _viewModel.selectedPrimaryImageBytes,
                                                existingImageUrl:
                                                    _viewModel.existingPrimaryImageUrl,
                                                onEnter: () {
                                                  setState(() {
                                                    _isDraggingPrimary = true;
                                                  });
                                                },
                                                onExit: () {
                                                  setState(() {
                                                    _isDraggingPrimary = false;
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: _buildImageUploader(
                                                title: 'Hover Image',
                                                isDragging: _isDraggingHover,
                                                type: ProductImageType.hover,
                                                fileName: _viewModel.selectedHoverImageName,
                                                bytes: _viewModel.selectedHoverImageBytes,
                                                existingImageUrl:
                                                    _viewModel.existingHoverImageUrl,
                                                onEnter: () {
                                                  setState(() {
                                                    _isDraggingHover = true;
                                                  });
                                                },
                                                onExit: () {
                                                  setState(() {
                                                    _isDraggingHover = false;
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        )
                                    else
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          _buildImageUploader(
                                            title: 'Normal Image (Upload)',
                                            isDragging: _isDraggingPrimary,
                                            type: ProductImageType.primary,
                                            fileName: _viewModel.selectedPrimaryImageName,
                                            bytes: _viewModel.selectedPrimaryImageBytes,
                                            existingImageUrl:
                                                _viewModel.existingPrimaryImageUrl,
                                            onEnter: () {
                                              setState(() {
                                                _isDraggingPrimary = true;
                                              });
                                            },
                                            onExit: () {
                                              setState(() {
                                                _isDraggingPrimary = false;
                                              });
                                            },
                                          ),
                                          const SizedBox(height: 12),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF3F7FF),
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(
                                                color: const Color(0xFFCCE0FF),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Select Model Image (Hover)',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFF17355C),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  'Showing model images for the selected category.',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    color: const Color(0xFF4F627E),
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                if (_viewModel.isLoadingAiModelImages)
                                                  const LinearProgressIndicator(
                                                    minHeight: 3,
                                                  )
                                                else if (_viewModel
                                                    .aiModelImages.isEmpty)
                                                  const Text(
                                                    'No model images available for this category. Add model images first.',
                                                    style: TextStyle(
                                                      color: Color(0xFF8A451A),
                                                    ),
                                                  )
                                                else
                                                  Wrap(
                                                    spacing: 10,
                                                    runSpacing: 10,
                                                    children: _viewModel.aiModelImages
                                                        .map((item) {
                                                      final isSelected =
                                                          _viewModel.selectedAiModelImageId ==
                                                              item.id;
                                                      return InkWell(
                                                        borderRadius:
                                                            BorderRadius.circular(12),
                                                        onTap: _viewModel.isSubmitting
                                                            ? null
                                                            : () => _viewModel
                                                                .setSelectedAiModelImage(
                                                                    item),
                                                        child: AnimatedContainer(
                                                          duration: const Duration(
                                                            milliseconds: 150,
                                                          ),
                                                          width: 126,
                                                          padding:
                                                              const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: isSelected
                                                                ? const Color(
                                                                    0xFFE1F5F2)
                                                                : Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                    12),
                                                            border: Border.all(
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFF0C8A7B)
                                                                  : const Color(
                                                                      0xFFD4DEEF),
                                                              width: isSelected
                                                                  ? 1.5
                                                                  : 1,
                                                            ),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              ClipRRect(
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(8),
                                                                child: Image.network(
                                                                  item.imageUrl,
                                                                  width: double.infinity,
                                                                  height: 88,
                                                                  fit: BoxFit.cover,
                                                                  errorBuilder: (
                                                                    context,
                                                                    error,
                                                                    stackTrace,
                                                                  ) => Container(
                                                                    height: 88,
                                                                    color: const Color(
                                                                        0xFFF1F5F9),
                                                                    child: const Center(
                                                                      child: Icon(Icons
                                                                          .broken_image_outlined),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(height: 8),
                                                              Text(
                                                                item.title,
                                                                maxLines: 2,
                                                                overflow:
                                                                    TextOverflow.ellipsis,
                                                                style: GoogleFonts
                                                                    .plusJakartaSans(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight.w600,
                                                                  color: const Color(
                                                                      0xFF17355C),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    }).toList(growable: false),
                                                  ),
                                                const SizedBox(height: 12),
                                                if (_viewModel.selectedAiModelImageUrl ==
                                                    null)
                                                  Text(
                                                    'Select one model image above, then tap Generate Hover Image.',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      color: const Color(0xFF8A451A),
                                                    ),
                                                  )
                                                else ...[
                                                  Text(
                                                    'Second Image Source (Model)',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: const Color(0xFF17355C),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    child: Container(
                                                      width: double.infinity,
                                                      height: 220,
                                                      color: const Color(0xFFF8FAFC),
                                                      child: Image.network(
                                                        _viewModel
                                                            .selectedAiModelImageUrl!,
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (
                                                          context,
                                                          error,
                                                          stackTrace,
                                                        ) => const Center(
                                                          child: Icon(
                                                            Icons.broken_image_outlined,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 12),
                                                FilledButton.icon(
                                                  onPressed: (_viewModel.isSubmitting ||
                                                          _viewModel.isGeneratingAiHoverImage ||
                                                          _viewModel.selectedAiModelImageUrl ==
                                                              null)
                                                      ? null
                                                      : () async {
                                                          final messenger =
                                                              ScaffoldMessenger.of(
                                                                  context);
                                                          final ok = await _viewModel
                                                              .generateAiHoverImage();
                                                          if (!mounted) {
                                                            return;
                                                          }
                                                          if (!ok) {
                                                            final message =
                                                                _viewModel.errorMessage ??
                                                                    'Unable to generate hover image.';
                                                            messenger.showSnackBar(
                                                              SnackBar(
                                                                content: Text(message),
                                                              ),
                                                            );
                                                          }
                                                        },
                                                  icon: _viewModel
                                                          .isGeneratingAiHoverImage
                                                      ? const SizedBox(
                                                          width: 16,
                                                          height: 16,
                                                          child:
                                                              CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                        )
                                                      : const Icon(
                                                          Icons.auto_awesome,
                                                        ),
                                                  label: Text(
                                                    _viewModel
                                                            .isGeneratingAiHoverImage
                                                        ? 'Generating Hover Image...'
                                                        : 'Generate Hover Image',
                                                  ),
                                                ),
                                                const SizedBox(height: 10),
                                                Text(
                                                  'Hover image is generated by merging Normal upload + selected Model image.',
                                                  style: GoogleFonts.plusJakartaSans(
                                                    fontSize: 12,
                                                    color: const Color(0xFF4F627E),
                                                  ),
                                                ),
                                                if (_viewModel
                                                        .selectedHoverImageBytes !=
                                                    null) ...[
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'Generated Hover Preview',
                                                    style:
                                                        GoogleFonts.plusJakartaSans(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color:
                                                          const Color(0xFF17355C),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 8),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                    child: Container(
                                                      width: double.infinity,
                                                      height: 240,
                                                      color: const Color(0xFFF8FAFC),
                                                      child: Image.memory(
                                                        _viewModel
                                                            .selectedHoverImageBytes!,
                                                        fit: BoxFit.contain,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSectionCard(
                                title: 'Descriptions',
                                subtitle:
                                    'Auto-generated from the form and editable before save.',
                                icon: Icons.notes_outlined,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TextFormField(
                                      controller: _viewModel.descriptionController,
                                      onChanged:
                                          _viewModel.onShortDescriptionChanged,
                                      maxLines: 3,
                                      decoration: _fieldDecoration(
                                        'Short Description',
                                        hintText:
                                            'A concise, customer-friendly summary...',
                                      ).copyWith(alignLabelWithHint: true),
                                      validator: (value) => _viewModel
                                          .validateRequired(
                                              value, 'Short Description'),
                                    ),
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller:
                                          _viewModel.longDescriptionController,
                                      onChanged:
                                          _viewModel.onLongDescriptionChanged,
                                      maxLines: 4,
                                        decoration: _fieldDecoration(
                                        'Long Description',
                                        hintText:
                                          'Detailed craftsmanship, materials, and design notes...',
                                        ).copyWith(alignLabelWithHint: true),
                                      validator: (value) => _viewModel
                                          .validateRequired(
                                              value, 'Long Description'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              if (_viewModel.isLoadingReferenceData)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: LinearProgressIndicator(minHeight: 3),
                                ),
                              if (!_viewModel.isLoadingReferenceData &&
                                  _viewModel.categories.isEmpty)
                                Container(
                                  width: double.infinity,
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF2E8),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(0xFFF4C4A6),
                                    ),
                                  ),
                                  child: const Text(
                                    'No categories available. Add categories in Supabase before saving products.',
                                    style: TextStyle(color: Color(0xFF8A451A)),
                                  ),
                                ),
                              SizedBox(
                                width: double.infinity,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFBF8204),
                                        Color(0xFFE7BE61),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x33261100),
                                        blurRadius: 16,
                                        offset: Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: FilledButton.icon(
                                    onPressed: _viewModel.isSubmitting
                                        ? null
                                        : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size.fromHeight(58),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                    ),
                                    icon: _viewModel.isSubmitting
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(Icons.auto_awesome),
                                    label: Text(
                                      _viewModel.isSubmitting
                                        ? (_viewModel.isEditMode
                                          ? 'Updating Product...'
                                          : 'Saving Product...')
                                        : (_viewModel.isEditMode
                                          ? 'Update Product'
                                          : 'Save Product'),
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
