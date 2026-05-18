import 'harmony_wedge.dart';
import 'harmony_state.dart';

class HarmonyCompetency {
  final String id;

  final String title;

  final String centerIcon;

  final Map<HarmonyWedge, HarmonyState>
  wedges;

  HarmonyCompetency({
    required this.id,
    required this.title,
    required this.centerIcon,
    required this.wedges,
  });

  factory HarmonyCompetency.empty({
    required String id,
    required String title,
    required String centerIcon,
  }) {
    return HarmonyCompetency(
      id: id,
      title: title,
      centerIcon: centerIcon,

      wedges: {
        for (
          final wedge
              in HarmonyWedge.values
        )
          wedge:
              HarmonyState
                  .incomplete,
      },
    );
  }
}