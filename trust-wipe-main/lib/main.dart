import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/wipe_provider.dart';
import 'theme/app_theme.dart';
import 'ui/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final provider = WipeProvider();
  await provider.initSystem();

  runApp(
    ChangeNotifierProvider<WipeProvider>.value(
      value: provider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrustWipe Enterprise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainScreen(),
    );
  }
}
