import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/screens/VerificationListScreen.dart';
import '../../main/utils/custom_store_checker.dart';
import 'package:the_apple_sign_in/the_apple_sign_in.dart';

import '../../delivery/fragment/DHomeFragment.dart';
import '../../extensions/common.dart';
import '../../extensions/extension_util/device_extensions.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../main.dart';
import '../../user/screens/DashboardScreen.dart';
import '../helper/encrypt_data.dart';
import '../models/CityListModel.dart';
import '../models/LoginResponse.dart';
import '../network/RestApis.dart';
import '../screens/EditProfileScreen.dart';
import '../screens/UserCitySelectScreen.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';

final FirebaseAuth _auth = FirebaseAuth.instance;

class AuthServices {
  Future<void> updateUserData(UserData user) async {
    userService.updateDocument({
      'player_id': getStringAsync(PLAYER_ID),
      'updatedAt': Timestamp.now(),
    }, user.uid);
  }

  Future<User?> createAuthUser(String? email, String? password) async {
    User? userCredential;
    try {
      await _auth
          .createUserWithEmailAndPassword(email: email!, password: password!)
          .then((value) {
        userCredential = value.user!;
      });
    } on FirebaseException catch (error) {
      if (error.code == "ERROR_EMAIL_ALREADY_IN_USE" ||
          error.code == "account-exists-with-different-credential" ||
          error.code == "email-already-in-use") {
        try {
          await _auth
              .signInWithEmailAndPassword(email: email!, password: password!)
              .then((value) {
            userCredential = value.user!;
          });
        } on FirebaseException catch (error) {
          print("on FirebaseException catch (error)");
          toast(getMessageFromErrorCode(error));
        }
      } else {
        toast(getMessageFromErrorCode(error));
      }
    }
    return userCredential;
  }

  Future<void> signUpWithEmailPassword(context,
      {String? name,
      String? email,
      String? password,
      LoginResponse? userData,
      String? mobileNumber,
      String? lName,
      String? userName,
      bool? isOTP,
      String? userType,
      bool isAddUser = false}) async {
    try {
      createAuthUser(email, password).then((user) async {
        if (user != null) {
          UserData userModel = UserData();

          /// Create user
          userModel.uid = user.uid;
          userModel.email = user.email;
          userModel.contactNumber = userData!.data!.contactNumber;
          userModel.name = userData.data!.name;
          userModel.username = userData.data!.username;
          userModel.userType = userData.data!.userType;
          userModel.longitude = userData.data!.longitude;
          userModel.latitude = userData.data!.longitude;
          userModel.countryName = userData.data!.countryName;
          userModel.cityName = userData.data!.cityName;
          userModel.status = userData.data!.status;
          userModel.playerId = userData.data!.playerId;
          userModel.profileImage = userData.data!.profileImage;
          userModel.createdAt = Timestamp.now().toDate().toString();
          userModel.updatedAt = Timestamp.now().toDate().toString();
          userModel.playerId = getStringAsync(PLAYER_ID);
          await userService
              .addDocumentWithCustomId(user.uid, userModel.toJson())
              .then((value) async {
            Map request = {
              "email": Encryption.instance.encrypt(userModel.email!),
              "password": Encryption.instance.encrypt(password!)
            };
            await logInApi(request).then((res) async {
              await setValue(USER_TOKEN, res.data!.apiToken.validate());
              await signInWithEmailPassword(context,
                      email: email.validate(), password: password.validate())
                  .then((value) {
                updateUserStatus({
                  "id": getIntAsync(USER_ID),
                  "uid": getStringAsync(UID),
                }).then((value) {
                  log("value...." + value.toString());
                });
                appStore.setLoading(false);
                updateStoreCheckerData().then((source) async {
                  await getUserDetail(getIntAsync(USER_ID)).then((value) async {
                    appStore.setReferralCode(value.referralCode.validate());
                    if (value.app_source.isEmptyOrNull ||
                        value.app_source != source) {
                      await updateUserStatus({
                        "id": getIntAsync(USER_ID),
                        "app_source": source
                      }).then((data) {});
                    }
                  }).catchError((e) {
                    log(e);
                  });
                });
                if (res.data!.emailVerifiedAt.isEmptyOrNull ||
                    res.data!.otpVerifyAt.isEmptyOrNull ||
                    (res.data!.documentVerifiedAt.isEmptyOrNull &&
                        getStringAsync(USER_TYPE) == DELIVERY_MAN)) {
                  VerificationListScreen().launch(context);
                } else {
                  UserCitySelectScreen().launch(context,
                      isNewTask: true,
                      pageRouteAnimation: PageRouteAnimation.Slide);
                }
              });
            }).catchError((e) {
              appStore.setLoading(false);
              log(e.toString());
              toast(e.toString());
            });
            // }
          }).catchError((e) {
            appStore.setLoading(false);
            toast(e.toString());
          });
        } else {
          appStore.setLoading(false);
          throw language.errorSomethingWentWrong;
        }
      }).catchError((e) {
        appStore.setLoading(false);
      });
    } on FirebaseException catch (error) {
      appStore.setLoading(false);
      toast(getMessageFromErrorCode(error));
    }
  }

