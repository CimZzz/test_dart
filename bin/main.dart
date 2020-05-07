

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:pedantic/pedantic.dart';
import 'package:transport/transport.dart';

import 'h264nalu.dart';
import 'rtsp.dart';




void main() async {
	a = '9832';
	b = InternetAddress('127.0.0.1');
	await transportData();
//	TransportServer(
//		localPort: 9999,
//		transaction: RTSPTransaction()
//	).startServer();
//	final socket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 12290);
//	final file = File('/Users/wangyanxiong/Downloads/test.h264');
//	final reader = StreamReader(h264NALUStream(file.openRead()));
//	while(!reader.isEnd) {
//		await reader.read();
//	}
//	print((await reader.read()).dataList);
//	print((await reader.read()).dataList);
}