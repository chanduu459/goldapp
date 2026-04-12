import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddMetalPriceView extends StatefulWidget {
  const AddMetalPriceView({super.key});

  @override
  State<AddMetalPriceView> createState() => _AddMetalPriceViewState();
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

class _AddMetalPriceViewState extends State<AddMetalPriceView> {
  final _formKey = GlobalKey<FormState>();
  final _priceController = TextEditingController();

  bool _isLoadingMetals = false;
  bool _isSaving = false;
  String? _errorMessage;

  List<_MetalOption> _metals = const [];
  String? _selectedMetalId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadMetals();
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  Future<void> _loadMetals() async {
    setState(() {
      _isLoadingMetals = true;
      _errorMessage = null;
    });

    try {
      final rows = await Supabase.instance.client
          .from('metals')
          .select('id, name, unit')
          .order('name', ascending: true);

      final mapped = (rows as List<dynamic>).map((row) {
        return _MetalOption(
          id: row['id'] as String,
          name: (row['name'] as String? ?? '').trim(),
          unit: (row['unit'] as String? ?? '').trim(),
        );
      }).toList(growable: false);

      if (!mounted) {
        return;
      }

      setState(() {
        _metals = mapped;
        if (_selectedMetalId == null && mapped.isNotEmpty) {
          _selectedMetalId = mapped.first.id;
        }
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
        _errorMessage = 'Unable to load metals.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMetals = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _selectedDate = picked;
    });
  }

  Future<void> _saveMetalPrice() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSaving || _selectedMetalId == null) {
      return;
    }

    final parsedPrice = double.parse(_priceController.text.trim());

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.from('metal_prices').insert({
        'metal_id': _selectedMetalId,
        'price': parsedPrice,
        'price_date': _formatDate(_selectedDate),
      });

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metal price added successfully.')),
      );

      _priceController.clear();
      setState(() {
        _selectedDate = DateTime.now();
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
        _errorMessage = 'Unable to add metal price.';
      });
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFFBF1), Color(0xFFF4F9FF), Color(0xFFF2F7FF)],
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
                        'Add Metal Price',
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
                      onPressed: _loadMetals,
                      tooltip: 'Refresh metals',
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ),
              if (_isSaving || _isLoadingMetals)
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedMetalId,
                              items: _metals
                                  .map(
                                    (metal) => DropdownMenuItem<String>(
                                      value: metal.id,
                                      child: Text(metal.label),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: _isSaving
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedMetalId = value;
                                      });
                                    },
                              decoration: const InputDecoration(
                                labelText: 'Metal',
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a metal';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Price',
                              ),
                              validator: (value) {
                                if (double.tryParse((value ?? '').trim()) ==
                                    null) {
                                  return 'Enter a valid price';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Price Date'),
                              subtitle: Text(_formatDate(_selectedDate)),
                              trailing: OutlinedButton.icon(
                                onPressed: _isSaving ? null : _pickDate,
                                icon: const Icon(Icons.calendar_today_outlined),
                                label: const Text('Choose'),
                              ),
                            ),
                            if (_metals.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'Add at least one metal before adding prices.',
                                  style: TextStyle(color: Color(0xFF7A869A)),
                                ),
                              ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isSaving || _metals.isEmpty
                                    ? null
                                    : _saveMetalPrice,
                                icon: const Icon(Icons.save_outlined),
                                label: const Text('Save Metal Price'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