  Future<void> registerUserWithDB(
      String email, String password, LoginResponse value) async {
    try {
      createAuthUser(email, password).then((user) async {
        if (user != null) {
          UserData userModel = UserData();
          userModel.email = value.data!.email;
          userModel.contactNumber = value.data!.contactNumber;
          userModel.name = value.data!.name;
          userModel.username = value.data!.username;
          userModel.userType = value.data!.userType;
          userModel.longitude = value.data!.longitude;
          userModel.latitude = value.data!.longitude;
          userModel.countryName = value.data!.countryName;
          userModel.cityName = value.data!.cityName;
          userModel.status = value.data!.status;
          userModel.playerId = value.data!.playerId;
          userModel.profileImage = value.data!.profileImage;
          userModel.createdAt = Timestamp.now().toDate().toString();
          userModel.updatedAt = Timestamp.now().toDate().toString();
          userModel.playerId = getStringAsync(PLAYER_ID);
          await userService
              .addDocumentWithCustomId(user.uid, userModel.toJson())
              .then((val) async {
            await setValue(UID, user.uid.validate());
            await updateUid(user.uid.validate()).catchError((error) {});
          }).catchError((e) {
            appStore.setLoading(false);
            toast(e.toString());
          });
        } else {
          appStore.setLoading(false);
          throw language.errorSomethingWentWrong;
        }
      }).catchError((e) {
        appStore.setLoading(false);
      });
    } on FirebaseException catch (error) {
      appStore.setLoading(false);
      toast(getMessageFromErrorCode(error));
    }
  }

