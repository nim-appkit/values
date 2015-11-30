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

    Describe "toValue(Ref)(), type checkers and accessors":
      It "Should work for bool":
        toValue(true).isBool().should beTrue()
        toValue(true).getBool().should beTrue()
        toValue(true).asBool().should beTrue()
        toValue(true)[bool].should beTrue()

        toValueRef(true).isBool().should beTrue()
        toValueRef(true).getBool().should beTrue()
        toValueRef(true).asBool().should beTrue()
        toValueRef(true)[bool].should beTrue()

      It "Should work for char":
        toValue('c').isChar().should beTrue()
        toValue('c').getChar().should equal 'c'
        toValue('c').asChar().should equal 'c'
        toValue('c')[char].should equal 'c'

        toValueRef('c').isChar().should beTrue()
        toValueRef('c').getChar().should equal 'c'
        toValueRef('c').asChar().should equal 'c'
        toValueRef('c')[char].should equal 'c'

      It "Should work for int":
        toValue(33'i8).isInt().should beTrue()
        toValue(33'i16).isInt().should beTrue()
        toValue(33'i32).isInt().should beTrue()
        toValue(33'i64).isInt().should beTrue()
        toValue(33).isInt().should beTrue()

        toValue(33).getInt().should equal 33
        toValue(33).asInt().should equal 33
        toValue(33)[int8].should equal 33'i8
        toValue(33)[int16].should equal 33'i16
        toValue(33)[int32].should equal 33'i32
        toValue(33)[int64].should equal 33'i64
        toValue(33)[int].should equal 33

        toValueRef(33).isInt().should beTrue()
        toValueRef(33).getInt().should equal 33
        toValueRef(33).asInt().should equal 33
        toValueRef(33)[int].should equal 33

      It "Should work for uint":
        toValue(33'u8).isUInt().should beTrue()
        toValue(33'u16).isUInt().should beTrue()
        toValue(33'u32).isUInt().should beTrue()
        toValue(33'u64).isUInt().should beTrue()
        toValue(33'u).isUInt().should beTrue()

        toValue(33'u).getUInt().should equal 33'u
        toValue(33'u).asUInt().should equal 33'u
        toValue(33'u)[uint8].should equal 33'u8
        toValue(33'u)[uint16].should equal 33'u16
        toValue(33'u)[uint32].should equal 33'u32
        toValue(33'u)[uint64].should equal 33'u64
        toValue(33'u)[uint].should equal 33'u

        toValueRef(33'u).isUInt().should beTrue()
        toValueRef(33'u).getUInt().should equal 33'u
        toValueRef(33'u).asUInt().should equal 33'u
        toValueRef(33'u)[uint].should equal 33'u

      It "Should work for float":
        toValue(33.33).isFloat().should beTrue()
        toValue(33'f32).isFloat().should beTrue()
        toValue(33'f64).isFloat().should beTrue()

        toValue(33.33).getFloat().should equal 33.33
        toValue(33.33).asFloat().should equal 33.33
        toValue(33.33)[float32].should equal 33.33'f32
        toValue(33.33)[float64].should equal 33.33'f64
        toValue(33.33)[float].should equal 33.33

        toValueRef(33.33).isFloat().should beTrue()
        toValueRef(33.33).getFloat().should equal 33.33
        toValueRef(33.33).asFloat().should equal 33.33
        toValueRef(33.33)[float].should equal 33.33

      It "Should work for string":
        toValue("string").isString().should beTrue()
        toValue("string").getString().should equal "string"
        toValue("string").asString().should equal "string"
        toValue("string")[string].should equal "string"

        toValueRef("string").isString().should beTrue()
        toValueRef("string").getString().should equal "string"
        toValueRef("string").asString().should equal "string"
        toValueRef("string")[string].should equal "string"

      It "Should work for time":
        var t = times.getTime()
        var ti = times.getLocalTime(t)
        toValue(t).isTime().should beTrue()
        toValue(t).getTime().should equal ti
        toValue(t)[times.TimeInfo].should equal ti
        toValue(t)[times.Time].should equal t

        toValueRef(t).isTime().should beTrue()
        toValueRef(t).getTime().should equal ti
        toValueRef(t)[Time].should equal t

      It "Should work for sequence":
        var s = @[1, 2, 3]
        var vs = @[toValueRef(1), toValueRef(2), toValueRef(3)]
        toValue(s).isSeq().should beTrue()
        toValue(s).getSeq().should equal vs
        toValue(s).asSeq(int).should equal s

        toValueRef(s).isSeq().should beTrue()
        toValueRef(s).getSeq().should equal vs
        toValueRef(s).asSeq(int).should equal s

      It "Should work for array":
        var a = [1, 2, 3]
        var vs = @[toValueRef(1), toValueRef(2), toValueRef(3)]
        toValue(a).isSeq().should beTrue()
        toValue(a).getSeq().should equal vs

        toValueRef(a).isSeq().should beTrue()
        toValueRef(a).getSeq().should equal vs

      It "Should work for set":
        var a = {1, 2, 3}
        var vs = @[toValueRef(1), toValueRef(2), toValueRef(3)]
        toValue(a).isSet().should beTrue()
        toValue(a).getSeq().should equal vs

        toValueRef(a).isSet().should beTrue()
        toValueRef(a).getSeq().should equal vs

      It "Should work for map":
        var t = (s: "s", i: 1, f: 1.1)
        var m = toValueRef(t)
        m.isMap().should beTrue()
        m.s.should equal "s"
        m.i.should equal 1
        m.f.should equal 1.1

    Describe "isZero()":
      It "Should work for int":
        toValue(0).isZero().should beTrue()
        toValue(1).isZero().should beFalse()

        toValueRef(0).isZero().should beTrue()
        toValueRef(1).isZero().should beFalse()

      It "Should work for uint":
        toValue(0'u).isZero().should beTrue()
        toValue(1'u).isZero().should beFalse()

        toValueRef(0'u).isZero().should beTrue()
        toValueRef(1'u).isZero().should beFalse()

      It "Should work for float":
        toValue(0.0).isZero().should beTrue()
        toValue(1.1).isZero().should beFalse()

        toValueRef(0.0).isZero().should beTrue()
        toValueRef(1.1).isZero().should beFalse()

      It "Should work for string":
        var s: string
        toValue(s).isZero().should beTrue()
        toValue("").isZero().should beTrue()
        toValue("a").isZero().should beFalse()

        toValueRef(s).isZero().should beTrue()
        toValueRef("").isZero().should beTrue()
        toValueRef("a").isZero().should beFalse()

    Describe ".len()":
      It "Should work for char":
        toValue(' ').len().should equal 1
        toValueRef(' ').len().should equal 1

      It "Should work for string":
        toValue("abc").len().should equal 3
        toValueRef("abc").len().should equal 3

      It "Should work for seq":
        toValue(@[1, 2, 3]).len().should equal 3
        toValueRef(@[1, 2, 3]).len().should equal 3

      It "Should work for set":
        toValue({1, 2, 3}).len().should equal 3
        toValueRef({1, 2, 3}).len().should equal 3

      It "Should work for map":
        toValueRef((a: 1)).len().should equal 1

    Describe "`==`":
      It "Should work for bool":
        (toValue(true) == toValue(true)).should beTrue()
        (toValue(true) == true).should beTrue()

        (toValueRef(false) == toValueRef(false)).should beTrue()
        (toValueRef(true) == toValue(true)).should beTrue()
        (toValue(true) == toValueRef(true)).should beTrue()
        (toValueRef(false) == false).should beTrue()

      It "Should work for char":
        (toValue(' ') == toValue(' ')).should beTrue()
        (toValue(' ') == ' ').should beTrue()

        (toValueRef(' ') == toValueRef(' ')).should beTrue()
        (toValueRef(' ') == toValue(' ')).should beTrue()
        (toValue(' ') == toValueRef(' ')).should beTrue()
        (toValueRef(' ') == ' ').should beTrue()

      It "Should work for string":
        (toValue("a b c") == toValue("a b c")).should beTrue()
        (toValue("a b c") == "a b c").should beTrue()

        (toValueRef("a b c") == toValueRef("a b c")).should beTrue()
        (toValueRef("a b c") == toValue("a b c")).should beTrue()
        (toValue("a b c") == toValueRef("a b c")).should beTrue()
        (toValueRef("a b c") == "a b c").should beTrue()

      It "Should work for int":
        (toValue(5) == toValue(5)).should beTrue()
        (toValue(5) == 5).should beTrue()

        (toValueRef(5) == toValueRef(5)).should beTrue()
        (toValueRef(5) == toValue(5)).should beTrue()
        (toValue(5) == toValueRef(5)).should beTrue()
        (toValueRef(5) == 5).should beTrue()


      It "Should work for uint":
        (toValue(5'u) == toValue(5'u)).should beTrue()
        (toValue(5'u) == 5'u).should beTrue()

        (toValueRef(5'u) == toValueRef(5'u)).should beTrue()
        (toValueRef(5'u) == toValue(5'u)).should beTrue()
        (toValue(5'u) == toValueRef(5'u)).should beTrue()
        (toValueRef(5'u) == 5'u).should beTrue()

      It "Should work for float":
        (toValue(5.5) == toValue(5.5)).should beTrue()
        (toValue(5.5) == 5.5).should beTrue()

        (toValueRef(5.5) == toValueRef(5.5)).should beTrue()
        (toValueRef(5.5) == toValue(5.5)).should beTrue()
        (toValue(5.5) == toValueRef(5.5)).should beTrue()
        (toValueRef(5.5) == 5.5).should beTrue()

      It "Should work for sequence":
        var s = ValueSeq(1, 2, 3)
        (s == ValueSeq(1, 2, 3)).should beTrue()
        (s == @[1, 2, 3]).should beTrue()
        (s == [1, 2, 3]).should beTrue()

        (toValueRef(5.5) == toValueRef(5.5)).should beTrue()
        (toValueRef(5.5) == toValue(5.5)).should beTrue()
        (toValue(5.5) == toValueRef(5.5)).should beTrue()
        (toValueRef(5.5) == 5.5).should beTrue()

      It "Should work for map":
        var s = @%(s: "s", i: 1, f: 1.1, b: true)
        (s == @%(s: "s", i: 1, f: 1.1, b: true)).should beTrue()
        (s == @%(s: "lala")).should beFalse()

  Describe "Sequence Value":

    It "Should iterate in pairs":
      var s = @[1, 2, 3]
      for i, x in toValue(s):
        x.should equal toValue(s[i])
      for i, x in toValueRef(s):
        x.should equal toValue(s[i])


    It "Should iterate items":
      var s = @[1, 2, 3]
      var i = 0
      for x in toValue(s):
        x.should equal toValue(s[i])
        i.inc()
      i = 0
      for x in toValueRef(s):
        x.should equal toValue(s[i])
        i.inc()

    It "Should get/set with [], []=":
      var s = toValue([1, 2, 3])
      s[0][int].should equal 1
      s[0] = toValue(10)
      s[0][int].should equal 10
      s[0] = 15
      s[0][int].should equal 15

      var r = toValueRef([1, 2, 3])
      r[0][int].should equal 1
      r[0] = toValue(10)
      r[0][int].should equal 10
      r[0] = 15
      r[0][int].should equal 15

    It "Should .add()":
      var s = toValue([0, 1, 2])
      s.add(toValue(3))
      s[3][int].should equal 3
      s.add(4)
      s[4][int].should equal 4

      var r = toValueRef([0, 1, 2])
      r.add(toValue(3))
      r[3][int].should equal 3
      r.add(4)
      r[4][int].should equal 4

    It "Should build with newValueSeq()":
      var s = newValueSeq(1, "a", false)
      s[0][int].should equal 1
      s[1][string].should equal "a"
      s[2][bool].should equal false

    It "Should build with ValueSeq()":
      var s = ValueSeq(1, "a", false)
      s.isSeq().should beTrue()
      echo(repr(s))
      s[0][int].should equal 1
      s[1][string].should equal "a"
      s[2][bool].should equal false


  Describe("ValueMap"):

    It("Should set / get with `[]`"):
      var m = newValueMap()
      m["x"] = toValue(22)
      m["y"] = 33
      m["x"][int].should equal 22
      m["y"][int].should equal 33

    It("Should set / get Value with `.`"):
      var m = newValueMap()
      m.x = toValue(22)
      m.y = 33
      m.x[int].should equal 22
      m.y[int].should equal 33

    It("Should set / get with nested `.`"):
      var m = newValueMap()
      m.nested = newValueMap()

      m.nested.val = toValue(1)
      m.nested.val[int].should equal 1

      m.nested.key = "lala"
      m.nested.key[string].should equal "lala"

    It("Should set/get with nested `[]`"):
      var m = newValueMap()
      m["nested"] = newValueMap()

      m["nested"]["key"] = toValue(1)
      m["nested"]["key"][int].should equal 1

      m["nested"]["key"] = "lala"
      m["nested"]["key"][string].should equal "lala"

    It "Should auto-create nested maps":
      var m = newValueMap(autoNesting = true)
      m.nested.x.x = 1
      m.nested.x.x[int].should equal 1

      m.nested.x.y = "lala"
      m.nested.x.y[string].should equal "lala"

    It "Should create ValueMap from tuple with @%()":
      var m = @%(x: "str", i: 55)
      m.x.should equal "str"
      m.i.should equal 55

    It "Should .hasKey()":
      var m = @%(x: "str")
      m.hasKey("x").should beTrue()
      m.hasKey("y").should beFalse()

    It "Should .keys()":
      var m = @%(x: "str", y: 1)
      var actualKeys = @["x", "y"]
      var keys: seq[string] = @[]
      for key in m.keys:
        keys.add(key)
      keys.should equal actualKeys

    It "Should .getKeys()":
      var m = @%(x: "str", y: 1)
      var actualKeys = @["x", "y"]
      m.getKeys().should equal actualKeys
    
    It "Should iterate over fieldpairs":
      var m = @%(x: "str", y: 1)
      for key, val in m.fieldPairs:
        val.should equal m[key]

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

when isMainModule:
  omega.run()