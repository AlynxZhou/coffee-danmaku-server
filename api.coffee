module.exports = (fastify, opts, next) ->
  { channelManager, Channel, Danmaku } = fastify
  fastify.post("/channel/create", (request, reply) ->
    if channelManager.getChannelByName(request.body.name)?
      reply.send(new Error("Channel #{request.body.name} Exists"))
    else
      c = new Channel(request.body.name, request.body.desc,
      request.body.expireTime)
      channelManager.addChannel(c)
      reply.send({ "url": c.url })
  )
  fastify.get("/channel", (request, reply) ->
    reply.send(channelManager.listChannel())
  )
  fastify.get("/channel/:cname", (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        throw new Error("Channel #{request.params["cname"]} Not Found")
      reply.send(c.toValue())
    catch err
      reply.send(err)
  )
  fastify.post("/channel/:cname/danmaku/create", (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        throw new Error("Channel #{request.params["cname"]} Not Found")
      await c.pushDanmaku(new Danmaku(request.body))
      reply.send({ "status": "ok" })
    catch err
      reply.send(err)
  )
  fastify.post("/channel/:cname/danmaku", (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        throw new Error("Channel #{request.params["cname"]} Not Found")
      dmkStrs = await c.getDanmakus(request.body["time"])
      dmks = (JSON.parse(s) for s in dmkStrs)
      reply.send(dmks)
    catch err
      reply.send(err)
  )
  next()
