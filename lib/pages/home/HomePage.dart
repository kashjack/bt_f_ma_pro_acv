import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_app/android_back_desktop.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/bluetooth/device_manager.dart';
import 'package:flutter_app/bluetooth/JKSetting.dart';
import 'package:flutter_app/helper/config/config.dart';
import 'package:flutter_app/helper/config/image.dart';
import 'package:flutter_app/helper/config/size.dart';
import 'package:flutter_app/pages/bt/BTPage.dart';
import 'package:flutter_app/pages/caraux/CarAuxPage.dart';
import 'package:flutter_app/pages/connect/ConnectPage.dart';
import 'package:flutter_app/pages/gps/GPSPage.dart';
import 'package:flutter_app/pages/home/widget/Swiper.dart';
import 'package:flutter_app/pages/play/PlayPage.dart';
import 'package:flutter_app/pages/radio/RadioPage.dart';
import 'package:flutter_app/pages/rgb/RGBPage.dart';
import 'package:flutter_app/route/BasePage.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import 'package:fluttertoast/fluttertoast.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:video_player/video_player.dart';

class HomePage extends BaseWidget with WidgetsBindingObserver {
  @override
  BaseWidgetState<BaseWidget> getState() => _HomePageState();
}

class _HomePageState extends BaseWidgetState<HomePage> {
  List<String> imageArr = [
    JKImage.icon_bt,
    JKImage.icon_aux,
    JKImage.icon_usb,
    JKImage.icon_sd,
    JKImage.icon_radio,
    JKImage.icon_rgb,
    JKImage.icon_gps,
  ];

  List<String> descArr = [
    S.current.BT_Music,
    S.current.AUX,
    S.current.USB,
    S.current.SD_Card,
    S.current.Radio,
    S.current.RGB,
    S.current.GPS
  ];

  List<Widget> pageArr = [
    BtPage(),
    CarAuxPage(),
    PlayPage(),
    PlayPage(),
    RadioPage(),
    RGBPage(),
    GPSPage(),
  ];

  int index = 0;

  bool _isPlayed = false;
  int count = 5;
  String _version = '';

  late VideoPlayerController _controller;
  GlobalKey<SwiperState> swiperKey = GlobalKey();

  // ignore: cancel_subscriptions
  StreamSubscription<List<ScanResult>>? scanSubscription;
  bool triedConnect = false;