  Future<void> signInWithEmailPassword(context,
      {required String email, required String password}) async {
    try {
      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        final User user = userCredential.user!;
        await userService.getUser(email: user.email).then((value) async {
          await updateUserData(value);
          setValue(USER_EMAIL, value.email.validate());
          setValue(IS_LOGGED_IN, true);
          setValue(UID, value.uid.validate());
        }).catchError((error) {
          log(error.toString());
          throw error;
        });
      }
    } on FirebaseAuthException catch (e) {
      log(e.toString());
      throw getMessageFromErrorCode(e);
    } catch (e) {
      log(e.toString());
      throw e.toString();
    }
  }

  Future<void> loginFromFirebaseUser(User currentUser,
      {LoginResponse? loginDetail,
      String? fullName,
      String? fName,
      String? lName}) async {
    UserData userModel = UserData();

    if (await userService.isUserExist(loginDetail!.data!.email)) {
      ///Return user data
      await userService.userByEmail(loginDetail.data!.email).then((user) async {
        userModel = user;
        appStore.setUserEmail(userModel.email.validate());
        appStore.setUId(userModel.uid.validate());

        await updateUserData(user);
      }).catchError((e) {
        log(e);
        throw e;
      });
    } else {
      /// Create user
      userModel.uid = currentUser.uid.validate();
      userModel.id = loginDetail.data!.id.validate();
      userModel.email = loginDetail.data!.email.validate();
      userModel.name = loginDetail.data!.name.validate();
      userModel.contactNumber = loginDetail.data!.contactNumber.validate();
      userModel.username = loginDetail.data!.username.validate();
      userModel.email = loginDetail.data!.email.validate();
      userModel.userType = CLIENT;

      if (isIOS) {
        userModel.username = fullName;
      } else {
        userModel.username = loginDetail.data!.username.validate();
      }

      userModel.contactNumber = loginDetail.data!.contactNumber.validate();
      userModel.profileImage = loginDetail.data!.profileImage.validate();
      userModel.playerId = getStringAsync(PLAYER_ID);

      setValue(UID, currentUser.uid.validate());
      log(getStringAsync(UID));
      setValue(USER_EMAIL, userModel.email.validate());
      setValue(IS_LOGGED_IN, true);

      log(userModel.toJson());

      await userService
          .addDocumentWithCustomId(currentUser.uid, userModel.toJson())
          .then((value) {
        //
      }).catchError((e) {
        throw e;
      });
    }
  }

  Future<void> loginFromFirebase(
      User currentUser, String loginType, String? accessToken,
      {String userType = CLIENT}) async {
    String? firstName;
    String lastName = '';
    if (loginType == LoginTypeGoogle) {
      String displayName = currentUser.displayName.validate();
      if (displayName.isNotEmpty) {
        List<String> nameParts = displayName.split(' ');
        firstName = nameParts.isNotEmpty ? nameParts.first : "";
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : "";
      } else {
        firstName = "User";
        lastName = "";
      }
    } else {
      firstName = getStringAsync('appleGivenName').validate();
      lastName = getStringAsync('appleFamilyName').validate();
    }

    String safeName = (firstName != null && firstName.trim().isNotEmpty)
        ? firstName.trim()
        : "User";

    log("safeName   ${Encryption.instance.encrypt(accessToken!)}");

    Map req = {
      "email": Encryption.instance.encrypt(currentUser.email!.trim()),
      "username": Encryption.instance.encrypt(currentUser.email!.trim()),
      "name": Encryption.instance.encrypt(safeName),
      "login_type": Encryption.instance.encrypt(loginType),
      "user_type": Encryption.instance.encrypt(userType),
      "accessToken": Encryption.instance.encrypt(accessToken!),
      if (!currentUser.phoneNumber.isEmptyOrNull)
        'contact_number': currentUser.phoneNumber.validate(),
    };

    await logInApi(req, isSocialLogin: true).then((value) async {
      //  Navigator.pop(getContext);

      UserData userModel = UserData();

      /// Create user
      userModel.uid = currentUser.uid;
      userModel.email = value.data!.email;
      userModel.contactNumber = value.data!.contactNumber;
      userModel.name = value.data!.name;
      userModel.username = value.data!.username;
      userModel.userType = value.data!.userType;
      userModel.longitude = value.data!.longitude;
      userModel.latitude = value.data!.longitude;
      userModel.countryName = value.data!.countryName;
      userModel.cityName = value.data!.cityName;
      userModel.status = value.data!.status;
      userModel.playerId = value.data!.playerId;
      userModel.profileImage = value.data!.profileImage;
      userModel.createdAt = Timestamp.now().toDate().toString();
      userModel.updatedAt = Timestamp.now().toDate().toString();
      userModel.playerId = getStringAsync(PLAYER_ID);
      await userService
          .addDocumentWithCustomId(currentUser.uid, userModel.toJson())
          .then((v) async {
        await setValue(USER_PROFILE_PHOTO, currentUser.photoURL.toString());
        if (value.data!.contactNumber.isEmptyOrNull) {
          EditProfileScreen(isGoogle: true).launch(getContext, isNewTask: true);
        } else {
          if (value.data!.countryId != null && value.data!.cityId != null) {
            await getCountryDetailApiCall(value.data!.countryId.validate());
            getCityDetailApiCall(value.data!.cityId.validate());
          } else {
            UserCitySelectScreen().launch(getContext,
                isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
          }
          if (value.data!.uid.isEmptyOrNull)
            await updateUid(getStringAsync(UID)).catchError((error) {});
          if (value.data!.playerId.isEmptyOrNull)
            await updatePlayerId().catchError((error) {});
        }
        updateStoreCheckerData().then((source) async {
          await getUserDetail(getIntAsync(USER_ID)).then((value) async {
            if (value.app_source.isEmptyOrNull || value.app_source != source) {
              await updateUserStatus(
                      {"id": getIntAsync(USER_ID), "app_source": source})
                  .then((data) {});
            }
          }).catchError((e) {
            log(e);
          });
        });
      }).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString());
      });
    }).catchError((e) {
      log(e.toString());
      throw e;
    });
  }

  Future<void> signInWithGoogle({String userType = CLIENT}) async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    GoogleSignInAccount? googleSignInAccount = await googleSignIn.signIn();

    if (googleSignInAccount != null) {
      //Authentication
      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleSignInAuthentication.accessToken,
        idToken: googleSignInAuthentication.idToken,
      );

      final UserCredential authResult =
          await _auth.signInWithCredential(credential);
      final User user = authResult.user!;

      assert(!user.isAnonymous);

      final User currentUser = _auth.currentUser!;
      print("AuthCredential " + user.uid.toString());
      setValue(UID, currentUser.uid);
      assert(user.uid == currentUser.uid);

      googleSignIn.signOut();

      await loginFromFirebase(
          user, LoginTypeGoogle, googleSignInAuthentication.accessToken,
          userType: userType);
    } else {
      throw language.errorSomethingWentWrong;
    }
  }

  /// Sign-In with Apple.
  Future<void> appleLogIn(String? userType) async {
    if (await TheAppleSignIn.isAvailable()) {
      AuthorizationResult result = await TheAppleSignIn.performRequests(
        [
          AppleIdRequest(requestedScopes: [Scope.email, Scope.fullName])
        ],
      );
      switch (result.status) {
        case AuthorizationStatus.authorized:
          final appleIdCredential = result.credential!;
          final oAuthProvider = OAuthProvider('apple.com');
          final credential = oAuthProvider.credential(
            idToken: String.fromCharCodes(appleIdCredential.identityToken!),
            accessToken:
                String.fromCharCodes(appleIdCredential.authorizationCode!),
          );
          final authResult = await _auth.signInWithCredential(credential);
          final user = authResult.user!;

          if (result.credential!.email != null) {
            await saveAppleData(result);
          }

          await loginFromFirebase(user, LoginTypeApple,
              String.fromCharCodes(appleIdCredential.authorizationCode!),
              userType: userType.validate());
          break;
        case AuthorizationStatus.error:
          throw ("${language.signInFailed} ${result.error!.localizedDescription}");
        case AuthorizationStatus.cancelled:
          throw (language.cancelled);
      }
    } else {
      throw (language.appleSignInNotAvailableError);
    }
  }

  Future<void> saveAppleData(AuthorizationResult result) async {
    await setValue('appleEmail', result.credential!.email.validate());
    await setValue(
        'appleGivenName', result.credential!.fullName!.givenName.validate());
    await setValue(
        'appleFamilyName', result.credential!.fullName!.familyName.validate());
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
          DashboardScreen().launch(getContext, isNewTask: true);
        } else {
          // DeliveryDashBoard().launch(getContext, isNewTask: true);
          DHomeFragment().launch(getContext, isNewTask: true);
        }
      } else {
        VerificationListScreen().launch(getContext, isNewTask: true);
      }
    } else {
      UserCitySelectScreen().launch(getContext, isNewTask: true);
    }
  }).catchError((error) {
    if (error.toString() == CITY_NOT_FOUND_EXCEPTION) {
      UserCitySelectScreen().launch(getContext,
          isNewTask: true, pageRouteAnimation: PageRouteAnimation.Slide);
    }
  });
}

