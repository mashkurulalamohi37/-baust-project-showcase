# Upload Form UI - Remaining Implementation

## Progress Update

### ✅ Completed:
1. **Models** - TeamMember & Project updated
2. **Firestore Services** - All save/load methods updated  
3. **Upload Screen State** - All controllers and variables added
4. **Submit Logic** - Project creation with all new fields
5. **Clear Form** - Resets all fields properly

### ⏳ Next: Add UI Form Fields

Need to add these sections to the upload form (after existing fields):

## UI Sections to Add

### 1. Project Type Selection (after category dropdown)
```dart
// Project or Thesis dropdown
DropdownButtonFormField<ProjectType>(
  decoration: const InputDecoration(labelText: 'Project Type'),
  value: _selectedProjectType,
  items: [Project, Thesis],
  onChanged: (value) => setState(() => _selectedProjectType = value!),
),
```

### 2. Group/Individual Selection
```dart
const _SectionTitle('Team Configuration'),
// Radio buttons for Individual/Group
Row(
  children: [
    Radio(value: false, groupValue: _isGroupProject, ...),
    Text('Individual'),
    Radio(value: true, groupValue: _isGroupProject, ...),
    Text('Group'),
  ],
),
```

### 3. If Individual - Student Details
```dart
if (!_isGroupProject) ...[
  TextFormField(controller: _studentIdController, label: 'Student ID'),
  Row([
    Expanded(TextFormField(_batchController, 'Batch')),
    Expanded(TextFormField(_levelController, 'Level')),  
    Expanded(TextFormField(_termController, 'Term')),
  ]),
]
```

### 4. If Group - Group Details
```dart
if (_isGroupProject) ...[
  TextFormField(_groupNameController, 'Group Name'),
  DropdownButtonFormField<int>(
    label: 'Number of Members',
    value: _numberOfMembers,
    items: [2,3,4,5,6,7,8,9,10],
    onChanged: (val) {
      setState(() {
        _numberOfMembers = val!;
        _initializeTeamMembers();
      });
    },
  ),
  // For each team member:
  for (int i = 0; i < _numberOfMembers; i++)
    ExpansionTile(
      title: 'Team Member ${i+1}',
      children: [
        TextFormField(_teamMemberControllers[i]['name'], 'Name'),
        TextFormField(_teamMemberControllers[i]['id'], 'Student ID'),
        Row([
          Expanded(TextFormField(_teamMemberControllers[i]['batch'], 'Batch')),
          Expanded(TextFormField(_teamMemberControllers[i]['level'], 'Level')),
          Expanded(TextFormField(_teamMemberControllers[i]['term'], 'Term')),
        ]),
      ],
    ),
]
```

### 5. Drive Link (for both)
```dart
const _SectionTitle('Additional Resources'),
TextFormField(
  controller: _driveLinkController,
  label: 'Google Drive Link',
  hint: 'Link to screenshots, additional PDFs, or posters',
  validator: optional URL validation,
),
```

## Where to Add

Insert after the GitHub URL field (around line 810 in main.dart).

The sections should be added in this order:
1. Project Type dropdown
2. Team Configuration section
3. Conditional Individual/Group fields
4. Additional Resources (Drive Link)
5. Existing file upload section
6. Submit button

## Validation Rules

- Student ID: Required for individual
- Batch, Level, Term: Must be numbers, required for individual
- Group Name: Required for group
- Team Members: All fields required, validated on submit
- Drive Link: Optional, URL format if provided

## Next Message

Would you like me to:
A. Add all UI fields at once (one big change)
B. Add section by section (4-5 smaller changes)
C. Provide the complete code for you to review first

The total addition will be approximately 200-300 lines of UI code.
