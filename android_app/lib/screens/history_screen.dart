import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/plastic_type.dart';
import '../models/scan_record.dart';
import '../services/scan_store.dart';
import '../widgets/common.dart';
import 'result_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';
  String _filter = 'All';

  static const _filters = ['All', ...polymerCodes, 'Non-plastic', 'Unsure'];

  bool _matches(ScanRecord s) {
    final label = scanMaterialLabel(s);
    if (_filter != 'All' && label != _filter) return false;
    if (_query.isEmpty) return true;
    final q = _query.toLowerCase();
    return s.itemName.toLowerCase().contains(q) || label.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ScanStore>();
    final items = store.scans.where(_matches).toList();
    final fmt = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(title: const Text('Scan history')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: SearchBar(
            hintText: 'Search scans',
            leading: const Icon(Icons.search),
            elevation: const WidgetStatePropertyAll(0),
            onChanged: (v) => setState(() => _query = v.trim()),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final f in _filters)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: Text(f),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: store.scans.isEmpty
              ? const EmptyState(icon: Icons.history, title: 'No scans yet', message: 'Your scans will appear here.')
              : items.isEmpty
                  ? const EmptyState(icon: Icons.search_off, title: 'No matches', message: 'Try another search or filter.')
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final s = items[i];
                        return Dismissible(
                          key: ValueKey(s.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                            child: const Icon(Icons.delete_outline),
                          ),
                          confirmDismiss: (_) => _confirm(context),
                          onDismissed: (_) => store.delete(s.id),
                          child: Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: ScanImage(path: s.imagePath, size: 52),
                              title: Text(s.itemName),
                              subtitle: Text(fmt.format(s.createdAt)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  s.plasticType == null ? Text(scanMaterialLabel(s)) : PolymerChip(code: s.plasticType!),
                                  if (s.syncStatus == SyncStatus.pending)
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Icon(Icons.cloud_upload_outlined, size: 14, semanticLabel: 'Not synced yet'),
                                    ),
                                ],
                              ),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultScreen(scanId: s.id))),
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ]),
    );
  }

  Future<bool?> _confirm(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete this scan?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
          ],
        ),
      );
}
