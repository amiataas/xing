package xing.template;

import haxe.Constraints.IMap;

@:forward
abstract Context(Map<String, Dynamic>) {	
	public function new() {
		this = new Map<String, Dynamic>();
	}

	public function addInt(name:String, variable:Int) {
		this.set(name, variable);
	}

	public function addFloat(name:String, variable:Float) {
		this.set(name, variable);
	}

	public function addString(name:String, variable:String) {
		this.set(name, variable);
	}

	public function addDynamic(name:String, variable:Dynamic) {
		this.set(name, variable);
	}

	public function addArray(name:String, array:Array<Dynamic>) {
		this.set(name, array);
	}

	public function addMap(name:String, map:IMap<String, Dynamic>) {
		this.set(name, map);
	}
}