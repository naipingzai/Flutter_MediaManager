import 'package:flutter_media_view/ui/common/extensions_build_context.dart';
import 'package:fmv_model/flutter_media_view_model.dart';
import 'package:flutter/widgets.dart';

extension ExtraVaultLockTypeView on VaultLockType {
  String getText(BuildContext context) {
    final l10n = context.l10n;
    return switch (this) {
      VaultLockType.system => l10n.settingsSystemDefault,
      VaultLockType.pattern => l10n.vaultLockTypePattern,
      VaultLockType.pin => l10n.vaultLockTypePin,
      VaultLockType.password => l10n.vaultLockTypePassword,
    };
  }
}
