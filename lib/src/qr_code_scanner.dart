import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'types/barcode.dart';
import 'types/camera.dart';
import 'types/features.dart';
import 'types/status.dart';

typedef QRViewCreatedCallback = void Function(QRViewController);
typedef PermissionSetCallback = void Function(QRViewController, bool);

enum BarcodeFormat {
  /// Aztec 2D barcode format.
  aztec,

  /// CODABAR 1D format.
  codabar,

  /// Code 39 1D format.
  code39,

  /// Code 93 1D format.
  code93,

  /// Code 128 1D format.
  code128,

  /// Data Matrix 2D barcode format.
  dataMatrix,

  /// EAN-8 1D format.
  ean8,

  /// EAN-13 1D format.
  ean13,

  /// ITF (Interleaved Two of Five) 1D format.
  itf,

  /// MaxiCode 2D barcode format.
  maxicode,

  /// PDF417 format.
  pdf417,

  /// QR Code 2D barcode format.
  qrcode,

  /// RSS 14
  rss14,

  /// RSS EXPANDED
  rssExpanded,

  /// UPC-A 1D format.
  upcA,

  /// UPC-E 1D format.
  upcE,

  /// UPC/EAN extension format. Not a stand-alone format.
  upcEanExtension
}

const _formatNames = <String, BarcodeFormat>{
  'AZTEC': BarcodeFormat.aztec,
  'CODABAR': BarcodeFormat.codabar,
  'CODE_39': BarcodeFormat.code39,
  'CODE_93': BarcodeFormat.code93,
  'CODE_128': BarcodeFormat.code128,
  'DATA_MATRIX': BarcodeFormat.dataMatrix,
  'EAN_8': BarcodeFormat.ean8,
  'EAN_13': BarcodeFormat.ean13,
  'ITF': BarcodeFormat.itf,
  'MAXICODE': BarcodeFormat.maxicode,
  'PDF_417': BarcodeFormat.pdf417,
  'QR_CODE': BarcodeFormat.qrcode,
  'RSS_14': BarcodeFormat.rss14,
  'RSS_EXPANDED': BarcodeFormat.rssExpanded,
  'UPC_A': BarcodeFormat.upcA,
  'UPC_E': BarcodeFormat.upcE,
  'UPC_EAN_EXTENSION': BarcodeFormat.upcEanExtension,
};

class Barcode {
  Barcode(this.code, this.format);

  final String code;
  final BarcodeFormat format;
}

class QRView extends StatefulWidget {
  static final _channel = MethodChannel('net.touchcapture.qr.flutterqr/qrview');

  static Future<bool> requestCameraPermission() async {
    try {
      var permissions = await _channel.invokeMethod('requestPermissions');
      return permissions;
    } on PlatformException {
      return false;
    }
  }

  const QRView({
    @required Key key,
    @required this.onQRViewCreated,
    this.onPermissionSet,
    this.showNativeAlertDialog = false,
    this.overlay,
  })  : assert(key != null),
        assert(onQRViewCreated != null),
        assert(showNativeAlertDialog != null),
        super(key: key);

  final QRViewCreatedCallback onQRViewCreated;
  final PermissionSetCallback onPermissionSet;
  final bool showNativeAlertDialog;
  final ShapeBorder overlay;

  @override
  State<StatefulWidget> createState() => _QRViewState();
}

class _QRViewState extends State<QRView> {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _getPlatformQrView(),
        if (widget.overlay != null)
          Container(
            decoration: ShapeDecoration(
              shape: widget.overlay,
            ),
          )
        else
          Container(),
      ],
    );
  }

  Widget _getPlatformQrView() {
    Widget _platformQrView;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        _platformQrView = AndroidView(
          viewType: 'net.touchcapture.qr.flutterqr/qrview',
          onPlatformViewCreated: _onPlatformViewCreated,
        );
        break;
      case TargetPlatform.iOS:
        _platformQrView = UiKitView(
          viewType: 'net.touchcapture.qr.flutterqr/qrview',
          onPlatformViewCreated: _onPlatformViewCreated,
          creationParams: _CreationParams.fromWidget(0, 0).toMap(),
          creationParamsCodec: StandardMessageCodec(),
        );
        break;
      default:
        throw UnsupportedError(
            "Trying to use the default webview implementation for $defaultTargetPlatform but there isn't a default one");
    }
    return _platformQrView;
  }

  void _onPlatformViewCreated(int id) {
    if (widget.onQRViewCreated == null) {
      return;
    }
    widget.onQRViewCreated(QRViewController._(
        id, widget.key, widget.onPermissionSet, widget.showNativeAlertDialog));
  }
}

class _CreationParams {
  _CreationParams({this.width, this.height});

