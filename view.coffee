nunjucks = require("nunjucks").configure("templates")
send = require("send")

module.exports = (fastify, opts, next) ->
  { channelManager, Channel, Danmaku } = fastify
  fastify.get("/", (request, reply) ->
    nunjucks.render("index.njk",
    {
      "channels": channelManager.listChannel(),
      "createChannel": "/channel/create"
    }, (err, res) ->
      if err
        reply.send(err)
      reply.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/index*", (request, reply) ->
    nunjucks.render("index.njk",
    {
      "channels": channelManager.listChannel(),
      "createChannel": "/channel/create"
    }, (err, res) ->
      if err
        reply.send(err)
      reply.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/channel/create", (request, reply) ->
    nunjucks.render("create-channel.njk",
    { "apiCreateChannel": "/api/channel/create" }, (err, res) ->
      if err
        reply.send(err)
      reply.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/channel/:cname", (request, reply) ->
    cname = request.params["cname"]
    nunjucks.render("channel.njk",
    {
      "channel": channelManager.getChannelByName(cname),
      "apiCreateDanmaaku": "/api/channel/#{cname}/danmaku/create"
    }, (err, res) ->
      if err
        reply.send(err)
      reply.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/test", (request, reply) ->
    reply.send({ "test": true })
  )
  fastify.get("/*", (request, reply) ->
    sendStream = send(request.req, request.params["*"])
    sendStream.on("error", (err) ->
      if err.status is 404
        reply.notFound()
      else
        reply.send(err)
    )
    sendStream.pipe(reply.res)
  )
  next()
