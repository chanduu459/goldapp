import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../viewmodels/add_product_view_model.dart';

class AddProductView extends StatefulWidget {
  const AddProductView({super.key});

  @override
  State<AddProductView> createState() => _AddProductViewState();
}

class _AddProductViewState extends State<AddProductView> {
  late final AddProductViewModel _viewModel;
  bool _isDraggingPrimary = false;
  bool _isDraggingHover = false;

  @override
  void initState() {
    super.initState();
    _viewModel = AddProductViewModel();
    _viewModel.loadReferenceData();
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
      SnackBar(content: Text('Product "${product.name}" added successfully')),
    );

    Navigator.of(context).pop();
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

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7DFEA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7DFEA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF0C8A7B), width: 1.5),
      ),
    );
  }

  Widget _buildImageUploader({
    required String title,
    required bool isDragging,
    required ProductImageType type,
    required String? fileName,
    required Uint8List? bytes,
    required VoidCallback onEnter,
    required VoidCallback onExit,
  }) {
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
              ? const Color(0xFFDDF5EE)
              : const Color(0xFFF4F8FE),
          border: Border.all(
            color:
                isDragging ? const Color(0xFF0C8A7B) : const Color(0xFFBFD0E8),
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
                color: const Color(0xFF17355C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Drag and drop image here or choose from files',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: const Color(0xFF4F627E),
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
                    color: const Color(0xFF4E627E),
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
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDF9), Color(0xFFE8F4FF), Color(0xFFFCF7E8)],
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
                    borderRadius: BorderRadius.circular(24),
                    color: theme.colorScheme.surface.withValues(alpha: 0.94),
                    border: Border.all(color: const Color(0xFFDCE4F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A0A2A43),
                        blurRadius: 24,
                        offset: Offset(0, 14),
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
                                        IconButton.filledTonal(
                                          onPressed: () => Navigator.of(context).pop(),
                                          icon: const Icon(Icons.arrow_back),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Add Gold Ornament',
                                          maxLines: 2,
                                          softWrap: true,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF08223E),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Schema-aligned product creation with dual images',
                                          softWrap: true,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 13,
                                            color: const Color(0xFF5F6E84),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        IconButton.filledTonal(
                                          onPressed: () => Navigator.of(context).pop(),
                                          icon: const Icon(Icons.arrow_back),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Add Gold Ornament',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 28,
                                                  fontWeight: FontWeight.w700,
                                                  color: const Color(0xFF08223E),
                                                ),
                                              ),
                                              Text(
                                                'Schema-aligned product creation with dual images',
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 13,
                                                  color: const Color(0xFF5F6E84),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                              const SizedBox(height: 24),
                              Wrap(
                                runSpacing: 14,
                                spacing: 14,
                                children: [
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 430, tablet: 360),
                                    child: TextFormField(
                                      controller: _viewModel.nameController,
                                      decoration: _fieldDecoration('Product Name'),
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
                                      decoration: _fieldDecoration('Category'),
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
                                      decoration: _fieldDecoration('Collection')
                                          .copyWith(
                                        helperText: _viewModel.collections.isEmpty
                                            ? 'No collection added. Add your first collection below.'
                                            : 'Select an existing collection.',
                                      ),
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
                                      decoration:
                                          _fieldDecoration('Original Price'),
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
                                      decoration:
                                          _fieldDecoration('Making Charge'),
                                      validator: (value) => _viewModel
                                          .validatePositiveNumber(
                                              value, 'Making Charge'),
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
                                      decoration:
                                          _fieldDecoration('Weight (grams)'),
                                      validator: (value) => _viewModel
                                          .validatePositiveNumber(
                                              value, 'Weight'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 170, tablet: 165),
                                    child: TextFormField(
                                      controller: _viewModel.purityController,
                                      keyboardType: TextInputType.number,
                                      decoration:
                                          _fieldDecoration('Purity (Karat)'),
                                      validator: _viewModel.validatePurity,
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 220, tablet: 200),
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _viewModel.selectedMetalType,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'Gold',
                                          child: Text('Gold'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'White Gold',
                                          child: Text('White Gold'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Rose Gold',
                                          child: Text('Rose Gold'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Platinum',
                                          child: Text('Platinum'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Silver',
                                          child: Text('Silver'),
                                        ),
                                      ],
                                      onChanged: _viewModel.isSubmitting
                                          ? null
                                          : _viewModel.setSelectedMetalType,
                                      decoration: _fieldDecoration('Metal Type'),
                                    ),
                                  ),
                                  SizedBox(
                                    width: adaptiveWidth(desktop: 220, tablet: 200),
                                    child: FilterChip(
                                      selected: _viewModel.hasDiamond,
                                      label: const Text('Diamond'),
                                      onSelected: _viewModel.isSubmitting
                                          ? null
                                          : _viewModel.setHasDiamond,
                                    ),
                                  ),
                                  if (_viewModel.hasDiamond)
                                    SizedBox(
                                      width: adaptiveWidth(desktop: 220, tablet: 200),
                                      child: DropdownButtonFormField<String>(
                                        initialValue:
                                            _viewModel.selectedDiamondType,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'Natural',
                                            child: Text('Natural'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'Lab-Grown',
                                            child: Text('Lab-Grown'),
                                          ),
                                        ],
                                        onChanged: _viewModel.isSubmitting
                                            ? null
                                            : _viewModel
                                                .setSelectedDiamondType,
                                        decoration:
                                            _fieldDecoration('Diamond Type'),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 18,
                                runSpacing: 14,
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
                              const SizedBox(height: 18),
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
                                                      _viewModel
                                                              .selectedAiModelImageId ==
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
                                                              width:
                                                                  double.infinity,
                                                              height: 88,
                                                              fit: BoxFit.cover,
                                                              errorBuilder:
                                                                  (context, error,
                                                                          stackTrace) =>
                                                                      Container(
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
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          Text(
                                                            item.title,
                                                            maxLines: 2,
                                                            overflow: TextOverflow
                                                                .ellipsis,
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
                                              onPressed: (_viewModel
                                                          .isSubmitting ||
                                                      _viewModel
                                                          .isGeneratingAiHoverImage ||
                                                      _viewModel
                                                              .selectedAiModelImageUrl ==
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
                                                        final message = _viewModel
                                                                .errorMessage ??
                                                            'Unable to generate hover image.';
                                                        messenger.showSnackBar(
                                                          SnackBar(
                                                              content: Text(
                                                                  message)),
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
                                                      Icons.auto_awesome),
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
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _viewModel.descriptionController,
                                onChanged: _viewModel.onShortDescriptionChanged,
                                maxLines: 3,
                                decoration: _fieldDecoration('Short Description')
                                    .copyWith(alignLabelWithHint: true),
                                validator: (value) => _viewModel
                                    .validateRequired(value, 'Short Description'),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _viewModel.longDescriptionController,
                                onChanged: _viewModel.onLongDescriptionChanged,
                                maxLines: 4,
                                decoration: _fieldDecoration('Long Description')
                                    .copyWith(alignLabelWithHint: true),
                                validator: (value) => _viewModel
                                    .validateRequired(value, 'Long Description'),
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
                                child: FilledButton(
                                  onPressed: _viewModel.isSubmitting
                                      ? null
                                      : _submit,
                                  child: _viewModel.isSubmitting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(
                                          'Save Product',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontWeight: FontWeight.w700,
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
