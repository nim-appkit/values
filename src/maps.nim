#############
# ValueMap. #
#############

proc newValueMap*(autoNesting: bool = false): ValueMap =
  ValueMap(
    table: initTable[string, Value](32),
    `autoNesting`: autoNesting
  )

proc len*(v: ValueMap): int = 
  v.table.len()

proc hasKey*(m: ValueMap, key: string): bool =
  return m.table.hasKey(key)
  
proc `[]=`*(m: var ValueMap, key: string, val: Value) =
  if key == nil or key == "":
    raise newValueErr("Map keys may not be nil/empty.")
  m.table[key] = val

proc `[]=`*[T](m: var ValueMap, key: string, val: T) =
  if key == nil or key == "":
    raise newValueErr("Map keys may not be nil/empty.")
  m.table[key] = toValue(val)

proc `[]`*(m: var ValueMap, key: string): Value =
  if not m.hasKey(key): 
    if m.autoNesting: 
      m[key] = newValueMap(autoNesting = true)
    else:
      raise newKeyErr(key)
  return m.table[key]

proc `[]`*(m: ValueMap, key: string): Value =
  if not m.hasKey(key): 
    raise newKeyErr(key)
  return m.table[key]

proc `.=`*(m: var ValueMap, key: expr, val: Value) =
  var key = string(key)
  m[key] = val

proc `.=`*[T](m: var ValueMap, key: expr, val: T) =
  var key = string(key)
  m[key] = val

proc `.`*(m: var ValueMap, key: expr): Value =
  var key = string(key)
  return m[key]

proc `.`*(m: ValueMap, key: expr): Value =
  var key = string(key)
  return m[key]

iterator pairs*(m: ValueMap): tuple[key: string, value: Value] =
  for key, val in m.table.pairs():
    yield (key, val)

proc repr*(m: ValueMap): string =
  result = "[ValueMap] =>\n"

  for key, value in m.pairs():
    result &= "  '" & key & "' ==> " & repr(value)

proc repr*(s: seq[ValueMap]): string =
  result = "seq[ValueMap] =>\n"

  for m in s:
    for line in repr(m).splitLines():
      result &= "  " & line & "\n"

  result &= "\n]"
