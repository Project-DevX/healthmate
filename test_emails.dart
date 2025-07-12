void main() {
  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  final emails = [
    'citygeneralhospital.admin@gmail.com',
    'johnsmith.cmo@gmail.com',
    'metromedicallab.info@gmail.com',
    'sarahjohnson.director@gmail.com',
    'healthcarepharmacy.contact@gmail.com',
    'mikewilson.pharmacist@gmail.com',
  ];

  print('Testing email validation with regex: ${regex.pattern}');
  print('========================================');

  for (final email in emails) {
    final isValid = regex.hasMatch(email);
    print('$email: ${isValid ? "✅ VALID" : "❌ INVALID"}');
  }
}
