import 'dart:io';

import 'package:dio/dio.dart';

import 'auth/oss_request_signer.dart';
import 'auth/oss_token.dart';
import 'client_config.dart';
import 'models/oss_const.dart';
import 'models/request_message.dart';
import 'network/OssRequest.dart';
import 'network/content_type_utils.dart';
import 'network/oss_call.dart';
import 'oss_utils.dart';
import 'service/base_service.dart';
import 'service/bucket_service.dart';
import 'service/object_service.dart';

///oss 封装类
class OssClient
    with ObjectService, BucketService
    implements BaseService {
  //提供单例
  static OssClient get instance => OssClient();

  //全局配置
  static ClientConfig _config;

  Dio _dio;

  OssClient() {
    _init();
  }

  static void init(ClientConfig config) {
    _config = config;
  }

  void _init() {
    _initDio();
  }

  void _initDio() {
    BaseOptions options;
    if (_config != null) {
      int connectTimeout = _config.connectTimeout;
      int receiveTimeout = _config.receiveTimeout;
      String baseUrl =
          OssUtils.buildUrlWithBucket(_config.bucket, _config.endPoint);
      options = BaseOptions(
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          baseUrl: baseUrl);
    }
    _dio = Dio(options);
    _dio.interceptors
        .add(LogInterceptor(requestBody: false, responseBody: true));
  }

  @override
  Future<OssCall> newCall(RequestMessage requestMessage) async {
    OssRequest request = await createOssRequest(requestMessage);
    OssCall call = OssCall(request, _dio);
    return call;
  }

  String ossDate(){
    var date = new DateTime.now().toUtc();
    var year = date.year;
    var month = date.month < 10 ? '0${date.month}' : date.month;
    var day = date.day < 10 ? '0${date.day}' : date.day;
    var hour = date.hour < 10 ? '0${date.hour}' : date.hour;
    var minute = date.minute < 10 ? '0${date.minute}' : date.minute;
    var seconds = date.second < 10 ? '0${date.second}' : date.second;
    var zone = date.timeZoneName;
    var weekDay = date.weekday;

    var weekDayStr = 'Mon';
    switch (weekDay){
      case 1:
        weekDayStr = 'Mon';
        break;
      case 2:
        weekDayStr = 'Tue';
        break;
      case 3:
        weekDayStr = 'Wed';
        break;
      case 4:
        weekDayStr = 'Thu';
        break;
      case 5:
        weekDayStr = 'Fri';
        break;
      case 6:
        weekDayStr = 'Sat';
        break;
      case 7:
        weekDayStr = 'Sun';
        break;
    }

    var monthStr = 'Jan';
    switch (month){
      case 1:
        monthStr = 'Jan';
        break;
      case 2:
        monthStr = 'Feb';
        break;
      case 3:
        monthStr = 'Mar';
        break;
      case 4:
        monthStr = 'Apr';
        break;
      case 5:
        monthStr = 'May';
        break;
      case 6:
        monthStr = 'Jun';
        break;
      case 7:
        monthStr = 'Jul';
        break;
      case 8:
        monthStr = 'Aug';
        break;
      case 9:
        monthStr = 'Sept';
        break;
      case 10:
        monthStr = 'Oct';
        break;
      case 11:
        monthStr = 'Nov';
        break;
      case 12:
        monthStr = 'Dec';
        break;
    }

    return "$weekDayStr, $day $monthStr $year $hour:$minute:$seconds GMT";
  }

  Future<OssRequest> createOssRequest(RequestMessage requestMessage) async {
    OssRequest request = OssRequest();
    var date = new DateTime.now();
    Map<String, dynamic> header = {
      HttpHeaderKey.CONTENT_TYPE:requestMessage.contentType??'',
        "x-oss-date": ossDate(),
        "Date": ossDate()
    };
    //生成url
    request.url = _buildUrl(requestMessage);
    //处理请求方法
    request.method = _buildMethod(requestMessage);
    //处理上传文件
    request.data = await _buildData(requestMessage, header);
    String bucket = requestMessage.bucketName?? _config.bucket;
    request.bucket = bucket;
    request.objectKey =
        requestMessage.objectKey == null ? "" : requestMessage.objectKey;
    request.contentType = requestMessage.contentType;
    request.headers = header;
    //处理Authorization
    if (requestMessage.isAuthorizationRequired??_config.authorizationProvider != null) {
      OssToken token = await _config.authorizationProvider.getAuthorization();
      request.headers[HttpHeaderKey.X_OSS_SECURITY_TOKEN]=token.securityToken;
      OssRequestSigner signer = OssRequestSigner(token, request);
      String authorization = signer.sign();
      if (authorization != null && authorization.isNotEmpty) {
        request.headers[HttpHeaderKey.AUTHORIZATION] = authorization;
      }
    }
    return request;
  }

  ///获取url
  String _buildUrl(RequestMessage requestMessage) {
    String bucket = requestMessage.bucketName ?? _config.bucket;
    String resourcePath = requestMessage.objectKey;
    String url = OssUtils.buildUrlWithBucket(bucket, _config.endPoint,
        resourcePath: resourcePath);
    print("requestUrl=$url");
    return url;
  }

  ///获取Http method
  String _buildMethod(RequestMessage requestMessage) {
    HttpMethod method = requestMessage.method;
    assert(method != null);
    String methodStr;
    switch (method) {
      case HttpMethod.GET:
        methodStr = "GET";
        break;
      case HttpMethod.POST:
        methodStr = "POST";
        break;
      case HttpMethod.PUT:
        methodStr = "PUT";
        break;
      case HttpMethod.DELETE:
        methodStr = "DELETE";
        break;
    }
    return methodStr;
  }

  ///获取data
  Future<dynamic> _buildData(
      RequestMessage requestMessage, Map<String, dynamic> header) async {
    String path = requestMessage.uploadPath;
    if (path != null && path.isNotEmpty) {
      File file = File(path);
      bool isExist = await file.exists();
      if (isExist) {
        header['Content-Type'] = ContentTypeUtils.getFileContentTypeString(path);
        return file.openRead();
      }
    } else {
      return null;
    }
  }
}
