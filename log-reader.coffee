module.exports = (env) ->

  # ##Dependencies
  # * from node.js
  util = require 'util'
  
  # * pimatic imports.
  Promise = env.require 'bluebird'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  M = env.matcher
  Tail = env.Tail or require('tail').Tail
  t = env.require('decl-api').types
  LineByLineReader = require("line-by-line")

  # ##The LogReaderPlugin
  class LogReaderPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) ->
      @framework.ruleManager.addPredicateProvider new LogWatcherPredicateProvider(@framework)

      deviceConfigDef = require("./device-config-schema")

      @framework.deviceManager.registerDeviceClass("LogWatcher", {
        configDef: deviceConfigDef.LogWatcher, 
        createCallback: (config, lastState) => return new LogWatcher(config, lastState)
      })

  plugin = new LogReaderPlugin

    # ##LogWatcher Sensor
  class LogWatcher extends env.devices.Sensor

    constructor: (@config, lastState) ->
      @id = @config.id
      @name = @config.name
      @attributeValue = {}
      @changedAttributeValue = {}

      @attributes = {}
      # initialise all attributes
      for attr, i in @config.attributes
        do (attr) =>
          # legazy support
          if typeof attr is "string"
            attr = {
              name: attr
              type: "string"
            }
            @config.attributes[i] = attr

          name = attr.name
          assert attr.name?
          assert attr.type?

          lastValue = lastState?[name]?.value
          unless typeof lastValue is attr.type
            lastValue = null

          switch attr.type
            when "string"
              # that the value to 'unknown'
              @attributeValue[name] = lastValue
              # Get all possible values
              possibleValues = _.map(_.filter(@config.lines, (l) => l[name]?), (l) => l[name])
              # Add attribute definition
              @attributes[name] =
                description: name
                type: t.string
                enum: possibleValues
            when "number"
              @attributeValue[name] = lastValue
              @attributes[name] =
                description: name
                type: t.number
              if attr.unit? then @attributes[name].unit = attr.unit
              
            when "boolean"
              @attributeValue[name] = lastValue
              @attributes[name] =
                description: name
                type: t.boolean
            else
              throw new Error("Illegal type: #{attr.type} for attributes #{name} in LogWatcher.")
          if _.isArray attr.labels
            @attributes[name].labels = attr.labels
          # Create a getter for this attribute
          @_createGetter name, ( => Promise.resolve @attributeValue[name] )


      onLine = (data) =>
        # check all lines in config
        for line in @config.lines
          # for a match.
          matches = new RegExp(line.match).exec(data)
          if matches?
            # If a match occures then emit a "match"-event.
            @emit 'match', line, data, matches
        return

      @_tailing = no
      onMatch = (line, data, matches) =>
        # then check for each prop in the config
        for attr in @config.attributes
          # if the attr is registered for the log line.
          if attr.name of line
            # When a value for the attr is defined, then set the value
            # and emit the event.
            valueToSet = line[attr.name]
            value = null
            
            if attr.type is "boolean" 
              value = line[attr.name]
            else
              matchesRegexValue = valueToSet.match(/\$(\d+)/)
              if matchesRegexValue?
                value = matches[parseInt(matchesRegexValue[1], 10)]
              else 
                value = line[attr.name]

              if attr.type is "number" then value = parseFloat(value)

            if @_tailing
              @attributeValue[attr.name] = value
              @emit(attr.name, value)
            else
              if @attributeValue[attr.name] isnt value
                @attributeValue[attr.name] = value
                @changedAttributeValue[attr.name] = value
        return

      # When a match event occures
      @on 'match', onMatch

      # read the file to get initial values:
      lr = new LineByLineReader(@config.file)
      lr.on "error", (err) -> 
        env.logger.error err.message
        env.logger.debug err.stack
      lr.on "line", onLine
      lr.on "end", =>
        @_tailing = yes
        for attrName, value of @changedAttributeValue
          @emit(attrName, value)
        @changedAttributeValue = {}
        # If we have read the full file then tail the file
        @tail = new Tail(@config.file)
        # On ervery new line in the log file
        @tail.on 'line', onLine
      super()


  class LogWatcherPredicateProvider extends env.predicates.PredicateProvider
    listener: []

    constructor: (@framework) ->

    parsePredicate: (input, context) ->
      for id, d of @framework.deviceManager.devices
        if d instanceof LogWatcher
          info = @_getLineWithPredicate d.config, input, context
          if info?
            return {
              token: info.token
              nextInput: input.substring(info.token.length)
              predicateHandler: new LogWatcherPredicateHandler(this, d, info.line)
            }
      return null

    _getLineWithPredicate: (config, input, context) ->
      for line in config.lines
        if line.predicate? 
          m = M(input, context).match(line.predicate)
          if m.hadMatch()
            match = m.getFullMatch()
            return {line, token: match, nextInput: input.substring(match.length)}
      return null

  class LogWatcherPredicateHandler extends env.predicates.PredicateHandler

    constructor: (@provider, @device, @line) ->

    setup: ->
      @deviceListener = (line, data) => 
        if @device._tailing and line.match is @line.match then @emit('change', 'event')
      @device.addListener 'match', @deviceListener
      super()
    getValue: -> Promise.resolve(false)
    destroy: -> 
      @device.removeListener 'match', @deviceListener
      super()
    getType: -> 'event'

  # For testing...
  @LogReaderPlugin = LogReaderPlugin
  @LogWatcherPredicateProvider = LogWatcherPredicateProvider
  # Export the plugin.
  return plugin