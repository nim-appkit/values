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

# Must be includes instead of imports.
include "system/inclrtl.nim"
include "system/hti.nim"

import typeinfo, typetraits, macros
import tables
from json import nil
from strutils import parseBiggestInt, parseFloat, parseBool, parseInt, splitLines, format
from sequtils import toSeq
from times import parse, format, `==`, Time, TimeInfo
import hashes

###########
# Errors. #
###########

type ConversionError* = object of Exception
  discard

proc newConversionError(msg: string): ref ConversionError =
  newException(ConversionError, msg)

##########
# Values #
##########

type
  ValueKind* = enum
    valUnknown
    valNil
    valBool
    valChar
    valInt
    valUInt
    valFloat
    valString
    valTime
    valSeq
    valSet
    valObj
    valPointer
    
    valMap

type
  Value* = object
    case kind*: ValueKind
    of valUnknown, valNil:
      discard

    of valBool:
      boolVal: bool

    of valChar:
      charVal: char

    of valInt:
      intVal: BiggestInt

    of valUInt:
      uintVal: uint64

    of valFloat:
      floatVal: BiggestFloat

    of valString:
      strVal: string

    of valTime:
      timeVal: times.TimeInfo

    of valSeq, valSet:
      seqVal: seq[ValueRef]

    of valObj:
      objPointer: pointer
      nimType: PNimType 
      typeName: string

    of valPointer:
      pointerVal: pointer

    of valMap:
      map: Table[string, ValueRef]
      autoNesting*: bool

  ValueRef* = ref Value

  Map* = ValueRef

# Value destructor.
#proc `=destroy`*(v: var Value) =
#  if v.kind == valObj:
#    if v.ptrVal != nil:
#      dealloc(v.ptrVal)

proc `$`*(v: Value): string
proc `$`*(v: ValueRef): string
proc `==`*(a: ValueRef, b: ValueRef): bool

##################
# Type checkers. #
##################

proc isInvalid*(v: Value): bool =
  v.kind == valUnknown

proc isInvalid*(v: ValueRef): bool =
  v[].isInvalid()

proc isNil*(v: Value): bool =
  v.kind == valNil

proc isNil*(v: ValueRef): bool =
  v[].isNil()

proc isBool*(v: Value): bool =
  v.kind == valBool

proc isBool*(v: ValueRef): bool =
  v[].isBool

proc isChar*(v: Value): bool =
  v.kind == valChar

proc isChar*(v: ValueRef): bool =
  v[].isChar()

proc isInt*(v: Value): bool =
  v.kind == valInt

proc isInt*(v: ValueRef): bool =
  v[].isInt()

proc isUInt*(v: Value): bool =
  v.kind == valUInt

proc isUInt*(v: ValueRef): bool =
  v[].isUInt()

proc isFloat*(v: Value): bool =
  v.kind == valFloat

proc isFloat*(v: ValueRef): bool =
  v[].isFloat()

proc isNumeric*(v: Value): bool =
  v.kind in {valInt, valUInt, valFloat}

proc isNumeric*(v: ValueRef): bool =
  v[].isNumeric()

proc isString*(v: Value): bool =
  v.kind == valString

proc isString*(v: ValueRef): bool =
  v[].isString()

proc isTime*(v: Value): bool =
  v.kind == valTime

proc isTime*(v: ValueRef): bool =
  v[].isTime

proc isSeq*(v: Value): bool =
  v.kind == valSeq

proc isSeq*(v: ValueRef): bool =
  v[].isSeq()

proc isSet*(v: Value): bool =
  v.kind == valSet

proc isSet*(v: ValueRef): bool =
  v[].isSet()

proc isObject*(v: Value): bool =
  v.kind == valObj

proc isObject*(v: ValueRef): bool =
  v[].isObject()

proc isPointer*(v: Value): bool =
  v.kind == valPointer

proc isPointer*(v: ValueRef): bool =
  v[].isPointer()

proc isMap*(v: Value): bool =
  v.kind == valMap

proc isMap*(v: ValueRef): bool =
  v[].isMap()

#############
# isZero(). #
#############

proc isZero*(v: Value): bool =
  case v.kind
  of valUnknown, valNil:
    result = true
  of valBool:
    result = false
  of valChar:
    result = v.charVal == '\0'
  of valInt:
    result = v.intVal == 0
  of valUInt:
    result = v.uintVal == 0
  of valFloat:
    result = v.floatVal == 0
  of valString:
    result = v.strVal == nil or v.strVal == ""
  of valPointer:
    result = v.pointerVal == nil
  of valObj:
    result = v.objPointer == nil
  of valTime, valSeq, valSet, valMap:
    result = false

