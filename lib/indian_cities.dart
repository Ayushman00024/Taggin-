import 'package:flutter/material.dart';

// Expanded Indian cities list with Haryana, UP, Uttarakhand, and North Indian cities
const List<String> indianCities = [
  // Tier 1
  'Delhi Ncr', 'Mumbai', 'Bengaluru', 'Chennai', 'Kolkata', 'Hyderabad', 'Pune', 'Ahmedabad',

  // Haryana cities (excluding Gurugram)
  'Ambala', 'Faridabad', 'Hisar', 'Panipat', 'Karnal', 'Sonipat', 'Yamunanagar', 'Rewari',

  // Noida and nearby UP cities
  'Noida', 'Greater Noida', 'Ghaziabad',

  // Additional Uttar Pradesh cities
  'Lucknow', 'Kanpur', 'Prayagraj', 'Varanasi', 'Agra', 'Meerut', 'Aligarh', 'Bareilly', 'Moradabad', 'Saharanpur',

  // Uttarakhand cities
  'Dehradun', 'Haridwar', 'Rishikesh', 'Haldwani', 'Nainital', 'Roorkee', 'Kashipur', 'Udham Singh Nagar',

  // Other Tier 2 and famous cities
  'Surat', 'Jaipur', 'Nagpur', 'Indore', 'Bhopal', 'Visakhapatnam', 'Patna', 'Vadodara',
  'Ludhiana', 'Nashik', 'Rajkot', 'Kalyan-Dombivali', 'Vasai-Virar', 'Srinagar',
  'Aurangabad', 'Dhanbad', 'Amritsar', 'Navi Mumbai', 'Ranchi', 'Howrah', 'Coimbatore',
  'Jabalpur', 'Gwalior', 'Vijayawada', 'Jodhpur', 'Madurai', 'Raipur', 'Kota',

  // More famous cities added
  'Thane', 'Bhilai', 'Tiruchirappalli', 'Mysore', 'Tiruppur', 'Guntur', 'Jamshedpur', 'Hubli', 'Salem', 'Warangal',

  // More North Indian cities
  'Chandigarh', 'Shimla', 'Jammu', 'Srinagar', 'Patiala', 'Amritsar', 'Dehradun',
];

class CityDropdown extends StatelessWidget {
  final String? value;
  final ValueChanged<String?> onChanged;

  const CityDropdown({Key? key, required this.value, required this.onChanged}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: (value != null && indianCities.contains(value)) ? value : null,
      items: indianCities.map((city) => DropdownMenuItem(
        value: city,
        child: Text(city, style: const TextStyle(color: Colors.white)),
      )).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: "Select City",
        labelStyle: const TextStyle(color: Colors.white70),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Colors.white24),
        ),
        filled: true,
        fillColor: Colors.white10,
      ),
      dropdownColor: Colors.grey[900],
      style: const TextStyle(color: Colors.white),
    );
  }
}
