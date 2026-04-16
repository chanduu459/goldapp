import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/tenant_context.dart';

class AddCategoryView extends StatefulWidget {
  const AddCategoryView({
    super.key,
    this.editCategoryId,
    this.preloadedEditRow,
  });

  final int? editCategoryId;
  final Map<String, dynamic>? preloadedEditRow;

  @override
  State<AddCategoryView> createState() => _AddCategoryViewState();
}

class _AddCategoryViewState extends State<AddCategoryView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  bool _slugManuallyEdited = false;
  bool _isActive = true;
  bool _isSaving = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _existingImageUrl;

  bool get _isEditMode => widget.editCategoryId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      if (widget.preloadedEditRow != null) {
        _applyPreloadedCategory(widget.preloadedEditRow!);
      } else {
        _loadExistingCategory();
      }
    }
  }

  void _applyPreloadedCategory(Map<String, dynamic> row) {
    _nameController.text = (row['name'] as String? ?? '').trim();
    _slugController.text = (row['slug'] as String? ?? '').trim();
    _descriptionController.text = (row['description'] as String? ?? '').trim();
    _existingImageUrl = (row['image_url'] as String?)?.trim();
    _isActive = row['is_active'] as bool? ?? true;
    _sortOrderController.text = ((row['sort_order'] as int?) ?? 0).toString();
    _slugManuallyEdited = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  String _slugify(String input) {
    final normalized = input.trim().toLowerCase();
    final replaced = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _loadExistingCategory() async {
    final id = widget.editCategoryId;
    if (id == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tenantId = await TenantContext.requireTenantId();
      final row = await Supabase.instance.client
          .from('categories')
          .select('name, slug, description, image_url, is_active, sort_order')
          .eq('id', id)
          .eq('tenant_id', tenantId)
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text = (row['name'] as String? ?? '').trim();
        _slugController.text = (row['slug'] as String? ?? '').trim();
        _descriptionController.text = (row['description'] as String? ?? '').trim();
        _existingImageUrl = (row['image_url'] as String?)?.trim();
        _isActive = row['is_active'] as bool? ?? true;
        _sortOrderController.text = ((row['sort_order'] as int?) ?? 0).toString();
        _slugManuallyEdited = true;
      });
    } on PostgrestException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load category. ${e.message}')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load category.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String get _categoryBucket {
    final explicitCategoryBucket = dotenv.env['SUPABASE_CATEGORY_BUCKET']?.trim();
    if (explicitCategoryBucket != null && explicitCategoryBucket.isNotEmpty) {
      return explicitCategoryBucket;
    }

    final productBucket = dotenv.env['SUPABASE_PRODUCT_BUCKET']?.trim();
    if (productBucket != null && productBucket.isNotEmpty) {
      return productBucket;
    }

    return 'goldJEWELLERY';
  }

  Future<void> _pickImage() async {
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
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read selected image file.')),
      );
      return;
    }

    setState(() {
      _selectedImageBytes = bytes;
      _selectedImageName = file.name;
    });
  }

  Future<String> _uploadImageToStorage({required String slug}) async {
    final bytes = _selectedImageBytes;
    final originalName = _selectedImageName;
    if (bytes == null || originalName == null) {
      throw StateError('Please choose an image before saving.');
    }

    final extParts = originalName.split('.');
    final extension = extParts.length > 1 ? extParts.last.toLowerCase() : 'jpg';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$ts-$slug.$extension';
    final filePath = 'products/categories/$fileName';

    await Supabase.instance.client.storage.from(_categoryBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return Supabase.instance.client.storage
        .from(_categoryBucket)
        .getPublicUrl(filePath);
  }

  String? _extractStoragePath(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      return null;
    }

    final bucketIndex = uri.pathSegments.indexOf(_categoryBucket);
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
      await Supabase.instance.client.storage.from(_categoryBucket).remove([path]);
    } catch (_) {
      // Best effort cleanup.
    }
  }

  Widget _buildSectionCard({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF021B44),
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildImagePickerField(ThemeData theme) {
    final selectedImage = _selectedImageBytes;
    final hasImage = selectedImage != null;
    final existingUrl = (_existingImageUrl ?? '').trim();
    final hasExistingImage = existingUrl.isNotEmpty;
    final hasDisplayImage = hasImage || hasExistingImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Category Image (optional)',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF021B44),
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD8DEEA)),
            color: const Color(0xFFF7F9FC),
          ),
          child: hasImage
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    selectedImage,
                    fit: BoxFit.cover,
                  ),
                )
              : hasExistingImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        existingUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.broken_image_outlined),
                        ),
                      ),
                    )
                  : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_outlined, size: 32, color: Color(0xFF7C879D)),
                    SizedBox(height: 8),
                    Text(
                      'No image selected',
                      style: TextStyle(color: Color(0xFF6A7388)),
                    ),
                  ],
                ),
        ),
        if (_selectedImageName != null) ...[
          const SizedBox(height: 8),
          Text(
            _selectedImageName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF5D6A83)),
          ),
        ] else if (hasExistingImage) ...[
          const SizedBox(height: 8),
          Text(
            'Existing image',
            style: theme.textTheme.bodySmall?.copyWith(color: const Color(0xFF5D6A83)),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _isSaving ? null : _pickImage,
              icon: Icon(hasDisplayImage ? Icons.refresh : Icons.upload_file),
              label: Text(hasDisplayImage ? 'Change Image' : 'Pick Image'),
            ),
            if (hasDisplayImage)
              TextButton.icon(
                onPressed: _isSaving
                    ? null
                    : () {
                        setState(() {
                          _selectedImageBytes = null;
                          _selectedImageName = null;
                          _existingImageUrl = null;
                        });
                      },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveCategory() async {
    if (_isSaving) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    final slug = _slugController.text.trim().toLowerCase();
    final description = _descriptionController.text.trim();
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;
    String? uploadedImageUrl;

    try {
      final tenantId = await TenantContext.requireTenantId();
      if (_isEditMode) {
        final categoryId = widget.editCategoryId!;
        final oldImageUrl = (_existingImageUrl ?? '').trim();

        if (_selectedImageBytes != null && _selectedImageName != null) {
          uploadedImageUrl = await _uploadImageToStorage(
            slug: slug.isNotEmpty ? slug : _slugify(name),
          );
        }

        final resolvedImageUrl = uploadedImageUrl ?? _existingImageUrl;

        await Supabase.instance.client.from('categories').update({
          'name': name,
          'slug': slug,
          'description': description.isEmpty ? null : description,
          'image_url': (resolvedImageUrl ?? '').trim().isEmpty
              ? null
              : resolvedImageUrl,
          'is_active': _isActive,
          'sort_order': sortOrder,
        }).eq('id', categoryId).eq('tenant_id', tenantId);

        if (uploadedImageUrl != null &&
            oldImageUrl.isNotEmpty &&
            oldImageUrl != uploadedImageUrl) {
          await _deleteUploadedImage(oldImageUrl);
        }

        messenger.showSnackBar(
          const SnackBar(content: Text('Category updated successfully.')),
        );
      } else {
        final existingNameRows = await Supabase.instance.client
            .from('categories')
            .select('id')
            .eq('tenant_id', tenantId)
            .ilike('name', name)
            .limit(1);

        final existingSlugRows = await Supabase.instance.client
            .from('categories')
            .select('id')
            .eq('tenant_id', tenantId)
            .eq('slug', slug)
            .limit(1);

        if (existingNameRows.isNotEmpty || existingSlugRows.isNotEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Category name or slug already exists in this tenant.',
              ),
            ),
          );
          return;
        }

        if (_selectedImageBytes != null && _selectedImageName != null) {
          uploadedImageUrl = await _uploadImageToStorage(
            slug: slug.isNotEmpty ? slug : _slugify(name),
          );
        }

        await Supabase.instance.client.from('categories').insert({
          'tenant_id': tenantId,
          'name': name,
          'slug': slug,
          'description': description.isEmpty ? null : description,
          'image_url': uploadedImageUrl,
          'is_active': _isActive,
          'sort_order': sortOrder,
        });

        messenger.showSnackBar(
          const SnackBar(content: Text('Category added successfully.')),
        );
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      await _deleteUploadedImage(uploadedImageUrl);
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to save category. ${e.message}')),
      );
    } catch (_) {
      await _deleteUploadedImage(uploadedImageUrl);
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save category. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(_isEditMode ? 'Update Category' : 'Add Category'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE6E7EB)),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140A2A43),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditMode ? 'Update Category' : 'Create Category',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF021B44),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'This creates a category in public.categories and it will appear in Add Product.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5D6A83),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        theme: theme,
                        title: 'Category Details',
                        children: [
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            onChanged: (value) {
                              if (_slugManuallyEdited) {
                                return;
                              }
                              _slugController.text = _slugify(value);
                            },
                            decoration: const InputDecoration(
                              labelText: 'Category Name',
                              hintText: 'Example: Necklaces',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Category name is required.';
                              }
                              if (text.length < 2) {
                                return 'Category name is too short.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _slugController,
                            textInputAction: TextInputAction.next,
                            onChanged: (_) {
                              if (!_slugManuallyEdited) {
                                setState(() {
                                  _slugManuallyEdited = true;
                                });
                              }
                            },
                            decoration: const InputDecoration(
                              labelText: 'Slug',
                              hintText: 'necklaces',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final text = (value ?? '').trim().toLowerCase();
                              if (text.isEmpty) {
                                return 'Slug is required.';
                              }
                              if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$')
                                  .hasMatch(text)) {
                                return 'Use lowercase letters, numbers and hyphens only.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _descriptionController,
                            textInputAction: TextInputAction.newline,
                            minLines: 3,
                            maxLines: 5,
                            decoration: const InputDecoration(
                              labelText: 'Description (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 14),
                          _buildImagePickerField(theme),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _sortOrderController,
                            textInputAction: TextInputAction.done,
                            keyboardType: TextInputType.number,
                            onFieldSubmitted: (_) => _saveCategory(),
                            decoration: const InputDecoration(
                              labelText: 'Sort Order',
                              hintText: '0',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final text = (value ?? '').trim();
                              if (text.isEmpty) {
                                return null;
                              }
                              if (int.tryParse(text) == null) {
                                return 'Sort order must be a number.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _buildSectionCard(
                        theme: theme,
                        title: 'Category Settings',
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active category'),
                            subtitle: const Text('Controls if this category is available.'),
                            value: _isActive,
                            onChanged: _isSaving
                                ? null
                                : (value) {
                                    setState(() {
                                      _isActive = value;
                                    });
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _saveCategory,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.category_outlined),
                          label: Text(
                            _isSaving
                                ? 'Saving...'
                                : (_isEditMode ? 'Update Category' : 'Add Category'),
                          ),
                        ),
                      ),
                    ],
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
