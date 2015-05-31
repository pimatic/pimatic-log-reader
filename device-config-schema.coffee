module.exports = {
  title: "pimatic-log-reader device config schemas"
  LogWatcher: {
    title: "LogWatcher config options"
    type: "object"
    extensions: ["xAttributeOptions"]
    properties:
      file:
        description: "The file to watch"
        type: "string"
        default: ""
      attributes:
        description: "Attributes of the device"
        type: "array"
      lines:
        description: "Lines to match"
        type: "array"
        default: ""
  }
}
