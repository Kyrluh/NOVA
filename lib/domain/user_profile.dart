class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.genres,
    required this.genresConfigured,
  });
  final String id;
  final String name;
  final Set<String> genres;
  final bool genresConfigured;
}

const preferredGenres = <String, List<String>>{
  'Action': ['action'],
  'Aventure': ['aventure', 'adventure'],
  'Comédie': ['comedie', 'comedy', 'humour'],
  'Drame': ['drame', 'drama'],
  'Horreur': ['horreur', 'horror', 'epouvante'],
  'Thriller': ['thriller', 'suspense'],
  'Science-fiction': ['science fiction', 'sci fi', 'science-fiction'],
  'Fantastique': ['fantastique', 'fantasy'],
  'Romance': ['romance', 'romantique'],
  'Animation': ['anim', 'kids', 'dessin'],
  'Famille': ['famille', 'family', 'jeunesse', 'kids'],
  'Policier': ['policier', 'crime', 'enquete'],
  'Documentaires': ['documentaire', 'documentary', 'documentaries'],
  'Histoire': ['histoire', 'historique', 'history'],
  'Émissions / Reality TV': ['emission', 'reality', 'tele realite'],
};

String genreText(String value) => value
    .toLowerCase()
    .replaceAll(RegExp('[éèêë]'), 'e')
    .replaceAll(RegExp('[àâä]'), 'a')
    .replaceAll(RegExp('[îï]'), 'i')
    .replaceAll(RegExp('[ôö]'), 'o')
    .replaceAll(RegExp('[ùûü]'), 'u')
    .replaceAll('ç', 'c');
