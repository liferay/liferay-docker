'use strict';

const prerender = require('prerender');
const cache = require('./lib/cache');

var server = prerender({
	chromeLocation: '/usr/bin/google-chrome',
	chromeFlags: [
		'--disable-gpu',
		'--disable-dev-shm-usage',
		'--headless',
		'--hide-scrollbars',
		'--no-sandbox',
		'--remote-debugging-port=9222'
	],
});

const isCacheEnabled = Number(process.env.MEMORY_CACHE) || 0;
if (isCacheEnabled === 1) {
	server.use(cache);
}

server.use(prerender.blacklist());
server.use(prerender.httpHeaders());
server.use(prerender.removeScriptTags());

server.start();

const http = require("http")

const requestListener = function (req, res) {
	res.writeHead(200);
	res.end("status: ok");
};

const status = http.createServer(requestListener);
status.listen(3001, () => {});