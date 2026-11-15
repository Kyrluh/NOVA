import 'package:flutter/material.dart';

const profileAvatars = <(String, String, String)>[
  ('superman', 'Superman', 'Super-héros'),
  ('spiderman', 'Spider-Man', 'Super-héros'),
  ('ironman', 'Iron Man', 'Super-héros'),
  ('batman', 'Batman', 'Super-héros'),
  ('wonderwoman', 'Wonder Woman', 'Super-héros'),
  ('panther', 'Black Panther', 'Super-héros'),
  ('harry', 'Harry Potter', 'Poudlard'),
  ('ron', 'Ron Weasley', 'Poudlard'),
  ('hermione', 'Hermione', 'Poudlard'),
  ('dumbledore', 'Dumbledore', 'Poudlard'),
  ('vader', 'Dark Vador', 'Star Wars'),
  ('luke', 'Luke Skywalker', 'Star Wars'),
  ('leia', 'Princesse Leia', 'Star Wars'),
  ('yoda', 'Yoda', 'Star Wars'),
  ('grogu', 'Grogu', 'Star Wars'),
  ('marty', 'Marty McFly', 'Retour vers le futur'),
  ('doc', 'Doc Brown', 'Retour vers le futur'),
  ('luffy', 'Luffy', 'One Piece'),
  ('zoro', 'Zoro', 'One Piece'),
  ('nami', 'Nami', 'One Piece'),
  ('usopp', 'Usopp', 'One Piece'),
  ('sanji', 'Sanji', 'One Piece'),
  ('chopper', 'Chopper', 'One Piece'),
  ('robin', 'Robin', 'One Piece'),
  ('franky', 'Franky', 'One Piece'),
  ('brook', 'Brook', 'One Piece'),
  ('jinbe', 'Jinbe', 'One Piece'),
  ('law', 'Trafalgar Law', 'One Piece'),
  ('goku', 'Goku', 'Animation'),
  ('naruto', 'Naruto', 'Animation'),
];

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.avatar, this.size = 64});
  final String avatar;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label:
        profileAvatars.where((a) => a.$1 == avatar).firstOrNull?.$2 ?? 'Profil',
    child: ClipOval(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _AvatarPainter(avatar)),
      ),
    ),
  );
}

