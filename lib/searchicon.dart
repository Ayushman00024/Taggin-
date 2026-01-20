// =============================
// 🌙 searchicon.dart (Dark Mode)
// Toggle used in the search screens' AppBar.
// =============================

import 'package:flutter/material.dart';
import 'search_city.dart';
import 'search_campus.dart';
import 'nearbyme.dart';

enum PeopleScope { myCampus, myCity, nearbyMe }

class SearchToggle extends StatelessWidget {
  final PeopleScope current;
  final ValueChanged<PeopleScope>? onChanged;

  const SearchToggle({
    Key? key,
    this.current = PeopleScope.myCampus,
    this.onChanged,
  }) : super(key: key);

  void _go(PeopleScope dest) {
    if (dest == current) return;
    onChanged?.call(dest);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A), // dark background
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Seg(
            label: 'My Campus',
            selected: current == PeopleScope.myCampus,
            onTap: () => _go(PeopleScope.myCampus),
          ),
          _Seg(
            label: 'My City',
            selected: current == PeopleScope.myCity,
            onTap: () => _go(PeopleScope.myCity),
          ),
          _Seg(
            label: 'Nearby Me',
            selected: current == PeopleScope.nearbyMe,
            onTap: () => _go(PeopleScope.nearbyMe),
          ),
        ],
      ),
    );
  }
}

typedef SearchIcon = SearchToggle;

class _Seg extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Seg({
    Key? key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.black : Colors.white70;
    final bg = selected ? Colors.white : Colors.transparent;

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(24),
          boxShadow: selected
              ? [
            BoxShadow(
              color: Colors.white.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ]
              : [],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: fg,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}
