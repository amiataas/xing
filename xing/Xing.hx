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

class Xing {
	private var cores:Int = 0;
	private var applicationThreads:IThreadPool;
	private var backlog:Array<PriorityClientSocket> = [];
	private var routes:Map<String, Request->Response->Void>;

	public function new() {
		this.cores = System.getProcessorCores();
		if (this.cores < 0)
			this.cores = 1;
		this.routes = new Map<String, Request->Response->Void>();
	}

	public function registerRoute(path:String, callback:Request->Response->Void) {
		routes.set(path, callback);
	}

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

	public function listen(?host:String = "0.0.0.0", ?ports:Array<Int> = null) {
		if (ports == null)
			ports = [3000];

		var nativeHost:Host = new Host(host);

		if (ports.length == 1) {
			applicationThreadHandler(nativeHost, ports[0])();
		} else {
			this.applicationThreads = new FixedThreadPool(ports.length - 1);
			var lastPort = ports.pop();
			for (port in ports) {
				this.applicationThreads.run(applicationThreadHandler(nativeHost, port));
			}
			applicationThreadHandler(nativeHost, lastPort)();
		}
	}

	private function applicationThreadHandler(host:Host, port:Int) {
		return function() {
			var workerSocket = new Socket();
			workerSocket.bind(host, port);
			workerSocket.listen(1024);
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
