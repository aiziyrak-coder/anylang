import 'package:sqflite/sqflite.dart';

import '../../domain/models/district_model.dart';
import '../../domain/models/region_model.dart';
import '../core/database_service.dart';

class LocalRegionsRepository {
  final DatabaseService _service;

  LocalRegionsRepository({required DatabaseService databaseService}) : _service = databaseService;


  Future<void> insertRegions(List<RegionModel> regions) async {
    final db = _service.db;

    await db.transaction((txn) async {
      for (final region in regions) {
        // REGION INSERT
        await txn.insert(
          "regions",
          {
            'id': region.id,
            'name': region.name,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

        // DISTRICTS INSERT
        for (final district in region.districts) {
          await txn.insert(
            "districts",
            {
              'id': district.id,
              'name': district.name,
              'region_id': region.id,
            },
            conflictAlgorithm: ConflictAlgorithm.ignore,
          );
        }
      }
    });
  }

  Future<List<RegionModel>> getRegions() async {
    final db = _service.db;

    // 1. regions ni olamiz
    final regionMaps = await db.query("regions");

    // 2. districts ni hammasini bir martada olamiz (OPTIMAL)
    final districtMaps = await db.query("districts");

    // region_id bo‘yicha group qilamiz
    final Map<int, List<DistrictModel>> groupedDistricts = {};

    for (final d in districtMaps) {
      final district = DistrictModel(
        id: d['id'] as int,
        name: d['name'] as String,
      );

      final regionId = d['region_id'] as int;

      groupedDistricts.putIfAbsent(regionId, () => []);
      groupedDistricts[regionId]!.add(district);
    }

    // regionlarni modelga aylantiramiz
    return regionMaps.map((r) {
      final regionId = r['id'] as int;

      return RegionModel(
        id: regionId,
        name: r['name'] as String,
        districts: groupedDistricts[regionId] ?? [],
      );
    }).toList();
  }
}