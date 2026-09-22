import 'package:flutter/material.dart';
import '../core/state.dart';
import '../core/models.dart';
import '../core/game_library.dart';
import '../core/library_sync.dart';
import 'design.dart';
import 'option_menu.dart';
import 'engine.dart';
import 'game_shelf.dart';

class PersonalLibrary extends StatefulWidget {
  final RyhzeState state;
  final String kind;
  final GameLibrary? games;
  final Widget Function(RyhzeTitle, Widget) titleCard;
  final Widget Function(LocalGame, Widget) localCard;
  final double horizontalPadding;
  final bool bigPicture;
  final String? initialFilter;
  final VoidCallback onOtherLibrary;
  const PersonalLibrary({
    super.key,
    required this.state,
    required this.kind,
    this.games,
    this.horizontalPadding = 28,
    this.bigPicture = false,
    this.initialFilter,
    required this.titleCard,
    required this.localCard,
    required this.onOtherLibrary,
  });
  @override
  State<PersonalLibrary> createState() => _PersonalLibraryState();
}

class _PersonalLibraryState extends State<PersonalLibrary> {
  String filter = 'all', sort = 'recent', query = '';
  RyhzeState get state => widget.state;
  String get scope => '${state.scope}:${widget.kind}';
  String get localKey => 'local-organisation:$scope';
  Set<String> get localItems =>
      (state.prefs.getStringList(localKey) ?? []).toSet();
  RyhzeTitle? catalogueTitle(LocalGame game) => state.visibleTitles
      .where(
        (t) =>
            t.isGame &&
            (gameNameKey(t.title) == gameNameKey(game.name) ||
                (game.source != 'Epic Games' &&
                    game.storeId.isNotEmpty &&
                    t.storeId == game.storeId)),
      )
      .firstOrNull;
  @override
  void initState() {
    super.initState();
    filter =
        widget.initialFilter ??
        state.prefs.getString('library-filter:$scope') ??
        'all';
    sort = state.prefs.getString('library-sort:$scope') ?? 'recent';
  }

  Future<void> localToggle(String key) async {
    final next = localItems;
    next.contains(key) ? next.remove(key) : next.add(key);
    if (!await state.prefs.setStringList(localKey, next.toList())) {
      throw Exception('Your library change could not be saved.');
    }
    if (mounted) setState(() {});
  }

