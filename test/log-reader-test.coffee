module.exports = (env) ->

  cassert = env.require "cassert"
  proxyquire = env.require 'proxyquire'

  assert = require 'assert'

  describe "pimatic-log-reader", ->

    tailDummy = null

    class TailDummy extends require('events').EventEmitter
        
      constructor: (@file) ->
        tailDummy = this


    logReaderWrapper = proxyquire 'pimatic-log-reader',
      tail: 
        Tail: TailDummy

    plugin = logReaderWrapper env

    sensor = null
    provider = null

    describe 'LogReaderPlugin', ->

      appDummy = {}
      frameworkDummy =
        ruleManager: 
          addPredicateProvider: (_provider)->
            provider = _provider
        devices: {}

      describe '#init()', ->

        it 'should accept minimal config', ->
          config = 
            plugin: 'log-reader'
          plugin.init(appDummy, frameworkDummy, config)


      describe '#createSensor()', ->

        it 'should create a sensor', ->

          frameworkDummy.registerDevice = (s) ->
            cassert s?
            cassert s.id?
            cassert s.name?
            frameworkDummy.devices["test-sensor"] = sensor = s

          sensorConfig =
            id: "test-sensor"
            name: "a test sensor"
            class: "LogWatcher"
            file: "/var/log/test"
            attributes: ["someProp"]
            lines: [
              {
                match: "test 1"
                predicate: "test predicate 1"
                "someProp": "1"
              }
              {
                match: "test 2"
                predicate: "test predicate 2"
                "someProp": "2"
              }
            ]




          res = plugin.createDevice sensorConfig
          cassert res is true
          cassert tailDummy.file is "/var/log/test"
          cassert sensor?

    describe 'LogWatcher', ->


      describe '#attributes', ->  

        it 'should have the attribute', ->
          prop = sensor.attributes.someProp
          cassert prop?
          cassert Array.isArray prop.type
          assert.deepEqual prop.type, ["1", "2"]

        it "should have the getter function", ->
          cassert typeof sensor.getSomeProp is "function"

      describe '#getSomeProp()', ->

        it 'should return unknown', (finish) ->
          sensor.getSomeProp().then( (value) ->
            assert.equal value, 'unknown'
            finish()
          ).catch(finish).done()

        it 'should react to log: test 1', (finish) ->
          tailDummy.emit 'line', 'test 1'
          sensor.getSomeProp().then( (value) ->
            assert.equal value, '1'
            finish()
          ).catch(finish).done()

        it 'should react to log: test 2', (finish) ->
          tailDummy.emit 'line', 'test 2'
          sensor.getSomeProp().then( (value) ->
            assert.equal value, '2'
            finish()
          ).catch(finish).done()

    describe 'LogWatcherPredicateProvider', ->

      describe '#canDecide()', ->

        it 'should decide: test predicate 1', ->
          result = provider.canDecide 'test predicate 1'
          cassert result is 'event'

        it 'should decide: test predicate 2', ->
          result = provider.canDecide 'test predicate 2'
          cassert result is 'event'

        it 'should not decide: test predicate 3', ->
          result = provider.canDecide 'test predicate 3'
          cassert result is no

      describe '#notifyWhen()', ->

        it 'should notify: test predicate 1', (finish) ->

          provider.notifyWhen 't1', 'test predicate 1', ->
            finish()
          
          tailDummy.emit 'line', 'test 1'


