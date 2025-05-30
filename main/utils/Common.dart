import 'dart:core';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chewie/chewie.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../extensions/decorations.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/utils/dynamic_theme.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../extensions/common.dart';
import '../../extensions/extension_util/device_extensions.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../extensions/widgets.dart';
import '../../main.dart';
import '../../main/utils/Colors.dart';
import '../../main/utils/Constants.dart';
import '../../user/screens/OrderDetailScreen.dart';
import '../Chat/ChatScreen.dart';
import '../models/LoginResponse.dart';
import '../network/RestApis.dart';
import '../screens/LoginScreen.dart';
import '../services/AuthServices.dart';
import 'Images.dart';
import 'Widgets.dart';

/// Make any variable nullable
T? makeNullable<T>(T? value) => value;

/// Enum for page route
enum PageRouteAnimation { Fade, Scale, Rotate, Slide, SlideBottomTop }

/// has match return bool for pattern matching
bool hasMatch(String? s, String p) {
  return (s == null) ? false : RegExp(p).hasMatch(s);
}

/// Show SnackBar
void snackBar(
  BuildContext context, {
  String title = '',
  Widget? content,
  SnackBarAction? snackBarAction,
  Function? onVisible,
  Color? textColor,
  Color? backgroundColor,
  EdgeInsets? margin,
  EdgeInsets? padding,
  Animation<double>? animation,
  double? width,
  ShapeBorder? shape,
  Duration? duration,
  SnackBarBehavior? behavior,
  double? elevation,
}) {
  if (title.isEmpty && content == null) {
    print('SnackBar message is empty');
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: backgroundColor,
        action: snackBarAction,
        margin: margin,
        animation: animation,
        width: width,
        shape: shape,
        duration: duration ?? 4.seconds,
        behavior: margin != null ? SnackBarBehavior.floating : behavior,
        elevation: elevation,
        onVisible: onVisible?.call(),
        content: content ??
            Padding(
              padding: padding ?? EdgeInsets.symmetric(vertical: 4),
              child: Text(
                title,
                style: primaryTextStyle(color: textColor ?? Colors.white),
              ),
            ),
      ),
    );
  }
}

/// Hide soft keyboard
void hideKeyboard(context) => FocusScope.of(context).requestFocus(FocusNode());

/// Returns a string from Clipboard
Future<String> paste() async {
  ClipboardData? data = await Clipboard.getData('text/plain');
  return data?.text?.toString() ?? "";
}

/// Returns a string from Clipboard
Future<dynamic> pasteObject() async {
  ClipboardData? data = await Clipboard.getData('text/plain');
  return data;
}

/// Enum for Link Provider
enum LinkProvider {
  PLAY_STORE,
  APPSTORE,
  FACEBOOK,
  INSTAGRAM,
  LINKEDIN,
  TWITTER,
  YOUTUBE,
  REDDIT,
  TELEGRAM,
  WHATSAPP,
  FB_MESSENGER,
  GOOGLE_DRIVE
}

const double degrees2Radians = pi / 180.0;

double radians(double degrees) => degrees * degrees2Radians;

void afterBuildCreated(Function()? onCreated) {
  makeNullable(SchedulerBinding.instance)!.addPostFrameCallback((_) => onCreated?.call());
}

