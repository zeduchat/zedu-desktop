import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class BillingSection extends ConsumerStatefulWidget {
  const BillingSection({
    super.key,
    required this.billing,
    required this.onInvite,
    required this.onComparePlans,
  });

  final BillingInfo billing;
  final Future<void> Function({required String email, required String role})
  onInvite;
  final VoidCallback onComparePlans;

  @override
  ConsumerState<BillingSection> createState() => _BillingSectionState();
}

class _BillingSectionState extends ConsumerState<BillingSection> {
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Your Organization Billing Information',
          style: context.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Securely manage your organization\'s billing details, payment history, and subscriptions.',
          style: context.textTheme.bodyMedium?.copyWith(
            color: colors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 32),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: colors.primaryBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final planSummary = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.billing.plan,
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.billing.description,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary.withValues(alpha: 0.6),
                      height: 1.4,
                    ),
                  ),
                ],
              );
              final actions = Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () =>
                        showInviteMemberDialog(context, widget.onInvite),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.primary,
                      side: BorderSide(color: colors.borderOutline),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Invite People',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton(
                    onPressed: widget.onComparePlans,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: const Text(
                      'Compare Plans',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              );

              if (constraints.maxWidth < 680) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [planSummary, const SizedBox(height: 20), actions],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: planSummary),
                  const SizedBox(width: 24),
                  actions,
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 48),
        Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.primary, width: 2)),
          ),
          child: Text(
            'Payment history',
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(height: 1, color: colors.divider),
        const SizedBox(height: 48),
        if (widget.billing.paymentHistory.isNotEmpty) ...[
          ...widget.billing.paymentHistory.map((record) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: colors.divider, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      record.description,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      record.amount,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      record.date,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      record.status,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: record.status.toLowerCase() == 'completed'
                            ? colors.success
                            : colors.accent,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ] else ...[
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: colors.textSecondary.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'No payment history found.',
                  style: context.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your payment and transaction history will appear here once you start using paid features.',
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
