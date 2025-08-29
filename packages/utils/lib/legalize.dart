// https://pub.dev/packages/legalize/versions/1.2.1
// https://github.com/Caesarovich/legalize/blob/c017c44c0077c9a1d91864477d89211fcc3c42ea/lib/src/legalize_base.dart

final reservedWindowsFilenames = [
  'con',
  'prn',
  'aux',
  'nul',
  'com1',
  'com2',
  'com3',
  'com4',
  'com5',
  'com6',
  'com7',
  'com8',
  'com9',
  'lpt1',
  'lpt2',
  'lpt3',
  'lpt4',
  'lpt5',
  'lpt6',
  'lpt7',
  'lpt8',
  'lpt9',
];

/// Checks if the filename is a reserved Windows file name.
bool isReservedWindowsFilename(String filename) {
  return reservedWindowsFilenames.contains(
    filename.toLowerCase().split('.').first,
  );
}

final illegalFATCharactersRegex = RegExp(r'[<>:"/\\|?*]');

/// Checks if the filename contains illegal FAT characters.
bool containsIllegalFATCharacters(String filename) {
  return filename.contains(illegalFATCharactersRegex) ||
      containsControlCharacters(filename);
}

/// Checks if the filename contains illegal Windows characters.
bool containsIllegalWindowsCharacters(String filename) {
  return filename.contains(illegalFATCharactersRegex);
}

final illegalWindowsTrailingCharactersRegex = RegExp(r'[\. ]+$');

/// Checks if the filename contains illegal Windows trailing characters.
bool containsIllegalWindowsTrailingCharacters(String filename) {
  return filename.contains(illegalWindowsTrailingCharactersRegex);
}

final illegalPosixCharactersRegex = RegExp(r'[/]');

/// Checks if the filename contains illegal Posix characters.
bool containsIllegalPosixCharacters(String filename) {
  return filename.contains(illegalPosixCharactersRegex);
}

/// Checks if the filename contains a null character.
bool containsNullCharacter(String filename) {
  return filename.contains(String.fromCharCode(0));
}

final controlCharacterRegex = RegExp(r'[\x00-\x1F\x7F]');

/// Checks if the filename contains a control character.
bool containsControlCharacters(String filename) {
  return filename.contains(controlCharacterRegex);
}

final illegalHFSCharactersRegex = RegExp(r'[/:]');

/// Checks if the filename contains illegal HFS characters.
bool containsIllegalHFSCharacters(String filename) {
  return filename.contains(illegalHFSCharactersRegex);
}

/// Checks if the filename is of valid length.
///
/// The filename must be less than or equal to 255 characters and not empty.
bool isLegalLength(String filename) {
  return filename.length <= 255 && filename.isNotEmpty;
}

/// Checks if the filename is a relative path.
///
/// Returns `true` if filename is "." or "..".
bool isRelativePath(String filename) {
  return filename == '.' || filename == '..';
}

/// Checks if the filename is a valid Windows filename.
///
/// This includes checking for illegal characters, reserved file names, null characters, and length.
bool isValidWindowsFilename(String filename) {
  return isLegalLength(filename) &&
      !containsIllegalWindowsCharacters(filename) &&
      !isReservedWindowsFilename(filename) &&
      !containsNullCharacter(filename) &&
      !isRelativePath(filename);
}

/// Checks if the filename is a valid Posix filename.
///
/// This includes checking for illegal characters and length.
bool isValidPosixFilename(String filename) {
  return isLegalLength(filename) &&
      !containsIllegalPosixCharacters(filename) &&
      !containsNullCharacter(filename) &&
      !isRelativePath(filename);
}

/// Checks if the filename is a valid HFS filename.
///
/// This includes checking for illegal characters and length.
bool isValidHFSFilename(String filename) {
  return isLegalLength(filename) &&
      !containsIllegalHFSCharacters(filename) &&
      !isRelativePath(filename);
}

