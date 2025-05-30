import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../delivery/screens/AddDeliverymanVehicleScreen.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/list_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/models/DeliverymanVehicleListModel.dart';
import '../../main/screens/RewardListScreen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../main/models/DeliveryDocumentListModel.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/utils/Widgets.dart';

import '../../extensions/LiveStream.dart';
import '../../extensions/animatedList/animated_scroll_view.dart';
import '../../extensions/colors.dart';
import '../../extensions/common.dart';
import '../../extensions/confirmation_dialog.dart';
import '../../extensions/decorations.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/text_styles.dart';
import '../../extensions/widgets.dart';
import '../../main.dart';
import '../../main/components/theme_selection_dialog.dart';
import '../../main/models/PageListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/screens/AboutUsScreen.dart';
import '../../main/screens/ChangePasswordScreen.dart';
import '../../main/screens/CustomerSupportScreen.dart';
import '../../main/screens/EditProfileScreen.dart';
import '../../main/screens/LanguageScreen.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Images.dart';
import '../../main/utils/dynamic_theme.dart';
import '../../user/screens/DeleteAccountScreen.dart';
import '../../user/screens/PageDetailScreen.dart';
import '../../user/screens/WalletScreen.dart';
import '../screens/EarningHistoryScreen.dart';
import '../screens/SelectVehicleScreen.dart';
import '../screens/VerifyDeliveryPersonScreen.dart';

class DProfileFragment extends StatefulWidget {
  @override
  DProfileFragmentState createState() => DProfileFragmentState();
}

class DProfileFragmentState extends State<DProfileFragment> {
  List<PageData> pageList = [];
  DeliverymanVehicle? vehicle;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    try {
      vehicle = DeliverymanVehicle.fromJson(getJSONAsync(VEHICLE));
    } catch (e) {
      appStore.setLoading(false);
    }
    LiveStream().on('UpdateLanguage', (p0) {
      setState(() {});
    });
    LiveStream().on('UpdateTheme', (p0) {
      setState(() {});
    });
    getPageListApi();

    LiveStream().on('VehicleInfo', (p0) {
      vehicle = DeliverymanVehicle.fromJson(getJSONAsync(VEHICLE));
      setState(() {});
    });

