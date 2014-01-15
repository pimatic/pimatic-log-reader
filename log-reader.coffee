module.exports = (env) ->

  # ##Dependencies
  # * from node.js
  util = require 'util'
  
  # * pimatic imports.
  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'
  _ = env.require 'lodash'

  Tail = require('tail').Tail

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
      for name in @config.attributes
        # that the value to 'unknown'
        @attributeValue[name] = 'unknown'
        # Get all possible values
        possibleValues = _.map(_.filter(@config.lines, (l) => l[name]?), (l) => l[name])
        # Add attribute definition
        @attributes[name] =
          description: "attribute #{name}"
          type: possibleValues
        # Create a getter for this attribute
        getter = 'get' + name[0].toUpperCase() + name.slice(1)
        @[getter] = () => Q @attributeValue[name]

      # On ervery new line in the log file
      @tail.on 'line', (data) =>
        # check all lines in config
        for line in @config.lines
          # for a match.
          if data.match(new RegExp line.match)
            # If a match occures then emit a "match"-event.
            @emit 'match', line, data
        return

      # When a match event occures
      @on 'match', (line, data) =>
        # then check for each prop in the config
        for prop in @config.attributes
          # if the prop is registed for the log line.
          if prop of line
            # When a value for the prop is define, then set the value
            # and emit the event.
            @attributeValue[prop] = line[prop]
            @emit prop, line[prop]
        return
      super()


  class LogWatcherPredicateProvider extends env.predicates.PredicateProvider
    listener: []

    constructor: (@framework) ->

    isTrue: (id, predicate) ->
      return Q false

    # Removes the notification for an with `notifyWhen` registered predicate. 
    cancelNotify: (id) ->
      l = listener[id]
      if l?
        l.destroy()
        delete @listener[id]

    canDecide: (predicate) ->
      info = @_findDevice predicate
      return if info? then 'event' else no 

    notifyWhen: (id, predicate, callback) ->
      info = @_findDevice predicate
      unless info?
        throw new Error 'Can not decide the predicate!'
      device = info.device

      deviceListener = (line, data) =>
        if line.match is info.line.match
          callback 'event'

      device.addListener 'match', deviceListener
      @listener[id] =
        destroy: () => device.removeListener 'match', deviceListener


    _findDevice: (predicate) ->
      for id, d of @framework.devices
        if d instanceof LogWatcher
          line = @_getLineWithPredicate d.config, predicate
          if line? then return {device: d, line: line}
      return null

    _getLineWithPredicate: (config, predicate) ->
      for line in config.lines
        if line.predicate? and predicate.match(new RegExp(line.predicate))
          return line
      return null


  # For testing...
  @LogReaderPlugin = LogReaderPlugin
  @LogWatcherPredicateProvider = LogWatcherPredicateProvider
  # Export the plugin.
  return plugin