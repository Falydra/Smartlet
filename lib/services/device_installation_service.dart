// DEPRECATED: DeviceInstallationService has been replaced by ServiceRequestService
// for creation and management of installation requests, and NodeService for checking
// installed devices. This stub intentionally throws if instantiated.

class DeviceInstallationService {
  DeviceInstallationService() {
    throw UnsupportedError(
      'DeviceInstallationService is deprecated. Use ServiceRequestService (type=installation) + NodeService instead.'
    );
  }
}