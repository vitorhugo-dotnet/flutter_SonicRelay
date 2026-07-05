import 'package:dio/dio.dart';

import '../../app/env/app_config.dart';

Dio createHttpClient(AppConfig config) {
  return Dio(BaseOptions(baseUrl: config.apiBaseUrl));
}
