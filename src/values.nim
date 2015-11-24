import typeinfo, typetraits
import macros
import tables
from json import escapeJson
from strutils import `%`, parseBiggestInt, parseFloat, parseBool, parseInt, splitLines
from times import parse, format, Time
import hashes

{.experimental.}

##########
# Values #
##########

type
  ValKind* = enum
    valUnknown
    valNone
    valBool
    valChar
    valInt
    valUInt
    valFloat
    valString
    valTime
    valSeq
    valObj
    
    valValue
    valValueMap

type
  Value* = ref object of RootObj
    case kind*: ValKind
    of valUnknown, valNone:
      discard

    of valBool:
      boolVal: bool

    of valChar:
      charVal: char

    of valInt:
      intVal*: BiggestInt

    of valUInt:
      uintVal*: uint64

    of valFloat:
      floatVal*: BiggestFloat

    of valString:
      strVal*: string

    of valTime:
      timeVal*: Time

    of valSeq:
      seqVal*: seq[Value]
      itemKind: ValKind

    of valObj:
      typeName: string
      size: int
      ptrVal: pointer

    of valValue:
      # Should never happen.
      discard

    of valValueMap:
      mapVal: ValueMap

  ValueMap* = ref object
    table: Table[string, Value]
    autoNesting: bool

# Value destructor.
#proc `=destroy`*(v: var Value) =
#  if v.kind == valObj:
#    if v.ptrVal != nil:
#      dealloc(v.ptrVal)

###########
# Errors. #
###########

type KeyErr* = object of Exception
  key: string

proc newKeyErr(key: string):  ref KeyErr =
  var e = newException(KeyErr, "ValueMap does not have key: '" & key & "'")
  e.key = key
  return e

type ValueErr* = object of Exception
  discard

proc newValueErr(msg: string): ref ValueErr =
  newException(ValueErr, msg)

type TypeErr* = object of Exception
  kindA: ValKind
  kindB: ValKind

proc newTypeErr(kindA, kindB: ValKind): ref TypeErr =
  var e = newException(TypeErr, "$1 can not be represented as $2." % [$kindA, $kindB])
  e.kindA = kindA
  e.kindB = kindB
  return e

type ConversionErr* = object of Exception
  discard

proc newConversionErr(msg: string): ref ConversionErr =
  newException(ConversionErr, msg)

#########################
# Forward declarations. #
#########################

proc toJson*(v: Value): string
proc toJson*(m: ValueMap): string

####################
# determineValKind #
####################

proc determineAnyKind*(x: typedesc): AnyKind =
  result = akNone

  when x is bool:
    result = akBool
  when x is char:
    result = akChar
  when x is enum:
    result = akEnum
  when x is array:
    result = akArray
  when x is object:
    result = akObject
  when x is tuple:
    result = akTuple
  when x is set:
    result = akSet
  when x is range:
    result = akRange
  when x is ptr:
    result = akPtr
  when x is ref:
    result = akRef
  when x is seq:
    result = akSequence
  when x is pointer:
    result = akPointer
  when x is string:
    result = akString
  when x is cstring:
    result = akCString

  when x is int:
    result = akInt
  when x is int8:
    result = akInt8
  when x is int16:
    result = akInt16
  when x is int32:
    result = akInt32
  when x is int64:
    result = akInt64

  when x is uint:
    result = akUInt
  when x is uint8:
    result = akUInt8
  when x is uint16:
    result = akUInt16
  when x is uint32:
    result = akUInt32
  when x is uint64:
    result = akUInt64

  when x is float:
    result = akFloat
  when x is float32:
    result = akFloat32
  when x is float64:
    result = akFloat64

proc determineValKind*(x: string): ValKind =
  result = valUnknown
  case x
  of "bool":
    result = valBool
  of "char":
    result = valChar
  of "int", "int8", "int16", "int32", "int64":
    result = valInt
  of "uint", "uint8", "uint16", "uint32", "uint64":
    result = valUInt
  of "float", "float32", "float64":
    result = valFloat
  of "string":
    result = valString
  of "Time":
    result = valTime
  else:
    discard

