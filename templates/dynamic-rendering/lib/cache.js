var cacheManager = require('cache-manager');

module.exports = {
	init: function() {
		this.cache = cacheManager.caching({
			store: 'memory', max: Number(process.env.CACHE_MAXSIZE) || 100, ttl: Number(process.env.CACHE_TTL) || 60
		});
	},

	requestReceived: function(req, res, next) {
		this.cache.get(req.prerender.url, function (err, result) {
			if (!err && result) {
				req.prerender.cacheHit = true;
				res.send(200, result);
			} else {
				next();
			}
		});
	},

	beforeSend: function(req, res, next) {
		if (!req.prerender.cacheHit && req.prerender.statusCode == 200) {
			this.cache.set(req.prerender.url, req.prerender.content);
		}
		next();
	}
};
