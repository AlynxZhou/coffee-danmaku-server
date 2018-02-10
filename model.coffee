fs = require("fs")
Promise = require("bluebird")
fp = require("fastify-plugin")

module.exports = fp((fastify, opts, next) ->
  { redis } = fastify
  Promise.promisifyAll(redis)

  class Danmaku
    constructor: (content = "", color = "white",
    position = "fly", offset = Date.now()) ->
      @content = content
      @color = color
      @position = position
      @offset = offset
      if content instanceof Object
        @content = content["content"]
        @color = content["color"]
        @position = content["position"]
        if content["offset"]?
          @offset = content["offset"]
      else if content instanceof String
        @fromString(content)
      if @content.length > 234
        @content = @content.substring(0, 234)

    toString: () =>
      return JSON.stringify({
        "content": @content,
        "color": @color,
        "position": @position,
        "offset": @offset
      })

    fromString: (json) =>
      obj = JSON.parse(json)
      @content = obj["content"]
      @color = obj["color"]
      @position = obj["position"]
      if obj["offset"]?
        @time = obj["offset"]

  class Channel
    constructor: (name, desc, expireTime = null,
    isOpen = true, password = null, useBlacklist = false) ->
      @redis = redis
      @name = name
      @desc = desc
      @expireTime = expireTime
      @isOpen = isOpen
      @password = password
      @useBlacklist = useBlacklist
      @url = "/channel/#{@name}"
      @channelKey = "channel_#{@name}"
      @ipTime = {}

    toValue: () =>
      return {
        "name": @name,
        "desc": @desc,
        "expireTime": @expireTime,
        "isOpen": @isOpen,
        "url": @url,
        "useBlacklist": @useBlacklist
      }

    isExpired: () =>
      if @expireTime? and Date.now() > @expireTime
        return true
      return false

    pushDanmaku: (danmaku) =>
      return @redis.zaddAsync(@channelKey,
      danmaku["offset"], danmaku.toString())

    getDanmakus: (offset) =>
      return @redis.zrangebyscoreAsync(@channelKey, offset, Date.now())

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
      return result

    toString: () =>
      tmp = []
      for c in @channels
        tmp.push({
          "name": c.name,
          "desc": c.desc,
          "expireTime": c.expireTime,
          "isOpen": c.isOpen,
          "password": c.password,
          "useBlacklist": c.useBlacklist
        })
      return JSON.stringify({ "channels": tmp }, null, "  ")

    fromString: (json) =>
      tmp = JSON.parse(json)["channels"]
      if not tmp?
        return
      @channels = []
      for c in tmp
        @addChannel(new Channel(c.name, c.desc, c.expireTime,
        c.isOpen, c.password, c.useBlacklist))
      if not @getChannelByName("demo")?
        @addChannel(new Channel("demo", "test"))

  fastify.decorate("channelManager", new ChannelManager())
  fastify.decorate("Channel", Channel)
  fastify.decorate("Danmaku", Danmaku)
  fs.readFile("blacklist.txt", "utf8", (err, result) ->
    if err
      console.error(err)
    else
      blacklist = new RegExp(result)
      fastify.decorate("blacklist", blacklist)
    next()
  )
)
