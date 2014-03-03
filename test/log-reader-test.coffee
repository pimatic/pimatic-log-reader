module.exports = (env) ->

  cassert = env.require "cassert"

  assert = require 'assert'

  describe "pimatic-log-reader", ->

    env.Tail = (
      class TailDummy extends require('events').EventEmitter
        constructor: (@file) -> 
    )

    plugin = require('pimatic-log-reader') env

    sensor = null
    sensor2 = null
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

        it 'should create a state sensor', ->

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
          cassert sensor.tail.file is "/var/log/test"
          cassert sensor?

        it 'should create a numeric sensor', ->

          frameworkDummy.registerDevice = (s) ->
            cassert s?
            cassert s.id?
            cassert s.name?
            cassert s.attributes.temperature?
            cassert s.attributes.temperature.type is Number
            frameworkDummy.devices["numeric-test-sensor"] = sensor2 = s

          sensorConfig =
            id: "numeric-test-sensor"
            name: "a temperature test sensor"
            class: "LogWatcher"
            file: "/var/log/temperature"
            attributes: [
              {
                name: "temperature"
                type: "number"
              }
            ]
            lines: [
              {
                match: "temperature: (.+)"
                temperature: "$1"
              }
            ]

          res = plugin.createDevice sensorConfig
          cassert res is true
          cassert sensor2.tail.file is "/var/log/temperature"
          cassert sensor2?

    describe 'LogWatcher', ->

      describe '#attributes', ->  

        it 'sensor 1 should have the attribute', ->
          prop = sensor.attributes.someProp
          cassert prop?
          cassert Array.isArray prop.type
          assert.deepEqual prop.type, ["1", "2"]

        it "should have the getter function", ->
          cassert typeof sensor.getSomeProp is "function"

        it 'sensor 2 should have the attribute', ->
          prop = sensor2.attributes.temperature
          cassert prop?
          cassert prop.type is Number

      describe '#getSomeProp()', ->

        it 'sensor 1 should return unknown', (finish) ->
          sensor.getSomeProp().then( (value) ->
            assert.equal value, 'unknown'
            finish()
          ).catch(finish).done()

        it 'sensor 1 should react to log: test 1', (finish) ->
          sensor.tail.emit 'line', 'test 1'
          sensor.getSomeProp().then( (value) ->
            assert.equal value, '1'
            finish()
          ).catch(finish).done()

        it 'sensor 1 should react to log: test 2', (finish) ->
          sensor.tail.emit 'line', 'test 2'
          sensor.getSomeProp().then( (value) ->
            assert.equal value, '2'
            finish()
          ).catch(finish).done()

        it 'sensor 2 should return 0', (finish) ->
          sensor2.getTemperature().then( (value) ->
            assert.equal value, 0
            finish()
          ).catch(finish).done()

        it 'sensor 2 should react to log: temperature: 10.0', (finish) ->
          sensor2.tail.emit 'line', 'temperature: 10.0'
          sensor2.getTemperature().then( (value) ->
            assert.equal value, 10.0
            finish()
          ).catch(finish).done()

        it 'sensor 2 should react to log: temperature: 12.1', (finish) ->
          sensor2.tail.emit 'line', 'temperature: 12.1'
          sensor2.getTemperature().then( (value) ->
            assert.equal value, '12.1'
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
          
          sensor.tail.emit 'line', 'test 1'


