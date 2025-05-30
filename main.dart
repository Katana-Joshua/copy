import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:geolocator/geolocator.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../main/services/OrdersMessageService.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main/models/models.dart';
import '../main/screens/SplashScreen.dart';
import '../main/utils/Constants.dart';
import 'extensions/common.dart';
import 'extensions/shared_pref.dart';
import 'languageConfiguration/AppLocalizations.dart';
import 'languageConfiguration/BaseLanguage.dart';
import 'languageConfiguration/LanguageDataConstant.dart';
import 'languageConfiguration/LanguageDefaultJson.dart';
import 'languageConfiguration/ServerLanguageResponse.dart';
import 'main/helper/encrypt_data.dart';
import 'main/models/FileModel.dart';
import 'main/network/RestApis.dart';
import 'main/screens/NoInternetScreen.dart';
import 'main/services/AuthServices.dart';
import 'main/services/EscrowService.dart';
import 'main/services/NotificationService.dart';
import 'main/services/UserServices.dart';
import 'main/store/AppStore.dart';
import 'main/utils/Common.dart';
import 'main/utils/firebase_options.dart';

final navigatorKey = GlobalKey<NavigatorState>();
late SharedPreferences sharedPreferences;
AppStore appStore = AppStore();
late BaseLanguage language;
// Added by SK
LanguageJsonData? selectedServerLanguageData;
List<LanguageJsonData>? defaultServerLanguageData = [];

UserService userService = UserService();
//ChatMessageService chatMessageService = ChatMessageService();
AuthServices authService = AuthServices();
OrdersMessageService ordersMessageService = OrdersMessageService();
NotificationService notificationService = NotificationService();
EscrowService escrowService = EscrowService();
late List<FileModel> fileList = [];
bool isCurrentlyOnNoInternet = false;
StreamSubscription<Position>? positionStream;
bool mIsEnterKey = false;
String mSelectedImage = "assets/default_wallpaper.png";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Platform.isIOS) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
  } catch (e) {
    print("Firebase initialization error: ${e.toString()}");
  }

  sharedPreferences = await SharedPreferences.getInstance();

  // Initialize app store
  appStore.setLanguage(getStringAsync(SELECTED_LANGUAGE_CODE,
      defaultValue: defaultLanguageCode));
  appStore.setLogin(getBoolAsync(IS_LOGGED_IN), isInitializing: true);
  appStore.setUserEmail(getStringAsync(USER_EMAIL), isInitialization: true);
  appStore.setUserProfile(getStringAsync(USER_PROFILE_PHOTO),
      isInitializing: true);

  // Initialize theme with hard-coded color
  appStore.setThemeColor("#0e53a1"); // Red color
  appStore.updateTheme(colorFromHex("#0e53a1"));

  // Initialize theme mode
  int themeModeIndex = getIntAsync(THEME_MODE_INDEX);
  if (themeModeIndex == appThemeMode.themeModeLight) {
    appStore.setDarkMode(false);
  } else if (themeModeIndex == appThemeMode.themeModeDark) {
    appStore.setDarkMode(true);
  }

  // Initialize other services
  initJsonFile();
  oneSignalSettings();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  String? color;

  @override
  void initState() {
    super.initState();
    init();
    getColor();
  }

  void init() async {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((e) {
      if (e.contains(ConnectivityResult.none)) {
        log('not connected');
        isCurrentlyOnNoInternet = true;
        push(NoInternetScreen());
      } else {
        if (isCurrentlyOnNoInternet) {
          pop();
          isCurrentlyOnNoInternet = false;
          //   nb.toast(language.internetIsConnected);
        }
        log('connected');
      }
    });
  }

  getColor() async {
    await getLanguageList(0).then((value) {
      color = value.themeColor;
      appStore.setThemeColor(value.themeColor!);
      appStore.updateTheme(colorFromHex(value.themeColor!));
      setState(() {});
    });
  }

  @override
  void setState(VoidCallback fn) {
    _connectivitySubscription.cancel();
    super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (context) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) {
          return ScrollConfiguration(
            behavior: MyBehavior(),
            child: child!,
          );
        },
        title: 'Trade Verge',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        darkTheme: appStore.darkTheme,
        themeMode: appStore.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: const [
          AppLocalizations(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: getSupportedLocales(),
        locale: const Locale('en'),
        home: SplashScreen(),
      );
    });
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}