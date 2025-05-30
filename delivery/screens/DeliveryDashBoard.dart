import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/models/models.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Widgets.dart';
import '../../main/utils/dynamic_theme.dart';

import '../../extensions/LiveStream.dart';
import '../../extensions/animatedList/animated_list_view.dart';
import '../../extensions/common.dart';
import '../../extensions/decorations.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../fragment/DProfileFragment.dart';
import 'OrdersMapScreen.dart';
import 'ReceivedScreenOrderScreen.dart';
import 'TrackingScreen.dart';

class DeliveryDashBoard extends StatefulWidget {
  final int? selectedIndex;

  DeliveryDashBoard({this.selectedIndex});

  @override
  DeliveryDashBoardState createState() => DeliveryDashBoardState();
}

class DeliveryDashBoardState extends State<DeliveryDashBoard> with TickerProviderStateMixin {
  TabController? tabBarController;
  int currentPage = 1;
  int totalPage = 1;
  bool isLastPage = false;

  List<OrderData> orderData = [];
  List<OrderData> allOrderData = [];
  List<OrderData> acceptedOrderData = [];
  List<OrderData> pickedUpOrderData = [];
  List<OrderData> departedOrderData = [];
  List<OrderData> arrivedOrderData = [];
  List<OrderData> completedOrderData = [];
  List<OrderData> cancelledOrderData = [];

  int index = 0;
  int? selectedTabIndex;

  @override
  void initState() {
    super.initState();
    init();
    
    LiveStream().on('UpdateOrderData', (p0) {
      currentPage = 1;
      init();
      setState(() {});
    });
  }