Future deleteUserFirebase() async {
  if (FirebaseAuth.instance.currentUser != null) {
    try {
      FirebaseAuth.instance.currentUser!.delete();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print("===========${e.toString()}");
    }
  }
}

sendOtp(BuildContext context,
    {required String phoneNumber, required Function(String) onUpdate}) async {
  appStore.setLoading(true);
  try {
    await FirebaseAuth.instance.verifyPhoneNumber(
      timeout: const Duration(seconds: 60),
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        appStore.setLoading(false);
        toast(language.verificationCompleted);
      },
      verificationFailed: (FirebaseAuthException e) {
        appStore.setLoading(false);
        if (e.code == 'invalid-phone-number') {
          toast(language.phoneNumberInvalid);
          throw language.phoneNumberInvalid;
        } else {
          toast(e.message.toString());
          throw e.message.toString();
        }
      },
      codeSent: (String verificationId, int? resendToken) async {
        appStore.setLoading(false);
        toast(language.codeSent);
        onUpdate.call(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        appStore.setLoading(false);
      },
    );
  } on FirebaseException catch (error) {
    appStore.setLoading(false);
    toast(error.message);
  }
}

Future<String> updateStoreCheckerData() async {
  InstallationSource installationSource;
  try {
    installationSource = await CustomStoreChecker.getSource();
  } on PlatformException {
    installationSource = InstallationSource.UNKNOWN;
  }

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
