import 'dart:convert' as convert;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:mongo_mate/helpers/mongo.dart';
import 'package:mongo_mate/helpers/storage.dart';
import 'package:mongo_mate/helpers/toast.dart';
import 'package:mongo_mate/schemas/selectable.dart';
import 'package:mongo_mate/screens/editor.dart';
import 'package:mongo_mate/utilities/jsonconverter.dart';
import 'package:mongo_mate/widgets/app_background.dart';
import 'package:mongo_mate/widgets/confirmDialog.dart';
import 'package:mongo_mate/widgets/singleDocument.dart';

class DocumentScreen extends StatefulWidget {
  final dynamic name;
  const DocumentScreen({super.key, required this.name});

  @override
  _DocumentState createState() => _DocumentState();
}

class _DocumentState extends State<DocumentScreen> {
  final TextEditingController _filterQueryController = TextEditingController();
  final TextEditingController _sortQueryController = TextEditingController();
  bool isLoading = true;
  bool showDetails = false;
  int _pageSize = 20;
  late final PagingController<int, Selectable<Map<String, dynamic>>>
      _pagingController;
  final ScrollController _scrollController = ScrollController();
  double offset = 0.0;
  bool refreshRequired = false;
  List<String> _filterHistory = [];
  List<String> _sortHistory = [];
  List<String> _fieldSuggestions = [];

  static const List<String> _filterSnippets = [
    '{}',
    '{"_id": {"\$oid": ""}}',
    '{"createdAt": {"\$gte": {"\$date": "2026-01-01T00:00:00.000Z"}}}',
    '{"\$or": [{"field": "value"}]}',
    '{"\$and": [{"field": {"\$exists": true}}]}',
    '{"field": {"\$regex": "", "\$options": "i"}}',
    '{"field": {"\$in": ["A", "B"]}}',
  ];

  static const List<String> _sortSnippets = [
    '{"createdAt": "\$desc"}',
    '{"createdAt": "\$asc"}',
    '{"updatedAt": "\$desc"}',
    '{"name": "\$asc"}',
    '{"_id": "\$desc"}',
  ];

  String get _historyKeyBase {
    final collectionKey =
        widget.name.toString().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'query_history_$collectionKey';
  }

  void showDetailsHandler() {
    HapticFeedback.mediumImpact();
    setState(() {
      showDetails = !showDetails;
    });
  }