Widget dialogAnimatedWrapperWidget({
  required Animation<double> animation,
  required Widget child,
  required DialogAnimation dialogAnimation,
  required Curve curve,
}) {
  switch (dialogAnimation) {
    case DialogAnimation.ROTATE:
      return Transform.rotate(
        angle: radians(animation.value * 360),
        child: Opacity(
          opacity: animation.value,
          child: FadeTransition(opacity: animation, child: child),
        ),
      );

    case DialogAnimation.SLIDE_TOP_BOTTOM:
      final curvedValue = curve.transform(animation.value) - 1.0;

      return Transform(
        transform: Matrix4.translationValues(0.0, curvedValue * 300, 0.0),
        child: Opacity(
          opacity: animation.value,
          child: FadeTransition(opacity: animation, child: child),
        ),
      );

    case DialogAnimation.SCALE:
      return Transform.scale(
        scale: animation.value,
        child: FadeTransition(opacity: animation, child: child),
      );

    case DialogAnimation.SLIDE_BOTTOM_TOP:
      return SlideTransition(
        position: Tween(begin: Offset(0, 1), end: Offset.zero).chain(CurveTween(curve: curve)).animate(animation),
        child: Opacity(
          opacity: animation.value,
          child: FadeTransition(opacity: animation, child: child),
        ),
      );

    case DialogAnimation.SLIDE_LEFT_RIGHT:
      return SlideTransition(
        position: Tween(begin: Offset(1.0, 0.0), end: Offset.zero).chain(CurveTween(curve: curve)).animate(animation),
        child: Opacity(
          opacity: animation.value,
          child: FadeTransition(opacity: animation, child: child),
        ),
      );

    case DialogAnimation.SLIDE_RIGHT_LEFT:
      return SlideTransition(
        position: Tween(begin: Offset(-1, 0), end: Offset.zero).chain(CurveTween(curve: curve)).animate(animation),
        child: Opacity(
          opacity: animation.value,
          child: FadeTransition(opacity: animation, child: child),
        ),
      );

    case DialogAnimation.DEFAULT:
      return FadeTransition(opacity: animation, child: child);
  }
}

Route<T> buildPageRoute<T>(
  Widget child,
  PageRouteAnimation? pageRouteAnimation,
  Duration? duration,
) {
  if (pageRouteAnimation != null) {
    if (pageRouteAnimation == PageRouteAnimation.Fade) {
      return PageRouteBuilder(
        pageBuilder: (c, a1, a2) => child,
        transitionsBuilder: (c, anim, a2, child) {
          return FadeTransition(opacity: anim, child: child);
        },
        transitionDuration: duration ?? pageRouteTransitionDurationGlobal,
      );
    } else if (pageRouteAnimation == PageRouteAnimation.Rotate) {
      return PageRouteBuilder(
        pageBuilder: (c, a1, a2) => child,
        transitionsBuilder: (c, anim, a2, child) {
          return RotationTransition(child: child, turns: ReverseAnimation(anim));
        },
        transitionDuration: duration ?? pageRouteTransitionDurationGlobal,
      );
    } else if (pageRouteAnimation == PageRouteAnimation.Scale) {
      return PageRouteBuilder(
        pageBuilder: (c, a1, a2) => child,
        transitionsBuilder: (c, anim, a2, child) {
          return ScaleTransition(child: child, scale: anim);
        },
        transitionDuration: duration ?? pageRouteTransitionDurationGlobal,
      );
    } else if (pageRouteAnimation == PageRouteAnimation.Slide) {
      return PageRouteBuilder(
        pageBuilder: (c, a1, a2) => child,
        transitionsBuilder: (c, anim, a2, child) {
          return SlideTransition(
            child: child,
            position: Tween(
              begin: Offset(1.0, 0.0),
              end: Offset(0.0, 0.0),
            ).animate(anim),
          );
        },
        transitionDuration: duration ?? pageRouteTransitionDurationGlobal,
      );
    } else if (pageRouteAnimation == PageRouteAnimation.SlideBottomTop) {
      return PageRouteBuilder(
        pageBuilder: (c, a1, a2) => child,
        transitionsBuilder: (c, anim, a2, child) {
          return SlideTransition(
            child: child,
            position: Tween(
              begin: Offset(0.0, 1.0),
              end: Offset(0.0, 0.0),
            ).animate(anim),
          );
        },
        transitionDuration: duration ?? pageRouteTransitionDurationGlobal,
      );
    }
  }
  return MaterialPageRoute<T>(builder: (_) => child);
}

EdgeInsets dynamicAppButtonPadding(BuildContext context) {
  if (context.isDesktop()) {
    return EdgeInsets.symmetric(vertical: 20, horizontal: 20);
  } else if (context.isTablet()) {
    return EdgeInsets.symmetric(vertical: 16, horizontal: 16);
  } else {
    return EdgeInsets.symmetric(vertical: 12, horizontal: 16);
  }
}

enum BottomSheetDialog { Dialog, BottomSheet }

