import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/tenant_context.dart';

class AddMetalView extends StatefulWidget {
  const AddMetalView({
    super.key,
    this.editMetalId,
    this.preloadedEditRow,
  });

  final String? editMetalId;
  final Map<String, dynamic>? preloadedEditRow;

  @override
  State<AddMetalView> createState() => _AddMetalViewState();
}

class _AddMetalViewState extends State<AddMetalView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();

  bool _isSaving = false;
  bool _isLoadingExisting = false;
  String? _errorMessage;

  bool get _isEditMode => widget.editMetalId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      if (widget.preloadedEditRow != null) {
        _applyPreloadedMetal(widget.preloadedEditRow!);
      } else {
        _loadExistingMetal();
      }
    }
  }

  void _applyPreloadedMetal(Map<String, dynamic> row) {
    _nameController.text = (row['name'] as String? ?? '').trim();
    _unitController.text = (row['unit'] as String? ?? '').trim();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingMetal() async {
    final id = widget.editMetalId;
    if (id == null || _isLoadingExisting) {
      return;
    }

    setState(() {
      _isLoadingExisting = true;
      _errorMessage = null;
    });

    try {
      final tenantId = await TenantContext.requireTenantId();
      final row = await Supabase.instance.client
          .from('metals')
          .select('name, unit')
          .eq('id', id)
          .eq('tenant_id', tenantId)
          .single();

      if (!mounted) {
        return;
      }

      setState(() {
        _nameController.text = (row['name'] as String? ?? '').trim();
        _unitController.text = (row['unit'] as String? ?? '').trim();
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
        _errorMessage = 'Unable to load metal.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExisting = false;
        });
      }
    }
  }

  Future<void> _saveMetal() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _isSaving || _isLoadingExisting) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final tenantId = await TenantContext.requireTenantId();
      if (_isEditMode) {
        await Supabase.instance.client.from('metals').update({
          'name': _nameController.text.trim(),
          'unit': _unitController.text.trim(),
        }).eq('id', widget.editMetalId!).eq('tenant_id', tenantId);
      } else {
        await Supabase.instance.client.from('metals').insert({
          'tenant_id': tenantId,
          'name': _nameController.text.trim(),
          'unit': _unitController.text.trim(),
        });
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? 'Metal updated successfully.' : 'Metal added successfully.',
          ),
        ),
      );

      if (_isEditMode) {
        Navigator.of(context).pop(true);
      } else {
        _nameController.clear();
        _unitController.clear();
      }
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
        _errorMessage = 'Unable to add metal.';
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
            colors: [Color(0xFFFFFBF1), Color(0xFFF3FFFD), Color(0xFFEFF5FF)],
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
                        _isEditMode ? 'Update Metal' : 'Add Metal',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 24,
                          color: const Color(0xFF08223E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isSaving) const LinearProgressIndicator(minHeight: 2),
              if (_isLoadingExisting) const LinearProgressIndicator(minHeight: 2),
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
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Metal Name',
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Metal Name is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _unitController,
                              decoration: const InputDecoration(
                                labelText: 'Unit',
                              ),
                              validator: (value) {
                                if ((value ?? '').trim().isEmpty) {
                                  return 'Unit is required';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: (_isSaving || _isLoadingExisting)
                                    ? null
                                    : _saveMetal,
                                icon: const Icon(Icons.save_outlined),
                                label: Text(_isEditMode ? 'Update Metal' : 'Save Metal'),
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