  List<MapEntry<String, dynamic>> get collections => state
      .library
      .entries
      .entries
      .where(
        (e) =>
            e.key.startsWith('collection:') &&
            e.value['value']?['kind'] == widget.kind,
      )
      .toList();
  Future<void> editCollection([String? id, String? name]) async {
    var input = name ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(id == null ? 'New collection' : 'Rename collection'),
        content: TextFormField(
          initialValue: input,
          onChanged: (value) => input = value,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Collection name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (input.trim().isNotEmpty) {
                Navigator.pop(context, input.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (result != null) {
      await state.library.change('collection:${id ?? libraryId()}', {
        'name': result,
        'kind': widget.kind,
      });
    }
  }

  Widget options(String id, {bool local = false, RyhzeTitle? title}) {
    final favorite = local
        ? localItems.contains('favorite:$id')
        : state.saved.contains(id);
    return PopupMenuButton<String>(
      tooltip: 'Library options',
      position: PopupMenuPosition.over,
      itemBuilder: (_) => [
        RyhzeMenuItem(
          value: 'favorite',
          child: Text(favorite ? 'Remove favourite' : 'Add favourite'),
        ),
        for (final c in collections)
          RyhzeMenuItem(
            value: c.key,
            checked: local
                ? localItems.contains('${c.key}:$id')
                : state.library.value('member:${c.key.substring(11)}:$id') ==
                      true,
            child: Text(c.value['value']['name']),
          ),
        if (widget.kind == 'film') ...[
          const RyhzeMenuItem(value: 'watched', child: Text('Mark watched')),
          const RyhzeMenuItem(
            value: 'remove-progress',
            child: Text('Remove from Continue'),
          ),
        ],
      ],
      onSelected: (value) => attempt(context, () async {
        if (value == 'favorite') {
          if (local) {
            await localToggle('favorite:$id');
          } else {
            await state.toggleSaved(title!);
          }
        } else if (value == 'watched') {
          await state.library.change('progress:$id', {
            'stream': state.history[id]?['stream'] ?? '',
            'position': state.history[id]?['duration'] ?? 0,
            'duration': state.history[id]?['duration'] ?? 0,
            'watched': true,
          });
        } else if (value == 'remove-progress') {
          await state.library.change('progress:$id', null);
        } else if (local) {
          await localToggle('$value:$id');
        } else {
          final key = 'member:${value.substring(11)}:$id';
          await state.library.change(
            key,
            state.library.value(key) == true ? null : true,
          );
        }
      }),
      icon: const Icon(Icons.more_horiz),
    );
  }

  bool matches(String id, String name, bool local) {
    if (!name.toLowerCase().contains(query.toLowerCase())) return false;
    if (filter == 'all') return true;
    if (filter == 'favorite') {
      return local
          ? localItems.contains('favorite:$id')
          : state.saved.contains(id);
    }
    if (filter == 'continue') {
      final p = state.history[id];
      return p != null &&
          p['watched'] != true &&
          (p['position'] ?? 0) > 0 &&
          (p['duration'] ?? 0) > 0;
    }
    return local
        ? localItems.contains('$filter:$id')
        : state.library.value('member:${filter.substring(11)}:$id') == true;
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 700;
    final controlWidth =
        MediaQuery.sizeOf(context).width - widget.horizontalPadding * 2;
    final available = {
      'all',
      'favorite',
      if (widget.kind == 'film') 'continue',
      ...collections.map((c) => c.key),
    };
    if (!available.contains(filter)) filter = 'all';
    final titles = state.visibleTitles
        .where(
          (t) =>
              (t.isGame ? 'game' : 'film') == widget.kind &&
              matches(t.id, t.title, false),
        )
        .toList();
    final games = widget.kind == 'game' && widget.games?.permission == true
        ? widget.games!.sorted
              .where(
                (g) => matches(
                  catalogueTitle(g)?.id ?? g.id,
                  g.name,
                  catalogueTitle(g) == null,
                ),
              )
              .toList()
        : <LocalGame>[];
    // Keep catalogue and installed representations from appearing twice.
    titles.removeWhere(
      (t) => games.any(
        (g) =>
            gameNameKey(g.name) == gameNameKey(t.title) ||
            (g.storeId.isNotEmpty && g.storeId == t.storeId),
      ),
    );
    final records =
        <
          ({
            String id,
            String name,
            int recent,
            int added,
            bool running,
            Widget card,
          })
        >[
          for (final t in titles)
            (
              id: t.id,
              name: t.title,
              recent:
                  DateTime.tryParse(
                    state.history[t.id]?['updated'] ?? '',
                  )?.millisecondsSinceEpoch ??
                  0,
              added:
                  state.library.entries['favorite:${t.id}']?['added'] ??
                  state.library.entries['progress:${t.id}']?['added'] ??
                  0,
              running: false,
              card: widget.titleCard(t, options(t.id, title: t)),
            ),
          for (final g in games)
            (
              id: g.id,
              name: g.name,
              recent: g.lastPlayed?.millisecondsSinceEpoch ?? 0,
              added: g.addedAt.millisecondsSinceEpoch,
              running: widget.games!.isRunning(g),
              card: widget.localCard(
                g,
                options(
                  catalogueTitle(g)?.id ?? g.id,
                  local: catalogueTitle(g) == null,
                  title: catalogueTitle(g),
                ),
              ),
            ),
        ];
    records.sort((a, b) {
      if (sort == 'recent' && a.running != b.running) return a.running ? -1 : 1;
      final n = sort == 'recent'
          ? b.recent.compareTo(a.recent)
          : sort == 'added'
          ? b.added.compareTo(a.added)
          : 0;
      return n != 0 ? n : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.horizontalPadding,
        vertical: 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.kind == 'game' ? 'Games Library' : 'Films Library',
            style: heading(36),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Pill(
                widget.kind == 'game' ? 'Films Library' : 'Games Library',
                onPressed: widget.onOtherLibrary,
              ),
              if (state.user != null)
                Pill(
                  'New collection',
                  icon: Icons.add,
                  onPressed: () => attempt(context, editCollection),
                ),
              if (state.library.pending.isNotEmpty ||
                  state.library.error != null)
                Pill('Sync pending · Retry', onPressed: state.library.sync),
            ],
          ),
          if (state.user == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Sign in to sync favourites, collections and film progress. Installed games stay on this PC.',
              ),
            ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: narrow ? controlWidth : 260,
                child: TextField(
                  onChanged: (v) => setState(() => query = v),
                  decoration: const InputDecoration(
                    labelText: 'Search library',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
              ),
              SizedBox(
                width: narrow ? controlWidth : 240,
                child: RyhzeDropdown<String>(
                  value: filter,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All titles'),
                    ),
                    const DropdownMenuItem(
                      value: 'favorite',
                      child: Text('Favourites'),
                    ),
                    if (widget.kind == 'film')
                      const DropdownMenuItem(
                        value: 'continue',
                        child: Text('Continue Watching'),
                      ),
                    for (final c in collections)
                      DropdownMenuItem(
                        value: c.key,
                        child: Text(c.value['value']['name']),
                      ),
                  ],
                  onChanged: (v) {
                    setState(() => filter = v!);
                    state.prefs.setString('library-filter:$scope', filter);
                  },
                ),
              ),
              SizedBox(
                width: narrow ? controlWidth : 220,
                child: RyhzeDropdown<String>(
                  value: sort,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: 'recent',
                      child: Text(
                        widget.kind == 'game'
                            ? 'Recently played'
                            : 'Recently watched',
                      ),
                    ),
                    const DropdownMenuItem(
                      value: 'added',
                      child: Text('Recently added'),
                    ),
                    const DropdownMenuItem(value: 'name', child: Text('Name')),
                  ],
                  onChanged: (v) {
                    setState(() => sort = v!);
                    state.prefs.setString('library-sort:$scope', sort);
                  },
                ),
              ),
              if (filter.startsWith('collection:')) ...[
                Pill(
                  'Rename collection',
                  onPressed: () => attempt(
                    context,
                    () => editCollection(
                      filter.substring(11),
                      state.library.value(filter)['name'],
                    ),
                  ),
                ),
                Pill(
                  'Delete collection',
                  onPressed: () => attempt(context, () async {
                    final yes = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Delete collection?'),
                        content: const Text(
                          'Titles and installed files will remain available.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(c, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );
                    if (yes == true) await state.library.change(filter, null);
                  }),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          if (records.isEmpty)
            const Glass(
              padding: EdgeInsets.all(28),
              child: Text(
                'No titles here yet. Try another filter or add titles to this collection.',
              ),
            ),
          LayoutBuilder(
            builder: (context, bounds) {
              if (widget.bigPicture && widget.kind == 'game') {
                return GameShelf(
                  children: [
                    for (final item in records)
                      KeyedSubtree(key: ValueKey(item.id), child: item.card),
                  ],
                );
              }
              final columns = bounds.maxWidth < 650
                  ? 1
                  : bounds.maxWidth < 1050
                  ? 2
                  : 3;
              final width = (bounds.maxWidth - (columns - 1) * 24) / columns;
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  for (final item in records)
                    SizedBox(width: width, child: item.card),
                ],
              );
            },
          ),
          if (widget.kind == 'game' &&
              state.engineAccess &&
              filter == 'all' &&
              'race'.contains(query.toLowerCase())) ...[
            const SizedBox(height: 40),
            Text('Engine', style: heading(28)),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, bounds) {
                final columns = bounds.maxWidth < 650
                    ? 1
                    : bounds.maxWidth < 1050
                    ? 2
                    : 3;
                final cardWidth =
                    (bounds.maxWidth - (columns - 1) * 24) / columns;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: cardWidth,
                    child: InstalledEngineCard(state: state),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
