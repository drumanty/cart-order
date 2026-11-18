
import 'package:flutter_test/flutter_test.dart';
import 'package:cartandorder/main.dart';

void main() {
  testWidgets('Cart And Order app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MyApp), findsOneWidget);
  });
}
