# Group/Individual Project Upload Feature - Implementation Plan

## Overview
Add support for both individual and group project submissions with team member details and additional drive link upload option.

## Features to Implement

### 1. **Project Type Selection**
- Radio button or dropdown for "Individual" vs "Group"
- Default: Individual

### 2. **Individual Project Fields**
When "Individual" is selected:
- Student Name (auto-filled from logged-in user)
- Student ID (number input)
- Batch (number input)
- Level (number input) 
- Term (number input)

### 3. **Group Project Fields**
When "Group" is selected:
- Group Name (text input)
- Number of Team Members (number input dropdown: 2-10)
- For each team member:
  - Name (text input)
  - ID (number/text input)
  - Batch (number input)
  - Level (number input)
  - Term (number input)

### 4. **Drive Link Upload**
For both Individual and Group:
- Drive Link for Screenshots/PDFs/Posters (URL input)
- Display icon/link in project details

## Model Changes Required

### TeamMember Model ✅ (Already Created)
```dart
class TeamMember {
  final String name;
  final String id;
  final int batch;
  final int level;
  final int term;
}
```

### Project Model Updates Needed
Add new fields to `lib/mvc/models/project.dart`:
```dart
class Project {
  // ... existing fields ...
  
  // New fields:
  final bool isGroupProject; // true for group, false for individual
  final String? groupName; // Only for group projects
  final List<TeamMember> teamMembers; // Empty for individual, filled for group
  final String? driveLink; // Google Drive link for additional resources
  
  // Individual project fields:
  final String? studentId; // For individual projects
  final int? batch; // For individual projects
  final int? level; // For individual projects  
  final int? term; // For individual projects
}
```

## UI Changes Required

### 1. Upload Form (lib/main.dart - UploadScreen)
Add these sections:

```dart
// After project type (thesis/project) selection:
1. Project Team Type Selection
   - Radio buttons: Individual / Group
   
2. IF Individual:
   - Student ID field (number)
   - Batch field (number)
   - Level field (number)
   - Term field (number)
   
3. IF Group:
   - Group Name field
   - Number of Members dropdown (2-10)
   - Dynamic team member forms based on count
   - Each member: Name, ID, Batch, Level, Term
   
4. Drive Link Section (for both):
   - Text field for Google Drive link
   - Helper text: "Link to screenshots, additional PDFs, or posters"
```

### 2. Project Detail Display (lib/screens/project_detail.dart)
Add display sections:

```dart
// In project header or info section:
1. Show "Individual Project" or "Group Project" badge

2. IF Individual:
   - Student ID: [value]
   - Batch: [value] | Level: [value] | Term: [value]
   
3. IF Group:
   - Group Name: [name]
   - Team Members: [count] members
   - Expandable list showing each member's details
   
4. IF Drive Link exists:
   - Button/Link: "View Additional Resources" 
   - Opens drive link in browser
```

## Files to Modify

### 1. Models
- ✅ `lib/mvc/models/team_member.dart` (Created)
- ⏳ `lib/mvc/models/project.dart` (Update with new fields)

### 2. Upload Forms
- ⏳ `lib/main.dart` (Update UploadScreen with team selection)
- ⏳ `lib/screens/student_dashboard.dart` (If there's separate upload there)

### 3. Display Screens
- ⏳ `lib/screens/project_detail.dart` (Show team info)
- ⏳ `lib/mvc/views/project_detail.dart` (MVC version)

### 4. Services
- ⏳ `lib/mvc/controllers/firestore_service.dart` (Handle new fields in save/load)
- ⏳ `lib/services/firestore_service.dart` (If separate)

## Implementation Steps

### Step 1: Update Project Model
1. Add new fields to Project class
2. Update copyWith method
3. Update toMap method
4. Update fromMap factory

### Step 2: Update Upload Form
1. Add project team type radio buttons
2. Add individual student fields  
3. Add group project fields with dynamic member forms
4. Add drive link field
5. Update form validation
6. Update submit logic to include new fields

### Step 3: Update Display
1. Add team type badge
2. Add student info display (individual)
3. Add team members list (group)
4. Add drive link button
5. Style with cards and proper spacing

### Step 4: Update Firestore Service
1. Handle saving new fields
2. Handle loading team members array
3. Ensure backward compatibility with existing projects

## UI/UX Considerations

1. **Validation**:
   - Student ID, Batch, Level, Term must be numbers
   - Group name required for group projects
   - Team member count must match actual members entered
   - Drive link should be valid URL format (optional)

2. **User Experience**:
   - Auto-fill student name for individual projects from logged-in user
   - Clear indication of which fields are required
   - Easy to add/remove team members
   - Preview of team before submission

3. **Display**:
   - Use colored badges for Individual/Group
   - Collapsible card for team members list
   - External link icon for drive link
   - Clean, organized layout

## Benefits

1. ✅ Supports both individual and group projects
2. ✅ Captures complete student/team information
3. ✅ Additional resource sharing via drive links
4. ✅ Better project categorization and display
5. ✅ Maintains backward compatibility

## Next Steps

Would you like me to proceed with:
1. All changes at once?
2. Step-by-step (Model → Form → Display)?
3. Review and modify this plan first?

Please let me know your preference and any modifications to this plan!