  // didChangeAppLifecycleState

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _initBlueTooth();
  }

  void initData() {
    super.initData();
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      this.setState(() {
        _version = packageInfo.version;
      });
    });
    DeviceManager.instance.initModeCallback();
    if (!_isPlayed) {
      _controller = VideoPlayerController.asset(JKImage.mp4_launch,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true))
        ..initialize().then((_) {
          setState(() {});
          _controller.play();
          Future.delayed(Duration(seconds: 5), () {
            setState(() {
              _isPlayed = true;
            });
          });
        });
    }
  }

  void _initBlueTooth() async {
    await DeviceManager.instance.initBle();
    _autoConnect();
  }

  @override
  Widget build(BuildContext context) {
    this.setParameters();
    int quarterTurns = JKSize.instance.isPortrait ? 0 : 3;
    if (_isPlayed) {
      return Scaffold(
        // appBar: appBarWidget, //顶部导航栏
        endDrawer: endDrawerWidget, //右滑菜单栏
        body: Platform.isIOS
            ? this._buildContentView()
            : WillPopScope(
                onWillPop: () async {
                  AndroidBackTop.backDeskTop(); //设置为返回不退出app
                  return false; //一定要return false
                },
                child: this._buildContentView(),
              ),
      );
    }

    return _controller!.value.isInitialized
        ? Scaffold(
            // appBar: appBarWidget!, //顶部导航栏
            endDrawer: endDrawerWidget, //右滑菜单栏
            body: Stack(
              children: [
                Container(
                  width: JKSize.instance.width,
                  height: JKSize.instance.height,
                  color: Colors.black,
                ),
                Container(
                  child: Image.asset(
                    JKImage.icon_bg,
                    fit: BoxFit.cover,
                    width: JKSize.instance.width,
                    height: JKSize.instance.height,
                  ),
                ),
                RotatedBox(
                  quarterTurns: quarterTurns,
                  child: OverflowBox(
                    maxWidth: JKSize.instance.isPortrait
                        ? JKSize.instance.height / 667 * 375
                        : JKSize.instance.width / 667 * 375,
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                ),
              ],
            ),
          )
        : Image.asset(
            JKImage.icon_launch,
            fit: BoxFit.cover,
            width: JKSize.instance.width,
            height: JKSize.instance.height,
          );
  }

  Widget _buildContentView() {
    return Stack(
      children: [
        Container(
          child: Image.asset(
            JKImage.icon_bg,
            fit: BoxFit.cover,
            width: JKSize.instance.width,
            height: JKSize.instance.height,
          ),
        ),
        this._buildBodyLayout(),
      ],
    );
  }

  Widget _buildBodyLayout() {
    return Container(
      height: JKSize.instance.height,
      width: JKSize.instance.width,
      margin: EdgeInsets.only(
        top: max(JKSize.instance.top, 30),
        bottom: JKSize.instance.bottom,
        left: max(JKSize.instance.left, JKSize.instance.right),
        right: max(JKSize.instance.left, JKSize.instance.right),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            // color: Colors.blue,
            margin: EdgeInsets.only(left: 10, right: 10),
            height: 50,
            child: this.buildTopView(),
          ),
          Container(
            child: Column(
              children: [
                this.buildSwiperView(),
                Container(
                  margin: EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        this.descArr[this.index],
                        style: TextStyle(
                          color: JKColor.main,
                          fontSize: 28,
                          fontFamily: 'Mont',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Text(
            'v ' + _version,
            style: TextStyle(
              color: JKColor.ff767676,
              fontFamily: 'Mont',
            ),
          )
        ],
      ),
    );
  }

  Widget buildTopView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Image.asset(
                JKImage.icon_logo,
                height: 23,
                fit: BoxFit.contain,
              ),
              Container(
                child: TextButton(
                  style: ButtonStyle(
                    overlayColor: MaterialStateProperty.all(Colors.transparent),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                      // Spacer(),
                      Text(
                        S.current.Connect,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontFamily: 'Mont',
                        ),
                      ),
                    ],
                  ),
                  onPressed: () {
                    this.push(ConnectPage());
                  },
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  Widget buildSwiperView() {
    return Container(
      height: 200,
      child: Swiper(
        key: swiperKey,
        images: this.imageArr,
        viewportFraction: 0.4,
        initialPage: this.index,
        onTapCallBack: (int pageIndex) async {
          if (pageIndex == 6) {
            if (Platform.isIOS) {
              this.push(this.pageArr[pageIndex]);
            } else {
              if (await canLaunchUrlString('geo:0,0')) {
                await launchUrlString('geo:0,0');
              } else {
                Fluttertoast.showToast(msg: 'Could not launch maps');
              }
            }
            return;
          }
          if (kDebugMode) {
            this.push(this.pageArr[pageIndex]);
            return;
          }
          if (DeviceManager.isConnect()) {
            switch (pageIndex) {
              case 0:
                JKSetting.instance.setMode(1);
                break;
              case 1:
                JKSetting.instance.setMode(5);
                break;
              case 2:
                JKSetting.instance.setMode(3);
                break;
              case 3:
                JKSetting.instance.setMode(4);
                break;
              case 4:
                JKSetting.instance.setMode(2);
                break;
              default:
                this.push(this.pageArr[pageIndex]);
                break;
            }
          } else {
            Fluttertoast.showToast(msg: S.current.reconnected_msg);
          }
        },
        onSwitchPageIndexCallBack: (int pageIndex) {
          this.setState(() {
            this.index = pageIndex;
          });
        },
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didPopNext() {
    if (JKSetting.instance.isModeChange) {
      JKSetting.instance.isModeChange = false;
      switch (JKSetting.instance.mode) {
        case 1:
          index = 0;
          break;
        case 2:
          index = 4;
          break;
        case 3:
          index = 2;
          break;
        case 4:
          index = 3;
          break;
        case 5:
          index = 1;
          break;
      }
    }
    swiperKey.currentState!.pageTo(this.index);
    super.didPopNext();
  }

  void _autoConnect() async {
    SharedPreferences shared = await SharedPreferences.getInstance();
    if (shared.getString('blueDeviceId') != null) {
      StreamSubscription? stream;
      stream = DeviceManager.instance.startScan().listen((result) {
        if (result.device.remoteId.toString() ==
                shared.getString('blueDeviceId')! &&
            !DeviceManager.isConnect()) {
          if (stream != null) {
            stream!.cancel();
            stream = null;
          }
          // EasyLoading.show(status: 'connect...');
          DeviceManager.connectDevice(result.device).then((value) {
            // EasyLoading.dismiss();
          });
        }
      });
    }
  }
}
