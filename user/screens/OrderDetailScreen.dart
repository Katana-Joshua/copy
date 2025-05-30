import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_vector_icons/flutter_vector_icons.dart';
import 'package:intl/intl.dart';
import '../../extensions/extension_util/context_extensions.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';
import '../../main/models/OrderDetailModel.dart';
import '../../main/utils/Common.dart';
import '../../main/utils/Widgets.dart';
import '../../main/utils/dynamic_theme.dart';

import '../../extensions/LiveStream.dart';
import '../../extensions/app_button.dart';
import '../../extensions/common.dart';
import '../../extensions/confirmation_dialog.dart';
import '../../extensions/decorations.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../../main/Chat/ChatScreen.dart';
import '../../main/components/CommonScaffoldComponent.dart';
import '../../main/components/OrderSummeryWidget.dart';
import '../../main/models/LoginResponse.dart';
import '../../main/models/OrderListModel.dart';
import '../../main/network/RestApis.dart';
import '../../main/utils/Constants.dart';
import '../../main/utils/Images.dart';
import '../components/CancelOrderDialog.dart';
import 'OrderHistoryScreen.dart';
import 'OrderTrackingScreen.dart';
import 'ReturnOrderScreen.dart';

class OrderDetailScreen extends StatefulWidget {
  static String tag = '/OrderDetailScreen';

  final int? orderId;

  OrderDetailScreen({this.orderId});

  @override
  OrderDetailScreenState createState() => OrderDetailScreenState();
}

class OrderDetailScreenState extends State<OrderDetailScreen> {
  OrderDetailModel? orderDetailModel;
  OrderData? orderData;
  Payment? payment;
  List<OrderHistory>? orderHistory = [];
  UserData? userData;

  @override
  void initState() {
    super.initState();
    init();
    LiveStream().on('UpdateOrderData', (p0) {
      init();
      setState(() {});
    });
  }

