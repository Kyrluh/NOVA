import '../domain/models.dart';

/// Original fictional catalogue. It does not contain any television provider,
/// account, protected stream or invented schedule presented as a real EPG.
const demoCatalog = <MediaItem>[
  MediaItem(
    id: 'film-orbite',
    title: 'Dernière orbite',
    kind: MediaKind.movie,
    category: 'Science-fiction',
    year: 2026,
    durationMinutes: 112,
    palette: 0xff6f70e8,
    subtitle: 'Au-delà du silence',
    art: 0,
    description:
        'Une cartographe reçoit un signal depuis une station abandonnée. '
        'Entre les anneaux d’une planète inconnue, elle retrouve les traces '
        'd’une expédition que personne ne se souvient avoir envoyée. '
        'Œuvre fictive créée pour la démonstration de NOVA IPTV.',
  ),
  MediaItem(
    id: 'film-azur',
    title: 'L’archipel bleu',
    kind: MediaKind.movie,
    category: 'Aventure',
    year: 2025,
    durationMinutes: 98,
    palette: 0xff1aacae,
    subtitle: 'Une île. Mille horizons.',
    art: 1,
    description:
        'Partie restaurer un phare, une jeune navigatrice découvre '
        'un archipel absent des cartes et une communauté qui vit au rythme '
        'des marées. Œuvre fictive de démonstration.',
  ),
  MediaItem(
    id: 'film-ambre',
    title: 'La ville d’ambre',
    kind: MediaKind.movie,
    category: 'Drame',
    year: 2026,
    durationMinutes: 106,
    palette: 0xffe29d55,
    subtitle: 'Les lieux se souviennent',
    art: 2,
    description:
        'Une architecte revient dans sa ville natale pour transformer '
        'une gare désaffectée. Chaque salle lui révèle une histoire oubliée '
        'de sa famille. Œuvre fictive de démonstration.',
  ),
  MediaItem(
    id: 'film-foret',
    title: 'Sous la canopée',
    kind: MediaKind.movie,
    category: 'Nature',
    year: 2024,
    durationMinutes: 84,
    palette: 0xff46a78b,
    subtitle: 'Un monde à hauteur de feuille',
    art: 3,
    description:
        'Un voyage imaginaire dans une forêt préservée, des racines '
        'aux plus hautes branches, raconté à travers les rencontres d’une '
        'botaniste. Documentaire fictif de démonstration.',
  ),
  MediaItem(
    id: 'film-minuit',
    title: 'Minuit électrique',
    kind: MediaKind.movie,
    category: 'Thriller',
    year: 2025,
    durationMinutes: 101,
    palette: 0xffcb5caa,
    subtitle: 'Suivez la lumière',
    art: 4,
    description:
        'Pendant une nuit de panne générale, un coursier traverse '
        'la métropole pour livrer une dernière enveloppe. Son itinéraire '
        'semble avoir été dessiné des années avant sa naissance. '
        'Œuvre fictive de démonstration.',
  ),
  MediaItem(
    id: 'film-dunes',
    title: 'Les dunes immobiles',
    kind: MediaKind.movie,
    category: 'Aventure',
    year: 2023,
    durationMinutes: 94,
    palette: 0xffc47b5e,
    subtitle: 'Le désert garde ses secrets',
    art: 5,
    description:
        'Deux sœurs suivent les relevés d’un observatoire englouti '
        'par le sable. Au fil du voyage, elles apprennent à lire un paysage '
        'en perpétuel mouvement. Œuvre fictive de démonstration.',
  ),
  MediaItem(
    id: 'serie-horizons',
    title: 'Horizons',
    kind: MediaKind.series,
    category: 'Exploration',
    year: 2026,
    durationMinutes: 44,
    palette: 0xff6e8ee6,
    subtitle: 'Chaque frontière est un départ',
    art: 0,
    description:
        'L’équipage d’un vaisseau d’exploration cartographie les '
        'limites d’un système stellaire. Une série fictive de démonstration, '
        'avec saisons et épisodes pour découvrir la navigation NOVA.',
    seasons: [
      DemoSeason(
        number: 1,
        episodes: [
          DemoEpisode(
            id: 'horizons-s1-e1',
            title: 'Le premier signal',
            number: 1,
            durationMinutes: 44,
          ),
          DemoEpisode(
            id: 'horizons-s1-e2',
            title: 'La mer des étoiles',
            number: 2,
            durationMinutes: 46,
          ),
          DemoEpisode(
            id: 'horizons-s1-e3',
            title: 'Une autre rive',
            number: 3,
            durationMinutes: 43,
          ),
        ],
      ),
      DemoSeason(
        number: 2,
        episodes: [
          DemoEpisode(
            id: 'horizons-s2-e1',
            title: 'L’observatoire',
            number: 1,
            durationMinutes: 45,
          ),
          DemoEpisode(
            id: 'horizons-s2-e2',
            title: 'Le retour des voyageurs',
            number: 2,
            durationMinutes: 48,
          ),
        ],
      ),
    ],
  ),
  MediaItem(
    id: 'serie-atelier',
    title: 'Atelier 17',
    kind: MediaKind.series,
    category: 'Drame',
    year: 2025,
    durationMinutes: 38,
    palette: 0xffd49867,
    subtitle: 'Construire une autre vie',
    art: 2,
    description:
        'Dans un atelier partagé au bord du fleuve, cinq inconnus '
        'réinventent leur quotidien autour d’un projet de quartier. '
        'Série fictive de démonstration.',
    seasons: [
      DemoSeason(
        number: 1,
        episodes: [
          DemoEpisode(
            id: 'atelier-s1-e1',
            title: 'La porte ouverte',
            number: 1,
            durationMinutes: 38,
          ),
          DemoEpisode(
            id: 'atelier-s1-e2',
            title: 'Plans de demain',
            number: 2,
            durationMinutes: 40,
          ),
          DemoEpisode(
            id: 'atelier-s1-e3',
            title: 'Les murs respirent',
            number: 3,
            durationMinutes: 37,
          ),
        ],
      ),
    ],
  ),
  MediaItem(
    id: 'serie-pelagique',
    title: 'Pélagique',
    kind: MediaKind.series,
    category: 'Nature',
    year: 2026,
    durationMinutes: 50,
    palette: 0xff2888a3,
    subtitle: 'L’océan, autrement',
    art: 1,
    description:
        'Une expédition imaginaire suit les grands courants et '
        'raconte la vie d’un laboratoire flottant. Série documentaire '
        'fictive de démonstration.',
    seasons: [
      DemoSeason(
        number: 1,
        episodes: [
          DemoEpisode(
            id: 'pelagique-s1-e1',
            title: 'Le grand courant',
            number: 1,
            durationMinutes: 50,
          ),
          DemoEpisode(
            id: 'pelagique-s1-e2',
            title: 'Sous la surface',
            number: 2,
            durationMinutes: 49,
          ),
          DemoEpisode(
            id: 'pelagique-s1-e3',
            title: 'Les gardiens du récif',
            number: 3,
            durationMinutes: 52,
          ),
        ],
      ),
    ],
  ),
  MediaItem(
    id: 'serie-ombres',
    title: 'Lignes d’ombre',
    kind: MediaKind.series,
    category: 'Thriller',
    year: 2024,
    durationMinutes: 42,
    palette: 0xffa96cba,
    subtitle: 'Tout commence par un détail',
    art: 4,
    description:
        'Une restauratrice remarque le même plan dans trois tableaux '
        'séparés par un siècle. Son enquête la conduit dans les passages '
        'oubliés de la ville. Série fictive de démonstration.',
    seasons: [
      DemoSeason(
        number: 1,
        episodes: [
          DemoEpisode(
            id: 'ombres-s1-e1',
            title: 'Le motif caché',
            number: 1,
            durationMinutes: 42,
          ),
          DemoEpisode(
            id: 'ombres-s1-e2',
            title: 'Les passages',
            number: 2,
            durationMinutes: 44,
          ),
          DemoEpisode(
            id: 'ombres-s1-e3',
            title: 'La dernière ligne',
            number: 3,
            durationMinutes: 46,
          ),
        ],
      ),
    ],
  ),
  MediaItem(
    id: 'live-nova',
    title: 'NOVA One',
    kind: MediaKind.live,
    category: 'Généralistes',
    year: 2026,
    durationMinutes: 0,
    palette: 0xff8b72e8,
    subtitle: 'Chaîne fictive · démonstration',
    art: 0,
    description:
        'Chaîne fictive pour découvrir la présentation TV. Aucun '
        'flux ni programme réel n’est associé à cette entrée.',
  ),
  MediaItem(
    id: 'live-terra',
    title: 'Terra',
    kind: MediaKind.live,
    category: 'Découverte',
    year: 2026,
    durationMinutes: 0,
    palette: 0xff4da78a,
    subtitle: 'Chaîne fictive · démonstration',
    art: 3,
    description:
        'Chaîne nature fictive de démonstration. Aucun flux fourni '
        'et aucun guide TV réel associé.',
  ),
  MediaItem(
    id: 'live-cinema',
    title: 'Cinéma Studio',
    kind: MediaKind.live,
    category: 'Cinéma',
    year: 2026,
    durationMinutes: 0,
    palette: 0xffd59768,
    subtitle: 'Chaîne fictive · démonstration',
    art: 2,
    description:
        'Chaîne cinéma fictive de démonstration. Ajoutez vos propres '
        'sources compatibles lorsque la connexion IPTV sera disponible.',
  ),
  MediaItem(
    id: 'live-orbite',
    title: 'Orbite',
    kind: MediaKind.live,
    category: 'Découverte',
    year: 2026,
    durationMinutes: 0,
    palette: 0xff6a9bc7,
    subtitle: 'Chaîne fictive · démonstration',
    art: 1,
    description:
        'Chaîne scientifique fictive de démonstration. Aucun '
        'stream, fournisseur ni compte inclus.',
  ),
  MediaItem(
    id: 'live-nocturne',
    title: 'Nocturne',
    kind: MediaKind.live,
    category: 'Culture',
    year: 2026,
    durationMinutes: 0,
    palette: 0xffbe6cbb,
    subtitle: 'Chaîne fictive · démonstration',
    art: 4,
    description:
        'Chaîne culturelle fictive de démonstration, sans flux '
        'associé ni fausse programmation EPG.',
  ),
];
