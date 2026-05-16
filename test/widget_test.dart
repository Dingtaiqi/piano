import 'package:flutter_test/flutter_test.dart';
import 'package:eda_piano/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const PianoApp());
    await tester.pump();
    expect(find.text('EDA 电子琴'), findsOneWidget);
  });
}
