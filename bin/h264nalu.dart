import 'dart:typed_data';
import 'package:stream_data_reader/stream_data_reader.dart';


Stream<H264NALU> h264NALUStream(Stream<List<int>> rawDataStream) async* {
	final reader = ByteBufferReader(StreamReader(rawDataStream));
	while(!reader.isEnd()) {
		final bytes = await reader.readUntil(terminators: const [[00, 00, 00, 01], [00, 00, 01]], needRemoveTerminator: true, endTerminate: true);
		if(bytes.isNotEmpty) {
			yield H264NALU(bytes);
		}
	}
}

class H264NALU {
    H264NALU(this.dataList);

	final List<int> dataList;
}