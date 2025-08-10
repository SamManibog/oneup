# Utilities

Utility functions used internally, but exposed for external use.

## Functions

### getLength(value, whole, default)

Gets the `integer` value for a `Length`.

_parameters:_
- `Length` value: The length to extract the value from.
- `integer` whole: If value is a percentage, what 100% would be.
- integer default: If value is nil, what its value should be.

*return (`integer`):* An `integer` representing the given `Length`.

### getLengthH(value)

Gets the `integer` value for a `Length` in the horizontal direction, assuming the entire window as the parent.

_parameters:_
- `Length` value: The length to extract the value from.

*return (`integer`):* An `integer` representing the given `Length`.

### getLengthV(value)

Gets the `integer` value for a `Length` in the vertical direction, assuming the entire window as the parent.

_parameters:_
- `Length` value: The length to extract the value from.

*return (`integer`):* An `integer` representing the given `Length`.

### advToInteger(length, horizontal)

Gets the `integer` value for an `AdvLength` in the specified direction, assuming the entire window as the parent.

_parameters:_
- `AdvLength` length: The length to extract the value from.
- `boolean` horizontal: Whether to consider the horizontal or vertical screen direction.

*return (`integer`):* An `integer` representing the given `AdvLength`.

### setBufOpts(buf_id, opts)

Sets all buffer options from a table.

_parameters:_
- `number` buf_id: The id of the buffer to set options for.
- `table` opts: A dictionary of options: option name -> option value.

*return (`integer`):* An `integer` representing the given `AdvLength`.
