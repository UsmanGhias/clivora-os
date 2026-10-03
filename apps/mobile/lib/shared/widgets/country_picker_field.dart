import 'package:flutter/material.dart';

import '../../core/constants/countries.dart';
import '../../core/theme/clivora_colors.dart';

class CountryPickerField extends StatelessWidget {
  const CountryPickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'Country',
    this.required = false,
    this.errorText,
  });

  final String? value;
  final ValueChanged<String> onChanged;
  final String label;
  final bool required;
  final String? errorText;

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountrySearchSheet(initial: value),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ClivoraColors.labelGray,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                  ),
            ),
            if (required)
              const Text(' *', style: TextStyle(color: ClivoraColors.errorRed, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              errorText: errorText,
              suffixIcon: const Icon(Icons.public, color: ClivoraColors.primaryPurple),
            ),
            child: Text(
              (value == null || value!.isEmpty) ? 'Select country' : value!,
              style: TextStyle(
                color: (value == null || value!.isEmpty)
                    ? ClivoraColors.textSecondary
                    : ClivoraColors.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CountrySearchSheet extends StatefulWidget {
  const _CountrySearchSheet({this.initial});

  final String? initial;

  @override
  State<_CountrySearchSheet> createState() => _CountrySearchSheetState();
}

class _CountrySearchSheetState extends State<_CountrySearchSheet> {
  final _search = TextEditingController();
  late List<String> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = List.of(kCountries);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter(String query) {
    setState(() {
      _filtered = kCountries
          .where((c) => c.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: ClivoraColors.borderLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              controller: _search,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search countries...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final country = _filtered[index];
                final selected = country == widget.initial;
                return ListTile(
                  title: Text(country),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: ClivoraColors.primaryPurple)
                      : null,
                  onTap: () => Navigator.pop(context, country),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
