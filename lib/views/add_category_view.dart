import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddCategoryView extends StatefulWidget {
  const AddCategoryView({super.key});

  @override
  State<AddCategoryView> createState() => _AddCategoryViewState();
}

class _AddCategoryViewState extends State<AddCategoryView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _slugController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _sortOrderController = TextEditingController(text: '0');

  bool _slugManuallyEdited = false;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  String _slugify(String input) {
    final normalized = input.trim().toLowerCase();
    final replaced = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    return replaced.replaceAll(RegExp(r'^-+|-+$'), '');
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
    final imageUrl = _imageUrlController.text.trim();
    final sortOrder = int.tryParse(_sortOrderController.text.trim()) ?? 0;

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
        'is_active': _isActive,
        'sort_order': sortOrder,
      });

      messenger.showSnackBar(
        const SnackBar(content: Text('Category added successfully.')),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
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
        title: const Text('Add Category'),
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
                        'Create Category',
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
                          label: Text(_isSaving ? 'Saving...' : 'Add Category'),
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