  Future<void> navigate(int index) async {
    HapticFeedback.mediumImpact();
    final items = _pagingController.items;
    dynamic shouldRefresh = await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => EditorScreen(
                collectionName: widget.name,
                item: (index == -1 || items == null)
                    ? null
                    : items.elementAt(index).item,
                itemId: (index == -1 || items == null)
                    ? null
                    : items.elementAt(index).item['_id'])));
    refreshRequired = shouldRefresh is bool && shouldRefresh;
    if (refreshRequired) {
      offset = _scrollController.offset;
      _pagingController.refresh();
    }
  }

  void select(int index, SelectType type) {
    final items = _pagingController.items;
    if (items == null || items.isEmpty) {
      return;
    }
    if (type == SelectType.tap) {
      if (items.any((element) => element.isSelected)) {
        setState(() {
          items.elementAt(index).select();
        });
      }
    } else if (type == SelectType.navigate) {
      if (items.any((element) => element.isSelected)) {
        setState(() {
          items.elementAt(index).select();
        });
      } else {
        HapticFeedback.lightImpact();
        navigate(index);
      }
    } else {
      HapticFeedback.mediumImpact();
      setState(() {
        items.elementAt(index).select();
      });
    }
  }

  bool isAnySelected() {
    final items = _pagingController.items;
    if (items != null) {
      return items.any((element) => element.isSelected);
    }
    return false;
  }

  Future<List<Selectable<Map<String, dynamic>>>> getDocuments(int page) async {
    return (await MongoHelper()
            .find(widget.name, page, _pageSize, filter(), sort()))
        .map((e) => Selectable(e))
        .toList();
  }

  Future<void> deleteHandler() async {
    HapticFeedback.mediumImpact();
    bool? delete = await showDialog(
        context: context,
        builder: (ctx) {
          return ConfirmDialog().build(context, 'Delete Document(s)',
              'Are you sure you want to delete?', 'Cancel', 'Delete');
        });
    if (delete == true) {
      setState(() {
        isLoading = true;
      });
      final items = _pagingController.items ?? [];
      Iterable<Future<bool>> futures = items
          .where((element) => element.isSelected)
          .map((q) => MongoHelper().deleteRecord(widget.name, q.item['_id']));
      await Future.wait(futures);
      setState(() {
        isLoading = false;
      });
      _pagingController.refresh();
    } else {
      final items = _pagingController.items;
      if (items == null) {
        return;
      }
      setState(() {
        for (var element in items) {
          element.isSelected = false;
        }
      });
    }
  }

  Map<String, dynamic>? filter() {
    try {
      if (_filterQueryController.value.text.trim().isEmpty) {
        return null;
      }
      return JsonConverter.decode(_filterQueryController.value.text);
    } catch (e) {
      ToastHelper.show("Invalid Filter Query: $e");
      return {};
    }
  }

  Map<String, Object>? sort() {
    try {
      if (_sortQueryController.value.text.trim().isEmpty) {
        return null;
      }
      return Map<String, Object>.from(
          JsonConverter.decode(_sortQueryController.value.text) as Map);
    } catch (e) {
      ToastHelper.show("Invalid Sort Query: $e");
      return {};
    }
  }

  Future<void> _loadQueryHistory() async {
    final storage = StorageHelper();
    final rawFilter = await storage.read('${_historyKeyBase}_filter');
    final rawSort = await storage.read('${_historyKeyBase}_sort');

    if (!mounted) return;

    setState(() {
      _filterHistory = _decodeHistory(rawFilter);
      _sortHistory = _decodeHistory(rawSort);
    });
  }

  Future<void> _loadFieldSuggestions({bool notify = false}) async {
    final fields = await MongoHelper().getCollectionFieldSuggestions(
      widget.name.toString(),
    );
    if (!mounted) return;
    setState(() {
      _fieldSuggestions = fields.take(40).toList();
    });
    if (notify) {
      ToastHelper.show(
          'Loaded ${_fieldSuggestions.length} field suggestion${_fieldSuggestions.length == 1 ? '' : 's'}');
    }
  }

  List<String> _decodeHistory(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (convert.jsonDecode(raw) as List<dynamic>).cast<String>();
      return list.where((e) => e.trim().isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _registerQueryHistory({
    required String type,
    required String value,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final target = type == 'filter' ? _filterHistory : _sortHistory;
    target.remove(trimmed);
    target.insert(0, trimmed);
    if (target.length > 8) {
      target.removeRange(8, target.length);
    }

    setState(() {});

    await StorageHelper().write(
      '${_historyKeyBase}_$type',
      convert.jsonEncode(target),
    );
  }

  void _insertInController(TextEditingController controller, String snippet) {
    final value = controller.value;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;
    final text = value.text.replaceRange(start, end, snippet);
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + snippet.length),
    );
  }

  List<String> _fieldSnippets(String type) {
    if (_fieldSuggestions.isEmpty) return const [];
    return _fieldSuggestions
        .take(12)
        .map((field) => type == 'sort'
            ? '{"$field": "\$desc"}'
            : '{"$field": {"\$exists": true}}')
        .toList();
  }

  Future<void> _openQueryEditor({
    required String title,
    required String type,
    required TextEditingController controller,
    required List<String> snippets,
  }) async {
    HapticFeedback.mediumImpact();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: StatefulBuilder(
            builder: (context, setLocalState) {
              final history = type == 'filter' ? _filterHistory : _sortHistory;
              final fieldSnippets = _fieldSnippets(type);
              final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

              return SafeArea(
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + keyboardInset),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(title,
                                style: Theme.of(context).textTheme.titleLarge),
                          ),
                          // IconButton(
                          //   tooltip: 'Dismiss keyboard',
                          //   onPressed: () =>
                          //       FocusManager.instance.primaryFocus?.unfocus(),
                          //   icon: const Icon(
                          //       CupertinoIcons.keyboard_chevron_compact_down),
                          // ),
                          // IconButton(
                          //   onPressed: () => Navigator.pop(context),
                          //   icon: const Icon(CupertinoIcons.clear_circled),
                          // ),
                        ],
                      ),
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () =>
                              FocusManager.instance.primaryFocus?.unfocus(),
                          child: ListView(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            children: [
                              TextField(
                                controller: controller,
                                maxLines: 8,
                                textInputAction: TextInputAction.done,
                                onTapOutside: (_) => FocusManager
                                    .instance.primaryFocus
                                    ?.unfocus(),
                                decoration: InputDecoration(
                                  hintText: type == 'filter'
                                      ? 'e.g {"name": "john"}'
                                      : 'e.g {"createdAt": "\$desc"}',
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Snippets',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: snippets
                                    .map((snippet) => ActionChip(
                                          label: Text(
                                            snippet,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          onPressed: () {
                                            _insertInController(
                                                controller, snippet);
                                            setLocalState(() {});
                                          },
                                        ))
                                    .toList(),
                              ),
                              if (fieldSnippets.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Fields',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: fieldSnippets
                                      .map((snippet) => ActionChip(
                                            label: Text(
                                              snippet,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onPressed: () {
                                              _insertInController(
                                                  controller, snippet);
                                              setLocalState(() {});
                                            },
                                          ))
                                      .toList(),
                                ),
                              ],
                              if (history.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Recent',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: history
                                      .map((entry) => InputChip(
                                            label: Text(
                                              entry,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            onPressed: () {
                                              controller.text = entry;
                                              setLocalState(() {});
                                            },
                                          ))
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                              onPressed: () {
                                FocusManager.instance.primaryFocus?.unfocus();
                                controller.clear();
                                _pagingController.refresh();
                                Navigator.pop(context);
                              },
                              child: const Text('Clear')),
                          const SizedBox(width: 6),
                          FilledButton(
                              onPressed: () async {
                                FocusManager.instance.primaryFocus?.unfocus();
                                await _registerQueryHistory(
                                  type: type,
                                  value: controller.text,
                                );
                                _pagingController.refresh();
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                              child: const Text('Apply')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _clearSelection() {
    final items = _pagingController.items;
    if (items == null || items.isEmpty) return;
    setState(() {
      for (final item in items) {
        item.isSelected = false;
      }
    });
  }

  void _clearQueries() {
    _filterQueryController.clear();
    _sortQueryController.clear();
    _pagingController.refresh();
  }

  void _copyQueryBundle() {
    final payload = {
      'filter': _filterQueryController.text.trim().isEmpty
          ? null
          : _filterQueryController.text.trim(),
      'sort': _sortQueryController.text.trim().isEmpty
          ? null
          : _sortQueryController.text.trim(),
      'pageSize': _pageSize,
    };
    Clipboard.setData(
      ClipboardData(text: convert.jsonEncode(payload)),
    );
    ToastHelper.show('Query settings copied');
  }

  void _showFieldSuggestionPreview() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Field Suggestions (${_fieldSuggestions.length})',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'These are inferred from sampled documents in this collection and are used in query snippet chips.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (_fieldSuggestions.isEmpty)
                  const Text('No suggestions loaded yet.')
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _fieldSuggestions
                        .map((field) => Chip(label: Text(field)))
                        .toList(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _pagingController = PagingController(
      getNextPageKey: (state) {
        final pages = state.pages;
        final keys = state.keys;
        if (pages == null || pages.isEmpty || keys == null || keys.isEmpty) {
          return 0;
        }
        final lastPage = pages.last;
        if (lastPage.length < _pageSize) {
          return null;
        }
        return keys.last + lastPage.length;
      },
      fetchPage: getDocuments,
    );
    _pagingController.addListener(_onPagingStateChanged);
    _loadQueryHistory();
    _loadFieldSuggestions();
  }

  @override
  void dispose() {
    _pagingController.removeListener(_onPagingStateChanged);
    _pagingController.dispose();
    _scrollController.dispose();
    _filterQueryController.dispose();
    _sortQueryController.dispose();
    super.dispose();
  }

  void _onPagingStateChanged() {
    final status = _pagingController.status;
    if (!mounted) {
      return;
    }
    setState(() {
      isLoading = status == PagingStatus.loadingFirstPage;
      if (refreshRequired && status == PagingStatus.completed) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(offset);
        }
        refreshRequired = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _filterQueryController.text.trim().isNotEmpty;
    final hasSort = _sortQueryController.text.trim().isNotEmpty;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Page size',
            icon: const Icon(CupertinoIcons.slider_horizontal_3),
            onSelected: (value) {
              if (_pageSize == value) return;
              setState(() {
                _pageSize = value;
              });
              _pagingController.refresh();
            },
            itemBuilder: (context) => [20, 50, 100]
                .map(
                  (size) => PopupMenuItem(
                    value: size,
                    child: Row(
                      children: [
                        if (_pageSize == size)
                          const Icon(CupertinoIcons.check_mark, size: 16)
                        else
                          const SizedBox(width: 16),
                        const SizedBox(width: 8),
                        Text('Page size $size'),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: const Icon(CupertinoIcons.ellipsis_circle),
            onSelected: (value) {
              switch (value) {
                case 'clear':
                  _clearQueries();
                  break;
                case 'copy':
                  _copyQueryBundle();
                  break;
                case 'fields':
                  _loadFieldSuggestions(notify: true);
                  break;
                case 'preview_fields':
                  _showFieldSuggestionPreview();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'clear', child: Text('Clear filter & sort')),
              PopupMenuItem(value: 'copy', child: Text('Copy query settings')),
              PopupMenuItem(
                  value: 'fields', child: Text('Refresh field suggestions')),
              PopupMenuItem(
                  value: 'preview_fields',
                  child: Text('Show field suggestions')),
            ],
          ),
          IconButton(
              onPressed: showDetailsHandler,
              icon: showDetails
                  ? const Icon(CupertinoIcons.eye_slash)
                  : const Icon(CupertinoIcons.eye)),
          IconButton(
            onPressed: () => _openQueryEditor(
              title: 'Sort Query',
              type: 'sort',
              controller: _sortQueryController,
              snippets: _sortSnippets,
            ),
            icon: Icon(
              CupertinoIcons.line_horizontal_3_decrease_circle,
              color: hasSort ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          IconButton(
            onPressed: () => _openQueryEditor(
              title: 'Filter Query',
              type: 'filter',
              controller: _filterQueryController,
              snippets: _filterSnippets,
            ),
            icon: Icon(
              CupertinoIcons.search,
              color: hasFilter ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          isAnySelected()
              ? IconButton(
                  onPressed: deleteHandler,
                  icon: const Icon(CupertinoIcons.delete))
              : IconButton(
                  onPressed: () => navigate(-1),
                  icon: const Icon(CupertinoIcons.add)),
          if (isAnySelected())
            IconButton(
              onPressed: _clearSelection,
              tooltip: 'Clear selection',
              icon: const Icon(CupertinoIcons.clear_circled),
            ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: Center(
            child: RefreshIndicator(
                onRefresh: () async => _pagingController.refresh(),
                child: CupertinoScrollbar(
                    controller: _scrollController,
                    child:
                        PagingListener<int, Selectable<Map<String, dynamic>>>(
                            controller: _pagingController,
                            builder: (context, state, fetchNextPage) =>
                                PagedListView<int,
                                    Selectable<Map<String, dynamic>>>.separated(
                                  state: state,
                                  fetchNextPage: fetchNextPage,
                                  scrollController: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 20, horizontal: 15),
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 10),
                                  builderDelegate: PagedChildBuilderDelegate<
                                          Selectable<Map<String, dynamic>>>(
                                      firstPageProgressIndicatorBuilder:
                                          (context) => const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2.2),
                                              ),
                                      noItemsFoundIndicatorBuilder: (context) =>
                                          Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  CupertinoIcons.doc_fill,
                                                  size: 84,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                ),
                                                const SizedBox(
                                                  height: 20,
                                                ),
                                                Text(
                                                  'No document found',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium,
                                                ),
                                              ],
                                            ),
                                          ),
                                      itemBuilder: (context, data, index) {
                                        return SingleDocument(
                                            index,
                                            data,
                                            isAnySelected(),
                                            select,
                                            showDetails,
                                            showDetailsHandler);
                                      }),
                                )))),
          ),
        ),
      ),
    );
  }
}
