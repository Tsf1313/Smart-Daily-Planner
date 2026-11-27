class SelectedFacility {
  const SelectedFacility({
    required this.id,
    required this.name,
    this.latitude,
    this.longitude,
  });

  final String id;
  final String name;
  final double? latitude;
  final double? longitude;
}
