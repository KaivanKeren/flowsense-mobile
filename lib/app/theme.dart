/// The theme, as the rest of the app imports it.
///
/// Everything moved to `lib/theme/` — colours in `colors.dart`, measurements in
/// `tokens.dart`, type roles in `typography.dart`, assembly in
/// `app_theme.dart`. This file is the door those four rooms open onto, so the
/// sixty widgets and four hundred tests that say
/// `import '../../app/theme.dart';` keep working while the design system grows
/// behind it.
///
/// New code may import either this or the specific file it needs. Prefer the
/// specific one: a widget that only needs `FlowSpace` should not be handed the
/// whole palette.
library;

export '../theme/app_theme.dart';
export '../theme/colors.dart';
export '../theme/tokens.dart';
export '../theme/typography.dart';
