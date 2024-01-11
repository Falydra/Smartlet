import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class StorageController extends GetxController {
  final storage = GetStorage();

  void saveData(String key, dynamic value) {
    storage.write(key, value);
  }

  dynamic getData(String key) {
    return storage.read(key);
  }
}

StorageController storageController = Get.put(StorageController());
