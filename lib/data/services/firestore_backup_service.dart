import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pharmassist/core/services/network_service.dart';
import 'package:pharmassist/data/local/app_database.dart';
import 'package:pharmassist/data/repositories/inventory_repository.dart';
import 'package:pharmassist/data/repositories/purchase_repository.dart';
import 'package:pharmassist/firebase_options.dart';

class FirebaseConfig {
  final String projectId;
  final String? apiKey;
  final String? authDomain;
  final String? storageBucket;
  final String? appId;
  final String rawJson;
  final String? filePath;

  FirebaseConfig({
    required this.projectId,
    this.apiKey,
    this.authDomain,
    this.storageBucket,
    this.appId,
    required this.rawJson,
    this.filePath,
  });

  factory FirebaseConfig.fromGoogleServicesJson(String jsonStr, {String? filePath}) {
    final Map<String, dynamic> map = json.decode(jsonStr);
    final projectInfo = map['project_info'] as Map<String, dynamic>?;
    if (projectInfo == null) {
      throw FormatException('Invalid google-services.json: Missing "project_info" section.');
    }

    final projectId = projectInfo['project_id']?.toString();
    if (projectId == null || projectId.trim().isEmpty) {
      throw FormatException('Missing "project_id" in google-services.json');
    }

    final storageBucket = projectInfo['storage_bucket']?.toString();

    String? apiKey;
    String? appId;
    final clientList = map['client'] as List?;
    if (clientList != null && clientList.isNotEmpty) {
      final client = clientList.first as Map<String, dynamic>?;
      if (client != null) {
        final clientInfo = client['client_info'] as Map<String, dynamic>?;
        appId = clientInfo?['mobilesdk_app_id']?.toString();

        final apiKeys = client['api_key'] as List?;
        if (apiKeys != null && apiKeys.isNotEmpty) {
          final keyObj = apiKeys.first as Map<String, dynamic>?;
          apiKey = keyObj?['current_key']?.toString();
        }
      }
    }

    return FirebaseConfig(
      projectId: projectId.trim(),
      apiKey: apiKey?.trim(),
      authDomain: '${projectId.trim()}.firebaseapp.com',
      storageBucket: storageBucket?.trim(),
      appId: appId?.trim(),
      rawJson: jsonStr,
      filePath: filePath ?? 'google-services.json',
    );
  }

  factory FirebaseConfig.fromDartOptionsContent(String dartContent, {String? filePath}) {
    String? extractValue(String key) {
      final regExp = RegExp(key + r'''\s*:\s*['"]([^'"]+)['"]''');
      final match = regExp.firstMatch(dartContent);
      return match?.group(1);
    }

    final projectId = extractValue('projectId');
    if (projectId == null || projectId.trim().isEmpty) {
      throw FormatException('Could not parse "projectId" from firebase_options.dart file.');
    }

    return FirebaseConfig(
      projectId: projectId.trim(),
      apiKey: extractValue('apiKey')?.trim(),
      authDomain: extractValue('authDomain')?.trim() ?? '${projectId.trim()}.firebaseapp.com',
      storageBucket: extractValue('storageBucket')?.trim(),
      appId: extractValue('appId')?.trim(),
      rawJson: dartContent,
      filePath: filePath ?? 'firebase_options.dart',
    );
  }

