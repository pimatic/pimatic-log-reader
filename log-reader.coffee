module.exports = (env) ->

  # ##Dependencies
  # * from node.js
  util = require 'util'
  
  # * pimatic imports.
  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'
  _ = env.require 'lodash'
  M = env.matcher
  Tail = env.Tail or require('tail').Tail

  # ##The LogReaderPlugin
  class LogReaderPlugin extends env.plugins.Plugin

    init: (app, @framework, @config) ->
      @framework.ruleManager.addPredicateProvider new LogWatcherPredicateProvider(@framework)

    createDevice: (config) ->
      switch config.class
        when 'LogWatcher'
          assert config.name?
          assert config.id?
          watcher = new LogWatcher(config)
          @framework.registerDevice watcher
          return true
        else
          return false

  plugin = new LogReaderPlugin

    # ##LogWatcher Sensor
  class LogWatcher extends env.devices.Sensor

    constructor: (@config) ->
      @id = config.id
      @name = config.name
      @tail = new Tail(config.file)
      @attributeValue = {}

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
          switch attr.type
            when "string"
              # that the value to 'unknown'
              @attributeValue[name] = 'unknown'
              # Get all possible values
              possibleValues = _.map(_.filter(@config.lines, (l) => l[name]?), (l) => l[name])
              # Add attribute definition
              @attributes[name] =
                description: name
                type: possibleValues
            when "number"
              @attributeValue[name] = 0
              @attributes[name] =
                description: name
                type: Number
              if attr.unit? then @attributes[name].unit = attr.unit
            else
              throw new Error("Illegal type: #{attr.type} for attributes #{name} in LogWatcher.")
          # Create a getter for this attribute
          getter = 'get' + name[0].toUpperCase() + name.slice(1)
          @[getter] = () => Q @attributeValue[name]


      # On ervery new line in the log file
      @tail.on 'line', (data) =>
        # check all lines in config
        for line in @config.lines
          # for a match.
          matches = new RegExp(line.match).exec(data)
          if matches?
            # If a match occures then emit a "match"-event.
            @emit 'match', line, data, matches
        return

      # When a match event occures
      @on 'match', (line, data, matches) =>
        # then check for each prop in the config
        for attr in @config.attributes
          # if the attr is registed for the log line.
          if attr.name of line
            # When a value for the attr is defined, then set the value
            # and emit the event.
            valueToSet = line[attr.name]
            value = null
            matchesRegexValue = valueToSet.match(/\$(\d+)/)
            if matchesRegexValue?
              value = matches[parseInt(matchesRegexValue[1], 10)]
            else 
              value = line[attr.name]

            if attr.type is "number" then value = parseFloat(value)

            @attributeValue[attr.name] = value 
            @emit attr.name, value
        return
      super()


  class LogWatcherPredicateProvider extends env.predicates.PredicateProvider
    listener: []

    constructor: (@framework) ->

    isTrue: (id, predicate) ->
      return Q false

    # Removes the notification for an with `notifyWhen` registered predicate. 
    cancelNotify: (id) ->
      l = @listener[id]
      if l?
        l.destroy()
        delete @listener[id]
      else
        env.logger.error "Could not find listener to cancel"

    canDecide: (predicate, context) ->
      info = @_findDevice predicate, context
      return if info? then 'event' else no 

    notifyWhen: (id, predicate, callback, context) ->
      info = @_findDevice predicate, context
      unless info?
        throw new Error 'Can not decide the predicate!'
      device = info.device

      deviceListener = (line, data) =>
        if line.match is info.line.match
          callback 'event'

      device.addListener 'match', deviceListener
      @listener[id] =
        destroy: () => device.removeListener 'match', deviceListener


    _findDevice: (predicate, context) ->
      for id, d of @framework.devices
        if d instanceof LogWatcher
          line = @_getLineWithPredicate d.config, predicate, context
          if line? then return {device: d, line: line}
      return null

    _getLineWithPredicate: (config, predicate, context) ->
      for line in config.lines
        #add autocomplete:
        
        if line.predicate? 
          doesMatch = no
          M(predicate, context).match(line.predicate).onEnd( => doesMatch = yes)
          if doesMatch
            return line
      return null


  # For testing...
  @LogReaderPlugin = LogReaderPlugin
  @LogWatcherPredicateProvider = LogWatcherPredicateProvider
  # Export the plugin.
  return plugin