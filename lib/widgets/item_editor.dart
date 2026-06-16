import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/transaction.dart' as txm;
import '../theme/app_theme.dart';

/// Editable list of optional receipt items (name + price) for a transaction.
///
/// Items are an informational breakdown only — they do not change the
/// transaction's total amount. Emits the current list through [onChanged].
class ItemListEditor extends StatefulWidget {
  final List<txm.TxItem> initial;
  final ValueChanged<List<txm.TxItem>> onChanged;

  const ItemListEditor({
    super.key,
    this.initial = const [],
    required this.onChanged,
  });

  @override
  State<ItemListEditor> createState() => _ItemListEditorState();
}

class _ItemRow {
  final TextEditingController name;
  final TextEditingController price;
  _ItemRow({String n = '', String p = ''})
      : name = TextEditingController(text: n),
        price = TextEditingController(text: p);
  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _ItemListEditorState extends State<ItemListEditor> {
  late final List<_ItemRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.initial
        .map((i) => _ItemRow(
            n: i.name, p: i.price == 0 ? '' : i.price.toStringAsFixed(2)))
        .toList();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _emit() {
    final items = <txm.TxItem>[];
    for (final r in _rows) {
      final name = r.name.text.trim();
      if (name.isEmpty) continue;
      items.add(txm.TxItem(
        name: name,
        price: double.tryParse(r.price.text.trim()) ?? 0,
      ));
    }
    widget.onChanged(items);
  }

  void _add() {
    setState(() => _rows.add(_ItemRow()));
  }

  void _remove(int i) {
    setState(() {
      _rows[i].dispose();
      _rows.removeAt(i);
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            'ITEMS (OPTIONAL)',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: AppTheme.midGray,
            ),
          ),
        ),
        for (var i = 0; i < _rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _rows[i].name,
                    onChanged: (_) => _emit(),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: 'Item',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _rows[i].price,
                    onChanged: (_) => _emit(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixText: '\$ ',
                      hintText: '0.00',
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.remove_circle_outline_rounded,
                      color: AppTheme.midGray, size: 20),
                  onPressed: () => _remove(i),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Add item',
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.orange,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ),
      ],
    );
  }
}