/// Checks if the filename is a valid FAT filename.
///
/// This includes checking for illegal characters and length.
bool isValidFATFilename(String filename) {
  return isLegalLength(filename) &&
      !containsIllegalFATCharacters(filename) &&
      !containsNullCharacter(filename) &&
      !isRelativePath(filename);
}

/// Checks if the filename is valid for all systems.
bool isValidUniversalFilename(String filename) {
  return isValidPosixFilename(filename) &&
      isValidWindowsFilename(filename) &&
      isValidHFSFilename(filename);
}

/// Checks if the filename is valid for a given system.
///
/// [os] is used to determine the system. Its values can be any of "android" "fuchsia" "ios" "linux" "macos" "windows".
/// If the system is unspecified or recognized, [isValidUniversalFilename] will be used.
bool isValidFilename(String filename, {String? os}) {
  switch (os) {
    case 'windows':
      return isValidWindowsFilename(filename);
    case 'ios':
    case 'macos':
      return isValidHFSFilename(filename);
    case 'android':
      return isValidFATFilename(filename);
    case 'linux':
      return isValidPosixFilename(filename);
    case 'fuchsia':
    default:
      return isValidUniversalFilename(filename);
  }
}

/// Sanitizes the filename for Windows systems.
///
/// [replacement] is used to replace illegal characters.
/// If the filename is empty after sanitization, it will be replaced with [placeholder].
/// It is recommended to not use an empty [replacement] and an empty [placeholder] as it may result in an empty filename.
String legalizeWindowsFilename(
  String filename, {
  String replacement = '_',
  String placeholder = 'untitled',
}) {
  var result = filename;

  // Replace control characters
  result = result.replaceAll(controlCharacterRegex, replacement);

  // Replace illegal characters
  result = result.replaceAll(illegalFATCharactersRegex, replacement);

  // Replace trailing illegal characters
  result = result.replaceAll(
    illegalWindowsTrailingCharactersRegex,
    replacement,
  );

  // Replace reserved file names
  if (isReservedWindowsFilename(result)) {
    for (var reserved in reservedWindowsFilenames) {
      if (result.toLowerCase().startsWith(reserved)) {
        result = replacement + result.substring(reserved.length);
        break;
      }
    }
  }

  // If the filename is empty, replace it with a placeholder
  if (result.isEmpty || isRelativePath(result)) {
    result = placeholder;
  }

  // Check length
  if (result.length > 255) {
    result = result.substring(0, 255);
  }

  return result;
}

/// Sanitizes the filename for FAT systems.
///
/// [replacement] is used to replace illegal characters.
/// If the filename is empty after sanitization, it will be replaced with [placeholder].
/// It is recommended to not use an empty [replacement] and an empty [placeholder] as it may result in an empty filename.
String legalizeFATFilename(
  String filename, {
  String replacement = '_',
  String placeholder = 'untitled',
}) {
  var result = filename;

  result = result.replaceAll(controlCharacterRegex, replacement);

  // Replace illegal characters
  result = result.replaceAll(illegalFATCharactersRegex, replacement);

  // If the filename is empty, replace it with a placeholder
  if (result.isEmpty || isRelativePath(result)) {
    result = placeholder;
  }

  // Check length
  if (result.length > 255) {
    result = result.substring(0, 255);
  }

  return result;
}

/// Sanitizes the filename for Posix systems.
///
/// [replacement] is used to replace illegal characters.
/// If the filename is empty after sanitization, it will be replaced with [placeholder].
/// It is recommended to not use an empty [replacement] and an empty [placeholder] as it may result in an empty filename.
/// [shouldReplaceControlCharacters] determines whether control characters should be replaced. Default is true.
String legalizePosixFilename(
  String filename, {
  String replacement = '_',
  String placeholder = 'untitled',
  bool shouldReplaceControlCharacters = true,
}) {
  var result = filename;

  // Replace null characters
  result = result.replaceAll(String.fromCharCode(0), replacement);

  // Replace control characters
  if (shouldReplaceControlCharacters) {
    result = result.replaceAll(controlCharacterRegex, replacement);
  }

  // Replace illegal characters
  result = result.replaceAll(illegalPosixCharactersRegex, replacement);

  // If the filename is empty, replace it with a placeholder
  if (result.isEmpty || isRelativePath(result)) {
    result = placeholder;
  }

  // Check length
  if (result.length > 255) {
    result = result.substring(0, 255);
  }

  return result;
}

