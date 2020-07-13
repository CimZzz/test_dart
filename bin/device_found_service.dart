import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 设备发现服务
/// @Author CimZzz
/// 监听组播、单播端口，实现对局域网内设备信息的
/// 发布与搜索


/// 设备发布组播地址
const _kDeviceDispatchAddress = '238.255.255.233';

/// 设备发布组播端口
const _kDeviceDispatchPort = 10086;

/// 设备发布单播接收端口
const _kDeviceRecvPort = 10087;

/// 设备过期时间，单位 1/s，目前 10 秒
const _kDeviceExpire = 10;

/// 设备发现回调接口
mixin DeviceFoundInterface {
	/// 发现新设备
	void onFoundDevice(Device device);
	
	/// 设备信息更新
	void onDeviceUpdate(Device device);
	
	/// 丢失设备
	void onMissDevice(Device device);
}

/// 设备数据类
class Device {
	Device(this.boxSn, this.ip, this.forward);
	
	final String boxSn;
	final String ip;
	final String forward;
	
	var _expireCount = 0;
	
	@override
	bool operator ==(other) {
		return other is Device &&
			boxSn == other.boxSn &&
			ip == other.ip &&
			forward == other.forward;
	}
	
	@override
	String toString() {
		return 'Device(boxSn=$boxSn, ip=$ip, forward=$forward)';
	}
}

/// 设备发现服务
class DeviceFoundService {
	DeviceFoundService(this._interface);
	
	/// 设备发现回调接口
	DeviceFoundInterface _interface;
	
	/// 组播 Socket
	RawDatagramSocket _multiSocket;
	
	/// 单播 Socket
	RawDatagramSocket _monoSocket;
	
	/// 设备检查定时器
	Timer _expireTimer;
	
	/// 设备表
	Map<String, Device> _deviceMap;
	
	/// 检查服务是否成功启动
	bool get _checkServiceStarted => _multiSocket != null && _monoSocket != null;
	
	/// 启动设备发现服务
	Future<void> start() async {
		if (!_checkServiceStarted) {
			_multiSocket = await RawDatagramSocket.bind('0.0.0.0', _kDeviceDispatchPort);
			_multiSocket.joinMulticast(InternetAddress(_kDeviceDispatchAddress));
			_monoSocket = await RawDatagramSocket.bind('0.0.0.0', _kDeviceRecvPort);
			
			/// 组播接收
			_multiSocket.listen((event) async {
				switch (event) {
				/// 收到组播
					case RawSocketEvent.read:
						await _datagramReceive(_multiSocket);
						break;
				}
			});
			
			/// 单播接收
			_monoSocket.listen((event) async {
				switch (event) {
				/// 收到单播
					case RawSocketEvent.read:
						await _datagramReceive(_monoSocket);
						break;
				}
			});
			
			/// 启动设备过期检查定时器
			_expireTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
				_checkDeviceExpire();
			});
		}
		return;
	}
	
	/// 发布搜索指令
	void query() {
		if(_checkServiceStarted) {
			_multiSocket.send(utf8.encode(json.encode({
				'search': _kDeviceRecvPort
			})), InternetAddress(_kDeviceDispatchAddress), _kDeviceDispatchPort);
		}
	}
	
	/// 关闭设备发现服务及回收相关所有资源
	void close() {
		_interface = null;
		_multiSocket?.close();
		_multiSocket = null;
		_monoSocket?.close();
		_monoSocket = null;
		_expireTimer?.cancel();
		_expireTimer = null;
		_deviceMap?.clear();
		_deviceMap = null;
	}
	
	/// 收到 UDP 报文并进行处理
	void _datagramReceive(RawDatagramSocket socket) async {
		if (socket == null) {
			return;
		}
		
		try {
			final datagram = socket.receive();
			final device = await _processDatagram(datagram);
			if (device != null) {
				_updateDeviceMap(device);
			}
		}
		catch (e) {
			return;
		}
	}
	
	/// 处理报文数据，转化为 Device
	Future<Device> _processDatagram(Datagram datagram) async {
		try {
			final map = json.decode(utf8.decode(datagram.data));
			final boxSn = map['boxSn'] as String;
			final ip = map['ip'] as String;
			final forward = map['forward'] as String;
			if (boxSn != null && ip != null) {
				return Device(boxSn, ip, forward);
			}
		}
		catch (e) {
			return null;
		}
		return null;
	}
	
	/// 更新数据过期时间
	void _updateDeviceMap(Device device) {
		_deviceMap ??= {};
		final oldDevice = _deviceMap[device.boxSn];
		if (oldDevice != null) {
			if (oldDevice == device) {
				oldDevice._expireCount = 0;
			}
			else {
				_interface?.onDeviceUpdate(device);
				_deviceMap[device.boxSn] = device;
				device._expireCount = 0;
			}
		}
		else {
			_interface?.onFoundDevice(device);
			_deviceMap[device.boxSn] = device;
			device._expireCount = 0;
		}
	}
	
	/// 检查设备是否过期
	void _checkDeviceExpire() {
		final expiredDeviceList = <Device>[];
		_deviceMap?.forEach((key, value) {
			value._expireCount ++;
			if (value._expireCount >= _kDeviceExpire) {
				expiredDeviceList.add(value);
			}
		});
		expiredDeviceList.forEach((device) {
			_interface?.onMissDevice(device);
			_deviceMap.remove(device.boxSn);
		});
		if(_deviceMap?.isEmpty == true) {
			_deviceMap = null;
		}
	}
}