import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_strings.dart';
import '../services/localization_service.dart';

void showHowToPlayDialog(BuildContext context, Map<String, String> description) {
  final localization = context.read<LocalizationService>();

  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(localization.translate(AppStrings.howToPlay)),
      content: SingleChildScrollView(
        child: Text(localization.translate(description)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(localization.translate(AppStrings.close)),
        ),
      ],
    ),
  );
}
