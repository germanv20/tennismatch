import 'package:flutter/material.dart';

/// One cell in a [ProfileStatGrid] — an icon, a bold value, and a small
/// label underneath. Deliberately has no border/background of its own
/// (see [ProfileStatGrid]'s doc comment for why). [icon] is optional: the
/// country cell (Sept 2026 reorder) has no small leading icon at all —
/// it puts a flag emoji directly in [value] and the country name in
/// [label], so the "icon slot" is simply omitted for that cell.
class ProfileStatCell {
  final IconData? icon;
  final String value;
  final String label;
  final Color? color;

  const ProfileStatCell({
    this.icon,
    required this.value,
    required this.label,
    this.color,
  });
}

/// Borderless "icon + big number + small label" stat grid, styled after
/// Duolingo's profile Overview section (Sept 2026 redesign — see CLAUDE.md).
/// Replaces the mix of colored pill badges and plain emoji-prefixed text
/// lines `my_profile_screen.dart`/`player_profile_view_screen.dart` used
/// to render their stats with, which read as visually inconsistent once
/// enough of them were shown at once.
///
/// Takes a list of already-built [ProfileStatCell]s — callers decide which
/// stats are eligible to show (hide-if-zero/absent) before constructing the
/// list, same as the old badges did individually. Renders nothing if the
/// list is empty, so a brand-new profile with no stats yet doesn't leave an
/// empty grid-shaped gap. Cell content is center-aligned (not left-aligned)
/// so the two-column block reads as centered under the profile photo/name
/// above it, rather than hugging the left edge of each column.
class ProfileStatGrid extends StatelessWidget {
  final List<ProfileStatCell> cells;

  const ProfileStatGrid({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return const SizedBox.shrink();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.0,
      mainAxisSpacing: 18,
      crossAxisSpacing: 12,
      children: cells.map((cell) => _StatCell(cell: cell)).toList(),
    );
  }
}

class _StatCell extends StatelessWidget {
  final ProfileStatCell cell;

  const _StatCell({required this.cell});

  @override
  Widget build(BuildContext context) {
    final color = cell.color ?? Colors.green.shade700;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (cell.icon != null) ...[
              Icon(cell.icon, size: 20, color: color),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                cell.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          cell.label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
