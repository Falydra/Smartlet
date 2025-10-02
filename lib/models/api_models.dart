// User model
class User {
  final int id;
  final String name;
  final String email;
  final String? location;
  final String? phone;
  final String? profileImageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.location,
    this.phone,
    this.profileImageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      location: json['location'],
      phone: json['no_telp'],
      profileImageUrl: json['profile_image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'location': location,
      'no_telp': phone,
      'profile_image_url': profileImageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// SwiftletHouse model
class SwiftletHouse {
  final int id;
  final int userId;
  final String name;
  final String location;
  final double? latitude;
  final double? longitude;
  final String? description;
  final int floorCount;
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  SwiftletHouse({
    required this.id,
    required this.userId,
    required this.name,
    required this.location,
    this.latitude,
    this.longitude,
    this.description,
    required this.floorCount,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SwiftletHouse.fromJson(Map<String, dynamic> json) {
    return SwiftletHouse(
      id: json['id'],
      userId: json['user_id'],
      name: json['name'],
      location: json['location'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      description: json['description'],
      floorCount: json['floor_count'],
      imageUrl: json['image_url'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'description': description,
      'floor_count': floorCount,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// IoTDevice model
class IoTDevice {
  final int id;
  final int userId;
  final int swiftletHouseId;
  final String installCode;
  final String? deviceName;
  final String? deviceType;
  final int floor;
  final int status;
  final DateTime createdAt;
  final DateTime updatedAt;

  IoTDevice({
    required this.id,
    required this.userId,
    required this.swiftletHouseId,
    required this.installCode,
    this.deviceName,
    this.deviceType,
    required this.floor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory IoTDevice.fromJson(Map<String, dynamic> json) {
    return IoTDevice(
      id: json['id'],
      userId: json['user_id'],
      swiftletHouseId: json['swiftlet_house_id'],
      installCode: json['install_code'],
      deviceName: json['device_name'],
      deviceType: json['device_type'],
      floor: json['floor'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'swiftlet_house_id': swiftletHouseId,
      'install_code': installCode,
      'device_name': deviceName,
      'device_type': deviceType,
      'floor': floor,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// SensorData model
class SensorData {
  final int id;
  final String installCode;
  final double temperature;
  final double humidity;
  final double ammonia;
  final DateTime recordedAt;
  final DateTime createdAt;

  SensorData({
    required this.id,
    required this.installCode,
    required this.temperature,
    required this.humidity,
    required this.ammonia,
    required this.recordedAt,
    required this.createdAt,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      id: json['id'],
      installCode: json['install_code'],
      temperature: json['suhu'].toDouble(),
      humidity: json['kelembaban'].toDouble(),
      ammonia: json['amonia'].toDouble(),
      recordedAt: DateTime.parse(json['recorded_at']),
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'install_code': installCode,
      'suhu': temperature,
      'kelembaban': humidity,
      'amonia': ammonia,
      'recorded_at': recordedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Harvest model
class Harvest {
  final int id;
  final int userId;
  final int swiftletHouseId;
  final int floor;
  final double bowlWeight;
  final int bowlPieces;
  final double ovalWeight;
  final int ovalPieces;
  final double cornerWeight;
  final int cornerPieces;
  final double brokenWeight;
  final int brokenPieces;
  final String? imageUrl;
  final DateTime harvestDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Harvest({
    required this.id,
    required this.userId,
    required this.swiftletHouseId,
    required this.floor,
    required this.bowlWeight,
    required this.bowlPieces,
    required this.ovalWeight,
    required this.ovalPieces,
    required this.cornerWeight,
    required this.cornerPieces,
    required this.brokenWeight,
    required this.brokenPieces,
    this.imageUrl,
    required this.harvestDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Harvest.fromJson(Map<String, dynamic> json) {
    return Harvest(
      id: json['id'],
      userId: json['user_id'],
      swiftletHouseId: json['id_swiftlet_house'],
      floor: json['lantai'],
      bowlWeight: json['bowl_weight'].toDouble(),
      bowlPieces: json['bowl_pieces'],
      ovalWeight: json['oval_weight'].toDouble(),
      ovalPieces: json['oval_pieces'],
      cornerWeight: json['corner_weight'].toDouble(),
      cornerPieces: json['corner_pieces'],
      brokenWeight: json['broken_weight'].toDouble(),
      brokenPieces: json['broken_pieces'],
      imageUrl: json['img_url'],
      harvestDate: DateTime.parse(json['harvest_date'] ?? json['created_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'id_swiftlet_house': swiftletHouseId,
      'lantai': floor,
      'bowl_weight': bowlWeight,
      'bowl_pieces': bowlPieces,
      'oval_weight': ovalWeight,
      'oval_pieces': ovalPieces,
      'corner_weight': cornerWeight,
      'corner_pieces': cornerPieces,
      'broken_weight': brokenWeight,
      'broken_pieces': brokenPieces,
      'img_url': imageUrl,
      'harvest_date': harvestDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper getters for legacy field names
  double get mangkok => bowlWeight;
  double get sudut => cornerWeight;
  double get oval => ovalWeight;
  double get patahan => brokenWeight;
}