proc determineValKind*(x: typedesc): ValKind =
  var kind = valUnknown
  
  # Bool val. 
  when x is bool:
    kind = valBool

  # Char val.
  when x is char:
    kind = valChar

  # Int values.
  when x is int or x is int8 or x is int16 or x is int32 or x is int64:
    kind = valInt
  
  # UInt values.
  when x is uint or x is uint8 or x is uint16 or x is uint32 or x is uint64:
    kind = valUInt
    
  # Float values.
  when x is float or x is float32 or x is float64:
    kind = valFloat
  
  # String. 
  when x is string:
    kind = valString

  when x is Time:
    kind = valTime

  when x is seq:
    kind == valSeq

  # Values, valuemaps.
  when x is Value:
    kind = valValue

  when x is ValueMap:
    kind = valValueMap
    
  kind

####################
# toValue methods #
####################

proc toValue*(v: Value): Value =
  v

######################
# toValue for bool. #
######################

proc toValue*(x: bool): Value =
  Value(kind: valBool, boolVal: x)

######################
# toValue for char. #
######################

proc toValue*(x: char): Value =
  Value(kind: valChar, charVal: x)

######################
# toValue for ints. #
######################

proc toValue*(x: int): Value =
  Value(kind: valInt, intVal: BiggestInt(x))

proc toValue*(x: int8): Value =
  Value(kind: valInt, intVal: BiggestInt(x))

proc toValue*(x: int16): Value =
  Value(kind: valInt, intVal: BiggestInt(x))

proc toValue*(x: int32): Value =
  Value(kind: valInt, intVal: BiggestInt(x))

proc toValue*(x: int64): Value =
  Value(kind: valInt, intVal: BiggestInt(x))

#######################
# toValue for uints. #
#######################

proc toValue*(x: uint): Value =
  Value(kind: valUInt, uintVal: uint64(x))

proc toValue*(x: uint8): Value =
  Value(kind: valUInt, uintVal: uint64(x))

proc toValue*(x: uint16): Value =
  Value(kind: valUInt, uintVal: uint64(x))

proc toValue*(x: uint32): Value =
  Value(kind: valUInt, uintVal: uint64(x))

proc toValue*(x: uint64): Value =
  Value(kind: valUInt, uintVal: x)

########################
# toValue for floats. #
########################

proc toValue*(x: float32): Value =
  Value(kind: valFloat, floatVal: BiggestFloat(x))

proc toValue*(x: float64): Value =
  Value(kind: valFloat, floatVal: BiggestFloat(x))

########################
# toValue for string. #
########################

proc toValue*(x: string): Value =
  Value(kind: valString, strVal: x)

###########################
# toValue for times.Time. #
###########################

proc toValue*(x: times.Time): Value =
  Value(kind: valTime, timeVal: x)

#########################
# toValue for ValueMap. #
#########################

proc toValue*(m: ValueMap): Value =
  Value(kind: valValueMap, mapVal: m)

####################
# toValue for seq. #
####################

proc toValue*(s: seq[Value]): Value =
  Value(
    kind: valSeq,
    itemKind: valValue,
    seqVal: s
  )

proc toValue*[T](s: seq[T]): Value =
  var kind = determineValKind(T)
  if kind == valNone:
    raise newValueErr("Could not determine ValKind of sequece items for: seq[$1]" % [name(T)])
  var s = s
  if s == nil:
    s = @[]

  var newSeq: seq[Value] = @[]
  for item in s:
    newSeq.add(toValue(item))

  Value(
    kind: valSeq, 
    itemKind: kind,
    seqVal: newSeq
  )

###############################
# Generic determineValKind(). #
###############################

proc determineValKind*[T](x: T): ValKind =
  var v = toValue(x)
  return v.kind

################
# isNumeric(). #
################

proc isNumeric*(v: Value): bool =
  v.kind in {valInt, valUInt, valFloat}

proc isInt*(v: Value): bool =
  v.kind == valInt

proc isUint*(v: Value): bool =
  v.kind == valUInt

proc isFloat*(v: Value): bool =
  v.kind == valFloat

####################
# Value accessors. #
####################

proc asBiggestFloat*(v: Value): BiggestFloat
proc strToChar*(str: string): char

# Bool accessors. 

proc getBool*(v: Value): bool =
  v.boolVal

