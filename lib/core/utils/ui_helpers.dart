import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../errors/app_failure.dart';
import 'picked_image.dart';

void showErrorSnack(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(AppFailure.from(error).message)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
      ],
    ),
  );
  return ok == true;
}

Future<PickedImage?> pickSingleImage({required double maxWidth}) async {
  final file = await ImagePicker()
      .pickImage(source: ImageSource.gallery, maxWidth: maxWidth, imageQuality: 82);
  if (file == null) return null;
  final name = file.name.toLowerCase();
  final ext = name.endsWith('.png') ? 'png' : name.endsWith('.webp') ? 'webp' : 'jpg';
  return PickedImage(await file.readAsBytes(), ext);
}
