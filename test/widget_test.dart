import 'package:emoji_container/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches setup screen when no root configured',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EmojiContainerApp());
    await tester.pumpAndSettle();

    expect(find.text('表情包管理器'), findsOneWidget);
    expect(find.text('浏览选择文件夹'), findsOneWidget);
  });
}
