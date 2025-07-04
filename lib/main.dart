import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'pages/home/HomePage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'generated/l10n.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 关键 1: 启用边缘到边缘模式（必须）
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // 关键 2: 设置全局透明状态栏
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent, // 完全透明
      statusBarIconBrightness: Brightness.dark, // Android 黑色图标
      statusBarBrightness: Brightness.light, // iOS 亮色文字
    ),
  );
  runApp(MyApp());
}

final GlobalKey<NavigatorState> navigatorKey = new GlobalKey();

class MyApp extends StatelessWidget {
  // 用于路由返回监听
  static final RouteObserver<PageRoute> routeObserver =
      RouteObserver<PageRoute>();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight
    ]);
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'ACV',
      supportedLocales: S.delegate.supportedLocales,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        S.delegate
      ],
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      builder: EasyLoading.init(),
      routes: {
        "/": (context) => HomePage(),
      },
      debugShowCheckedModeBanner: false, //去掉右上角DEBUG标签
    );
  }
}
