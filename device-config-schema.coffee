module.exports = {
  title: "pimatic-log-reader device config schemas"
  LogWatcher: {
    title: "LogWatcher config options"
    type: "object"
    extensions: ["xAttributeOptions"]
    properties:
      template:
        description: "Template to use in GUI"
        type: "string"
        default: ""
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
