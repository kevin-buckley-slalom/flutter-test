import 'package:flutter/material.dart';
import '../ui/ability_detail/ability_detail_view.dart';
import '../ui/move_detail/move_detail_view.dart';
import 'theme/app_theme.dart';

class App extends StatelessWidget {
  final Widget home;

  const App({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChampionDex',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: home,
      routes: {
        '/ability-detail': (context) {
          final abilityName = ModalRoute.of(context)?.settings.arguments as String?;
          return AbilityDetailView(abilityName: abilityName ?? 'Unknown');
        },
        '/move-detail': (context) {
          final moveName = ModalRoute.of(context)?.settings.arguments as String?;
          return MoveDetailView(moveName: moveName ?? 'Unknown');
        },
      },
      debugShowCheckedModeBanner: false,
    );
  }
}




