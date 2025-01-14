# Xing
A web framework for Haxe.

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
To install `Xing` use:
`haxelib git xing https://github.com/amiataas/xing`.

## Features
* Routing
* Template Engine

## WIP
This is a work in progress but routing and template engine works for now.