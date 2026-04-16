import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/tenant_context.dart';

class AddCollectionView extends StatefulWidget {
  const AddCollectionView({
    super.key,
    this.editCollectionId,
    this.preloadedEditRow,
  });

  final int? editCollectionId;
  final Map<String, dynamic>? preloadedEditRow;

  @override
  State<AddCollectionView> createState() => _AddCollectionViewState();
}

class _AddCollectionViewState extends State<AddCollectionView> {
  final _collectionFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  bool _slugManuallyEdited = false;
  bool _isActive = true;
  bool _isSaving = false;
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  Uint8List? _selectedBannerImageBytes;
  String? _selectedBannerImageName;
  String? _existingImageUrl;
  String? _existingBannerImageUrl;

  bool get _isEditMode => widget.editCollectionId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      if (widget.preloadedEditRow != null) {
        _applyPreloadedCollection(widget.preloadedEditRow!);
      } else {
        _loadExistingCollection();
      }
    }
  }

  void _applyPreloadedCollection(Map<String, dynamic> row) {
    _nameController.text = (row['name'] as String? ?? '').trim();
    _slugController.text = (row['slug'] as String? ?? '').trim();
    _subtitleController.text = (row['subtitle'] as String? ?? '').trim();
    _descriptionController.text = (row['description'] as String? ?? '').trim();
    _existingImageUrl = (row['image_url'] as String?)?.trim();
    _existingBannerImageUrl = (row['banner_image_url'] as String?)?.trim();
    _isActive = row['is_active'] as bool? ?? true;
    _sortOrderController.text = ((row['sort_order'] as int?) ?? 0).toString();
    _slugManuallyEdited = true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  String _slugify(String input) {
    final normalized = input.trim().toLowerCase();
    final replaced = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
  }

  Future<void> _loadExistingCollection() async {
    final id = widget.editCollectionId;
    if (id == null) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final tenantId = await TenantContext.requireTenantId();
      final row = await Supabase.instance.client
          .from('collections')
          .select(
            'name, slug, subtitle, description, image_url, banner_image_url, is_active, sort_order',
          )
          .eq('id', id)
          .eq('tenant_id', tenantId)
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text = (row['name'] as String? ?? '').trim();
        _slugController.text = (row['slug'] as String? ?? '').trim();
        _subtitleController.text = (row['subtitle'] as String? ?? '').trim();
        _descriptionController.text = (row['description'] as String? ?? '').trim();
        _existingImageUrl = (row['image_url'] as String?)?.trim();
        _existingBannerImageUrl = (row['banner_image_url'] as String?)?.trim();
        _isActive = row['is_active'] as bool? ?? true;
        _sortOrderController.text = ((row['sort_order'] as int?) ?? 0).toString();
        _slugManuallyEdited = true;
      });
    } on PostgrestException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load collection. ${e.message}')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load collection.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String get _collectionBucket {
    final explicitCollectionBucket = dotenv.env['SUPABASE_COLLECTION_BUCKET']?.trim();
    if (explicitCollectionBucket != null && explicitCollectionBucket.isNotEmpty) {
      return explicitCollectionBucket;
    }

    final productBucket = dotenv.env['SUPABASE_PRODUCT_BUCKET']?.trim();
    if (productBucket != null && productBucket.isNotEmpty) {
      return productBucket;
    }

    return 'goldJEWELLERY';
  }

  Future<void> _pickImage({required bool isBanner}) async {
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
      if (isBanner) {
        _selectedBannerImageBytes = bytes;
        _selectedBannerImageName = file.name;
      } else {
        _selectedImageBytes = bytes;
        _selectedImageName = file.name;
      }
    });
  }

  Future<String> _uploadImageToStorage({
    required Uint8List bytes,
    required String originalName,
    required String slug,
    required String imageType,
  }) async {
    final extParts = originalName.split('.');
    final extension = extParts.length > 1 ? extParts.last.toLowerCase() : 'jpg';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$ts-$slug-$imageType.$extension';
    final filePath = 'products/collections/$fileName';

    await Supabase.instance.client.storage.from(_collectionBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return Supabase.instance.client.storage
        .from(_collectionBucket)
        .getPublicUrl(filePath);
  }

  String? _extractStoragePath(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      return null;
    }

    final bucketIndex = uri.pathSegments.indexOf(_collectionBucket);
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
      await Supabase.instance.client.storage.from(_collectionBucket).remove([path]);
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

  Widget _buildImagePickerField({
    required ThemeData theme,
    required String title,
    required Uint8List? bytes,
    required String? name,
    required String? existingUrl,
    required VoidCallback onPick,
    required VoidCallback onClear,
  }) {
    final hasImage = bytes != null;
    final trimmedExistingUrl = (existingUrl ?? '').trim();
    final hasExistingImage = trimmedExistingUrl.isNotEmpty;
    final hasDisplayImage = hasImage || hasExistingImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
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
                    bytes,
                    fit: BoxFit.cover,
                  ),
                )
              : hasExistingImage
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        trimmedExistingUrl,
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
        if (name != null) ...[
          const SizedBox(height: 8),
          Text(
            name,
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
              onPressed: _isSaving ? null : onPick,
              icon: Icon(hasDisplayImage ? Icons.refresh : Icons.upload_file),
              label: Text(hasDisplayImage ? 'Change Image' : 'Pick Image'),
            ),
            if (hasDisplayImage)
              TextButton.icon(
                onPressed: _isSaving ? null : onClear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _saveCollection() async {
    if (_isSaving) {
      return;
    }

    final form = _collectionFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final name = _nameController.text.trim();
    final slug = _slugController.text.trim().toLowerCase();
    final subtitle = _subtitleController.text.trim();
    final description = _descriptionController.text.trim();
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;
    String? uploadedImageUrl;
    String? uploadedBannerImageUrl;

    try {
      final tenantId = await TenantContext.requireTenantId();
      final normalizedSlug = slug.isNotEmpty ? slug : _slugify(name);

      if (_isEditMode) {
        final collectionId = widget.editCollectionId!;
        final oldImageUrl = (_existingImageUrl ?? '').trim();
        final oldBannerImageUrl = (_existingBannerImageUrl ?? '').trim();

        if (_selectedImageBytes != null && _selectedImageName != null) {
          uploadedImageUrl = await _uploadImageToStorage(
            bytes: _selectedImageBytes!,
            originalName: _selectedImageName!,
            slug: normalizedSlug,
            imageType: 'cover',
          );
        }

        if (_selectedBannerImageBytes != null && _selectedBannerImageName != null) {
          uploadedBannerImageUrl = await _uploadImageToStorage(
            bytes: _selectedBannerImageBytes!,
            originalName: _selectedBannerImageName!,
            slug: normalizedSlug,
            imageType: 'banner',
          );
        }

        final resolvedImageUrl = uploadedImageUrl ?? _existingImageUrl;
        final resolvedBannerImageUrl =
            uploadedBannerImageUrl ?? _existingBannerImageUrl;

        await Supabase.instance.client.from('collections').update({
          'name': name,
          'slug': slug,
          'subtitle': subtitle.isEmpty ? null : subtitle,
          'description': description.isEmpty ? null : description,
          'image_url': (resolvedImageUrl ?? '').trim().isEmpty
              ? null
              : resolvedImageUrl,
          'banner_image_url': (resolvedBannerImageUrl ?? '').trim().isEmpty
              ? null
              : resolvedBannerImageUrl,
          'is_active': _isActive,
          'sort_order': sortOrder,
        }).eq('id', collectionId).eq('tenant_id', tenantId);

        if (uploadedImageUrl != null &&
            oldImageUrl.isNotEmpty &&
            oldImageUrl != uploadedImageUrl) {
          await _deleteUploadedImage(oldImageUrl);
        }
        if (uploadedBannerImageUrl != null &&
            oldBannerImageUrl.isNotEmpty &&
            oldBannerImageUrl != uploadedBannerImageUrl) {
          await _deleteUploadedImage(oldBannerImageUrl);
        }

        messenger.showSnackBar(
          const SnackBar(content: Text('Collection updated successfully.')),
        );
      } else {
        final existingNameRows = await Supabase.instance.client
            .from('collections')
            .select('id')
            .eq('tenant_id', tenantId)
            .ilike('name', name)
            .limit(1);

        final existingSlugRows = await Supabase.instance.client
            .from('collections')
            .select('id')
            .eq('tenant_id', tenantId)
            .eq('slug', slug)
            .limit(1);

        if (existingNameRows.isNotEmpty || existingSlugRows.isNotEmpty) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Collection name or slug already exists in this tenant.',
              ),
            ),
          );
          return;
        }

        if (_selectedImageBytes != null && _selectedImageName != null) {
          uploadedImageUrl = await _uploadImageToStorage(
            bytes: _selectedImageBytes!,
            originalName: _selectedImageName!,
            slug: normalizedSlug,
            imageType: 'cover',
          );
        }

        if (_selectedBannerImageBytes != null && _selectedBannerImageName != null) {
          uploadedBannerImageUrl = await _uploadImageToStorage(
            bytes: _selectedBannerImageBytes!,
            originalName: _selectedBannerImageName!,
            slug: normalizedSlug,
            imageType: 'banner',
          );
        }

        await Supabase.instance.client.from('collections').insert({
          'tenant_id': tenantId,
          'name': name,
          'slug': slug,
          'subtitle': subtitle.isEmpty ? null : subtitle,
          'description': description.isEmpty ? null : description,
          'image_url': uploadedImageUrl,
          'banner_image_url': uploadedBannerImageUrl,
          'is_active': _isActive,
          'sort_order': sortOrder,
        });

        messenger.showSnackBar(
          const SnackBar(content: Text('Collection added successfully.')),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      await _deleteUploadedImage(uploadedImageUrl);
      await _deleteUploadedImage(uploadedBannerImageUrl);
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to save collection. ${e.message}')),
      );
    } catch (_) {
      await _deleteUploadedImage(uploadedImageUrl);
      await _deleteUploadedImage(uploadedBannerImageUrl);
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to save collection. Please try again.')),
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
        title: Text(_isEditMode ? 'Update Collection' : 'Add Collection'),
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
                  key: _collectionFormKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditMode ? 'Update Collection' : 'Create Collection',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF021B44),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Fill in collection details based on your database schema.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5D6A83),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildSectionCard(
                        theme: theme,
                        title: 'Collection Details',
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
                              labelText: 'Collection Name',
                              hintText: 'Example: Bridal Gold',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return 'Collection name is required.';
                              }
                              if (text.length < 2) {
                                return 'Collection name is too short.';
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
                              hintText: 'bridal-gold',
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
                            controller: _subtitleController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Subtitle (optional)',
                              border: OutlineInputBorder(),
                            ),
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
                          _buildImagePickerField(
                            theme: theme,
                            title: 'Collection Image (optional)',
                            bytes: _selectedImageBytes,
                            name: _selectedImageName,
                            existingUrl: _existingImageUrl,
                            onPick: () => _pickImage(isBanner: false),
                            onClear: () {
                              setState(() {
                                _selectedImageBytes = null;
                                _selectedImageName = null;
                                _existingImageUrl = null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          _buildImagePickerField(
                            theme: theme,
                            title: 'Banner Image (optional)',
                            bytes: _selectedBannerImageBytes,
                            name: _selectedBannerImageName,
                            existingUrl: _existingBannerImageUrl,
                            onPick: () => _pickImage(isBanner: true),
                            onClear: () {
                              setState(() {
                                _selectedBannerImageBytes = null;
                                _selectedBannerImageName = null;
                                _existingBannerImageUrl = null;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _sortOrderController,
                            textInputAction: TextInputAction.done,
                            keyboardType: TextInputType.number,
                            onFieldSubmitted: (_) => _saveCollection(),
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
                        title: 'Collection Settings',
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active collection'),
                            subtitle: const Text('Controls if this collection is visible.'),
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
                          onPressed: _isSaving ? null : _saveCollection,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add),
                          label: Text(
                            _isSaving
                                ? 'Saving...'
                                : (_isEditMode ? 'Update Collection' : 'Add Collection'),
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