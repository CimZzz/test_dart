import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';
import 'package:transport/transport.dart' show ServerTransaction;

/// 关于 SDP 文件的解析
/// v 会话级描述
/// m 媒体级描述
///
/// 关于 v
///
/// v 表示 sdp 版本
///
/// o=<用户名> <会话id> <会话版本> <网络类型><地址类型> <地址>
/// 下列 o 解析为
/// 用户名：-
/// 会话id：91565340853，表示rtsp://192.168.31.115:8554/live请求中的live这个会话
/// 会话版本：1
/// 网络类型：IN，表示internet
/// 地址类型：IP4，表示ipv4
/// 地址：192.168.31.115，表示服务器的地址
///
/// 关于 m
///
/// m=<媒体类型> <端口号> <传输协议> <媒体格式>
/// 下列 m 解析为
/// 媒体类型：video
/// 端口号：0，为什么是0？因为上面在SETUP过程会告知端口号，所以这里就不需要了
/// 传输协议：RTP/AVP，表示RTP OVER UDP，如果是RTP/AVP/TCP，表示RTP OVER TCP
/// 媒体格式：表示负载类型(payload type)，一般使用96表示H.264
///
/// a=rtpmap:<媒体格式><编码格式>/<时钟频率>
/// a=framerate:25 表示帧率
/// a=control:track0 表示这路视频流在这个会话中的编号
String sdp = '''
v=0
o=- 1588127624 1 IN IP4 10.91.1.118
t=0 0
a=control:*
m=video 0 RTP/AVP 96
a=rtpmap:96 H264/90000
a=control:track0
''';

final replaceReg = RegExp('(\\r)?(\\n)?');

/// RTSP Server 端指令流
Stream<RTSPServerRecv> rtspStream(Stream<List<int>> rawDataStream) async* {
	final reader = DataReader(ByteBufferReader(StreamReader(rawDataStream)));
	while(!reader.isEnd()) {
		// RTSP Method Header
		var strLine = await reader.readString();
		strLine = strLine.replaceAll(replaceReg, '');
		var arr = strLine.split(' ');
		if(arr.length != 3) {
			throw Exception('RTSP first line error');
		}
		// get rtsp method
		final method = arr[0];
		final url = arr[1];
		final version = arr[2];
		int cseq;
		final headers = <String, String>{};
		// read until CRLF
		while(true) {
			strLine = await reader.readString();
			if(strLine == '\r\n') {
				break;
			}

			// CSeq number
			strLine = strLine.replaceAll(replaceReg, '');
			arr = strLine.split(':');
			if(arr.length != 2) {
				throw Exception('RTSP header error');
			}
			final key = arr[0].trim();
			final value = arr[1].trim();
			if(key.toLowerCase() == 'cseq') {
				cseq = int.tryParse(value);
			}
			else {
				headers[key] = value;
			}
		}

		if(cseq == null) {
			throw Exception('invalid rtsp cmd');
		}

		yield RTSPServerRecv(
			method: method,
			url: url,
			version: version,
			cseq: cseq,
			headers: headers
		);
	}

}

class RTSPServerRecv {
	RTSPServerRecv({this.method, this.url, this.version, this.cseq, this.headers});

	final String method;
	final String url;
	final String version;
	final int cseq;
	final Map<String, String> headers;

	@override
	String toString() {
		final buffer = StringBuffer();
		buffer.writeln('$method $url $version');
		buffer.writeln('CSeq: $cseq');
		headers.forEach((key, value) {
			buffer.writeln('$key: $value');
		});
		return buffer.toString();
	}
}

class RTSPTransaction extends ServerTransaction {
	@override
	void handleSocket(Socket socket) {
		rtspStream(socket).listen((event) {
			print(event);
			print('');
			switch(event.method) {
				case 'OPTIONS':
					socket.write('RTSP/1.0 200 OK\r\n');
					socket.write('CSeq: ${event.cseq}\r\n');
					socket.write('Public: OPTIONS, DESCRIBE, SETUP, PLAY\r\n\r\n');
					break;
				case 'DESCRIBE':
					socket.write('RTSP/1.0 200 OK\r\n');
					socket.write('CSeq: ${event.cseq}\r\n');
					socket.write('Content-Base: ${event.url}\r\n');
					socket.write('Content-type: application/sdp\r\n');
					socket.write('Content-length: ${sdp.length}\r\n\r\n');
					socket.write(sdp);
					break;
				case 'SETUP':
					final transport = event.headers['Transport'];
					final clientIdx = transport.indexOf('client_port');
					final flag = transport.indexOf('=', clientIdx);
					var endIdx = transport.indexOf(';', flag);
					if(endIdx == -1) {
						endIdx = transport.length;
					}
					final clientPort = transport.substring(flag + 1, endIdx);
					socket.write('RTSP/1.0 200 OK\r\n');
					socket.write('CSeq: ${event.cseq}\r\n');
					socket.write('Transport: RTP/AVP;unicast;client_port=$clientPort;server_port=60000-60001\r\n');
					socket.write('Session: 66334873\r\n\r\n');
					break;
				case 'PLAY':
					socket.write('RTSP/1.0 200 OK\r\n');
					socket.write('CSeq: ${event.cseq}\r\n');
					socket.write('Range: npt=0.000-\r\n');
					socket.write('Session: 66334873\r\n\r\n');
					// 开始播放，通过 udp 发送 H264 数据流
					break;
			}
		}, onError: (e, stackTrace) {
		}, onDone: () {
			print('done');
			socket.destroy();
		});
	}
}
