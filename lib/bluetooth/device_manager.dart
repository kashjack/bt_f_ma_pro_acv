import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_app/generated/l10n.dart';
import 'package:flutter_app/bluetooth/JKSetting.dart';
import 'package:flutter_app/helper/config/config.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/pages/bt/BTPage.dart';
import 'package:flutter_app/pages/caraux/CarAuxPage.dart';
import 'package:flutter_app/pages/play/PlayPage.dart';
import 'package:flutter_app/pages/radio/RadioPage.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef _CallBack = void Function(String value);

class DeviceManager {
  /// 1. 创建一个静态的私有实例
  static final DeviceManager _instance = DeviceManager._privateConstructor();

  /// 2. 声明一个私有的构造方法
  DeviceManager._privateConstructor();

  /// 3. 提供一个公共的访问方法来获取单例实例
  static DeviceManager get instance => _instance;

  /// 蓝牙获取的设备列表
  // List<ScanResult> deviceList = [];
  BluetoothDevice? connectedDevice;

  StreamSubscription<BluetoothConnectionState>? _device_subscription;

  /// 写套接字
  BluetoothCharacteristic? _characteristic;

  _CallBack? stateCallback;
  _CallBack? modeCallback;

  /// 初始化蓝牙
  Future<void> initBle() async {
    if (await FlutterBluePlus.isSupported == false) {
      printLog('Bluetooth not supported by this device');
      return;
    }
    FlutterBluePlus.setLogLevel(LogLevel.error);

    if (Platform.isAndroid) {
      await FlutterBluePlus.turnOn();
    }

    await FlutterBluePlus.adapterState
        .where((event) => event == BluetoothAdapterState.on)
        .first;
  }

  initModeCallback() {
    modeCallback = (value) {
      if (value == 'disconnect') {
        navigatorKey.currentState!.popUntil(ModalRoute.withName("/"));
        Fluttertoast.showToast(msg: S.current.reconnected_msg);
      } else if (value == 'mode') {
        JKSetting.instance.isModeChange = true;
        if (JKSetting.instance.mode == 1) {
          push(BtPage());
        } else if (JKSetting.instance.mode == 2) {
          push(RadioPage());
        } else if (JKSetting.instance.mode == 3) {
          push(PlayPage());
        } else if (JKSetting.instance.mode == 4) {
          push(PlayPage());
        } else if (JKSetting.instance.mode == 5) {
          push(CarAuxPage());
        }
      }
    };
  }

  push(Widget page) {
    navigatorKey.currentState!
        .push(MaterialPageRoute(builder: (context) => page))
        .then((value) {
      if (value != null && value) {
        // ignore: invalid_use_of_protected_member
        navigatorKey.currentState!.setState(() {});
      }
    });
  }

  static bool isConnect() {
    return _instance.connectedDevice != null;
  }

