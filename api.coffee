module.exports = (fastify, opts, next) ->
  {channelManager, Channel, Danmaku, blacklist} = fastify

  fastify.post("/channel", {
    "response": {
      "200": {
        "type": "object",
        "properties": {
          "url": {"type": "string"}
        }
      }
    }
  }, (request, reply) ->
    if channelManager.getChannelByName(request.body["name"])?
      reply.code(403).send(new Error("Channel #{request.body["name"]} Exists"))
      return
    isOpen = true
    if request.body["password"]? and request.body["password"].length isnt 0
      isOpen = false
    if request.body["examPassword"]? and
    request.body["examPassword"].length isnt 0
      isExam = true
    c = new Channel(request.body["name"], request.body["desc"],
    request.body["expireTime"], isOpen,
    request.body["password"], isExam,
    request.body["examPassword"], request.body["useBlacklist"])
    channelManager.addChannel(c)
    reply.send({"url": c.url})
  )

  fastify.get("/channel", {
    "response": {
      "200": {
        "type": "object",
        "properties": {
          "result": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "name": "string",
                "desc": "string",
                "expireTime": "integer",
                "isOpen": "boolean",
                "isExam": "boolean",
                "url": "string",
                "useBlacklist": "boolean"
              }
            }
          },
          "status": {"type": "string"}
        }
      }
    }
  }, (request, reply) ->
    reply.send({"result": channelManager.listChannelValue(), "status": "ok"})
  )

  fastify.get("/channel/:cname", {
    "response": {
      "200": {
        "type": "object",
        "properties": {
          "result": {
            "type": "object",
            "properties": {
              "name": "string",
              "desc": "string",
              "expireTime": "integer",
              "isOpen": "boolean",
              "isExam": "boolean",
              "url": "string",
              "useBlacklist": "boolean"
            }
          },
          "status": {"type": "string"}
        }
      }
    }
  }, (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        reply.code(404)
        .send(new Error("Channel #{request.params["cname"]} Not Found"))
        return
      reply.send({"result": c.toValue(), "status": "ok"})
    catch err
      reply.code(400).send(err)
      console.error(err)
  )

  fastify.post("/channel/:cname/danmaku", {
    "response": {
      "200": {
        "type": "object",
        "properties": {
          "status": {"type": "string"}
        }
      }
    }
  }, (request, reply) ->
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
      if c.isExam
        status = c.pushExamDanmaku(new Danmaku(request.body))
      else
        status = await c.pushDanmaku(new Danmaku(request.body))
      if status is 1
        reply.send({"status": "ok"})
    catch err
      reply.code(400).send(err)
      console.error(err)
  )

  fastify.get("/channel/:cname/danmaku", {
    "response": {
      "200": {
        "type": "object",
        "properties": {
          "result": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "content": "string",
                "color": "string",
                "position": "string",
                "offset": "integer"
              }
            }
          },
          "status": {"type": "string"}
        }
      }
    }
  }, (request, reply) ->
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
      reply.send({"result": danmakus, "status": "ok"})
    catch err
      reply.code(400).send(err)
      console.error(err)
  )

  fastify.post("/channel/:cname/examination", {
    "response": {
      "200": {
        "type": "object",
        "properties": {
          "status": {"type": "string"}
        }
      }
    }
  }, (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        reply.code(404)
        .send(new Error("Channel #{request.params["cname"]} Not Found"))
        return
      if not c.isExam
        reply.code(400)
        .send(
          new Error( "Channel #{request.params["cname"]} has no examination")
        )
        return
      if c.isExam and request.headers["x-danmaku-exam-key"] isnt c.examPassword
        reply.code(403).send(new Error("Wrong Password"))
        return
      if request.body["content"].length is 0
        reply.send(new Error("Empty Danmaku"))
        return
      status = await c.pushDanmaku(new Danmaku(request.body))
      if (status == 1)
        reply.send({"status": "ok"})
    catch err
      reply.code(400).send(err)
      console.error(err)
  )

  fastify.get("/channel/:cname/examination", {
    "response": {
      "200": {
        "type": "object",
        "properties": {
          "result": {
            "type": "array",
            "items": {
              "type": "object",
              "properties": {
                "content": "string",
                "color": "string",
                "position": "string",
                "offset": "integer"
              }
            }
          },
          "status": {"type": "string"}
        }
      }
    }
  }, (request, reply) ->
    try
      c = channelManager.getChannelByName(request.params["cname"])
      if not c?
        reply.code(404)
        .send(new Error("Channel #{request.params["cname"]} Not Found"))
        return
      if not c.isExam
        reply.code(403)
        .send(
          new Error( "Channel #{request.params["cname"]} has no examination")
        )
        return
      if c.isExam and request.headers["x-danmaku-exam-key"] isnt c.examPassword
        reply.code(403).send(new Error("Wrong Password"))
        return
      danmakus = c.getExamDanmakus()
      reply.send({"result": danmakus, "status": "ok"})
    catch err
      reply.code(400).send(err)
      console.error(err)
  )

  next()
