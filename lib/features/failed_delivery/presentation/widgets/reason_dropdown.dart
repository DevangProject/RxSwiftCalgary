// ============================================================================
// presentation/widgets/reason_dropdown.dart
// ============================================================================

import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/failed_delivery_state.dart';

class ReasonDropdown extends StatelessWidget {
  const ReasonDropdown({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final FailureReason? value;
  final ValueChanged<FailureReason> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Reason', required: true),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: AppColors.textOnPrimary,
            borderRadius: BorderRadius.circular(AppRadius.field),
            border: Border.all(color: AppColors.cardBorder),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<FailureReason>(
              value: value,
              isExpanded: true,
              hint: const Text(
                'Select a reason',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.textSecondary),
              borderRadius: BorderRadius.circular(AppRadius.field),
              items: FailureReason.values
                  .map(
                    (r) => DropdownMenuItem<FailureReason>(
                      value: r,
                      child: Text(
                        r.label,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (r) {
                if (r != null) onChanged(r);
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.danger,
            ),
          ),
      ],
    );
  }
}
