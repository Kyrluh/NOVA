/// Compares image assets without changing the URL used for downloading them.
String? posterIdentity(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme) ||
      uri.host.isEmpty) {
    return null;
  }
  if (uri.host == 'image.tmdb.org' && uri.pathSegments.isNotEmpty) {
    return 'tmdb/${uri.pathSegments.last}';
  }
  if ({'images.metahub.space', 'live.metahub.space'}.contains(uri.host)) {
    final imdb = RegExp(r'tt\d{5,12}').firstMatch(uri.path)?.group(0);
    if (imdb != null) return 'metahub/$imdb';
  }
  return uri.replace(fragment: '').toString();
}
