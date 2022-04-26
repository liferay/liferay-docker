const http = require('http');

const options = {
	port: 3000,
	path:'http://localhost:3000/http://localhost:3001',
	timeout: 2000
};

const healthCheck = http.request(options, (res) => {
	console.log(`HEALTHCHECK STATUS: ${res.statusCode}`);
	if (res.statusCode == 200) {
		process.exit(0);
	}
	else {
		process.exit(1);
	}
});

healthCheck.on('error', function (err) {
	console.error('ERROR');
	process.exit(1);
});

healthCheck.end();