    setState(() {});
  }

  Future<void> getPageListApi() async {
    appStore.setLoading(true);
    await getPagesList().then((value) {
      appStore.setLoading(false);
      if (value.data.validate().isNotEmpty) {
        pageList.addAll(value.data!);
      }
      setState(() {});
    }).catchError((e) {
      appStore.setLoading(false);
      toast(e.toString(), print: true);
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  Widget accountSettingItemWidget(String? img, String title, Function() onTap,
      {bool isLast = false, IconData? suffixIcon}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            minLeadingWidth: 14,
            dense: true,
            leading: Image.asset(img.validate(),
                height: 18,
                fit: BoxFit.fill,
                width: 18,
                color: textPrimaryColorGlobal),
            title: Text(title, style: primaryTextStyle()),
            trailing: suffixIcon != null
                ? Icon(suffixIcon, color: Colors.green)
                : Icon(Icons.navigate_next,
                    color: appStore.isDarkMode ? Colors.white : Colors.grey),
            onTap: onTap),
        if (isLast) Divider(height: 0, color: ColorUtils.dividerColor)
      ],
    );
  }

  Widget mTitle(String value) {
    return Text(value.toUpperCase(),
            style: boldTextStyle(
                size: 12, letterSpacing: 0.7, color: textSecondaryColorGlobal))
        .paddingOnly(left: 16, right: 16, top: 24, bottom: 4);
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBarTitle: language.profile,
      body: Observer(
        builder: (_) => Stack(
          children: [
            SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                              decoration: boxDecorationWithRoundedCorners(
                                  boxShape: BoxShape.circle,
                                  border: Border.all(
                                      width: 2,
                                      color: ColorUtils.colorPrimary)),
                              child: commonCachedNetworkImage(
                                      appStore.userProfile.validate(),
                                      height: 65,
                                      width: 65,
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center)
                                  .cornerRadiusWithClipRRect(50)),
                          Container(
                              decoration: boxDecorationWithRoundedCorners(
                                  boxShape: BoxShape.circle,
                                  border: Border.all(width: 1, color: white),
                                  backgroundColor: ColorUtils.colorPrimary),
                              padding: EdgeInsets.all(4),
                              child: Image.asset(ic_edit,
                                  color: white, height: 14, width: 14))
                        ],
                      ),
                      10.width,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(getStringAsync(NAME).validate(),
                              style: boldTextStyle(size: 20)),
                          6.height,
                          Text(appStore.userEmail.validate(),
                              style: secondaryTextStyle(size: 16)),
                        ],
                      )
                    ],
                  ).onTap(() {
                    EditProfileScreen().launch(context);
                  }).paddingOnly(top: 12, right: 12, left: 12),
                  ListView(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      mTitle(language.ordersWalletMore),
                      Container(
                        decoration: boxDecorationWithRoundedCorners(
                            borderRadius: BorderRadius.circular(defaultRadius),
                            border: Border.all(
                                color:
                                    ColorUtils.colorPrimary.withOpacity(0.3)),
                            backgroundColor: Colors.transparent),
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        margin:
                            EdgeInsets.symmetric(horizontal: 15, vertical: 4),
                        child: Row(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  vehicle != null
                                      ? language.yourVehicle
                                      : language.noVehicleAdded,
                                  style: primaryTextStyle(),
                                ),
                                Text(
                                  vehicle != null
                                      ? "${vehicle!.vehicleInfo.make.validate()}"
                                      : "-",
                                  style: boldTextStyle(),
                                ),
                              ],
                            ),
                            Spacer(),
                            Container(
                              decoration: boxDecorationWithRoundedCorners(
                                  borderRadius:
                                      BorderRadius.circular(defaultRadius),
                                  backgroundColor: ColorUtils.colorPrimary),
                              padding: EdgeInsets.symmetric(
                                  horizontal: 15, vertical: 5),
                              child: Text(
                                vehicle != null
                                    ? language.update
                                    : language.add,
                                style: TextStyle(color: Colors.white),
                              ),
                            ).onTap(() {
                              AddDeliverymanVehicleScreen(
                                vehicle: vehicle != null
                                    ? vehicle!.vehicleInfo
                                    : null,
                                isUpdate: true,
                              ).launch(context);
                            })
                          ],
                        ),
                      ),
                      accountSettingItemWidget(
                          ic_earning, language.earningHistory, () {
                        EarningHistoryScreen().launch(context);
                      }),
                      accountSettingItemWidget(ic_wallet, language.wallet, () {
                        WalletScreen().launch(context);
                      }),
                      accountSettingItemWidget(
                          ic_vehicle_list, language.vehicleHistory, () {
                        SelectVehicleScreen().launch(context);
                      }),
                      mTitle(language.account),
                      accountSettingItemWidget(
                          ic_verification, language.verifyDocument, () {
                        VerifyDeliveryPersonScreen().launch(context);
                      },
                          suffixIcon: getBoolAsync(IS_VERIFIED_DELIVERY_MAN)
                              ? Icons.verified_user
                              : null),
                      accountSettingItemWidget(
                          ic_change_password, language.changePassword, () {
                        ChangePasswordScreen().launch(context);
                      }),
                      accountSettingItemWidget(ic_languages, language.language,
                          () {
                        LanguageScreen().launch(context);
                      }),
                      accountSettingItemWidget(ic_dark_mode, language.theme,
                          () async {
                        await showInDialog(context,
                            shape:
                                RoundedRectangleBorder(borderRadius: radius()),
                            builder: (_) => ThemeSelectionDialog(),
                            contentPadding: EdgeInsets.zero);
                      }),
                      accountSettingItemWidget(
                          ic_change_password, language.customerSupport, () {
                        CustomerSupportScreen().launch(context);
                      }),
                      accountSettingItemWidget(
                          ic_delete_account, language.deleteAccount, () async {
                        DeleteAccountScreen().launch(context);
                      }, isLast: true),
                      mTitle(language.general),
                      accountSettingItemWidget(
                          ic_document, language.privacyPolicy, () {
                        commonLaunchUrl(mPrivacyPolicy);
                      }),
                      accountSettingItemWidget(
                          ic_information, language.helpAndSupport, () {
                        //    commonLaunchUrl(appStore.siteEmail);
                        print("--------------${appStore.siteEmail}");
                        commonLaunchUrl('mailto:${appStore.siteEmail}');
                      }),
                      accountSettingItemWidget(
                          ic_document, language.termAndCondition, () {
                        commonLaunchUrl(mTermAndCondition);
                      }),
                      accountSettingItemWidget(ic_information, language.aboutUs,
                          () {
                        AboutUsScreen().launch(context);
                      }, isLast: pageList.isNotEmpty),
                      if (pageList.isNotEmpty) ...[
                        mTitle(language.pages),
                        ListView.builder(
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            PageData item = pageList[index];
                            return accountSettingItemWidget(
                                ic_pages, item.title.validate(), () {
                              PageDetailScreen(
                                title: item.title.validate(),
                                description: item.description.validate(),
                              ).launch(context);
                            });
                          },
                          itemCount: pageList.length,
                        )
                      ],
                      Container(
                        decoration: boxDecorationWithRoundedCorners(
                            border: Border.all(
                                color: ColorUtils.colorPrimary, width: 1),
                            backgroundColor: Colors.transparent),
                        padding: EdgeInsets.all(16),
                        width: context.width(),
                        child: Text(language.logout,
                            style: boldTextStyle(
                                size: 18, color: ColorUtils.colorPrimary),
                            textAlign: TextAlign.center),
                      ).onTap(() async {
                        await showConfirmDialogCustom(
                          context,
                          primaryColor: ColorUtils.colorPrimary,
                          title: language.logoutConfirmationMsg,
                          positiveText: language.yes,
                          negativeText: language.no,
                          onAccept: (c) {
                            logout(context);
                          },
                        );
                      }).paddingAll(16),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (_, snap) {
                          if (snap.hasData) {
                            return Text(
                                    '${language.version} ${snap.data!.version.validate()}',
                                    style: secondaryTextStyle())
                                .center();
                          }
                          return SizedBox();
                        },
                      ),
                      16.height,
                    ],
                  ),
                  Container(
                    margin: EdgeInsets.only(top: 16),
                    padding: EdgeInsets.all(16),
                    decoration: boxDecorationWithRoundedCorners(
                      backgroundColor: appStore.isDarkMode
                          ? ColorUtils.scaffoldSecondaryDark
                          : Colors.white,
                      borderRadius: BorderRadius.circular(defaultRadius),
                      border: Border.all(
                          color: ColorUtils.colorPrimary.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(language.documentVerification,
                            style: boldTextStyle(size: 16)),
                        16.height,
                        FutureBuilder(
                          future: getDeliveryPersonDocumentList(),
                          builder: (context,
                              AsyncSnapshot<DeliveryDocumentListModel>
                                  snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return loaderWidget();
                            }

                            if (snapshot.hasError) {
                              return Text('Error loading documents',
                                  style: secondaryTextStyle());
                            }

                            final documents = snapshot.data?.data ?? [];
                            if (documents.isEmpty) {
                              return Text('No documents uploaded',
                                  style: secondaryTextStyle());
                            }

                            return Column(
                              children: documents.map((doc) {
                                final isVerified = doc.isVerified == 1;

                                return Container(
                                  margin: EdgeInsets.only(bottom: 12),
                                  padding: EdgeInsets.all(12),
                                  decoration: boxDecorationWithRoundedCorners(
                                    backgroundColor: appStore.isDarkMode
                                        ? Colors.grey.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.05),
                                    borderRadius:
                                        BorderRadius.circular(defaultRadius),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isVerified
                                            ? Icons.verified
                                            : Icons.pending,
                                        color: isVerified
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                      12.width,
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(doc.documentName ?? '',
                                                style: primaryTextStyle()),
                                            4.height,
                                            Text(
                                              isVerified
                                                  ? 'Verified'
                                                  : 'Pending Verification',
                                              style: secondaryTextStyle(
                                                color: isVerified
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (!isVerified)
                                        TextButton(
                                          onPressed: () {
                                            VerifyDeliveryPersonScreen()
                                                .launch(context);
                                          },
                                          child: Text(language.verify,
                                              style: primaryTextStyle(
                                                  color:
                                                      ColorUtils.colorPrimary)),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            loaderWidget().center().visible(appStore.isLoading),
          ],
        ),
      ),
    );
  }
}