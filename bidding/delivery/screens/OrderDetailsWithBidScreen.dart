import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:intl/intl.dart';
import '../../../extensions/extension_util/context_extensions.dart';
import '../../../extensions/extension_util/int_extensions.dart';
import '../../../extensions/extension_util/string_extensions.dart';
import '../../../extensions/extension_util/widget_extensions.dart';
import '../../../main/models/OrderListModel.dart';
import '../../../main/utils/Common.dart';
import '../../../main/utils/Widgets.dart';
import '../../../main/utils/dynamic_theme.dart';

import '../../../extensions/app_button.dart';
import '../../../extensions/app_text_field.dart';
import '../../../extensions/common.dart';
import '../../../extensions/confirmation_dialog.dart';
import '../../../extensions/decorations.dart';
import '../../../extensions/shared_pref.dart';
import '../../../extensions/system_utils.dart';
import '../../../extensions/text_styles.dart';
import '../../../main.dart';
import '../../../main/components/CommonScaffoldComponent.dart';
import '../../../main/components/TopBarAddressComponent.dart';
import '../models/ApplyBidModel.dart';
import '../models/BidListData.dart';
import '../network/RestApis.dart';

class OrderDetailWithBidScreen extends StatefulWidget {
  final BidListData? bidData;
  final int? orderId;

  OrderDetailWithBidScreen({this.bidData, this.orderId});

  @override
  State<OrderDetailWithBidScreen> createState() => _OrderDetailWithBidScreenState();
}

class _OrderDetailWithBidScreenState extends State<OrderDetailWithBidScreen> {
  OrderData? orderData;
  TextEditingController bidAmountController = TextEditingController();
  TextEditingController notesController = TextEditingController();
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    getOrderDetails();
    if (widget.bidData != null) {
      bidAmountController.text = widget.bidData!.bidAmount.toString();
      notesController.text = widget.bidData!.notes.toString();
    }
  }

  Future<void> getOrderDetails() async {
    appStore.setLoading(true);
    await getOrderDetails(widget.orderId!).then((value) {
      appStore.setLoading(false);
      orderData = value.data;
      setState(() {});
    }).catchError((error) {
      appStore.setLoading(false);
      toast(error.toString());
    });
  }

  Future<void> applyBid() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      hideKeyboard(context);

      Map req = {
        "id": widget.bidData != null ? widget.bidData!.id : "",
        "order_id": widget.orderId,
        "bid_amount": bidAmountController.text.trim(),
        "notes": notesController.text.trim(),
      };

      appStore.setLoading(true);
      await createBid(req).then((value) {
        appStore.setLoading(false);
        toast(value.message.toString());
        finish(context);
      }).catchError((error) {
        appStore.setLoading(false);
        toast(error.toString());
      });
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return CommonScaffoldComponent(
      appBarTitle: language.bidRequest,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (orderData != null) TopBarAddressComponent(orderData: orderData),
                  16.height,
                  Text(language.bidAmount, style: boldTextStyle()),
                  8.height,
                  AppTextField(
                    controller: bidAmountController,
                    textFieldType: TextFieldType.PHONE,
                    decoration: commonInputDecoration(
                      hintText: language.enterAmount,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 16, right: 8),
                        child: Text(appStore.currencySymbol, style: boldTextStyle()),
                      ),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) return language.pleaseEnterBidAmount;
                      if (double.parse(value) <= 0) return language.pleaseEnterBidAmount;
                      return null;
                    },
                  ),
                  16.height,
                  Text(language.notes, style: boldTextStyle()),
                  8.height,
                  AppTextField(
                    controller: notesController,
                    textFieldType: TextFieldType.MULTILINE,
                    decoration: commonInputDecoration(hintText: language.saySomething),
                    minLines: 3,
                    maxLines: 5,
                  ),
                  30.height,
                  Row(
                    children: [
                      AppButton(
                        text: language.cancel,
                        textStyle: boldTextStyle(color: Colors.white),
                        width: context.width() - 32,
                        color: Colors.red,
                        onTap: () {
                          finish(context);
                        },
                      ).expand(),
                      16.width,
                      AppButton(
                        text: language.confirmBid,
                        textStyle: boldTextStyle(color: Colors.white),
                        width: context.width() - 32,
                        color: ColorUtils.colorPrimary,
                        onTap: () {
                          showConfirmDialogCustom(
                            context,
                            title: language.confirmBid,
                            subTitle: '${language.bidAmount}: ${appStore.currencySymbol}${bidAmountController.text}\n\n${language.notes}: ${notesController.text}',
                            positiveText: language.confirm,
                            negativeText: language.cancel,
                            primaryColor: ColorUtils.colorPrimary,
                            onAccept: (context) {
                              applyBid();
                            },
                          );
                        },
                      ).expand(),
                    ],
                  ),
                  if (orderData != null && orderData!.totalAmount != null)
                    Container(
                      margin: EdgeInsets.only(top: 16),
                      padding: EdgeInsets.all(16),
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: context.cardColor,
                        borderRadius: BorderRadius.circular(defaultRadius),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(language.estimateAmount, style: boldTextStyle()),
                          8.height,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(language.clientBidAmount, style: primaryTextStyle()),
                              Text('${printAmount(orderData!.totalAmount!)}', style: boldTextStyle()),
                            ],
                          ),
                          8.height,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(language.serviceCharge, style: primaryTextStyle()),
                              Text('${printAmount(calculateServiceCharge(orderData!.totalAmount!.toDouble()))}', style: primaryTextStyle(color: Colors.red)),
                            ],
                          ),
                          8.height,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(language.youWillReceive, style: boldTextStyle()),
                              Text('${printAmount(calculateAmountAfterServiceCharge(orderData!.totalAmount!.toDouble()))}', style: boldTextStyle(color: Colors.green)),
                            ],
                          ),
                          Divider(),
                          Text(language.serviceChargeNote, style: secondaryTextStyle()),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          Observer(builder: (context) => loaderWidget().visible(appStore.isLoading)),
        ],
      ),
    );
  }
}