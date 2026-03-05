import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mongo_mate/helpers/mongo.dart';
import 'package:mongo_mate/helpers/storage.dart';
import 'package:mongo_mate/helpers/toast.dart';
import 'package:mongo_mate/schemas/connection.dart';
import 'package:mongo_mate/schemas/selectable.dart';
import 'package:mongo_mate/screens/collection.dart';
import 'package:mongo_mate/widgets/adBanner.dart';
import 'package:mongo_mate/widgets/app_background.dart';
import 'package:mongo_mate/widgets/confirmDialog.dart';
import 'package:mongo_mate/widgets/remove_ads_cta.dart';
import 'package:mongo_mate/widgets/singleConnection.dart';
import 'package:mongo_mate/widgets/subscription_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isLoading = false;
  final TextEditingController _name = TextEditingController();
  final TextEditingController _uri = TextEditingController();
  List<Selectable<Connection>> connections = <Selectable<Connection>>[];

  Future<void> saveConnections() async {
    final json =
        jsonEncode(connections.map((connection) => connection.item).toList());
    StorageHelper().write('connections', json);
  }

  void reorderHandler(int oldIndex, int newIndex) {
    if (oldIndex == 0 || newIndex == 0) return;

    setState(() {
      if (oldIndex > 0) oldIndex -= 1;
      if (newIndex > 0) newIndex -= 1;
      newIndex -= oldIndex < newIndex ? 1 : 0;

      final Selectable<Connection> item = connections.removeAt(oldIndex);
      connections.insert(newIndex, item);
    });

    saveConnections();
  }

  Future<void> connectAndGo(int index) async {
    setState(() => isLoading = true);
    final connected = await MongoHelper()
        .connect(connections[index].item.getConnectionString());
    setState(() => isLoading = false);

    if (connected && mounted) {
      HapticFeedback.lightImpact();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              CollectionScreen(name: connections[index].item.name),
        ),
      );
    }
  }

  void add(String name, String uri) {
    if (name.isNotEmpty && uri.isNotEmpty) {
      setState(() => connections.add(Selectable(Connection(name, uri))));
      saveConnections();
    }
  }

  void update(int index, String name, String uri) {
    if (index >= 0 &&
        connections.length > index &&
        name.isNotEmpty &&
        uri.isNotEmpty) {
      setState(() {
        connections[index] = Selectable(Connection(name, uri));
      });
      saveConnections();
    }
  }

  void select(int index, SelectType type) {
    if (type == SelectType.tap) {
      if (connections.any((element) => element.isSelected)) {
        setState(() => connections[index].select());
      } else {
        connectAndGo(index);
      }
    } else {
      HapticFeedback.mediumImpact();
      setState(() => connections[index].select());
    }
  }

  Future<void> openUrl(Uri url) async {
    if (!await launchUrl(url)) {
      ToastHelper.show('Could not launch $url');
    }
  }

  Future<void> deleteHandler() async {
    HapticFeedback.mediumImpact();
    final delete = await showDialog<bool>(
      context: context,
      builder: (ctx) => ConfirmDialog().build(
        context,
        'Delete Connection(s)',
        'Are you sure you want to delete?',
        'Cancel',
        'Delete',
      ),
    );

    if (delete == true) {
      setState(() {
        connections.removeWhere((element) => element.isSelected);
      });
      saveConnections();
    } else {
      setState(() {
        for (final element in connections) {
          element.isSelected = false;
        }
      });
    }
  }

  Future<void> manageHandler(BuildContext context, String mode) async {
    int index = -1;
    _name.clear();
    _uri.clear();

    if (mode == 'edit') {
      for (int i = 0; i < connections.length; i++) {
        if (connections[i].isSelected) {
          index = i;
          _name.text = connections[i].item.name;
          _uri.text = connections[i].item.uri;
          break;
        }
      }
    }

    await showModalBottomSheet<void>(
      isScrollControlled: true,
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final isNameEmpty = _name.text.isEmpty;
            final isUriEmpty = _uri.text.isEmpty;

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
                    mode == 'add' ? 'New Connection' : 'Edit Connection',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Use a MongoDB URI with credentials and optional database name.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      hintText: 'e.g Production Cluster',
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _uri,
                    decoration: const InputDecoration(
                      labelText: 'URI',
                      hintText: 'mongodb+srv://user:pass@host/db',
                    ),
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
                        onPressed: isNameEmpty || isUriEmpty
                            ? null
                            : () {
                                if (mode == 'add') {
                                  add(_name.text, _uri.text);
                                } else {
                                  update(index, _name.text, _uri.text);
                                }
                                Navigator.pop(context);
                                _uri.clear();
                                _name.clear();
                              },
                        child: Text(mode == 'add' ? 'Add' : 'Save'),
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

    if (index >= 0) {
      setState(() {
        connections[index].isSelected = false;
      });
    }
  }

  Future<void> manageAbout(BuildContext context) async {
    final rootContext = context;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.45,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: GlassPanel(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MonMate',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    Text('Version 1.1',
                        style: Theme.of(context).textTheme.bodyMedium),
                    Text('© 2026',
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 12),
                    Text(
                      'MonMate helps you manage MongoDB on iOS with a touch-first interface for connections, collections, and documents.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 14),
                    _buildSettingsTile(
                      context: context,
                      title: 'Subscription',
                      subtitle: 'Remove ads and manage plan',
                      icon: CupertinoIcons.sparkles,
                      onTap: () {
                        Navigator.pop(context);
                        SubscriptionSheet.show(rootContext);
                      },
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsTile(
                      context: context,
                      title: 'Privacy Policy',
                      subtitle: 'Read how data and permissions are handled',
                      icon: CupertinoIcons.shield_fill,
                      onTap: () => openUrl(
                        Uri.parse('https://pahlavan.co.uk/monmate/privacy'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsTile(
                      context: context,
                      title: 'Website',
                      subtitle: 'Open MonMate website',
                      icon: CupertinoIcons.globe,
                      onTap: () =>
                          openUrl(Uri.parse('https://pahlavan.co.uk/monmate')),
                    ),
                    const SizedBox(height: 10),
                    _buildSettingsTile(
                      context: context,
                      title: 'Licensing',
                      subtitle: 'App license, attributions, and OSS licenses',
                      icon: CupertinoIcons.doc_text_fill,
                      onTap: () {
                        Navigator.pop(context);
                        _openLicensingPage(rootContext);
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSettingsTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GlassPanel(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(CupertinoIcons.chevron_right, size: 18),
        onTap: onTap,
      ),
    );
  }

  Future<void> _openLicensingPage(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: const Text('Licensing'),
          ),
          body: AppBackground(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                children: [
                  GlassPanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(CupertinoIcons.doc_plaintext),
                      title: const Text('GNU General Public License v3.0'),
                      subtitle: const Text('MonMate is licensed under GPL-3.0'),
                      trailing:
                          const Icon(CupertinoIcons.arrow_up_right_square),
                      onTap: () => openUrl(
                        Uri.parse(
                            'https://www.gnu.org/licenses/gpl-3.0.en.html'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                          CupertinoIcons.chevron_left_slash_chevron_right),
                      title: const Text('Source Code'),
                      subtitle: const Text('GitHub repository for MonMate'),
                      trailing:
                          const Icon(CupertinoIcons.arrow_up_right_square),
                      onTap: () => openUrl(
                        Uri.parse('https://github.com/Pahlavan-Ltd/monmate'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(CupertinoIcons.square_list),
                      title: const Text('Third-Party OSS Licenses'),
                      subtitle:
                          const Text('View package licenses used by this app'),
                      trailing: const Icon(CupertinoIcons.chevron_right),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              final base = Theme.of(context);
                              return Theme(
                                data: base.copyWith(
                                  scaffoldBackgroundColor:
                                      base.colorScheme.surface,
                                  appBarTheme: base.appBarTheme.copyWith(
                                    backgroundColor: base.colorScheme.surface,
                                    elevation: 0,
                                    scrolledUnderElevation: 0,
                                    foregroundColor: base.colorScheme.onSurface,
                                  ),
                                ),
                                child: const LicensePage(
                                  applicationName: 'MonMate',
                                  applicationVersion: '1.1.0',
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  GlassPanel(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(CupertinoIcons.heart),
                      title: const Text('Credits'),
                      subtitle: const Text('Inspired by Mondroid'),
                      trailing:
                          const Icon(CupertinoIcons.arrow_up_right_square),
                      onTap: () => openUrl(
                        Uri.parse('https://github.com/vedfi/mondroid'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> getConnections() async {
    final data = await StorageHelper().read('connections');
    if (data == null) return;

    final savedConnections = jsonDecode(data) as List<dynamic>;
    setState(() {
      connections = savedConnections
          .map((e) => Selectable(Connection.fromJson(e)))
          .toList(growable: true);
    });
  }

  @override
  void initState() {
    super.initState();
    getConnections();
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount =
        connections.where((element) => element.isSelected).length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'MonMate',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: 'Avenir Next',
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
        ),
        leading: IconButton(
          onPressed: () => manageAbout(context),
          icon: const Icon(CupertinoIcons.info_circle),
        ),
        actions: [
          if (isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
              ),
            ),
          if (selectedCount == 0)
            IconButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                manageHandler(context, 'add');
              },
              icon: const Icon(CupertinoIcons.add),
            )
          else if (selectedCount == 1)
            IconButton(
              onPressed: () {
                HapticFeedback.mediumImpact();
                manageHandler(context, 'edit');
              },
              icon: const Icon(CupertinoIcons.pencil),
            ),
          if (selectedCount > 0)
            IconButton(
              onPressed: deleteHandler,
              icon: const Icon(CupertinoIcons.delete),
            ),
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: connections.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: GlassPanel(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            CupertinoIcons.cube_box_fill,
                            color: Theme.of(context).colorScheme.primary,
                            size: 78,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No connections yet',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Tap + to add your first MongoDB deployment.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: ReorderableListView(
                    onReorder: reorderHandler,
                    children: List<Widget>.generate(
                      connections.length + 1,
                      (index) {
                        if (index == 0) {
                          return Column(
                            key: const ValueKey('ad-banner'),
                            children: [
                              RemoveAdsCta(
                                onPressed: () =>
                                    SubscriptionSheet.show(context),
                              ),
                              const SizedBox(height: 10),
                              const AdBanner(bottomSpacing: 12),
                            ],
                          );
                        }

                        final adjustedIndex = index - 1;
                        return SingleConnection(
                          adjustedIndex,
                          connections[adjustedIndex],
                          connections.any((q) => q.isSelected),
                          (i, t) => select(i, t),
                          key: ValueKey(connections[adjustedIndex].item.name),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
