class AuditLogEntry {
  final String id;
  final String? userId;
  final String title;
  final String? ipAddress;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.userId,
    required this.title,
    required this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogEntry.fromMap(Map<String, dynamic> map) {
    final eventType =
        map['eventType']?.toString() ??
        map['event_type']?.toString() ??
        'unknown';
    final metadata = map['metadata'];
    var title = eventType;
    if (metadata is Map) {
      final actionKey = metadata['actionKey'];
      if (actionKey is String && actionKey.isNotEmpty) {
        title = '$eventType ($actionKey)';
      }
    }

    final createdRaw = map['createdAt'] ?? map['created_at'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : DateTime.now();

    return AuditLogEntry(
      id: map['id']?.toString() ?? '',
      userId: map['userId']?.toString() ?? map['user_id']?.toString(),
      title: title,
      ipAddress: map['ipAddress']?.toString() ?? map['ip_address']?.toString(),
      createdAt: createdAt,
    );
  }
}

class AccessActionResult {
  final String message;
  final AuditLogEntry? event;

  const AccessActionResult({required this.message, this.event});
}

class UserSummary {
  final String id;
  final String? email;
  final String? displayName;
  final String role;
  final DateTime? createdAt;

  const UserSummary({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
  });

  factory UserSummary.fromMap(Map<String, dynamic> map) {
    final rawCreated = map['createdAt'] ?? map['created_at'];
    return UserSummary(
      id: map['id']?.toString() ?? '',
      email: map['email']?.toString(),
      displayName: map['displayName']?.toString(),
      role: map['role']?.toString() ?? 'unknown',
      createdAt: rawCreated is String ? DateTime.tryParse(rawCreated) : null,
    );
  }
}

class RoleSummary {
  final String name;
  final String? description;

  const RoleSummary({required this.name, required this.description});
}

class UserCreationResult {
  final String userId;
  final String? defaultPassword;

  const UserCreationResult({
    required this.userId,
    required this.defaultPassword,
  });
}
