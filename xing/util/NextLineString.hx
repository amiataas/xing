package xing.util;

class NextLineString {
	final str:String;
	var offset:Int = 0;

	public function new(str:String) {
		this.str = str;
	}

	public function hasNext():Bool {
		return this.offset < this.str.length;
	}

	public function next():String {
		var i1 = str.indexOf('\r\n', this.offset);
		var i2 = str.indexOf('\n', this.offset);
		var i3 = str.indexOf('\r', this.offset);
		var indexes = [i1, i2, i3];
		indexes.sort(function(a, b) {
			if (a > b)
				return 1;
			if (a < b)
				return -1;
			return 0;
		});
		var index = indexes.filter(function(index) {
			return index != -1;
		});

		if (index.length != 0)
			return extract(index[0], index[0] == i1 ? 2 : 1);

		var length = str.length;
		if (length == offset)
			return null;
		return extract(length, 0);
	}

	function extract(index, skip) {
		var line = str.substr(offset, index - offset);
		offset = index + skip;
		return line;
	}
}
