import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCollectionView extends StatefulWidget {
  const AddCollectionView({super.key});

  @override
  State<AddCollectionView> createState() => _AddCollectionViewState();
}

class _AddCollectionViewState extends State<AddCollectionView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _subtitleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _bannerImageUrlController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  bool _slugManuallyEdited = false;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _bannerImageUrlController.dispose();
    _sortOrderController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: const Text('Add Collection'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE6E7EB)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Collection',
                        style: TextStyle(
                          fontSize: 20,
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