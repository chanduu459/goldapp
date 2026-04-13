import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_collection_view.dart';

class ViewModifyCollectionsView extends StatefulWidget {
  const ViewModifyCollectionsView({super.key});

  @override
  State<ViewModifyCollectionsView> createState() =>
      _ViewModifyCollectionsViewState();
}

class _CollectionItem {
  const _CollectionItem({
    required this.id,
    required this.name,
    required this.slug,
    this.subtitle,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final String name;
  final String slug;
  final String? subtitle;
  final bool isActive;
  final int sortOrder;
}

class _ViewModifyCollectionsViewState extends State<ViewModifyCollectionsView> {
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPreparingEdit = false;
  int? _preparingCollectionId;
  String? _errorMessage;
  List<_CollectionItem> _collections = const [];

  @override
  void initState() {
    super.initState();
    _loadCollections();
  }

  Future<void> _loadCollections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final rows = await Supabase.instance.client
          .from('collections')
          .select('id, name, slug, subtitle, is_active, sort_order')
          .order('sort_order', ascending: true)
          .order('name', ascending: true);

      final mapped = (rows as List<dynamic>).map((row) {
        return _CollectionItem(
          id: row['id'] as int,
          name: (row['name'] as String? ?? '').trim(),
          slug: (row['slug'] as String? ?? '').trim(),
          subtitle: (row['subtitle'] as String?)?.trim(),
          isActive: row['is_active'] as bool? ?? true,
          sortOrder: row['sort_order'] as int? ?? 0,
        );
      }).toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _collections = mapped;
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
        _errorMessage = 'Unable to load collections.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openEditDialog(_CollectionItem item) async {
    if (_isSaving) {
      return;
    }

    if (_isPreparingEdit && _preparingCollectionId == item.id) {
      return;
    }

    if (_isPreparingEdit && _preparingCollectionId != item.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, fetching selected collection data...')),
      );
      return;
    }

    setState(() {
      _isPreparingEdit = true;
      _preparingCollectionId = item.id;
    });

    Map<String, dynamic>? preloadedRow;
    try {
      final row = await Supabase.instance.client
          .from('collections')
          .select(
            'name, slug, subtitle, description, image_url, banner_image_url, is_active, sort_order',
          )
          .eq('id', item.id)
          .single();
      preloadedRow = Map<String, dynamic>.from(row);
    } on PostgrestException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
      return;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load collection data. Please try again.')),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingEdit = false;
          _preparingCollectionId = null;
        });
      }
    }

    if (!mounted) {
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddCollectionView(
          editCollectionId: item.id,
          preloadedEditRow: preloadedRow,
        ),
      ),
    );

    if (!mounted || saved != true) {
      return;
    }

    await _loadCollections();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Collection updated successfully')),
    );
  }

  Future<void> _confirmDeleteCollection(_CollectionItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Collection'),
          content: Text(
            'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
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
      await Supabase.instance.client.from('collections').delete().eq('id', item.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Collection deleted successfully')),
      );
      await _loadCollections();
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
      const message = 'Unable to delete collection.';
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
            colors: [Color(0xFFFFFBF1), Color(0xFFF7F2FF), Color(0xFFF0F8FF)],
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
                        'View / Modify Collections',
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
                      onPressed: _loadCollections,
                      tooltip: 'Refresh collections',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (_isLoading || _isSaving || _isPreparingEdit)
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
                    : _collections.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.collections_bookmark_outlined,
                              size: 38,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 10),
                            const Text('No collections found.'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: _collections.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _collections[index];
                          final isThisPreparing =
                              _isPreparingEdit && _preparingCollectionId == item.id;
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                              title: Text(
                                item.name,
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Slug: ${item.slug}${item.subtitle == null || item.subtitle!.isEmpty ? '' : '\n${item.subtitle}'}',
                                ),
                              ),
                              trailing: Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: 'Edit',
                                    onPressed: _isSaving || isThisPreparing
                                        ? null
                                        : () => _openEditDialog(item),
                                    icon: isThisPreparing
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.edit_outlined),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    onPressed: _isSaving || isThisPreparing
                                        ? null
                                        : () => _confirmDeleteCollection(item),
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
