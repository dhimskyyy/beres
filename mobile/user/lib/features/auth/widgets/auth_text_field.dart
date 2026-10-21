import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final String label;
  final String hintText;
  final TextEditingController controller;
  final bool isPassword;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final TextInputType keyboardType;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final bool enabled;

  const AuthTextField({
    super.key,
    required this.label,
    required this.hintText,
    required this.controller,
    this.isPassword = false,
    this.obscureText = false,
    this.onToggleObscure,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.validator,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9), // Soft pill background
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword ? obscureText : false,
            keyboardType: keyboardType,
            enabled: enabled,
            validator: validator,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hintText,
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.normal,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: Color(0xFF16397E),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: Color(0xFFDC2626),
                  width: 1.5,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(
                  color: Color(0xFFDC2626),
                  width: 1.5,
                ),
              ),
              prefixIcon: prefixIcon != null
                  ? Icon(
                      prefixIcon,
                      size: 20,
                      color: const Color(0xFF64748B),
                    )
                  : null,
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: const Color(0xFF64748B),
                      ),
                      onPressed: onToggleObscure,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
