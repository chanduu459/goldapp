import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'add_product_view.dart';
import '../models/manage_product.dart';
import '../viewmodels/view_modify_products_view_model.dart';

class ViewModifyProductsView extends StatefulWidget {
  const ViewModifyProductsView({super.key});

  @override
  State<ViewModifyProductsView> createState() => _ViewModifyProductsViewState();
}

class _ViewModifyProductsViewState extends State<ViewModifyProductsView> {
  late final ViewModifyProductsViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ViewModifyProductsViewModel();
    _viewModel.loadData();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _openEditDialog(ManageProduct product) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AddProductView(editProductId: product.id),
      ),
    );

    if (!mounted || saved != true) {
      return;
    }

    await _viewModel.loadData();
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product updated successfully')),
    );
  }

  Future<void> _confirmDeleteProduct(ManageProduct product) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Product'),
          content: Text(
            'Are you sure you want to delete "${product.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFB91C1C),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!mounted || shouldDelete != true) {
      return;
    }

    final success = await _viewModel.deleteProduct(productId: product.id);
    if (!mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
      return;
    }

    final message = _viewModel.errorMessage ?? 'Delete failed';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            colors: [Color(0xFFF0FDF9), Color(0xFFE8F4FF), Color(0xFFFCF7E8)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _viewModel,
            builder: (context, _) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 680;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  IconButton.filledTonal(
                                    onPressed: () =>
                                        Navigator.of(context).pop(),
                                    icon: const Icon(Icons.arrow_back),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'View / Modify Products',
                                      maxLines: 2,
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
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  onPressed: _viewModel.loadData,
                                  tooltip: 'Refresh products',
                                  icon: const Icon(Icons.refresh),
                                ),
                              ),
                            ],
                          );
                        }

                        return Row(
                          children: [
                            IconButton.filledTonal(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'View / Modify Products',
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
                              onPressed: _viewModel.loadData,
                              tooltip: 'Refresh products',
                              icon: const Icon(Icons.refresh),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  if (_viewModel.isLoading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (_viewModel.errorMessage != null)
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
                          _viewModel.errorMessage!,
                          style: const TextStyle(color: Color(0xFF9F1D1D)),
                        ),
                      ),
                    ),
                  Expanded(
                    child: _viewModel.isLoading
                        ? const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          )
                        : _viewModel.products.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 38,
                                  color: theme.colorScheme.outline,
                                ),
                                const SizedBox(height: 10),
                                const Text('No products found.'),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: _viewModel.products.length,
                            itemBuilder: (context, index) {
                              final product = _viewModel.products[index];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isNarrow = constraints.maxWidth < 640;
                                    final imageWidget = ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: product.imageUrl.isEmpty
                                          ? Container(
                                              width: 56,
                                              height: 56,
                                              color: const Color(0xFFE6EDF8),
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.image_not_supported,
                                              ),
                                            )
                                          : Image.network(
                                              product.imageUrl,
                                              width: 56,
                                              height: 56,
                                              fit: BoxFit.cover,
                                              semanticLabel:
                                                  '${product.name} image',
                                            ),
                                    );

                                    final infoWidget = Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Category: ${product.categoryName} | Price: ${product.originalPrice.toStringAsFixed(2)}',
                                          maxLines: isNarrow ? 3 : 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    );

                                    final actions = Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        FilledButton.tonalIcon(
                                          onPressed: _viewModel.isSaving
                                              ? null
                                              : () => _openEditDialog(product),
                                          icon: const Icon(Icons.edit),
                                          label: const Text('Update'),
                                        ),
                                        FilledButton.icon(
                                          onPressed: _viewModel.isSaving
                                              ? null
                                              : () => _confirmDeleteProduct(
                                                  product,
                                                ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFFB91C1C,
                                            ),
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text('Delete'),
                                        ),
                                      ],
                                    );

                                    if (isNarrow) {
                                      return Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                imageWidget,
                                                const SizedBox(width: 12),
                                                Expanded(child: infoWidget),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            actions,
                                          ],
                                        ),
                                      );
                                    }

                                    return Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Row(
                                        children: [
                                          imageWidget,
                                          const SizedBox(width: 12),
                                          Expanded(child: infoWidget),
                                          const SizedBox(width: 12),
                                          actions,
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