  factory FirebaseConfig.fromJsonString(String jsonStr, {String? filePath}) {
    final Map<String, dynamic> map = json.decode(jsonStr);

    // If google-services.json format
    if (map.containsKey('project_info') && map['project_info'] is Map) {
      return FirebaseConfig.fromGoogleServicesJson(jsonStr, filePath: filePath);
    }

    String? foundProjectId;
    String? foundApiKey;
    String? foundAuthDomain;
    String? foundStorageBucket;
    String? foundAppId;

    // Direct keys (standard web config format)
    if (map['projectId'] != null) {
      foundProjectId = map['projectId'].toString();
    } else if (map['project_id'] != null) {
      foundProjectId = map['project_id'].toString();
    }

    if (map['apiKey'] != null) {
      foundApiKey = map['apiKey'].toString();
    } else if (map['api_key'] != null) {
      foundApiKey = map['api_key'].toString();
    }

    if (map['authDomain'] != null) {
      foundAuthDomain = map['authDomain'].toString();
    }

    if (map['storageBucket'] != null) {
      foundStorageBucket = map['storageBucket'].toString();
    }

    if (map['appId'] != null) {
      foundAppId = map['appId'].toString();
    }

    // FlutterFire CLI firebase.json nested structure check
    if (foundProjectId == null && map['flutter'] is Map) {
      try {
        final flutterMap = map['flutter'] as Map;
        final platforms = flutterMap['platforms'] as Map?;
        final dartMap = platforms?['dart'] as Map?;
        if (dartMap != null && dartMap.isNotEmpty) {
          final firstTarget = dartMap.values.first as Map?;
          if (firstTarget != null && firstTarget['projectId'] != null) {
            foundProjectId = firstTarget['projectId'].toString();
          }
        }
      } catch (_) {}
    }

    if (foundProjectId == null || foundProjectId.trim().isEmpty) {
      throw FormatException('Could not find a valid "projectId" in the provided credential JSON.');
    }

    return FirebaseConfig(
      projectId: foundProjectId.trim(),
      apiKey: foundApiKey?.trim(),
      authDomain: foundAuthDomain?.trim() ?? '${foundProjectId.trim()}.firebaseapp.com',
      storageBucket: foundStorageBucket?.trim(),
      appId: foundAppId?.trim(),
      rawJson: jsonStr,
      filePath: filePath,
    );
  }

  static FirebaseConfig parseAnyCredentialContent(String content, {String? filePath}) {
    final trimmed = content.trim();
    if (trimmed.startsWith('{')) {
      return FirebaseConfig.fromJsonString(trimmed, filePath: filePath);
    } else if (trimmed.contains('FirebaseOptions') || trimmed.contains('projectId:')) {
      return FirebaseConfig.fromDartOptionsContent(trimmed, filePath: filePath);
    }
    throw FormatException('Unrecognized credential format. Please select google-services.json, firebase.json, or firebase_options.dart.');
  }

  factory FirebaseConfig.fromDefaultFirebaseOptions() {
    final options = DefaultFirebaseOptions.currentPlatform;
    if (options.projectId.trim().isEmpty) {
      throw FormatException('DefaultFirebaseOptions in lib/firebase_options.dart contains an empty projectId. Please configure credentials via Settings UI or file upload.');
    }
    return FirebaseConfig(
      projectId: options.projectId.trim(),
      apiKey: options.apiKey.trim(),
      authDomain: options.authDomain?.trim(),
      storageBucket: options.storageBucket?.trim(),
      appId: options.appId.trim(),
      rawJson: 'DefaultFirebaseOptions',
      filePath: 'lib/firebase_options.dart',
    );
  }
}

class FirestoreBackupResult {
  final bool success;
  final int backedUpCount;
  final int totalCount;
  final DateTime timestamp;
  final String message;
  final String? error;

  FirestoreBackupResult({
    required this.success,
    required this.backedUpCount,
    required this.totalCount,
    required this.timestamp,
    required this.message,
    this.error,
  });
}

class FirestoreBackupService {
  static const String _prefKeyConfigJson = 'firebase_config_json';
  static const String _prefKeyConfigPath = 'firebase_config_path';
  static const String _prefKeyLastBackup = 'firebase_last_backup_time';

  FirebaseConfig? _config;

  FirebaseConfig? get currentConfig => _config;
  bool get isConfigured => _config != null;

