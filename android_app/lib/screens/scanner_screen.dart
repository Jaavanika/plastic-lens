import 'package:camera/camera.dart';
import 'package:material_ui/material_ui.dart';
import 'package:permission_handler/permission_handler.dart';

import 'scan_flow.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

enum _CamStatus { starting, ready, denied, unavailable }

class _ScannerScreenState extends State<ScannerScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  _CamStatus _status = _CamStatus.starting;
  bool _capturing = false;
  FlashMode _flash = FlashMode.off;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  bool _starting = false;
  bool _wasRunning = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The permission dialog itself pauses the app, so only restart the
    // camera if it was actually running before.
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      final c = _controller;
      if (c != null) {
        _controller = null;
        _wasRunning = true;
        c.dispose();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_wasRunning) {
        _wasRunning = false;
        _start();
      } else if (_status == _CamStatus.denied) {
        // Back from system settings: start if access was granted there.
        Permission.camera.status.then((s) {
          if (s.isGranted) _start();
        });
      }
    }
  }

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    if (mounted) setState(() => _status = _CamStatus.starting);
    try {
      final permission = await Permission.camera.request();
      if (!permission.isGranted) {
        if (mounted) setState(() => _status = _CamStatus.denied);
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _status = _CamStatus.unavailable);
        return;
      }
      final back = cameras.firstWhere((c) => c.lensDirection == CameraLensDirection.back, orElse: () => cameras.first);
      final controller = CameraController(back, ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _status = _CamStatus.ready;
      });
    } on CameraException catch (e) {
      final denied = e.code.startsWith('CameraAccess');
      if (mounted) setState(() => _status = denied ? _CamStatus.denied : _CamStatus.unavailable);
    } catch (_) {
      if (mounted) setState(() => _status = _CamStatus.unavailable);
    } finally {
      _starting = false;
    }
  }

  Future<void> _capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || _capturing) return;
    setState(() => _capturing = true);
    try {
      final file = await c.takePicture();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PreviewScreen(imagePath: file.path, fromCamera: true)));
    } on CameraException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Capture failed: ${e.description ?? e.code}')));
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await c.setFlashMode(next);
      setState(() => _flash = next);
    } catch (_) {}
  }

  Future<void> _requestAgain() async {
    if (await Permission.camera.isPermanentlyDenied) {
      await openAppSettings();
    } else {
      await _start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan plastic'),
        actions: [
          if (_status == _CamStatus.ready)
            IconButton(
              tooltip: 'Torch',
              onPressed: _toggleFlash,
              icon: Icon(_flash == FlashMode.off ? Icons.flash_off : Icons.flash_on),
            ),
        ],
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    switch (_status) {
      case _CamStatus.starting:
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      case _CamStatus.denied:
        return _Message(
          icon: Icons.no_photography_outlined,
          text: 'PlasticLens needs camera access to scan items. You can still choose a photo from your gallery.',
          primary: ('Allow camera', _requestAgain),
          secondary: ('Choose from gallery', () => pickFromGallery(context)),
        );
      case _CamStatus.unavailable:
        return _Message(
          icon: Icons.videocam_off_outlined,
          text: 'The camera is not available on this device right now.',
          primary: ('Try again', _start),
          secondary: ('Choose from gallery', () => pickFromGallery(context)),
        );
      case _CamStatus.ready:
        final c = _controller!;
        return Column(children: [
          Expanded(
            child: Stack(alignment: Alignment.center, children: [
              Center(child: CameraPreview(c)),
              IgnorePointer(
                child: FractionallySizedBox(
                  widthFactor: 0.75,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white70, width: 2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ),
              ),
              const Positioned(
                bottom: 16,
                child: Text('Fill the frame with one item', style: TextStyle(color: Colors.white, fontSize: 14)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              IconButton.filledTonal(
                tooltip: 'Gallery',
                iconSize: 28,
                onPressed: () => pickFromGallery(context),
                icon: const Icon(Icons.photo_library_outlined),
              ),
              Semantics(
                button: true,
                label: 'Take photo',
                child: GestureDetector(
                  onTap: _capture,
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
                    padding: const EdgeInsets.all(5),
                    child: DecoratedBox(
                      decoration: BoxDecoration(shape: BoxShape.circle, color: _capturing ? Colors.white54 : Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ]),
          ),
        ]);
    }
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, required this.primary, required this.secondary});
  final IconData icon;
  final String text;
  final (String, VoidCallback) primary;
  final (String, VoidCallback) secondary;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white70, size: 64),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 24),
            FilledButton(onPressed: primary.$2, child: Text(primary.$1)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: secondary.$2,
              child: Text(secondary.$1, style: const TextStyle(color: Colors.white)),
            ),
          ]),
        ),
      );
}
