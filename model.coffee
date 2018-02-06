fp = require("fastify-plugin")
Promise = require("bluebird")

module.exports = fp((fastify, opts, next) ->
  { redis } = fastify
  Promise.promisifyAll(redis)

  class Danmaku
    constructor: (content = "", color = "white", position = "fly") ->
      @content = content
      @color = color
      @position = position
      @time = Date.now()
      if content instanceof Object
        @content = content["content"]
        @color = content["color"]
        @position = content["position"]
      else if content instanceof String
        @fromString(content)
      if @content.length > 234
        @content = @content.substring(0, 234)

    toString: () =>
      return JSON.stringify({
        "content": @content,
        "color": @color,
        "position": @position,
        "time": @time
      })

    fromString: (json) =>
      obj = JSON.parse(json)
      @content = obj["content"]
      @color = obj["color"]
      @position = obj["position"]
      if obj["time"]?
        @time = obj["time"]

  class Channel
    constructor: (name, desc, expireTime = null,
    isOpen = true, password = null) ->
      @redis = redis
      @name = name
      @desc = desc
      @expireTime = expireTime
      @isOpen = isOpen
      @password = password
      @url = "/channel/#{@name}"
      @channelKey = "channel_#{@name}"
      @ipTime = {}

    toValue: () =>
      return {
        "name": @name,
        "desc": @desc,
        "expireTime": @expireTime,
        "isOpen": @isOpen,
        "url": @url
      }

    isExpired: () =>
      if @expireTime? and Date.now() > @expireTime
        return true
      return false

    pushDanmaku: (danmaku) =>
      return @redis.zaddAsync(@channelKey, danmaku.time, danmaku.toString())

    getDanmakus: (time) =>
      return @redis.zrangebyscoreAsync(@channelKey, time, Date.now())

    delete: () =>
      return @redis.delAsync(@channelKey)

  class ChannelManager
    constructor: () ->
      @channels = []
      @addChannel(new Channel("demo", "test"))

    addChannel: (channel) =>
      @cleanChannels()
      @channels.push(channel)

    getChannelByName: (name) =>
      @cleanChannels()
      for c in @channels
        if c.name is name
          return c
      return null

    cleanChannels: () =>
      for i in [0...@channels.length]
        if @channels[i].isExpired()
          @channels[i].delete()
          @channels.splice(i, 1)

    listChannelValue: () =>
      @cleanChannels()
      result = []
      for c in @channels
        result.push(c.toValue())
      return res

    toString: () =>
      tmp = []
      for c in @channels
        tmp.push({
          "name": c.name,
          "desc": c.desc,
          "expireTime": c.expireTime,
          "isOpen": c.isOpen,
          "password": c.password
        })
      return JSON.stringify({ "channels": tmp }, null, "  ")

    fromString: (json) =>
      tmp = JSON.parse(json)["channels"]
      if not tmp?
        return
      @channels = []
      for c in tmp
        @addChannel(new Channel(c.name, c.desc, c.expireTime,
        c.isOpen, c.password))
      if not @getChannelByName("demo")?
        @addChannel(new Channel("demo", "test"))

  fastify.decorate("channelManager", new ChannelManager())
  fastify.decorate("Channel", Channel)
  fastify.decorate("Danmaku", Danmaku)
  next()
)
