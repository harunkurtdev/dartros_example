import 'dart:async';
import 'dart:ui' as ui;

import 'package:dartros/dartros.dart' as ros;
import 'package:dartros_example/base_ros_services.dart';
import 'package:dartros_example/image_tools.dart';
import 'package:flutter/services.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import 'package:sensor_msgs/msgs.dart' as sensor_msgs;
import 'package:geometry_msgs/msgs.dart' as geometry_msgs;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

Future<void> main(List<String> args) async {
  try {
    final ros.NodeHandle nodeHandle = await ros.initNode(
      'deneme',
      args,
      rosMasterUri: "http://192.168.182.128:11311",
    );
    BaseRosServices.instance.setNodeHandle(nodeHandle);
    runApp(MyApp());
  } catch (e) {
    print(e);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight]);
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'Flutter Demo ROS Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ros.Subscriber<sensor_msgs.Image>? sub;

  // İki ayrı stream: biri TensorFlow için, biri UI için
  final StreamController<img.Image> _tfImageStreamController =
      StreamController<img.Image>.broadcast();
  final StreamController<ui.Image> _uiImageStreamController =
      StreamController<ui.Image>.broadcast();

  bool _isProcessing = false;
  int _droppedFrames = 0;
  int _processedFrames = 0;
  img.Image? _currentImage;

  ros.Publisher<geometry_msgs.Twist>? joystickPub;

  @override
  void initState() {
    super.initState();
    // sub = BaseRosServices.instance.nodeHandle?.subscribe<sensor_msgs.Image>(
    //   '/camera/rgb/image_raw',
    //   sensor_msgs.Image.$prototype,
    //   (msg) => _processImage(msg),
    // );
    joystickPub =
        BaseRosServices.instance.nodeHandle?.advertise<geometry_msgs.Twist>(
      '/cmd_vel',
      geometry_msgs.Twist.$prototype,
    );
  }

  Future<void> _processImage(sensor_msgs.Image msg) async {
    if (_isProcessing) {
      _droppedFrames++;
      return;
    }

    _isProcessing = true;

    try {
      final tfImage = ImageTools.instance.convertRosImageToImageFast(msg);

      final uiImageFuture = ImageTools.instance.convertRosToUiImageDirect(msg);

      if (mounted) {
        _currentImage = tfImage;
        _tfImageStreamController.add(tfImage);
        _processedFrames++;

        uiImageFuture.then((uiImage) {
          if (!_uiImageStreamController.isClosed && mounted) {
            _uiImageStreamController.add(uiImage);
          }
        });
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isProcessing = false;
    }
  }

  @override
  void dispose() {
    _tfImageStreamController.close();
    _uiImageStreamController.close();
    sub?.shutdown();
    BaseRosServices.instance.nodeHandle?.shutdown();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            // Text(
            //   'Processed: $_processedFrames | Dropped: $_droppedFrames',
            //   style: Theme.of(context).textTheme.bodyMedium,
            // ),
            const SizedBox(height: 20),
            Joystick(
              listener: (details) {
                double x = details.x;
                double y = details.y;

                joystickPub?.publish(
                  geometry_msgs.Twist()
                    ..linear =
                        geometry_msgs.Vector3(x: -y * 1.0, y: 0.0, z: 0.0)
                    ..angular =
                        geometry_msgs.Vector3(x: 0.0, y: 0.0, z: -x * 1.0),
                );
                print('Joystick moved: x=$x, y=$y');
              },
            ),
            // Direkt ui.Image stream'i kullan (FutureBuilder yok!)
            // StreamBuilder<ui.Image>(
            //   stream: _uiImageStreamController.stream,
            //   builder: (context, snapshot) {
            //     if (!snapshot.hasData) {
            //       return const SizedBox(
            //         width: 640,
            //         height: 480,
            //         child: Center(
            //           child: Text('Waiting for camera stream...'),
            //         ),
            //       );
            //     }

            //     return SizedBox(
            //       width: 640,
            //       height: 480,
            //       child: RawImage(
            //         image: snapshot.data,
            //         fit: BoxFit.contain,
            //         filterQuality: FilterQuality.low,
            //       ),
            //     );
            //   },
            // ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
