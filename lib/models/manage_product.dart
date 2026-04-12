class ManageProduct {
  const ManageProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.originalPrice,
    required this.imageUrl,
    required this.description,
    required this.isActive,
  });

  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final double originalPrice;
  final String imageUrl;
  final String description;
  final bool isActive;
}

class ManageCategoryOption {
  const ManageCategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}
