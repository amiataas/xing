# Xing
A web framework for [Hashlink](https://hashlink.haxe.org/).

```haxe
package;

import xing.Xing;

class Main {
	public static function main() {
		var x = new Xing();
		x.registerRoute("/", function(req, res) {
			res.setBody("Hello World");
			res.send();
		});
		x.listen("0.0.0.0", [8000]);
	}
}
```
## Installation
This [Haxe](https://haxe.org/) library depends on [Hashlink PicoHTTP](https://github.com/aemorax/hlphttp) module, so please install that before installing this.

To install `Xing` use:
`haxelib git xing https://github.com/aemorax/xing`.

## Features
* Routing
* Template Engine

## WIP
This is a work in progress but routing and template engine works for now.