proc asBool*(v: Value): bool =
  if v.kind == valBool:
    return v.boolVal
  if v.isNumeric():
    return v.asBiggestFloat() == BiggestFloat(0)
  elif v.kind == valString:
    return parseBool(v.strVal)
  elif v.kind == valChar:
    return parseBool("" & v.charVal)
  else:
    raise newConversionErr("Can't convert $1 to bool." % [$v.kind])

# Char accessors. 

proc getChar*(v: Value): char =
  v.charVal

proc asChar*(v: Value): char =
  if v.kind == valChar:
    return v.charVal
  elif v.kind == valString:
    return strToChar(v.strVal)
  else:
    raise newConversionErr("Can't convert $1 to char." % [$v.kind])

# Int accessors.
proc getInt*(v: Value): BiggestInt =
  v.intVal

proc getBiggestInt*(v: Value): BiggestInt =
  v.intVal

proc asBiggestInt*(v: Value): BiggestInt =
  if v.isInt():
    result = v.intVal
  elif v.isUint():
    result = BiggestInt(v.uintVal)
  elif v.isFloat():
    result = BiggestInt(v.floatVal)
  elif v.kind == valChar:
    return parseBiggestInt("" & v.charVal)
  elif v.kind == valString:
    return parseBiggestInt(v.strVal)
  else:
    raise newConversionErr("Can't convert $1 to int." % [$v.kind])

proc asInt*(v: Value): int =
  int(v.asBiggestInt())

proc asInt8*(v: Value): int8 =
  int8(v.asBiggestInt())

proc asInt16*(v: Value): int16 =
  int16(v.asBiggestInt())

proc asInt32*(v: Value): int32 =
  int32(v.asBiggestInt())

proc asInt64*(v: Value): int64 =
  v.asBiggestInt()


# Uint accessors.

proc getUInt*(v: Value): uint64 =
  v.uintVal

proc getBiggestUInt*(v: Value): uint64 =
  v.uintVal

proc asBiggestUInt*(v: Value): uint64 =
  if v.isUint():
    result = v.uintVal
  elif v.isInt():
    result = uint64(v.uintVal)
  elif v.isFloat():
    result = uint64(v.floatVal)
  else:
    result = uint64(v.asBiggestInt())

proc getUInt64*(v: Value): uint64 =
  v.uintVal

proc asUInt64*(v: Value): uint64 =
  v.asBiggestUInt()

proc asUInt*(v: Value): uint =
  uint(v.asBiggestUInt())

proc asUInt8*(v: Value): uint8 =
  uint8(v.asBiggestUInt())

proc asUInt16*(v: Value): uint16 =
  uint16(v.asBiggestUInt())

proc asUInt32*(v: Value): uint32 =
  uint32(v.asBiggestUInt())


# Float accessors.

proc getBiggestFloat*(v: Value): BiggestFloat =
  v.floatVal

proc asBiggestFloat*(v: Value): BiggestFloat =
  if v.isFloat():
    result = v.floatVal
  elif v.isInt():
    result = BiggestFloat(v.intVal)
  elif v.isUint():
    result = BiggestFloat(v.uintVal)
  elif v.kind == valChar:
    return parseFloat("" & v.charVal)
  elif v.kind == valString:
    return parseFloat(v.strVal)
  else:
    raise newConversionErr("Can't convert $1 to float." % [$v.kind])

proc getFloat*(v: Value): float =
  v.floatVal

proc asFloat*(v: Value): float =
  float(v.asBiggestFloat())

proc asFloat32*(v: Value): float32 =
  float32(v.asBiggestFloat())

proc asFloat64*(v: Value): float64 =
  v.asBiggestFloat()

# String accessor.

proc getString*(v: Value): string = 
  v.strVal

# Value $.
proc `$`*(v: Value): string =
  case v.kind
  of valNone:
    result = "nil"
  of valBool:
    result = $(v.boolVal)
  of valChar:
    result = $(v.charVal)
  of valInt:
    result = $(v.intVal)
  of valUInt:
    result = $(v.uintVal)
  of valFloat:
    result = $(v.floatVal)
  of valString:
    result = v.strVal
  else:
    assert false, "$ not implemented for Value: " & v.kind.`$`

proc asString*(v: Value): string =
  return v.`$`

