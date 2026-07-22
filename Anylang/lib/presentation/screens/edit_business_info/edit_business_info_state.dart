import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditBusinessInfoState extends GetxController {
  RxString companyName = ''.obs;
  RxString country = ''.obs;
  RxString role = ''.obs;
  RxString website = ''.obs;
  RxString description = ''.obs;
  RxList<String> certificates = <String>[].obs;
  RxList<LinearGradient> factoryImages = <LinearGradient>[].obs;
  RxBool isSaving = false.obs;
  final RxnString logoUrl = RxnString();
}
