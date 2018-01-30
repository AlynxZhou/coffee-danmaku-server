fp = require("fastify-plugin")
Promise = require("bluebird")

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
  constructor: (redis, name, desc, isOpen = true) ->
    @redis = redis
    @name = name
    @desc = desc
    @isOpen = isOpen
    @url = "/channel/#{@name}"
    @channelKey = "channel_#{@name}"

  pushDanmaku: (danmaku) =>
    return @redis.zaddAsync(@channelKey, danmaku.time,
    danmaku.toString())

  getDanmakus: (time) =>
    return @redis.zrangebyscoreAsync(@channelKey, time, Date.now())

class ChannelManager
  constructor: (redis) ->
    @redis = redis
    @channels = []
    @addChannel(new Channel(@redis, "demo", "test", true))

  addChannel: (channel) =>
    @channels.push(channel)

  getChannel: (name) =>
    for channel in @channels
      if channel["name"] is name
        return channel
    return null

  listChannel: () =>
    return @channels


module.exports = fp((fastify, opts, next) ->
  { redis } = fastify
  Promise.promisifyAll(redis)
  fastify.decorate("channelManager", new ChannelManager(redis))
  fastify.decorate("Channel", Channel)
  fastify.decorate("Danmaku", Danmaku)
  next()
)
