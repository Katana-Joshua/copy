import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/screens/VerificationListScreen.dart';
import '../../main/utils/dynamic_theme.dart';
import '../../main/utils/custom_store_checker.dart';
import '../../delivery/fragment/DHomeFragment.dart';
import '../../extensions/app_text_field.dart';
import '../../extensions/common.dart';
import '../../extensions/confirmation_dialog.dart';
import '../../extensions/decorations.dart';
import '../../extensions/extension_util/device_extensions.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/network/RestApis.dart';
import '../../main/screens/ForgotPasswordScreen.dart';
import '../../main/screens/RegisterScreen.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Widgets.dart';
import '../../user/screens/DashboardScreen.dart';
import '../helper/encrypt_data.dart';
import '../models/CityListModel.dart';
import '../services/AuthServices.dart';
import '../utils/Images.dart';
import 'UserCitySelectScreen.dart';

class LoginScreen extends StatefulWidget {
  static String tag = '/LoginScreen';

  @override
  LoginScreenState createState() => LoginScreenState();
}

class LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();
  AuthServices authService = AuthServices();

  TextEditingController emailController = TextEditingController();
  TextEditingController passController = TextEditingController();

  FocusNode emailFocus = FocusNode();
  FocusNode passFocus = FocusNode();

  bool mIsCheck = false;

  bool isAcceptedTc = false;
  String userType = CLIENT;
  int? isDemoSelected;

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    if (getStringAsync(PLAYER_ID).isEmpty) {
      await saveOneSignalPlayerId().then((value) {
        //
      });
    }
    mIsCheck = getBoolAsync(REMEMBER_ME, defaultValue: false);
    if (mIsCheck) {
      emailController.text = getStringAsync(USER_EMAIL);
      passController.text = getStringAsync(USER_PASSWORD);
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> loginApiCall() async {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      hideKeyboard(context);
      if (isAcceptedTc) {
        appStore.setLoading(true);

        try {
          print("Starting login...");
          String email = emailController.text.trim();
          String password = passController.text.trim();
          String playerId = getStringAsync(PLAYER_ID).validate();

          Map req = {
            "email": email,
            "password": password,
            "player_id": playerId,
          };

          print("Calling logInApi with: $req");
          final response = await logInApi(req).timeout(
            Duration(seconds: 10),
            onTimeout: () {
              throw Exception(
                  "Login request timed out. Please check your internet connection or try again later.");
            },
          );
          print("logInApi response: $response");

          if (response.data != null) {
            print("Calling Firebase signInWithEmailPassword...");
            await authService.signInWithEmailPassword(
              context,
              email: email,
              password: password,
            );
            print("Firebase sign-in successful");
            appStore.setLoading(false);

            if (response.data!.userType != CLIENT &&
                response.data!.userType != DELIVERY_MAN) {
              print("User type not allowed, showing confirm dialog");
              showConfirmDialogCustom(
                context,
                title: language.logoutConfirmationMsg,
                positiveText: language.yes,
                primaryColor: ColorUtils.colorPrimary,
                showCancelButton: false,
                onAccept: (v) async {
                  await logout(context, isFromLogin: true);
                },
              );
            } else {
              appStore.setUserType(response.data!.userType.toString());
              print("User type set: ${response.data!.userType}");
              if (response.data!.status == 1) {
                print("User status is 1, updating user status...");
                await updateUserStatus({
                  "id": response.data!.id,
                  "uid": response.data!.uid,
                });

                if (response.data!.emailVerifiedAt.isEmptyOrNull ||
                    response.data!.otpVerifyAt.isEmptyOrNull ||
                    (response.data!.documentVerifiedAt.isEmptyOrNull &&
                        response.data!.userType == DELIVERY_MAN)) {
                  print(
                      "User needs verification, launching VerificationListScreen");
                  VerificationListScreen(isSignIn: true).launch(context);
                } else if (response.data!.countryId != null &&
                    response.data!.cityId != null) {
                  print("Getting country and city details...");
                  await getCountryDetailApiCall(
                      response.data!.countryId.validate());
                  getCityDetailApiCall(response.data!.cityId.validate());
                } else {
                  print("Launching UserCitySelectScreen");
                  UserCitySelectScreen().launch(context, isNewTask: true);
                }
              } else {
                print("User not approved");
                toast(language.userNotApproveMsg);
                await logout(context, isDeleteAccount: true);
              }
            }

            // Update store checker data
            String source = await updateStoreCheckerData();
            if (response.data?.id != null) {
              print("Getting user detail for id: ${response.data!.id}");
              await getUserDetail(response.data!.id!).then((value) async {
                if (value.deliverymanVehicleHistory != null) {
                  setValue(
                      VEHICLE, value.deliverymanVehicleHistory![0].toJson());
                }
                appStore.setReferralCode(value.referralCode.validate());
                if (value.app_source.isEmptyOrNull ||
                    value.app_source != source) {
                  await updateUserStatus(
                      {"id": response.data!.id!, "app_source": source});
                }
              });
            }
          } else {
            print("No data in response");
            toast("Login failed: No data received.");
          }
        } catch (e) {
          appStore.setLoading(false);
          print("Login error: $e");
          toast(e.toString());
        }
      } else {
        toast(language.acceptTermService);
      }
    }
  }

  Future<String> updateStoreCheckerData() async {
    InstallationSource installationSource;
    try {
      installationSource = await CustomStoreChecker.getSource();
    } on PlatformException {
      installationSource = InstallationSource.UNKNOWN;
    }

    // Set source text state
    switch (installationSource) {
      case InstallationSource.PLAY_STORE:
        return PLAY_STORE;
      case InstallationSource.GOOGLE_PACKAGE_INSTALLER:
        return GOOGLE_PACKAGE_INSTALLER;
      case InstallationSource.RUSTORE:
        return RUSTORE;
      case InstallationSource.LOCAL_SOURCE:
        return LOCAL_SOURCE;
      case InstallationSource.AMAZON_STORE:
        return AMAZON_STORE;
      case InstallationSource.HUAWEI_APP_GALLERY:
        return HUAWEI_APP_GALLERY;
      case InstallationSource.SAMSUNG_GALAXY_STORE:
        return SAMSUNG_GALAXY_STORE;
      case InstallationSource.SAMSUNG_SMART_SWITCH_MOBILE:
        return SAMSUNG_SMART_SWITCH_MOBILE;
      case InstallationSource.XIAOMI_GET_APPS:
        return XIAOMI_GET_APPS;
      case InstallationSource.OPPO_APP_MARKET:
        return OPPO_APP_MARKET;
      case InstallationSource.VIVO_APP_STORE:
        return VIVO_APP_STORE;
      case InstallationSource.OTHER_SOURCE:
        return OTHER_SOURCE;
      case InstallationSource.APP_STORE:
        return APP_STORE;
      case InstallationSource.TEST_FLIGHT:
        return TEST_FLIGHT;
      case InstallationSource.UNKNOWN:
        return UNKNOWN_SOURCE;
    }
  }

  getCountryDetailApiCall(int countryId) async {
    await getCountryDetail(countryId).then((value) {
      setValue(COUNTRY_DATA, value.data!.toJson());
    }).catchError((error) {});
  }

  getCityDetailApiCall(int cityId) async {
    await getCityDetail(cityId).then((value) async {
      await setValue(CITY_DATA, value.data!.toJson());
      if (CityModel.fromJson(getJSONAsync(CITY_DATA))
          .name
          .validate()
          .isNotEmpty) {
        if (getBoolAsync(OTP_VERIFIED) &&
            getBoolAsync(EMAIL_VERIFIED) &&
            (getBoolAsync(IS_VERIFIED_DELIVERY_MAN) ||
                getStringAsync(USER_TYPE) == CLIENT)) {
          if (getStringAsync(USER_TYPE) == CLIENT) {
            DashboardScreen().launch(context, isNewTask: true);
          } else {
            // DeliveryDashBoard().launch(context, isNewTask: true);
            DHomeFragment().launch(context, isNewTask: true);
          }
        } else {
          VerificationListScreen().launch(context, isNewTask: true);
          // VerificationScreen().launch(context, isNewTask: true);
        }
      } else {
        UserCitySelectScreen().launch(context, isNewTask: true);
      }
    }).catchError((error) {
      if (error.toString() == CITY_NOT_FOUND_EXCEPTION) {
        UserCitySelectScreen().launch(getContext,
            isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
      }
    });
  }

  void googleSignIn() async {
    hideKeyboard(context);
    appStore.setLoading(true);

    await authService.signInWithGoogle(userType: userType).then((value) async {
      appStore.setLoading(false);
      await setValue(USER_PASSWORD, passController.text);
      await setValue(LOGIN_TYPE, LoginTypeGoogle);
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
      print(e.toString());
    });
  }

  appleLoginApi() async {
    hideKeyboard(context);
    appStore.setLoading(true);
    await authService.appleLogIn(userType).then((value) {
      appStore.setLoading(false);
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appStore.isDarkMode
          ? ColorUtils.scaffoldSecondaryDark
          : ColorUtils.colorPrimaryLight,
      appBar: commonAppBarWidget(language.signIn, showBack: false),
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
                  16.height,
                  Text(language.email, style: primaryTextStyle()),
                  8.height,
                  AppTextField(
                    controller: emailController,
                    textFieldType: TextFieldType.EMAIL,
                    focus: emailFocus,
                    nextFocus: passFocus,
                    decoration: commonInputDecoration(),
                    errorThisFieldRequired: language.fieldRequiredMsg,
                    errorInvalidEmail: language.emailInvalid,
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
                  16.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: Checkbox(
                              shape: RoundedRectangleBorder(
                                  borderRadius: radius(4)),
                              checkColor: Colors.white,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              focusColor: ColorUtils.colorPrimary,
                              activeColor: ColorUtils.colorPrimary,
                              value: mIsCheck,
                              onChanged: (bool? value) async {
                                mIsCheck = value!;
                                if (!mIsCheck) {
                                  removeKey(REMEMBER_ME);
                                }
                                setState(() {});
                              },
                            ),
                          ),
                          10.width,
                          Text(language.rememberMe, style: primaryTextStyle())
                        ],
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: Text(language.forgotPasswordQue,
                                style: boldTextStyle(
                                    color: ColorUtils.colorPrimary))
                            .onTap(() {
                          ForgotPasswordScreen().launch(context);
                        }),
                      ),
                    ],
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
                  commonButton(
                    language.signIn,
                    () {
                      loginApiCall();
                    },
                    width: context.width(),
                  ),
                  32.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(language.doNotHaveAccount,
                          style: primaryTextStyle()),
                      4.width,
                      Text(language.signUp,
                              style:
                                  boldTextStyle(color: ColorUtils.colorPrimary))
                          .onTap(() {
                        RegisterScreen(
                          userType: CLIENT,
                        ).launch(context,
                            duration: Duration(milliseconds: 500),
                            pageRouteAnimation: PageRouteAnimation.Slide);
                      }),
                    ],
                  ),
                  16.height,
                  Row(
                    children: [
                      Spacer(),
                      Divider().expand(),
                      16.width,
                      Text(language.signWith, style: secondaryTextStyle()),
                      16.width,
                      Divider().expand(),
                      Spacer(),
                    ],
                  ),
                  20.height,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        child: Image.asset(ic_google, height: 30, width: 30),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.all(12),
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(defaultRadius)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          socialDialog(() {
                            googleSignIn();
                          });
                        },
                      ),
                      if (isIOS) 8.width,
                      if (isIOS)
                        OutlinedButton(
                          child: Image.asset(ic_apple, height: 30, width: 30),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.all(12),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(defaultRadius)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            socialDialog(() {
                              appleLoginApi();
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Observer(
              builder: (context) => loaderWidget().visible(appStore.isLoading)),
        ],
      ),
      bottomNavigationBar: Container(
        color: appStore.isDarkMode
            ? ColorUtils.scaffoldSecondaryDark
            : ColorUtils.colorPrimaryLight,
        padding: EdgeInsets.all(16),
        child: appStore.isAllowDeliveryMan
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("${language.becomeADeliveryBoy}",
                      style: primaryTextStyle()),
                  4.width,
                  Text(language.signUp,
                          style: boldTextStyle(color: ColorUtils.colorPrimary))
                      .onTap(() {
                    RegisterScreen(userType: DELIVERY_MAN).launch(context,
                        duration: Duration(milliseconds: 500),
                        pageRouteAnimation: PageRouteAnimation.Slide);
                  }),
                ],
              ).visible(appStore.isAllowDeliveryMan)
            : SizedBox(),
      ).visible(appStore.isAllowDeliveryMan),
    );
  }

  socialDialog(Function onContinue) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              actionsPadding: EdgeInsets.all(16),
              contentPadding: EdgeInsets.zero,
              shape:
                  RoundedRectangleBorder(borderRadius: radius(defaultRadius)),
              title: Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(language.selectUserType,
                      style: boldTextStyle(size: 18))),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: userTypeList.where((item) {
                  if (!appStore.isAllowDeliveryMan) {
                    return item == CLIENT;
                  }
                  return item == CLIENT || item == DELIVERY_MAN;
                }).map((item) {
                  return RadioListTile<String>(
                    value: item,
                    activeColor: ColorUtils.colorPrimary,
                    visualDensity: const VisualDensity(
                      horizontal: VisualDensity.minimumDensity,
                      vertical: VisualDensity.minimumDensity,
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    title: Text(
                      item == CLIENT
                          ? language.lblUser
                          : item == DELIVERY_MAN
                              ? language.lblDeliveryBoy
                              : '',
                    ),
                    groupValue: userType,
                    onChanged: (val) {
                      userType = val.validate();
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              actions: <Widget>[
                Row(
                  children: [
                    outlineButton(language.cancel, () {
                      Navigator.pop(context);
                    }).expand(),
                    16.width,
                    commonButton(language.lblContinue, () {
                      finish(context);
                      onContinue();
                    }, color: ColorUtils.colorPrimary)
                        .expand(),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
