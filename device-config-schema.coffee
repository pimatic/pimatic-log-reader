module.exports =
  LogWatcher:
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