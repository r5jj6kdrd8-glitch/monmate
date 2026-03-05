import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mongo_mate/schemas/connection.dart';
import 'package:mongo_mate/schemas/selectable.dart';

class SingleConnection extends StatelessWidget {
  final Function(int, SelectType) onClick;
  final int index;
  final bool isAnySelected;
  final Selectable<Connection> selectable;

  String _obfuscateUri(String uri) {
    final match = RegExp(r'(://[^:]+:)([^@]+)(@)').firstMatch(uri);
    if (match == null) return uri;

    return uri.replaceRange(match.start + match.group(1)!.length,
        match.end - match.group(3)!.length, '*' * match.group(2)!.length);
  }

  const SingleConnection(
      this.index, this.selectable, this.isAnySelected, this.onClick,
      {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selectable.isSelected ? scheme.primary : null,
      child: ListTile(
        selected: selectable.isSelected,
        contentPadding: const EdgeInsets.fromLTRB(10, 10, 16, 10),
        selectedColor: scheme.onPrimary,
        minLeadingWidth: 12,
        horizontalTitleGap: 8,
        leading: ReorderableDragStartListener(
          index: index,
          child: SizedBox(
            width: 24,
            child: Icon(Icons.drag_handle,
                size: 20,
                color: selectable.isSelected
                    ? scheme.onPrimary.withValues(alpha: 0.86)
                    : scheme.onSurfaceVariant),
          ),
        ),
        onTap: () => onClick(index, SelectType.tap),
        onLongPress: () => onClick(index, SelectType.longPress),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              CupertinoIcons.cube_box_fill,
              color: selectable.isSelected ? scheme.onPrimary : scheme.primary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selectable.item.name,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                maxLines: 1,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: selectable.isSelected ? scheme.onPrimary : null,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          _obfuscateUri(selectable.item.uri),
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          maxLines: 1,
          style: TextStyle(
            color: selectable.isSelected
                ? scheme.onPrimary.withValues(alpha: 0.85)
                : scheme.onSurfaceVariant,
          ),
        ),
        trailing: selectable.isSelected
            ? Icon(CupertinoIcons.check_mark_circled_solid,
                color: scheme.onPrimary)
            : (isAnySelected
                ? Icon(CupertinoIcons.circle, color: scheme.outline)
                : null),
      ),
    );
  }
}
