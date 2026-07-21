import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditBusinessInfoState extends GetxController {
  RxString country = ''.obs;
  RxString role = ''.obs;
  RxList<String> certificates = <String>[].obs;
  RxList<LinearGradient> factoryImages = <LinearGradient>[].obs;
  RxBool isSaving = false.obs;
}
