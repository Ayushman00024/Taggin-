import 'package:flutter/material.dart';
import 'search_city.dart';
import 'search_campus.dart';

enum PeopleScope { yourCity, myCampus }

class SearchScopePill extends StatelessWidget {
  final PeopleScope current;
  const SearchScopePill({Key? key, required this.current}) : super(key: key);

  String _label(PeopleScope s) =>
      s == PeopleScope.yourCity ? 'Your City' : 'My Campus';

  void _goTo(BuildContext context, PeopleScope dest) {
    if (dest == PeopleScope.yourCity) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SearchCityScreen()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SearchCampusScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = GlobalKey();
    return GestureDetector(
      key: key,
      onTapDown: (details) async {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        final size = box?.size ?? const Size(120, 36);

        final chosen = await showMenu<PeopleScope>(
          context: context,
          position: RelativeRect.fromLTRB(
            details.globalPosition.dx,
            details.globalPosition.dy + size.height,
            details.globalPosition.dx + size.width,
            details.globalPosition.dy,
          ),
          items: const [
            PopupMenuItem(
              value: PeopleScope.yourCity,
              child: Row(children: [
                Icon(Icons.location_city_outlined, size: 18),
                SizedBox(width: 8),
                Text('Your City'),
              ]),
            ),
            PopupMenuItem(
              value: PeopleScope.myCampus,
              child: Row(children: [
                Icon(Icons.school_outlined, size: 18),
                SizedBox(width: 8),
                Text('My Campus'),
              ]),
            ),
          ],
        );

        if (chosen != null && chosen != current) {
          _goTo(context, chosen); // always navigate
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F3F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.black.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.expand_more, size: 18, color: Colors.black87),
            const SizedBox(width: 6),
            Text(
              _label(current),
              style: const TextStyle(
                  color: Colors.black87, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
