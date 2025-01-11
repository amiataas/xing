package xing.request;

import haxe.io.ArrayBufferView;
import haxe.io.BytesInput;
import haxe.io.BufferInput;
import haxe.io.BytesBuffer;
import haxe.io.Input;
import xing.util.NextLineString;
import haxe.io.Bytes;
import haxe.ds.Vector;

typedef TokenParseData = {
	var status:Bool;
	var token:String;
	var length:Int;
}

typedef RequestType = {
	final method:String;
	final uri:String;
	final version:String;
	final headers:Map<String, String>;
	final body:Bytes;
}

typedef RequestParserContext = {
	var position:Int;
	var data:Null<Bytes>;
}

class RequestParser {
	private static final CTL:Array<Bool> = [
		 true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,
		 true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,  true,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,  true
	];
	private static final tspecials:Array<Bool> = [
		false, false, false, false, false, false, false, false, false, true, false, false, false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false, false, false, true, false, true, false, false, false, false, false, true, true, false,
		false, true, false, false, true, false, false, false, false, false, false, false, false, false, false, true, true, true, true, true, true, true,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, true, true, true, false, false, false, false, false, false, false, false, false, false, false, false, false, false,
		false, false, false, false, false, false, false, false, false, false, false, false, false, false, false, true, false, true
	];

	static inline function isCTL(code:Int):Bool {
		try {
			return CTL[code];
		} catch (e:Dynamic) {
			return false;
		}
	}

	static inline function isTspecial(code:Int):Bool {
		try {
			return tspecials[code];
		} catch (e:Dynamic) {
			return false;
		}
	}

	static inline function isNum(code:Int):Bool {
		return code >= 48 && code <= 57;
	}

	static inline function isAlpha(code:Int):Bool {
		return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
	}

	static function consumeTokensWhile(tokens:Array<String>, string:String):String {
		var pos:Int = 0;
		var cur = string.charAt(pos);

		while (cur != null && tokens.indexOf(cur) != -1) {
			pos++;
			cur = string.charAt(pos);
		}

		return string.substr(pos);
	}

	public static function parseHeadersLine(line:String):Map<String, String> {
		final headers:Map<String, String> = new Map();
		final lines = new NextLineString(line);

		for (headerLine in lines) {
			var token = parseToken(headerLine, 0);
			if (token != null) {
				headers.set(token.token, consumeTokensWhile([' ', '\t', ':'], headerLine.substr(token.pos)));
			}
		}
		return headers;
	}

	public static function parseToken(line:String, position:Int):{token:String, pos:Int} {
		var tokenBuffer:StringBuf = new StringBuf();
		var current = line.charCodeAt(position);
		while (current != null && !isCTL(current) && !isTspecial(current)) {
			tokenBuffer.addChar(current);
			position++;
			current = line.charCodeAt(position);
		}
		return {token: tokenBuffer.toString(), pos: position};
	}

	public static function requestFromInput(input:Input):RequestType {
		final req = readRequest(input);
		return parse(req);
	}

	static function readRequest(input:Input):Bytes {
		final allocationSize:Int = 2048;
		final buffer:BytesBuffer = new BytesBuffer();
		final bytes:Bytes = Bytes.alloc(allocationSize);
		var readSize:Int = allocationSize;
		var position:Int = 0;
		while (readSize == allocationSize) {
			readSize = input.readBytes(bytes, 0, allocationSize);
			buffer.addBytes(bytes, position, allocationSize);
			position += readSize;
		}
		return buffer.getBytes();
	}

	static function parse(request:Bytes) {
		final requestString = request.getString(0, request.length);
		final likelyRequestLine:String = requestString.substring(0, requestString.indexOf("\r\n"));
		final likelyHeaderPos:Int = requestString.indexOf("\r\n") + 2;
		final likelyHeadersLine:String = requestString.substring(likelyHeaderPos, requestString.indexOf("\r\n", likelyHeaderPos));
		final likelyBodyPos:Int = requestString.indexOf("\r\n", likelyHeaderPos) + 2;
		final likelyBodyEnd:Int = requestString.lastIndexOf('\r\n');
		final likelyBodyLength:Int = (likelyBodyEnd == -1 ? request.length : likelyBodyEnd) - likelyBodyPos;
		final likelyBody:Bytes = request.sub(likelyBodyPos, likelyBodyLength);

		final requestSplit:Vector<String> = Vector.fromArrayCopy(likelyRequestLine.split(" "));

		final request:RequestType = {
			method: requestSplit[0],
			uri: requestSplit[1],
			version: requestSplit[2],
			headers: parseHeadersLine(likelyHeadersLine),
			body: likelyBody
		}

		return request;
	}
}
