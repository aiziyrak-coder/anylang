/// Tuman — `RegionModel` tarkibida keladi (`api/v1/locations/regions`) va
/// lokal `districts` jadvalida saqlanadi.
class DistrictModel {
  final int id;
  final String name;

  const DistrictModel({
    required this.id,
    required this.name,
  });

  factory DistrictModel.fromJson(Map<String, dynamic> json) {
    return DistrictModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
    );
  }
}
