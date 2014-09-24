path = require 'path'
temp = require 'temp'
CSON = require 'season'
fs = require 'fs-plus'

describe "Config", ->
  dotAtomPath = path.join(temp.dir, 'dot-atom-dir')
  dotAtomPath = null

  beforeEach ->
    dotAtomPath = temp.path('dot-atom-dir')

  describe ".get(keyPath)", ->
    it "allows a key path's value to be read", ->
      expect(atom.config.set("foo.bar.baz", 42)).toBe 42
      expect(atom.config.get("foo.bar.baz")).toBe 42
      expect(atom.config.get("bogus.key.path")).toBeUndefined()

    it "returns a deep clone of the key path's value", ->
      atom.config.set('value', array: [1, b: 2, 3])
      retrievedValue = atom.config.get('value')
      retrievedValue.array[0] = 4
      retrievedValue.array[1].b = 2.1
      expect(atom.config.get('value')).toEqual(array: [1, b: 2, 3])

    it "merges defaults into the returned value if both the assigned value and the default value are objects", ->
      atom.config.setDefaults("foo", a: 1, b: 2)
      atom.config.set("foo", a: 3)
      expect(atom.config.get("foo")).toEqual {a: 3, b: 2}

      atom.config.set("foo", 7)
      expect(atom.config.get("foo")).toBe 7

      atom.config.set("bar.baz", a: 3)
      atom.config.setDefaults("bar", baz: 7)
      expect(atom.config.get("bar.baz")).toEqual {a: 3}

  describe ".set(keyPath, value)", ->
    it "allows a key path's value to be written", ->
      expect(atom.config.set("foo.bar.baz", 42)).toBe 42
      expect(atom.config.get("foo.bar.baz")).toBe 42

    it "updates observers and saves when a key path is set", ->
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      atom.config.set("foo.bar.baz", 42)

      expect(atom.config.save).toHaveBeenCalled()
      expect(observeHandler).toHaveBeenCalledWith 42, {previous: undefined}

    describe "when the value equals the default value", ->
      it "does not store the value", ->
        atom.config.setDefaults "foo",
          same: 1
          changes: 1
          sameArray: [1, 2, 3]
          sameObject: {a: 1, b: 2}
          null: null
          undefined: undefined
        expect(atom.config.settings.foo).toBeUndefined()

        atom.config.set('foo.same', 1)
        atom.config.set('foo.changes', 2)
        atom.config.set('foo.sameArray', [1, 2, 3])
        atom.config.set('foo.null', undefined)
        atom.config.set('foo.undefined', null)
        atom.config.set('foo.sameObject', {b: 2, a: 1})
        expect(atom.config.settings.foo).toEqual {changes: 2}

        atom.config.set('foo.changes', 1)
        expect(atom.config.settings.foo).toEqual {}

  describe ".getDefault(keyPath)", ->
    it "returns a clone of the default value", ->
      atom.config.setDefaults("foo", same: 1, changes: 1)
      expect(atom.config.getDefault('foo.same')).toBe 1
      expect(atom.config.getDefault('foo.changes')).toBe 1

      atom.config.set('foo.same', 2)
      atom.config.set('foo.changes', 3)
      expect(atom.config.getDefault('foo.same')).toBe 1
      expect(atom.config.getDefault('foo.changes')).toBe 1

      initialDefaultValue = [1, 2, 3]
      atom.config.setDefaults("foo", bar: initialDefaultValue)
      expect(atom.config.getDefault('foo.bar')).toEqual initialDefaultValue
      expect(atom.config.getDefault('foo.bar')).not.toBe initialDefaultValue

  describe ".isDefault(keyPath)", ->
    it "returns true when the value of the key path is its default value", ->
      atom.config.setDefaults("foo", same: 1, changes: 1)
      expect(atom.config.isDefault('foo.same')).toBe true
      expect(atom.config.isDefault('foo.changes')).toBe true

      atom.config.set('foo.same', 2)
      atom.config.set('foo.changes', 3)
      expect(atom.config.isDefault('foo.same')).toBe false
      expect(atom.config.isDefault('foo.changes')).toBe false

  describe ".toggle(keyPath)", ->
    it "negates the boolean value of the current key path value", ->
      atom.config.set('foo.a', 1)
      atom.config.toggle('foo.a')
      expect(atom.config.get('foo.a')).toBe false

      atom.config.set('foo.a', '')
      atom.config.toggle('foo.a')
      expect(atom.config.get('foo.a')).toBe true

      atom.config.set('foo.a', null)
      atom.config.toggle('foo.a')
      expect(atom.config.get('foo.a')).toBe true

      atom.config.set('foo.a', true)
      atom.config.toggle('foo.a')
      expect(atom.config.get('foo.a')).toBe false

  describe ".restoreDefault(keyPath)", ->
    it "sets the value of the key path to its default", ->
      atom.config.setDefaults('a', b: 3)
      atom.config.set('a.b', 4)
      expect(atom.config.get('a.b')).toBe 4
      atom.config.restoreDefault('a.b')
      expect(atom.config.get('a.b')).toBe 3

      atom.config.set('a.c', 5)
      expect(atom.config.get('a.c')).toBe 5
      atom.config.restoreDefault('a.c')
      expect(atom.config.get('a.c')).toBeUndefined()

  describe ".pushAtKeyPath(keyPath, value)", ->
    it "pushes the given value to the array at the key path and updates observers", ->
      atom.config.set("foo.bar.baz", ["a"])
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      expect(atom.config.pushAtKeyPath("foo.bar.baz", "b")).toBe 2
      expect(atom.config.get("foo.bar.baz")).toEqual ["a", "b"]
      expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz"), {previous: ['a']}

  describe ".unshiftAtKeyPath(keyPath, value)", ->
    it "unshifts the given value to the array at the key path and updates observers", ->
      atom.config.set("foo.bar.baz", ["b"])
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      expect(atom.config.unshiftAtKeyPath("foo.bar.baz", "a")).toBe 2
      expect(atom.config.get("foo.bar.baz")).toEqual ["a", "b"]
      expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz"), {previous: ['b']}

  describe ".removeAtKeyPath(keyPath, value)", ->
    it "removes the given value from the array at the key path and updates observers", ->
      atom.config.set("foo.bar.baz", ["a", "b", "c"])
      observeHandler = jasmine.createSpy "observeHandler"
      atom.config.observe "foo.bar.baz", observeHandler
      observeHandler.reset()

      expect(atom.config.removeAtKeyPath("foo.bar.baz", "b")).toEqual ["a", "c"]
      expect(atom.config.get("foo.bar.baz")).toEqual ["a", "c"]
      expect(observeHandler).toHaveBeenCalledWith atom.config.get("foo.bar.baz"), {previous: ['a', 'b', 'c']}

  describe ".getPositiveInt(keyPath, defaultValue)", ->
    it "returns the proper current or default value", ->
      atom.config.set('editor.preferredLineLength', 0)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      atom.config.set('editor.preferredLineLength', -1234)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      atom.config.set('editor.preferredLineLength', 'abcd')
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80
      atom.config.set('editor.preferredLineLength', null)
      expect(atom.config.getPositiveInt('editor.preferredLineLength', 80)).toBe 80

  describe ".save()", ->
    CSON = require 'season'

    beforeEach ->
      spyOn(CSON, 'writeFileSync')
      jasmine.unspy atom.config, 'save'

    describe "when ~/.atom/config.json exists", ->
      it "writes any non-default properties to ~/.atom/config.json", ->
        atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.json")
        atom.config.set("a.b.c", 1)
        atom.config.set("a.b.d", 2)
        atom.config.set("x.y.z", 3)
        atom.config.setDefaults("a.b", e: 4, f: 5)

        CSON.writeFileSync.reset()
        atom.config.save()

        expect(CSON.writeFileSync.argsForCall[0][0]).toBe(path.join(atom.config.configDirPath, "atom.config.json"))
        writtenConfig = CSON.writeFileSync.argsForCall[0][1]
        expect(writtenConfig).toBe atom.config.settings

    describe "when ~/.atom/config.json doesn't exist", ->
      it "writes any non-default properties to ~/.atom/config.cson", ->
        atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
        atom.config.set("a.b.c", 1)
        atom.config.set("a.b.d", 2)
        atom.config.set("x.y.z", 3)
        atom.config.setDefaults("a.b", e: 4, f: 5)

        CSON.writeFileSync.reset()
        atom.config.save()

        expect(CSON.writeFileSync.argsForCall[0][0]).toBe(path.join(atom.config.configDirPath, "atom.config.cson"))
        CoffeeScript = require 'coffee-script'
        writtenConfig = CSON.writeFileSync.argsForCall[0][1]
        expect(writtenConfig).toEqual atom.config.settings

  describe ".setDefaults(keyPath, defaults)", ->
    it "assigns any previously-unassigned keys to the object at the key path", ->
      atom.config.set("foo.bar.baz", a: 1)
      atom.config.setDefaults("foo.bar.baz", a: 2, b: 3, c: 4)
      expect(atom.config.get("foo.bar.baz.a")).toBe 1
      expect(atom.config.get("foo.bar.baz.b")).toBe 3
      expect(atom.config.get("foo.bar.baz.c")).toBe 4

      atom.config.setDefaults("foo.quux", x: 0, y: 1)
      expect(atom.config.get("foo.quux.x")).toBe 0
      expect(atom.config.get("foo.quux.y")).toBe 1

    it "emits an updated event", ->
      updatedCallback = jasmine.createSpy('updated')
      atom.config.observe('foo.bar.baz.a', callNow: false, updatedCallback)
      expect(updatedCallback.callCount).toBe 0
      atom.config.setDefaults("foo.bar.baz", a: 2)
      expect(updatedCallback.callCount).toBe 1

  describe ".onDidChange(keyPath)", ->
    [observeHandler, observeSubscription] = []

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      atom.config.set("foo.bar.baz", "value 1")
      observeSubscription = atom.config.onDidChange "foo.bar.baz", observeHandler

    it "does not fire the given callback with the current value at the keypath", ->
      expect(observeHandler).not.toHaveBeenCalledWith("value 1")

    it "fires the callback every time the observed value changes", ->
      observeHandler.reset() # clear the initial call
      atom.config.set('foo.bar.baz', "value 2")
      expect(observeHandler).toHaveBeenCalledWith("value 2", {previous: 'value 1'})
      observeHandler.reset()

      atom.config.set('foo.bar.baz', "value 1")
      expect(observeHandler).toHaveBeenCalledWith("value 1", {previous: 'value 2'})

  describe ".observe(keyPath)", ->
    [observeHandler, observeSubscription] = []

    beforeEach ->
      observeHandler = jasmine.createSpy("observeHandler")
      atom.config.set("foo.bar.baz", "value 1")
      observeSubscription = atom.config.observe "foo.bar.baz", observeHandler

    it "fires the given callback with the current value at the keypath", ->
      expect(observeHandler).toHaveBeenCalledWith("value 1")

    it "fires the callback every time the observed value changes", ->
      observeHandler.reset() # clear the initial call
      atom.config.set('foo.bar.baz', "value 2")
      expect(observeHandler).toHaveBeenCalledWith("value 2", {previous: 'value 1'})
      observeHandler.reset()

      atom.config.set('foo.bar.baz', "value 1")
      expect(observeHandler).toHaveBeenCalledWith("value 1", {previous: 'value 2'})

    it "fires the callback when the observed value is deleted", ->
      observeHandler.reset() # clear the initial call
      atom.config.set('foo.bar.baz', undefined)
      expect(observeHandler).toHaveBeenCalledWith(undefined, {previous: 'value 1'})

    it "fires the callback when the full key path goes into and out of existence", ->
      observeHandler.reset() # clear the initial call
      atom.config.set("foo.bar", undefined)

      expect(observeHandler).toHaveBeenCalledWith(undefined, {previous: 'value 1'})
      observeHandler.reset()

      atom.config.set("foo.bar.baz", "i'm back")
      expect(observeHandler).toHaveBeenCalledWith("i'm back", {previous: undefined})

    it "does not fire the callback once the observe subscription is off'ed", ->
      observeHandler.reset() # clear the initial call
      observeSubscription.off()
      atom.config.set('foo.bar.baz', "value 2")
      expect(observeHandler).not.toHaveBeenCalled()

  describe ".initializeConfigDirectory()", ->
    beforeEach ->
      if fs.existsSync(dotAtomPath)
        fs.removeSync(dotAtomPath)

      atom.config.configDirPath = dotAtomPath

    afterEach ->
      fs.removeSync(dotAtomPath)

    describe "when the configDirPath doesn't exist", ->
      it "copies the contents of dot-atom to ~/.atom", ->
        initializationDone = false
        jasmine.unspy(window, "setTimeout")
        atom.config.initializeConfigDirectory ->
          initializationDone = true

        waitsFor -> initializationDone

        runs ->
          expect(fs.existsSync(atom.config.configDirPath)).toBeTruthy()
          expect(fs.existsSync(path.join(atom.config.configDirPath, 'packages'))).toBeTruthy()
          expect(fs.isFileSync(path.join(atom.config.configDirPath, 'snippets.cson'))).toBeTruthy()
          expect(fs.isFileSync(path.join(atom.config.configDirPath, 'config.cson'))).toBeTruthy()
          expect(fs.isFileSync(path.join(atom.config.configDirPath, 'init.coffee'))).toBeTruthy()
          expect(fs.isFileSync(path.join(atom.config.configDirPath, 'styles.less'))).toBeTruthy()

  describe ".loadUserConfig()", ->
    beforeEach ->
      atom.config.configDirPath = dotAtomPath
      atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
      expect(fs.existsSync(atom.config.configDirPath)).toBeFalsy()

    afterEach ->
      fs.removeSync(dotAtomPath)

    describe "when the config file contains valid cson", ->
      beforeEach ->
        fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'baz'")
        atom.config.loadUserConfig()

      it "updates the config data based on the file contents", ->
        expect(atom.config.get("foo.bar")).toBe 'baz'

    describe "when the config file contains invalid cson", ->
      beforeEach ->
        spyOn(console, 'error')
        fs.writeFileSync(atom.config.configFilePath, "{{{{{")

      it "logs an error to the console and does not overwrite the config file on a subsequent save", ->
        atom.config.loadUserConfig()
        expect(console.error).toHaveBeenCalled()
        atom.config.set("hair", "blonde") # trigger a save
        expect(atom.config.save).not.toHaveBeenCalled()

    describe "when the config file does not exist", ->
      it "creates it with an empty object", ->
        fs.makeTreeSync(atom.config.configDirPath)
        atom.config.loadUserConfig()
        expect(fs.existsSync(atom.config.configFilePath)).toBe true
        expect(CSON.readFileSync(atom.config.configFilePath)).toEqual {}

  describe ".observeUserConfig()", ->
    updatedHandler = null

    beforeEach ->
      atom.config.configDirPath = dotAtomPath
      atom.config.configFilePath = path.join(atom.config.configDirPath, "atom.config.cson")
      expect(fs.existsSync(atom.config.configDirPath)).toBeFalsy()
      fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'baz'")
      atom.config.loadUserConfig()
      atom.config.observeUserConfig()
      updatedHandler = jasmine.createSpy("updatedHandler")
      atom.config.on 'updated', updatedHandler

    afterEach ->
      atom.config.unobserveUserConfig()
      fs.removeSync(dotAtomPath)

    describe "when the config file changes to contain valid cson", ->
      it "updates the config data", ->
        fs.writeFileSync(atom.config.configFilePath, "foo: { bar: 'quux', baz: 'bar'}")
        waitsFor 'update event', -> updatedHandler.callCount > 0
        runs ->
          expect(atom.config.get('foo.bar')).toBe 'quux'
          expect(atom.config.get('foo.baz')).toBe 'bar'

    describe "when the config file changes to contain invalid cson", ->
      beforeEach ->
        spyOn(console, 'error')
        fs.writeFileSync(atom.config.configFilePath, "}}}")
        waitsFor "error to be logged", -> console.error.callCount > 0

      it "logs a warning and does not update config data", ->
        expect(updatedHandler.callCount).toBe 0
        expect(atom.config.get('foo.bar')).toBe 'baz'
        atom.config.set("hair", "blonde") # trigger a save
        expect(atom.config.save).not.toHaveBeenCalled()

      describe "when the config file subsequently changes again to contain valid cson", ->
        beforeEach ->
          fs.writeFileSync(atom.config.configFilePath, "foo: bar: 'baz'")
          waitsFor 'update event', -> updatedHandler.callCount > 0

        it "updates the config data and resumes saving", ->
          atom.config.set("hair", "blonde")
          expect(atom.config.save).toHaveBeenCalled()

  describe "when there is a schema specified", ->
    schema = null

    describe '.setSchema(keyPath, schema)', ->
      it 'sets defaults specified by the schema', ->
        schema =
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12
            anObject:
              type: 'object'
              properties:
                nestedInt:
                  type: 'integer'
                  default: 24
                nestedObject:
                  type: 'object'
                  properties:
                    superNestedInt:
                      type: 'integer'
                      default: 36

        atom.config.setSchema('foo.bar', schema)
        expect(atom.config.get("foo.bar.anInt")).toBe 12
        expect(atom.config.get("foo.bar.anObject")).toEqual
          nestedInt: 24
          nestedObject:
            superNestedInt: 36

      it 'can set a non-object schema', ->
        schema =
          type: 'integer'
          default: 12

        atom.config.setSchema('foo.bar.anInt', schema)
        expect(atom.config.get("foo.bar.anInt")).toBe 12
        expect(atom.config.schemaForKeyPath('foo.bar.anInt')).toEqual
          type: 'integer'
          default: 12

      it 'creates a properly nested schema', ->
        schema =
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12

        atom.config.setSchema('foo.bar', schema)

        expect(atom.config.schema).toEqual
          type: 'object'
          properties:
            foo:
              type: 'object'
              properties:
                bar:
                  type: 'object'
                  properties:
                    anInt:
                      type: 'integer'
                      default: 12

    describe '.schemaForKeyPath(keyPath)', ->
      schema =
        type: 'object'
        properties:
          anInt:
            type: 'integer'
            default: 12

      atom.config.setSchema('foo.bar', schema)

      expect(atom.config.schemaForKeyPath('foo.bar')).toEqual
        type: 'object'
        properties:
          anInt:
            type: 'integer'
            default: 12

      expect(atom.config.schemaForKeyPath('foo.bar.anInt')).toEqual
        type: 'integer'
        default: 12

    describe 'when the value has an "integer" type', ->
      beforeEach ->
        schema =
          type: 'integer'
          default: 12
        atom.config.setSchema('foo.bar.anInt', schema)

      it 'coerces a string to an int', ->
        atom.config.set('foo.bar.anInt', '123')
        expect(atom.config.get('foo.bar.anInt')).toBe 123

      it 'coerces a float to an int', ->
        atom.config.set('foo.bar.anInt', 12.3)
        expect(atom.config.get('foo.bar.anInt')).toBe 12

      it 'will not set non-integers', ->
        atom.config.set('foo.bar.anInt', null)
        expect(atom.config.get('foo.bar.anInt')).toBe 12

        atom.config.set('foo.bar.anInt', 'nope')
        expect(atom.config.get('foo.bar.anInt')).toBe 12

      describe 'when the minimum and maximum keys are used', ->
        beforeEach ->
          schema =
            type: 'integer'
            minimum: 10
            maximum: 20
            default: 12
          atom.config.setSchema('foo.bar.anInt', schema)

        it 'keeps the specified value within the specified range', ->
          atom.config.set('foo.bar.anInt', '123')
          expect(atom.config.get('foo.bar.anInt')).toBe 20

          atom.config.set('foo.bar.anInt', '1')
          expect(atom.config.get('foo.bar.anInt')).toBe 10

    describe 'when the value has an "integer" and "string" type', ->
      beforeEach ->
        schema =
          type: ['integer', 'string']
          default: 12
        atom.config.setSchema('foo.bar.anInt', schema)

      it 'can coerce an int, and fallback to a string', ->
        atom.config.set('foo.bar.anInt', '123')
        expect(atom.config.get('foo.bar.anInt')).toBe 123

        atom.config.set('foo.bar.anInt', 'cats')
        expect(atom.config.get('foo.bar.anInt')).toBe 'cats'

    describe 'when the value has a "number" type', ->
      beforeEach ->
        schema =
          type: 'number'
          default: 12.1
        atom.config.setSchema('foo.bar.aFloat', schema)

      it 'coerces a string to a float', ->
        atom.config.set('foo.bar.aFloat', '12.23')
        expect(atom.config.get('foo.bar.aFloat')).toBe 12.23

      it 'will not set non-numbers', ->
        atom.config.set('foo.bar.aFloat', null)
        expect(atom.config.get('foo.bar.aFloat')).toBe 12.1

        atom.config.set('foo.bar.aFloat', 'nope')
        expect(atom.config.get('foo.bar.aFloat')).toBe 12.1

      describe 'when the minimum and maximum keys are used', ->
        beforeEach ->
          schema =
            type: 'number'
            minimum: 11.2
            maximum: 25.4
            default: 12.1
          atom.config.setSchema('foo.bar.aFloat', schema)

        it 'keeps the specified value within the specified range', ->
          atom.config.set('foo.bar.aFloat', '123.2')
          expect(atom.config.get('foo.bar.aFloat')).toBe 25.4

          atom.config.set('foo.bar.aFloat', '1.0')
          expect(atom.config.get('foo.bar.aFloat')).toBe 11.2

    describe 'when the value has a "boolean" type', ->
      beforeEach ->
        schema =
          type: 'boolean'
          default: true
        atom.config.setSchema('foo.bar.aBool', schema)

      it 'coerces various types to a boolean', ->
        atom.config.set('foo.bar.aBool', 'true')
        expect(atom.config.get('foo.bar.aBool')).toBe true
        atom.config.set('foo.bar.aBool', 'false')
        expect(atom.config.get('foo.bar.aBool')).toBe false
        atom.config.set('foo.bar.aBool', 'TRUE')
        expect(atom.config.get('foo.bar.aBool')).toBe true
        atom.config.set('foo.bar.aBool', 'FALSE')
        expect(atom.config.get('foo.bar.aBool')).toBe false
        atom.config.set('foo.bar.aBool', 1)
        expect(atom.config.get('foo.bar.aBool')).toBe true
        atom.config.set('foo.bar.aBool', 0)
        expect(atom.config.get('foo.bar.aBool')).toBe false
        atom.config.set('foo.bar.aBool', {})
        expect(atom.config.get('foo.bar.aBool')).toBe true
        atom.config.set('foo.bar.aBool', null)
        expect(atom.config.get('foo.bar.aBool')).toBe false

    describe 'when the value has an "string" type', ->
      beforeEach ->
        schema =
          type: 'string'
          default: 'ok'
        atom.config.setSchema('foo.bar.aString', schema)

      it 'allows strings', ->
        atom.config.set('foo.bar.aString', 'yep')
        expect(atom.config.get('foo.bar.aString')).toBe 'yep'

      it 'will not set non-strings', ->
        expect(atom.config.set('foo.bar.aString', null)).toBe false
        expect(atom.config.get('foo.bar.aString')).toBe 'ok'

        expect(atom.config.set('foo.bar.aString', 123)).toBe false
        expect(atom.config.get('foo.bar.aString')).toBe 'ok'

    describe 'when the value has an "object" type', ->
      beforeEach ->
        schema =
          type: 'object'
          properties:
            anInt:
              type: 'integer'
              default: 12
            nestedObject:
              type: 'object'
              properties:
                nestedBool:
                  type: 'boolean'
                  default: false
        atom.config.setSchema('foo.bar', schema)

      it 'converts and validates all the children', ->
        atom.config.set 'foo.bar',
          anInt: '23'
          nestedObject:
            nestedBool: 't'
        expect(atom.config.get('foo.bar')).toEqual
          anInt: 23
          nestedObject:
            nestedBool: true

    describe 'when the value has an "array" type', ->
      beforeEach ->
        schema =
          type: 'array'
          default: [1, 2, 3]
          items:
            type: 'integer'
        atom.config.setSchema('foo.bar', schema)

      it 'converts an array of strings to an array of ints', ->
        atom.config.set 'foo.bar', ['2', '3', '4']
        expect(atom.config.get('foo.bar')).toEqual  [2, 3, 4]

    describe 'when the `enum` key is used', ->
      beforeEach ->
        schema =
          type: 'object'
          properties:
            str:
              type: 'string'
              default: 'ok'
              enum: ['ok', 'one', 'two']
            int:
              type: 'integer'
              default: 2
              enum: [2, 3, 5]
            arr:
              type: 'array'
              default: ['one', 'two']
              items:
                type: 'string'
                enum: ['one', 'two', 'three']

        atom.config.setSchema('foo.bar', schema)

      it 'will only set a string when the string is in the enum values', ->
        expect(atom.config.set('foo.bar.str', 'nope')).toBe false
        expect(atom.config.get('foo.bar.str')).toBe 'ok'

        expect(atom.config.set('foo.bar.str', 'one')).toBe true
        expect(atom.config.get('foo.bar.str')).toBe 'one'

      it 'will only set an integer when the integer is in the enum values', ->
        expect(atom.config.set('foo.bar.int', '400')).toBe false
        expect(atom.config.get('foo.bar.int')).toBe 2

        expect(atom.config.set('foo.bar.int', '3')).toBe true
        expect(atom.config.get('foo.bar.int')).toBe 3

      it 'will only set an array when the array values are in the enum values', ->
        expect(atom.config.set('foo.bar.arr', ['one', 'two', 'five'])).toBe false
        expect(atom.config.get('foo.bar.arr')).toEqual ['one', 'two']

        expect(atom.config.set('foo.bar.arr', ['two', 'three'])).toBe true
        expect(atom.config.get('foo.bar.arr')).toEqual ['two', 'three']
