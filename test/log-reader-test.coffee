module.exports = (env) ->

  sinon = env.require 'sinon'
  cassert = env.require "cassert"
  _ = env.require 'lodash'
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
    frameworkDummy = null

    describe 'LogReaderPlugin', ->
      appDummy = {}
      frameworkDummy =
        ruleManager: 
          addPredicateProvider: sinon.spy()
        deviceManager:
          devices: {}
          registerDeviceClass: sinon.spy()
          getDevices: -> _.values(@devices)

      describe '#init()', ->
        it 'should accept minimal config', ->
          config = 
            plugin: 'log-reader'
          plugin.init(appDummy, frameworkDummy, config)
          assert frameworkDummy.deviceManager.registerDeviceClass.calledOnce
          firstCall = frameworkDummy.deviceManager.registerDeviceClass.getCall(0)
          assert firstCall.args[0] is "LogWatcher"

      describe '#createCallback()', ->
        it 'should create a LogWatcher with string attribute', ->
          firstCall = frameworkDummy.deviceManager.registerDeviceClass.getCall(0)
          sensorConfig = {
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
          }
          device = firstCall.args[1].createCallback(sensorConfig)
          assert device
          cassert device.tail.file is "/var/log/test"
          frameworkDummy.deviceManager.devices["test-sensor"] = device

        it 'should create a nLogWatcher  with number attribute', ->
          firstCall = frameworkDummy.deviceManager.registerDeviceClass.getCall(0)
          sensorConfig = {
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
          }
          device = firstCall.args[1].createCallback(sensorConfig)
          assert device
          cassert device.tail.file is "/var/log/temperature"
          frameworkDummy.deviceManager.devices["numeric-test-sensor"] = device

        it 'should create a LogWatcher with boolean attribute', ->
          firstCall = frameworkDummy.deviceManager.registerDeviceClass.getCall(0)
          sensorConfig = {
            id: "test-sensor2"
            name: "a test sensor2"
            class: "LogWatcher"
            file: "/var/log/test2"
            attributes: [
              {
                name: "someProp"
                type: "boolean"
              }
            ]
            lines: [
              {
                match: "test 1"
                predicate: "test predicate 1"
                "someProp": true
              }
              {
                match: "test 2"
                predicate: "test predicate 2"
                "someProp": false
              }
            ]
          }
          device = firstCall.args[1].createCallback(sensorConfig)
          assert device
          cassert device.tail.file is "/var/log/test2"
          frameworkDummy.deviceManager.devices["test-sensor2"] = device
          
    describe 'LogWatcher', ->
      describe '#attributes', ->  
        it 'sensor 1 should have the attribute', ->
          sensor = frameworkDummy.deviceManager.devices["test-sensor"]
          prop = sensor.attributes.someProp
          cassert prop?
          cassert prop.type is "string"
          assert.deepEqual prop.enum, ["1", "2"]

        it "should have the getter function", ->
          sensor = frameworkDummy.deviceManager.devices["test-sensor"]
          cassert typeof sensor.getSomeProp is "function"

        it 'sensor 2 should have the attribute', ->
          sensor2 = frameworkDummy.deviceManager.devices["numeric-test-sensor"]
          prop = sensor2.attributes.temperature
          cassert prop?
          cassert prop.type is "number"

        it 'sensor 3 should have the attribute', ->
          sensor2 = frameworkDummy.deviceManager.devices["numeric-test-sensor"]
          prop = sensor2.attributes.temperature
          cassert prop?
          cassert prop.type is "boolean"
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
          
        it 'sensor 2 should react to log: test 1', (finish) ->
          sensor.tail.emit 'line', 'test 1'
          sensor.getSomeProp().then( (value) ->
            assert.equal value, true
            finish()
          ).catch(finish).done()

    describe 'LogWatcherPredicateProvider', ->
      describe '#parsePredicate()', ->
        it 'should decide: test predicate 1', ->
          provider = frameworkDummy.ruleManager.addPredicateProvider.getCall(0).args[0]
          result = provider.parsePredicate 'test predicate 1'
          cassert result?
          cassert result.token is 'test predicate 1'
          cassert result.nextInput is ''

        it 'should decide: test predicate 2', ->
          provider = frameworkDummy.ruleManager.addPredicateProvider.getCall(0).args[0]
          result = provider.parsePredicate 'test predicate 2'
          cassert result?
          cassert result.token is 'test predicate 2'
          cassert result.nextInput is ''

        it 'should not decide: test predicate 3', ->
          provider = frameworkDummy.ruleManager.addPredicateProvider.getCall(0).args[0]
          result = provider.parsePredicate 'test predicate 3'
          cassert not result?

      describe 'LogWatcherPredicateHandler', -> 
        describe '#on "change"', ->
          it 'should notify: test predicate 1', (finish) ->
            provider = frameworkDummy.ruleManager.addPredicateProvider.getCall(0).args[0]
            result = provider.parsePredicate 'test predicate 1'
            cassert result?
            predHandler = result.predicateHandler
            cassert predHandler?
            predHandler.setup()
            predHandler.once 'change', -> finish()
            sensor.tail.emit 'line', 'test 1'