path = require("path")
Fastify = require("fastify")

fastify = new Fastify()

fastify.register(require("fastify-static"), {
  "root": path.join(__dirname, "/static"),
  "prefix": "/static"
})

fastify.register(require("fastify-redis"), {"host": "127.0.0.1"}, (err) ->
  if err
    throw err
)

fastify.register(require("./model"))
fastify.register(require("./view"))
fastify.register(require("./api"), {"prefix": "/api"})
fastify.register(require("./console"))

fastify.listen(2333, "0.0.0.0")
