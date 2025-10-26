import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:sensor_msgs/msgs.dart' as sensor_msgs;
import 'package:image/image.dart' as img;

class ImageTools {
  static ImageTools? _instance;
  static ImageTools get instance {
    _instance ??= ImageTools._init();
    return _instance!;
  }

  ImageTools._init();

  img.Image convertRosImageToImageFast(sensor_msgs.Image msg) {
    final Uint8List srcData = msg.data is Uint8List
        ? msg.data as Uint8List
        : Uint8List.fromList(msg.data);

    switch (msg.encoding) {
      case 'rgb8':
        return _rgb8ToImageFast(srcData, msg.width, msg.height);
      case 'bgr8':
        return _bgr8ToImageFast(srcData, msg.width, msg.height);
      case 'rgba8':
        return _rgba8ToImageFast(srcData, msg.width, msg.height);
      case 'bgra8':
        return _bgra8ToImageFast(srcData, msg.width, msg.height);
      case 'mono8':
      case '8UC1':
        return _mono8ToImageFast(srcData, msg.width, msg.height);
      default:
        throw Exception('Unsupported encoding: ${msg.encoding}');
    }
  }

  img.Image _rgb8ToImageFast(Uint8List src, int width, int height) {
    final int length = width * height;
    final rgba = Uint8List(length * 4);

    for (int i = 0; i < length; i++) {
      final s = i * 3;
      final d = i * 4;
      rgba[d] = src[s];
      rgba[d + 1] = src[s + 1];
      rgba[d + 2] = src[s + 2];
      rgba[d + 3] = 255;
    }

    return img.Image.fromBytes(
      width,
      height,
      rgba.buffer.asUint8List().toList(),
      channels: img.Channels.rgba,
    );
  }

  img.Image _bgr8ToImageFast(Uint8List src, int width, int height) {
    final int length = width * height;
    final rgba = Uint8List(length * 4);

    for (int i = 0; i < length; i++) {
      final s = i * 3;
      final d = i * 4;
      rgba[d] = src[s + 2];
      rgba[d + 1] = src[s + 1];
      rgba[d + 2] = src[s];
      rgba[d + 3] = 255;
    }

    return img.Image.fromBytes(
      width,
      height,
      rgba.buffer.asUint8List().toList(),
      channels: img.Channels.rgba,
    );
  }

  img.Image _rgba8ToImageFast(Uint8List src, int width, int height) {
    return img.Image.fromBytes(
      width,
      height,
      src.buffer.asUint8List().toList(),
      channels: img.Channels.rgba,
    );
  }

  img.Image _bgra8ToImageFast(Uint8List src, int width, int height) {
    final int length = width * height;
    final rgba = Uint8List(length * 4);

    for (int i = 0; i < length; i++) {
      final idx = i * 4;
      rgba[idx] = src[idx + 2];
      rgba[idx + 1] = src[idx + 1];
      rgba[idx + 2] = src[idx];
      rgba[idx + 3] = src[idx + 3];
    }

    return img.Image.fromBytes(
      width,
      height,
      rgba.buffer.asUint8List().toList(),
      channels: img.Channels.rgba,
    );
  }

  img.Image _mono8ToImageFast(Uint8List src, int width, int height) {
    final int length = width * height;
    final rgba = Uint8List(length * 4);

    for (int i = 0; i < length; i++) {
      final gray = src[i];
      final d = i * 4;
      rgba[d] = gray;
      rgba[d + 1] = gray;
      rgba[d + 2] = gray;
      rgba[d + 3] = 255;
    }

    return img.Image.fromBytes(
      width,
      height,
      rgba.buffer.asUint8List().toList(),
      channels: img.Channels.rgba,
    );
  }

  final Map<int, ui.Image> _uiImageCache = {};
  int _cacheCounter = 0;

  Future<ui.Image> convertImageToUiImageCached(img.Image image) async {
   
    if (_cacheCounter++ > 10) {
      _uiImageCache.clear();
      _cacheCounter = 0;
    }

    final bytes = image.getBytes(format: img.Format.rgba);

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      bytes,
      image.width,
      image.height,
      ui.PixelFormat.rgba8888,
      (ui.Image result) {
        completer.complete(result);
      },
    );

    return completer.future;
  }

  Future<ui.Image> convertRosToUiImageDirect(sensor_msgs.Image msg) async {
    final Uint8List srcData = msg.data is Uint8List
        ? msg.data as Uint8List
        : Uint8List.fromList(msg.data);

    Uint8List rgba;

    switch (msg.encoding) {
      case 'rgb8':
        rgba = _convertRgb8ToRgba(srcData, msg.width * msg.height);
        break;
      case 'bgr8':
        rgba = _convertBgr8ToRgba(srcData, msg.width * msg.height);
        break;
      case 'rgba8':
        rgba = srcData;
        break;
      case 'bgra8':
        rgba = _convertBgra8ToRgba(srcData, msg.width * msg.height);
        break;
      default:
        throw Exception('Unsupported encoding: ${msg.encoding}');
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      msg.width,
      msg.height,
      ui.PixelFormat.rgba8888,
      (ui.Image result) {
        completer.complete(result);
      },
    );

    return completer.future;
  }

  Uint8List _convertRgb8ToRgba(Uint8List src, int pixelCount) {
    final rgba = Uint8List(pixelCount * 4);
    for (int i = 0; i < pixelCount; i++) {
      final s = i * 3;
      final d = i * 4;
      rgba[d] = src[s];
      rgba[d + 1] = src[s + 1];
      rgba[d + 2] = src[s + 2];
      rgba[d + 3] = 255;
    }
    return rgba;
  }

  Uint8List _convertBgr8ToRgba(Uint8List src, int pixelCount) {
    final rgba = Uint8List(pixelCount * 4);
    for (int i = 0; i < pixelCount; i++) {
      final s = i * 3;
      final d = i * 4;
      rgba[d] = src[s + 2];
      rgba[d + 1] = src[s + 1];
      rgba[d + 2] = src[s];
      rgba[d + 3] = 255;
    }
    return rgba;
  }

  Uint8List _convertBgra8ToRgba(Uint8List src, int pixelCount) {
    final rgba = Uint8List(pixelCount * 4);
    for (int i = 0; i < pixelCount; i++) {
      final idx = i * 4;
      rgba[idx] = src[idx + 2];
      rgba[idx + 1] = src[idx + 1];
      rgba[idx + 2] = src[idx];
      rgba[idx + 3] = src[idx + 3];
    }
    return rgba;
  }
}
