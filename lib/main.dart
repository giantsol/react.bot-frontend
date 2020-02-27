import 'package:fb_app/AppColors.dart';
import 'package:fb_app/MainScreen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(App());
}

class App extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FB App',
      theme: ThemeData(
        canvasColor: AppColors.BACKGROUND_WHITE,
        splashColor: AppColors.RIPPLE,
        textTheme: TextTheme(
          subhead: TextStyle(
            textBaseline: TextBaseline.alphabetic
          ),
        ),
      ),
      builder: (context, widget) {
        // do NOT show red error screen in production build although there's an error
        if (kReleaseMode) {
          ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
            return Container();
          };
        }
        return widget;
      },
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
