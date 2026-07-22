/// Fixed palette of ARGB colour values used for activities and fixed blocks.
///
/// Stored as plain ints in the database and reconstructed with `Color(value)`
/// so we never depend on (potentially deprecated) `Color.value`.
const List<int> kPalette = [
  0xFF5C6BC0, // indigo
  0xFF26A69A, // teal
  0xFFEF5350, // red
  0xFFFFA726, // orange
  0xFF66BB6A, // green
  0xFFAB47BC, // purple
  0xFF42A5F5, // blue
  0xFF8D6E63, // brown
];

/// A stable default colour for work blocks.
const int kWorkColor = 0xFF78909C; // blue grey
