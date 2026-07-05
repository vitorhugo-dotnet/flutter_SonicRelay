import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/http/http_client.dart';
import '../../core/storage/secure_storage.dart';
import '../env/app_config.dart';

final appConfigProvider = Provider<AppConfig>(
  (ref) => AppConfig.fromEnvironment(),
);

final dioProvider = Provider<Dio>(
  (ref) => createHttpClient(ref.watch(appConfigProvider)),
);

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (ref) => createSecureStorage(),
);