/// Original geometric portraits, drawn offline at the exact display size.
class _AvatarPainter extends CustomPainter {
  const _AvatarPainter(this.id);
  final String id;
  @override
  void paint(Canvas canvas, Size size) {
    final c = canvas;
    c.save();
    c.scale(size.width / 100, size.height / 100);
    void oval(double x, double y, double w, double h, Color color) =>
        c.drawOval(Rect.fromLTWH(x, y, w, h), Paint()..color = color);
    void rect(double x, double y, double w, double h, Color color) =>
        c.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, y, w, h),
            const Radius.circular(3),
          ),
          Paint()..color = color,
        );
    void line(
      double x,
      double y,
      double xx,
      double yy,
      Color color, [
      double width = 2,
    ]) => c.drawLine(
      Offset(x, y),
      Offset(xx, yy),
      Paint()
        ..color = color
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    void poly(List<Offset> points, Color color) {
      final p = Path()..addPolygon(points, true);
      c.drawPath(p, Paint()..color = color);
    }

    const dark = Color(0xFF171927),
        skin = Color(0xFFF2BC94),
        gold = Color(0xFFFFD45B);
    final known = profileAvatars.any((a) => a.$1 == id);
    final green = {'yoda', 'grogu'}.contains(id);
    final blue = id == 'jinbe';
    final skull = id == 'brook';
    final blackMask = {'batman', 'panther', 'vader'}.contains(id);
    final redMask = {'spiderman', 'ironman'}.contains(id);
    final masked = blackMask || redMask;
    final face = green
        ? const Color(0xFF9AC96B)
        : blue
        ? const Color(0xFF65BED9)
        : skull
        ? const Color(0xFFF5EFE1)
        : masked
        ? (redMask ? const Color(0xFFCF334C) : dark)
        : skin;
    final hair = switch (id) {
      'ron' || 'nami' => const Color(0xFFF18A32),
      'luke' || 'sanji' || 'naruto' => gold,
      'doc' || 'dumbledore' => const Color(0xFFE7E8F5),
      'zoro' => const Color(0xFF62BA67),
      'franky' => const Color(0xFF51C6EC),
      'hermione' || 'marty' => const Color(0xFF794B37),
      _ => dark,
    };
    final suit = switch (id) {
      'superman' => const Color(0xFF376DCB),
      'ironman' || 'marty' || 'luffy' => const Color(0xFFCD3E4E),
      'goku' || 'naruto' => const Color(0xFFED873A),
      'harry' || 'ron' || 'hermione' => const Color(0xFF782E40),
      'leia' || 'doc' => const Color(0xFFE6E8ED),
      'yoda' || 'grogu' || 'luke' => const Color(0xFFAC9A77),
      'zoro' => const Color(0xFF358F70),
      _ => const Color(0xFF424775),
    };
    final background = switch (id) {
      'luffy' || 'nami' || 'goku' => const Color(0xFF553446),
      'yoda' || 'grogu' || 'zoro' => const Color(0xFF1C4B50),
      _ => const Color(0xFF383064),
    };
    rect(0, 0, 100, 100, background);
    oval(5, 8, 90, 90, const Color(0x18FFFFFF));
    oval(12, 71, 76, 58, suit);
    if (!known) {
      oval(33, 23, 34, 38, const Color(0xFFE8DFFF));
      c.restore();
      return;
    }
    if (green) {
      poly([
        const Offset(32, 40),
        const Offset(3, 32),
        const Offset(28, 59),
      ], face);
      poly([
        const Offset(68, 40),
        const Offset(97, 32),
        const Offset(72, 59),
      ], face);
    }
    if ({'leia', 'brook'}.contains(id)) {
      oval(13, 29, 25, 32, hair);
      oval(62, 29, 25, 32, hair);
    }
    if (id == 'brook') oval(22, 13, 56, 57, dark);
    if (id == 'chopper') {
      line(27, 29, 15, 9, gold, 5);
      line(18, 17, 8, 18, gold, 4);
      line(73, 29, 85, 9, gold, 5);
      line(82, 17, 92, 18, gold, 4);
    }
    if (!masked && !green && !skull) oval(24, 19, 52, 49, hair);
    oval(28, 27, 44, 49, face);
    if (!masked && !green && !skull) {
      oval(25, 21, 49, 17, hair);
      poly([
        const Offset(28, 29),
        const Offset(51, 26),
        const Offset(34, 48),
      ], hair);
      if ({'goku', 'naruto', 'franky', 'doc'}.contains(id)) {
        for (var i = 0; i < 5; i++) {
          poly([
            Offset(23 + i * 11, 29),
            Offset(23 + i * 11, 8 + (i % 2) * 5),
            Offset(40 + i * 9, 28),
          ], hair);
        }
      }
      if (id == 'sanji') {
        poly([
          const Offset(47, 26),
          const Offset(74, 28),
          const Offset(59, 57),
        ], hair);
      }
    }
    if ({'batman', 'panther'}.contains(id)) {
      poly([
        const Offset(29, 37),
        const Offset(28, 10),
        const Offset(44, 31),
      ], dark);
      poly([
        const Offset(56, 31),
        const Offset(72, 10),
        const Offset(71, 37),
      ], dark);
    }
    if (id == 'batman') oval(36, 57, 28, 17, skin);
    if (id == 'vader') {
      poly([
        const Offset(27, 32),
        const Offset(17, 76),
        const Offset(42, 70),
      ], dark);
      poly([
        const Offset(73, 32),
        const Offset(83, 76),
        const Offset(58, 70),
      ], dark);
      poly([
        const Offset(50, 49),
        const Offset(38, 66),
        const Offset(62, 66),
      ], const Color(0xFF707483));
      line(44, 58, 44, 65, dark);
      line(50, 57, 50, 65, dark);
      line(56, 58, 56, 65, dark);
    }
    if (id == 'ironman') {
      poly([
        const Offset(33, 33),
        const Offset(46, 36),
        const Offset(54, 36),
        const Offset(67, 33),
        const Offset(63, 65),
        const Offset(50, 71),
        const Offset(37, 65),
      ], gold);
    }
    final eyes = masked ? Colors.white : dark;
    if (id == 'spiderman') {
      for (var i = 0; i < 4; i++) {
        line(50, 30, 29 + i * 14, 67, const Color(0xFF6F2034), 1);
      }
      line(29, 42, 71, 42, const Color(0xFF6F2034), 1);
      line(29, 57, 71, 57, const Color(0xFF6F2034), 1);
      oval(34, 44, 12, 12, Colors.white);
      oval(54, 44, 12, 12, Colors.white);
    } else {
      oval(36, 46, green ? 9 : 6, green ? 11 : 5, eyes);
      if (id != 'zoro' && id != 'sanji') {
        oval(58, 46, green ? 9 : 6, green ? 11 : 5, eyes);
      }
    }
    if (skull) {
      oval(35, 44, 11, 13, dark);
      oval(54, 44, 11, 13, dark);
      rect(41, 65, 18, 4, dark);
    } else if (!masked) {
      line(44, 63, 56, 63, const Color(0xFF8E524A), 2);
    }
    if (id == 'usopp') oval(47, 51, 29, 8, skin);
    if (id == 'zoro') line(61, 40, 59, 62, const Color(0xFF4A7747), 2);
    if (id == 'harry') {
      for (final x in [40.0, 60.0]) {
        c.drawCircle(
          Offset(x, 49),
          9,
          Paint()
            ..color = dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      line(48, 48, 52, 48, dark);
      line(58, 32, 54, 36, const Color(0xFFAC6B51));
      line(54, 36, 58, 38, const Color(0xFFAC6B51));
    }
    if (id == 'dumbledore') {
      poly([
        const Offset(31, 62),
        const Offset(50, 96),
        const Offset(69, 62),
      ], hair);
      poly([
        const Offset(24, 30),
        const Offset(50, 4),
        const Offset(76, 30),
      ], const Color(0xFF7D6CB2));
    }
    if ({'luffy', 'law', 'chopper', 'usopp', 'brook'}.contains(id)) {
      final hat = id == 'luffy'
          ? gold
          : id == 'chopper'
          ? const Color(0xFFE274A3)
          : id == 'law'
          ? const Color(0xFFF3EFDB)
          : dark;
      rect(27, 19, 46, 21, hat);
      oval(17, 32, 66, 9, hat);
      if (id == 'luffy') rect(27, 29, 46, 5, const Color(0xFFBA3343));
      if (id == 'chopper') {
        line(44, 24, 56, 36, Colors.white, 4);
        line(56, 24, 44, 36, Colors.white, 4);
      }
      if (id == 'law') {
        for (var i = 0; i < 5; i++) {
          oval(31 + i * 8, 23 + (i % 2) * 6, 4, 4, dark);
        }
      }
    }
    if (id == 'doc') {
      rect(28, 35, 44, 11, const Color(0xFFB2DDF5));
      line(49, 36, 49, 45, dark);
    }
    if (id == 'wonderwoman') {
      poly([
        const Offset(29, 33),
        const Offset(50, 39),
        const Offset(71, 33),
        const Offset(70, 41),
        const Offset(50, 45),
        const Offset(30, 41),
      ], gold);
      oval(47, 37, 6, 6, const Color(0xFFCF334C));
    }
    if (id == 'naruto') {
      rect(26, 33, 48, 10, const Color(0xFF343B5D));
      rect(39, 34, 22, 8, const Color(0xFFCFD3DD));
      for (var i = 0; i < 3; i++) {
        line(31, 55 + i * 4, 39, 57 + i * 3, dark, 1);
        line(61, 57 + i * 3, 69, 55 + i * 4, dark, 1);
      }
    }
    if (id == 'superman') {
      poly([
        const Offset(35, 82),
        const Offset(65, 82),
        const Offset(50, 97),
      ], gold);
      final t = TextPainter(
        text: const TextSpan(
          text: 'S',
          style: TextStyle(
            color: Color(0xFFC93648),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(c, const Offset(45, 79));
    }
    if (id == 'marty') {
      rect(27, 78, 12, 25, const Color(0xFFEF644C));
      rect(61, 78, 12, 25, const Color(0xFFEF644C));
    }
    if (id == 'jinbe') {
      poly([
        const Offset(38, 62),
        const Offset(42, 53),
        const Offset(45, 64),
      ], Colors.white);
      poly([
        const Offset(55, 64),
        const Offset(58, 53),
        const Offset(62, 62),
      ], Colors.white);
    }
    if (id == 'robin') {
      line(32, 33, 46, 31, const Color(0xFFB9D3EE), 3);
      line(54, 31, 68, 33, const Color(0xFFB9D3EE), 3);
    }
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter oldDelegate) =>
      oldDelegate.id != id;
}
