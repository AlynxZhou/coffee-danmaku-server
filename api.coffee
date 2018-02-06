module.exports = (fastify, opts, next) ->
  { channelManager, Channel, Danmaku } = fastify
  fastify.post("/channel", (request, reply) ->
    if channelManager.getChannelByName(request.body.name)?
      reply.send(new Error("Channel #{request.body.name} Exists"))
    else
      isOpen = true
      if request.body.password?
        isOpen = false
      c = new Channel(request.body.name, request.body.desc,
      request.body.expireTime, isOpen, request.body.password)
      channelManager.addChannel(c)
      reply.send({ "url": c.url })
  )
  fastify.get("/channel", (request, reply) ->
    reply.send(channelManager.listChannelValue())
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
  fastify.post("/channel/:cname/danmaku", (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        throw new Error("Channel #{request.params["cname"]} Not Found")
      req = request.raw
      ip = request.headers["x-forwarded-for"]?.split(",").pop() or
      req.connection.remoteAddress or
      req.socket.remoteAddress or
      req.connection.socket.remoteAddress
      if not c.ipTime[ip]?
        c.ipTime[ip] = 0
      if (not c.isOpen) and
      request.headers["x-danmaku-auth-key"] isnt c.password
        reply.code(403)
      else
        if Date.now() - c.ipTime[ip] > 1 * 1000
          c.ipTime[ip] = Date.now()
          if request.body["content"].length is 0 or (not request.body["time"]?)
            await c.pushDanmaku(new Danmaku(request.body))
          reply.send({ "status": "ok" })
        else
          reply.code(428)
    catch err
      console.error(err)
  )
  fastify.get("/channel/:cname/danmaku", (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        throw new Error("Channel #{request.params["cname"]} Not Found")
      if not request.query["time"]?
        request.query["time"] = Date.now() - 10 * 60 * 1000
      if (not c.isOpen) and
      request.headers["x-danmaku-auth-key"] isnt c.password
        reply.send([])
      else
        dmkStrs = await c.getDanmakus(request.query["time"])
        dmks = (JSON.parse(s) for s in dmkStrs)
        reply.send(dmks)
    catch err
      reply.send(err)
  )
  next()
