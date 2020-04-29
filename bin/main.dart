

import 'dart:io';
import 'dart:math';

import 'package:pedantic/pedantic.dart';
import 'package:transport/transport.dart';

import 'h264nalu.dart';
import 'rtsp.dart';




void main() async {
	final file = File('/Users/wangyanxiong/Downloads/test.h264');
	final reader = StreamReader(h264NALUStream(file.openRead()));
	while(!reader.isEnd) {
		await reader.read();
	}
//	print((await reader.read()).dataList);
//	print((await reader.read()).dataList);
}