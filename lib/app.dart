import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/domain/appearance.dart';
import 'features/settings/presentation/settings_providers.dart';

/// Raiz do app: tema, localização e roteamento.
class IziFncApp extends ConsumerStatefulWidget {
  const IziFncApp({super.key});

  @override
  ConsumerState<IziFncApp> createState() => _IziFncAppState();
}

class _IziFncAppState extends ConsumerState<IziFncApp> {
  // O router guarda o histórico de navegação, então precisa sobreviver aos
  // rebuilds — daí o State em vez de criá-lo dentro do build.
  late final GoRouter _router = createAppRouter();

  @override
  Widget build(BuildContext context) {
    // Enquanto o banco não responde, vale o padrão (segue o sistema).
    final appearance = ref.watch(appearanceProvider).value ?? const Appearance();
    return MaterialApp.router(
      title: 'IziFnc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(highContrast: appearance.highContrast),
      darkTheme: AppTheme.dark(highContrast: appearance.highContrast),
      themeMode: appearance.themeMode.flutter,
      // O tamanho escolhido multiplica o do sistema, não o substitui.
      builder: (context, child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: TextScaler.linear(
              media.textScaler.scale(1.0) * appearance.textScale,
            ),
          ),
          child: child!,
        );
      },
      routerConfig: _router,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