  void init() async {
    selectedTabIndex = widget.selectedIndex ?? 0;
    tabBarController = TabController(length: 7, vsync: this, initialIndex: selectedTabIndex!);
    getDeliveryManOrders();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  getDeliveryManOrders() async {
    appStore.setLoading(true);
    await getDeliveryBoyOrderList(
      page: currentPage,
      deliveryBoyID: getIntAsync(USER_ID),
      countryId: getIntAsync(COUNTRY_ID),
      cityId: getIntAsync(CITY_ID),
      orderStatus: '',
    ).then((value) {
      appStore.setLoading(false);
      currentPage = value.pagination!.currentPage!;
      totalPage = value.pagination!.totalPages!;
      isLastPage = false;
      
      if (currentPage == 1) {
        orderData.clear();
        allOrderData.clear();
        acceptedOrderData.clear();
        pickedUpOrderData.clear();
        departedOrderData.clear();
        arrivedOrderData.clear();
        completedOrderData.clear();
        cancelledOrderData.clear();
      }
      
      orderData.addAll(value.data!);
      allOrderData.addAll(value.data!);
      
      value.data!.forEach((element) {
        if (element.status == ORDER_ACCEPTED) {
          acceptedOrderData.add(element);
        } else if (element.status == ORDER_PICKED_UP) {
          pickedUpOrderData.add(element);
        } else if (element.status == ORDER_DEPARTED) {
          departedOrderData.add(element);
        } else if (element.status == ORDER_ARRIVED) {
          arrivedOrderData.add(element);
        } else if (element.status == ORDER_COMPLETED || element.status == ORDER_DELIVERED) {
          completedOrderData.add(element);
        } else if (element.status == ORDER_CANCELLED) {
          cancelledOrderData.add(element);
        }
      });
      
      print("Accepted orders count: ${acceptedOrderData.length}");
      print("All orders count: ${allOrderData.length}");
      
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  @override
  void dispose() {
    tabBarController!.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBarTitle: language.myOrders,
      actions: [
        IconButton(
          onPressed: () {
            OrdersMapScreen().launch(context);
          },
          icon: Icon(Icons.location_on_outlined, color: Colors.white),
        ),
        IconButton(
          onPressed: () {
            DProfileFragment().launch(context);
          },
          icon: Icon(Icons.person_outline, color: Colors.white),
        ),
      ],
      body: Column(
        children: [
          TabBar(
            controller: tabBarController,
            labelColor: ColorUtils.colorPrimary,
            unselectedLabelColor: textSecondaryColorGlobal,
            labelStyle: boldTextStyle(),
            unselectedLabelStyle: primaryTextStyle(),
            isScrollable: true,
            indicatorColor: ColorUtils.colorPrimary,
            onTap: (val) {
              selectedTabIndex = val;
              setState(() {});
            },
            tabs: [
              Tab(text: language.all),
              Tab(text: language.accepted),
              Tab(text: language.pickedUp),
              Tab(text: language.arrived),
              Tab(text: language.departed),
              Tab(text: language.completed),
              Tab(text: language.cancelled),
            ],
          ),
          16.height,
          TabBarView(
            controller: tabBarController,
            children: [
              tabBarWidget(allOrderData),
              tabBarWidget(acceptedOrderData),
              tabBarWidget(pickedUpOrderData),
              tabBarWidget(arrivedOrderData),
              tabBarWidget(departedOrderData),
              tabBarWidget(completedOrderData),
              tabBarWidget(cancelledOrderData),
            ],
          ).expand(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: ColorUtils.colorPrimary,
        child: Icon(Icons.refresh, color: Colors.white),
        onPressed: () {
          currentPage = 1;
          getDeliveryManOrders();
        },
      ),
    );
  }

  Widget tabBarWidget(List<OrderData> orderData) {
    return Stack(
      children: [
        AnimatedListView(
          itemCount: orderData.length,
          shrinkWrap: true,
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(left: 16, right: 16, bottom: 50),
          onNextPage: () {
            if (!isLastPage) {
              currentPage++;
              getDeliveryManOrders();
            }
          },
          onSwipeRefresh: () async {
            currentPage = 1;
            getDeliveryManOrders();
            return await Future.delayed(Duration(seconds: 2));
          },
          itemBuilder: (context, index) {
            OrderData data = orderData[index];
            return Container(
              margin: EdgeInsets.only(top: 8, bottom: 8),
              decoration: boxDecorationWithRoundedCorners(
                borderRadius: BorderRadius.circular(defaultRadius),
                border: Border.all(color: ColorUtils.colorPrimary.withOpacity(0.4)),
                backgroundColor: Colors.transparent,
              ),
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('#${data.id}', style: boldTextStyle()),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor(data.status.validate()).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(defaultRadius),
                        ),
                        child: Text(
                          orderStatus(data.status.validate()),
                          style: boldTextStyle(color: statusColor(data.status.validate()), size: 12),
                        ),
                      ),
                    ],
                  ),
                  4.height,
                  Divider(),
                  4.height,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ImageIcon(AssetImage(ic_from), size: 20, color: ColorUtils.colorPrimary),
                      8.width,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.pickupPoint!.address.validate(), style: primaryTextStyle(size: 14)),
                          if (data.pickupPoint!.contactNumber.validate().isNotEmpty)
                            TextIcon(
                              edgeInsets: EdgeInsets.only(top: 4),
                              prefix: Icon(Icons.call, size: 14, color: Colors.green),
                              text: data.pickupPoint!.contactNumber.validate(),
                              textStyle: secondaryTextStyle(),
                              onTap: () {
                                commonLaunchUrl('tel:${data.pickupPoint!.contactNumber.validate()}');
                              },
                            ),
                        ],
                      ).expand(),
                    ],
                  ),
                  8.height,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ImageIcon(AssetImage(ic_to), size: 20, color: ColorUtils.colorPrimary),
                      8.width,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.deliveryPoint!.address.validate(), style: primaryTextStyle(size: 14)),
                          if (data.deliveryPoint!.contactNumber.validate().isNotEmpty)
                            TextIcon(
                              edgeInsets: EdgeInsets.only(top: 4),
                              prefix: Icon(Icons.call, size: 14, color: Colors.green),
                              text: data.deliveryPoint!.contactNumber.validate(),
                              textStyle: secondaryTextStyle(),
                              onTap: () {
                                commonLaunchUrl('tel:${data.deliveryPoint!.contactNumber.validate()}');
                              },
                            ),
                        ],
                      ).expand(),
                    ],
                  ),
                  8.height,
                  Row(
                    children: [
                      Text(language.paymentType, style: secondaryTextStyle()),
                      8.width,
                      Text(paymentType(data.paymentType.validate(value: PAYMENT_TYPE_CASH)), style: primaryTextStyle()),
                      Spacer(),
                      Text(language.amount, style: secondaryTextStyle()),
                      8.width,
                      Text(printAmount(data.totalAmount.validate()), style: boldTextStyle()),
                    ],
                  ),
                  8.height,
                  Row(
                    children: [
                      AppButton(
                        child: Text(language.viewHistory, style: boldTextStyle(color: Colors.white)),
                        color: ColorUtils.colorPrimary,
                        elevation: 0,
                        onTap: () {
                          TrackingScreen(
                            orderId: data.id,
                            order: [data],
                            latLng: LatLng(
                              double.parse(data.deliveryPoint!.latitude.validate()),
                              double.parse(data.deliveryPoint!.longitude.validate()),
                            ),
                          ).launch(context);
                        },
                      ).expand(),
                      16.width,
                      AppButton(
                        child: Text(
                          getButtonTitle(data.status),
                          style: boldTextStyle(color: Colors.white),
                        ),
                        color: ColorUtils.colorPrimary,
                        elevation: 0,
                        onTap: () {
                          if (data.status == ORDER_ASSIGNED) {
                            showConfirmDialogCustom(
                              context,
                              primaryColor: ColorUtils.colorPrimary,
                              title: language.acceptOrderConfirmation,
                              positiveText: language.yes,
                              negativeText: language.no,
                              onAccept: (c) {
                                updateOrder(orderStatus: ORDER_ACCEPTED, orderId: data.id).then((value) {
                                  currentPage = 1;
                                  getDeliveryManOrders();
                                  toast(language.orderActiveSuccessfully);
                                }).catchError((error) {
                                  toast(error.toString());
                                });
                              },
                            );
                          } else if (data.status == ORDER_ACCEPTED) {
                            ReceivedScreenOrderScreen(
                              orderData: data,
                              isShowPayment: data.paymentCollectFrom == PAYMENT_ON_PICKUP,
                            ).launch(context).then((value) {
                              if (value ?? false) {
                                currentPage = 1;
                                getDeliveryManOrders();
                              }
                            });
                          } else if (data.status == ORDER_ARRIVED) {
                            showConfirmDialogCustom(
                              context,
                              primaryColor: ColorUtils.colorPrimary,
                              title: language.orderDepartedConfirmation,
                              positiveText: language.yes,
                              negativeText: language.no,
                              onAccept: (c) {
                                updateOrder(orderStatus: ORDER_DEPARTED, orderId: data.id).then((value) {
                                  currentPage = 1;
                                  getDeliveryManOrders();
                                  toast(language.orderDepartedSuccessfully);
                                }).catchError((error) {
                                  toast(error.toString());
                                });
                              },
                            );
                          } else if (data.status == ORDER_DEPARTED) {
                            ReceivedScreenOrderScreen(
                              orderData: data,
                              isShowPayment: data.paymentCollectFrom == PAYMENT_ON_DELIVERY,
                            ).launch(context).then((value) {
                              if (value ?? false) {
                                currentPage = 1;
                                getDeliveryManOrders();
                              }
                            });
                          } else if (data.status == ORDER_PICKED_UP) {
                            showConfirmDialogCustom(
                              context,
                              primaryColor: ColorUtils.colorPrimary,
                              title: language.orderArrivedConfirmation,
                              positiveText: language.yes,
                              negativeText: language.no,
                              onAccept: (c) {
                                updateOrder(orderStatus: ORDER_ARRIVED, orderId: data.id).then((value) {
                                  currentPage = 1;
                                  getDeliveryManOrders();
                                  toast(language.orderArrivedSuccessfully);
                                }).catchError((error) {
                                  toast(error.toString());
                                });
                              },
                            );
                          }
                        },
                      ).expand().visible(
                            data.status == ORDER_ASSIGNED ||
                            data.status == ORDER_ACCEPTED ||
                            data.status == ORDER_ARRIVED ||
                            data.status == ORDER_DEPARTED ||
                            data.status == ORDER_PICKED_UP,
                          ),
                    ],
                  ),
                ],
              ),
            );
          },
          emptyWidget: !appStore.isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(ic_no_data, height: 80, width: 80),
                    16.height,
                    Text(language.noData, style: boldTextStyle()),
                  ],
                )
              : SizedBox(),
        ),
        Observer(builder: (context) => loaderWidget().visible(appStore.isLoading)),
      ],
    );
  }

  String getButtonTitle(String? status) {
    if (status == ORDER_ASSIGNED) {
      return language.accept;
    } else if (status == ORDER_ACCEPTED) {
      return language.pickUp;
    } else if (status == ORDER_ARRIVED) {
      return language.departed;
    } else if (status == ORDER_DEPARTED) {
      return language.confirmDelivery;
    } else if (status == ORDER_PICKED_UP) {
      return language.arrived;
    }
    return '';
  }
}

class TextIcon extends StatelessWidget {
  final Widget? prefix;
  final String? text;
  final TextStyle? textStyle;
  final Function? onTap;
  final double? width;
  final double? spacing;
  final MainAxisAlignment? mainAxisAlignment;
  final MainAxisSize? mainAxisSize;
  final EdgeInsetsGeometry? edgeInsets;

  TextIcon({
    this.prefix,
    this.text,
    this.textStyle,
    this.onTap,
    this.width,
    this.spacing,
    this.mainAxisAlignment,
    this.mainAxisSize,
    this.edgeInsets,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap as void Function()?,
      child: Container(
        width: width,
        padding: edgeInsets ?? EdgeInsets.all(0),
        child: Row(
          mainAxisAlignment: mainAxisAlignment ?? MainAxisAlignment.start,
          mainAxisSize: mainAxisSize ?? MainAxisSize.min,
          children: [
            prefix ?? SizedBox(),
            SizedBox(width: spacing ?? 4),
            Text(text ?? '', style: textStyle ?? primaryTextStyle()),
          ],
        ),
      ),
    );
  }
}