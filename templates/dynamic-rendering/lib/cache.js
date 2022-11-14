const cacheManager = require('cache-manager');

module.exports = {
  beforeSend: function (request, response, next) {
    if (!request.prerender.cacheHit && request.prerender.statusCode == 200) {
      this.cache.set(request.prerender.url, request.prerender.content);
    }

    next();
  },

  init: function () {
    this.cache = cacheManager.caching({
      max: Number(process.env.CACHE_MAXSIZE) || 100,
      store: 'memory',
      ttl: Number(process.env.CACHE_TTL) || 60,
    });
  },

  requestReceived: function (request, response, next) {
    this.cache.get(request.prerender.url, function (error, result) {
      if (!error && result) {
        request.prerender.cacheHit = true;

        return response.send(200, result);
      }

      next();
    });
  },
};
