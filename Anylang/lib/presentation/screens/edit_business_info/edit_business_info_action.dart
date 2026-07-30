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

class AddExportCountryRequested extends EditBusinessInfoAction {}

class RemoveExportCountry extends EditBusinessInfoAction {
  final String code;
  RemoveExportCountry(this.code);
}

class ToggleIncoterm extends EditBusinessInfoAction {
  final String code;
  ToggleIncoterm(this.code);
}

class TogglePaymentMethod extends EditBusinessInfoAction {
  final String code;
  TogglePaymentMethod(this.code);
}

class ToggleCertificatePreset extends EditBusinessInfoAction {
  final String code;
  ToggleCertificatePreset(this.code);
}

class AddFactoryImageRequested extends EditBusinessInfoAction {}

class OpenFactoryImage extends EditBusinessInfoAction {
  final String url;
  OpenFactoryImage(this.url);
}

class UploadAuditReportRequested extends EditBusinessInfoAction {}

class OpenAuditReport extends EditBusinessInfoAction {}

class RemoveAuditReport extends EditBusinessInfoAction {}

class SaveBusinessInfo extends EditBusinessInfoAction {
  final String companyName;
  final String website;
  final String description;
  final String seoText;
  SaveBusinessInfo({
    required this.companyName,
    required this.website,
    required this.description,
    required this.seoText,
  });
}

class GenerateAiProfile extends EditBusinessInfoAction {
  final String prompt;
  final String companyName;
  GenerateAiProfile(this.prompt, {this.companyName = ''});
}

class OpenTradeAiSettings extends EditBusinessInfoAction {}

class ToggleAiTranslations extends EditBusinessInfoAction {}

class RemoveAiKeyword extends EditBusinessInfoAction {
  final String keyword;
  RemoveAiKeyword(this.keyword);
}