proc isZero*(v: ValueRef): bool =
  v[].isZero()

#################
# Common procs. #
#################

proc len*(v: Value): int =
  case v.kind:
  of valChar:
    result = 1
  of valString:
    result = v.strVal.len()
  of valSeq, valSet:
    result = v.seqVal.len()
  of valMap:
    result = v.map.len()
  else:
    raise newException(ValueError, ".len() is not available for " & v.kind.`$`)

proc len*(v: ValueRef): int =
  v[].len()

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
    result = hash(BiggestInt(v.uintVal))
  of valFloat:
    result = hash(v.floatVal)
  of valString:
    result = hash(v.strVal)
  of valSeq, valSet:
    var s: seq[Value] = @[]
    for item in v.seqVal:
      s.add(item[])
    result = hash(s)
  else:
    raise newException(ValueError, "Can't hash " & v.kind.`$`)

proc hash*(v: ValueRef): hashes.Hash =
  v[].hash()

###########
# toValue #
###########

# Need a forward declaration for newValueMap().
proc newValueMap*(autoNesting: bool = false): ValueRef

proc toValue*[T](val: T): Value =
  # Bool val. 
  when val is bool:
    result = Value(kind: valBool, boolVal: val)

  # Char val.
  when val is char:
    result = Value(kind: valChar, charVal: val)

  # Int values.
  when val is int or val is int8 or val is int16 or val is int32 or val is int64:
    result = Value(kind: valInt, intVal: BiggestInt(val))
  
  # UInt values.
  when val is uint or val is uint8 or val is uint16 or val is uint32 or val is uint64:
    result = Value(kind: valUInt, uintVal: uint64(val))
    
  # Float values.
  when val is float or val is float32 or val is float64:
    result = Value(kind: valFloat, floatVal: float64(val))
  
  # String. 
  when val is string:
    var strVal = if val == nil: "" else: val
    result = Value(kind: valString, `strVal`: strVal)

  when val is times.Time:
    result = Value(kind: valTime, timeVal: times.getLocalTime(val))
  when val is times.TimeInfo:
    result = Value(kind: valTime, timeVal: val)

  when val is seq or val is array:
    result = Value(kind: valSeq, seqVal: @[])
    for x in val:
      result.seqVal.add(toValueRef(x))

  when val is set:
    result = Value(kind: valSet, seqVal: newSeq[ValueRef]())
    for x in val:
      result.seqVal.add(toValueRef(x))

  when val is pointer or val is ptr:
    result = Value(kind: valPointer, pointerVal: val)

  # Values, valuemaps.
  when val is Value:
    result = Value(kind: val.kind)
    deepCopy(result, val)

  when val is ValueRef:
    result = val[]

  if T is tuple:
    raise newException(ValueError, "Must use toValueRef for tuples (results in map)!")

  if result.kind == valUnknown:
    raise newException(ValueError, "Could not create Value for item of type: " & name(type(val)))

proc toValueRef*[T](val: T): ValueRef =
  when val is tuple:
    result = newValueMap()
    for key, val in val.fieldPairs:
      result.map[key] = toValueRef(val)
  else:
    new(result)
    result[] = toValue(val)

proc newNilVal*(): Value =
  Value(kind: valNil)

###################
# Sequence procs. #
###################

iterator pairs*(v: Value): tuple[key: int, val: ValueRef] =
  if v.kind notin {valSeq, valSet}:
    raise newException(ValueError, ".pairs() iterator is not available for " & v.kind.`$`)

  for i, x in v.seqVal:
    yield (i, x)

iterator pairs*(v: ValueRef): tuple[key: int, val: ValueRef] =
  for i, x in v[].pairs:
    yield (i, x)

iterator items*(v: Value): ValueRef =
  if v.kind notin {valSeq, valSet}:
    raise newException(ValueError, ".pairs() iterator is not available for " & v.kind.`$`)

  for x in v.seqVal:
    yield x

iterator items*(v: ValueRef): ValueRef =
  for x in v[].items:
    yield  x

proc `[]=`*[T](v: var Value, key: int, val: T) =
  if v.kind != valSeq:
    raise newException(ValueError, "[]= can only be used for sequence values, got " & v.kind.`$`)
  v.seqVal[key] = toValueRef(val)

