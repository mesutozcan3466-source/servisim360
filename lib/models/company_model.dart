class CompanyModel {
  final String id;
  final String name;
  final String code;
  final String status;
  final String adminEmail;
  final String adminPhone;

  CompanyModel({
    required this.id,
    required this.name,
    required this.code,
    required this.status,
    required this.adminEmail,
    required this.adminPhone,
  });

  factory CompanyModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CompanyModel(
      id: id,
      name: data['name'] ?? '',
      code: data['code'] ?? '',
      status: data['status'] ?? 'aktif',
      adminEmail: data['adminEmail'] ?? '',
      adminPhone: data['adminPhone'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'code': code,
      'status': status,
      'adminEmail': adminEmail,
      'adminPhone': adminPhone,
    };
  }
}