  void init() async {
    appStore.setLoading(true);
    await getOrderDetails(widget.orderId!).then((value) {
      appStore.setLoading(false);
      orderDetailModel = value;
      orderData = value.data;
      payment = value.payment;
      orderHistory = value.orderHistory;
      userData = value.deliveryManDetail;
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  void dispose() {
    LiveStream().dispose('UpdateOrderData');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBarTitle: language.yourOrder,
      actions: [
        IconButton(
          icon: Icon(Icons.history, color: Colors.white),
          onPressed: () {
            OrderHistoryScreen(orderHistory: orderHistory!).launch(context);
          },
        ).visible(orderHistory!.isNotEmpty),
      ],
      body: Observer(builder: (context) {
        return Stack(
          children: [
            orderData != null
                ? SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text('${language.orderId}:', style: boldTextStyle()),
                                4.width,
                                Text('#${orderData!.id}', style: boldTextStyle()),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: statusColor(orderData!.status.validate()).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8)),
                              child: Text(orderStatus(orderData!.status.validate()),
                                  style: boldTextStyle(color: statusColor(orderData!.status.validate()), size: 12)),
                            ),
                          ],
                        ),
                        16.height,
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: boxDecorationWithRoundedCorners(
                              borderRadius: BorderRadius.circular(defaultRadius),
                              border: Border.all(color: ColorUtils.colorPrimary.withOpacity(0.3)),
                              backgroundColor: Colors.transparent),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  ImageIcon(AssetImage(ic_from), size: 18, color: ColorUtils.colorPrimary),
                                  16.width,
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(language.pickupLocation, style: boldTextStyle(size: 16)),
                                      4.height,
                                      Text(orderData!.pickupPoint!.address.validate(),
                                          style: secondaryTextStyle()),
                                      if (orderData!.pickupPoint!.contactNumber.validate().isNotEmpty)
                                        TextIcon(
                                          edgeInsets: EdgeInsets.only(top: 4),
                                          prefix: Icon(Icons.call, size: 14, color: Colors.green),
                                          text: orderData!.pickupPoint!.contactNumber.validate(),
                                          textStyle: secondaryTextStyle(),
                                          onTap: () {
                                            commonLaunchUrl(
                                                'tel:${orderData!.pickupPoint!.contactNumber.validate()}');
                                          },
                                        ),
                                      if (orderData!.pickupDatetime != null)
                                        TextIcon(
                                          edgeInsets: EdgeInsets.only(top: 4),
                                          prefix: Icon(Icons.access_time_rounded, size: 14, color: Colors.blue),
                                          text: printDate(orderData!.pickupDatetime.validate()),
                                          textStyle: secondaryTextStyle(),
                                        ),
                                    ],
                                  ).expand(),
                                ],
                              ),
                              16.height,
                              Row(
                                children: [
                                  ImageIcon(AssetImage(ic_to), size: 18, color: ColorUtils.colorPrimary),
                                  16.width,
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(language.deliveryLocation, style: boldTextStyle(size: 16)),
                                      4.height,
                                      Text(orderData!.deliveryPoint!.address.validate(),
                                          style: secondaryTextStyle()),
                                      if (orderData!.deliveryPoint!.contactNumber.validate().isNotEmpty)
                                        TextIcon(
                                          edgeInsets: EdgeInsets.only(top: 4),
                                          prefix: Icon(Icons.call, size: 14, color: Colors.green),
                                          text: orderData!.deliveryPoint!.contactNumber.validate(),
                                          textStyle: secondaryTextStyle(),
                                          onTap: () {
                                            commonLaunchUrl(
                                                'tel:${orderData!.deliveryPoint!.contactNumber.validate()}');
                                          },
                                        ),
                                      if (orderData!.deliveryDatetime != null)
                                        TextIcon(
                                          edgeInsets: EdgeInsets.only(top: 4),
                                          prefix: Icon(Icons.access_time_rounded, size: 14, color: Colors.blue),
                                          text: printDate(orderData!.deliveryDatetime.validate()),
                                          textStyle: secondaryTextStyle(),
                                        ),
                                    ],
                                  ).expand(),
                                ],
                              ),
                            ],
                          ),
                        ),
                        16.height,
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: boxDecorationWithRoundedCorners(
                              borderRadius: BorderRadius.circular(defaultRadius),
                              border: Border.all(color: ColorUtils.colorPrimary.withOpacity(0.3)),
                              backgroundColor: Colors.transparent),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(language.parcelDetails, style: boldTextStyle()),
                              8.height,
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
                                    child: Image.asset(parcelTypeIcon(orderData!.parcelType.validate()),
                                        height: 24, width: 24, color: ColorUtils.colorPrimary),
                                  ),
                                  16.width,
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(orderData!.parcelType.validate(), style: boldTextStyle()),
                                      4.height,
                                      Row(
                                        children: [
                                          Text('${language.weight}: ', style: secondaryTextStyle()),
                                          Text(
                                              '${orderData!.totalWeight} ${CountryModel.fromJson(getJSONAsync(COUNTRY_DATA)).weightType}',
                                              style: primaryTextStyle()),
                                        ],
                                      ),
                                      4.height,
                                      Row(
                                        children: [
                                          Text('${language.numberOfParcels}: ', style: secondaryTextStyle()),
                                          Text('${orderData!.totalParcel}', style: primaryTextStyle()),
                                        ],
                                      ),
                                    ],
                                  ).expand(),
                                ],
                              ),
                            ],
                          ),
                        ),
                        16.height,
                        if (userData != null)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: boxDecorationWithRoundedCorners(
                                borderRadius: BorderRadius.circular(defaultRadius),
                                border: Border.all(color: ColorUtils.colorPrimary.withOpacity(0.3)),
                                backgroundColor: Colors.transparent),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(language.aboutDeliveryMan, style: boldTextStyle()),
                                8.height,
                                Row(
                                  children: [
                                    commonCachedNetworkImage(userData!.profileImage.validate(),
                                            height: 60, width: 60, fit: BoxFit.cover)
                                        .cornerRadiusWithClipRRect(30),
                                    16.width,
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(userData!.name.validate(), style: boldTextStyle()),
                                        4.height,
                                        TextIcon(
                                          edgeInsets: EdgeInsets.only(top: 4),
                                          prefix: Icon(Icons.call, size: 14, color: Colors.green),
                                          text: userData!.contactNumber.validate(),
                                          textStyle: secondaryTextStyle(),
                                          onTap: () {
                                            commonLaunchUrl('tel:${userData!.contactNumber.validate()}');
                                          },
                                        ),
                                      ],
                                    ).expand(),
                                    IconButton(
                                      icon: Icon(Icons.chat, color: ColorUtils.colorPrimary),
                                      onPressed: () {
                                        ChatScreen(
                                          userData: userData,
                                          orderId: orderData!.id.toString(),
                                        ).launch(context);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        16.height,
                        if (payment != null)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: boxDecorationWithRoundedCorners(
                                borderRadius: BorderRadius.circular(defaultRadius),
                                border: Border.all(color: ColorUtils.colorPrimary.withOpacity(0.3)),
                                backgroundColor: Colors.transparent),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(language.paymentDetails, style: boldTextStyle()),
                                8.height,
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(language.paymentType, style: secondaryTextStyle()),
                                    Text(paymentType(payment!.paymentType.validate()), style: primaryTextStyle()),
                                  ],
                                ),
                                4.height,
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(language.paymentStatus, style: secondaryTextStyle()),
                                    Text(paymentStatus(payment!.paymentStatus.validate()),
                                        style: primaryTextStyle(
                                            color: paymentStatusColor(payment!.paymentStatus.validate()))),
                                  ],
                                ),
                                4.height,
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(language.paymentCollectFrom, style: secondaryTextStyle()),
                                    Text(
                                        paymentCollectForm(orderData!.paymentCollectFrom.validate())!,
                                        style: primaryTextStyle()),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        16.height,
                        if (orderData!.extraCharges.validate().isNotEmpty)
                          OrderSummeryWidget(
                            extraChargesList: orderData!.extraChargesList.validate(),
                            totalDistance: orderData!.totalDistance.validate(),
                            totalWeight: orderData!.totalWeight.validate(),
                            distanceCharge: orderData!.distanceCharge.validate(),
                            weightCharge: orderData!.weightCharge.validate(),
                            totalAmount: orderData!.totalAmount.validate(),
                            status: orderData!.status.validate(),
                            payment: payment,
                            vehiclePrice: orderData!.vehicleCharge,
                            insuranceCharge: orderData!.insuranceCharge,
                            isInsuranceChargeDisplay: true,
                            baseTotal: orderData!.baseTotal,
                          ),
                        16.height,
                        if (orderData!.reason.validate().isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: boxDecorationWithRoundedCorners(
                                borderRadius: BorderRadius.circular(defaultRadius),
                                border: Border.all(color: ColorUtils.colorPrimary.withOpacity(0.3)),
                                backgroundColor: Colors.transparent),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(language.reason, style: boldTextStyle()),
                                8.height,
                                Text(orderData!.reason.validate(), style: secondaryTextStyle()),
                              ],
                            ),
                          ),
                        16.height,
                        Row(
                          children: [
                            if (orderData!.status == ORDER_CREATED ||
                                orderData!.status == ORDER_ACCEPTED ||
                                orderData!.status == ORDER_ASSIGNED ||
                                orderData!.status == ORDER_ARRIVED ||
                                orderData!.status == ORDER_PICKED_UP)
                              AppButton(
                                child: Text(language.cancelOrder, style: boldTextStyle(color: Colors.white)),
                                color: Colors.red,
                                width: context.width(),
                                elevation: 0,
                                onTap: () {
                                  showInDialog(
                                    context,
                                    contentPadding: EdgeInsets.all(16),
                                    builder: (p0) {
                                      return CancelOrderDialog(
                                        orderId: orderData!.id.validate(),
                                        onUpdate: () {
                                          init();
                                          setState(() {});
                                        },
                                      );
                                    },
                                  );
                                },
                              ).expand(),
                            16.width.visible(orderData!.status == ORDER_DELIVERED),
                            if (orderData!.status == ORDER_DELIVERED)
                              AppButton(
                                child: Text(language.returnOrder, style: boldTextStyle(color: Colors.white)),
                                color: ColorUtils.colorPrimary,
                                width: context.width(),
                                elevation: 0,
                                onTap: () {
                                  ReturnOrderScreen(orderData: orderData!).launch(context);
                                },
                              ).expand(),
                          ],
                        ).visible(getStringAsync(USER_TYPE) == CLIENT),
                        if (orderData!.status == ORDER_DEPARTED ||
                            orderData!.status == ORDER_PICKED_UP ||
                            orderData!.status == ORDER_ARRIVED ||
                            orderData!.status == ORDER_ACCEPTED)
                          AppButton(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(language.trackOrder, style: boldTextStyle(color: Colors.white)),
                                8.width,
                                Icon(Icons.location_on_outlined, color: Colors.white, size: 18),
                              ],
                            ),
                            color: ColorUtils.colorPrimary,
                            width: context.width(),
                            elevation: 0,
                            onTap: () {
                              OrderTrackingScreen(orderData: orderData!).launch(context);
                            },
                          ).paddingOnly(top: 16),
                        16.height,
                        // Service charge information
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: boxDecorationWithRoundedCorners(
                              borderRadius: BorderRadius.circular(defaultRadius),
                              border: Border.all(color: ColorUtils.colorPrimary.withOpacity(0.3)),
                              backgroundColor: Colors.transparent),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Service Charge Information", style: boldTextStyle()),
                              8.height,
                              Text(
                                "A 5% service charge applies to all transactions. 2.5% is charged after pickup and 2.5% after delivery.",
                                style: secondaryTextStyle(),
                              ),
                              8.height,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Total Service Charge", style: primaryTextStyle()),
                                  Text(
                                    printAmount(calculateServiceCharge(orderData!.totalAmount!.toDouble())),
                                    style: primaryTextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                : SizedBox(),
            loaderWidget().center().visible(appStore.isLoading),
          ],
        );
      }),
    );
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