proc repr*(v: Value): string =
  "Value[$1]($2)" % [v.kind.`$`, $v]

#############
# toJson(). #
#############

proc toJson*(v: Value): string =
  case v.kind
  of valUnknown, valNone:
    result = ""

  of valBool:
    result = v.boolVal.`$`

  of valChar:
    result = "\"" & escapeJson(v.charVal.`$`) & "\""

  of valInt:
    result = v.intVal.`$`

  of valUInt:
    result = v.uintVal.`$`

  of valFloat:
    result = v.floatVal.`$`

  of valString:
    result = escapeJson(v.strVal)

  of valTime:
    result = escapeJson(times.getLocalTime(v.timeVal).format("yyyy-dd-MM'T'HH:mmzzz"))

  of valSeq:
    result = "["
    for i, val in v.seqVal:
      result &= val.toJson
      if i < high(v.seqVal):
        result &= ", "
    result &= "]"

  of valValueMap:
    result = v.mapVal.toJson()

  of valObj, valValue:
    raise newValueErr("toJson() not yet implemented for valObj")


#############
# isZero(). #
#############

proc isZero*(v: Value): bool =
  if v.isNumeric():
    return v.asBiggestFloat() == 0

  case v.kind
  of valNone:
    result = true
  of valBool:
    result = false
  of valChar:
    result = v.charVal == '\0'
  of valString:
    result = v.strVal == nil or v.strVal == ""
  of valObj:
    result = v.ptrVal == nil
  of valValueMap:
    result = false
  else:
    raise newException(Exception, "isZero() not implemented for kind " & $(v.kind))

###########
# hash(). #
###########

proc hash*(v: Value): hashes.Hash =
  case v.kind
  of valChar:
    result = hash(v.charVal)
  of valInt:
    result = hash(v.intVal)
  of valUInt:
    result = hash(v.asBiggestInt)
  of valFloat:
    result = hash(v.floatVal)
  of valString:
    result = hash(v.strVal)
  of valSeq:
    result = hash(v.seqVal)
  else:
    raise newValueErr("Can't hash " & v.kind.`$`)


#############
# ValueMap. #
#############

include ./maps.nim

######################
# generic toValue.  #
######################

proc toValue*[T](x: T): Value =
  if T is tuple:
    var m = newValueMap()
    for key, val in x.fieldPairs:
      m[key] = val
    return toValue(m)

  var val = x
  var anyVal = toAny(val)

  if anyVal.kind == akRef:
    anyVal = anyVal[]

  if anyVal.kind == akObject:
    var p = alloc(anyVal.size())
    copyMem(p, anyVal.getPointer(), anyVal.size())
    return Value(kind: valObj, size: anyVal.size(), ptrVal: p) 

  raise newException(Exception, "Unhandled kind: " & anyVal.kind.`$`)

# Map accessor.

proc getMap*(v: Value): ValueMap =
  v.mapVal

# Typed accessor.

proc `[]`(v: Value, typ: typedesc): any =
  when typ is bool:
    result = v.asBool()

  when typ is char:
    result = v.asChar()

  when typ is int:
    result = v.asInt()
  when typ is int8:
    result = v.asInt8()
  when typ is int16:
    result = v.asInt16()
  when typ is int32:
    result = v.asInt32()
  when typ is int64:
    result = v.asInt64()
  
  when typ is uint:
    result = v.asUInt()
  when typ is uint8:
    result = v.asUInt8()
  when typ is uint16:
    result = v.asUInt16()
  when typ is uint32:
    result = v.asUInt32()
  when typ is uint64:
    result = v.asUInt64()

  when typ is float:
    result = v.asFloat()
  when typ is float32:
    result = v.asFloat32()
  when typ is float64:
    result = v.asFloat64()

  when typ is string:
    result = v.getString()

  # TODO: time, object, sequence.

  when typ is ValueMap:
    result = v.mapVal

#######################
# Sequence accessors. #
#######################

proc `[]`*(v: Value, index: int): Value =
  if v.kind != valSeq:
    raise newValueErr("Value is not a sequence")
  v.seqVal[index]

proc `[]=`*(v: Value, index: int, val: Value) =
  if v.kind != valSeq:
    raise newValueErr("Value is not a sequence")
  v.seqVal[index] = val

