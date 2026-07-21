import '../../utils/screen_options/my_action.dart';

/// Faqat Biznes ma'lumot tahrirlash ekraniga xos action'lar.
class EditBusinessInfoAction extends MyAction {}

class ChangeLogo extends EditBusinessInfoAction {}

class SelectBusinessCountry extends EditBusinessInfoAction {
  final String country;
  SelectBusinessCountry(this.country);
}

class SelectBusinessRole extends EditBusinessInfoAction {
  final String role;
  SelectBusinessRole(this.role);
}

class RemoveCertificate extends EditBusinessInfoAction {
  final String certificate;
  RemoveCertificate(this.certificate);
}

class AddCertificateRequested extends EditBusinessInfoAction {}

class AddFactoryImageRequested extends EditBusinessInfoAction {}

class SaveBusinessInfo extends EditBusinessInfoAction {
  final String companyName;
  final String website;
  final String description;
  SaveBusinessInfo({required this.companyName, required this.website, required this.description});
}
