import 'dart:io';
import 'dart:typed_data';

import 'dart:ui' as ui;
import 'package:angles/angles.dart';
import 'package:body_detection/body_detection.dart';
import 'package:body_detection/models/body_mask.dart';
import 'package:body_detection/models/image_result.dart';
import 'package:body_detection/models/pose.dart';
import 'package:body_detection/models/pose_landmark.dart';
import 'package:body_detection/models/pose_landmark_type.dart';
import 'package:body_detection/png_image.dart';
import 'package:body_posture_detector/pose_mask_painter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class ImagePickerScreen extends StatefulWidget {
  const ImagePickerScreen({Key? key}) : super(key: key);

  @override
  State<ImagePickerScreen> createState() => _ImagePickerScreenState();
}

class _ImagePickerScreenState extends State<ImagePickerScreen> {
  int _selectedTabIndex = 0;

  bool _isDetectingPose = false;
  bool _isDetectingBodyMask = false;
  LensFacing _lens = LensFacing.front;

  Image? _selectedImage;

  Pose? _detectedPose;
  ui.Image? _maskImage;
  Image? _cameraImage;
  Size _imageSize = Size.zero;

  Future<void> _selectImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.single.path;
    if (path != null) {
      _resetState();
      setState(() {
        _selectedImage = Image.file(File(path));
      });
    }
  }

  bool _showLoader = false;
  Future<void> _detectImagePose() async {
    PngImage? pngImage = await _selectedImage?.toPngImage();
    if (pngImage == null) return;
    setState(() {
      _imageSize = Size(pngImage.width.toDouble(), pngImage.height.toDouble());
    });
    final pose = await BodyDetection.detectPose(image: pngImage);
    _handlePose(pose);
  }

  Future<void> _detectImageBodyMask() async {
    PngImage? pngImage = await _selectedImage?.toPngImage();
    if (pngImage == null) return;
    setState(() {
      _imageSize = Size(pngImage.width.toDouble(), pngImage.height.toDouble());
    });
    final mask = await BodyDetection.detectBodyMask(image: pngImage);
    _handleBodyMask(mask);
  }

  Future<void> _startCameraStream() async {
    final request = await Permission.camera.request();
    if (request.isGranted) {
      await BodyDetection.startCameraStream(
        onFrameAvailable: _handleCameraImage,
        onPoseAvailable: (pose) {
          if (!_isDetectingPose) return;
          _handlePose(pose);
        },
        onMaskAvailable: (mask) {
          if (!_isDetectingBodyMask) return;
          _handleBodyMask(mask);
        },
      );
    }
  }

  Future<void> _stopCameraStream() async {
    await BodyDetection.stopCameraStream();

    setState(() {
      _cameraImage = null;
      _imageSize = Size.zero;
    });
  }

  void _handleCameraImage(ImageResult result) {
    // Ignore callback if navigated out of the page.
    if (!mounted) return;

    // To avoid a memory leak issue.
    // https://github.com/flutter/flutter/issues/60160
    PaintingBinding.instance?.imageCache?.clear();
    PaintingBinding.instance?.imageCache?.clearLiveImages();

    final image = Image.memory(
      result.bytes,
      gaplessPlayback: true,
      fit: BoxFit.contain,
    );

    setState(() {
      _cameraImage = image;
      _imageSize = result.size;
    });
  }

  void _handlePose(Pose? pose) {
    // Ignore if navigated out of the page.
    if (!mounted) return;

    setState(() {
      _detectedPose = pose;
    });
  }

  void _handleBodyMask(BodyMask? mask) {
    // Ignore if navigated out of the page.
    if (!mounted) return;

    if (mask == null) {
      setState(() {
        _maskImage = null;
      });
      return;
    }

    final bytes = mask.buffer
        .expand(
          (it) => [0, 0, 0, (it * 255).toInt()],
        )
        .toList();
    ui.decodeImageFromPixels(Uint8List.fromList(bytes), mask.width, mask.height, ui.PixelFormat.rgba8888,
        (image) {
      setState(() {
        _maskImage = image;
      });
    });
  }

  Future<void> _toggleDetectPose() async {
    if (_isDetectingPose) {
      await BodyDetection.disablePoseDetection();
    } else {
      await BodyDetection.enablePoseDetection();
    }

    setState(() {
      _isDetectingPose = !_isDetectingPose;
      _detectedPose = null;
    });
  }

  Future<void> _toggleLens() async {
    await _stopCameraStream();
    if (_lens == LensFacing.front) {
      await BodyDetection.switchCamera(LensFacing.back);
      _lens = LensFacing.back;
    } else {
      await BodyDetection.switchCamera(LensFacing.front);
      _lens = LensFacing.front;
    }

    await _startCameraStream();
  }

  Future<void> _toggleDetectBodyMask() async {
    if (_isDetectingBodyMask) {
      await BodyDetection.disableBodyMaskDetection();
    } else {
      await BodyDetection.enableBodyMaskDetection();
    }

    setState(() {
      _isDetectingBodyMask = !_isDetectingBodyMask;
      _maskImage = null;
    });
  }

  void _onTabEnter(int index) {
    // Camera tab
    if (index == 1) {
      _startCameraStream();
    }
  }

  void _onTabExit(int index) {
    // Camera tab
    if (index == 1) {
      _stopCameraStream();
    }
  }

  void _onTabSelectTapped(int index) {
    _onTabExit(_selectedTabIndex);
    _onTabEnter(index);

    setState(() {
      _selectedTabIndex = index;
    });
  }

  Widget? get _selectedTab => _selectedTabIndex == 0
      ? _imageDetectionView
      : _selectedTabIndex == 1
          ? _cameraDetectionView
          : null;

  void _resetState() {
    setState(() {
      _maskImage = null;
      _detectedPose = null;
      _imageSize = Size.zero;
    });
  }

  final _buttonStyle = OutlinedButton.styleFrom(
    backgroundColor: const ui.Color.fromARGB(153, 104, 204, 207),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    side: const BorderSide(
      color: ui.Color.fromRGBO(44, 51, 51, 1),
    ),
  );

  Widget get _noImageSelected => Center(
        child: Card(
          shape: const CircleBorder(
            side: BorderSide(
              color: ui.Color.fromRGBO(2, 67, 67, 1),
              width: 1.5,
            ),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          elevation: 7,
          color: const ui.Color.fromRGBO(113, 181, 181, 0.6),
          child: GestureDetector(
            onTap: () {
              _selectImage();
            },
            child: Container(
              height: 100,
              padding: const EdgeInsets.all(15),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.filter,
                    size: 25,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Select Image',
                    style: Theme.of(context).textTheme.button,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  double getAngle(
      {required PoseLandmark firstPoint, required PoseLandmark midPoint, required PoseLandmark lastPoint}) {
    var result = Angle.degrees(Angle.atan2(
                    lastPoint.position.y - midPoint.position.y, lastPoint.position.x - midPoint.position.x)
                .degrees -
            Angle.atan2(
                    firstPoint.position.y - midPoint.position.y, firstPoint.position.x - midPoint.position.x)
                .degrees)
        .degrees;
    result = result.abs().roundToDouble();
    result = result > 180 ? 360 - result : result;
    return result;
  }

  Widget get _imageDetectionView => _selectedImage == null
      ? _noImageSelected
      : Card(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          elevation: 0,
          color: Colors.transparent,
          child: Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CustomPaint(
                  child: _selectedImage,
                  foregroundPainter: PoseMaskPainter(
                    pose: _detectedPose,
                    mask: _maskImage,
                    imageSize: _imageSize,
                  ),
                ),
              ),
              if (_showLoader)
                const Center(
                  child: CircularProgressIndicator(
                    backgroundColor: ui.Color.fromRGBO(165, 201, 202, 1),
                    color: ui.Color.fromRGBO(44, 51, 51, 1),
                  ),
                ),
              Positioned(
                bottom: 5,
                left: 5,
                child: OutlinedButton(
                  onPressed: () async {
                    setState(() {
                      _showLoader = true;
                    });
                    await _detectImagePose();
                    setState(() {
                      _showLoader = false;
                      double result = getAngle(
                        firstPoint:
                            PoseMaskPainter.getPoselandMark(PoseLandmarkType.rightAnkle, _detectedPose),
                        midPoint: PoseMaskPainter.getPoselandMark(PoseLandmarkType.rightKnee, _detectedPose),
                        lastPoint: PoseMaskPainter.getPoselandMark(PoseLandmarkType.rightHip, _detectedPose),
                      );

                      print(result);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$result'),
                        duration: Duration(seconds: 5),
                      ));
                    });
                  },
                  child: Text(
                    'Detect pose',
                    style: Theme.of(context).textTheme.button,
                  ),
                  style: _buttonStyle,
                ),
              ),
              Positioned(
                bottom: 5,
                right: 5,
                child: OutlinedButton(
                  style: _buttonStyle,
                  onPressed: () async {
                    setState(() {
                      _showLoader = true;
                    });
                    await _detectImageBodyMask();
                    setState(() {
                      _showLoader = false;
                    });
                  },
                  child: Text(
                    'Detect body mask',
                    style: Theme.of(context).textTheme.button,
                  ),
                ),
              ),
            ],
          ),
        );

  Widget get _cameraDetectionView => Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CustomPaint(
                child: _cameraImage,
                foregroundPainter: PoseMaskPainter(
                  pose: _detectedPose,
                  mask: _maskImage,
                  imageSize: _imageSize,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 80,
            child: OutlinedButton(
              style: _buttonStyle,
              onPressed: () {
                _toggleDetectPose();
              },
              child: _isDetectingPose
                  ? Text(
                      'Turn off pose detection',
                      style: Theme.of(context).textTheme.button,
                    )
                  : Text(
                      'Turn on pose detection',
                      style: Theme.of(context).textTheme.button,
                    ),
            ),
          ),
          Positioned(
            bottom: 20,
            child: OutlinedButton(
              style: _buttonStyle,
              onPressed: () {
                _toggleDetectBodyMask();
              },
              child: _isDetectingBodyMask
                  ? Text(
                      'Turn off body mask detection',
                      style: Theme.of(context).textTheme.button,
                    )
                  : Text(
                      'Turn on body mask detection',
                      style: Theme.of(context).textTheme.button,
                    ),
            ),
          ),
        ],
      );

  // final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // key: _scaffoldKey,
      appBar: AppBar(
        title: Text(
          'Body Detection',
          style: Theme.of(context).textTheme.headline1,
        ),
        actions: _selectedTabIndex == 0
            ? [
                IconButton(
                  onPressed: _selectImage,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                  ),
                ),
                if (_selectedImage != null)
                  IconButton(
                    onPressed: () {
                      _resetState();
                    },
                    icon: const Icon(
                      Icons.replay,
                    ),
                  ),
              ]
            : [
                IconButton(
                  onPressed: _toggleLens,
                  icon: const Icon(
                    Icons.cameraswitch_outlined,
                  ),
                ),
              ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.shifting,
        selectedItemColor: const ui.Color.fromARGB(255, 69, 113, 125),
        unselectedItemColor: const ui.Color.fromARGB(255, 111, 153, 154),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.image),
            label: 'Image',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Camera',
          ),
        ],
        currentIndex: _selectedTabIndex,
        onTap: _onTabSelectTapped,
      ),
      body: GestureDetector(
        onPanUpdate: (details) {
          // Swiping in left direction.
          if (details.delta.dx < 0 && _selectedTabIndex != 1) {
            setState(() {
              _onTabExit(_selectedTabIndex);
              _selectedTabIndex = 1;
              _onTabEnter(_selectedTabIndex);
            });
          }

          // Swiping in right direction.
          if (details.delta.dx > 0 && _selectedTabIndex != 0) {
            setState(() {
              _onTabExit(_selectedTabIndex);
              _selectedTabIndex = 0;
              _onTabEnter(_selectedTabIndex);
            });
          }
        },
        child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ui.Color.fromRGBO(44, 51, 51, 1),
                  ui.Color.fromARGB(255, 123, 176, 178),
                  ui.Color.fromRGBO(57, 91, 100, 1),
                ],
                tileMode: TileMode.clamp,
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                stops: [
                  0.1,
                  0.6,
                  0.9,
                ],
              ),
            ),
            height: MediaQuery.of(context).size.height - AppBar().preferredSize.height,
            width: MediaQuery.of(context).size.width,
            child: _selectedTab),
      ),
    );
  }
}
