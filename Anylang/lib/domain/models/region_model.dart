import 'district_model.dart';

/// Viloyat + uning tumanlari. `ProfileRepository.getRegions()` javobidan
/// (`api/v1/locations/regions`) yasaladi va `LocalRegionsRepository` orqali
/// sqflite'ga (regions + districts jadvallari) saqlanadi.
class RegionModel {
  final int id;
  final String name;
  final List<DistrictModel> districts;

  const RegionModel({
    required this.id,
    required this.name,
    this.districts = const [],
  });

  factory RegionModel.fromJson(Map<String, dynamic> json) {
    final raw = json['districts'] as List<dynamic>?;

    return RegionModel(
      id: json['id'] as int,
      name: (json['name'] ?? '') as String,
      districts: raw == null
          ? const []
          : raw
              .map((e) => DistrictModel.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  /// getRegions javobi (ro'yxat) uchun qulaylik.
  static List<RegionModel> listFromJson(List<dynamic> json) => json
      .map((e) => RegionModel.fromJson(e as Map<String, dynamic>))
      .toList();
}
