import 'package:flutter/material.dart';

class DOBPickerScreen extends StatefulWidget {
  final void Function(DateTime dob) onDOBSelected;

  const DOBPickerScreen({Key? key, required this.onDOBSelected}) : super(key: key);

  @override
  State<DOBPickerScreen> createState() => _DOBPickerScreenState();
}

class _DOBPickerScreenState extends State<DOBPickerScreen> {
  DateTime? _dob;
  String? _error;

  void _pickDOB() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      // Default to a recent sensible date (e.g., today) since no age restriction
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now, // still block future dates for DOB
      helpText: 'Select your Date of Birth',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: Colors.black87,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dob = picked;
        _error = null;
      });
    }
  }

  void _submit() {
    if (_dob == null) {
      setState(() => _error = "Please select your date of birth.");
      return;
    }
    // ✅ No age check — all age groups allowed
    widget.onDOBSelected(_dob!);
  }

  String _formatDOB(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    // Exactly as requested: dd/mm//yyyy (double slash before year)
    return "$dd/$mm//$yyyy";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Enter Your Date of Birth",
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _pickDOB,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
                  decoration: BoxDecoration(
                    color: Colors.grey[900],
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: Text(
                    _dob == null ? "Select Date of Birth" : _formatDOB(_dob!),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Continue",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
