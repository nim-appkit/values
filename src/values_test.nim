###############################################################################
##                                                                           ##
##                     nim-values library                                    ##
##                                                                           ##
##   (c) Christoph Herzog <chris@theduke.at> 2015                            ##
##                                                                           ##
##   This project is under the LGPL license.                                 ##
##   Check LICENSE.txt for details.                                          ##
##                                                                           ##
###############################################################################

import macros, typetraits

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
      echo("should get typed")
      var v = toValue(22)
      v[int].should(equal(22))

    Describe "isZero()":

      It "Should determine numeric zero":
        toValue(0).isZero().should(beTrue())

  Describe "toValue":

    It "Should create value from sequence":
      var a = @[1, 2, 3]
      var v = toValue(a)

      v.kind.should equal valSeq
      v.seqVal.len().should equal 3
      v.seqVal[0].getInt().should equal 1



  Describe "ValueSequence":

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

    It "Should construct with @& macro":
      #var s = @&["a", 1, 1.1, false]
      #s.should haveLen 4
      discard

  Describe("ValueMap"):

    It "Should create map with @@":
      var map = @%(a: 22, b: "str", c: @%(x: false))
      map.kind.should equal valMap
      map.hasKey("a").should beTrue()
      map.a.should equal 22
      map.hasKey("b").should beTrue()
      map.b.should equal "str"
      map.hasKey("c").should beTrue()

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

    It "Should create ValueMap from tuple with @%()":
      var m = @%(x: "str", i: 55)
      m.x.should equal "str"
      m.i.should equal 55

    It "Should create value from tuple":
      var tpl = (a: 22, b: "str")
      var v = toValueRef(tpl)
      v.a.should be 22
      v.b.should be "str"

  Describe "JSON handling":

    It "Should parse json from string":
      var js = """{"str": "string", "intVal": 55, "floatVal": 1.115, "boolVal": true, "nested": {"nestedStr": "str", "arr": [1, 3, "str"]}}"""
      var map = fromJson(js)
      map.kind.should be valMap

      map.str.should be "string"

      map["intVal"].should be 55

      map["floatVal"].should be 1.115

      map["boolVal"].should beTrue()

      var nestedMap = map.nested
      nestedMap.kind.should be valMap

      nestedMap.nestedStr.should be "str"

      nestedMap.arr.isSeq.should beTrue()

      var arr = nestedMap.arr
      arr.isSeq().should beTrue()
      arr.len().should be 3
      arr[0].should be 1
      arr[1].should be 3
      arr[2].should be "str"

    Describe "toJson":

      It "Should convert bool":
        toValue(true).toJson().should equal "true"
        toValue(false).toJson().should equal "false"

      It "Should convert char":
        toValue('x').toJson().should equal "\"x\""

      It "Should convert int":
        toValue(22).toJson().should equal "22"

      It "Should convert uint":
        toValue(22).toJson().should equal "22"

      It "Should convert float":
        toValue(22.22).toJson().should equal "22.22"

      It "Should convert string":
        toValue("test").toJson().should equal "\"test\""

      It "Should convert sequence":
        var s = toValue(@[1, 2])
        s.add("22")
        s.toJson().should equal "[1, 2, \"22\"]"

      It "Should convert map":
        var json = toMap((s: "str", i: 1, f: 10.11, b: true, nested: (ns: "str", ni: 5, na: @[1, 2, 3]))).toJson()
        json.should equal """{"nested": {"ni": 5, "ns": "str", "na": [1, 2, 3]}, "f": 10.11, "i": 1, "s": "str", "b": true}""" 


  Describe "Accessors":

    Describe "Sequence accessors":

      It "Should access with []":
        var v = toValue(@[1, 2, 3])
        v[0].should equal 1
        v[1].should equal 2
        v[2].should equal 3

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