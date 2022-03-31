import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:exif/exif.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

class ExifPackage extends StatefulWidget {
  @override
  _ExifPackageState createState() => _ExifPackageState();
}

class _ExifPackageState extends State<ExifPackage> with WidgetsBindingObserver {
  bool servicestatus = false;
  bool haspermission = false;
  late LocationPermission permission;
  late Position position;
  String long = "", lat = "";
  late StreamSubscription<Position> positionStream;

  File? _image;
  final picker = ImagePicker();

  CameraController? controller;

  @override
  initState() {
    super.initState();
    WidgetsBinding.instance!.addObserver(this);
    _initCamera();
    checkGps();
  }

  @override
  void dispose() {
    controller?.dispose();
    WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }
    if (state == AppLifecycleState.inactive) {
      controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      if (controller != null) {
        _initCamera();
      }
    }
  }

  checkGps() async {
    servicestatus = await Geolocator.isLocationServiceEnabled();
    if (servicestatus) {
      permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print('Location permissions are denied');
        } else if (permission == LocationPermission.deniedForever) {
          print("'Location permissions are permanently denied");
        } else {
          haspermission = true;
        }
      } else {
        haspermission = true;
      }

      if (haspermission) {
        setState(() {
          //refresh the UI
        });

        getLocation();
      }
    } else {
      print("GPS Service is not enabled, turn on GPS location");
    }

    setState(() {
      //refresh the UI
    });
  }

  getLocation() async {
    position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    print(position.longitude); //Output: 80.24599079
    print(position.latitude); //Output: 29.6593457

    long = position.longitude.toString();
    lat = position.latitude.toString();

    setState(() {
      //refresh UI
    });

    LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high, //accuracy of the location data
      distanceFilter: 100, //minimum distance (measured in meters) a
      //device must move horizontally before an update event is generated;
    );

    StreamSubscription<Position> positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      print(position.longitude); //Output: 80.24599079
      print(position.latitude); //Output: 29.6593457

      long = position.longitude.toString();
      lat = position.latitude.toString();

      setState(() {
        //refresh UI on update
      });
    });
  }

  void _initCamera() async {
    controller?.dispose();

    var cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    await controller!.initialize();
    setState(() {});
  }

  Future onCameraCapture() async {
    if (controller == null || !controller!.value.isInitialized) {
      return;
    }

    if (!mounted) {
      return;
    }

    var path = await takePicture(controller!);
    if (path.isNotEmpty) {
      setState(() {
        _image = File(path);
      });
    }
  }

  Future<String> takePicture(CameraController controller) async {
    if (!controller.value.isInitialized) {
      return "";
    }

    if (controller.value.isTakingPicture) {
      // A capture is already pending, do nothing.
      return "";
    }

    try {
      final f = await controller.takePicture();
      return f.path;
    } on CameraException catch (e) {
      return "";
    }
  }

  Future getImage() async {
    var image = await picker.getImage(source: ImageSource.gallery);
    setState(() {
      if (image != null) {
        _image = File(image.path);
      }
    });
  }

  Future<String> getExifFromFile() async {
    if (_image == null) {
      return "";
    }

    var bytes = await _image!.readAsBytes();
    var tags = await readExifFromBytes(bytes);
    var sb = StringBuffer();

    tags.forEach((k, v) {
      sb.write("$k: $v \n");
    });

    return sb.toString();
  }

  Future<Widget> getImageFromCamera(BuildContext context) async {
    Widget res;
    if (_image == null) {
      res = Text('No image selected.');
    } else {
      var imageData = _image!.readAsBytesSync();

      var imageDataCompressed =
          await FlutterImageCompress.compressWithList(imageData);
      res = Image.memory(Uint8List.fromList(imageDataCompressed));
    }
    return res;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EXIF Viewer'),
        // actions: <Widget>[
        //   IconButton(
        //     icon: Icon(Icons.camera),
        //     onPressed: onCameraCapture,
        //   )
        // ],
      ),
      body: ListView(children: <Widget>[
        Column(
          children: <Widget>[
            ///Top camera
            // SizedBox(
            //   child: controller?.value.isInitialized ?? false
            //       ? CameraPreview(controller!)
            //       : Container(),
            //   height: 200.0,
            // ),
            // const SizedBox(
            //   height: 10.0,
            // ),
            // ElevatedButton.icon(
            //   onPressed: onCameraCapture,
            //   icon: const Icon(Icons.camera),
            //   label: const Text('Capture'),
            // ),
            const SizedBox(
              height: 10.0,
            ),
            Text(servicestatus ? "GPS is Enabled" : "GPS is disabled."),
            Text(haspermission ? "GPS is Enabled" : "GPS is disabled."),
            Text("Longitude: $long", style: TextStyle(fontSize: 20)),
            Text(
              "Latitude: $lat",
              style: TextStyle(fontSize: 20),
            ),
            const SizedBox(
              height: 10.0,
            ),
            FutureBuilder(
                future: getImageFromCamera(context),
                builder:
                    (BuildContext context, AsyncSnapshot<Widget> snapshot) {
                  if (snapshot.hasData) {
                    if (snapshot.data != null) {
                      return SizedBox(
                        child: snapshot.data,
                        height: 200.0,
                      );
                    } else {
                      return CircularProgressIndicator();
                    }
                  }
                  return Container();
                }),
            FutureBuilder(
              future: getExifFromFile(),
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (snapshot.hasData) {
                  if (snapshot.data != null) {
                    return Text(snapshot.data ?? "");
                  } else {
                    return CircularProgressIndicator();
                  }
                }
                return Container();
              },
            ),
          ],
        ),
      ]),
      floatingActionButton: FloatingActionButton(
        onPressed: getImage,
        tooltip: 'Pick Image',
        child: Icon(Icons.photo_library),
      ),
    );
  }
}
