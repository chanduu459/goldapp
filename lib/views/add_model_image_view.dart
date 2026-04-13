import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _CategoryOption {
  const _CategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}

class _ModelImageListItem {
  const _ModelImageListItem({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.imageUrl,
    required this.isActive,
    required this.createdAt,
  });

  final int id;
  final String title;
  final int categoryId;
  final String categoryName;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;
}

class AddModelImageView extends StatefulWidget {
  const AddModelImageView({super.key, this.editModelImageId});

  final int? editModelImageId;

  @override
  State<AddModelImageView> createState() => _AddModelImageViewState();
}

class _AddModelImageViewState extends State<AddModelImageView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  bool _isLoadingCategories = false;
  bool _isLoadingExisting = false;
  bool _isSaving = false;
  bool _isActive = true;
  int? _selectedCategoryId;
  List<_CategoryOption> _categories = const [];
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;
  String? _existingImageUrl;

  bool get _isEditMode => widget.editModelImageId != null;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  String _slugify(String value) {
    return value
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  String get _modelImageBucket {
    final configuredBucket = dotenv.env['SUPABASE_MODEL_IMAGE_BUCKET']?.trim();
    if (configuredBucket != null && configuredBucket.isNotEmpty) {
      return configuredBucket;
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

  Future<String> _uploadImageToStorage({required String title}) async {
    final bytes = _selectedImageBytes;
    final originalName = _selectedImageName;
    if (bytes == null || originalName == null) {
      throw StateError('Please choose an image before saving.');
    }

    final extParts = originalName.split('.');
    final extension = extParts.length > 1 ? extParts.last.toLowerCase() : 'jpg';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName = '$ts-${_slugify(title)}.$extension';
    // Reuse the same top-level folder pattern as product uploads to satisfy
    // existing storage policies that are scoped to products/* paths.
    final filePath = 'products/model-images/$fileName';

    await Supabase.instance.client.storage.from(_modelImageBucket).uploadBinary(
          filePath,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return Supabase.instance.client.storage
        .from(_modelImageBucket)
        .getPublicUrl(filePath);
  }

  String? _extractStoragePath(String imageUrl) {
    final uri = Uri.tryParse(imageUrl);
    if (uri == null) {
      return null;
    }

    final bucketIndex = uri.pathSegments.indexOf(_modelImageBucket);
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
      await Supabase.instance.client.storage.from(_modelImageBucket).remove([path]);
    } catch (_) {
      // Best effort cleanup.
    }
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .eq('is_active', true)
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final mapped = (rows as List<dynamic>)
          .map(
            (row) => _CategoryOption(
              id: row['id'] as int,
              name: ((row['name'] as String?) ?? 'Unnamed').trim(),
            ),
          )
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = mapped;
        _selectedCategoryId = mapped.isNotEmpty ? mapped.first.id : null;
      });
      if (_isEditMode) {
        await _loadExistingModelImage();
      }
    } on PostgrestException {
      final rows = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final mapped = (rows as List<dynamic>)
          .map(
            (row) => _CategoryOption(
              id: row['id'] as int,
              name: ((row['name'] as String?) ?? 'Unnamed').trim(),
            ),
          )
          .toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = mapped;
        _selectedCategoryId = mapped.isNotEmpty ? mapped.first.id : null;
      });
      if (_isEditMode) {
        await _loadExistingModelImage();
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load categories.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
        });
      }
    }
  }

  Future<void> _loadExistingModelImage() async {
    final id = widget.editModelImageId;
    if (id == null) {
      return;
    }

    if (_isLoadingExisting) {
      return;
    }

    setState(() {
      _isLoadingExisting = true;
    });

    try {
      final row = await Supabase.instance.client
          .from('model_images')
          .select('title, category_id, image_url, is_active, sort_order')
          .eq('id', id)
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _titleController.text = (row['title'] as String? ?? '').trim();
        _selectedCategoryId = row['category_id'] as int? ?? _selectedCategoryId;
        _existingImageUrl = (row['image_url'] as String?)?.trim();
        _isActive = row['is_active'] as bool? ?? true;
        _sortOrderController.text = ((row['sort_order'] as int?) ?? 0).toString();
      });
    } on PostgrestException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load model image. ${e.message}')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load model image.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExisting = false;
        });
      }
    }
  }

  Future<void> _openAddedImagesView() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ViewModelImagesView(),
      ),
    );
  }

  Future<void> _saveModelImage() async {
    if (_isSaving) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category.')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final title = _titleController.text.trim();
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;
    String? uploadedImageUrl;

    try {
      if (_isEditMode) {
        final modelImageId = widget.editModelImageId!;
        final oldImageUrl = (_existingImageUrl ?? '').trim();

        if (_selectedImageBytes != null && _selectedImageName != null) {
          uploadedImageUrl = await _uploadImageToStorage(title: title);
        }

        final resolvedImageUrl = uploadedImageUrl ?? _existingImageUrl;

        await Supabase.instance.client.from('model_images').update({
          'title': title,
          'category_id': _selectedCategoryId,
          'image_url': (resolvedImageUrl ?? '').trim().isEmpty
              ? null
              : resolvedImageUrl,
          'is_active': _isActive,
          'sort_order': sortOrder,
        }).eq('id', modelImageId);

        if (uploadedImageUrl != null &&
            oldImageUrl.isNotEmpty &&
            oldImageUrl != uploadedImageUrl) {
          await _deleteUploadedImage(oldImageUrl);
        }
      } else {
        uploadedImageUrl = await _uploadImageToStorage(title: title);

        await Supabase.instance.client.from('model_images').insert({
          'title': title,
          'category_id': _selectedCategoryId,
          'image_url': uploadedImageUrl,
          'is_active': _isActive,
          'sort_order': sortOrder,
        });
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Model image updated successfully.'
                : 'Model image added successfully.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      try {
        await _deleteUploadedImage(uploadedImageUrl);
      } catch (_) {
        // Keep original error for better user feedback.
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to save model image. ${e.message}')),
      );
    } on StorageException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image upload failed. ${e.message}')),
      );
    } on StateError catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      try {
        await _deleteUploadedImage(uploadedImageUrl);
      } catch (_) {
        // Keep original error for better user feedback.
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save model image. Please try again.')),
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
        title: Text(_isEditMode ? 'Update Model Image' : 'Add Model Image'),
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
                        _isEditMode
                            ? 'Update Model Image Entry'
                            : 'Create Model Image Entry',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF021B44),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _openAddedImagesView,
                          icon: const Icon(Icons.visibility_outlined),
                          label: const Text('View Added Images'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Add model image metadata with title and category.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5D6A83),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          hintText: 'Example: Bridal Necklace Front Pose',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          final text = (value ?? '').trim();
                          if (text.isEmpty) {
                            return 'Title is required.';
                          }
                          if (text.length < 2) {
                            return 'Title is too short.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCategoryId,
                        isExpanded: true,
                        items: _categories
                            .map(
                              (item) => DropdownMenuItem<int>(
                                value: item.id,
                                child: Text(item.name),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (_isSaving || _isLoadingCategories)
                            ? null
                            : (value) {
                                setState(() {
                                  _selectedCategoryId = value;
                                });
                              },
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null) {
                            return 'Category is required.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: const Color(0xFFF4F8FE),
                          border: Border.all(color: const Color(0xFFBFD0E8)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Image',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF17355C),
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Choose an image file from your device to upload.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4F627E),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _isSaving ? null : _pickImage,
                                  icon: const Icon(Icons.upload_file),
                                  label: Text(
                                    (_selectedImageBytes != null ||
                                            (_existingImageUrl ?? '').trim().isNotEmpty)
                                        ? 'Change Image'
                                        : 'Choose Image',
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: (_isSaving ||
                                          (_selectedImageBytes == null &&
                                              (_existingImageUrl ?? '').trim().isEmpty))
                                      ? null
                                      : () {
                                          setState(() {
                                            _selectedImageBytes = null;
                                            _selectedImageName = null;
                                            _existingImageUrl = null;
                                          });
                                        },
                                  icon: const Icon(Icons.delete),
                                  label: const Text('Clear'),
                                ),
                              ],
                            ),
                            if (_selectedImageName != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  'Selected: $_selectedImageName',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF4E627E),
                                  ),
                                ),
                              ),
                            if (_selectedImageBytes != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    height: 170,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              )
                            else if ((_existingImageUrl ?? '').trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    _existingImageUrl!,
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _sortOrderController,
                        textInputAction: TextInputAction.done,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Sort Order',
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
                      const SizedBox(height: 10),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active model image'),
                        subtitle: const Text('Controls if this model image is available.'),
                        value: _isActive,
                        onChanged: (_isSaving || _isLoadingExisting)
                            ? null
                            : (value) {
                                setState(() {
                                  _isActive = value;
                                });
                              },
                      ),
                      if (_isLoadingCategories)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                      if (_isLoadingExisting)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: LinearProgressIndicator(minHeight: 3),
                        ),
                      if (!_isLoadingCategories && _categories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'No categories found. Add categories first.',
                            style: TextStyle(color: Color(0xFF8A451A)),
                          ),
                        ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: (_isSaving ||
                              _isLoadingExisting ||
                              _categories.isEmpty ||
                              (!_isEditMode && _selectedImageBytes == null))
                              ? null
                              : _saveModelImage,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined),
                          label: Text(
                            _isSaving
                                ? 'Saving...'
                                : (_isEditMode ? 'Update Model Image' : 'Add Model Image'),
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

class ViewModelImagesView extends StatefulWidget {
  const ViewModelImagesView({super.key});

  @override
  State<ViewModelImagesView> createState() => _ViewModelImagesViewState();
}

class _ViewModelImagesViewState extends State<ViewModelImagesView> {
  bool _isLoading = false;
  String? _errorMessage;
  List<_ModelImageListItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  Future<void> _loadImages() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categoryRows = await Supabase.instance.client
          .from('categories')
          .select('id, name');

      final categoryMap = <int, String>{};
      for (final row in (categoryRows as List<dynamic>)) {
        final id = row['id'] as int?;
        if (id == null) {
          continue;
        }
        final name = ((row['name'] as String?) ?? 'Unknown').trim();
        categoryMap[id] = name;
      }

      final imageRows = await Supabase.instance.client
          .from('model_images')
          .select('id, title, category_id, image_url, is_active, created_at')
          .order('created_at', ascending: false);

      final items = (imageRows as List<dynamic>).map((row) {
        final categoryId = (row['category_id'] as int?) ?? -1;
        return _ModelImageListItem(
          id: (row['id'] as int?) ?? 0,
          title: ((row['title'] as String?) ?? 'Untitled').trim(),
          categoryId: categoryId,
          categoryName: categoryMap[categoryId] ?? 'Category #$categoryId',
          imageUrl: (row['image_url'] as String?)?.trim(),
          isActive: (row['is_active'] as bool?) ?? true,
          createdAt: DateTime.tryParse((row['created_at'] as String?) ?? ''),
        );
      }).toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
      });
    } on PostgrestException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = 'Unable to load model images.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
        title: const Text('Added Model Images'),
        actions: [
          IconButton(
            onPressed: _isLoading ? null : _loadImages,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 460),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEFEF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFF2C2C2)),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF9B1C1C)),
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: _loadImages,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.image_search_outlined,
                                    size: 38,
                                    color: theme.colorScheme.outline,
                                  ),
                                  const SizedBox(height: 10),
                                  const Text('No model images added yet.'),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: _items.length,
                                separatorBuilder: (context, index) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final item = _items[index];
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border:
                                        Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 92,
                                          height: 92,
                                          child: item.imageUrl == null ||
                                                  item.imageUrl!.isEmpty
                                              ? Container(
                                                  color: const Color(0xFFF1F5F9),
                                                  child: const Icon(
                                                    Icons.image_not_supported,
                                                    color: Color(0xFF64748B),
                                                  ),
                                                )
                                              : Image.network(
                                                  item.imageUrl!,
                                                  fit: BoxFit.cover,
                                                    errorBuilder:
                                                      (context, error, stackTrace) => Container(
                                                    color:
                                                        const Color(0xFFF1F5F9),
                                                    child: const Icon(
                                                      Icons.broken_image_outlined,
                                                      color: Color(0xFF64748B),
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Category: ${item.categoryName}',
                                              style: const TextStyle(
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Status: ${item.isActive ? 'Active' : 'Inactive'}',
                                              style: const TextStyle(
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                            if (item.createdAt != null) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'Added: ${item.createdAt!.toLocal()}',
                                                style: const TextStyle(
                                                  color: Color(0xFF475569),
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                            const SizedBox(height: 4),
                                            Text(
                                              'ID: ${item.id}',
                                              style: const TextStyle(
                                                color: Color(0xFF64748B),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
            ),
          ),
        ),
      ),
    );
  }
}
