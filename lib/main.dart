import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sensorflow_accelerometer/screens/recorder_screen.dart';
import 'package:sensorflow_accelerometer/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.background,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const SensorFlowApp());
}

class SensorFlowApp extends StatelessWidget {
  const SensorFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SensorFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const RecorderScreen(),
    );
  }
}
