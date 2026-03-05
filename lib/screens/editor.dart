import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mongo_mate/helpers/mongo.dart';
import 'package:mongo_mate/helpers/toast.dart';
import 'package:mongo_mate/utilities/jsonconverter.dart';
import 'package:mongo_mate/widgets/app_background.dart';
import 'package:mongo_mate/widgets/confirmDialog.dart';

class EditorScreen extends StatefulWidget {
  final String collectionName;
  final dynamic itemId;
  final dynamic item;
  const EditorScreen(
      {super.key, required this.collectionName, this.itemId, this.item});

  @override
  _EditState createState() => _EditState();
}

String jsonEncode(dynamic item) {
  return JsonConverter.encode(item);
}

dynamic jsonDecode(String json) {
  return JsonConverter.decode(json);
}

class _EditState extends State<EditorScreen> {
  bool isLoading = false;
  final TextEditingController _jsonController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _editorSnippets = [
    '{"field": "value"}',
    '"_id": {"\$oid": ""}',
    '"createdAt": {"\$date": "2026-01-01T00:00:00.000Z"}',
    '"value": {"\$numberDecimal": "0.0"}',
    '"uuid": {"\$uuid": ""}',
    '"tags": ["A", "B"]',
    '"meta": {"enabled": true}',
  ];

  Future<void> encoder() async {
    try {
      String encoded = widget.itemId == null
          ? '{\n\n}'
          : await compute(jsonEncode, widget.item);
      setState(() {
        _jsonController.value = TextEditingValue(
          text: encoded,
          selection: const TextSelection.collapsed(offset: 0),
        );
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    } catch (e) {
      setState(() {
        _jsonController.value = const TextEditingValue(
          text: '{\n\n}',
          selection: TextSelection.collapsed(offset: 0),
        );
        ToastHelper.show("Encode Error. $e");
      });
    }
  }

  Future<void> savehandler() async {
    bool? ok = await showDialog(
        context: context,
        builder: (ctx) {
          return ConfirmDialog().build(context, 'Save document',
              'Are you sure you want to save it?', 'Cancel', 'Save');
        });
    if (ok == true) {
      await save();
    }
  }

  Future<void> save() async {
    final navigator = Navigator.of(context);
    setState(() {
      isLoading = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    if (_jsonController.value.text.isNotEmpty) {
      try {
        dynamic obj = await compute(jsonDecode, _jsonController.value.text);
        bool result = false;
        if (widget.itemId != null) {
          obj.removeWhere((key, value) => key == '_id');
          result = await MongoHelper()
              .updateRecord(widget.collectionName, widget.itemId, obj);
        } else {
          result = await MongoHelper().insertRecord(widget.collectionName, obj);
        }
        if (result) {
          navigator.pop(true);
        }
      } catch (e) {
        ToastHelper.show("Invalid JSON. $e");
      }
    } else {
      ToastHelper.show("Document is empty.");
    }
    setState(() {
      isLoading = false;
    });
  }

  void copy() {
    var jsonText = _jsonController.value.text;
    if (jsonText.isNotEmpty) {
      HapticFeedback.mediumImpact();
      Clipboard.setData(ClipboardData(text: jsonText));
      ToastHelper.show('JSON copied to clipboard');
    }
  }

  Future<void> validate() async {
    try {
      await compute(jsonDecode, _jsonController.value.text);
      ToastHelper.show('JSON/BSON is valid');
    } catch (e) {
      ToastHelper.show('Validation failed: $e');
    }
  }

  Future<void> formatPretty() async {
    try {
      final obj = await compute(jsonDecode, _jsonController.value.text);
      final pretty = await compute(jsonEncode, obj);
      _jsonController.text = pretty;
      ToastHelper.show('Formatted');
    } catch (e) {
      ToastHelper.show('Format failed: $e');
    }
  }

  void _insertSnippet(String snippet) {
    final value = _jsonController.value;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;
    final text = value.text.replaceRange(start, end, snippet);

    _jsonController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
  }

  @override
  void initState() {
    super.initState();
    encoder();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.item == null ? 'New' : 'Edit'),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            onPressed: formatPretty,
            tooltip: 'Format',
            icon: const Icon(CupertinoIcons.textformat_size),
          ),
          IconButton(
            onPressed: validate,
            tooltip: 'Validate',
            icon: const Icon(CupertinoIcons.checkmark_shield),
          ),
          IconButton(
            onPressed: copy,
            icon: const Icon(CupertinoIcons.doc_on_doc),
            tooltip: 'Copy',
          ),
          IconButton(
              onPressed: savehandler,
              icon: const Icon(CupertinoIcons.check_mark)),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              children: [
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _editorSnippets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final snippet = _editorSnippets[index];
                      return ActionChip(
                        label: Text(snippet, overflow: TextOverflow.ellipsis),
                        onPressed: () => _insertSnippet(snippet),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: GlassPanel(
                    padding: const EdgeInsets.all(0),
                    child: CupertinoScrollbar(
                      controller: _scrollController,
                      child: TextField(
                        expands: true,
                        minLines: null,
                        maxLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        scrollController: _scrollController,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        scrollPhysics: const AlwaysScrollableScrollPhysics(),
                        decoration: InputDecoration(
                          fillColor: Theme.of(context)
                              .colorScheme
                              .surface
                              .withValues(alpha: 0.14),
                          filled: true,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.fromLTRB(14, 12, 14, 12),
                        ),
                        style: const TextStyle(height: 1.35),
                        controller: _jsonController,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
