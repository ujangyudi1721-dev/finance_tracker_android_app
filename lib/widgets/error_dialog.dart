import 'package:flutter/material.dart';

/// Shows an error in a window. The text stays on the screen,
/// and you can press and hold it to select and copy it.
Future<void> showErrorDialog(BuildContext context, String title, Object error) {
  return showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: SelectableText('$error')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Tutup'),
        ),
      ],
    ),
  );
}