nunjucks = require("nunjucks").configure("templates")
send = require("send")

module.exports = (fastify, opts, next) ->
  { channelManager, Channel, Danmaku } = fastify
  fastify.get("/", (request, reply) ->
    nunjucks.render("index.njk",
    {
      "channels": channelManager.listChannelValue(),
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
      "channels": channelManager.listChannelValue(),
      "createChannel": "/channel/create"
    }, (err, res) ->
      if err
        reply.send(err)
      reply.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/channel/create", (request, reply) ->
    nunjucks.render("create-channel.njk",
    { "apiCreateChannel": "/api/channel" }, (err, res) ->
      if err
        reply.send(err)
      reply.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/channel/:cname", (request, reply) ->
    cname = request.params["cname"]
    c = channelManager.getChannelByName(cname)
    if c?
      c = c.toValue()
    nunjucks.render("channel.njk",
    {
      "channel": c,
      "apiDanmaku": "/api/channel/#{cname}/danmaku"
    }, (err, result) ->
      if err
        reply.send(err)
      reply.header("Content-Type", "text/html").send(result)
    )
  )
  fastify.get("/channel/:cname/exam", (request, reply) ->
    cname = request.params["cname"]
    c = channelManager.getChannelByName(cname)
    if c?
      c = c.toValue()
    nunjucks.render("exam-channel.njk",
    {
      "channel": c,
      "apiExamination": "/api/channel/#{cname}/examination"
    }, (err, result) ->
      if err
        reply.send(err)
      reply.header("Content-Type", "text/html").send(result)
    )
  )
  next()