/// Legalizes the filename for HFS systems.
///
/// [replacement] is used to replace illegal characters.
/// If the filename is empty after sanitization, it will be replaced with [placeholder].
/// It is recommended to not use an empty [replacement] and an empty [placeholder] as it may result in an empty filename.
/// [shouldReplaceControlCharacters] determines whether control characters should be replaced. Default is true.
String legalizeHFSFilename(
  String filename, {
  String replacement = '_',
  String placeholder = 'untitled',
  bool shouldReplaceControlCharacters = true,
}) {
  var result = filename;

  // Replace null characters
  result = result.replaceAll(String.fromCharCode(0), replacement);

  // Replace control characters
  if (shouldReplaceControlCharacters) {
    result = result.replaceAll(controlCharacterRegex, replacement);
  }

  // Replace illegal characters
  result = result.replaceAll(illegalHFSCharactersRegex, replacement);

  // If the filename is empty, replace it with a placeholder
  if (result.isEmpty || isRelativePath(result)) {
    result = placeholder;
  }

  // Check length
  if (result.length > 255) {
    result = result.substring(0, 255);
  }

  return result;
}

/// Sanitizes the filename for both Windows and Posix systems.
///
/// This function is a combination of [legalizeWindowsFilename], [legalizePosixFilename] and [legalizeHFSFilename].
/// [replacement] is used to replace illegal characters.
/// If the filename is empty after sanitization, it will be replaced with [placeholder].
/// It is recommended to not use an empty [replacement] and an empty [placeholder] as it may result in an empty filename.
String legalizeFilenameUniversal(
  String filename, {
  String replacement = '_',
  String placeholder = 'untitled',
}) {
  var result = filename;

  result = legalizeWindowsFilename(
    result,
    replacement: replacement,
    placeholder: placeholder,
  );
  result = legalizePosixFilename(
    result,
    replacement: replacement,
    placeholder: placeholder,
  );
  result = legalizeHFSFilename(
    result,
    replacement: replacement,
    placeholder: placeholder,
  );

  return result;
}

/// Sanitizes the filename for a given system.
///
/// [os] is used to determine the system. Its values can be any of "android" "fuchsia" "ios" "linux" "macos" "windows".
/// If the system is unspecified or recognized, [legalizeFilenameUniversal] will be used.
/// [replacement] is used to replace illegal characters.
/// If the filename is empty after sanitization, it will be replaced with [placeholder].
/// It is recommended to not use an empty [replacement] and an empty [placeholder] as it may result in an empty filename.
String legalizeFilename(
  String filename, {
  String? os,
  String replacement = '_',
  String placeholder = 'untitled',
}) {
  var result = filename;

  switch (os) {
    case 'windows':
      result = legalizeWindowsFilename(
        result,
        replacement: replacement,
        placeholder: placeholder,
      );
      break;
    case 'macos':
    case 'ios':
      result = legalizeHFSFilename(
        result,
        replacement: replacement,
        placeholder: placeholder,
      );
      break;

    case 'android':
      result = legalizeFATFilename(
        result,
        replacement: replacement,
        placeholder: placeholder,
      );
    case 'linux':
      result = legalizePosixFilename(
        result,
        replacement: replacement,
        placeholder: placeholder,
      );
      break;
    case 'fuchsia':
    default:
      result = legalizeFilenameUniversal(
        result,
        replacement: replacement,
        placeholder: placeholder,
      );
  }

  return result;
}
