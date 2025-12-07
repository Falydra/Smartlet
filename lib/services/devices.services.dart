// DEPRECATED: This service targeted legacy /iot-devices endpoints which are no longer part of the API.
// Do NOT import or use this file. Use NodeService under /rbw/{id}/nodes and /nodes instead.
// Any attempt to construct or call this class will throw to prevent accidental usage.

class DeviceService {
  DeviceService() {
    throw UnsupportedError(
      'DeviceService is deprecated. Use NodeService (/rbw/{rbw_id}/nodes, /nodes) instead.'
    );
  }
}
