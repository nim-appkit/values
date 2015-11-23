import macros
import omega, alpha

include values

type TestTyp = ref object of RootObj
  strField: string
  intField: int
  floatField: float
  boolField: bool

macro testType(): stmt =
  result = quote do:
    type TestTyp = ref object of RootObj
      strField: string
      intField: int
      floatField: float
      boolField: bool

  var acs = buildAccessors(result[0][0])
  acs.copyChildrenTo(result)
  echo(repr(result))

testType()

Suite("Values"):

  Describe "Value":

    It "Should get with typed accessor `[]`":
      var v = toValue(22)
      v[int].should(equal(22))

    Describe "isZero()":

      It "Should determine numeric zero":
        toValue(0).isZero().should(beTrue())


  Describe "Sequence value":

    It "Should construct from arbitrary seq":
      var s = toValue(@["a", "b", "c"])
      s.seqVal.shouldNot(beNil())
      s.seqVal.len().should(equal(3))
      s.seqVal[0].should(equal(toValue("a")))

    It "Should determine length":
      var s = toValue(@["a", "b", "c"])
      s.len().should(equal(3))

    It "Should allow access with []":
      var s = toValue(@["a", "b", "c"])
      s[1].should(equal(toValue("b")))

    It "Should set with []= and value":
      var s = toValue(@["a", "b", "c"])
      s[0] = toValue(22)
      s[0].should(equal(toValue(22)))

    It "Should .add()":
      var s = toValue(@["a", "b", "c"])
      s.add("d")
      s.len().should(equal(4))
      s[3].getString().should(equal("d"))


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

    It "Should create value from tuple":
      var v = toValue((a: 22, b: "str"))
      v.should(equal((a: 22, b: "str")))

  Describe "Type Accessors":
    var item: TestTyp

    beforeEach:
      item = TestTyp()

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
