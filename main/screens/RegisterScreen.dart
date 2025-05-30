import 'dart:math';

import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';

import '../../extensions/app_text_field.dart';
import '../../extensions/common.dart';
import '../../extensions/decorations.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Widgets.dart';
import '../components/CommonScaffoldComponent.dart';
import '../helper/encrypt_data.dart';
import '../network/RestApis.dart';
import '../services/AuthServices.dart';
import '../utils/dynamic_theme.dart';

class RegisterScreen extends StatefulWidget {
  final String? userType;
  static String tag = '/RegisterScreen';

  RegisterScreen({this.userType});

  @override
  RegisterScreenState createState() => RegisterScreenState();
}

class RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AuthServices authService = AuthServices();
  String countryCode = defaultPhoneCode;

  TextEditingController nameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController phoneController = TextEditingController();
  TextEditingController passController = TextEditingController();
  TextEditingController partnerCodeController = TextEditingController();

  FocusNode nameFocus = FocusNode();
  FocusNode emailFocus = FocusNode();
  FocusNode phoneFocus = FocusNode();
  FocusNode passFocus = FocusNode();
  FocusNode partnerCodeFocus = FocusNode();

  bool isAcceptedTc = false;

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> registerApiCall() async {
    print("Step 1: Validating form...");
    if (formKey.currentState!.validate()) {
      print("Step 2: Saving form state and hiding keyboard...");
      formKey.currentState!.save();
      hideKeyboard(context);
      if (isAcceptedTc) {
        appStore.setLoading(true);
        print("Step 3: Preparing data...");
        String name = nameController.text;
        String username = emailController.text;
        String userType = widget.userType!;
        String contactNumber = '$countryCode ${phoneController.text.trim()}';
        String email = emailController.text.trim();
        String password = passController.text.trim();
        String playerId = getStringAsync(PLAYER_ID).validate();
        String partnerRefCode = partnerCodeController.text.trim();

        print("Step 4: Preparing request map...");
        var request = {
          "name": name,
          "username": username,
          "user_type": userType,
          "contact_number": contactNumber,
          "email": email,
          "password": password,
          "player_id": playerId,
          "partner_referral_code": partnerRefCode
        };

        print("Step 5: Sending API request with: $request");
        try {
          final res = await signUpApi(request).timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print("Step 6: API request timed out.");
              throw Exception(
                  "Sign up request timed out. Please check your internet connection or try again later.");
            },
          );
          print("Step 7: API response received: $res");
          await setValue(USER_TOKEN, res.data!.apiToken.validate());
          await setValue(USER_ID, res.data!.id.validate());
          await authService
              .signUpWithEmailPassword(getContext,
                  lName: res.data!.name,
                  userName: res.data!.username,
                  name: res.data!.name,
                  email: res.data!.email,
                  password: passController.text.trim(),
                  mobileNumber: res.data!.contactNumber,
                  userType: res.data!.userType,
                  userData: res)
              .then((res) async {
            print("Step 8: Firebase sign-up successful");
          }).catchError((e) {
            appStore.setLoading(false);
            print("Step 9: Firebase sign-up error: $e");
            toast(e.toString());
          });
        } catch (e) {
          appStore.setLoading(false);
          print("Step 10: Sign-up error: $e");
          toast(e.toString());
        }
      } else {
        print("Step 11: Terms and conditions not accepted.");
        toast(language.acceptTermService);
      }
    } else {
      print("Step 12: Form validation failed.");
    }
  }

  void generateRandomValues() {
    final random = Random();

    nameController.text = "User${random.nextInt(1000)}";
    emailController.text = "user${random.nextInt(1000)}@example.com";
    phoneController.text = "${random.nextInt(900000000) + 100000000}";
    passController.text = "pass${random.nextInt(10000)}";
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBarTitle:
          "${language.signUp.capitalizeFirstLetter()} ${language.forKey} ${widget.userType == CLIENT ? language.lblUser.toLowerCase() : language.lblDeliveryBoy.toLowerCase()}",
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            physics: BouncingScrollPhysics(),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ElevatedButton(
                  //   onPressed: generateRandomValues,
                  //   child: Text("Generate Random Data"),
                  // ),
                  16.height,
                  Text(language.name, style: primaryTextStyle()),
                  8.height,
                  AppTextField(
                    controller: nameController,
                    textFieldType: TextFieldType.NAME,
                    focus: nameFocus,
                    nextFocus: emailFocus,
                    decoration: commonInputDecoration(),
                    errorThisFieldRequired: language.fieldRequiredMsg,
                  ),
                  16.height,
                  Text(language.email, style: primaryTextStyle()),
                  8.height,
                  AppTextField(
                      controller: emailController,
                      textFieldType: TextFieldType.EMAIL,
                      focus: emailFocus,
                      nextFocus: phoneFocus,
                      decoration: commonInputDecoration(),
                      errorThisFieldRequired: language.fieldRequiredMsg,
                      errorInvalidEmail: language.emailInvalid),
                  16.height,
                  Text(language.contactNumber, style: primaryTextStyle()),
                  8.height,
                  AppTextField(
                    controller: phoneController,
                    textFieldType: TextFieldType.PHONE,
                    focus: phoneFocus,
                    nextFocus: passFocus,
                    decoration: commonInputDecoration(
                      prefixIcon: IntrinsicHeight(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CountryCodePicker(
                              initialSelection: countryCode,
                              showCountryOnly: false,
                              dialogSize: Size(
                                  context.width() - 60, context.height() * 0.6),
                              showFlag: true,
                              showFlagDialog: true,
                              showOnlyCountryWhenClosed: false,
                              alignLeft: false,
                              textStyle: primaryTextStyle(),
                              dialogBackgroundColor:
                                  Theme.of(context).cardColor,
                              barrierColor: Colors.black12,
                              dialogTextStyle: primaryTextStyle(),
                              searchDecoration: InputDecoration(
                                iconColor: Theme.of(context).dividerColor,
                                enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: Theme.of(context).dividerColor)),
                                focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                        color: ColorUtils.colorPrimary)),
                              ),
                              searchStyle: primaryTextStyle(),
                              onInit: (c) {
                                countryCode = c!.dialCode!;
                              },
                              onChanged: (c) {
                                countryCode = c.dialCode!;
                              },
                            ),
                            VerticalDivider(
                                color: Colors.grey.withOpacity(0.5)),
                          ],
                        ),
                      ),
                    ),
                    validator: (value) {
                      if (value!.trim().isEmpty)
                        return language.fieldRequiredMsg;
                      // if (value.trim().length < minContactLength || value.trim().length > maxContactLength) return language.contactLength;
                      return null;
                    },
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                  ),
                  16.height,
                  Text(language.password, style: primaryTextStyle()),
                  8.height,
                  AppTextField(
                    controller: passController,
                    textFieldType: TextFieldType.PASSWORD,
                    focus: passFocus,
                    decoration: commonInputDecoration(),
                    errorThisFieldRequired: language.fieldRequiredMsg,
                    errorMinimumPasswordLength: language.passwordInvalid,
                  ),
                  8.height,
                  Text(language.parnerCode, style: primaryTextStyle()),
                  8.height,
                  AppTextField(
                    controller: partnerCodeController,
                    textFieldType: TextFieldType.NAME,
                    focus: partnerCodeFocus,
                    isValidationRequired: false,
                    decoration: commonInputDecoration(),
                  ),
                  16.height,
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          shape:
                              RoundedRectangleBorder(borderRadius: radius(4)),
                          checkColor: Colors.white,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          focusColor: ColorUtils.colorPrimary,
                          activeColor: ColorUtils.colorPrimary,
                          value: isAcceptedTc,
                          onChanged: (bool? value) async {
                            isAcceptedTc = value!;
                            setState(() {});
                          },
                        ),
                      ),
                      10.width,
                      RichText(
                        text: TextSpan(children: [
                          TextSpan(
                              text: '${language.iAgreeToThe} ',
                              style: secondaryTextStyle()),
                          TextSpan(
                            text: language.termOfService,
                            style: boldTextStyle(
                                color: ColorUtils.colorPrimary, size: 14),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                commonLaunchUrl(mTermAndCondition);
                              },
                          ),
                          TextSpan(text: ' & ', style: secondaryTextStyle()),
                          TextSpan(
                            text: language.privacyPolicy,
                            style: boldTextStyle(
                                color: ColorUtils.colorPrimary, size: 14),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                commonLaunchUrl(mPrivacyPolicy);
                              },
                          ),
                        ]),
                      ).expand()
                    ],
                  ),
                  30.height,
                  commonButton(language.signUp, () {
                    registerApiCall();
                  }, width: context.width()),
                  30.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(language.alreadyHaveAnAccount,
                          style: primaryTextStyle()),
                      4.width,
                      Text(language.signIn,
                              style:
                                  boldTextStyle(color: ColorUtils.colorPrimary))
                          .onTap(() {
                        finish(context);
                      }),
                    ],
                  ),
                  16.height,
                ],
              ),
            ),
          ),
          Observer(
              builder: (context) => loaderWidget().visible(appStore.isLoading)),
        ],
      ),
    );
  }
}