proc `[]=`*[T](v: ValueRef, key: int, val: T) =
  if v.kind != valSeq:
    raise newException(ValueError, "[]= can only be used for sequence values, got " & v.kind.`$`)
  v.seqVal[key] = toValueRef(val)

proc `[]`*(val: Value, key: int): ValueRef =
  if val.kind != valSeq:
    raise newException(ValueError, "[]= can only be used for sequence values, got " & val.kind.`$`)
  val.seqVal[key]

proc `[]`*(val: ValueRef, key: int): ValueRef =
  val[][key]

proc add*[T](v: var Value, x: T) =
  if v.kind != valSeq:
    raise newException(ValueError, ".add() is not available for " & v.kind.`$`)
  v.seqVal.add(toValueRef(x))

proc add*[T](v: ValueRef, x: T) =
  v.seqVal.add(toValueRef(x))

proc newValueSeq*(items: varargs[ValueRef, toValueRef]): ValueRef =
  new(result)
  result.kind = valSeq
  result.seqVal = @[]
  for item in items:
    result.add(item)

proc ValueSeq(items: varargs[ValueRef, toValueRef]): ValueRef =
  newValueSeq(items)

########
# Map. #
########

proc newValueMap*(autoNesting: bool = false): ValueRef =
  new(result)
  result[] = Value(
    kind: valMap,
    map: initTable[string, ValueRef](32),
    `autoNesting`: autoNesting
  )

proc hasKey*(v: ValueRef, key: string): bool =
  if v.kind != valMap:
    raise newException(ValueError, ".hasKey() is not available for " & v.kind.`$`)
  result = v.map.hasKey(key)

iterator keys*(v: ValueRef): string =
  if v.kind != valMap:
    raise newException(ValueError, ".hasKey() is not available for " & v.kind.`$`)
  for key in v.map.keys:
    yield key

proc getKeys*(v: ValueRef): seq[string] =
  if v.kind != valMap:
    raise newException(ValueError, ".hasKey() is not available for " & v.kind.`$`)
  toSeq(v.map.keys)

iterator fieldPairs*(v: Value): tuple[key: string, val: ValueRef] =
  if v.kind != valMap:
    raise newException(ValueError, "fieldPairs can only be used for map values, got " & v.kind.`$`)

  for key, x in v.map:
    yield (key, x)

iterator fieldPairs*(v: ValueRef): tuple[key: string, val: ValueRef] =
  for key, x in v[].fieldPairs:
    yield (key, x)

proc `[]=`*[T](v: ValueRef, key: string, val: T) =
  if v.kind != valMap:
    raise newException(ValueError, "[]= can only be used for map values, got " & v.kind.`$`)
  v.map[key] = toValueRef(val)

proc `[]`*(v: ValueRef, key: string): ValueRef =
  if v.kind != valMap:
    raise newException(ValueError, "[]= can only be used for map values, got " & v.kind.`$`)
  if not v.map.hasKey(key) and v.autoNesting:
    v.map[key] = newValueMap(true)
  v.map[key]


proc `.=`*[T](v: ValueRef, key: auto, val: T) =
  v[string(key)] = val

proc `.`*(v: ValueRef, key: auto): ValueRef =
  return v[string(key)]

proc toMap*(t: tuple): ValueRef =
  # Convenient constructor for maps based on a tuple.
  result = newValueMap()

  for key, val in t.fieldPairs():
    result[key] = val

proc `@%`*(t: tuple): ValueRef =
  toMap(t)

proc `@%`*(): ValueRef =
  newValueMap()


########
# `==` #
########

proc `==`*(a: Value, b: Value): bool =
  if a.kind != b.kind:
    return false

  case a.kind
  of valUnknown, valNil:
    # Both are valNone.
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

  of valSeq, valSet:
    if a.len() != b.len():
      return false

    result = true
    for index, item in a.seqVal:
      if a.seqVal[index] != b.seqVal[index]:
        result = false
        break

  of valMap:
    result = a.map == b.map

  else:
    raise newException(ValueError, "`==` not implemented for value kind: " & a.kind.`$`)

proc `==`*[T](a: Value, b: T): bool =
  a == toValue(b)

proc `==`*(a: ValueRef, b: ValueRef): bool =
  if system.`==`(a, nil) or system.`==`(b, nil):
    return system.`==`(a, b)

  a[] == b[]

proc `==`*(a: ValueRef, b: Value): bool =
  if system.`==`(a, nil):
    return b.kind == valNil

  a[] == b

proc `==`*(a: Value, b: ValueRef): bool =
  if system.`==`(b, nil):
    return a.kind == valNil

  a == b[]

