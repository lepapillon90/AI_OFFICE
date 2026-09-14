import 'package:flame/components.dart';

/// Empty first-floor scene while its redesigned map is being produced.
///
/// Keeping this scene explicit lets the rest of the app still switch floors
/// without rendering the retired first-floor artwork.
class IsoLobbyScene {
  List<Component> createComponents() => const [];
}
