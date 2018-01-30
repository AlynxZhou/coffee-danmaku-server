nunjucks = require("nunjucks").configure("templates")
send = require("send")

module.exports = (fastify, opts, next) ->
  { channelManager, Channel, Danmaku } = fastify
  fastify.get("/", (request, responce) ->
    nunjucks.render("index.njk",
    {
      "channels": channelManager.listChannel(),
      "createChannel": "/channel/create"
    }, (err, res) ->
      if err
        responce.send(err)
      responce.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/index*", (request, responce) ->
    nunjucks.render("index.njk",
    {
      "channels": channelManager.listChannel(),
      "createChannel": "/channel/create"
    }, (err, res) ->
      if err
        responce.send(err)
      responce.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/channel/create", (request, responce) ->
    nunjucks.render("create-channel.njk",
    { "apiCreateChannel": "/api/channel/create" }, (err, res) ->
      if err
        responce.send(err)
      responce.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/channel/:cname", (request, responce) ->
    cname = request.params["cname"]
    nunjucks.render("channel.njk",
    {
      "channel": channelManager.getChannel(cname),
      "apiCreateDanmaaku": "/api/channel/#{cname}/danmaku/create"
    }, (err, res) ->
      if err
        responce.send(err)
      responce.header("Content-Type", "text/html").send(res)
    )
  )
  fastify.get("/test", (request, responce) ->
    responce.send({ "test": true })
  )
  fastify.get("/*", (request, responce) ->
    sendStream = send(request.req, request.params["*"])
    sendStream.on("error", (err) ->
      if err.status is 404
        responce.notFound()
      else
        responce.send(err)
    )
    sendStream.pipe(responce.res)
  )
  next()
