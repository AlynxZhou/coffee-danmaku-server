fs = require("fs")

module.exports = (fastify, opts, next) ->
  { channelManager } = fastify
  if process.platform is "win32"
    require("readline").createInterface({
      input: process.stdin,
      output: process.stdout
    }).on("SIGINT", () ->
      process.emit("SIGINT")
    )
  process.on("SIGINT", () ->
    fs.writeFile("data.json", channelManager.toString(), (err) ->
      if err
        console.error(err)
      process.exit()
    )
  )
