class TeamMember {
  final String name;
  final String id; // Student ID number
  final int batch;
  final int level;
  final int term;

  const TeamMember({
    required this.name,
    required this.id,
    required this.batch,
    required this.level,
    required this.term,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'id': id,
      'batch': batch,
      'level': level,
      'term': term,
    };
  }

  factory TeamMember.fromMap(Map<String, dynamic> map) {
    return TeamMember(
      name: map['name'] ?? '',
      id: map['id'] ?? '',
      batch: map['batch'] ?? 0,
      level: map['level'] ?? 0,
      term: map['term'] ?? 0,
    );
  }

  TeamMember copyWith({
    String? name,
    String? id,
    int? batch,
    int? level,
    int? term,
  }) {
    return TeamMember(
      name: name ?? this.name,
      id: id ?? this.id,
      batch: batch ?? this.batch,
      level: level ?? this.level,
      term: term ?? this.term,
    );
  }
}
