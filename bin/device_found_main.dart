import 'dart:async';

import 'device_found_service.dart';

class Callback with DeviceFoundInterface {
	@override
	void onDeviceUpdate(Device device) {
		print('device update: $device');
	}
	
	@override
	void onFoundDevice(Device device) {
		print('found device: $device');
	}
	
	@override
	void onMissDevice(Device device) {
		print('miss device: $device');
	}
	
}

void main() async {
	final service = DeviceFoundService(Callback());
	await service.start();
	Timer.periodic(const Duration(seconds: 4), (timer) {
		service.query();
	});
	await Future.delayed(const Duration(seconds: 60), null);
}
