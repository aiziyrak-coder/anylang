import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'deal_mode_models.dart';

class DealModeState extends GetxController {
  final RxInt chatId = 0.obs;
  final RxString title = ''.obs;
  final RxBool loading = true.obs;
  final RxBool saving = false.obs;
  final RxnString loadError = RxnString();
  final Rxn<DealData> deal = Rxn<DealData>();
  final RxList<DealDocumentCandidate> candidates = <DealDocumentCandidate>[].obs;

  late final TextEditingController productCtrl;
  late final TextEditingController priceCtrl;
  late final TextEditingController quantityCtrl;
  late final TextEditingController unitCtrl;
  late final TextEditingController deliveryCtrl;
  late final TextEditingController paymentCtrl;
  final RxString currency = 'USD'.obs;

  @override
  void onInit() {
    super.onInit();
    productCtrl = TextEditingController();
    priceCtrl = TextEditingController();
    quantityCtrl = TextEditingController();
    unitCtrl = TextEditingController();
    deliveryCtrl = TextEditingController();
    paymentCtrl = TextEditingController();
  }

  void applyDeal(DealData? d) {
    deal.value = d;
    if (d == null) return;
    productCtrl.text = d.product;
    priceCtrl.text = d.price;
    quantityCtrl.text = d.quantity;
    unitCtrl.text = d.unit;
    deliveryCtrl.text = d.delivery;
    paymentCtrl.text = d.payment;
    currency.value = d.currency.isEmpty ? 'USD' : d.currency;
  }

  @override
  void onClose() {
    productCtrl.dispose();
    priceCtrl.dispose();
    quantityCtrl.dispose();
    unitCtrl.dispose();
    deliveryCtrl.dispose();
    paymentCtrl.dispose();
    super.onClose();
  }
}