Future<dynamic> showBottomSheetOrDialog({
  required BuildContext context,
  required Widget child,
  BottomSheetDialog bottomSheetDialog = BottomSheetDialog.Dialog,
}) {
  if (bottomSheetDialog == BottomSheetDialog.BottomSheet) {
    return showModalBottomSheet(context: context, builder: (_) => child);
  } else {
    return showInDialog(context, builder: (_) => child);
  }
}

/// mailto: function to open native email app
Uri mailTo({
  required List<String> to,
  String subject = '',
  String body = '',
  List<String> cc = const [],
  List<String> bcc = const [],
}) {
  String _subject = '';
  if (subject.isNotEmpty) _subject = '&subject=$subject';

  String _body = '';
  if (body.isNotEmpty) _body = '&body=$body';

  String _cc = '';
  if (cc.isNotEmpty) _cc = '&cc=${cc.join(',')}';

  String _bcc = '';
  if (bcc.isNotEmpty) _bcc = '&bcc=${bcc.join(',')}';

  return Uri(
    scheme: 'mailto',
    query: 'to=${to.join(',')}$_subject$_body$_cc$_bcc',
  );
}

/// returns true if network is available
Future<bool> isNetworkAvailable() async {
  var connectivityResult = await Connectivity().checkConnectivity();
  return connectivityResult != ConnectivityResult.none;
}

get getContext => navigatorKey.currentState?.overlay?.context;

Future<T?> push<T>(
  Widget widget, {
  bool isNewTask = false,
  PageRouteAnimation? pageRouteAnimation,
  Duration? duration,
}) async {
  final context = getContext; // Assuming getContext is a method or property that returns a BuildContext

  if (isNewTask) {
    return await Navigator.of(context).pushAndRemoveUntil(
      buildPageRoute(widget, pageRouteAnimation, duration),
      (route) => false,
    );
  } else {
    return await Navigator.of(context).push(
      buildPageRoute(widget, pageRouteAnimation, duration),
    );
  }
}

String parseHtmlString(String? htmlString) {
  return parse(parse(htmlString).body!.text).documentElement!.text;
}

/// Dispose current screen or close current dialog
void pop([Object? object]) {
  final context = getContext;
  if (Navigator.canPop(context)) Navigator.pop(getContext, object);
}

void toast(
  String? value, {
  ToastGravity? gravity,
  length = Toast.LENGTH_SHORT,
  Color? bgColor,
  Color? textColor,
  bool print = false,
}) {
  if (value.validate().isEmpty || isLinux) {
  } else {
    Fluttertoast.showToast(
      msg: value.validate(),
      gravity: gravity,
      toastLength: length,
      backgroundColor: bgColor,
      textColor: textColor,
    );
  }
}

Future<bool> checkPermission() async {
  // Request app level location permission
  LocationPermission locationPermission = await Geolocator.requestPermission();

  if (locationPermission == LocationPermission.whileInUse || locationPermission == LocationPermission.always) {
    // Check system level location permission
    if (!await Geolocator.isLocationServiceEnabled()) {
      return await Geolocator.openLocationSettings().then((value) => false).catchError((e) => false);
    } else {
      return true;
    }
  } else {
    toast(language.allowLocationPermission);

    // Open system level location permission
    await Geolocator.openAppSettings();

    return false;
  }
}

Future<void> getCurrentLocationData({Function()? onUpdate}) async {
  if (await checkPermission()) {
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((value) async {
      List<Placemark> placeMarks = await placemarkFromCoordinates(value.latitude, value.longitude);
      setValue(CURRENT_LATITUDE, value.latitude);
      setValue(CURRENT_LONGITUDE, value.longitude);
      setValue(CURRENT_CITY, placeMarks[0].locality);
      onUpdate?.call();
    }).catchError((e) {
      //
    });
  }
}

// Calculate service charge (5%)
double calculateServiceCharge(double amount) {
  return (amount * SERVICE_CHARGE_PERCENTAGE);
}

// Calculate amount with service charge for client
double calculateAmountWithServiceCharge(double amount) {
  return amount + calculateServiceCharge(amount);
}

// Calculate amount after deducting service charge for transporter
double calculateAmountAfterServiceCharge(double amount) {
  return amount - calculateServiceCharge(amount);
}

