import 'package:dio/dio.dart';

import 'dto/join_session_request.dart';
import 'dto/join_session_response.dart';

abstract interface class SessionsApi {
  Future<JoinSessionResponse> join(JoinSessionRequest request);
}

class DioSessionsApi implements SessionsApi {
  const DioSessionsApi(this._dio);

  final Dio _dio;

  @override
  Future<JoinSessionResponse> join(JoinSessionRequest request) async {
    final response = await _dio.post<Map<String, Object?>>(
      '/api/sessions/join',
      data: request.toJson(),
    );
    return JoinSessionResponse.fromJson(response.data!);
  }
}