  /// 开始扫描
  Stream<ScanResult> startScan() {
    StreamController<ScanResult> controller = StreamController<ScanResult>();
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult result in results) {
        if (result.device.platformName.length > 0) {
          controller.sink.add(result);
        }
      }
    });
    if (!FlutterBluePlus.isScanningNow) {
      FlutterBluePlus.startScan(
        timeout: Duration(seconds: 5),
        androidUsesFineLocation: true,
      );
    } else {
      FlutterBluePlus.stopScan().then((value) {
        FlutterBluePlus.startScan(
          timeout: Duration(seconds: 5),
          androidUsesFineLocation: true,
        );
      });
    }
    return controller.stream;
  }

  /// 连接设备
  static Future<void> connectDevice(BluetoothDevice device) async {
    await device.connect();
    await _connectService(device);

    /// 监听设备状态
    _instance._device_subscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        printLog("设备已断开");
        if (_instance._device_subscription != null) {
          _instance._device_subscription!.cancel();
          _instance._device_subscription = null;
        }
        _instance.connectedDevice = null;
        if (_instance.modeCallback != null) {
          _instance.modeCallback!("disconnect");
        }
      } else if (state == BluetoothConnectionState.connected) {
        printLog('设备连上了');
        _instance.connectedDevice = device;
        JKSetting.instance.getMode();

        /// 存储蓝牙id
        SharedPreferences.getInstance().then((shared) {
          shared.setString("bleRemoteId", device.remoteId.toString());
        });
      }
    });
  }

  /// 连接服务
  static Future<void> _connectService(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    services.forEach((service) {
      // printLog(service.uuid.toString().toUpperCase());
      String uuid = service.uuid.toString().toUpperCase();
      if (uuid == "FFF0") {
        service.characteristics.forEach((characteristic) async {
          String cuuid = characteristic.uuid.toString().toUpperCase();
          if (cuuid == "FFF1") {
            printLog('读套接字连上了');
            await characteristic.setNotifyValue(true);
            final subscription = characteristic.onValueReceived.listen((value) {
              print("接收数据$value");
              _instance._parseValue(value);
            });
            device.cancelWhenDisconnected(subscription);
          } else if (cuuid == 'FFF2') {
            printLog('获取写套接字');
            _instance._characteristic = characteristic;
          }
        });
      }
    });
  }

  static Future<void> disConnect() async {
    return _instance.connectedDevice!.disconnect();
  }

  static void writeData(List<int> data) {
    if (isConnect() || kDebugMode) {
      int startCode = 0xff;
      int endCode = 0xfe;
      int lengthCode = data.length + 1;
      int verifyCode = lengthCode;
      for (int item in data) {
        verifyCode += item;
      }
      verifyCode = verifyCode % 256;
      List<int> finalData =
          [startCode, lengthCode] + data + [verifyCode, endCode];
      if (isConnect()) {
        printLog("我写了$finalData");
        _instance._characteristic!.write(finalData, withoutResponse: true);
      }
    } else {
      Fluttertoast.showToast(msg: S.current.reconnected_msg);
    }
  }

  void _parseValue(List<int> value) {
    printLog("蓝牙接收数据：$value");
    int function = value[2];
    JKSetting.instance.allData.add(value);
    switch (function) {
      case 0x01: // 音量
        JKSetting.instance.volume = value[3].toDouble();
        if (stateCallback != null) {
          stateCallback!('volume');
        }
        break;
      case 0x04: //radio
        var list = value[3].toList();
        JKSetting.instance.isLoud = list[0] == 1;
        JKSetting.instance.isInt = list[1] == 1;
        JKSetting.instance.isDistance = list[2] == 1;
        JKSetting.instance.isStereo = list[3] == 1;
        JKSetting.instance.channelIndex = list[6] * 2 + list[7];
        var list2 = value[4].toList();
        JKSetting.instance.isSub = list2[7] == 1;
        JKSetting.instance.isEon = list2[6] == 1;
        JKSetting.instance.isTa = list2[5] == 1;
        JKSetting.instance.isAf = list2[4] == 1;
        JKSetting.instance.channel = value[5];
        //选中预置台号，好像本地存起来没什么用
        JKSetting.instance.checkedPresetChannel = value[6];
        JKSetting.instance.presetChannels = [
          value[7],
          value[8],
          value[9],
          value[10],
          value[11],
          value[12]
        ];
        JKSetting.instance.presetDecimalChannels = value[13].toList();
        if (stateCallback != null) {
          stateCallback!('radio');
        }
        break;
      case 0x02: //RGB
        JKSetting.instance.isAuto = value[3] != 1;
        if (!JKSetting.instance.isAuto) {
          if (value.length == 7) {
            JKSetting.instance.currentRgbIndex = value[4];
            JKSetting.instance.currentRGB =
                JKSetting.instance.autoRGBList[value[4] - 1];
          } else {
            JKSetting.instance.currentRgbIndex = 0;
            JKSetting.instance.currentRGB =
                Color.fromARGB(0xFF, value[5], value[6], value[7]);
          }
        }
        if (stateCallback != null) {
          stateCallback!('rgb');
        }
        break;
      case 0x05: //bt
        var list = value[3].toList();
        JKSetting.instance.isBtMusicPlay = list[7] == 1;
        JKSetting.instance.isSub = list[4] == 1;
        JKSetting.instance.isLoud = list[3] == 1;
        JKSetting.instance.isBtMusicMute = list[2] == 1;
        if (stateCallback != null) {
          stateCallback!('bt');
        }
        break;
      case 0x06: //aux
        var list = value[3].toList();
        JKSetting.instance.isAuxMute = list[7] == 1;
        JKSetting.instance.isSub = list[6] == 1;
        JKSetting.instance.isLoud = list[5] == 1;
        if (stateCallback != null) {
          stateCallback!('aux');
        }
        break;
      case 0x07: //usb
      case 0x08: //sd
        int function1 = value[3];
        int function2 = value[4];
        var list1 = function1.toList();
        var list2 = function2.toList();
        JKSetting.instance.isMusicPlay = list1[7] == 1;
        JKSetting.instance.isCycle = list1[3] == 1;
        JKSetting.instance.isRandom = list1[2] == 1;
        JKSetting.instance.isMute = list2[7] == 1;
        JKSetting.instance.isSub = list2[4] == 1;
        JKSetting.instance.isLoud = list2[3] == 1;
        JKSetting.instance.totalMinute = value[5];
        JKSetting.instance.totalSecond = value[6];
        JKSetting.instance.nowMinute = value[7];
        JKSetting.instance.nowSecond = value[8];
        if (stateCallback != null) {
          stateCallback!('play');
        }
        break;
      case 0x09: //EQ
        if (value.length == 6) {
          JKSetting.instance.nowEQMode = value[3];
        } else if (value.length == 8 && value[3] == 0 && value[4] == 0) {
          JKSetting.instance.eqQFactor = value[5];
        } else {
          if (value[3] == 0x01) {
            JKSetting.instance.eqLongDbs.setRange(
                0, 10, List.generate(10, (index) => value[index + 4] - 9));
          } else if (value[3] == 0x02) {
            JKSetting.instance.eqLongDbs.setRange(
                10, 20, List.generate(10, (index) => value[index + 4] - 9));
          }
        }
        if (stateCallback != null) {
          stateCallback!('eq');
        }
        break;
      case 0x10: //BassBoost
        int function = value[3];
        var list = function.toList();
        JKSetting.instance.isSubwoofer = list[0] == 1;
        JKSetting.instance.level =
            value[3] - (JKSetting.instance.isSubwoofer ? 128 : 0);
        JKSetting.instance.bassBoost = value[4];
        if (stateCallback != null) {
          stateCallback!('bassBoost');
        }
        break;
      case 0x0a: //FA/BA
        JKSetting.instance.faderProgress = value[3] - 15;
        JKSetting.instance.balanceProgress = value[4] - 15;
        if (stateCallback != null) {
          stateCallback!('faba');
        }
        break;
      case 0x0b: //alignment
        //获取前4位数值
        int positionPreFourth = value[4] >> 4;
        JKSetting.instance.is2WAY = positionPreFourth != 2;
        JKSetting.instance.alignmentPosition =
            value[4] - (positionPreFourth << 4) - 1;
        if (value[3] == 0x01) {
          JKSetting.instance.alignmentSpeaks[0]
            ..cm0 = value[5]
            ..cm1 = value[6]
            ..cm = (value[5] << 8) + value[6]
            ..db = value[7];
          JKSetting.instance.alignmentSpeaks[1]
            ..cm0 = value[8]
            ..cm1 = value[9]
            ..cm = (value[8] << 8) + value[9]
            ..db = value[10];
          JKSetting.instance.alignmentSpeaks[2]
            ..cm0 = value[11]
            ..cm1 = value[12]
            ..cm = (value[11] << 8) + value[12]
            ..db = value[13];
        } else if (value[3] == 0x02) {
          JKSetting.instance.alignmentSpeaks[3]
            ..cm0 = value[5]
            ..cm1 = value[6]
            ..cm = (value[5] << 8) + value[6]
            ..db = value[7];
          JKSetting.instance.alignmentSpeaks[4]
            ..cm0 = value[8]
            ..cm1 = value[9]
            ..cm = (value[8] << 8) + value[9]
            ..db = value[10];
          JKSetting.instance.alignmentSpeaks[5]
            ..cm0 = value[11]
            ..cm1 = value[12]
            ..cm = (value[11] << 8) + value[12]
            ..db = value[13];
        } else if (value[3] == 0x10) {
          JKSetting.instance.alignmentSpeakMss[0]
            ..ms0 = value[5]
            ..ms1 = value[6]
            ..ms = (value[5] << 8) + value[6];
          JKSetting.instance.alignmentSpeakMss[1]
            ..ms0 = value[7]
            ..ms1 = value[8]
            ..ms = (value[7] << 8) + value[8];
          JKSetting.instance.alignmentSpeakMss[2]
            ..ms0 = value[9]
            ..ms1 = value[10]
            ..ms = (value[9] << 8) + value[10];
          JKSetting.instance.alignmentSpeakMss[3]
            ..ms0 = value[11]
            ..ms1 = value[12]
            ..ms = (value[11] << 8) + value[12];
          JKSetting.instance.alignmentSpeakMss[4]
            ..ms0 = value[13]
            ..ms1 = value[14]
            ..ms = (value[13] << 8) + value[14];
          JKSetting.instance.alignmentSpeakMss[5]
            ..ms0 = value[15]
            ..ms1 = value[16]
            ..ms = (value[15] << 8) + value[16];
        }
        if (stateCallback != null) {
          stateCallback!('alignment');
        }
        break;
      case 0x0c:
        if (value[3] == 0x01) {
          JKSetting.instance
            ..aisle = 1
            ..is2WAY = true
            ..frq21 = value[4]
            ..gain = value[5]
            ..gainRight = value[6];
        } else if (value[3] == 0x02) {
          JKSetting.instance
            ..aisle = 2
            ..is2WAY = true
            ..frq22 = value[4]
            ..slope = value[5]
            ..gain = value[6];
        } else if (value[3] == 0x03) {
          JKSetting.instance
            ..aisle = 3
            ..is2WAY = true
            ..frq23 = value[4]
            ..slope = value[5]
            ..gain = value[6];
        } else if (value[3] == 0x04) {
          JKSetting.instance
            ..aisle = 4
            ..is2WAY = true
            ..frq24 = value[4]
            ..slope = value[5]
            ..gain = value[6]
            ..phase = value[7];
        } else if (value[3] == 0x21) {
          JKSetting.instance
            ..aisle = 1
            ..is2WAY = false
            ..frq31 = value[7]
            ..slope = value[8]
            ..gain = value[9]
            ..phase = value[10];
        } else if (value[3] == 0x22) {
          JKSetting.instance
            ..aisle = 2
            ..is2WAY = false
            ..frq321 = value[4]
            ..hSlope = value[5]
            ..frq322 = value[6]
            ..slope = value[7]
            ..gain = value[8]
            ..phase = value[9];
        } else if (value[3] == 0x23) {
          JKSetting.instance
            ..aisle = 3
            ..is2WAY = false
            ..frq33 = value[4]
            ..slope = value[5]
            ..gain = value[6]
            ..phase = value[7];
        }
        if (stateCallback != null) {
          stateCallback!('xover');
        }
        break;
      case 0x0d:
        // 模式
        if (JKSetting.instance.mode != value[3]) {
          JKSetting.instance.mode = value[3];
          if (value[3] == 0x01) {
            JKSetting.instance.musicName = "";
            JKSetting.instance.artistName = "";
            JKSetting.instance.albumName = "";
          }
          if (modeCallback != null) {
            modeCallback!('mode');
          }
        }
        break;
      case 0x33:
        // 模式
        JKSetting.instance.is2WAY = (value[3] == 1);
        if (stateCallback != null) {
          stateCallback!('way');
        }
        break;
      case 0x32:
        //音乐信息
        if (value[3] == 0x01) {
          //歌曲名
          if (value[4] == 0x01) {
            //重置字符串
            JKSetting.instance.musicName = "";
          }
          JKSetting.instance.musicName +=
              value.getRange(5, 17).toList().toAscii();
        } else if (value[3] == 0x02) {
          //艺术家名称
          if (value[4] == 0x01) {
            //重置字符串
            JKSetting.instance.artistName = "";
          }
          JKSetting.instance.artistName +=
              value.getRange(5, 17).toList().toAscii();
        } else if (value[3] == 0x03) {
          //专辑名称
          if (value[4] == 0x01) {
            //重置字符串
            JKSetting.instance.albumName = "";
          }
          JKSetting.instance.albumName +=
              value.getRange(5, 17).toList().toAscii();
        }
        if (stateCallback != null) {
          stateCallback!('music');
        }
        break;
    }
  }
}