// Calculate partial payment (50% of service charge)
double calculatePartialServiceCharge(double amount) {
  return calculateServiceCharge(amount) / 2;
}

Color statusColor(String status) {
  Color color = ColorUtils.colorPrimary;
  switch (status) {
    case ORDER_ACCEPTED:
      return acceptColor;
    case ORDER_CREATED:
      return CreatedColorColor;
    case ORDER_DEPARTED:
      return acceptColor;
    case ORDER_ASSIGNED:
      return pendingApprovalColorColor;
    case ORDER_PICKED_UP:
      return in_progressColor;
    case ORDER_ARRIVED:
      return in_progressColor;
    case ORDER_CANCELLED:
      return cancelledColor;
    case ORDER_DELIVERED:
      return completedColor;
    case ORDER_DRAFT:
      return holdColor;
    case ORDER_DELAYED:
      return WaitingStatusColor;
  }
  return color;
}

Color paymentStatusColor(String status) {
  Color color = ColorUtils.colorPrimary;
  if (status == PAYMENT_PAID) {
    color = Colors.green;
  } else if (status == PAYMENT_FAILED) {
    color = Colors.red;
  } else if (status == PAYMENT_PENDING) {
    color = ColorUtils.colorPrimary;
  }
  return color;
}

String parcelTypeIcon(String? parcelType) {
  String icon = 'assets/icons/ic_product.png';
  switch (parcelType.validate().toLowerCase()) {
    case "documents":
      return 'assets/icons/ic_document.png';
    case "document":
      return 'assets/icons/ic_document.png';
    case "food":
      return 'assets/icons/ic_food.png';
    case "foods":
      return 'assets/icons/ic_food.png';
    case "cake":
      return 'assets/icons/ic_cake.png';
    case "flowers":
      return 'assets/icons/ic_flower.png';
    case "flower":
      return 'assets/icons/ic_flower.png';
  }
  return icon;
}

String printDate(String date) {
  return DateFormat('dd MMM yyyy').format(DateTime.parse(date).toLocal()) + " at " + DateFormat('hh:mm a').format(DateTime.parse(date).toLocal());
}

String printDateWithoutAt(String date) {
  return DateFormat('dd MMM yyyy').format(DateTime.parse(date).toLocal()) + " " + DateFormat('hh:mm a').format(DateTime.parse(date).toLocal());
}

Widget loaderWidget() {
  return Center(
    child: LoadingAnimationWidget.hexagonDots(
      color: ColorUtils.colorPrimary,
      size: 50,
    ),
  );
}

Widget emptyWidget() {
  return Center(child: Image.asset(ic_no_data, width: 80, height: 80, color: ColorUtils.colorPrimary));
}

String orderStatus(String orderStatus) {
  if (orderStatus == ORDER_ASSIGNED) {
    return language.assigned;
  } else if (orderStatus == ORDER_DRAFT) {
    return language.draft;
  } else if (orderStatus == ORDER_CREATED) {
    return language.created;
  } else if (orderStatus == ORDER_ACCEPTED) {
    return language.accepted;
  } else if (orderStatus == ORDER_PICKED_UP) {
    return language.pickedUp;
  } else if (orderStatus == ORDER_ARRIVED) {
    return language.arrived;
  } else if (orderStatus == ORDER_DEPARTED) {
    return language.departed;
  } else if (orderStatus == ORDER_DELIVERED) {
    return language.delivered;
  } else if (orderStatus == ORDER_CANCELLED) {
    return language.cancelled;
  } else if (orderStatus == ORDER_SHIPPED) {
    return language.shipped;
  }
  return language.assigned;
}

String countName(String count) {
  if (count == TODAY_ORDER) {
    return language.todayOrder;
  } else if (count == REMAINING_ORDER) {
    return language.remainingOrder;
  } else if (count == COMPLETED_ORDER) {
    return language.completedOrder;
  } else if (count == INPROGRESS_ORDER) {
    return language.inProgressOrder;
  } else if (count == TOTAL_EARNING) {
    return language.commission;
  } else if (count == WALLET_BALANCE) {
    return language.walletBalance;
  } else if (count == PENDING_WITHDRAW_REQUEST) {
    return language.pendingWithdReq;
  } else if (count == COMPLETED_WITHDRAW_REQUEST) {
    return language.completedWithReq;
  }
  return "";
}