proc `==`*[T](a: ValueRef, b: T): bool =
  a[] == toValue(b)

#############
# `$`, repr #
#############

# Value $.

proc `$`*(v: Value): string =
  case v.kind
  of valUnknown:
    result = "unknown"
  of valNil:
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
  of valTime:
    result = $(v.timeVal)
  of valSeq, valSet:
    result = $(v.seqVal)
  of valPointer:
    result = repr(v.pointerVal)
  of valObj:
    result = "[" & v.typeName & "] " & repr(v.objPointer)
  of valMap:
    result = "[Map] =>\n"
    for key, value in v.fieldPairs():
      result &= "  '" & key & "' ==> " & repr(value)

proc `$`*(v: ValueRef): string =
  $(v[])

proc repr*(v: Value): string =
  "Value[$1]($2)".format(v.kind, v)

proc repr*(v: ValueRef): string =
  repr(v[])

######################
# determineValueKind #
######################

proc determineAnyKind*(x: typedesc): AnyKind =
  # Determine the AnyKind based on a type description.
  
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

proc determineValueKind*(x: string): ValueKind =
  # Determine ValueKind based on name(type(x)).

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
  of "pointer", "ptr":
    result = valPointer
  of "Time", "TimeInfo":
    result = valTime
  else:
    result = valUnknown

proc determineValueKind*(x: typedesc): ValueKind =
  # Bool val. 
  when x is bool:
    result = valBool

  # Char val.
  when x is char:
    result = valChar

  # Int values.
  when x is int or x is int8 or x is int16 or x is int32 or x is int64:
    result = valInt
  
  # UInt values.
  when x is uint or x is uint8 or x is uint16 or x is uint32 or x is uint64:
    result = valUInt
    
  # Float values.
  when x is float or x is float32 or x is float64:
    result = valFloat
  
  # String. 
  when x is string:
    result = valString

  when x is times.Time or x is times.TimeInfo:
    result = valTime

  when x is seq or x is array:
    result == valSeq

  when x is set:
    result = valSet

  when x is pointer:
    result = valPointer

  when x is ptr or x is pointer:
    result = valPointer

  # Values, valuemaps.
  when x is Value:
    result = valValue

  when x is Map:
    result = valMap
    
  if result == valUnknown:
    raise newException(ValueError, "Could not determine ValueKind for item of type: " & name(type(x))) 

####################
# Value accessors. #
####################

proc asBiggestFloat*(v: Value): BiggestFloat
proc strToChar*(str: string): char

# Bool accessors. 

proc getBool*(v: Value): bool =
  v.boolVal

proc getBool*(v: ValueRef): bool =
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
    raise newConversionError("Can't convert $1 to bool.".format(v.kind))

proc asBool*(v: ValueRef): bool =
  v[].asBool()

# Char accessors. 

proc getChar*(v: Value): char =
  v.charVal

proc getChar*(v: ValueRef): char =
  v.charVal

proc asChar*(v: Value): char =
  if v.kind == valChar:
    return v.charVal
  elif v.kind == valString:
    return strToChar(v.strVal)
  else:
    raise newConversionError("Can't convert $1 to char.".format(v.kind))

proc asChar*(v: ValueRef): char =
  v[].asChar()

# Int accessors.
proc getInt*(v: Value): BiggestInt =
  v.intVal

proc getInt*(v: ValueRef): BiggestInt =
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
    raise newConversionError("Can't convert $1 to int.".format(v.kind))

proc asBiggestInt*(v: ValueRef): BiggestInt =
  v[].asBiggestInt()

proc asInt*(v: Value): int =
  int(v.asBiggestInt())

proc asInt*(v: ValueRef): int =
  v[].asInt()

proc asInt8*(v: Value): int8 =
  int8(v.asBiggestInt())

proc asInt8*(v: ValueRef): int8 =
  v[].asInt8()

proc asInt16*(v: Value): int16 =
  int16(v.asBiggestInt())

proc asInt16*(v: ValueRef): int16 =
  v[].asInt16()

proc asInt32*(v: Value): int32 =
  int32(v.asBiggestInt())

proc asInt32*(v: ValueRef): int32 =
  v[].asInt32()

proc asInt64*(v: Value): int64 =
  v.asBiggestInt()

proc asInt64*(v: ValueRef): int64 =
  v[].asInt64()

# Uint accessors.

proc getUInt*(v: Value): uint64 =
  v.uintVal

