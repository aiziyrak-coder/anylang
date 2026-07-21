import 'package:dio/dio.dart';

import '../../domain/models/profile_model.dart';
import '../core/buildNetwork/base_result.dart';
import '../core/buildNetwork/network_client.dart';

class ProfileRepository {
  final NetworkClient _client;

  ProfileRepository({required NetworkClient client}) : _client = client;

  Future<BaseResult> getRegions() async {
    return _client.get(
        api: "api/v1/locations/regions"
    );
  }
  Future<BaseResult> updateProfile(ProfileModel profile) async {
    return _client.patch(
        api: "api/v1/users/me/profile",
        data: {
          "full_name" : profile.fullName,
          "birth_date" : profile.birthDate,
          "gender" : profile.gender,
          "region_id" : profile.regionId,
          "district_id" : profile.districtId,
        }
    );
  }

  Future<BaseResult> getMeInfo() async {
    return _client.get(
        api: "api/v1/users/me"
    );
  }

  Future<BaseResult> updateImage({required String image}) async {

    final formData = FormData.fromMap({
      "file": await MultipartFile.fromFile(image),
    });

    return _client.patch(
        api: "api/v1/users/me/profile/picture",
        data: formData
    );
  }
}