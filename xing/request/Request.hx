package xing.request;

import xing.request.RequestParser.RequestType;

class Request {
	public var method:RequestMethod;
	public var body:haxe.io.Bytes;
	public var path:String;
	@:isVar
	public var cookies(get, null):Map<String, String>;
	public var headers(default, null):Map<String, String>;

	public function new(request:RequestType) {
		this.method = request.method;
		this.path = request.uri;
		this.headers = request.headers;
		this.body = request.body;
		this.cookies = this.get_cookies();
	}

	function get_cookies():Map<String, String> {
		if (this.cookies == null) {
			this.cookies = new Map<String, String>();
			var cs = this.headers.get("Cookie");
			if(cs == null) {
				return this.cookies;
			}
			var cookies = cs.split(";");
			var temp:Array<String>;
			for (cookie in cookies) {
				temp = cookie.split("=");
				this.cookies.set(StringTools.trim(temp[0]), StringTools.trim(temp[1]));
			}
		}

		return this.cookies;
	}
}
