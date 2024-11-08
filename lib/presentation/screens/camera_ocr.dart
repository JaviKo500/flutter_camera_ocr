import 'package:flutter/material.dart';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraOcr extends StatefulWidget {
  const CameraOcr({super.key});

  @override
  State<CameraOcr> createState() => _CameraOcrState();
}

class _CameraOcrState extends State<CameraOcr> {
  bool _isPermissionGranted = false;
  bool _loadingText = false;
  double zoom = 0.0;
  double maxZoom = 0.0;
  CameraController? _cameraController;
  final textRecognizer = TextRecognizer();
  String keyAccess = '';
  late final Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = _requestCameraPermission();
  }

  @override
  void dispose() {
    _stopCamera();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Camera Ocr', style: TextStyle()),
        ),
        body: FutureBuilder(
          future: _future,
          builder: (context, snapshot) {
            return Padding(
              padding: const EdgeInsets.all(12.0),
              child: Stack(
                alignment: Alignment.topCenter,
                children: [
                  Column(
                    children: [
                      Text(keyAccess,
                          textAlign: TextAlign.center, style: const TextStyle()),
                      Text('Max Zoom $maxZoom',
                        textAlign: TextAlign.center, style: const TextStyle()),
                    ],
                  ),
                  if (_isPermissionGranted)
                    FutureBuilder<List<CameraDescription>>(
                      future: availableCameras(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          _initCameraController(snapshot.data!);
                          return Center(
                              child: CameraPreview(_cameraController!)
                              );
                        } else {
                          return const LinearProgressIndicator();
                        }
                      },
                    ),
                  _isPermissionGranted
                      ? Column(
                          children: [
                            Expanded(
                              child: Container(),
                            ),
                            Container(
                              padding: const EdgeInsets.only(bottom: 5.0),
                              child: Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      ElevatedButton(
                                        onPressed: () async {
                                          if ( zoom > 0 ) {
                                            setState(() {
                                              --zoom;
                                            });
                                            await _cameraController?.setZoomLevel(zoom);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.blueGrey,
                                          textStyle: const TextStyle(  color: Colors.white,), // Color rojo del botón
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 20.0),
                                        ),
                                        child: const Icon(Icons.zoom_out, color: Colors.white,),
                                      ),
                                      const SizedBox(height: 10,),
                                      ElevatedButton(
                                        onPressed: () async {
                                          if ( zoom < maxZoom ) {
                                            setState(() {
                                              ++zoom;
                                            });
                                            await _cameraController?.setZoomLevel(zoom);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: zoom < maxZoom 
                                            ?Colors.red
                                            : Colors.grey  ,
                                          textStyle: const TextStyle(  color: Colors.white,), // Color rojo del botón
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 20.0),
                                        ),
                                        child: const Icon(Icons.zoom_in, color: Colors.white,),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10,),
                            Container(
                              padding: const EdgeInsets.only(bottom: 5.0),
                              child: Center(
                                child: SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _loadingText ? null : _scanImage,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          Colors.red,
                                      textStyle: const TextStyle(  color: Colors.white,), // Color rojo del botón
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16.0),
                                    ),
                                    child: const Text('Escanear Clave', style: TextStyle(color: Colors.white, fontSize: 20),),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Center(
                          child: Container(
                            padding:
                                const EdgeInsets.only(left: 24.0, right: 24.0),
                            child: const Text(
                              'Camera permission denied',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                ],
              ),
            );
          },
        ));
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    _isPermissionGranted = status == PermissionStatus.granted;
  }

  void _startCamera() {
    if (_cameraController != null) {
      _cameraSelected(_cameraController!.description);
    }
  }

  void _stopCamera() {
    if (_cameraController != null) {
      _cameraController?.dispose();
    }
  }

  void _initCameraController(List<CameraDescription> cameras) {
    if (_cameraController != null) {
      return;
    }

    // Select the first rear camera.
    CameraDescription? camera;
    for (var i = 0; i < cameras.length; i++) {
      final CameraDescription current = cameras[i];
      if (current.lensDirection == CameraLensDirection.back) {
        camera = current;
        break;
      }
    }

    if (camera != null) {
      _cameraSelected(camera);
    }
  }

  Future<void> _cameraSelected(CameraDescription camera) async {
    _cameraController = CameraController(
      camera,
      ResolutionPreset.ultraHigh,
      enableAudio: false,
    );
    await _cameraController!.initialize();
    await _cameraController!.setFlashMode(FlashMode.off);
    maxZoom = await _cameraController?.getMaxZoomLevel() ?? 0;
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  Future<void> _scanImage() async {
    if (_cameraController == null) return;
    try {
      setState(() {
        _loadingText = true;
      });
      final pictureFile = await _cameraController!.takePicture();

      final file = File(pictureFile.path);

      final inputImage = InputImage.fromFile(file);
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Expresión regular para encontrar texto con el formato AAA-1234
      final plateRegExp = RegExp(r'\d+');
      ;
      final matches = plateRegExp.allMatches(recognizedText.text);

      if (matches.isNotEmpty) {
        String? accessAuth =
            matches.first.group(0); // Extraemos la primera coincidencia
        if (accessAuth != null) {
          accessAuth =
              accessAuth.replaceAll('-', ''); // Eliminar el guion del texto
        }
        setState(() {
          keyAccess = accessAuth ?? "Not valid";
          _loadingText = false;
        });
      } else {
        setState(() {
          keyAccess = 'Not valid';
          _loadingText = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No se encontró una clave de acceso con el formato adecuado.'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _loadingText = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error al escanear la clave'),
        ),
      );
    }
  }
}
