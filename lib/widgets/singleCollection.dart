import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mongo_mate/schemas/collection.dart';
import 'package:mongo_mate/schemas/selectable.dart';

class SingleCollection extends StatelessWidget {
  final Function(int, SelectType) onClick;
  final int index;
  final bool isAnySelected;
  final Selectable<Collection> selectable;

  const SingleCollection(
      {super.key,
      required this.index,
      required this.selectable,
      required this.isAnySelected,
      required this.onClick});

  String getDocumentText() {
    switch (selectable.item.count) {
      case -2:
        {
          return 'Loading';
        }
      case -1:
        {
          return '';
        }
      case 0:
        {
          return '0';
        }
      case 1:
        {
          return '1';
        }
      default:
        {
          return '${selectable.item.count}';
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: selectable.isSelected ? scheme.primary : null,
      child: ListTile(
        selected: selectable.isSelected,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
        selectedColor: scheme.onPrimary,
        onTap: () => onClick(index, SelectType.tap),
        onLongPress: () => onClick(index, SelectType.longPress),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Icon(
              CupertinoIcons.folder_fill,
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
                    color: selectable.isSelected ? scheme.onPrimary : null),
              ),
            )
          ],
        ),
        subtitle: Row(
          children: [
            if (selectable.item.count >= 0 || selectable.item.count == -2) ...[
              Text(
                getDocumentText(),
                style: TextStyle(
                  color: selectable.isSelected
                      ? scheme.onPrimary.withValues(alpha: 0.85)
                      : scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                CupertinoIcons.doc_fill,
                size: 12,
                color: selectable.isSelected
                    ? scheme.onPrimary.withValues(alpha: 0.85)
                    : scheme.onSurfaceVariant,
              ),
            ],
          ],
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
