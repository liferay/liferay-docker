'use strict';

const prerender = require('prerender');
const cache = require('./lib/cache');

var server = prerender({
	chromeLocation: '/usr/bin/google-chrome',
	chromeFlags: [
		'--disable-dev-shm-usage',
		'--disable-gl-drawing-for-tests',
		'--disable-gpu',
		'--hide-scrollbars',
		'--no-proxy-server',
		'--no-sandbox',
		'--proxy-server="direct://"',
		'--proxy-bypass-list=*',
		'--remote-debugging-port=9222',
		'--user-data-dir=/tmp/chrome-data'
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