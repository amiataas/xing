package xing.request;

typedef RequestParserContext = {
	final request:String;
	var currentPos:Int;
}

enum URI {
	Relative(String);
	Absolute(AbsoluteURIType);
}

typedef URIType {
	var uri:URI;
	var fragment:String;
}

enum RelativeURI {
	NetPath;
	AbsPath;
	RelPath;
}

typedef RelPathType = {
	var path:String;
	var params:String;
	var query:String;
}

typedef AbsoluteURIType = {
	var scheme:String;
	var uri:String;
	var fragment:String;
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

	public static inline function isCTL(code:Int):Bool {
		try {
			return CTL[code];
		} catch (e:Dynamic) {
			return false;
		}
	}

	public static inline function isTspecial(code:Int):Bool {
		try {
			return tspecials[code];
		} catch (e:Dynamic) {
			return false;
		}
	}

	public static inline function isNum(code:Int):Bool {
		return code >= 48 && code <= 57;
	}

	public static inline function isAlpha(code:Int):Bool {
		return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
	}

	public static function parseURI(context:RequestParserContext):URIType {}

	public static function parseScheme(context:RequestParserContext):String {
		var schemeBuffer:StringBuf = new StringBuf();
		var current = context.request.charCodeAt(context.currentPos);
		while (current != null && (current == 43 || current == 45 || current == 46 || isNum(current) || isAlpha(current))) {
			schemeBuffer.addChar(current);
			context.currentPos++;
			current = context.request.charCodeAt(context.currentPos);
		}
		return schemeBuffer.toString();
	}

	public static function parseToken(context:RequestParserContext):String {
		var tokenBuffer:StringBuf = new StringBuf();
		var current = context.request.charCodeAt(context.currentPos);
		while (current != null && !isCTL(current) && !isTspecial(current)) {
			tokenBuffer.addChar(current);
			context.currentPos++;
			current = context.request.charCodeAt(context.currentPos);
		}
		return tokenBuffer.toString();
	}

	public static function parse(request:String) {
		var context:RequestParserContext = {
			request: request,
			currentPos: 0
		};

		var method = parseToken(context);
		context.currentPos++;
		var path = parseToken(context);
		context.currentPos++;
		var version = parseToken(context);

		return {
			method: method,
		}
	}
}
