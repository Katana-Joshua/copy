import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

enum InstallationSource {
  PLAY_STORE,
  GOOGLE_PACKAGE_INSTALLER,
  RUSTORE,
  LOCAL_SOURCE,
  AMAZON_STORE,
  HUAWEI_APP_GALLERY,
  SAMSUNG_GALAXY_STORE,
  SAMSUNG_SMART_SWITCH_MOBILE,
  XIAOMI_GET_APPS,
  OPPO_APP_MARKET,
  VIVO_APP_STORE,
  OTHER_SOURCE,
  APP_STORE,
  TEST_FLIGHT,
  UNKNOWN
}

class CustomStoreChecker {
  static Future<InstallationSource> getSource() async {
    try {
      if (Platform.isAndroid) {
        return await _getAndroidSource();
      } else if (Platform.isIOS) {
        return await _getIOSSource();
      }
      return InstallationSource.UNKNOWN;
    } catch (e) {
      return InstallationSource.UNKNOWN;
    }
  }

  static Future<InstallationSource> _getAndroidSource() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = await DeviceInfoPlugin().androidInfo;

      // Get the installer package name
      String? installerPackageName;
      try {
        const platform = MethodChannel('store_checker');
        installerPackageName =
            await platform.invokeMethod<String>('getInstallerPackageName');
      } catch (e) {
        // If we can't get the installer package name, try to determine it from other sources
        installerPackageName = packageInfo.packageName;
      }

      // Check if app is installed from Play Store
      if (installerPackageName?.toLowerCase().contains('com.android.vending') ??
          false) {
        return InstallationSource.PLAY_STORE;
      }

      // Check for other stores based on package name
      final packageName = packageInfo.packageName.toLowerCase();
      if (packageName.contains('amazon')) {
        return InstallationSource.AMAZON_STORE;
      } else if (packageName.contains('huawei')) {
        return InstallationSource.HUAWEI_APP_GALLERY;
      } else if (packageName.contains('samsung')) {
        return InstallationSource.SAMSUNG_GALAXY_STORE;
      } else if (packageName.contains('xiaomi')) {
        return InstallationSource.XIAOMI_GET_APPS;
      } else if (packageName.contains('oppo')) {
        return InstallationSource.OPPO_APP_MARKET;
      } else if (packageName.contains('vivo')) {
        return InstallationSource.VIVO_APP_STORE;
      }

      // Check if app is installed from package installer
      if (installerPackageName
              ?.toLowerCase()
              .contains('com.google.android.packageinstaller') ??
          false) {
        return InstallationSource.GOOGLE_PACKAGE_INSTALLER;
      }

      // Check if app is installed from local source
      if (installerPackageName == null || installerPackageName.isEmpty) {
        return InstallationSource.LOCAL_SOURCE;
      }

      return InstallationSource.OTHER_SOURCE;
    } catch (e) {
      return InstallationSource.UNKNOWN;
    }
  }

  static Future<InstallationSource> _getIOSSource() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();

      // For iOS, we can check if the app is running in TestFlight
      if (packageInfo.packageName.toLowerCase().contains('testflight')) {
        return InstallationSource.TEST_FLIGHT;
      }

      // If not in TestFlight, it's likely from App Store
      return InstallationSource.APP_STORE;
    } catch (e) {
      return InstallationSource.UNKNOWN;
    }
  }
}
