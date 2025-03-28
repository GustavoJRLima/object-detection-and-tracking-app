import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(ObjectDetectionApp(cameras: cameras));
}

class ObjectDetectionApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  ObjectDetectionApp({required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ObjectDetectionScreen(cameras: cameras),
    );
  }
}

class ObjectDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  ObjectDetectionScreen({required this.cameras});

  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  late CameraController _cameraController;
  late ObjectDetector _objectDetector;
  bool isProcessing = false;
  List<DetectedObject> detectedObjects = [];

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeObjectDetector();
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.max,
      enableAudio: false,
    );

    try {
      await _cameraController.initialize();
      if (!mounted) return;
      setState(() {});
      _startImageStream();
    } catch (e) {
      print("Erro ao iniciar a câmera: $e");
    }
  }

  void _initializeObjectDetector() {
    final options = ObjectDetectorOptions(
      mode: DetectionMode.stream,
      classifyObjects: true,
      multipleObjects: true,
    );
    _objectDetector = ObjectDetector(options: options);
  }

  void _startImageStream() {
    if (!_cameraController.value.isInitialized) return;

    _cameraController.startImageStream((CameraImage image) async {
      if (isProcessing) return;

      isProcessing = true;

      try {
        final inputImage = _convertCameraImageToInputImage(image);
        if (inputImage == null) {
          isProcessing = false;
          return;
        }

        final objects = await _objectDetector.processImage(inputImage);
        print("Objetos detectados: ${objects.length}");

        if (mounted) {
          setState(() {
            detectedObjects = objects;
          });
        }
      } catch (e) {
        print("Erro ao processar imagem: $e");
      }

      isProcessing = false;
    });
  }

  InputImage? _convertCameraImageToInputImage(CameraImage image) {
    try {
      final WriteBuffer buffer = WriteBuffer();
      for (final Plane plane in image.planes) {
        buffer.putUint8List(plane.bytes);
      }
      final Uint8List bytes = buffer.done().buffer.asUint8List();

      final metadata = InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      return InputImage.fromBytes(bytes: bytes, metadata: metadata);
    } catch (e) {
      print("Erro na conversão da imagem: $e");
      return null;
    }
  }

  @override
  void dispose() {
    if (_cameraController.value.isInitialized) {
      _cameraController.dispose();
    }
    _objectDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Detecção de Objetos')),
      body: Column(
        children: [
          if (_cameraController.value.isInitialized)
            AspectRatio(
              aspectRatio: _cameraController.value.aspectRatio,
              child: CameraPreview(_cameraController),
            )
          else
            Container(
              height: 200,
              alignment: Alignment.center,
              child: CircularProgressIndicator(),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: detectedObjects.length,
              itemBuilder: (context, index) {
                final object = detectedObjects[index];
                return ListTile(
                  title: Text('Objeto ${index + 1}'),
                  subtitle: Text(
                    'Rótulo: ${object.labels.isNotEmpty ? object.labels.first.text : 'Desconhecido'}',
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