proc getUInt*(v: ValueRef): uint64 =
  v.uintVal

proc asUInt64*(v: Value): uint64 =
  if v.isUint():
    result = v.uintVal
  elif v.isInt():
    result = uint64(v.intVal)
  elif v.isFloat():
    result = uint64(v.floatVal)
  else:
    result = uint64(v.asBiggestInt())

proc asUInt64*(v: ValueRef): uint64 =
  v[].asUInt64()

proc getUInt64*(v: Value): uint64 =
  v.uintVal

proc asUInt*(v: Value): uint =
  uint(v.asUInt64())

proc asUInt8*(v: Value): uint8 =
  uint8(v.asUInt64())

proc asUInt16*(v: Value): uint16 =
  uint16(v.asUInt64())

proc asUInt32*(v: Value): uint32 =
  uint32(v.asUInt64())

proc getUInt64*(v: ValueRef): uint64 =
  v.uintVal

proc asUInt*(v: ValueRef): uint =
  v[].asUInt()

proc asUInt8*(v: ValueRef): uint8 =
  v[].asUInt8()

proc asUInt16*(v: ValueRef): uint16 =
  v[].asUInt16()

proc asUInt32*(v: ValueRef): uint32 =
  v[].asUInt32()


# Float accessors.

proc getBiggestFloat*(v: Value): BiggestFloat =
  v.floatVal

proc getBiggestFloat*(v: ValueRef): BiggestFloat =
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
    raise newConversionError("Can't convert $1 to float.".format(v.kind))

proc asBiggestFloat*(v: ValueRef): BiggestFloat =
  v[].asBiggestFloat()

proc getFloat*(v: Value): float =
  v.floatVal

proc getFloat*(v: ValueRef): float =
  v.floatVal

proc asFloat*(v: Value): float =
  float(v.asBiggestFloat())

proc asFloat*(v: ValueRef): float =
  v[].asFloat()

proc asFloat32*(v: Value): float32 =
  float32(v.asBiggestFloat())

proc asFloat32*(v: ValueRef): float32 =
  v[].asFloat32()

proc asFloat64*(v: Value): float64 =
  v.asBiggestFloat()

proc asFloat64*(v: ValueRef): float64 =
  v[].asFloat64()


# String accessor.

proc getString*(v: Value): string = 
  v.strVal

proc getString*(v: ValueRef): string = 
  v.strVal

proc asString*(v: Value): string =
  return v.`$`

proc asString*(v: ValueRef): string =
  v[].`$`

# Time.

proc getTime*(v: Value): times.TimeInfo =
  v.timeVal

proc getTime*(v: ValueRef): times.TimeInfo =
  v.timeVal

# Sequence, set, map.

proc getSeq*(v: Value): seq[ValueRef] =
  v.seqVal


proc asSeq*(v: Value, typ: typedesc): seq[typ] =
  if v.kind in {valSeq, valSet}:
    result = @[]
    for item in v.seqVal:
      result.add(item[typ])
  elif v.kind == valMap:
    result = @[]
    for item in v.map.values:
      result.add(item[typ])
  else:
    raise newException(ValueError, ".asSeq() is only available for sequence, set, map. got " & v.kind.`$`)

proc getSeq*(v: ValueRef): seq[ValueRef] =
  v.seqVal

proc asSeq*(v: ValueRef, typ: typedesc): seq[typ] =
  v[].asSeq(typ)

proc getSet*(v: Value): seq[ValueRef] =
  v.seqVal

proc getSet*(v: ValueRef): seq[ValueRef] =
  v.seqVal

# Typed accessor.

proc `[]`*(v: Value, typ: typedesc): any =
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

  when typ is times.Time:
    result = times.timeInfoToTime(v.getTime())
  when typ is times.TimeInfo:
    result = v.getTime()

  # TODO: object, sequence.

proc `[]`*(v: ValueRef, typ: typedesc): any =
  v[][typ]

#################
# JSON support. #
#################

###################################
# toValue() for the JSON parser. #
##################################

proc toValueRef*(n: json.JsonNode): ValueRef =
  case n.kind
  of json.JString:
    return toValueRef(n.str)
  of json.JInt:
    return toValueRef(n.num)
  of json.JFloat:
    return toValueRef(n.fnum)
  of json.JBool:
    return toValueRef(n.bval)
  of json.JNull:
    new(result)
    result.kind = valNil 
  of json.JObject:
    result = newValueMap()
    for item in n.fields:
      result[item.key] = toValueRef(item.val)
  of json.JArray:
    new(result)
    result.kind = valSeq
    result.seqVal = @[]
    for item in n.elems:
      result.seqVal.add(toValueRef(item))


 
