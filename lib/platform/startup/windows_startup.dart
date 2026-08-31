import 'dart:typed_data';

import 'package:win32_registry/win32_registry.dart';

import '../../core/diagnostics/tempo_log.dart';

/// The two registry values Windows keeps for "open this when I sign in".
///
/// `launch_at_startup` writes both and reads them back as a single yes or no,
/// which cannot tell *Tempo was never registered* from *the person switched it
/// off in Task Manager*. Tempo has to know the difference: the first is
/// something to put right, the second is a decision to leave alone.
///
/// Nothing here writes. Registering and unregistering stay with the package
/// that owns them; this only reads, so the two can never disagree about how an
/// entry is written.
class WindowsStartupEntry {
  const WindowsStartupEntry._();

  static const String _runPath =
      r'Software\Microsoft\Windows\CurrentVersion\Run';

  static const String _approvedPath =
      r'Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';

  /// The command line registered under [name], or null when there is none.
  static String? command(String name) =>
      _read(_runPath, (RegistryKey key) => key.getStringValue(name));

  /// Whether Windows will actually act on that entry.
  ///
  /// Task Manager's startup list does not remove an entry when it is switched
  /// off — it writes a flag beside it, an odd first byte meaning disabled. No
  /// flag at all means nobody has ever objected.
  static bool approved(String name) {
    final Uint8List? flag = _read(
      _approvedPath,
      (RegistryKey key) => key.getBinaryValue(name),
    );
    if (flag == null || flag.isEmpty) {
      return true;
    }
    return flag.first.isEven;
  }

  /// Opens a key, reads one thing out of it and closes it again. A registry
  /// that will not answer is reported as nothing rather than as a crash: the
  /// caller then treats the entry as missing and writes it afresh.
  static T? _read<T>(String path, T? Function(RegistryKey key) read) {
    RegistryKey? key;
    try {
      key = Registry.openPath(RegistryHive.currentUser, path: path);
      return read(key);
    } on Object catch (error) {
      TempoLog.error('could not read the sign-in entry · $error');
      return null;
    } finally {
      key?.close();
    }
  }
}
