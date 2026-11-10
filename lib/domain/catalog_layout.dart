import 'models.dart';

int effectiveCatalogColumns(
  AppSettings settings,
  double width,
  double spacing,
  int automatic,
) {
  if (settings.catalogColumns == 0) return automatic;
  final maximum = ((width + spacing) / (90 + spacing)).floor().clamp(1, 12);
  return settings.catalogColumns.clamp(1, maximum);
}
