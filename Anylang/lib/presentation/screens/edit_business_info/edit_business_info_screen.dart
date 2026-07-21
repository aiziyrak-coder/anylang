import '../../modal/image_picker.dart';
import '../../ui/theme/gradients.dart';
import '../../utils/screen_options/my_action.dart';
import '../../utils/screen_options/screen.dart';
import 'edit_business_info_action.dart';
import 'edit_business_info_content.dart';
import 'edit_business_info_state.dart';

class EditBusinessInfoScreen extends Screen<EditBusinessInfoState, void> {

  EditBusinessInfoScreen() : super(
    mobileContent: EditBusinessInfoContent(),
  );

  @override
  void initState(void payload) {
    // TODO: joriy biznes ma'lumotini backenddan yuklash. Hozircha mock.
    state.country.value = 'Turkiya';
    state.role.value = 'Ishlab chiqaruvchi';
    state.certificates.addAll(['ISO 9001', 'CE Mark']);
    state.factoryImages.addAll([prodBlueGradient, prodBrownGradient]);
  }

  @override
  Future<void> actionHandler(EditBusinessInfoState state, MyAction action) async {
    switch (action) {
      case Back _:
        popBackNavigate();
      case ChangeLogo _:
        await pickImage(context);
        // TODO: tanlangan logotipni yuklash so'rovi.
      case SelectBusinessCountry a:
        state.country.value = a.country;
      case SelectBusinessRole a:
        state.role.value = a.role;
      case RemoveCertificate a:
        state.certificates.remove(a.certificate);
      case AddCertificateRequested _:
        // TODO: sertifikat nomini kiritish dialogi.
        break;
      case AddFactoryImageRequested _:
        final file = await pickImage(context);
        if (file != null) {
          state.factoryImages.add(prodOliveGradient);
        }
      case SaveBusinessInfo _:
        state.isSaving.value = true;
        // TODO: haqiqiy saqlash so'rovi.
        state.isSaving.value = false;
        popBackNavigate();
    }
  }
}
