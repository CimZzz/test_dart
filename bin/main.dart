


import 'dart:convert';
import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';

void main() async {
	final socket = await Socket.connect('192.168.31.195', 10087);
	final message = utf8.encode(json.encode({
		'eventType': 0,
		'eventParams': {
			'accountId': 'abc'
		}
	}));
	socket.add([message.length & 0xFF]);
	socket.add(message);
	await socket.flush();
	final reader = DataReader(ByteBufferReader(StreamReader(socket)));
	final size = await reader.readOneByte();
	final buffer = await reader.readBytes(length: size);
	print(utf8.decode(buffer));
}