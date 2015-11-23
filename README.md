# nim-values

**Note: still a WIP. Objects and tuples are not supported yet, but will be soon.**

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

var i = toValue(22)
var s = toValue("test")

i == s # False

var iv = toValue("22")
iv.asInt() == 22 # True.
```

## Maps

```nim
import values

var m = newValueMap(autNesting = true)

m.field1 = 22
echo m.field1.getString() # "22"
echo m.field1.asInt() # 22

m.field2 = "xxx"

m.field3 = @[1, 2, 3, 4, 5]
echo m.field3[2].getInt() # 3

# Nested.
m.nestedMap.field1 = "val"
m.nestedMap.subnested.data = @["a", "b", "c"]

echo m.nestedMap.subnested.data[1].getString() # "b"
```

## Additional Information

### Versioning

This project follows [SemVer](semver.org).

### License.

This project is under the [MIT license](https://opensource.org/licenses/MIT).
