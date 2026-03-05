import 'package:flutter/material.dart';

class ConfirmDialog {
  Widget build(BuildContext context, String title, String subtitle,
      String cancelText, String okText) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(title),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [Text(subtitle)],
      ),
      actions: [
        TextButton(
            style: TextButton.styleFrom(foregroundColor: scheme.primary),
            onPressed: () {
              Navigator.pop(context, false);
            },
            child: Text(cancelText)),
        TextButton(
            onPressed: () {
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(foregroundColor: scheme.error),
            child: Text(okText)),
      ],
    );
  }
}