proc toJson*(v: ValueRef): string

proc toJson*(v: Value): string =
  case v.kind
  of valUnknown:
    result = ""
  of valNil:
    result = "null"

  of valBool:
    result = v.boolVal.`$`

  of valChar:
    result = json.escapeJson(v.charVal.`$`) 

  of valInt:
    result = v.intVal.`$`

  of valUInt:
    result = v.uintVal.`$`

  of valFloat:
    result = v.floatVal.`$`

  of valString:
    result = json.escapeJson(v.strVal)

  of valTime:
    result = json.escapeJson(v.timeVal.format("yyyy-dd-MM'T'HH:mmzzz"))

  of valSeq, valSet:
    result = "["
    for i, val in v.seqVal:
      result &= val.toJson()
      if i < high(v.seqVal):
        result &= ", "
    result &= "]"

  of valMap:
    result = "{"

    var lastIndex = v.len() - 1
    var index = 0
    for key, val in v.fieldPairs:
      result &= json.escapeJson(key) & ": " & val[].toJson()
      if index < lastIndex:
        result &= ", "
      index += 1

    result &= "}"


  of valObj, valPointer:
    raise newException(ValueError, "toJson() not yet implemented for " & v.kind.`$`)

proc toJson*(v: ValueRef): string =
  v[].toJson()

proc fromJson*(jsonContent: string): ValueRef =
  toValueRef(json.parseJson(jsonContent))

######################
# String conversions #
######################

proc strToChar(str: string): char =
  if str == nil:
    raise newConversionError("Can't convert nil string.")

  case str.len():
  of 0:
    result = '\0'
  of 1:
    result = str[0]
  else:
    raise newConversionError("Can't convert str '$1' to char: must have length 1".format(str))


proc convertString*[T](str: string): T =
  if str == nil:
    raise newConversionError("Can't convert nil string.")

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
    raise newConversionError("Can't convert string '$1' to $2.".format(str, name(T)))




##########################
# buildAccessors helper. #
##########################

proc buildAccessors*(typeName: string, fields: seq[tuple[name, typ: string]]): string =
  # Build setProp().
  var code = "method setProp*[T](o: $1, name: string, val: T) =\n".format(typeName)
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
          raise newException(Exception, "Field $1 is $2, not " & name(type(T)))""" .format(field.name, field.typ)
    code &= "\n"
  code &= """  else: raise newException(Exception, "Unknown field: " & name)"""
  code &= "\n\n"

  # Build setProp() for strings.
  code &= "method setProp*(o: $1, name: string, val: string) =\n".format(typeName)
  code &= "  case name\n"
  for field in fields:
    code &= """  of "$1": o.$1 = convertString[$2](val)""".format(field.name, field.typ)
    code &= "\n"
  code &= """  else: raise newException(Exception, "Unknown field: " & name)"""
  code &= "\n\n"

  # Build setValue().
  code &= "method setValue*(o: $1, name: string, val: Value) =\n".format(typeName)
  # Check that field exists and determine type.
  code &= "  var typ = \"\"\n"
  code &= "  case name\n"
  for field in fields:
    var setter = ""
    case field.typ
    of "bool":
      setter = "o.$1 = val.asBool()".format(field.name)
    of "char":
      setter = "o.$1 = val.asChar()".format(field.name)
    of "int", "int8", "int16", "int32", "int64":
      setter = "o.$1 = $2(val.asBiggestInt())".format(field.name, field.typ)
    of "uint", "uint8", "uint16", "uint32", "uint64":
      setter = "o.$1 = $2(val.asBiggestUInt())".format(field.name, field.typ)
    of "float", "float32", "float64":
      setter = "o.$1 = $2(val.asBiggestFloat())".format(field.name, field.typ)
    of "string":
      setter = "o.$1 = val.asString()".format(field.name)
    else:
      continue
      #raise newException(Exception, "setValue() can't handle type: " & field.typ)
    
    code &= "  of \"$1\":\n".format(field.name)
    code &= "    " & setter & "\n"
  code &= """  else: raise newException(Exception, "Unknown field: " & name)"""
  code &= "\n\n"
  
  # Build getValue().
  code &= "method getValue*(o: $1, name: string): Value =\n".format(typeName)
  code &= "  case name\n"
  for field in fields:
    code &= """  of "$1": result = toValue(o.$1)""".format(field.name)
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
