module.exports = (fastify, opts, next) ->
  { channelManager, Channel, Danmaku, blacklist } = fastify
  fastify.post("/channel", (request, reply) ->
    if channelManager.getChannelByName(request.body["name"])?
      reply.code(403).send(new Error("Channel #{request.body["name"]} Exists"))
      return
    isOpen = true
    if request.body["password"]?
      isOpen = false
    c = new Channel(request.body["name"], request.body["desc"],
    request.body["expireTime"], isOpen, request.body["password"],
    request.body["useBlacklist"])
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
        reply.code(404)
        .send(new Error("Channel #{request.params["cname"]} Not Found"))
        return
      reply.send(c.toValue())
    catch err
      reply.code(400).send(err)
      console.error(err)
  )
  fastify.post("/channel/:cname/danmaku", (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        reply.code(404)
        .send(new Error("Channel #{request.params["cname"]} Not Found"))
        return
      req = request.raw
      ip = request.headers["x-forwarded-for"]?.split(",").pop() or
      req.connection.remoteAddress or
      req.socket.remoteAddress or
      req.connection.socket.remoteAddress
      if not c.ipTime[ip]?
        c.ipTime[ip] = 0
      if (not c.isOpen) and
      request.headers["x-danmaku-auth-key"] isnt c.password
        reply.code(403).send(new Error("Wrong Password"))
        return
      if Date.now() - c.ipTime[ip] < 1 * 1000
        reply.code(428).send(new Error("Too Fast"))
        return
      c.ipTime[ip] = Date.now()
      if request.body["content"].length is 0
        reply.send(new Error("Empty Danmaku"))
        return
      if c.useBlacklist and blacklist? and
      request.body["content"].match(blacklist)?
        reply.code(444).send(new Error("Blacklist Word"))
        return
      status = await c.pushDanmaku(new Danmaku(request.body))
      if (status == 1)
        reply.send({ "status": "ok" })
    catch err
      reply.code(400).send(err)
      console.error(err)
  )
  fastify.get("/channel/:cname/danmaku", (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        reply.code(404)
        .send(new Error("Channel #{request.params["cname"]} Not Found"))
        return
      # If no time offset given return danmakus in 10 minutes.
      if (not request.query["offset"]?) or request.query["offset"] > Date.now()
        request.query["offset"] = Date.now() - 1 * 60 * 1000
      if (not c.isOpen) and
      request.headers["x-danmaku-auth-key"] isnt c.password
        reply.code(403).send(new Error("Wrong password!"))
        return
      danmakuStrs = await c.getDanmakus(request.query["offset"])
      danmakus = (JSON.parse(s) for s in danmakuStrs)
      reply.send({ "result": danmakus, "status": "ok"})
    catch err
      reply.code(400).send(err)
      console.error(err)
  )
  next()
