# nim-values

**Note: still a WIP. Objects are not supported yet, but will be soon.**

A [Nim](http://nim-lang.org) library for working with arbitrary variables/values.
Includes a map data structure for easily storing and working with nested, flexible data. 

## Getting started

### Install

You can easily install *values* with [nimble](https://github.com/nim-lang/nimble), Nims package manager.

```bash
nimble install values
```

Alternatively, just clone the repo and add it to your nim path when compiling.

### Use

```nim
import values

# Create a new value.
var i = toValue(22)
# Return the value as a specific type.
var retrievedInt = i[int]
# Alternative:
retrievedInt = i.getInt()

# Compare values with other values or other types.
i == toValue(22) # true
i == 22 # true
i == "" # false

var s = toValue("test")
var retrievedStr = s[string]
i == s # False

var iv = toValue("22")
# Convert between types with the "asXX" procs. (asInt, asUint8, asString, ...)
iv.asInt() == 22 # True.
```

## Maps

```nim
import values

# New, empty map:

var m = newValueMap()
m.x = "x"
echo(m.x)

m.y = 44.4
echo(m.y)

m["a"] = false
echo(m["a"])

m.hasKey("x") => false

for key, val in m.fieldPairs:
  echo(key, ": ", val.kind)

# Create a new, nested map.
var m1 = @%(a: 22, b: "val", c: (a: 22), d: [1, 2, 3])

m1.d.len() => 3
var x = m1.d[1][int] # => 2

m1.newKey = 55

# Create a map with automatic nesting!

var m = newValueMap(autNesting = true)

m.field1 = 22

m.nestedMap.field1 = "val"

m.nestedMap.subnested.again.data = @["a", "b", "c"]
m.nestedMap.subnested.again.data.len() # => 3

var s = m["nestedMap"]["subnested"]["again"]["data"][0][string]
echo(s)
```

## Additional Information

### Versioning

This project follows [SemVer](semver.org).

### License.

This project is under the [MIT license](https://opensource.org/licenses/MIT).
