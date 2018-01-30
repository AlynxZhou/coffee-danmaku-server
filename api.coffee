module.exports = (fastify, opts, next) ->
  { channelManager, Channel, Danmaku } = fastify
  fastify.post("/channel/create", (request, responce) ->
    if channelManager.getChannel(request.body.name)?
      responce.send(new Error("Channel Exists."))
    else
      c = new Channel(request.body.name, request.body.desc)
      channelManager.addChannel(c)
      responce.send({ "url": c.url })
  )
  fastify.get("/channel/list", (request, responce) ->
    responce.send(channelManager.listChannel())
  )
  fastify.get("/channel/:cname/", (request, responce) ->
    responce.send( channelManager.getChannnel(request.params["cname"]) or \
    new Error("No Channel #{request.params["cname"]}."))
  )
  fastify.post("/channel/:cname/danmaku/create", (request, responce) ->
    c = channelManager.getChannel(request.params["cname"])
    if c?
      c.pushDanmaku(new Danmaku(request.body)).then(() ->
        responce.send({ "status": "ok" })
      ).catch(responce.send)
    else
      responce.send(new Error("No Channel #{request.params["cname"]}."))
  )
  fastify.get("/channel/:cname/danmaku/get", (request, responce) ->

  )
  next()
