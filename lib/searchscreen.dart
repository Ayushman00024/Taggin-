// lib/search_screen.dart
// 🌙 Dark Mode Search Screen with Swipe Navigation (Campus / City / NearbyMe)

import 'package:flutter/material.dart';
import 'searchicon.dart'; // toggle widget
import 'search_campus.dart';
import 'search_city.dart';
import 'nearbyme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  PeopleScope _current = PeopleScope.myCampus; // default
  final PageController _pageController = PageController(initialPage: 0);

  int _getIndexFromScope(PeopleScope scope) {
    switch (scope) {
      case PeopleScope.myCampus:
        return 0;
      case PeopleScope.myCity:
        return 1;
      case PeopleScope.nearbyMe:
        return 2;
    }
  }

  PeopleScope _getScopeFromIndex(int index) {
    switch (index) {
      case 0:
        return PeopleScope.myCampus;
      case 1:
        return PeopleScope.myCity;
      case 2:
        return PeopleScope.nearbyMe;
      default:
        return PeopleScope.myCampus;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D0D0D),
        elevation: 0,
        centerTitle: true,
        title: SearchToggle(
          current: _current,
          onChanged: (scope) {
            setState(() {
              _current = scope;
            });
            // Animate to selected page when toggle is pressed
            _pageController.animateToPage(
              _getIndexFromScope(scope),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        ),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _current = _getScopeFromIndex(index);
          });
        },
        children: const [
          SearchCampusScreen(),
          SearchCityScreen(),
          NearbyMeScreen(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
