import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCollectionView extends StatefulWidget {
  const AddCollectionView({super.key});

  @override
  State<AddCollectionView> createState() => _AddCollectionViewState();
}

class _AddCollectionViewState extends State<AddCollectionView> {
  final _collectionFormKey = GlobalKey<FormState>();
  final _categoryFormKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _bannerImageUrlController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');
  final _categoryNameController = TextEditingController();
  final _categorySlugController = TextEditingController();
  final _categoryDescriptionController = TextEditingController();
  final _categoryImageUrlController = TextEditingController();
  final _categorySortOrderController = TextEditingController(text: '0');

  bool _slugManuallyEdited = false;
  bool _categorySlugManuallyEdited = false;
  bool _isActive = true;
  bool _isCategoryActive = true;
  bool _isSaving = false;
  bool _isSavingCategory = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _bannerImageUrlController.dispose();
    _sortOrderController.dispose();
    _categoryNameController.dispose();
    _categorySlugController.dispose();
    _categoryDescriptionController.dispose();
    _categoryImageUrlController.dispose();
    _categorySortOrderController.dispose();
    super.dispose();
  }

  String _slugify(String input) {
    final normalized = input.trim().toLowerCase();
    final replaced = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
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
    final imageUrl = _imageUrlController.text.trim();
    final bannerImageUrl = _bannerImageUrlController.text.trim();
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    try {
      final existingNameRows = await Supabase.instance.client
          .from('collections')
          .select('id')
          .ilike('name', name)
          .limit(1);

      final existingSlugRows = await Supabase.instance.client
          .from('collections')
          .select('id')
          .eq('slug', slug)
          .limit(1);

      if (existingNameRows.isNotEmpty || existingSlugRows.isNotEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Collection already exists.')),
        );
        return;
      }

      await Supabase.instance.client.from('collections').insert({
        'name': name,
        'slug': slug,
        'subtitle': subtitle.isEmpty ? null : subtitle,
        'description': description.isEmpty ? null : description,
        'image_url': imageUrl.isEmpty ? null : imageUrl,
        'banner_image_url': bannerImageUrl.isEmpty ? null : bannerImageUrl,
        'is_active': _isActive,
        'sort_order': sortOrder,
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Collection added successfully.')),
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } on PostgrestException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to add collection. ${e.message}')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to add collection. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _saveCategory() async {
    if (_isSavingCategory) {
      return;
    }

    final form = _categoryFormKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _isSavingCategory = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final name = _categoryNameController.text.trim();
    final slug = _categorySlugController.text.trim().toLowerCase();
    final description = _categoryDescriptionController.text.trim();
    final imageUrl = _categoryImageUrlController.text.trim();
    final sortOrder = int.tryParse(_categorySortOrderController.text.trim()) ?? 0;

    try {
      final existingNameRows = await Supabase.instance.client
          .from('categories')
          .select('id')
          .ilike('name', name)
          .limit(1);

      final existingSlugRows = await Supabase.instance.client
          .from('categories')
          .select('id')
          .eq('slug', slug)
          .limit(1);

      if (existingNameRows.isNotEmpty || existingSlugRows.isNotEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Category already exists.')),
        );
        return;
      }

      await Supabase.instance.client.from('categories').insert({
        'name': name,
        'slug': slug,
        'description': description.isEmpty ? null : description,
        'image_url': imageUrl.isEmpty ? null : imageUrl,
        'is_active': _isCategoryActive,
        'sort_order': sortOrder,
      });

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Category added successfully. It will appear in Add Product.'),
        ),
      );

      _categoryNameController.clear();
      _categorySlugController.clear();
      _categoryDescriptionController.clear();
      _categoryImageUrlController.clear();
      _categorySortOrderController.text = '0';
      _categorySlugManuallyEdited = false;
      _isCategoryActive = true;
    } on PostgrestException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to add category. ${e.message}')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Unable to add category. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingCategory = false;
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
        title: const Text('Add Collection / Category'),
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
                        'Create Collection',
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
                          if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(text)) {
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
                      TextFormField(
                        controller: _imageUrlController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Image URL (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _bannerImageUrlController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Banner Image URL (optional)',
                          border: OutlineInputBorder(),
                        ),
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
                      const SizedBox(height: 8),
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
                          label: Text(_isSaving ? 'Saving...' : 'Add Collection'),
                        ),
                      ),
                      const SizedBox(height: 30),
                      const Divider(height: 1),
                      const SizedBox(height: 22),
                      Text(
                        'Create Category',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF021B44),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Add categories to public.categories. These will show in Add Product.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF5D6A83),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _categoryFormKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _categoryNameController,
                              textInputAction: TextInputAction.next,
                              onChanged: (value) {
                                if (_categorySlugManuallyEdited) {
                                  return;
                                }
                                _categorySlugController.text = _slugify(value);
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
                              controller: _categorySlugController,
                              textInputAction: TextInputAction.next,
                              onChanged: (_) {
                                if (!_categorySlugManuallyEdited) {
                                  setState(() {
                                    _categorySlugManuallyEdited = true;
                                  });
                                }
                              },
                              decoration: const InputDecoration(
                                labelText: 'Category Slug',
                                hintText: 'necklaces',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                final text = (value ?? '').trim().toLowerCase();
                                if (text.isEmpty) {
                                  return 'Slug is required.';
                                }
                                if (!RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$').hasMatch(text)) {
                                  return 'Use lowercase letters, numbers and hyphens only.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _categoryDescriptionController,
                              textInputAction: TextInputAction.newline,
                              minLines: 2,
                              maxLines: 4,
                              decoration: const InputDecoration(
                                labelText: 'Category Description (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _categoryImageUrlController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Category Image URL (optional)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _categorySortOrderController,
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.number,
                              onFieldSubmitted: (_) => _saveCategory(),
                              decoration: const InputDecoration(
                                labelText: 'Category Sort Order',
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
                            const SizedBox(height: 8),
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Active category'),
                              subtitle: const Text('Controls if this category is available.'),
                              value: _isCategoryActive,
                              onChanged: _isSavingCategory
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _isCategoryActive = value;
                                      });
                                    },
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSavingCategory ? null : _saveCategory,
                                icon: _isSavingCategory
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.category_outlined),
                                label: Text(
                                  _isSavingCategory ? 'Saving...' : 'Add Category',
                                ),
                              ),
                            ),
                          ],
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