proc `[]=`*[T](v: Value, index: int, val: T) =
  if v.kind != valSeq:
    raise newValueErr("Value is not a sequence")
  v.seqVal[index] = toValue(val)

proc add*[T](v: Value, item: T) =
  if v.kind == valSeq:
    v.seqVal.add(toValue(item))
  else:
    raise newValueErr("Can't .add() to value of kind: " & v.kind.`$`)

###########################
# Object / map accessors. #
###########################

proc `[]`*(v: Value, key: string): Value =
  # [] accessor for map/object/tuple values.

  if v.kind == valValueMap:
    return v.mapVal[key]
  else:
    raise newException(Exception, "Value is not a map / object")

proc `[]=`*(v: Value, key: string, val: Value) =
  # Set values on maps/objects/tuples.

  if v.kind == valValueMap:
    v.mapVal[key] = val
  else:
    raise newException(Exception, "Value is not a map / object")

proc `[]=`*[T](v: Value, key: string, val: T) =
  # Set values on maps/objects/tuples.

  if v.kind == valValueMap:
    v.mapVal[key] = val
  else:
    raise newException(Exception, "Value is not a map / object")

proc `.`*(v: Value, key: expr): Value =
  v[string(key)]

proc `.=`*(v: Value, key: expr, val: Value) =
  v[string(key)] = val

proc `.=`*[T](v: Value, key: expr, val: T) =
  v[string(key)] = val


##############
# Operators. #
##############

proc len*(v: Value): int =
  case v.kind
  of valChar:
    result = 1
  of valString:
    result = v.strVal.len()
  of valSeq:
    result = v.seqVal.len()
  of valValueMap:
    result = v.mapVal.len()
  else:
    raise newValueErr(".len() not available for value of type " & v.kind.`$`)

proc `==`*(a: Value, b: tuple): bool =
  if a.kind != valValueMap:
    return false

  var handledKeys = 0
  for key, val in b.fieldPairs:
    if not a.mapVal.hasKey(key):
      return false
    handledKeys += 1

  return handledKeys == a.mapVal.len()

proc `==`*(a: Value, b: Value): bool =
  if a.kind != b.kind:
    return false

  case a.kind
  of valNone:
    # Bot are valNone.
    result = true

  of valBool:
    result = a.boolVal == b.boolVal

  of valChar:
    result = a.charVal == b.charVal

  of valInt:
    result = a.intVal == b.intVal

  of valUInt:
    result = a.uintVal == b.uintVal

  of valFloat:
    result = a.floatVal == b.floatVal

  of valString:
    result = a.strVal == b.strVal

  of valSeq:
    if a.len() != b.len():
      return false

    for index, item in a.seqVal:
      result = true
      if a.seqVal[index] != b.seqVal[index]:
        result = false
        break

  of valValueMap:
    result = a.mapVal == b.mapVal

  else:
    raise newValueErr("`==` not implemented for value kind: " & a.kind.`$`)



######################
# String conversions #
######################

proc strToChar(str: string): char =
  if str == nil:
    raise newConversionErr("Can't convert nil string.")

  case str.len():
  of 0:
    result = '\0'
  of 1:
    result = str[0]
  else:
    raise newConversionErr("Can't convert str '$1' to char: must have length 1" % [str])


proc convertString*[T](str: string): T =
  if str == nil:
    raise newConversionErr("Can't convert nil string.")

  var haveResult = false

  when T is bool:
    result = parseBool(str)    
    haveResult = true
  when T is char:
    result = strToChar(str)
    haveResult = true
  when T is int:
    result = parseInt(str)
    haveResult = true
  when T is int8:
    result = int8(parseInt(str))
    haveResult = true
  when T is int16:
    result = int16(parseInt(str))
    haveResult = true
  when T is int32:
    result = int32(parseInt(str))
    haveResult = true
  when T is int64:
    result = int64(parseBiggestInt(str))
    haveResult = true
  when T is uint:
    result = uint(parseInt(str))
    haveResult = true
  when T is uint8:
    result = uint8(parseInt(str))
    haveResult = true
  when T is uint16:
    result = uint16(parseInt(str))
    haveResult = true
  when T is uint32:
    result = uint32(parseInt(str))
    haveResult = true
  when T is uint64:
    result = uint64(parseBiggestInt(str))
    haveResult = true
  when T is float:
    result = parseFloat(str)
    haveResult = true
  when T is float32:
    result = float32(parseFloat(str))
    haveResult = true
  when T is float64:
    result = float64(parseFloat(str))
    haveResult = true
  when T is string:
    result = str
    haveResult = true

  if not haveResult:
    raise newConversionErr("Can't convert string '$1' to $2." % [str, name(T)])


