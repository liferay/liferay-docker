'use strict';

const cache = require('./lib/cache');
const http = require('http');
const prerender = require('prerender');

const prerenderServer = prerender({
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
		'--user-data-dir=/tmp/chrome-data',
	],
	chromeLocation: '/usr/bin/google-chrome',
});

const isCacheEnabled = Number(process.env.MEMORY_CACHE) || 0;

if (isCacheEnabled === 1) {
	prerenderServer.use(cache);
}

prerenderServer.use(prerender.blacklist());
prerenderServer.use(prerender.httpHeaders());
prerenderServer.use(prerender.removeScriptTags());

prerenderServer.start();

const requestListener = function (req, res) {
	res.writeHead(200);
	res.end('status: ok');
};

const httpServer = http.createServer(requestListener);

httpServer.listen(3001, () => {});
