package xing;

import haxe.Exception;
import haxe.ds.GenericStack;
import sys.FileSystem;
import sys.io.File;
import sys.net.Host;
import sys.net.Socket;
import sys.thread.FixedThreadPool;
import sys.thread.IThreadPool;
import xing.core.PriorityClientSocket;
import xing.core.System;
import xing.request.Request;
import xing.request.RequestParser;
import xing.response.Response;

/**
	Base framework runner application.

	```haxe
	final x = new Xing();
	x.registerRoute("/", function(req, res) {
		res.setBody("Hello World");
		res.send();
	});
	x.listen("0.0.0.0", [8000]);
	```
**/
class Xing {
	private var cores:Int = 0;
	private var applicationThreads:IThreadPool;
	private var backlog:Array<PriorityClientSocket> = [];
	private var routes:Map<String, Request->Response->Void>;

	/**
		Constructor
	**/
	public function new() {
		this.cores = System.getProcessorCores();
		if (this.cores < 0)
			this.cores = 1;
		this.routes = new Map<String, Request->Response->Void>();
	}

	/**
		Registers a new route for a callback.

		```haxe
		x.registerRoute("/", (req, res)-> {
			if(req.method == "GET") {
				req.send("Hello Xing!");
			}
		});
		```
	**/
	public function registerRoute(path:String, callback:Request->Response->Void) {
		routes.set(path, callback);
	}

	/**
		Serves given `directory` at given `path`.
		```haxe
		// Serve directory dist at /static path.
		x.serveStatic("static", "dist");
		```
	**/
	public function serveStatic(path:String, directory:String) {
		var laters:GenericStack<String> = new GenericStack<String>();
		var currentPath:String;
		if (FileSystem.isDirectory(directory)) {
			var current = FileSystem.readDirectory(directory);
			for (each in current) {
				currentPath = directory + "/" + each;
				if (FileSystem.isDirectory(currentPath))
					laters.add(each);
				else
					serveFile(path + "/" + each, currentPath);
			}
			while (!laters.isEmpty()) {
				currentPath = laters.pop();
				serveStatic(path + "/" + currentPath, directory + "/" + currentPath);
			}
		}
	}

	/**
		Serves a file at given `filePath` at `path`.
		```haxe
		// Serve file dist/css/styles.css at /css/styles.css path.
		x.serveStatic("css/styles.css", "dist/css/styles.css");
		```
	**/
	public function serveFile(path:String, filePath:String) {
		var fileContent:haxe.io.Bytes = null;
		if (FileSystem.exists(filePath)) {
			fileContent = File.getBytes(filePath);
		}

		routes.set(path, function(req, res) {
			if (fileContent != null) {
				res.setBytes(fileContent);
			} else {
				res.setBody("");
			}
			res.send();
		});
	}

	/**
		Starts listening on given `host` on multiple `ports`, and callback when listening.

		```haxe
		x.listen("0.0.0.0", [8000, 8001], function() {
			Sys.println('Listening on 0.0.0.0:${ports}');
		});
		```
	**/
	public function listen(?host:String = "0.0.0.0", ?ports:Array<Int> = null, ?callback:Void->Void) {
		if (ports == null)
			ports = [3000];

		var nativeHost:Host = new Host(host);

		if (ports.length == 1) {
			applicationThreadHandler(nativeHost, ports[0], callback)();
		} else {
			this.applicationThreads = new FixedThreadPool(ports.length - 1);
			var lastPort = ports.pop();
			for (port in ports) {
				this.applicationThreads.run(applicationThreadHandler(nativeHost, port, callback));
			}
			applicationThreadHandler(nativeHost, lastPort, callback)();
		}
	}

	private function applicationThreadHandler(host:Host, port:Int, ?callback:Void->Void) {
		return function() {
			var workerSocket = new Socket();
			workerSocket.bind(host, port);
			workerSocket.listen(1024);
			if(callback != null) {
				callback();
			} 
			var workerClientHandlerThread:IThreadPool = new FixedThreadPool(this.cores * 25);

			while (true) {
				var client = workerSocket.accept();
				if (client != null) {
					workerClientHandlerThread.run(clientThreadHandler({
						socket: client,
						priority: 0,
						pending: false,
						done: false
					}));
				}
			}
		}
	}

	private function clientThreadHandler(client:PriorityClientSocket) {
		return function() {
			client.pending = true;
			try {
				var req = parseRequest(client.socket.input);
				if (routes.exists(req.path)) {
					routes.get(req.path)(req, Response.fromOutput(client.socket.output));
				} else {
					Response.notFound(client.socket.output);
				}
				client.socket.shutdown(true, true);
				client.socket.close();
				client.pending = false;
				client.done = true;
			} catch (e:Exception) {
				client.pending = false;
				client.done = true;
			}
		}
	}

	private function parseRequest(input:haxe.io.Input):Request {
		var request = RequestParser.requestFromInput(input);
		return new Request(request);
	}
}
