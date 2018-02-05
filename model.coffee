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
      @channels = {}
      @addChannel(new Channel("demo", "test"))

    addChannel: (channel) =>
      @cleanChannels()
      @channels[channel["name"]] = channel

    getChannelByName: (name) =>
      @cleanChannels()
      return @channels[name]

    cleanChannels: () =>
      for k, v of @channels
        if v.isExpired()
          v.delete()
          delete @channels[k]

    listChannel: () =>
      @cleanChannels()
      res = []
      for k, v of @channels
        res.push(v.toValue())
      return res

  fastify.decorate("channelManager", new ChannelManager())
  fastify.decorate("Channel", Channel)
  fastify.decorate("Danmaku", Danmaku)
  next()
)
