import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StatusBarPage extends StatelessWidget {
  final Widget child;

  const StatusBarPage({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark, // iOS 状态栏文字颜色
      ),
      child: child,
    );
  }
}