String transactionType(String type) {
  if (type == TRANSACTION_ORDER_FEE) {
    return language.orderFee;
  } else if (type == TRANSACTION_TOPUP) {
    return language.topup;
  } else if (type == TRANSACTION_ORDER_CANCEL_CHARGE) {
    return language.orderCancelCharge;
  } else if (type == TRANSACTION_ORDER_CANCEL_REFUND) {
    return language.orderCancelRefund;
  } else if (type == TRANSACTION_CORRECTION) {
    return language.correction;
  } else if (type == TRANSACTION_COMMISSION) {
    return language.commission;
  } else if (type == TRANSACTION_WITHDRAW) {
    return language.withdraw;
  } else if (type == TRANSACTION_SERVICE_CHARGE) {
    return language.serviceCharge;
  } else if (type == TRANSACTION_PICKUP_SERVICE_CHARGE) {
    return "Pickup " + language.serviceCharge;
  } else if (type == TRANSACTION_DELIVERY_SERVICE_CHARGE) {
    return "Delivery " + language.serviceCharge;
  }
  return type;
}

oneSignalSettings() async {
  if (isMobile) {
    PermissionStatus status = await Permission.notification.status;
    if (!status.isGranted) {
      await Permission.notification.request();
    }

    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.Debug.setAlertLevel(OSLogLevel.none);
    OneSignal.consentRequired(false);
    OneSignal.initialize(mOneSignalAppId);
    OneSignal.Notifications.requestPermission(true);
    saveOneSignalPlayerId();
    OneSignal.Notifications.addPermissionObserver((state) {
      print("Has permission " + state.toString());
    });
    OneSignal.Notifications.addClickListener((notification) async {
      var notId = notification.notification.additionalData!["id"];
      if (notId != null) {
        if (!appStore.isLoggedIn) {
          LoginScreen().launch(getContext);
        } else if (notId.toString().contains('CHAT')) {
          UserData user = await getUserDetail(int.parse(notId.toString().replaceAll("CHAT_", "")));
          ChatScreen(userData: user).launch(getContext);
        } else {
          OrderDetailScreen(orderId: int.parse(notId.toString())).launch(getContext);
        }
      }
    });
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
      print('NOTIFICATION WILL DISPLAY LISTENER CALLED WITH: ${event.notification.jsonRepresentation()}');
      event.preventDefault();
      event.notification.display();
      if (event.notification.additionalData!["type"].toString().contains(ORDER_TRANSFER) || event.notification.additionalData!["type"].toString().contains(ORDER_ASSIGNED)) {
        if (getStringAsync(USER_TYPE) == DELIVERY_MAN) {
          playSoundForDuration();
        }
      }
    });
  }
}

// Method to play the sound for 60 seconds
void playSoundForDuration() async {
  print("===========type=====================${getStringAsync(USER_TYPE)}");
  try {
    FlutterRingtonePlayer().play(fromAsset: "assets/ringtone/ringtone.mp3", looping: true);
    await Future.delayed(Duration(seconds: 60));
    FlutterRingtonePlayer().stop();
  } catch (e) {
    print('Error playing sound: $e');
  }
}

Future<void> saveOneSignalPlayerId() async {
  OneSignal.User.pushSubscription.addObserver((state) async {
    print(OneSignal.User.pushSubscription.optedIn);
    print("Player Id" + OneSignal.User.pushSubscription.id.toString());
    print(OneSignal.User.pushSubscription.token);
    print(state.current.jsonRepresentation());

    if (OneSignal.User.pushSubscription.id.validate().isNotEmpty) await setValue(PLAYER_ID, OneSignal.User.pushSubscription.id.validate());
  });
}