  static _CreationParams fromWidget(double width, double height) {
    return _CreationParams(
      width: width,
      height: height,
    );
  }

  final double width;
  final double height;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'width': width,
      'height': height,
    };
  }
}

class QRViewController {
  QRViewController._(
    int id,
    GlobalKey qrKey,
    PermissionSetCallback onPermissionSet,
    bool showNativeAlertDialogOnError,
  ) : _channel = MethodChannel('net.touchcapture.qr.flutterqr/qrview_$id') {
    updateDimensions(qrKey);
    _channel.setMethodCallHandler((call) async {
      var args = call.arguments;
      switch (call.method) {
        case scanMethodCall:
          if (args != null) {
            // final argsMap = call.arguments as Map;
            final code = args['code'] as String;
            final rawType = args['type'] as String;
            final format = _formatNames[rawType];
            if (format != null) {
              final barcode = Barcode(code, format);
              _scanUpdateController.sink.add(barcode);
            } else {
              throw Exception('Unexpected barcode type $rawType');
              // _scanUpdateController.sink.add(args.toString());
            }
          }
          break;
        case permissionMethodCall:
          await getSystemFeatures(); // if we have no permission all features will not be available
          if (args != null) {
            if (args as bool) {
              _cameraActive = true;
              _hasPermissions = true;
            } else {
              _hasPermissions = false;
              if (showNativeAlertDialogOnError) {
                await showNativeAlertDialog();
              }
            }
            if (onPermissionSet != null) {
              onPermissionSet(this, args as bool);
            }
          }
          break;
      }
    });
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final RenderBox renderBox = qrKey.currentContext.findRenderObject();
      _channel.invokeMethod('setDimensions',
          {'width': renderBox.size.width, 'height': renderBox.size.height});
    }
  }

  static const scanMethodCall = 'onRecognizeQR';
  static const permissionMethodCall = 'onPermissionSet';

  final MethodChannel _channel;

  final StreamController<Barcode> _scanUpdateController =
      StreamController<Barcode>();

  Stream<Barcode> get scannedDataStream => _scanUpdateController.stream;

  bool _flashActive = false;

  bool _cameraActive = false;

  int _activeCamera = 0;

  SystemFeatures _features;

  SystemFeatures get systemFeatures => _features;

  bool _hasPermissions;

  bool get hasPermissions => _hasPermissions;

  bool get cameraActive => _cameraActive;

  bool get flashActive => _flashActive;

  Camera get activeCamera =>
      _activeCamera == null ? null : Camera.values[_activeCamera];

  Future<ReturnStatus> flipCamera() async {
    try {
      _activeCamera = await _channel.invokeMethod('flipCamera') as int;
      return ReturnStatus.success;
    } on PlatformException {
      return ReturnStatus.failed;
    }
  }

  Future<ReturnStatus> toggleFlash() async {
    try {
      _flashActive = await _channel.invokeMethod('toggleFlash') as bool;
      return ReturnStatus.success;
    } on PlatformException {
      return ReturnStatus.failed;
    }
  }

  Future<ReturnStatus> pauseCamera() async {
    try {
      var cameraPaused = await _channel.invokeMethod('pauseCamera') as bool;
      _cameraActive = !cameraPaused;
      return ReturnStatus.success;
    } on PlatformException {
      return ReturnStatus.failed;
    }
  }

  Future<ReturnStatus> resumeCamera() async {
    try {
      _cameraActive = await _channel.invokeMethod('resumeCamera');
      return ReturnStatus.success;
    } on PlatformException {
      return ReturnStatus.failed;
    }
  }

  Future<ReturnStatus> showNativeAlertDialog() async {
    try {
      await _channel.invokeMethod('showNativeAlertDialog');
      return ReturnStatus.success;
    } on PlatformException {
      return ReturnStatus.failed;
    }
  }

  Future<ReturnStatus> setAllowedBarcodeTypes(List<BarcodeTypes> list) async {
    try {
      await _channel.invokeMethod('setAllowedBarcodeFormats',
          list?.map((e) => e.asInt())?.toList() ?? []);
      return ReturnStatus.success;
    } on PlatformException {
      return ReturnStatus.failed;
    }
  }

  Future<SystemFeatures> getSystemFeatures() async {
    try {
      var features =
          await _channel.invokeMapMethod<String, dynamic>('getSystemFeatures');
      _features = SystemFeatures.fromJson(features);
      _activeCamera = features['activeCamera'];
      return _features;
    } on PlatformException {
      return null;
    }
  }

  void dispose() {
    _scanUpdateController.close();
  }

  void updateDimensions(GlobalKey key) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final RenderBox renderBox = key.currentContext.findRenderObject();
      _channel.invokeMethod('setDimensions',
          {'width': renderBox.size.width, 'height': renderBox.size.height});
    }
  }
}
