import 'dart:async';

import 'package:date_time_picker/date_time_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../../delivery/screens/OrdersMapScreen.dart';
import '../../extensions/app_text_field.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../extensions/widgets.dart';
import '../../main/utils/Colors.dart';
import '../../main/utils/Widgets.dart';
import '../../main/utils/dynamic_theme.dart';

import '../../delivery/fragment/DProfileFragment.dart';
import '../../extensions/LiveStream.dart';
import '../../extensions/animatedList/animated_configurations.dart';
import '../../extensions/animatedList/animated_list_view.dart';
import '../../extensions/app_button.dart';
import '../../extensions/colors.dart';
import '../../extensions/common.dart';
import '../../extensions/confirmation_dialog.dart';
import '../../extensions/decorations.dart';
import '../../extensions/horizontal_list.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/CityListModel.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/screens/NotificationScreen.dart';
import '../../main/screens/UserCitySelectScreen.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Images.dart';
import '../../user/screens/OrderDetailScreen.dart';
import 'ReceivedScreenOrderScreen.dart';

const String PAYMENT_TYPE_CASH = 'cash';
const String PAYMENT_TYPE_CARD = 'card';

class DeliveryDashBoard extends StatefulWidget {
  final int selectedIndex;

  DeliveryDashBoard({this.selectedIndex = 0});

  @override
  @override
  DeliveryDashBoardState createState() => DeliveryDashBoardState();
}