String statusTypeIcon({String? type}) {
  String icon = ic_order;
  if (type == ORDER_ASSIGNED) {
    icon = ic_order_assigned;
  } else if (type == ORDER_ACCEPTED) {
    icon = ic_order_accept;
  } else if (type == ORDER_PICKED_UP) {
    icon = ic_order_pickedUp;
  } else if (type == ORDER_ARRIVED) {
    icon = ic_order_arrived;
  } else if (type == ORDER_DEPARTED) {
    icon = ic_order_departed;
  } else if (type == ORDER_DELIVERED) {
    icon = ic_order_delivered;
  } else if (type == ORDER_CANCELLED) {
    icon = ic_order_cancelled;
  } else if (type == ORDER_CREATED) {
    icon = ic_order_created;
  } else if (type == ORDER_DRAFT) {
    icon = ic_order_draft;
  } else if (type == ORDER_TRANSFER) {
    icon = ic_order_transfer;
  }
  return icon;
}

String? orderTitle(String orderStatus) {
  if (orderStatus == ORDER_ASSIGNED) {
    return language.orderAssignConfirmation;
  } else if (orderStatus == ORDER_ACCEPTED) {
    return language.orderPickupConfirmation;
  } else if (orderStatus == ORDER_PICKED_UP) {
    return language.orderDepartedConfirmation;
  } else if (orderStatus == ORDER_ARRIVED) {
    return language.orderPickupConfirmation;
  } else if (orderStatus == ORDER_DEPARTED) {
    return language.orderCompleteConfirmation;
  } else if (orderStatus == ORDER_DELIVERED) {
    return '';
  } else if (orderStatus == ORDER_CANCELLED) {
    return language.orderCancelConfirmation;
  } else if (orderStatus == ORDER_CREATED) {
    return language.orderCreateConfirmation;
  }
  return '';
}

String dateParse(String date) {
  return DateFormat.yMd().add_jm().format(DateTime.parse(date).toLocal());
}

bool get isRTL => rtlLanguage.contains(appStore.selectedLanguage);

num countExtraCharge({required num totalAmount, required String chargesType, required num charges}) {
  if (chargesType == CHARGE_TYPE_PERCENTAGE) {
    return (totalAmount * charges * 0.01).toStringAsFixed(digitAfterDecimal).toDouble();
  } else {
    return charges.toStringAsFixed(digitAfterDecimal).toDouble();
  }
}

String paymentStatus(String paymentStatus) {
  if (paymentStatus.toLowerCase() == PAYMENT_PENDING.toLowerCase()) {
    return language.pending;
  } else if (paymentStatus.toLowerCase() == PAYMENT_FAILED.toLowerCase()) {
    return language.failed;
  } else if (paymentStatus.toLowerCase() == PAYMENT_PAID.toLowerCase()) {
    return language.paid;
  }
  return language.pending;
}

String? paymentCollectForm(String paymentType) {
  if (paymentType.toLowerCase() == PAYMENT_ON_PICKUP.toLowerCase()) {
    return language.onPickup;
  } else if (paymentType.toLowerCase() == PAYMENT_ON_DELIVERY.toLowerCase()) {
    return language.onDelivery;
  }
  return language.onPickup;
}

String paymentType(String paymentType) {
  if (paymentType.toLowerCase() == PAYMENT_TYPE_STRIPE.toLowerCase()) {
    return language.stripe;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_RAZORPAY.toLowerCase()) {
    return language.razorpay;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_PAYSTACK.toLowerCase()) {
    return language.payStack;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_FLUTTERWAVE.toLowerCase()) {
    return language.flutterWave;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_MERCADOPAGO.toLowerCase()) {
    return language.mercadoPago;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_PAYPAL.toLowerCase()) {
    return language.paypal;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_PAYTABS.toLowerCase()) {
    return language.payTabs;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_PAYTM.toLowerCase()) {
    return language.paytm;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_MYFATOORAH.toLowerCase()) {
    return language.myFatoorah;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_CASH.toLowerCase()) {
    return language.cash;
  } else if (paymentType.toLowerCase() == PAYMENT_TYPE_WALLET.toLowerCase()) {
    return language.wallet;
  }
  return language.cash;
}

String printAmount(var amount) {
  return appStore.currencyPosition == CURRENCY_POSITION_LEFT ? '${appStore.currencySymbol} ${amount.toStringAsFixed(digitAfterDecimal)}' : '${amount.toStringAsFixed(digitAfterDecimal)} ${appStore.currencySymbol}';
}

