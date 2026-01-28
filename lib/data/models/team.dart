import 'team_member.dart';

class Team {
  final String id;
  final String name;
  final List<TeamMember?> members; // 6 slots, can be null

  Team({
    required this.id,
    required this.name,
    List<TeamMember?>? members,
  }) : members = members ?? List.filled(6, null);

  // Create a copy with updated fields
  Team copyWith({
    String? id,
    String? name,
    List<TeamMember?>? members,
  }) {
    return Team(
      id: id ?? this.id,
      name: name ?? this.name,
      members: members ?? this.members,
    );
  }

  // Update a specific team member slot
  Team updateMember(int index, TeamMember? member) {
    if (index < 0 || index >= 6) {
      throw ArgumentError('Team member index must be between 0 and 5');
    }
    final updatedMembers = List<TeamMember?>.from(members);
    updatedMembers[index] = member;
    return copyWith(members: updatedMembers);
  }

  // Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'members': members.map((m) => m?.toJson()).toList(),
    };
  }

  // Create from JSON
  factory Team.fromJson(Map<String, dynamic> json) {
    final membersList = (json['members'] as List<dynamic>?)
            ?.map((e) => e == null
                ? null
                : TeamMember.fromJson(e as Map<String, dynamic>))
            .toList() ??
        List.filled(6, null);

    // Ensure we always have exactly 6 slots
    while (membersList.length < 6) {
      membersList.add(null);
    }
    if (membersList.length > 6) {
      membersList.removeRange(6, membersList.length);
    }

    return Team(
      id: json['id'] as String,
      name: json['name'] as String,
      members: membersList,
    );
  }

  // Check if team is full (6 pokemon)
  bool get isFull => members.where((m) => m != null).length >= 6;

  // Check if team is empty
  bool get isEmpty => members.every((m) => m == null);

  // Get number of open slots
  int get openSlots => members.where((m) => m == null).length;

  // Get number of filled slots
  int get filledSlots => members.where((m) => m != null).length;
}
