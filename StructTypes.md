# Types

Several data types are used throughout this API. They are defined as follows:

## Align

A `string` enum representing some alignment.

Valid values are:
- "left"
- "right"
- "center"

## Length

A `string` or non-negative `integer` value representing a length. May also be `nil`,
but the meaning of nil depends on the context in which Length is used.

If Length is an `integer`, it represents an absolute length in characters.

If length is a `string`, it can either represent an absolute length or a relative length.
If the string ends with *'%'*, then it is interpreted as the percentage of the parent container.
Otherwise, it is directly converted to an integer representing an absolute length in characters.

## AdvLength

A `table` representing a length with constraints.

_fields:_
- min `Length` the minimum allowable value
- max `Length` the maximum allowable value
- value `Length` the base value of the length
