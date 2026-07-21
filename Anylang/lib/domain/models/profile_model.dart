/// Foydalanuvchi profili — `api/v1/users/me` javobidan yasaladi va
/// `ProfileRepository.updateProfile()` uchun ishlatiladi.
class ProfileModel {
  final int id;
  final String fullName;
  final String birthDate;
  final String gender;
  final String? image;
  final String created;
  final String regionName;
  final int regionId;
  final String districtName;
  final int districtId;
  final bool isActive;
  final String role;
  final String phone;

  const ProfileModel({
    required this.id,
    required this.fullName,
    required this.birthDate,
    required this.gender,
    this.image,
    required this.created,
    required this.regionName,
    required this.regionId,
    required this.districtName,
    required this.districtId,
    required this.isActive,
    required this.role,
    required this.phone,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id'] as int,
      fullName: (json['full_name'] ?? '') as String,
      birthDate: (json['birth_date'] ?? '') as String,
      gender: (json['gender'] ?? '') as String,
      image: json['image'] as String?,
      created: (json['created'] ?? '') as String,
      regionName: (json['region_name'] ?? '') as String,
      regionId: (json['region_id'] ?? 0) as int,
      districtName: (json['district_name'] ?? '') as String,
      districtId: (json['district_id'] ?? 0) as int,
      isActive: (json['is_active'] ?? false) as bool,
      role: (json['role'] ?? '') as String,
      phone: (json['phone'] ?? '') as String,
    );
  }
}
