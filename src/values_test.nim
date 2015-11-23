import macros
import omega, alpha

include values


macro testType(): stmt =
  result = quote do:
    type Test = ref object of RootObj
      strField: string
      intField: int
      floatField: float
      boolField: bool

  var acs = buildAccessors(result[0][0])
  acs.copyChildrenTo(result)
  echo(repr(result))

#testType()

type
  Test = ref object of RootObj
    strField: string
    intField: int
    floatField: float
    boolField: bool

method setProp*[T](o: Test; name: string; val: T) =
  case name
  of "strField":
    when T is type(o.strField):
      o.strField = val
    else:
      raise newException(Exception,
                        "Field strField is string, not " & name(type(T)))
  of "intField":
    when T is type(o.intField):
      o.intField = val
    else:
      raise newException(Exception,
                        "Field intField is int, not " & name(type(T)))
  of "floatField":
    when T is type(o.floatField):
      o.floatField = val
    else:
      raise newException(Exception,
                        "Field floatField is float, not " & name(type(T)))
  of "boolField":
    when T is type(o.boolField):
      o.boolField = val
    else:
      raise newException(Exception,
                        "Field boolField is bool, not " & name(type(T)))
  else:
    raise newException(Exception, "Unknown field: " & name)

method setProp*(o: Test; name: string; val: string) =
  case name
  of "strField":
    o.strField = convertString[string](val)
  of "intField":
    o.intField = convertString[int](val)
  of "floatField":
    o.floatField = convertString[float](val)
  of "boolField":
    o.boolField = convertString[bool](val)
  else:
    raise newException(Exception, "Unknown field: " & name)

method setValue*(o: Test; name: string; val: Value) =
  var typ = ""
  case name
  of "strField":
    o.strField = val.asString()
  of "intField":
    o.intField = int(val.asBiggestInt())
  of "floatField":
    o.floatField = float(val.asBiggestFloat())
  of "boolField":
    o.boolField = val.asBool()
  else:
    raise newException(Exception, "Unknown field: " & name)

method getValue*(o: Test; name: string): Value =
  case name
  of "strField":
    result = toValue(o.strField)
  of "intField":
    result = toValue(o.intField)
  of "floatField":
    result = toValue(o.floatField)
  of "boolField":
    result = toValue(o.boolField)
  else:
    raise newException(Exception, "Unknown field: " & name)

Suite("Values"):

  Describe "Value":

    It "Should get with typed accessor `[]`":
      var v = toValue(22)
      v[int].should(equal(22))

    Describe "isZero()":

      It "Should determine numeric zero":
        toValue(0).isZero().should(beTrue())

  Describe("ValueMap"):

    It("Should set / get Value with `[]`"):
      var m = newValueMap()
      m["x"] = toValue(22)
      m["x"].getInt().should(equal(22))

    It("Should set / get Value with `.`"):
      var m = newValueMap()
      m.x = toValue(22)
      m.x.getInt().should(equal(22))

    It("Should set / get T with `[]`"):
      var m = newValueMap()
      m["x"] = 22
      m["x"].getInt().should(equal(22))

    It("Should set / get T with `.`"):
      var m = newValueMap()
      m.x = 22
      m.x.getInt().should(equal(22))

    It("Should get T with nested `.`"):
      var m = newValueMap()
      m.nested = newValueMap()

      m.nested.key = "lala"
      m.nested.key.getString().should(equal("lala"))

    It("Should get T with nested `[]`"):
      var m = newValueMap()
      m["nested"] = newValueMap()

      m["nested"]["key"] = "lala"
      m["nested"]["key"].getString().should(equal("lala"))

    It "Should auto-create nested maps":
      var m = newValueMap(autoNesting = true)
      m.nested.x.y = "lala"
      m.nested.x.y[string].should(equal("lala"))

  Describe "Type Accessors":
    var item: Test

    beforeEach:
      item = Test()

    It "Should setProp()":
      item.setProp("strField", "strVal")
      item.strField.should(equal("strVal"))

      item.setProp("intField", 23)
      item.intField.should(equal(23))

      item.setProp("floatField", 33.33)
      item.floatField.should(equal(33.33))

      item.setProp("boolField", true)
      item.boolField.should(equal(true))

    It "Should setProp with string values":
      item.setProp("strField", "22")
      item.strField.should(equal("22"))

      item.setProp("intField", "55")
      item.intField.should(equal(55))

      item.setProp("floatField", "123.321")
      item.floatField.should(equal(123.321))

      item.setProp("boolField", "y")
      item.boolField.should(beTrue())

    It "Should getValue()":
      item.strField = "str"
      item.getValue("strField").strVal.should(equal("str"))

    It "Should setValue()":
      item.setValue("strField", toValue("xxx"))
      item.strField.should(equal("xxx"))

      item.setValue("intField", toValue(22))
      item.intField.should(equal(22))
      item.setValue("intField", toValue("22")) 
      item.intField.should(equal(22))


when isMainModule:
  omega.run()
