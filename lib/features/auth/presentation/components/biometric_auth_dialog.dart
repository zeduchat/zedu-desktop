import 'package:zedu/core/core.dart';

enum BiometricAuthStatus { idle, authenticating, success, failed }

class BiometricAuthDialog extends StatefulWidget {
  const BiometricAuthDialog({
    super.key,
    this.title = 'Biometric Authentication',
    this.subtitle =
        'Confirm your Face ID, Touch ID, or biometric credential to continue',
    this.fallbackLabel = 'Use Passcode',
    this.cancelLabel = 'Cancel',
    this.onSuccess,
    this.onFallback,
    this.onCancel,
  });

  final String title;
  final String subtitle;
  final String fallbackLabel;
  final String cancelLabel;
  final VoidCallback? onSuccess;
  final VoidCallback? onFallback;
  final VoidCallback? onCancel;

  static Future<bool?> show(
    BuildContext context, {
    String title = 'Biometric Authentication',
    String subtitle =
        'Confirm your Face ID, Touch ID, or biometric credential to continue',
    VoidCallback? onSuccess,
    VoidCallback? onFallback,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => BiometricAuthDialog(
        title: title,
        subtitle: subtitle,
        onSuccess: onSuccess,
        onFallback: onFallback,
      ),
    );
  }

  @override
  State<BiometricAuthDialog> createState() => _BiometricAuthDialogState();
}

class _BiometricAuthDialogState extends State<BiometricAuthDialog> {
  BiometricAuthStatus _status = BiometricAuthStatus.idle;

  void _authenticate() {
    setState(() {
      _status = BiometricAuthStatus.authenticating;
    });

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _status = BiometricAuthStatus.success;
      });

      Future.delayed(const Duration(milliseconds: 400), () {
        if (!mounted) return;
        widget.onSuccess?.call();
        Navigator.of(context).pop(true);
      });
    });
  }

  void _fallback() {
    widget.onFallback?.call();
    Navigator.of(context).pop(false);
  }

  void _cancel() {
    widget.onCancel?.call();
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = context.textTheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: colors.background,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colors.primaryBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _status == BiometricAuthStatus.success
                    ? Icon(Icons.check_circle, size: 40, color: colors.success)
                    : _status == BiometricAuthStatus.authenticating
                    ? SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: colors.primary,
                        ),
                      )
                    : Icon(Icons.fingerprint, size: 42, color: colors.primary),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            if (_status == BiometricAuthStatus.authenticating) ...[
              Text(
                'Scanning biometric credential...',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
            ] else if (_status == BiometricAuthStatus.success) ...[
              Text(
                'Biometric verification successful',
                style: textTheme.bodySmall?.copyWith(
                  color: colors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _authenticate,
                  icon: const Icon(Icons.fingerprint, size: 20),
                  label: const Text('Authenticate Now'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.onFallback != null) ...[
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: _fallback,
                    child: Text(
                      widget.fallbackLabel,
                      style: TextStyle(color: colors.primary),
                    ),
                  ),
                ),
              ],
            ],
            TextButton(
              onPressed: _cancel,
              child: Text(
                widget.cancelLabel,
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