class DeliveryDashBoardState extends State<DeliveryDashBoard>
    with WidgetsBindingObserver {
  List<String> statusList = [
    'all_jobs',
    ORDER_ASSIGNED,
    ORDER_ACCEPTED,
    ORDER_ARRIVED,
    ORDER_PICKED_UP,
    ORDER_DEPARTED,
    ORDER_DELIVERED,
    ORDER_CANCELLED,
    ORDER_SHIPPED
  ];
  ScrollController scrollController = ScrollController();
  ScrollController scrollController1 = ScrollController();
  PageController pageController = PageController();
  int currentPage = 1;
  int totalPage = 1;
  int selectedStatusIndex = 0;
  List<OrderData> orderData = [];
  GlobalKey<FormState> rescheduleFormKey = GlobalKey<FormState>();
  TextEditingController reasonTitleTextEditingController =
      TextEditingController();
  TextEditingController dateTextEditingController = TextEditingController();
  TextEditingController pickDateController = TextEditingController();
  DateTime? pickDate;

  // --- FILTER VARIABLES (MINIMAL) ---
  bool showFilters = false;
  String? selectedCity;
  DateTime? fromDate;
  DateTime? toDate;
  double? minPrice;
  double? maxPrice;
  String? selectedVehicleType;
  List<String> vehicleTypes = ['Car', 'Bike', 'Van', 'Truck'];
  double maxDistance = 50.0;
  // --- END FILTER VARIABLES ---

  // Add input decoration helper
  InputDecoration inputDecoration(BuildContext context,
      {required String label}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    init();
  }

  void init() async {
    LiveStream().on('UpdateLanguage', (p0) {
      setState(() {});
    });
    LiveStream().on('UpdateTheme', (p0) {
      setState(() {});
    });
    selectedStatusIndex = widget.selectedIndex;
    await getAppSetting().then((value) {
      print(
          "-------------------------------${value.otpVerifyOnPickupDelivery}");
      appStore
          .setOtpVerifyOnPickupDelivery(value.otpVerifyOnPickupDelivery == 1);
      appStore.setCurrencyCode(value.currencyCode ?? CURRENCY_CODE);
      appStore.setCurrencySymbol(value.currency ?? CURRENCY_SYMBOL);
      appStore.setCurrencyPosition(
          value.currencyPosition ?? CURRENCY_POSITION_LEFT);
      appStore.isVehicleOrder = value.isVehicleInOrder ?? 0;
      appStore.setSiteEmail(value.siteEmail ?? "");
      appStore.setCopyRight(value.siteCopyright ?? "");
      //   appStore.setOrderTrackingIdPrefix(value.orderTrackingIdPrefix ?? "");
      appStore.setIsInsuranceAllowed(value.isInsuranceAllowed ?? "0");
      appStore.setInsurancePercentage(value.insurancePercentage ?? "0");
      appStore.setInsuranceDescription(value.insuranceDescription ?? "");
      appStore.setMaxAmountPerMonth(value.maxEarningsPerMonth ?? '');
      appStore.setClaimDuration(value.claimDuration ?? "");
      // setValue(IS_VERIFIED_DELIVERY_MAN, (value.isVerifiedDeliveryMan.validate() == 1));
    }).catchError((error) {
      log(error.toString());
    });
    if (await checkPermission()) {
      await checkLocationPermission(context);
    }
    scrollController.addListener(() {
      if (scrollController.position.pixels ==
          scrollController.position.maxScrollExtent) {
        if (currentPage < totalPage) {
          appStore.setLoading(true);
          currentPage++;
          setState(() {});
          getOrderListApiCall();
        }
      }
    });
    if (selectedStatusIndex == 5) {
      scrollController1.animateTo(4 * 100,
          duration: Duration(milliseconds: 500), curve: Curves.easeInOut);
    }
    await getOrderListApiCall();
    afterBuildCreated(() => appStore.setLoading(true));
  }

  Future<void> checkLocationPermission(BuildContext context) async {
    initLocationStream();
  }

  void initLocationStream() async {
    positionStream?.cancel();

    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 100,
    );
    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position event) async {
      List<Placemark> placeMarks = await placemarkFromCoordinates(
        event.latitude,
        event.longitude,
      );
      try {
        if (placeMarks.isNotEmpty)
          updateUserStatus({
            "id": getIntAsync(USER_ID),
            "latitude": event.latitude.toString(),
            "longitude": event.longitude.toString(),
          }).then((value) {
            log("value...." + value.toString());
          });
      } catch (e) {}
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        onResumed();
        break;
      default:
    }
  }

  void onResumed() async {
    await checkLocationPermission(context);
    setState(() {});
  }

  getOrderListApiCall() async {
    appStore.setLoading(true);
    try {
      if (statusList[selectedStatusIndex] == 'all_jobs') {
        await getAllAvailableJobsForTransporter(
          page: currentPage,
          maxDistance: maxDistance,
          parcelType: selectedVehicleType,
          minAmount: minPrice,
          maxAmount: maxPrice,
          fromDate: fromDate?.toIso8601String(),
          toDate: toDate?.toIso8601String(),
        ).then((value) {
          appStore.setLoading(false);
          appStore.setAllUnreadCount(value.allUnreadCount.validate());
          currentPage = value.pagination!.currentPage!;
          totalPage = value.pagination!.totalPages!;
          if (currentPage == 1) {
            orderData.clear();
          }
          orderData.addAll(value.data!.where((e) =>
              e.status == 'create' &&
              (e.deliveryManId == null || e.deliveryManId == 0)));
          setState(() {});
        });
      } else if (statusList[selectedStatusIndex] == ORDER_ACCEPTED) {
        log('=== FETCHING ACCEPTED ORDERS ===');
        log('Delivery Man ID: ${getIntAsync(USER_ID)}');
        log('City ID: ${getIntAsync(CITY_ID)}');
        log('Country ID: ${getIntAsync(COUNTRY_ID)}');

        // Try all possible status values
        List<String> statusesToTry = ['courier_assigned', 'active', 'accepted'];

        for (String status in statusesToTry) {
          log('Trying to fetch orders with status: $status');
          try {
            final response = await getDeliveryBoyOrderList(
              page: currentPage,
              deliveryBoyID: getIntAsync(USER_ID),
              cityId: getIntAsync(CITY_ID),
              countryId: getIntAsync(COUNTRY_ID),
              orderStatus: status,
            );

            log('=== API RESPONSE FOR STATUS: $status ===');
            log('Response: $response');
            log('Total items: ${response.pagination?.totalItems}');
            log('Current page: ${response.pagination?.currentPage}');
            log('Total pages: ${response.pagination?.totalPages}');
            log('Number of orders received: ${response.data?.length ?? 0}');

            if (response.data?.isNotEmpty ?? false) {
              log('=== ORDER DETAILS ===');
              response.data?.forEach((order) {
                log('Order ID: ${order.id}');
                log('Status: ${order.status}');
                log('Delivery Man ID: ${order.deliveryManId}');
                log('Pickup Point: ${order.pickupPoint?.address}');
                log('Delivery Point: ${order.deliveryPoint?.address}');
                log('-------------------');
              });

              // Add orders to the list
              orderData.addAll(response.data!
                  .where((e) => e.deliveryManId == getIntAsync(USER_ID)));
              setState(() {});
            }
          } catch (error) {
            log('Error fetching orders with status $status: $error');
          }
        }

        appStore.setLoading(false);
      } else {
        await getDeliveryBoyOrderList(
          page: currentPage,
          deliveryBoyID: getIntAsync(USER_ID),
          cityId: getIntAsync(CITY_ID),
          countryId: getIntAsync(COUNTRY_ID),
          orderStatus: statusList[selectedStatusIndex],
        ).then((value) {
          appStore.setLoading(false);
          appStore.setAllUnreadCount(value.allUnreadCount.validate());
          currentPage = value.pagination!.currentPage!;
          totalPage = value.pagination!.totalPages!;
          if (currentPage == 1) {
            orderData.clear();
          }
          orderData.addAll(value.data!);
          setState(() {});
        });
      }
    } catch (error) {
      log('Error in getOrderListApiCall: $error');
      appStore.setLoading(false);
    }
  }

  Future<void> cancelOrder(OrderData order) async {
    appStore.setLoading(true);
    List<dynamic> cancelledDeliverManIds = order.cancelledDeliverManIds ?? [];
    cancelledDeliverManIds.add(getIntAsync(USER_ID));
    Map req = {
      "id": order.id,
      "cancelled_delivery_man_ids": cancelledDeliverManIds,
    };
    await cancelAutoAssignOrder(req).then((value) {
      appStore.setLoading(false);
      toast(value.message);
      getOrderListApiCall();
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    positionStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBar: PreferredSize(
        preferredSize: Size(context.width(), 110),
        child: commonAppBarWidget(
          '${language.hey} ${getStringAsync(NAME)} 👋',
          showBack: false,
          actions: [
            Container(
              margin: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: boxDecorationWithRoundedCorners(
                  borderRadius: radius(defaultRadius),
                  backgroundColor: Colors.white24),
              child: Row(children: [
                Icon(Ionicons.ios_location_outline,
                    color: Colors.white, size: 18),
                8.width,
                Text(
                    CityModel.fromJson(getJSONAsync(CITY_DATA)).name.validate(),
                    style: primaryTextStyle(color: white)),
              ]).onTap(() {
                UserCitySelectScreen(
                  isBack: true,
                  onUpdate: () {
                    currentPage = 1;
                    getOrderListApiCall();
                    setState(() {});
                  },
                ).launch(context);
              },
                  highlightColor: Colors.transparent,
                  hoverColor: Colors.transparent,
                  splashColor: Colors.transparent),
            ),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Align(
                    alignment: AlignmentDirectional.center,
                    child: Icon(Ionicons.md_notifications_outline,
                        color: Colors.white)),
                Observer(builder: (context) {
                  return Positioned(
                    right: 0,
                    top: 2,
                    child: Container(
                        height: 20,
                        width: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: Colors.orange, shape: BoxShape.circle),
                        child: Text(
                            '${appStore.allUnreadCount < 99 ? appStore.allUnreadCount : '99+'}',
                            style: primaryTextStyle(
                                size: appStore.allUnreadCount < 99 ? 12 : 8,
                                color: Colors.white))),
                  ).visible(appStore.allUnreadCount != 0);
                }),
              ],
            ).withWidth(30).onTap(() {
              NotificationScreen().launch(context);
            }),
            IconButton(
              padding: EdgeInsets.only(right: 8),
              onPressed: () async {
                DProfileFragment().launch(context,
                    pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
              },
              icon: Icon(Ionicons.settings_outline, color: Colors.white),
            ),
            IconButton(
              icon: Icon(Icons.filter_list),
              onPressed: () {
                setState(() {
                  showFilters = !showFilters;
                });
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: Size(context.width(), 100),
            child: HorizontalList(
              controller: scrollController1,
              itemCount: statusList.length,
              itemBuilder: (ctx, index) {
                String label = statusList[index] == 'all_jobs'
                    ? 'All Jobs'
                    : orderStatus(statusList[index]);
                return Theme(
                  data: ThemeData(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent),
                  child: Text(label,
                          style: statusList[selectedStatusIndex] ==
                                  statusList[index]
                              ? boldTextStyle(color: Colors.white)
                              : secondaryTextStyle(color: Colors.white70))
                      .paddingAll(8)
                      .onTap(() {
                    currentPage = 1;
                    selectedStatusIndex = index;
                    pageController.jumpToPage(selectedStatusIndex);
                    setState(() {});
                  }),
                );
              },
            ).paddingOnly(left: 6, right: 6),
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification notification) {
          if (notification is ScrollUpdateNotification &&
              notification.depth == 0) {
            if (notification.dragDetails != null &&
                notification.dragDetails?.delta != null) {
              double? delta = notification.dragDetails?.delta.dx;
              double newPosition = scrollController1.position.pixels - delta!;
              scrollController1.jumpTo(newPosition.clamp(
                  0.0, scrollController1.position.maxScrollExtent));
            }
          }
          return false;
        },
        child: Stack(
          children: [
            Column(
              children: [
                if (showFilters) buildFilterSection(),
                Expanded(
                  child: PageView(
                    controller: pageController,
                    onPageChanged: (value) {
                      selectedStatusIndex = statusList
                          .indexWhere((item) => item == statusList[value]);
                      orderData.clear();
                      getOrderListApiCall();
                      setState(() {});
                    },
                    children: statusList.map((e) {
                      return Stack(
                        children: [
                          AnimatedListView(
                            itemCount: orderData.length,
                            shrinkWrap: true,
                            physics: BouncingScrollPhysics(),
                            listAnimationType: ListAnimationType.Slide,
                            padding: EdgeInsets.only(
                                left: 16, right: 16, top: 16, bottom: 60),
                            flipConfiguration: FlipConfiguration(
                                duration: Duration(seconds: 1),
                                curve: Curves.fastOutSlowIn),
                            fadeInConfiguration: FadeInConfiguration(
                                duration: Duration(seconds: 1),
                                curve: Curves.fastOutSlowIn),
                            onNextPage: () {
                              if (currentPage < totalPage) {
                                currentPage++;
                                setState(() {});
                                getOrderListApiCall();
                              }
                            },
                            onSwipeRefresh: () async {
                              currentPage = 1;
                              await getAppSetting().then((value) {
                                appStore.setOtpVerifyOnPickupDelivery(
                                    value.otpVerifyOnPickupDelivery == 1);
                                appStore.setCurrencyCode(
                                    value.currencyCode ?? CURRENCY_CODE);
                                appStore.setCurrencySymbol(
                                    value.currency ?? CURRENCY_SYMBOL);
                                appStore.setCurrencyPosition(
                                    value.currencyPosition ??
                                        CURRENCY_POSITION_LEFT);
                                appStore.isVehicleOrder =
                                    value.isVehicleInOrder ?? 0;
                                appStore.setSiteEmail(value.siteEmail ?? "");
                                appStore
                                    .setCopyRight(value.siteCopyright ?? "");
                                appStore.setIsInsuranceAllowed(
                                    value.isInsuranceAllowed ?? "0");
                                appStore.setInsurancePercentage(
                                    value.insurancePercentage ?? "0");
                                //   appStore.setOrderTrackingIdPrefix(value.orderTrackingIdPrefix ?? "");
                                appStore.setInsuranceDescription(
                                    value.insuranceDescription ?? "");
                                appStore.setMaxAmountPerMonth(
                                    value.maxEarningsPerMonth ?? '');
                                appStore.setClaimDuration(
                                    value.claimDuration ?? '');
                              }).catchError((error) {
                                log(error.toString());
                              });
                              getOrderListApiCall();
                              return Future.value(true);
                            },
                            itemBuilder: (context, i) {
                              OrderData item = orderData[i];
                              return item.status != ORDER_DRAFT
                                  ? orderCard(item)
                                  : SizedBox();
                            },
                          ).visible(orderData.length > 0),
                          loaderWidget().visible(appStore.isLoading),
                          emptyWidget().visible(
                              orderData.length <= 0 && !appStore.isLoading),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: RoundedRectangleBorder(borderRadius: radius(40)),
        backgroundColor: appStore.availableBal >= 0
            ? ColorUtils.colorPrimary
            : textSecondaryColorGlobal,
        child: Icon(Icons.pin_drop_outlined, color: Colors.white),
        onPressed: () {
          OrdersMapScreen().launch(context);
        },
      ).paddingAll(10),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
    );
  }

  Widget orderCard(OrderData data) {
    return GestureDetector(
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        decoration: boxDecorationWithRoundedCorners(
            borderRadius: BorderRadius.circular(defaultRadius),
            border: Border.all(color: ColorUtils.colorPrimary),
            backgroundColor: Colors.transparent),
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 50,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${language.order}# ${data.id}',
                              style: boldTextStyle(size: 14))
                          .expand(),
                      Text('${data.orderTrackingId}',
                              style: boldTextStyle(
                                  size: 12, color: ColorUtils.colorPrimary))
                          .expand(),
                    ],
                  ),
                ).expand(),
                if (data.status == ORDER_ACCEPTED)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: boxDecorationWithRoundedCorners(
                      backgroundColor: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Ready for Pickup',
                      style: boldTextStyle(color: Colors.green, size: 12),
                    ),
                  ),
                Container(
                  decoration: boxDecorationWithRoundedCorners(
                      backgroundColor: appStore.isDarkMode
                          ? ColorUtils.scaffoldSecondaryDark
                          : ColorUtils.colorPrimaryLight,
                      borderRadius: BorderRadius.circular(defaultRadius),
                      border: Border.all(
                          color: ColorUtils.colorPrimary.withOpacity(0.5))),
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Icon(
                    Icons.navigation_outlined,
                    color: ColorUtils.colorPrimary,
                    size: 28,
                  ),
                )
                    .onTap(() {
                      openMap(
                          double.parse(data.pickupPoint!.latitude.validate()),
                          double.parse(data.pickupPoint!.longitude.validate()),
                          double.parse(data.deliveryPoint!.latitude.validate()),
                          double.parse(
                              data.deliveryPoint!.longitude.validate()));
                    })
                    .paddingSymmetric(horizontal: 5)
                    .visible(data.status != ORDER_DELIVERED &&
                            data.status != ORDER_CANCELLED &&
                            data.status != ORDER_SHIPPED &&
                            data.status != 'create' ||
                        getStringAsync(USER_TYPE) != DELIVERY_MAN),
                Container(
                  decoration: boxDecorationWithRoundedCorners(
                      borderRadius: BorderRadius.circular(defaultRadius),
                      border: Border.all(color: Colors.red),
                      backgroundColor: Colors.red.withOpacity(0.2)),
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Icon(
                    Icons.close,
                    color: Colors.red,
                    size: 28,
                  ),
                ).onTap(() {
                  showConfirmDialogCustom(
                    context,
                    primaryColor: Colors.red,
                    dialogType: DialogType.CONFIRMATION,
                    title: language.orderCancelConfirmation,
                    positiveText: language.yes,
                    negativeText: language.no,
                    onAccept: (c) async {
                      await cancelOrder(data);
                    },
                  );
                }).visible(data.status == ORDER_ASSIGNED),
                (statusList[selectedStatusIndex] == ORDER_ASSIGNED)
                    ? Container(
                        decoration: boxDecorationWithRoundedCorners(
                            borderRadius: BorderRadius.circular(defaultRadius),
                            border: Border.all(color: ColorUtils.colorPrimary),
                            backgroundColor: ColorUtils.colorPrimary),
                        padding:
                            EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 28,
                        ),
                      ).onTap(() {
                        showConfirmDialogCustom(
                          context,
                          primaryColor: ColorUtils.colorPrimary,
                          dialogType: DialogType.CONFIRMATION,
                          title: orderTitle(statusList[selectedStatusIndex]),
                          positiveText: language.yes,
                          negativeText: language.no,
                          onAccept: (c) async {
                            appStore.setLoading(true);
                            await onTapData(
                                orderStatus: statusList[selectedStatusIndex],
                                orderData: data);
                            appStore.setLoading(false);
                            // finish(context);
                          },
                        );
                      }).paddingSymmetric(horizontal: 5)
                    : SizedBox(),
                (statusList[selectedStatusIndex] != ORDER_CANCELLED &&
                        statusList[selectedStatusIndex] != ORDER_ASSIGNED)
                    ? AppButton(
                        elevation: 0,
                        text: data.status == 'create' &&
                                getStringAsync(USER_TYPE) == DELIVERY_MAN
                            ? 'Accept Job'
                            : buttonText(statusList[selectedStatusIndex]),
                        height: 35,
                        width: 120,
                        padding:
                            EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                        textStyle: boldTextStyle(color: Colors.white, size: 14),
                        color: ColorUtils.colorPrimary,
                        onTap: data.status == 'create' &&
                                getStringAsync(USER_TYPE) == DELIVERY_MAN
                            ? () async {
                                await onTapData(
                                    orderStatus: ORDER_ASSIGNED,
                                    orderData: data);
                              }
                            : () {
                                if (statusList[selectedStatusIndex] ==
                                    ORDER_ACCEPTED) {
                                  onTapData(
                                      orderStatus:
                                          statusList[selectedStatusIndex],
                                      orderData: data);
                                } else if (statusList[selectedStatusIndex] ==
                                    ORDER_ARRIVED) {
                                  onTapData(
                                      orderStatus:
                                          statusList[selectedStatusIndex],
                                      orderData: data);
                                } else if (statusList[selectedStatusIndex] ==
                                    ORDER_DEPARTED) {
                                  int val = 0;
                                  return showInDialog(
                                    barrierDismissible: true,
                                    getContext,
                                    builder: (p0) {
                                      return StatefulBuilder(
                                        builder:
                                            (context, selectedImagesUpdate) {
                                          // This is used to toggle the visibility of the reschedule form

                                          return Form(
                                            key: rescheduleFormKey,
                                            child: SingleChildScrollView(
                                              child: Container(
                                                child: !appStore.isLoading
                                                    ? Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .start,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Row(
                                                            children: [
                                                              // Reschedule button - shows the reschedule form
                                                              commonButton(
                                                                  language
                                                                      .reschedule,
                                                                  size: 12, () {
                                                                selectedImagesUpdate(
                                                                    () {
                                                                  val = 1;
                                                                  print(
                                                                      "$val"); // This will make the reschedule form visible
                                                                });
                                                              }).expand(),

                                                              2.width,

                                                              // Departed button - triggers the API call and hides the form
                                                              commonButton(
                                                                language
                                                                    .confirmDelivery,
                                                                size: 12,
                                                                () async {
                                                                  if (context
                                                                      .mounted) {
                                                                    Navigator.pop(
                                                                        context);
                                                                  }
                                                                  onTapData(
                                                                      orderStatus:
                                                                          statusList[
                                                                              selectedStatusIndex],
                                                                      orderData:
                                                                          data);
                                                                },
                                                              ).expand(),
                                                            ],
                                                          ).visible(val == 0),

                                                          // Reschedule form (only visible when val == 1)
                                                          Column(
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .start,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                  language
                                                                      .rescheduleTitle,
                                                                  style:
                                                                      boldTextStyle()),
                                                              10.height,
                                                              Divider(
                                                                  color:
                                                                      dividerColor,
                                                                  height: 1),
                                                              8.height,

                                                              // Reason text field
                                                              Text(
                                                                  language
                                                                      .reason,
                                                                  style:
                                                                      boldTextStyle()),
                                                              12.height,
                                                              AppTextField(
                                                                isValidationRequired:
                                                                    true,
                                                                controller:
                                                                    reasonTitleTextEditingController,
                                                                textFieldType:
                                                                    TextFieldType
                                                                        .NAME,
                                                                errorThisFieldRequired:
                                                                    language
                                                                        .fieldRequiredMsg,
                                                                decoration: commonInputDecoration(
                                                                    hintText:
                                                                        language
                                                                            .reason),
                                                              ),
                                                              8.height,

                                                              // Date picker
                                                              Text(
                                                                  language.date,
                                                                  style:
                                                                      boldTextStyle()),
                                                              12.height,
                                                              DateTimePicker(
                                                                controller:
                                                                    pickDateController,
                                                                type:
                                                                    DateTimePickerType
                                                                        .date,
                                                                initialDate:
                                                                    DateTime
                                                                        .now(),
                                                                firstDate:
                                                                    DateTime
                                                                        .now(),
                                                                lastDate: DateTime
                                                                        .now()
                                                                    .add(Duration(
                                                                        days:
                                                                            30)),
                                                                onChanged:
                                                                    (value) {
                                                                  pickDate =
                                                                      DateTime.parse(
                                                                          value);
                                                                },
                                                                validator:
                                                                    (value) {
                                                                  if (value!
                                                                      .isEmpty)
                                                                    return language
                                                                        .fieldRequiredMsg;
                                                                  return null;
                                                                },
                                                                decoration: commonInputDecoration(
                                                                    suffixIcon:
                                                                        Icons
                                                                            .calendar_today,
                                                                    hintText:
                                                                        language
                                                                            .date),
                                                              ),

                                                              16.height,

                                                              // Buttons inside the reschedule form
                                                              Row(
                                                                children: [
                                                                  commonButton(
                                                                      language
                                                                          .cancel,
                                                                      size: 14,
                                                                      () {
                                                                    finish(
                                                                        getContext,
                                                                        0); // Close the dialog
                                                                  }).expand(),

                                                                  6.width,

                                                                  // Reschedule button inside the form
                                                                  commonButton(
                                                                      language
                                                                          .reschedule,
                                                                      size: 14,
                                                                      () async {
                                                                    if (rescheduleFormKey
                                                                        .currentState!
                                                                        .validate()) {
                                                                      // Trigger the reschedule API call
                                                                      // Example API call
                                                                      Map request =
                                                                          {
                                                                        "order_id":
                                                                            data.id,
                                                                        "reason": reasonTitleTextEditingController
                                                                            .text
                                                                            .toString(),
                                                                        "date":
                                                                            DateFormat('yyyy-MM-dd').format(pickDate!),
                                                                      };
                                                                      appStore.setLoading(
                                                                          true);
                                                                      await rescheduleOrder(
                                                                              request)
                                                                          .then(
                                                                              (value) {
                                                                        toast(value
                                                                            .message);
                                                                        appStore
                                                                            .setLoading(false);
                                                                        finish(
                                                                            context);
                                                                      });
                                                                    }
                                                                  }).expand(),
                                                                ],
                                                              ),
                                                            ],
                                                          ).visible(val == 1),
                                                          // This makes the form visible based on the value of "val"
                                                        ],
                                                      )
                                                    : Observer(
                                                            builder: (context) =>
                                                                loaderWidget()
                                                                    .visible(
                                                                        appStore
                                                                            .isLoading))
                                                        .center(),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  );
                                } else {
                                  showConfirmDialogCustom(
                                    context,
                                    primaryColor: ColorUtils.colorPrimary,
                                    dialogType: DialogType.CONFIRMATION,
                                    title: orderTitle(
                                        statusList[selectedStatusIndex]),
                                    positiveText: language.yes,
                                    negativeText: language.no,
                                    onAccept: (c) async {
                                      appStore.setLoading(true);
                                      await onTapData(
                                          orderStatus:
                                              statusList[selectedStatusIndex],
                                          orderData: data);
                                      appStore.setLoading(false);
                                      // finish(context);
                                    },
                                  );
                                }
                              },
                      )
                        .visible(data.status != ORDER_DELIVERED &&
                            data.status != ORDER_SHIPPED)
                        .paddingOnly(
                            right: appStore.selectedLanguage == "ar" ? 10 : 0)
                    : SizedBox()
              ],
            ),
            8.height,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.pickupDatetime != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(language.picked,
                          style: secondaryTextStyle(size: 12)),
                      4.height,
                      Text(
                          '${language.at} ${printDateWithoutAt("${data.pickupDatetime!}Z")}',
                          style: secondaryTextStyle(size: 12)),
                    ],
                  ),
                4.height,
                Row(
                  children: [
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            OrderDetailScreen(orderId: data.id!).launch(context,
                                pageRouteAnimation:
                                    PageRouteAnimation.SlideBottomTop,
                                duration: 400.milliseconds);
                          },
                          child: Row(
                            children: [
                              ImageIcon(AssetImage(ic_from),
                                  size: 24, color: ColorUtils.colorPrimary),
                              12.width,
                              Text('${data.pickupPoint!.address}',
                                      style: primaryTextStyle(size: 14))
                                  .expand(),
                            ],
                          ),
                        ),
                      ],
                    ).expand(),
                    12.width,
                    if (data.pickupPoint!.contactNumber != null)
                      Icon(Ionicons.ios_call_outline,
                              size: 20, color: ColorUtils.colorPrimary)
                          .onTap(() {
                        commonLaunchUrl(
                            'tel:${data.pickupPoint!.contactNumber}');
                      }),
                  ],
                ),
                if (data.pickupDatetime == null &&
                    data.pickupPoint!.endTime != null &&
                    data.pickupPoint!.startTime != null)
                  Row(
                    children: [
                      Text('${language.note} ${language.courierWillPickupAt} ${DateFormat('dd MMM yyyy').format(DateTime.parse(data.pickupPoint!.startTime!).toLocal())} ${language.from} ${DateFormat('hh:mm').format(DateTime.parse(data.pickupPoint!.startTime!).toLocal())} ${language.to} ${DateFormat('hh:mm').format(DateTime.parse(data.pickupPoint!.endTime!).toLocal())}',
                              style: secondaryTextStyle(
                                  size: 12, color: Colors.red),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)
                          .expand(),
                    ],
                  ),
              ],
            ),
            16.height,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.deliveryDatetime != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(language.delivered,
                          style: secondaryTextStyle(size: 12)),
                      4.height,
                      Text(
                          '${language.at} ${printDateWithoutAt("${data.deliveryDatetime!}Z")}',
                          style: secondaryTextStyle(size: 12)),
                    ],
                  ),
                4.height,
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        OrderDetailScreen(orderId: data.id!).launch(context,
                            pageRouteAnimation:
                                PageRouteAnimation.SlideBottomTop,
                            duration: 400.milliseconds);
                      },
                      child: Row(
                        children: [
                          ImageIcon(AssetImage(ic_to),
                              size: 24, color: ColorUtils.colorPrimary),
                          12.width,
                          Text('${data.deliveryPoint!.address}',
                                  style: primaryTextStyle(size: 14),
                                  textAlign: TextAlign.start)
                              .expand(),
                        ],
                      ),
                    ).expand(),
                    12.width,
                    if (data.deliveryPoint!.contactNumber != null)
                      Icon(Ionicons.ios_call_outline,
                              size: 20, color: ColorUtils.colorPrimary)
                          .onTap(() {
                        commonLaunchUrl(
                            'tel:${data.deliveryPoint!.contactNumber}');
                      }),
                  ],
                ),
                if (data.deliveryDatetime == null &&
                    data.deliveryPoint!.endTime != null &&
                    data.deliveryPoint!.startTime != null)
                  Text('${language.note} ${language.courierWillDeliverAt} ${DateFormat('dd MMM yyyy').format(DateTime.parse(data.deliveryPoint!.startTime!).toLocal())} ${language.from} ${DateFormat('hh:mm').format(DateTime.parse(data.deliveryPoint!.startTime!).toLocal())} ${language.to} ${DateFormat('hh:mm').format(DateTime.parse(data.deliveryPoint!.endTime!).toLocal())}',
                          style:
                              secondaryTextStyle(color: Colors.red, size: 12))
                      .paddingOnly(top: 4),
                if (data.reScheduleDateTime != null)
                  Text('${language.note} ${language.rescheduleMsg} ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(data.reScheduleDateTime!))} ',
                          style:
                              secondaryTextStyle(color: Colors.red, size: 12))
                      .paddingOnly(top: 4)
              ],
            ),
            Divider(height: 30, thickness: 1, color: context.dividerColor),
            Row(
              children: [
                Container(
                  decoration: boxDecorationWithRoundedCorners(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: ColorUtils.borderColor,
                          width: appStore.isDarkMode ? 0.2 : 1),
                      backgroundColor: context.cardColor),
                  padding: EdgeInsets.all(8),
                  child: Image.asset(parcelTypeIcon(data.parcelType.validate()),
                      height: 24, width: 24, color: Colors.grey),
                ),
                8.width,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.parcelType.validate(), style: boldTextStyle()),
                    4.height,
                    Row(
                      children: [
                        data.date != null
                            ? Text(printDate("${data.date}"),
                                    style: secondaryTextStyle())
                                .expand()
                            : SizedBox(),
                        Text('${printAmount(data.totalAmount ?? 0)}',
                            style: boldTextStyle()),
                      ],
                    ),
                  ],
                ).expand(),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: AppButton(
                    elevation: 0,
                    color: Colors.transparent,
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    shapeBorder: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(defaultRadius),
                        side: BorderSide(color: ColorUtils.colorPrimary)),
                    child: Text(language.notifyUser,
                        style:
                            primaryTextStyle(color: ColorUtils.colorPrimary)),
                    onTap: () {
                      showConfirmDialogCustom(
                        context,
                        primaryColor: ColorUtils.colorPrimary,
                        dialogType: DialogType.CONFIRMATION,
                        title: language.areYouSureWantToArrive,
                        positiveText: language.yes,
                        negativeText: language.cancel,
                        onAccept: (c) async {
                          appStore.setLoading(true);
                          await updateOrder(
                                  orderStatus: ORDER_ARRIVED, orderId: data.id)
                              .then((value) {
                            toast(language.orderArrived);
                          });
                          appStore.setLoading(false);
                          // finish(context);
                          int i = statusList
                              .indexWhere((item) => item == ORDER_ARRIVED);
                          pageController.jumpToPage(i);
                          getOrderListApiCall();
                        },
                      );
                    },
                  ),
                ).paddingOnly(top: 10).visible(data.status == ORDER_ACCEPTED),
              ],
            ),
          ],
        ),
      ),
      onTap: () {
        OrderDetailScreen(orderId: data.id!).launch(context,
            pageRouteAnimation: PageRouteAnimation.SlideBottomTop,
            duration: 400.milliseconds);
      },
    );
  }

  Future<void> onTapData(
      {required String orderStatus, required OrderData orderData}) async {
    if (orderStatus == ORDER_ASSIGNED || orderData.status == 'create') {
      FlutterRingtonePlayer().stop();
      try {
        appStore.setLoading(true);
        log('=== ACCEPTING ORDER ===');
        log('Order ID: ${orderData.id}');
        log('Current Status: ${orderData.status}');
        log('Delivery Man ID: ${getIntAsync(USER_ID)}');

        // Create the request body with all necessary data
        Map<String, dynamic> requestBody = {
          'status': 'courier_assigned',
          'delivery_man_id': getIntAsync(USER_ID),
          'order_id': orderData.id,
          'type': 'courier_assigned'
        };

        log('Request Body: $requestBody');

        // Update the order with the complete request body
        await updateOrder(
          orderStatus: 'courier_assigned',
          orderId: orderData.id,
        ).then((value) {
          log('=== ORDER UPDATE RESPONSE ===');
          log('Response: $value');
          toast('Job accepted successfully! Ready for pickup.');
        });

        // Move to the ACCEPTED tab
        int i = statusList.indexWhere((item) => item == ORDER_ACCEPTED);
        pageController.jumpToPage(i);

        // Reset and refresh the list
        currentPage = 1;
        await getOrderListApiCall();

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Job accepted! You can now proceed with pickup.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } catch (e) {
        log('Error updating order status: $e');
        toast('Error accepting job. Please try again.');
      } finally {
        appStore.setLoading(false);
      }
    } else if (orderStatus == ORDER_ACCEPTED ||
        orderStatus == 'accepted' ||
        orderStatus == 'active') {
      DateTime startTime = DateTime.parse(orderData.pickupPoint!.startTime!);
      DateTime endTime = DateTime.parse(orderData.pickupPoint!.endTime!);
      DateTime now = DateTime.now();

      // Check if the current time is between start and end times
      if (now.isAfter(startTime) && now.isBefore(endTime)) {
        await ReceivedScreenOrderScreen(
                orderData: orderData,
                isShowPayment: orderData.paymentId == null &&
                    orderData.paymentCollectFrom == PAYMENT_ON_PICKUP)
            .launch(context,
                pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
        int i = statusList.indexWhere((item) => item == ORDER_PICKED_UP);
        pageController.jumpToPage(i);
        getOrderListApiCall();
      } else {
        toast(language.earlyPickupMsg);
      }
      getOrderListApiCall();
    } else if (orderStatus == ORDER_ARRIVED) {
      bool isCheck = await ReceivedScreenOrderScreen(
              orderData: orderData,
              isShowPayment: orderData.paymentId == null &&
                  orderData.paymentCollectFrom == PAYMENT_ON_PICKUP)
          .launch(context,
              pageRouteAnimation: PageRouteAnimation.SlideBottomTop);

      if (isCheck) {
        getOrderListApiCall();
      }
      int i = statusList.indexWhere((item) => item == ORDER_ARRIVED);
      pageController.jumpToPage(i + 1);
    } else if (orderStatus == ORDER_PICKED_UP) {
      await updateOrder(orderStatus: ORDER_DEPARTED, orderId: orderData.id)
          .then((value) {
        toast(language.orderDepartedSuccessfully);
      });
      int i = statusList.indexWhere((item) => item == ORDER_PICKED_UP);
      pageController.jumpToPage(i + 1);
      getOrderListApiCall();
    } else if (orderStatus == ORDER_DEPARTED) {
      DateTime startTime = DateTime.parse(orderData.pickupDatetime!);
      DateTime now = DateTime.now();
      // Check if the current time is between start and end times
      if (now.isAfter(startTime)) {
        await ReceivedScreenOrderScreen(
                orderData: orderData,
                isShowPayment: orderData.paymentId == null &&
                    orderData.paymentCollectFrom == PAYMENT_ON_DELIVERY)
            .launch(context,
                pageRouteAnimation: PageRouteAnimation.SlideBottomTop);
        int i = statusList.indexWhere((item) => item == ORDER_DEPARTED);
        pageController.jumpToPage(i + 1);
        getOrderListApiCall();
      } else {
        toast(language.earlyDeliveryMsg);
      }
    }
  }

  buttonText(String orderStatus) {
    if (orderStatus == ORDER_ASSIGNED || orderStatus == 'create') {
      return 'Accept Job';
    } else if (orderStatus == ORDER_ACCEPTED) {
      return language.pickUp;
    } else if (orderStatus == ORDER_ARRIVED) {
      return language.pickUp;
    } else if (orderStatus == ORDER_PICKED_UP) {
      return language.departed;
    } else if (orderStatus == ORDER_DEPARTED) {
      return language.confirmDelivery;
    }
    return '';
  }

  // --- FILTER UI (MINIMAL) ---
  Widget buildFilterSection() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: appStore.isDarkMode ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(defaultRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(language.filters, style: boldTextStyle(size: 18)),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    showFilters = false;
                  });
                },
              ),
            ],
          ),
          16.height,
          // City Filter
          DropdownButtonFormField<String>(
            value: selectedCity,
            decoration: inputDecoration(context, label: 'City'),
            items:
                ['New York', 'Los Angeles', 'Chicago', 'Houston'].map((city) {
              return DropdownMenuItem(
                value: city,
                child: Text(city),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedCity = value;
              });
            },
          ),
          16.height,
          // Date Range Filter
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: fromDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        fromDate = date;
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: boxDecorationWithRoundedCorners(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Text(
                      fromDate != null
                          ? DateFormat('MM/dd/yyyy').format(fromDate!)
                          : 'From Date',
                    ),
                  ),
                ),
              ),
              16.width,
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: toDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(Duration(days: 365)),
                    );
                    if (date != null) {
                      setState(() {
                        toDate = date;
                      });
                    }
                  },
                  child: Container(
                    padding: EdgeInsets.all(12),
                    decoration: boxDecorationWithRoundedCorners(
                      border: Border.all(color: Colors.grey),
                    ),
                    child: Text(
                      toDate != null
                          ? DateFormat('MM/dd/yyyy').format(toDate!)
                          : 'To Date',
                    ),
                  ),
                ),
              ),
            ],
          ),
          16.height,
          // Price Range Filter
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: inputDecoration(context, label: 'Min Price'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      minPrice = double.tryParse(value);
                    });
                  },
                ),
              ),
              16.width,
              Expanded(
                child: TextFormField(
                  decoration: inputDecoration(context, label: 'Max Price'),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    setState(() {
                      maxPrice = double.tryParse(value);
                    });
                  },
                ),
              ),
            ],
          ),
          16.height,
          // Vehicle Type Filter
          DropdownButtonFormField<String>(
            value: selectedVehicleType,
            decoration: inputDecoration(context, label: 'Vehicle Type'),
            items: vehicleTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                selectedVehicleType = value;
              });
            },
          ),
          16.height,
          // Apply Filters Button
          AppButton(
            text: 'Apply Filters',
            color: ColorUtils.colorPrimary,
            textColor: Colors.white,
            onTap: () {
              setState(() {
                showFilters = false;
                currentPage = 1;
                orderData.clear();
              });
              getOrderListApiCall();
            },
          ),
        ],
      ),
    );
  }

  void showBidForm(OrderData data) {
    // Implement bid dialog logic here or call existing bid dialog
  }
}
