class ManageProduct {
  const ManageProduct({
    required this.id,
    required this.name,
    required this.categoryId,
    required this.categoryName,
    required this.collectionId,
    required this.collectionName,
    required this.basePrice,
    required this.originalPrice,
    required this.imageUrl,
    required this.hoverImageUrl,
    required this.description,
    required this.longDescription,
    required this.stockQuantity,
    required this.isNew,
    required this.isBestSeller,
    required this.isEngravable,
    required this.isActive,
    required this.metalType,
    required this.purity,
    required this.ringSize,
    required this.caratWeight,
    required this.diamondType,
    required this.stockNumber,
  });

  final int id;
  final String name;
  final int categoryId;
  final String categoryName;
  final int? collectionId;
  final String? collectionName;
  final double basePrice;
  final double originalPrice;
  final String imageUrl;
  final String hoverImageUrl;
  final String description;
  final String longDescription;
  final int stockQuantity;
  final bool isNew;
  final bool isBestSeller;
  final bool isEngravable;
  final bool isActive;
  final String metalType;
  final String purity;
  final String ringSize;
  final double caratWeight;
  final String diamondType;
  final String stockNumber;
}

class ManageCategoryOption {
  const ManageCategoryOption({required this.id, required this.name});

  final int id;
  final String name;
}

class ManageCollectionOption {
  const ManageCollectionOption({required this.id, required this.name});

  final int id;
  final String name;
}