Future<void> commonLaunchUrl(String url, {bool forceWebView = false}) async {
  log(url);
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication).then((value) {}).catchError((e) {
    toast('${language.invalidUrl}: $url');
  });
}

cashConfirmDialog() {
  showInDialog(
    getContext,
    contentPadding: EdgeInsets.all(16),
    builder: (p0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(language.balanceInsufficientCashPayment, style: primaryTextStyle(size: 16), textAlign: TextAlign.center),
          30.height,
          commonButton(language.ok, () {
            finish(getContext);
          }),
        ],
      );
    },
  );
}

Future deleteAccount(BuildContext context) async {
  appStore.setLoading(true);
  await userService.removeDocument(getStringAsync(UID)).then((value) async {
    await deleteUserFirebase().then((value) async {
      Map deleteAccountReq = {"id": getIntAsync(USER_ID), "type": "forcedelete"};
      await userAction(deleteAccountReq).then((value) async {
        await logout(context, isDeleteAccount: true).then((value) async {
          appStore.setLoading(false);
          await removeKey(USER_EMAIL);
          await removeKey(USER_PASSWORD);
        });
      });
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }).catchError((error) {
    appStore.setLoading(false);
    toast(error.toString());
  });
}

String timeAgo(String date) {
  if (date.contains("week ago")) {
    return date.splitBefore("week ago").trim() + "w";
  }
  if (date.contains("year ago")) {
    return date.splitBefore("year ago").trim() + "y";
  }
  if (date.contains("month ago")) {
    return date.splitBefore("month ago").trim() + "m";
  }
  return date.toString();
}

String getMessageFromErrorCode(FirebaseException error) {
  switch (error.code) {
    case "ERROR_EMAIL_ALREADY_IN_USE":
    case "account-exists-with-different-credential":
    case "email-already-in-use":
      return "The email address is already in use by another account.";
    case "ERROR_WRONG_PASSWORD":
    case "wrong-password":
      return "Wrong email/password combination.";
    case "ERROR_USER_NOT_FOUND":
    case "user-not-found":
      return "No user found with this email.";
    case "ERROR_USER_DISABLED":
    case "user-disabled":
      return "User disabled.";
    case "ERROR_TOO_MANY_REQUESTS":
    case "operation-not-allowed":
      return "Too many requests to log into this account.";
    case "ERROR_OPERATION_NOT_ALLOWED":
    case "operation-not-allowed":
      return "Server error, please try again later.";
    case "ERROR_INVALID_EMAIL":
    case "invalid-email":
      return "Email address is invalid.";
    default:
      return error.message.toString();
  }
}

List<String> userTypeList = [CLIENT, DELIVERY_MAN];

Future<void> openMap(double originLatitude, double originLongitude, double destinationLatitude, double destinationLongitude) async {
  String googleUrl = 'https://www.google.com/maps/dir/?api=1&origin=$originLatitude,$originLongitude&destination=$destinationLatitude,$destinationLongitude';

  if (await canLaunchUrl(Uri.parse(googleUrl))) {
    await launchUrl(Uri.parse(googleUrl));
  } else {
    throw language.mapLoadingError;
  }
}

Future<BitmapDescriptor> createMarkerIconFromAsset(String assetPath) async {
  final ByteData data = await rootBundle.load(assetPath);
  final Uint8List bytes = data.buffer.asUint8List();
  return BitmapDescriptor.fromBytes(bytes);
}

Color colorFromHex(String hexColor) {
  hexColor = hexColor.toUpperCase().replaceAll("#", "");
  if (hexColor.length == 6) {
    hexColor = "FF$hexColor";
  }
  return Color(int.parse(hexColor, radix: 16));
}

dynamic getClaimStatus(String status) {
  if (status == STATUS_PENDING) {
    return Text(status, style: boldTextStyle(color: pendingColor));
  } else if (status == STATUS_IN_REVIEW) {
    return Text(status, style: boldTextStyle(color: WaitingStatusColor));
  } else if (status == APPROVED) {
    return Text(status, style: boldTextStyle(color: acceptColor));
  } else if (status == STATUS_REJECTED) {
    return Text(status, style: boldTextStyle(color: rejectedColor));
  } else {
    return Text(status, style: boldTextStyle(color: completedColor));
  }
}