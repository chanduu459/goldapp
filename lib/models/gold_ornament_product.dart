class GoldOrnamentProduct {
  const GoldOrnamentProduct({
    required this.productId,
    required this.name,
    required this.categoryId,
    required this.collectionId,
    required this.weightInGrams,
    required this.purityKarat,
    required this.basePrice,
    required this.originalPrice,
    required this.stockQuantity,
    required this.makingCharge,
    required this.imageUrl,
    required this.hoverImageUrl,
    required this.description,
    required this.longDescription,
    required this.isNew,
    required this.isBestSeller,
    required this.isEngravable,
    required this.isActive,
    required this.metaTitle,
    required this.metaDescription,
    required this.metaKeywords,
    required this.metalType,
    required this.ringSize,
    required this.caratWeight,
    required this.diamondType,
    required this.stockNumber,
    required this.widthMm,
    required this.rhodiumFinish,
  });

  final int productId;
  final String name;
  final int categoryId;
  final int? collectionId;
  final double weightInGrams;
  final int? purityKarat;
  final double basePrice;
  final double? originalPrice;
  final int stockQuantity;
  final double makingCharge;
  final String imageUrl;
  final String hoverImageUrl;
  final String description;
  final String longDescription;
  final bool isNew;
  final bool isBestSeller;
  final bool isEngravable;
  final bool isActive;
  final String? metaTitle;
  final String? metaDescription;
  final String? metaKeywords;
  final String metalType;
  final String ringSize;
  final double caratWeight;
  final String diamondType;
  final String stockNumber;
  final double widthMm;
  final bool rhodiumFinish;
}
