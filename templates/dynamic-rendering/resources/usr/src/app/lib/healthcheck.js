const http = require('http');

const EXIT_CODE = {
  ERROR: 1,
  SUCCESS: 0,
};

const options = {
  path: 'http://localhost:3000/http://localhost:3001',
  port: 3000,
  timeout: 2000,
};

const healthCheck = http.request(options, (response) => {
  console.log(`HEALTHCHECK STATUS: ${response.statusCode}`);

  process.exit(
    response.statusCode == 200 ? EXIT_CODE.SUCCESS : EXIT_CODE.ERROR
  );
});

healthCheck.on('error', function (error) {
  console.error(`HEALTHCHECK ERROR: ${error.message}`);

  process.exit(EXIT_CODE.ERROR);
});

healthCheck.end();
