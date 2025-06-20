import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/bluetooth/device_manager.dart';
import 'package:flutter_app/helper/config/image.dart';
import 'package:flutter_app/route/BasePage.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

class ConnectPage extends BaseWidget {
  BaseWidgetState<BaseWidget> getState() => _ConnectPageState();
}

class _ConnectPageState extends BaseWidgetState<ConnectPage> {
  List<ScanResult> _deviceList = [];
  RefreshController _controller = RefreshController(initialRefresh: true);
  StreamSubscription? _streamSubscription;

  buildVerticalLayout() {
    return this._buildBodyLayout();
  }

  buildHorizontalLayout() {
    return this._buildBodyLayout();
  }

  @override
  void dispose() {
    super.dispose();
    if (_streamSubscription != null) {
      _streamSubscription!.cancel();
      _streamSubscription = null;
    }
  }

  Widget _buildBodyLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        this.initTitleView(),
        _buildContentView(),
      ],
    );
  }

  Widget initTitleView() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: () {
              this.back();
            },
            child: Container(
              width: 105,
              alignment: Alignment.centerLeft,
              child: Image.asset(
                JKImage.icon_back,
                height: 25,
                width: 25,
                fit: BoxFit.fitHeight,
              ),
            ),
          ),
          Text(
            S.current.Device,
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
            ),
          ),
          InkWell(
            onTap: () {
              if (DeviceManager.isConnect()) {
                Fluttertoast.showToast(msg: S.current.Connect);
              } else {
                Fluttertoast.showToast(msg: S.current.DisConnected);
              }
            },
            child: Container(
              width: 105,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Offstage(
                    offstage: !DeviceManager.isConnect(),
                    child: Image.asset(
                      JKImage.icon_true,
                      height: 15,
                      width: 20,
                      fit: BoxFit.fitHeight,
                    ),
                  ),
                  Text(
                    S.current.Connect,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    bool isConnected = DeviceManager.isConnect();
    List<int> groupLength = [(isConnected ? 1 : 0), _deviceList.length];
    List<String> sectionListTitle = [
      S.current.Paired_Device,
      S.current.Devices_Found
    ];
    return Expanded(
      child: SmartRefresher(
        controller: _controller,
        enablePullUp: false,
        onRefresh: () {
          _controller.refreshCompleted();
          _controller.loadComplete();
          _deviceList.clear();
          _streamSubscription =
              DeviceManager.instance.startScan().listen((result) {
            if (!_deviceList.contains(result)) {
              _deviceList.add(result);
            }
            setState(() {});
          });
        },
        child: ListView.builder(
          itemCount: 2,
          itemBuilder: (context, index) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 分组标题
                _buildGroupView(sectionListTitle[index]),
                // 分组中的行
                ListView.builder(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  // 关键——把默认的 padding 清掉

                  physics: NeverScrollableScrollPhysics(),
                  itemCount: groupLength[index],
                  itemBuilder: (BuildContext context, int rowIndex) {
                    if (index == 0) {
                      return _buildItemView(
                          DeviceManager.instance.connectedDevice!);
                    } else {
                      return _buildItemView(_deviceList[rowIndex].device);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGroupView(String title) {
    return Container(
      height: 50,
      margin: EdgeInsets.symmetric(horizontal: 15),
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white60,
          fontSize: 20,
        ),
      ),
    );
  }

  Widget _buildItemView(BluetoothDevice device) {
    return InkWell(
      onTap: () {
        if (DeviceManager.isConnect()) {
          EasyLoading.show(status: S.current.DisConnected + '...');
          DeviceManager.disConnect().then((value) {
            EasyLoading.dismiss();
            setState(() {});
          });
        } else {
          EasyLoading.show(status: S.current.Connect + '...');
          // 连接设备回调
          DeviceManager.connectDevice(device).then((value) {
            EasyLoading.dismiss();
            Fluttertoast.showToast(msg: S.current.Connected);
            setState(() {});
          });
        }
      },
      child: Container(
        padding: EdgeInsets.only(top: 15, bottom: 15, left: 30, right: 20),
        child: Text(
          device.platformName,
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
