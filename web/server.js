var connect = require('connect')
  , port = process.env.PORT || 9090;

console.log("Listening on port", port, "...")
connect().use(connect.static(__dirname)).listen(port)
