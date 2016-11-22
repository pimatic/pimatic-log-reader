module.exports = {
  title: "pimatic-log-reader device config schemas"
  LogWatcher: {
    title: "LogWatcher config options"
    type: "object"
    extensions: ["xAttributeOptions", "xLink"]
    properties:
      template:
        description: "Template to use in GUI"
        type: "string"
        required: false
      file:
        description: "The file to watch"
        type: "string"
      attributes:
        description: "Attributes of the device"
        type: "array"
        items:
          type: "object"
          properties:
            name:
              type: "string"
              description: "The name of the attribute"
            type:
              type: "string"
              enum: ["string", "number", "boolean"]
            label:
              description: "A custom label to use in the frontend."
              type: "string"
              required: false
            discrete:
              description: "
                Should be set to true if the value does not change continuously over time.
              "
              type: "boolean"
              required: false
            unit:
              type: "string"
              description: "The unit of the attribute. Only works if type is a number."
              required: no
            acronym:
              type: "string"
              description: "Acronym to show as value label in the frontend"
              required: no
      lines:
        description: "Lines to match"
        type: "array"
        default: ""
        items:
          type: "object"
          nameProperty: "match"
          properties:
            match:
              type: "string"
            predicate:
              type: "string"
              required: false
          additionalProperties:
            description: """
              You can add properties for attributes as key value pairs. The attribute with the name
              of the added property will be set to the value of the property. You can use
              $1, $2, ... as placeholder for capture groups in the match regular expression.
            """
            type: "string"
  }
}
