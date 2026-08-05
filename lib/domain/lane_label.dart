/// How a lane key is written on screen.
///
/// The key itself is never invented and never rewritten for lookup: it is the
/// ROI name from the connector's `config/rois.json`, and every map access still
/// uses it verbatim. This is presentation only — `kota` is the lane, `Arah
/// kota` is how a rider reads it.
///
/// Sentence case throughout, per the layout spec, so a key that arrives
/// capitalised or shouting is normalised rather than passed through.
String laneLabel(String key) {
  final trimmed = key.trim();
  if (trimmed.isEmpty) return 'Lajur';

  // Already phrased as a direction by the backend — leave it alone rather than
  // producing "Arah arah kota".
  final lower = trimmed.toLowerCase();
  if (lower.startsWith('arah ')) {
    return 'Arah ${_sentenceCase(trimmed.substring(5))}';
  }
  return 'Arah ${_sentenceCase(trimmed)}';
}

String _sentenceCase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return trimmed;
  // Only the shape of the first character is decided here; the rest is left as
  // the backend sent it, so a proper noun keeps its capitals.
  return trimmed[0].toLowerCase() + trimmed.substring(1);
}
