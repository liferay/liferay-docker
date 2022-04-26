'use strict';

const prerender = require('prerender');

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

server.use(prerender.blacklist());
server.use(prerender.httpHeaders());
server.use(prerender.removeScriptTags());

server.start();