  /// Encoder helper: Convert Dart native values to Firestore REST API typed format
  static Map<String, dynamic> encodeFirestoreValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is String) return {'stringValue': value};
    if (value is DateTime) return {'timestampValue': value.toUtc().toIso8601String()};
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map((e) => encodeFirestoreValue(e)).toList(),
        }
      };
    }
    if (value is Map) {
      final Map<String, dynamic> mapData = value.cast<String, dynamic>();
      return {
        'mapValue': {
          'fields': mapData.map((k, v) => MapEntry(k, encodeFirestoreValue(v))),
        }
      };
    }
    return {'stringValue': value.toString()};
  }

  static Map<String, dynamic> dartToFirestoreFields(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, encodeFirestoreValue(value)));
  }

  /// Decoder helper: Convert Firestore REST API fields to Dart native map
  static dynamic decodeFirestoreValue(Map<String, dynamic> firestoreMap) {
    if (firestoreMap.containsKey('stringValue')) return firestoreMap['stringValue'];
    if (firestoreMap.containsKey('integerValue')) return int.tryParse(firestoreMap['integerValue'].toString()) ?? 0;
    if (firestoreMap.containsKey('doubleValue')) return (firestoreMap['doubleValue'] as num).toDouble();
    if (firestoreMap.containsKey('booleanValue')) return firestoreMap['booleanValue'] as bool;
    if (firestoreMap.containsKey('timestampValue')) return DateTime.tryParse(firestoreMap['timestampValue'].toString());
    if (firestoreMap.containsKey('arrayValue')) {
      final arrayObj = firestoreMap['arrayValue'];
      if (arrayObj is Map && arrayObj.containsKey('values')) {
        final values = arrayObj['values'] as List?;
        return values?.map((e) => decodeFirestoreValue(e is Map ? e.cast<String, dynamic>() : {})).toList() ?? [];
      }
      return [];
    }
    if (firestoreMap.containsKey('mapValue')) {
      final mapObj = firestoreMap['mapValue'];
      if (mapObj is Map && mapObj.containsKey('fields')) {
        final fields = mapObj['fields'];
        if (fields is Map) {
          final Map<String, dynamic> mapFields = fields.cast<String, dynamic>();
          return mapFields.map((k, v) => MapEntry(k, decodeFirestoreValue(v is Map ? v.cast<String, dynamic>() : {})));
        }
      }
      return {};
    }
    return null;
  }

  static Map<String, dynamic> firestoreFieldsToDart(Map<String, dynamic> fields) {
    return fields.map((key, value) => MapEntry(key, decodeFirestoreValue(value as Map<String, dynamic>)));
  }

  /// Load configuration from any raw content (JSON or Dart options) and save to SharedPreferences
  Future<FirebaseConfig> saveAndSetConfig(String content, {String? filePath}) async {
    final config = FirebaseConfig.parseAnyCredentialContent(content, filePath: filePath);
    _config = config;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyConfigJson, content);
    if (filePath != null) {
      await prefs.setString(_prefKeyConfigPath, filePath);
    }

    return config;
  }

  /// Clear saved configuration from SharedPreferences
  Future<void> clearSavedConfig() async {
    _config = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyConfigJson);
    await prefs.remove(_prefKeyConfigPath);
  }

  /// Initialize Firebase options by inspecting saved prefs or auto-detecting local files
  Future<FirebaseConfig?> initializeSavedOrLocalConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final savedContent = prefs.getString(_prefKeyConfigJson);
    final savedPath = prefs.getString(_prefKeyConfigPath);

    if (savedContent != null && savedContent.isNotEmpty) {
      try {
        _config = FirebaseConfig.parseAnyCredentialContent(savedContent, filePath: savedPath);
        return _config;
      } catch (e) {
        if (kDebugMode) debugPrint('Failed parsing saved custom firebase config: $e');
      }
    }

    // Auto-detect credential files in local project directory
    final candidatePaths = [
      'google-services.json',
      'android/app/google-services.json',
      'firebase.json',
      'lib/firebase_options.dart',
      '${Directory.current.path}/google-services.json',
      '${Directory.current.path}/android/app/google-services.json',
      '${Directory.current.path}/firebase.json',
      '${Directory.current.path}/lib/firebase_options.dart',
    ];

    for (final path in candidatePaths) {
      final file = File(path);
      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final config = FirebaseConfig.parseAnyCredentialContent(content, filePath: path);
          _config = config;
          return _config;
        } catch (_) {}
      }
    }

    // Fallback: DefaultFirebaseOptions if present
    try {
      _config = FirebaseConfig.fromDefaultFirebaseOptions();
      return _config;
    } catch (_) {}

    return null;
  }

  /// Test Firestore connection via REST API
  Future<bool> testFirestoreConnection() async {
    final bool hasNet = await NetworkService.hasInternetConnection();
    if (!hasNet) {
      throw Exception('No internet connection. Please verify network connectivity and try again.');
    }

    if (_config == null) {
      throw Exception('No Firebase configuration loaded. Please select or paste firebase.json.');
    }

    String urlStr = 'https://firestore.googleapis.com/v1/projects/${_config!.projectId}/databases/(default)/documents';
    if (_config!.apiKey != null && _config!.apiKey!.isNotEmpty) {
      urlStr += '?key=${_config!.apiKey}';
    }

    final response = await http.get(Uri.parse(urlStr));

    // HTTP 200 (OK) or 404 (database documents empty) means connection to Firebase REST endpoint works!
    if (response.statusCode == 200 || response.statusCode == 404 || response.statusCode == 403) {
      // If HTTP 403, check if response contains valid JSON error from Firebase REST API
      if (response.statusCode == 403 && !response.body.contains('error')) {
        throw Exception('Firebase Firestore endpoint returned 403 Forbidden. Check security rules or API key.');
      }
      return true;
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  /// Perform Online Backup of Stocks to Firebase Firestore
  Future<FirestoreBackupResult> backupStocksToFirestore({
    required List<MedicineWithStock> medicines,
    required List<Batch> allBatches,
  }) async {
    final bool hasNet = await NetworkService.hasInternetConnection();
    if (!hasNet) {
      throw Exception('No internet connection. Cloud Backup requires an active internet connection.');
    }

    if (_config == null) {
      throw Exception('Firebase Firestore is not configured. Load firebase.json first.');
    }

    final projectId = _config!.projectId;
    final apiKey = _config!.apiKey;
    final now = DateTime.now();
    int backedUpCount = 0;

    final Map<int, List<Batch>> medicineBatchesMap = {};
    for (final b in allBatches) {
      medicineBatchesMap.putIfAbsent(b.medicineId, () => []).add(b);
    }

    final Set<String> uploadedDocIds = {};

    String sanitizeDocId(String name) {
      final clean = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
      return clean.isEmpty ? 'med_${DateTime.now().millisecondsSinceEpoch}' : clean;
    }

    for (final item in medicines) {
      final med = item.medicine;
      final batches = medicineBatchesMap[med.id] ?? [];
      final docId = sanitizeDocId(med.name);
      uploadedDocIds.add(docId);

      final Map<String, dynamic> docData = {
        'id': med.id,
        'name': med.name,
        'genericName': med.genericName,
        'category': med.category ?? 'General',
        'unit': med.unit,
        'reorderLevel': med.reorderLevel,
        'gstRate': med.gstRate,
        'hsnCode': med.hsnCode,
        'scheduleFlag': med.scheduleFlag,
        'totalQuantity': item.totalQuantity,
        'batchCount': batches.length,
        'lastSyncedAt': now,
        'batches': batches.map((b) => <String, dynamic>{
              'id': b.id,
              'batchNo': b.batchNo,
              'mfgDate': b.mfgDate,
              'expiryDate': b.expiryDate,
              'purchasePrice': b.purchasePrice,
              'mrp': b.mrp,
              'quantity': b.quantity,
            }).toList(),
      };

      final queryParams = <String>[];
      if (apiKey != null && apiKey.isNotEmpty) {
        queryParams.add('key=$apiKey');
      }
      for (final fieldKey in docData.keys) {
        queryParams.add('updateMask.fieldPaths=$fieldKey');
      }

      final queryJoined = queryParams.join('&');
      final urlStr = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/stocks/$docId?$queryJoined';

      final bodyJson = json.encode({
        'fields': dartToFirestoreFields(docData),
      });

      // Use PATCH with updateMask to upsert document in Firestore
      final res = await http.patch(
        Uri.parse(urlStr),
        headers: {'Content-Type': 'application/json'},
        body: bodyJson,
      );

      if (res.statusCode == 200) {
        backedUpCount++;
      } else {
        final errorMsg = 'Failed to backup medicine "${med.name}" [HTTP ${res.statusCode}]: ${res.body}';
        if (kDebugMode) {
          print(errorMsg);
        }
        throw Exception(errorMsg);
      }
    }

    // Clean up stale documents in Cloud Firestore that no longer exist in local inventory
    try {
      String fetchUrlStr = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/stocks';
      if (apiKey != null && apiKey.isNotEmpty) {
        fetchUrlStr += '?key=$apiKey';
      }
      final fetchRes = await http.get(Uri.parse(fetchUrlStr));
      if (fetchRes.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(fetchRes.body);
        final List<dynamic> documents = body['documents'] as List<dynamic>? ?? [];
        for (final doc in documents) {
          final String? namePath = doc['name']?.toString();
          if (namePath != null) {
            final cloudDocId = namePath.split('/').last;
            if (!uploadedDocIds.contains(cloudDocId)) {
              String delUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/stocks/$cloudDocId';
              if (apiKey != null && apiKey.isNotEmpty) {
                delUrl += '?key=$apiKey';
              }
              await http.delete(Uri.parse(delUrl));
            }
          }
        }
      }
    } catch (_) {}

    // Save summary document under backup_info/latest_stock_backup
    final summaryParams = <String>[];
    if (apiKey != null && apiKey.isNotEmpty) {
      summaryParams.add('key=$apiKey');
    }
    final summaryData = {
      'lastBackupTime': now,
      'totalMedicines': medicines.length,
      'backedUpCount': backedUpCount,
      'totalStockUnits': medicines.fold<int>(0, (sum, m) => sum + m.totalQuantity),
      'status': 'SUCCESS',
      'appVersion': '1.0.0',
    };
    for (final fieldKey in summaryData.keys) {
      summaryParams.add('updateMask.fieldPaths=$fieldKey');
    }

    final summaryJoined = summaryParams.join('&');
    final summaryUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/backup_info/latest_stock_backup?$summaryJoined';

    await http.patch(
      Uri.parse(summaryUrl),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'fields': dartToFirestoreFields(summaryData)}),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyLastBackup, now.toIso8601String());

    final result = FirestoreBackupResult(
      success: backedUpCount > 0 || medicines.isEmpty,
      backedUpCount: backedUpCount,
      totalCount: medicines.length,
      timestamp: now,
      message: 'Successfully backed up $backedUpCount of ${medicines.length} stock items to Firebase Firestore.',
    );

    return result;
  }

  /// Fetch backed-up stocks from Firestore collection
  Future<List<Map<String, dynamic>>> fetchStocksFromFirestore() async {
    if (_config == null) {
      throw Exception('Firebase Firestore is not configured.');
    }

    final projectId = _config!.projectId;
    final apiKey = _config!.apiKey;

    String urlStr = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/stocks';
    if (apiKey != null && apiKey.isNotEmpty) {
      urlStr += '?key=$apiKey';
    }

    final response = await http.get(Uri.parse(urlStr));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch stocks from Firestore: HTTP ${response.statusCode} - ${response.body}');
    }

    final Map<String, dynamic> body = json.decode(response.body);
    final List<dynamic> documents = body['documents'] as List<dynamic>? ?? [];

    final List<Map<String, dynamic>> items = [];
    for (final doc in documents) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields != null) {
        items.add(firestoreFieldsToDart(fields));
      }
    }

    return items;
  }

  /// Perform Online Backup of Purchases to Firebase Firestore
  Future<int> backupPurchasesToFirestore(List<Map<String, dynamic>> purchases) async {
    if (_config == null) return 0;

    final projectId = _config!.projectId;
    final apiKey = _config!.apiKey;
    int count = 0;
    final Set<String> uploadedInvNos = {};

    for (final pur in purchases) {
      final String invoiceNo = pur['invoiceNo']?.toString() ?? 'inv_${DateTime.now().millisecondsSinceEpoch}';
      final docId = invoiceNo.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      uploadedInvNos.add(docId);

      final queryParams = <String>[];
      if (apiKey != null && apiKey.isNotEmpty) {
        queryParams.add('key=$apiKey');
      }
      for (final fieldKey in pur.keys) {
        queryParams.add('updateMask.fieldPaths=$fieldKey');
      }

      final queryJoined = queryParams.join('&');
      final urlStr = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/purchases/$docId?$queryJoined';

      final bodyJson = json.encode({
        'fields': dartToFirestoreFields(pur),
      });

      final res = await http.patch(
        Uri.parse(urlStr),
        headers: {'Content-Type': 'application/json'},
        body: bodyJson,
      );

      if (res.statusCode == 200) {
        count++;
      } else {
        final errorMsg = 'Failed to backup purchase invoice "$invoiceNo" [HTTP ${res.statusCode}]: ${res.body}';
        if (kDebugMode) {
          print(errorMsg);
        }
        throw Exception(errorMsg);
      }
    }

    // Clean up stale purchases in Cloud Firestore
    try {
      String fetchUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/purchases';
      if (apiKey != null && apiKey.isNotEmpty) {
        fetchUrl += '?key=$apiKey';
      }
      final fetchRes = await http.get(Uri.parse(fetchUrl));
      if (fetchRes.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(fetchRes.body);
        final List<dynamic> documents = body['documents'] as List<dynamic>? ?? [];
        for (final doc in documents) {
          final String? namePath = doc['name']?.toString();
          if (namePath != null) {
            final cloudDocId = namePath.split('/').last;
            if (!uploadedInvNos.contains(cloudDocId)) {
              String delUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/purchases/$cloudDocId';
              if (apiKey != null && apiKey.isNotEmpty) {
                delUrl += '?key=$apiKey';
              }
              await http.delete(Uri.parse(delUrl));
            }
          }
        }
      }
    } catch (_) {}

    return count;
  }

  /// Fetch backed-up purchases from Firestore collection
  Future<List<Map<String, dynamic>>> fetchPurchasesFromFirestore() async {
    if (_config == null) return [];

    final projectId = _config!.projectId;
    final apiKey = _config!.apiKey;

    String urlStr = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/purchases';
    if (apiKey != null && apiKey.isNotEmpty) {
      urlStr += '?key=$apiKey';
    }

    final response = await http.get(Uri.parse(urlStr));

    if (response.statusCode != 200) {
      return [];
    }

    final Map<String, dynamic> body = json.decode(response.body);
    final List<dynamic> documents = body['documents'] as List<dynamic>? ?? [];

    final List<Map<String, dynamic>> items = [];
    for (final doc in documents) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields != null) {
        items.add(firestoreFieldsToDart(fields));
      }
    }

    return items;
  }

  /// Perform Online Backup of Suppliers/Distributors Master Data to Firebase Firestore
  Future<int> backupSuppliersToFirestore(List<Map<String, dynamic>> suppliers) async {
    if (_config == null) return 0;

    final projectId = _config!.projectId;
    final apiKey = _config!.apiKey;
    int count = 0;
    final Set<String> uploadedSupNames = {};

    for (final sup in suppliers) {
      final String supName = sup['name']?.toString() ?? 'sup_${DateTime.now().millisecondsSinceEpoch}';
      final docId = supName.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      uploadedSupNames.add(docId);

      final queryParams = <String>[];
      if (apiKey != null && apiKey.isNotEmpty) {
        queryParams.add('key=$apiKey');
      }
      for (final fieldKey in sup.keys) {
        queryParams.add('updateMask.fieldPaths=$fieldKey');
      }

      final queryJoined = queryParams.join('&');
      final urlStr = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/suppliers/$docId?$queryJoined';

      final bodyJson = json.encode({
        'fields': dartToFirestoreFields(sup),
      });

      final res = await http.patch(
        Uri.parse(urlStr),
        headers: {'Content-Type': 'application/json'},
        body: bodyJson,
      );

      if (res.statusCode == 200) {
        count++;
      } else {
        final errorMsg = 'Failed to backup supplier "$supName" [HTTP ${res.statusCode}]: ${res.body}';
        if (kDebugMode) {
          print(errorMsg);
        }
        throw Exception(errorMsg);
      }
    }

    // Clean up stale suppliers in Cloud Firestore
    try {
      String fetchUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/suppliers';
      if (apiKey != null && apiKey.isNotEmpty) {
        fetchUrl += '?key=$apiKey';
      }
      final fetchRes = await http.get(Uri.parse(fetchUrl));
      if (fetchRes.statusCode == 200) {
        final Map<String, dynamic> body = json.decode(fetchRes.body);
        final List<dynamic> documents = body['documents'] as List<dynamic>? ?? [];
        for (final doc in documents) {
          final String? namePath = doc['name']?.toString();
          if (namePath != null) {
            final cloudDocId = namePath.split('/').last;
            if (!uploadedSupNames.contains(cloudDocId)) {
              String delUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/suppliers/$cloudDocId';
              if (apiKey != null && apiKey.isNotEmpty) {
                delUrl += '?key=$apiKey';
              }
              await http.delete(Uri.parse(delUrl));
            }
          }
        }
      }
    } catch (_) {}

    return count;
  }

  /// Fetch backed-up suppliers from Firestore collection
  Future<List<Map<String, dynamic>>> fetchSuppliersFromFirestore() async {
    if (_config == null) return [];

    final projectId = _config!.projectId;
    final apiKey = _config!.apiKey;

    String urlStr = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/suppliers';
    if (apiKey != null && apiKey.isNotEmpty) {
      urlStr += '?key=$apiKey';
    }

    final response = await http.get(Uri.parse(urlStr));

    if (response.statusCode != 200) {
      return [];
    }

    final Map<String, dynamic> body = json.decode(response.body);
    final List<dynamic> documents = body['documents'] as List<dynamic>? ?? [];

    final List<Map<String, dynamic>> items = [];
    for (final doc in documents) {
      final fields = doc['fields'] as Map<String, dynamic>?;
      if (fields != null) {
        items.add(firestoreFieldsToDart(fields));
      }
    }

    return items;
  }
}

