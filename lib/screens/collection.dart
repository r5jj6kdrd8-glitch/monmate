import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mongo_mate/helpers/mongo.dart';
import 'package:mongo_mate/schemas/collection.dart';
import 'package:mongo_mate/schemas/selectable.dart';
import 'package:mongo_mate/screens/document.dart';
import 'package:mongo_mate/widgets/adBanner.dart';
import 'package:mongo_mate/widgets/app_background.dart';
import 'package:mongo_mate/widgets/confirmDialog.dart';
import 'package:mongo_mate/widgets/singleCollection.dart';

class CollectionScreen extends StatefulWidget {
  final String name;
  const CollectionScreen({super.key, required this.name});

  @override
  _CollectionState createState() => _CollectionState();
}

class _CollectionState extends State<CollectionScreen> {
  bool isLoading = false;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  List<Selectable<Collection>> collections = <Selectable<Collection>>[];

  Future<void> getRecordCounts() async {
    for (final selectable in collections) {
      final count = await MongoHelper().getRecordCount(selectable.item.name);
      if (!mounted) return;
      setState(() {
        // Keep loading state when count cannot be retrieved.
        selectable.item.count = count >= 0 ? count : -2;
      });
    }
  }

  Future<void> getCollections() async {
    setState(() => isLoading = true);
    final names = await MongoHelper().getCollectionNames();
    setState(() {
      collections = names.map((e) => Selectable(Collection(e))).toList();
      isLoading = false;
    });
    getRecordCounts();
  }

  void selectHandler(int index, SelectType type) {
    if (type == SelectType.tap) {
      if (collections.any((element) => element.isSelected)) {
        setState(() => collections[index].select());
      } else {
        HapticFeedback.lightImpact();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                DocumentScreen(name: collections[index].item.name),
          ),
        );
      }
    } else {
      HapticFeedback.mediumImpact();
      setState(() => collections[index].select());
    }
  }

  Future<void> create(String collectionName) async {
    setState(() => isLoading = true);
    await MongoHelper().createCollection(collectionName);
    setState(() => isLoading = false);
    getCollections();
  }

  Future<void> createHandler() async {
    HapticFeedback.mediumImpact();
    _name.clear();

    showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final isNameEmpty = _name.text.isEmpty;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                18,
                8,
                18,
                MediaQuery.of(context).viewInsets.bottom + 18,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Collection',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _name,
                    decoration:
                        const InputDecoration(labelText: 'Collection name'),
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: isNameEmpty
                            ? null
                            : () {
                                create(_name.text);
                                Navigator.pop(context);
                              },
                        child: const Text('Create'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> deleteHandler() async {
    HapticFeedback.mediumImpact();
    final delete = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return ConfirmDialog().build(context, 'Delete Collection(s)',
            'Are you sure you want to delete?', 'Cancel', 'Delete');
      },
    );

    if (delete == true) {
      setState(() => isLoading = true);
      final futures = collections
          .where((element) => element.isSelected)
          .map((q) => MongoHelper().deleteCollection(q.item.name));
      await Future.wait(futures);
      setState(() => isLoading = false);
      getCollections();
    } else {
      setState(() {
        for (final element in collections) {
          element.isSelected = false;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    getCollections();
  }

  @override
  void dispose() {
    _name.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = collections.any((element) => element.isSelected);
    final query = _searchController.text.trim().toLowerCase();
    final visibleCollections = query.isEmpty
        ? collections
        : collections
            .where((c) => c.item.name.toLowerCase().contains(query))
            .toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          hasSelection
              ? IconButton(
                  onPressed: deleteHandler,
                  icon: const Icon(CupertinoIcons.delete),
                )
              : IconButton(
                  onPressed: createHandler,
                  icon: const Icon(CupertinoIcons.add),
                )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: getCollections,
            child: collections.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 120),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: GlassPanel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                CupertinoIcons.folder_solid,
                                size: 74,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No collections found',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                        child: CupertinoSearchTextField(
                          controller: _searchController,
                          placeholder: 'Search collections',
                        ),
                      ),
                      Expanded(
                        child: visibleCollections.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  const SizedBox(height: 80),
                                  Center(
                                    child: Text(
                                      'No collections match your search',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                ],
                              )
                            : CupertinoScrollbar(
                                child: ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 20, horizontal: 12),
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 2),
                                  itemCount: visibleCollections.length + 1,
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return const AdBanner(bottomSpacing: 12);
                                    }

                                    final selectable =
                                        visibleCollections[index - 1];
                                    final originalIndex =
                                        collections.indexOf(selectable);

                                    return SingleCollection(
                                      index: originalIndex,
                                      selectable: selectable,
                                      isAnySelected: hasSelection,
                                      onClick: selectHandler,
                                    );
                                  },
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
