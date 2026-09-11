class RyhzeTitle {
  final String id, title, kind, label, status, description, image, imageNote;
  final List<String> categories, streams;
  final List<Season> seasons;
  final List<TitleFact> facts;
  final String? preview, download, availability;
  final String storeId;
  final int revision;
  final bool internal;
  const RyhzeTitle({
    required this.id,
    required this.title,
    required this.kind,
    required this.label,
    required this.status,
    required this.description,
    this.image = '',
    this.imageNote = '',
    this.categories = const [],
    this.streams = const [],
    this.seasons = const [],
    this.facts = const [],
    this.preview,
    this.download,
    this.availability,
    this.internal = false,
    this.storeId = '',
    this.revision = 0,
  });
  bool get isGame => kind == 'game';
  bool get upcoming => availability == 'coming-soon';
  bool matches(String query) => [
    title,
    label,
    ...categories,
  ].join(' ').toLowerCase().contains(query.trim().toLowerCase());
  factory RyhzeTitle.fromJson(Map<String, dynamic> j) => RyhzeTitle(
    id: j['id'] as String,
    title: j['title'] as String,
    kind: j['kind'] as String,
    label: j['label'] as String? ?? '',
    status: j['status'] as String? ?? '',
    description: j['description'] as String? ?? '',
    image: j['image'] as String? ?? '',
    imageNote: j['imageNote'] as String? ?? '',
    categories: List<String>.from(j['categories'] ?? []),
    streams: parseStreams(j['streams']),
    seasons: (j['seasons'] as List? ?? [])
        .map((s) => Season.fromJson(s))
        .toList(),
    facts: (j['facts'] as List? ?? [])
        .map((f) => TitleFact(f['label'], f['value']))
        .toList(),
    preview: j['preview'],
    download: j['download'],
    availability: j['availability'],
    internal: j['internal'] == true,
    storeId: j['storeId'] as String? ?? '',
    revision: j['revision'] as int? ?? 0,
  );
}

List<String> parseStreams(dynamic value) =>
    (value as List? ?? []).map((s) => s['url'] as String).toList();

class TitleFact {
  final String label, value;
  const TitleFact(this.label, this.value);
}

class Season {
  final String title;
  final List<Episode> episodes;
  const Season(this.title, this.episodes);
  factory Season.fromJson(Map<String, dynamic> j) => Season(
    j['title'],
    (j['episodes'] as List)
        .map((e) => Episode(e['title'], parseStreams(e['streams'])))
        .toList(),
  );
}

class Episode {
  final String title;
  final List<String> streams;
  const Episode(this.title, this.streams);
}

class Member {
  final String username, role;
  const Member(this.username, this.role);
  bool get launcherAdmin =>
      role == 'admin' && ['andru', 'leo'].contains(username.toLowerCase());
  factory Member.fromJson(Map<String, dynamic> j) =>
      Member(j['username'], j['role']);
}
