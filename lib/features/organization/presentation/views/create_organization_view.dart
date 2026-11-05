import 'package:zedu/core/core.dart';
import 'package:zedu/features/features.dart';

class CreateOrganizationView extends ConsumerStatefulWidget {
  const CreateOrganizationView({super.key});

  @override
  ConsumerState<CreateOrganizationView> createState() =>
      _CreateOrganizationViewState();
}

class _CreateOrganizationViewState
    extends ConsumerState<CreateOrganizationView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _typeController = TextEditingController();
  String? _selectedCountry;

  // Complete list of countries from central registry
  static const List<String> _countries = [...kCountries, 'Other'];

  @override
  void dispose() {
    _nameController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountry == null || _selectedCountry!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a country.'),
          backgroundColor: context.colors.error,
        ),
      );
      return;
    }

    final notifier = ref.read(userProfileNotifierProvider.notifier);

    // Simulate loading state locally before notifying the user
    setState(() {}); // trigger rebuild if we had a local loading state

    // The creation method will update the state
    await notifier.createOrganization(
      name: _nameController.text.trim(),
      type: _typeController.text.trim(),
      country: _selectedCountry!,
    );

    if (!mounted) return;

    final state = ref.read(userProfileNotifierProvider);
    if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: context.colors.error,
        ),
      );
    } else if (state.organization != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Organization created!'),
            ],
          ),
          backgroundColor: context.colors.success,
        ),
      );
      context.go(AppRouter.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final state = ref.watch(userProfileNotifierProvider);
    final isLoading = state.isSaving;

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Create Your Organization',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Input the details of your organization below',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: colors.textHint),
                  ),
                  const SizedBox(height: 48),

                  // Organization Name
                  Text(
                    'Organization Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      hintText: 'Enter your organization name',
                      hintStyle: TextStyle(color: colors.textHint),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Organization name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Organization Type
                  Text(
                    'Organization Type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _typeController,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      hintText: 'What does your organization do?',
                      hintStyle: TextStyle(color: colors.textHint),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.divider),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.divider),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: colors.primary),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Organization type is required';
                      }
                      if (value.length > 200) {
                        return 'Cannot exceed 200 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Country
                  Text(
                    'Country',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  FormField<String>(
                    initialValue: _selectedCountry,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Country is required';
                      }
                      return null;
                    },
                    builder: (field) {
                      OutlineInputBorder border(Color color) =>
                          OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: color),
                          );

                      return DropdownMenu<String>(
                        expandedInsets: EdgeInsets
                            .zero, // fill the same width as the other fields
                        enabled: !isLoading,
                        initialSelection: _selectedCountry,
                        hintText: 'Select an option...',
                        menuHeight: 240,
                        requestFocusOnTap:
                            false, // behave like a plain dropdown, no typing
                        errorText: field.errorText,
                        inputDecorationTheme: InputDecorationTheme(
                          hintStyle: TextStyle(color: colors.textHint),
                          filled: true,
                          fillColor: Colors.white,
                          border: border(colors.divider),
                          enabledBorder: border(colors.divider),
                          focusedBorder: border(colors.primary),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        dropdownMenuEntries: _countries
                            .map(
                              (c) =>
                                  DropdownMenuEntry<String>(value: c, label: c),
                            )
                            .toList(),
                        onSelected: (val) {
                          setState(() => _selectedCountry = val);
                          field.didChange(val);
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 48),

                  // Submit Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: colors.primary.withValues(
                        alpha: 0.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
