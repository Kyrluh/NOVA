import 'models.dart';

enum SourceKind { m3uUrl, m3uFile, xtream }

class SourceDraft {
  const SourceDraft({
    required this.name,
    required this.kind,
    required this.address,
    this.username = '',
    this.password = '',
    this.epgUrl = '',
  });

  final String name;
  final SourceKind kind;
  final String address;
  final String username;
  final String password;
  final String epgUrl;

  @override
  String toString() => 'SourceDraft($kind)';
}

class SourceConfig extends SourceDraft {
  const SourceConfig({
    required this.id,
    required super.name,
    required super.kind,
    required super.address,
    super.username,
    super.password,
    super.epgUrl,
  });

  factory SourceConfig.fromDraft(String id, SourceDraft draft) => SourceConfig(
    id: id,
    name: draft.name.trim(),
    kind: draft.kind,
    address: draft.address.trim(),
    username: draft.username.trim(),
    password: draft.password,
    epgUrl: draft.epgUrl.trim(),
  );

  factory SourceConfig.fromJson(Map<String, dynamic> json) => SourceConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: SourceKind.values.byName(json['kind'] as String),
    address: json['address'] as String,
    username: json['username'] as String? ?? '',
    password: json['password'] as String? ?? '',
    epgUrl: json['epgUrl'] as String? ?? '',
  );

  final String id;
  SourceDraft get draft => SourceDraft(
    name: name,
    kind: kind,
    address: address,
    username: username,
    password: password,
    epgUrl: epgUrl,
  );

  /// Sensitive fields: serialize only into protected storage.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'address': address,
    'username': username,
    'password': password,
    'epgUrl': epgUrl,
  };

  SourceConfig copyWith({String? epgUrl}) => SourceConfig(
    id: id,
    name: name,
    kind: kind,
    address: address,
    username: username,
    password: password,
    epgUrl: epgUrl ?? this.epgUrl,
  );

  @override
  String toString() => 'SourceConfig($id, $kind)';
}

class SourceSummary {
  const SourceSummary({
    required this.id,
    required this.name,
    required this.kind,
    required this.itemCount,
    required this.updatedAt,
    this.error,
  });
  final String id;
  final String name;
  final SourceKind kind;
  final int itemCount;
  final DateTime updatedAt;
  final String? error;
}

class SourceCatalog {
  const SourceCatalog({
    required this.items,
    this.suggestedEpgUrl,
    this.warnings = const [],
    this.failedKinds = const {},
  });
  final List<MediaItem> items;
  final String? suggestedEpgUrl;
  final List<String> warnings;
  final Set<MediaKind> failedKinds;
}

class EpgProgramme {
  const EpgProgramme({
    required this.channelId,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
    this.channelAliases = const [],
  });
  final String channelId;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
  final List<String> channelAliases;

  Map<String, dynamic> toJson() => {
    'channelId': channelId,
    'title': title,
    'description': description,
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
    'channelAliases': channelAliases,
  };
  factory EpgProgramme.fromJson(Map<String, dynamic> json) => EpgProgramme(
    channelId: json['channelId'] as String,
    title: json['title'] as String,
    description: json['description'] as String? ?? '',
    start: DateTime.parse(json['start'] as String).toUtc(),
    end: DateTime.parse(json['end'] as String).toUtc(),
    channelAliases:
        (json['channelAliases'] as List?)?.whereType<String>().toList() ??
        const [],
  );

  bool isCurrentAt(DateTime now) => !now.isBefore(start) && now.isBefore(end);
  double progressAt(DateTime now) => end.isAfter(start)
      ? (now.difference(start).inMilliseconds /
                end.difference(start).inMilliseconds)
            .clamp(0, 1)
      : 0;
}

class SourceException implements Exception {
  const SourceException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SourceCancelled extends SourceException {
  const SourceCancelled() : super('Chargement annulé.');
}

class CancellationToken {
  bool _cancelled = false;
  final Set<void Function()> _callbacks = {};
  bool get isCancelled => _cancelled;
  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final callback in _callbacks.toList()) {
      callback();
    }
    _callbacks.clear();
  }

  void throwIfCancelled() {
    if (_cancelled) throw const SourceCancelled();
  }

  void onCancel(void Function() callback) {
    if (_cancelled) {
      callback();
    } else {
      _callbacks.add(callback);
    }
  }

  void removeOnCancel(void Function() callback) => _callbacks.remove(callback);
}
