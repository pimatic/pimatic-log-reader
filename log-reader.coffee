module.exports = (env) ->

  # ##Dependencies
  # * from node.js
  util = require 'util'
  
  # * pimatic imports.
  convict = env.require "convict"
  Q = env.require 'q'
  assert = env.require 'cassert'

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
      @states = {}

      # initialise all states with unknown
      for name in @config.states
        @states[name] = 'unknown'

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
        # then check for each state in the config
        for state in @config.states
          # if the state is registed for the log line.
          if state of line
            # When a value for the state is define, then set the value
            # and emit the event.
            @states[state] = line[state]
            @emit state, line[state]
        return


    getSensorValuesNames: ->
      return @config.states

    getSensorValue: (name)->
      if name in @config.states
        return Q.fcall => @states[name]
      throw new Error("Illegal sensor value name")


  class LogWatcherPredicateProvider extends env.predicates.PredicateProvider
    listener: []

    constructor: (@framework) ->

    isTrue: (id, predicate) ->
      return Q.fcall -> false

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