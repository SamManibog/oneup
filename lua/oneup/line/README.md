# Line

The line module is used to store highlight and text data for a buffer line.

## Parameters

### text

**Type:** `string` or `Text[]`

The text content of the line. Either a single string or an array of multiple text classes.

### opts

Type: `table`

_fields:_
- `Align` align: The alignment of the content.
- `string` hl_group: The name of the highlight group for the text.
- `number` hl_priority: The priority of the highlight.

Highlight and alignment options for the line's text.

## Functions

### render(buf, line, width)

Draws the line to a buffer. Intended for internal use only.

_parameters:_
- `number` buf: The buffer to render the line to.
- `integer` line: The line number to render the line to.
- `integer` width: The width of the window the buffer belongs to.

### getText()

Returns the string that would be rendered to the screen ignoring alignment.

*return (`string`):* The text contained in the line.
