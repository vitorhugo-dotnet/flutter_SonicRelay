import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'app/di/app_providers.dart';
import 'app/env/app_config.dart';
import 'app/sonic_relay_app.dart';
import 'core/storage/server_config_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const secureStorage = FlutterSecureStorage();
  final savedServerUrl =
      await const ServerConfigStorage(secureStorage).read() ??
      AppConfig.defaultServerUrl;

  runApp(
    ProviderScope(
      overrides: [
        serverUrlProvider.overrideWith(() => ServerUrlNotifier(savedServerUrl)),
      ],
      child: const SonicRelayApp(),
    ),
  );
}
