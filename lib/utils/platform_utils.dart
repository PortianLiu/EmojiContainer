import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

bool get isMobile =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

bool get isDesktop =>
    !kIsWeb &&
    (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

bool get supportsOutboundDrag => isDesktop;

bool get supportsSystemShare => isMobile;
