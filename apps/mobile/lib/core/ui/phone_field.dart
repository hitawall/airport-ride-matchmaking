import "package:flutter/services.dart";
import "package:material_ui/material_ui.dart";
import "../phone.dart";
import "tokens.dart";
import "required_label.dart";

/// A mobile-number field with a country-code picker in front of it. The picker
/// lists [supportedPhoneCountries], which is only India today, so it shows
/// +91 and offers nothing else; more countries appear here as soon as they are
/// added to that list.
class PhoneField extends StatelessWidget {
  const PhoneField({
    required this.controller,
    required this.country,
    required this.onCountryChanged,
    this.errorText,
    this.helperText,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onCountryChanged;
  final String? errorText;
  final String? helperText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: textInputAction,
      autofillHints: const [AutofillHints.telephoneNumberNational],
      // Allow a pasted "+91 98765-43210"; it is normalized on submit.
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r"[0-9+\s\-]"))],
      maxLength: 18,
      buildCounter: (context, {required currentLength, required isFocused, required maxLength}) => null,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        label: const RequiredLabel("Mobile number"),
        hintText: country.example,
        helperText: helperText,
        errorText: errorText,
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md, right: AppSpacing.sm),
          child: _CountryPicker(country: country, onChanged: onCountryChanged),
        ),
      ),
    );
  }
}

class _CountryPicker extends StatelessWidget {
  const _CountryPicker({required this.country, required this.onChanged});

  final PhoneCountry country;
  final ValueChanged<PhoneCountry> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopupMenuButton<PhoneCountry>(
      tooltip: "Country code",
      initialValue: country,
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final option in supportedPhoneCountries)
          PopupMenuItem(value: option, child: Text("${option.name} (${option.label})")),
      ],
      // At least 48 x 48 so it is easy to hit with a thumb.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(country.label, style: textTheme.titleSmall),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
