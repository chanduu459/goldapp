import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'add_metal_price_view.dart';

class ViewModifyMetalPricesView extends StatefulWidget {
  const ViewModifyMetalPricesView({super.key});

  @override
  State<ViewModifyMetalPricesView> createState() =>
      _ViewModifyMetalPricesViewState();
}

class _MetalOption {
  const _MetalOption({
    required this.id,
    required this.name,
    required this.unit,
  });

  final String id;
  final String name;
  final String unit;

  String get label => '$name ($unit)';
}

class _MetalPriceItem {
  const _MetalPriceItem({
    required this.id,
    required this.metalId,
    required this.price,
    required this.priceDate,
  });

  final String id;
  final String metalId;
  final double price;
  final DateTime priceDate;
}

class _ViewModifyMetalPricesViewState extends State<ViewModifyMetalPricesView> {
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isPreparingEdit = false;
  String? _preparingPriceId;
  String? _errorMessage;

  List<_MetalOption> _metals = const [];
  List<_MetalPriceItem> _prices = const [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final metalsRows = await Supabase.instance.client
          .from('metals')
          .select('id, name, unit')
          .order('name', ascending: true);

      final mappedMetals = (metalsRows as List<dynamic>).map((row) {
        return _MetalOption(
          id: row['id'] as String,
          name: (row['name'] as String? ?? '').trim(),
          unit: (row['unit'] as String? ?? '').trim(),
        );
      }).toList(growable: false);

      final pricesRows = await Supabase.instance.client
          .from('metal_prices')
          .select('id, metal_id, price, price_date')
          .order('price_date', ascending: false)
          .order('created_at', ascending: false);

      final mappedPrices = (pricesRows as List<dynamic>).map((row) {
        return _MetalPriceItem(
          id: row['id'] as String,
          metalId: row['metal_id'] as String,
          price: (row['price'] as num?)?.toDouble() ?? 0,
          priceDate:
              DateTime.tryParse(row['price_date'] as String? ?? '') ?? DateTime.now(),
        );
      }).toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _metals = mappedMetals;
        _prices = mappedPrices;
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
        _errorMessage = 'Unable to load metal prices.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _metalLabel(String metalId) {
    for (final metal in _metals) {
      if (metal.id == metalId) {
        return metal.label;
      }
    }
    return 'Unknown Metal';
  }

  Future<void> _openEditDialog(_MetalPriceItem item) async {
    if (_isSaving) {
      return;
    }

    if (_isPreparingEdit && _preparingPriceId == item.id) {
      return;
    }

    if (_isPreparingEdit && _preparingPriceId != item.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait, fetching selected metal price data...')),
      );
      return;
    }

    setState(() {
      _isPreparingEdit = true;
      _preparingPriceId = item.id;
    });

    List<Map<String, dynamic>>? preloadedMetals;
    Map<String, dynamic>? preloadedRow;
    try {
      final metalsRows = await Supabase.instance.client
          .from('metals')
          .select('id, name, unit')
          .order('name', ascending: true);

      final row = await Supabase.instance.client
          .from('metal_prices')
          .select('metal_id, price, price_date')
          .eq('id', item.id)
          .single();

      preloadedMetals = (metalsRows as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList(growable: false);
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
          const SnackBar(content: Text('Unable to load metal price data. Please try again.')),
        );
      }
      return;
    } finally {
      if (mounted) {
        setState(() {
          _isPreparingEdit = false;
          _preparingPriceId = null;
        });
      }
    }

    if (!mounted) {
      return;
    }

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddMetalPriceView(
          editMetalPriceId: item.id,
          preloadedMetals: preloadedMetals,
          preloadedEditRow: preloadedRow,
        ),
      ),
    );

    if (!mounted || saved != true) {
      return;
    }

    await _loadInitialData();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Updated successfully')),
    );
  }

  Future<void> _confirmDeletePrice(_MetalPriceItem item) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Metal Price'),
          content: Text(
            'Are you sure you want to delete the price for "${_metalLabel(item.metalId)}" on ${_formatDate(item.priceDate)}?',
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
      await Supabase.instance.client.from('metal_prices').delete().eq('id', item.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metal price deleted successfully')),
      );
      await _loadInitialData();
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
      const message = 'Unable to delete metal price.';
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
                        'View / Modify Metal Prices',
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
                      onPressed: _loadInitialData,
                      tooltip: 'Refresh prices',
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
                    : _prices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.price_change_outlined,
                              size: 38,
                              color: theme.colorScheme.outline,
                            ),
                            const SizedBox(height: 10),
                            const Text('No metal prices found.'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                        itemCount: _prices.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = _prices[index];
                          final isThisPreparing =
                              _isPreparingEdit && _preparingPriceId == item.id;
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: ListTile(
                              contentPadding:
                                  const EdgeInsets.fromLTRB(16, 10, 12, 10),
                              title: Text(
                                _metalLabel(item.metalId),
                                style: const TextStyle(fontWeight: FontWeight.w700),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  'Price: ${item.price.toStringAsFixed(2)} | Date: ${_formatDate(item.priceDate)}',
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
                                        : () => _confirmDeletePrice(item),
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