// --- RIVERPOD STATE MANAGERS ---

class FirestoreBackupState {
  final bool isConfigured;
  final bool isConnected;
  final bool isBackingUp;
  final bool isRestoring;
  final FirebaseConfig? config;
  final DateTime? lastBackupTime;
  final String? statusMessage;
  final String? errorMessage;

  FirestoreBackupState({
    this.isConfigured = false,
    this.isConnected = false,
    this.isBackingUp = false,
    this.isRestoring = false,
    this.config,
    this.lastBackupTime,
    this.statusMessage,
    this.errorMessage,
  });

  FirestoreBackupState copyWith({
    bool? isConfigured,
    bool? isConnected,
    bool? isBackingUp,
    bool? isRestoring,
    FirebaseConfig? config,
    DateTime? lastBackupTime,
    String? statusMessage,
    String? errorMessage,
  }) {
    return FirestoreBackupState(
      isConfigured: isConfigured ?? this.isConfigured,
      isConnected: isConnected ?? this.isConnected,
      isBackingUp: isBackingUp ?? this.isBackingUp,
      isRestoring: isRestoring ?? this.isRestoring,
      config: config ?? this.config,
      lastBackupTime: lastBackupTime ?? this.lastBackupTime,
      statusMessage: statusMessage ?? this.statusMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class FirestoreBackupNotifier extends StateNotifier<FirestoreBackupState> {
  final FirestoreBackupService _service;

  FirestoreBackupNotifier(this._service) : super(FirestoreBackupState()) {
    _init();
  }

  Future<void> _init() async {
    final config = await _service.initializeSavedOrLocalConfig();
    state = state.copyWith(
      isConfigured: config != null,
      config: config,
      statusMessage: config != null ? 'Firebase configuration ready.' : 'No Firebase credentials loaded.',
    );
  }

  Future<bool> setCustomConfig(String jsonContent, {String? filePath}) async {
    try {
      final config = await _service.saveAndSetConfig(jsonContent, filePath: filePath);
      state = state.copyWith(
        isConfigured: true,
        config: config,
        statusMessage: 'Firebase configuration saved successfully.',
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Invalid configuration file: $e',
      );
      return false;
    }
  }

  Future<bool> setConfigFromJson(String content, {String? filePath}) async {
    return await setCustomConfig(content, filePath: filePath);
  }

  Future<void> clearConfig() async {
    await _service.clearSavedConfig();
    state = FirestoreBackupState(
      isConfigured: false,
      isConnected: false,
      statusMessage: 'Firebase credentials cleared.',
    );
  }

  Future<bool> testConnection() async {
    if (!_service.isConfigured) return false;
    try {
      state = state.copyWith(statusMessage: 'Testing connection to Firestore...');
      final ok = await _service.testFirestoreConnection();
      state = state.copyWith(
        isConnected: ok,
        statusMessage: ok ? 'Successfully connected to Firebase Firestore!' : 'Connection failed.',
        errorMessage: null,
      );
      return ok;
    } catch (e) {
      state = state.copyWith(
        isConnected: false,
        errorMessage: 'Firestore Connection Error: $e',
      );
      return false;
    }
  }

  Future<FirestoreBackupResult?> backupStocks({
    required List<MedicineWithStock> medicines,
    required List<Batch> allBatches,
    PurchaseRepository? purchaseRepo,
  }) async {
    if (!state.isConfigured) {
      state = state.copyWith(errorMessage: 'Please configure firebase.json credentials first.');
      return null;
    }

    state = state.copyWith(isBackingUp: true, statusMessage: 'Syncing stock, purchases & distributors to Cloud Firestore...');

    try {
      final res = await _service.backupStocksToFirestore(
        medicines: medicines,
        allBatches: allBatches,
      );

      int purCount = 0;
      int supCount = 0;
      if (purchaseRepo != null) {
        final purchases = await purchaseRepo.getPurchasesForBackup();
        if (purchases.isNotEmpty) {
          purCount = await _service.backupPurchasesToFirestore(purchases);
        }

        final suppliers = await purchaseRepo.getSuppliersForBackup();
        if (suppliers.isNotEmpty) {
          supCount = await _service.backupSuppliersToFirestore(suppliers);
        }
      }

      state = state.copyWith(
        isBackingUp: false,
        isConnected: res.success,
        lastBackupTime: res.timestamp,
        statusMessage: 'Successfully backed up ${medicines.length} stock items, $purCount purchase invoices, and $supCount distributors to Cloud Firestore.',
        errorMessage: res.success ? null : res.error,
      );

      return res;
    } catch (e) {
      state = state.copyWith(
        isBackingUp: false,
        errorMessage: 'Backup Failed: $e',
      );
      return null;
    }
  }

  Future<Map<String, int>?> restoreBackup(
    InventoryRepository inventoryRepo, {
    PurchaseRepository? purchaseRepo,
  }) async {
    if (!state.isConfigured) {
      state = state.copyWith(errorMessage: 'Please configure Firebase options first.');
      return null;
    }

    final bool hasNet = await NetworkService.hasInternetConnection();
    if (!hasNet) {
      state = state.copyWith(errorMessage: 'No internet connection available to restore cloud backup.');
      return null;
    }

    state = state.copyWith(isRestoring: true, statusMessage: 'Fetching stock, purchase & distributor records from Cloud Firestore...');

    try {
      final List<Map<String, dynamic>> items = await _service.fetchStocksFromFirestore();
      final summary = await inventoryRepo.restoreStocksFromFirestore(items);

      if (purchaseRepo != null) {
        final cloudPurchases = await _service.fetchPurchasesFromFirestore();
        if (cloudPurchases.isNotEmpty) {
          final purSummary = await purchaseRepo.restorePurchasesFromFirestore(cloudPurchases);
          summary['purchases'] = purSummary['invoices'] ?? 0;
        }

        final cloudSuppliers = await _service.fetchSuppliersFromFirestore();
        if (cloudSuppliers.isNotEmpty) {
          final supSummary = await purchaseRepo.restoreSuppliersFromFirestore(cloudSuppliers);
          summary['suppliers'] = supSummary;
        }
      }

      final purCount = summary['purchases'] ?? 0;
      final supCount = summary['suppliers'] ?? 0;

      state = state.copyWith(
        isRestoring: false,
        statusMessage: 'Successfully restored ${summary['medicines'] ?? 0} medicines, ${summary['batches'] ?? 0} batches, $purCount purchase invoices, and $supCount distributors from Cloud Firestore.',
        errorMessage: null,
      );

      return summary;
    } catch (e) {
      state = state.copyWith(
        isRestoring: false,
        errorMessage: 'Restore Failed: $e',
      );
      return null;
    }
  }
}

final firestoreBackupServiceProvider = Provider<FirestoreBackupService>((ref) {
  return FirestoreBackupService();
});

final firestoreBackupNotifierProvider = StateNotifierProvider<FirestoreBackupNotifier, FirestoreBackupState>((ref) {
  final service = ref.watch(firestoreBackupServiceProvider);
  return FirestoreBackupNotifier(service);
});
