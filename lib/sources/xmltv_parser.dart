import 'package:xml/xml.dart';

import '../domain/source_models.dart';

/// XMLTV timestamps are converted to instants; timezone display belongs to UI.
DateTime? parseXmltvTime(String? value) {
  if (value == null) return null;
  final match = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})?(\d{2})?(\d{2})?\s*(Z|[+-]\d{4})?$',
  ).firstMatch(value.trim());
  if (match == null) return null;
  final year = int.parse(match[1]!);
  final month = int.parse(match[2]!);
  final day = int.parse(match[3]!);
  final hour = int.parse(match[4] ?? '0');
  final minute = int.parse(match[5] ?? '0');
  final second = int.parse(match[6] ?? '0');
  if (month < 1 ||
      month > 12 ||
      day < 1 ||
      day > 31 ||
      hour > 23 ||
      minute > 59 ||
      second > 59) {
    return null;
  }
  var instant = DateTime.utc(year, month, day, hour, minute, second);
  if (instant.month != month || instant.day != day) return null;
  final zone = match[7];
  if (zone != null && zone != 'Z') {
    final hours = int.parse(zone.substring(1, 3));
    final minutes = int.parse(zone.substring(3));
    if (hours > 23 || minutes > 59) return null;
    final offset = Duration(hours: hours, minutes: minutes);
    instant = zone.startsWith('+')
        ? instant.subtract(offset)
        : instant.add(offset);
  }
  // XMLTV defines omitted timezone as UTC, not the computer's local zone.
  return instant;
}

List<EpgProgramme> parseXmltv(String text) {
  final document = XmlDocument.parse(text.replaceFirst('\ufeff', ''));
  if (document.rootElement.name.local != 'tv') {
    throw const SourceException('Ce document n’est pas un guide XMLTV valide.');
  }
  final aliases = <String, List<String>>{};
  for (final channel in document.rootElement.findElements('channel')) {
    final id = channel.getAttribute('id');
    if (id == null || id.isEmpty) continue;
    aliases[id] = channel
        .findElements('display-name')
        .map((name) => name.innerText.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
  }
  final result = <EpgProgramme>[];
  for (final programme in document.rootElement.findElements('programme')) {
    final channel = programme.getAttribute('channel');
    final start = parseXmltvTime(programme.getAttribute('start'));
    final stop = parseXmltvTime(programme.getAttribute('stop'));
    if (channel == null ||
        channel.isEmpty ||
        start == null ||
        stop == null ||
        !stop.isAfter(start)) {
      continue;
    }
    final titles = programme.findElements('title').toList();
    final descriptions = programme.findElements('desc').toList();
    String localized(List<XmlElement> values) {
      if (values.isEmpty) return '';
      return (values
                  .where((e) => (e.getAttribute('lang') ?? '').startsWith('fr'))
                  .firstOrNull ??
              values.first)
          .innerText
          .trim();
    }

    final title = localized(titles);
    if (title.isEmpty) continue;
    result.add(
      EpgProgramme(
        channelId: channel,
        title: title,
        description: localized(descriptions),
        start: start,
        end: stop,
        channelAliases: aliases[channel] ?? const [],
      ),
    );
  }
  result.sort((a, b) => a.start.compareTo(b.start));
  return result;
}