##########################
# buildAccessors helper. #
##########################

proc buildAccessors*(typeName: string, fields: seq[tuple[name, typ: string]]): string =
  # Build setProp().
  var code = "method setProp*[T](o: $1, name: string, val: T) =\n" % [typeName]
  code &= "  case name\n"
  for field in fields:
    code &= """  of "$1": 
    when T is type(o.$1):
      o.$1 = val
    else:
      when type(o.$1) is T:
        o.$1 = cast[$1](val)
      else:
        when type(o.$1) is seq:
          if val == nil:
            o.$1 = nil
          else:
            var s: seq[$2] = @[]
            for item in val:
              s.add(cast[$2](item))
            o.$1 = s
        else:
          raise newException(Exception, "Field $1 is $2, not " & name(type(T)))""" % [field.name, field.typ]
    code &= "\n"
  code &= """  else: raise newException(Exception, "Unknown field: " & name)"""
  code &= "\n\n"

  # Build setProp() for strings.
  code &= "method setProp*(o: $1, name: string, val: string) =\n" % [typeName]
  code &= "  case name\n"
  for field in fields:
    code &= """  of "$1": o.$1 = convertString[$2](val)""" % [field.name, field.typ]
    code &= "\n"
  code &= """  else: raise newException(Exception, "Unknown field: " & name)"""
  code &= "\n\n"

  # Build setValue().
  code &= "method setValue*(o: $1, name: string, val: Value) =\n" % [typeName]
  # Check that field exists and determine type.
  code &= "  var typ = \"\"\n"
  code &= "  case name\n"
  for field in fields:
    var setter = ""
    case field.typ
    of "bool":
      setter = "o.$1 = val.asBool()" % [field.name]
    of "char":
      setter = "o.$1 = val.asChar()" % [field.name]
    of "int", "int8", "int16", "int32", "int64":
      setter = "o.$1 = $2(val.asBiggestInt())" % [field.name, field.typ]
    of "uint", "uint8", "uint16", "uint32", "uint64":
      setter = "o.$1 = $2(val.asBiggestUInt())" % [field.name, field.typ]
    of "float", "float32", "float64":
      setter = "o.$1 = $2(val.asBiggestFloat())" % [field.name, field.typ]
    of "string":
      setter = "o.$1 = val.asString()" % [field.name]
    else:
      continue
      #raise newException(Exception, "setValue() can't handle type: " & field.typ)
    
    code &= "  of \"$1\":\n" % [field.name]
    code &= "    " & setter & "\n"
  code &= """  else: raise newException(Exception, "Unknown field: " & name)"""
  code &= "\n\n"
  
  # Build getValue().
  code &= "method getValue*(o: $1, name: string): Value =\n" % [typeName]
  code &= "  case name\n"
  for field in fields:
    code &= """  of "$1": result = toValue(o.$1)""" % [field.name]
    code &= "\n"
  code &= """  else: raise newException(Exception, "Unknown field: " & name)"""
  code &= "\n\n"

  return code

proc buildAccessors*(node: NimNode): NimNode {.compileTime.} =
  if node.kind != nnkTypeDef:
    raise newException(Exception, "node must be nnkTypeDef")
  
  var typeNode = node[0] 
  if typeNode.kind == nnkPostfix:
    typeNode = typeNode[1]
  var typeName = $typeNode
  
  # Find fields.
  var fields: seq[tuple[name: string, typ: string]] = @[]
  for fieldDef in node[2][0][2]:
    if fieldDef.kind == nnkEmpty or fieldDef.kind == nnkNilLit:
      continue

    fields.add((fieldDef[0].`$`, fieldDef[1].`$`))

  var code = buildAccessors(typeName, fields)
  parseStmt(code)
