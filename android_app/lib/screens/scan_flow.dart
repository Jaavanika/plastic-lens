import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/classification.dart';
import '../models/scan_record.dart';
import '../services/auth_service.dart';
import '../services/classifier_service.dart';
import '../services/enrich_service.dart';
import '../services/material_repository.dart';
import '../services/scan_store.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

const _maxBytes = 20 * 1024 * 1024;
const _allowedExt = {'.jpg', '.jpeg', '.png', '.webp', '.heic', '.heif'};

/// Returns an error message, or null when the file looks usable.
String? validateImageFile(String path) {
  final f = File(path);
  if (!f.existsSync()) return 'The image could not be found.';
  final lower = path.toLowerCase();
  if (!_allowedExt.any(lower.endsWith)) {
    return 'Unsupported file type. Please choose a JPG or PNG photo.';
  }
  final len = f.lengthSync();
  if (len == 0) return 'The image file is empty.';
  if (len > _maxBytes) return 'The image is larger than 20 MB.';
  return null;
}

Future<void> pickFromGallery(BuildContext context) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 92);
  } catch (e) {
    if (context.mounted) showSnack(context, 'Could not open the gallery: $e');
    return;
  }
  if (file == null || !context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PreviewScreen(imagePath: file!.path, fromCamera: false)));
}

/// Copies a picked/captured photo into app storage so it survives cache clears.
Future<String> persistImage(String sourcePath, String scanId) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final scans = Directory('${dir.path}/scans');
    await scans.create(recursive: true);
    final ext = sourcePath.contains('.') ? sourcePath.substring(sourcePath.lastIndexOf('.')) : '.jpg';
    final dest = '${scans.path}/$scanId$ext';
    await File(sourcePath).copy(dest);
    return dest;
  } catch (_) {
    return sourcePath; // keep the original if app storage is unavailable
  }
}

/// Preview with Retake / Use photo; runs the classifier on confirm.
class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key, required this.imagePath, required this.fromCamera});
  final String imagePath;
  final bool fromCamera;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = validateImageFile(widget.imagePath);
  }

  Future<void> _analyze() async {
    setState(() => _busy = true);
    final classifier = context.read<ClassifierService>();
    final store = context.read<ScanStore>();
    final materials = context.read<MaterialRepository>();
    final enrich = context.read<EnrichService>();
    final auth = context.read<AuthService>();
    try {
      // The online second opinion runs alongside the on-device model and
      // is simply skipped when offline, signed out or failing.
      final Future<EnrichResult?> online = enrich.enabled && auth.signedIn
          ? auth.idToken().then((t) => t == null ? null : enrich.enrich(widget.imagePath, t)).catchError((Object _) => null)
          : Future.value(null);
      final result = await classifier.classify(widget.imagePath);
      final id = const Uuid().v4();
      final stored = await persistImage(widget.imagePath, id);
      final scan = buildScan(id, stored, result, materials);
      final second = await online;
      if (second != null) applySecondOpinion(scan, second, materials);
      await store.save(scan);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ResultScreen(scanId: id, justScanned: true, probabilities: result.ranked)),
      );
    } on ClassifierException catch (e) {
      setState(() {
        _busy = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _busy = false;
        _error = 'Something went wrong while analysing the photo. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Preview')),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Stack(fit: StackFit.expand, children: [
                ScanImage(path: widget.imagePath, radius: 20, fit: BoxFit.contain),
                if (_busy)
                  Container(
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(height: 16),
                      Text('Analysing material…', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ]),
                  ),
              ]),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.refresh),
                  label: Text(widget.fromCamera ? 'Retake' : 'Choose another'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || validateImageFile(widget.imagePath) != null ? null : _analyze,
                  icon: const Icon(Icons.check),
                  label: const Text('Use photo'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Merge the online check into a scan (identification spec §6): it names the object,
/// and a printed resin code beats the classifier; disagreements are shown.
void applySecondOpinion(ScanRecord scan, EnrichResult r, MaterialRepository materials) {
  scan
    ..itemName = r.objectName
    ..llmUsed = true;
  final printed = r.printedPolymer;
  if (printed != null && printed != scan.plasticType) {
    final model = scan.plasticType == null
        ? 'the on-device model was unsure'
        : 'the on-device model suggested ${scan.plasticType} (${(scan.confidence * 100).round()} %)';
    scan
      ..secondOpinion = 'A printed resin code ♲${r.resinCode} ($printed) was read in the photo; $model.'
      ..plasticType = printed
      ..resinCode = r.resinCode
      ..containsPlastic = true;
  } else if (r.resinCode == 7) {
    scan.secondOpinion = 'A printed resin code ♲7 (other plastics) was read in the photo. PlasticLens does not classify code 7.';
  } else if (printed == null && r.likelyPolymer != null && r.likelyPolymer != scan.plasticType) {
    scan.secondOpinion = 'The online check thinks this may be ${r.likelyPolymer}. Check the resin code to be sure.';
  }
}

ScanRecord buildScan(String id, String imagePath, Classification c, MaterialRepository materials) {
  final polymer = c.polymer;
  return ScanRecord(
    id: id,
    itemName: switch (c.state) {
      ResultState.nonPlastic => 'Non-plastic item',
      _ when polymer != null => '$polymer item',
      _ => 'Unknown item',
    },
    containsPlastic: c.containsPlastic,
    plasticType: polymer,
    resinCode: materials.byCode(polymer)?.resinCode,
    confidence: c.confidence,
    state: c.state,
    modelVersion: c.modelVersion,
    imagePath: imagePath,
    createdAt: DateTime.now(),
  );
}
