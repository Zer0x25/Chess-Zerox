import 'package:flutter/foundation.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:lichess_mobile/src/model/auth/auth_repository.dart';
import 'package:lichess_mobile/src/network/http.dart';
import 'package:lichess_mobile/src/utils/l10n_context.dart';
import 'package:lichess_mobile/src/widgets/feedback.dart';
import 'package:material_ui/material_ui.dart';

/// Shows an error snackbar when the sign-in [signInMutation] fails.
///
/// Meant to be used as the listener of `ref.listen(signInMutation, ...)`.
void showSignInErrorSnackBar(BuildContext context, MutationState<void> state) {
  if (state case MutationError(:final error) when error is! SignInCancelledException) {
    final diagnostic = switch (error) {
      FlutterAppAuthPlatformException(:final platformErrorDetails) =>
        'OAuth ${int.tryParse(platformErrorDetails.type ?? '') ?? -1}/'
            '${int.tryParse(platformErrorDetails.code ?? '') ?? -1}',
      ServerException(:final statusCode) => 'HTTP $statusCode',
      _ => 'other',
    };
    if (kDebugMode) debugPrint('Sign-in diagnostic: $diagnostic');
    showSnackBar(
      context,
      kDebugMode
          ? '${context.l10n.mobileSomethingWentWrong} ($diagnostic)'
          : context.l10n.mobileSomethingWentWrong,
      type: SnackBarType.error,
    );
  }
}
