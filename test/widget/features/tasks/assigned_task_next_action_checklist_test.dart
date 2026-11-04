import 'package:zedu/features/tasks/tasks.dart';
import '../../../helpers/helpers.dart';

void main() {
  group('AssignedTaskNextActionChecklist Widget Tests', () {
    testWidgets('renders next action checklist and role selector chips', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestMaterialApp(
          const Scaffold(
            body: AssignedTaskNextActionChecklist(
              input: TaskChecklistStateInput(
                status: 'in_progress',
                substatus: 'in_progress',
                isClaimHolder: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Next Actions & Checklist'), findsOneWidget);
      expect(find.text('Contributor'), findsOneWidget);
      expect(find.text('Reviewer'), findsOneWidget);
      expect(find.text('Triager'), findsOneWidget);
      expect(find.text('Observer'), findsOneWidget);
      expect(find.text('Maintain Claim Heartbeat'), findsOneWidget);
      expect(find.text('Link Open Pull Request'), findsOneWidget);
    });

    testWidgets(
      'switches to Reviewer and displays owner-independence exclusion',
      (tester) async {
        await tester.pumpWidget(
          buildTestMaterialApp(
            const Scaffold(
              body: AssignedTaskNextActionChecklist(
                input: TaskChecklistStateInput(
                  status: 'in_progress',
                  isOwnAgent: true,
                ),
                initialRole: TaskRole.reviewer,
              ),
            ),
          ),
        );

        expect(
          find.text('Owner-Independence Exclusion Active'),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            'Agents owned by the same user account cannot review',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'renders delivery deadline timer badge when deliverBy is present',
      (tester) async {
        final deliverBy = DateTime.now().add(
          const Duration(hours: 2, minutes: 30),
        );

        await tester.pumpWidget(
          buildTestMaterialApp(
            Scaffold(
              body: AssignedTaskNextActionChecklist(
                input: TaskChecklistStateInput(
                  status: 'in_progress',
                  deliverBy: deliverBy,
                ),
              ),
            ),
          ),
        );

        expect(find.textContaining('Deliver by:'), findsOneWidget);
        expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
      },
    );
  });
}
