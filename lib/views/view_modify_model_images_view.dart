import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ViewModifyModelImagesView extends StatefulWidget {
  const ViewModifyModelImagesView({super.key});

  @override
  State<ViewModifyModelImagesView> createState() =>
      _ViewModifyModelImagesViewState();
}

class _CategoryOption {
  const _CategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}

class _ModelImageItem {
  const _ModelImageItem({
    required this.id,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.imageUrl,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final String title;
  final int categoryId;
  final String categoryName;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;
}

class _ViewModifyModelImagesViewState extends State<ViewModifyModelImagesView> {
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorMessage;
  List<_CategoryOption> _categories = const [];
  List<_ModelImageItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final categoryRows = await Supabase.instance.client
          .from('categories')
          .select('id, name')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final categories = (categoryRows as List<dynamic>)
          .map(
            (row) => _CategoryOption(
              id: row['id'] as int,
              name: ((row['name'] as String?) ?? 'Unknown').trim(),
            ),
          )
          .toList(growable: false);

      final categoryMap = <int, String>{
        for (final item in categories) item.id: item.name,
      };

      final imageRows = await Supabase.instance.client
          .from('model_images')
          .select('id, title, category_id, image_url, is_active, sort_order')
          .order('sort_order', ascending: true)
          .order('id', ascending: false);

      final items = (imageRows as List<dynamic>).map((row) {
        final categoryId = row['category_id'] as int? ?? 0;
        return _ModelImageItem(
          id: row['id'] as int,
          title: ((row['title'] as String?) ?? 'Untitled').trim(),
          categoryId: categoryId,
          categoryName: categoryMap[categoryId] ?? 'Category #$categoryId',
          imageUrl: (row['image_url'] as String?)?.trim(),
          isActive: row['is_active'] as bool? ?? true,
          sortOrder: row['sort_order'] as int? ?? 0,
        );
      }).toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _categories = categories;
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

  Future<void> _openEditDialog(_ModelImageItem item) async {
    if (_categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No categories found to update this image.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: item.title);
    final imageUrlController = TextEditingController(text: item.imageUrl ?? '');
    final sortOrderController = TextEditingController(
      text: item.sortOrder.toString(),
    );
    var selectedCategoryId = item.categoryId;
    var isActive = item.isActive;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Update Model Image'),
              content: SizedBox(
                width: MediaQuery.sizeOf(dialogContext).width < 500
                    ? MediaQuery.sizeOf(dialogContext).width - 48
                    : 420,
                child: SingleChildScrollView(
                  child: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) {
                              return 'Title is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<int>(
                          initialValue: selectedCategoryId,
                          items: _categories
                              .map(
                                (c) => DropdownMenuItem<int>(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (value) {
                            if (value != null) {
                              setDialogState(() {
                                selectedCategoryId = value;
                              });
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Category',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: imageUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Image URL',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: sortOrderController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Sort Order',
                          ),
                          validator: (value) {
                            if (int.tryParse((value ?? '').trim()) == null) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Active Model Image'),
                          value: isActive,
                          onChanged: (value) {
                            setDialogState(() {
                              isActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    final isValid = formKey.currentState?.validate() ?? false;
                    if (!isValid) {
                      return;
                    }

                    final success = await _updateModelImage(
                      id: item.id,
                      title: titleController.text,
                      categoryId: selectedCategoryId,
                      imageUrl: imageUrlController.text,
                      isActive: isActive,
                      sortOrder: int.parse(sortOrderController.text.trim()),
                    );

                    if (!dialogContext.mounted) {
                      return;
                    }

                    if (success) {
                      Navigator.of(dialogContext).pop(true);
                    }
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    imageUrlController.dispose();
    sortOrderController.dispose();

    if (!mounted || saved != true) {
      return;
    }

    await _loadData();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Model image updated successfully')),
    );
  }

  Future<bool> _updateModelImage({
    required int id,
    required String title,
    required int categoryId,
    required String imageUrl,
    required bool isActive,
    required int sortOrder,
  }) async {
    if (_isSaving) {
      return false;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.from('model_images').update({
        'title': title.trim(),
        'category_id': categoryId,
        'image_url': imageUrl.trim().isEmpty ? null : imageUrl.trim(),
        'is_active': isActive,
        'sort_order': sortOrder,
      }).eq('id', id);

      return true;
    } on PostgrestException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return false;
    } catch (_) {
      if (mounted) {
        const message = 'Unable to update model image.';
        setState(() {
          _errorMessage = message;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(message)),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _confirmDeleteModelImage(_ModelImageItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Model Image'),
          content: Text(
            'Are you sure you want to delete "${item.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.from('model_images').delete().eq('id', item.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model image deleted successfully')),
      );
      await _loadData();
    } on PostgrestException catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = e.message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      const message = 'Unable to delete model image.';
      setState(() {
        _errorMessage = message;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(message)),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDF9), Color(0xFFF1F5FF), Color(0xFFFFFAEF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'View / Modify Model Images',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: const Color(0xFF08223E),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _loadData,
                      tooltip: 'Refresh model images',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (_isLoading || _isSaving)
                const LinearProgressIndicator(minHeight: 2),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEFEF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFF2C2C2)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Color(0xFF9F1D1D)),
                    ),
                  ),
                ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
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
                            const Text('No model images found.'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: SizedBox(
                                  width: 58,
                                  height: 58,
                                  child: item.imageUrl == null || item.imageUrl!.isEmpty
                                      ? Container(
                                          color: const Color(0xFFF1F5F9),
                                          child: const Icon(Icons.image_not_supported),
                                        )
                                      : Image.network(
                                          item.imageUrl!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(
                                            color: const Color(0xFFF1F5F9),
                                            child: const Icon(Icons.broken_image_outlined),
                                          ),
                                        ),
                                ),
                              ),
                              title: Text(
                                item.title,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Text(
                                'Category: ${item.categoryName}\nStatus: ${item.isActive ? 'Active' : 'Inactive'}',
                              ),
                              isThreeLine: true,
                              trailing: Wrap(
                                spacing: 2,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: _isSaving
                                        ? null
                                        : () => _openEditDialog(item),
                                    icon: const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: _isSaving
                                        ? null
                                        : () => _confirmDeleteModelImage(item),
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Color(0xFFB91C1C),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
