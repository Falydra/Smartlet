# Kandang API Integration Updates

## Overview
Updated the kandang (cage) management system to properly integrate with the backend API while maintaining backward compatibility with local storage.

## Changes Made

### 1. Updated Cage Data Page (`cage_data_page.dart`)

#### New Form Fields
- **Name Field**: Added dedicated field for kandang name
- **Location Field**: Renamed from "address" to match API expectations
- **Floor Count Field**: Updated to match API field name (`floor_count`)
- **Description Field**: Added optional description field

#### API Integration
- **Image Upload**: Integrated with `FileService` to upload images before creating kandang
- **API-First Approach**: Attempts to save to API first, falls back to local storage
- **Error Handling**: Comprehensive error handling with user feedback

#### Updated Data Structure
```dart
// API Payload
{
  'name': _nameController.text,
  'location': _locationController.text,
  'floor_count': int.parse(_floorCountController.text),
  'description': _descriptionController.text,
  'image_url': uploadedImageUrl, // Optional
}
```

### 2. Updated Home Page (`home_page.dart`)

#### API Data Loading
- **Primary Source**: Loads kandang data from API first
- **Field Mapping**: Maps API fields to local structure
  - `location` → `address`
  - `floor_count` → `floors`
- **Fallback**: Uses local storage if API fails

#### Enhanced Data Structure
```dart
// Updated kandang object
{
  'id': 'house_${house['id']}',
  'apiId': house['id'],
  'name': house['name'],
  'address': house['location'],
  'floors': house['floor_count'],
  'description': house['description'],
  'image': house['image_url'],
  'isEmpty': false,
  'isFromAPI': true,
}
```

### 3. Updated Cage Selection Page (`cage_selection_page.dart`)

#### Enhanced Local Storage
- **New Fields**: Added support for name and description fields
- **Reorganization**: Updated data reorganization to handle all fields
- **Deletion**: Enhanced deletion to remove all new fields

#### Updated Storage Keys
```dart
'kandang_${i}_name'        // New
'kandang_${i}_address'     // Existing (now location)
'kandang_${i}_floors'      // Existing
'kandang_${i}_description' // New
'kandang_${i}_image'       // Existing
```

## API Service Integration

### House Service
Uses the existing `HouseService` which provides:
- `getAll(token)` - Fetch all user's kandang
- `create(token, payload)` - Create new kandang
- `update(token, id, payload)` - Update existing kandang
- `delete(token, id)` - Delete kandang

### File Service
Integrated `FileService` for image uploads:
- Uploads images with category 'swiftlet_house'
- Returns file URL for storage in kandang record
- Handles upload errors gracefully

## Data Flow

### Creating New Kandang
1. User fills form with name, location, floors, description, and image
2. Image uploaded to API (if selected)
3. Kandang data posted to API with image URL
4. Data saved to local storage for offline support
5. User navigated to home page with updated data

### Loading Kandang Data
1. Authentication token retrieved
2. API called to fetch user's kandang data
3. Device data loaded and associated with kandang
4. If API fails, fallback to local storage
5. Display kandang cards with all available data

## Backward Compatibility

### Local Storage Support
- Maintains existing local storage structure
- Enhanced with new fields (name, description)
- Supports offline operation when API unavailable

### Legacy Data Migration
- Automatically detects legacy single-kandang data
- Converts to new multi-kandang format
- Preserves existing user data

## Error Handling

### API Errors
- Network failures gracefully handled
- User informed of save status (API vs local)
- Fallback to local storage maintains functionality

### User Feedback
- Success messages for API saves
- Warning messages for local-only saves
- Error messages for failures with retry options

## Benefits

1. **API-First Architecture**: Modern backend integration
2. **Offline Support**: Works without internet connection
3. **Enhanced Data**: More detailed kandang information
4. **Image Support**: Proper image upload and storage
5. **Better UX**: Clear feedback and error handling
6. **Scalability**: Ready for additional API features

## Next Steps

1. **Testing**: Thoroughly test API integration
2. **Performance**: Add caching for better performance
3. **Sync**: Implement data synchronization features
4. **Validation**: Add server-side validation feedback
5. **Features**: Add kandang editing and advanced management

## Field Mapping Reference

| Form Field | Local Storage | API Field | Type |
|------------|---------------|-----------|------|
| Name | `kandang_${i}_name` | `name` | string |
| Location | `kandang_${i}_address` | `location` | string |
| Floor Count | `kandang_${i}_floors` | `floor_count` | integer |
| Description | `kandang_${i}_description` | `description` | string |
| Image | `kandang_${i}_image` | `image_url` | string (URL) |

## Database Integration
The kandang data is now properly saved to the database through the API, ensuring:
- Data persistence across devices
- Centralized data management
- Integration with harvest and device services
- Scalable multi-user support