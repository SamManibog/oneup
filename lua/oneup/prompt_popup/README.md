# Prompt Popup

A popup used to take text input from the user. Instantiated with PromptPopup:new(opts), using the options
defined in the next section.

## Initialization Options

### text

**Type:** `string[]` or `Line[]`

The text to display on the popup provided as a list of separate lines.

### title

**Type:** `string?`

The title to display on the popup. Does nothing if border is set to nil.

### border

**Type:** `boolean?`

Whether or not to display a border on the popup. Defaults to true.

### width

**Type:** `AdvLength` or `Length`

The width of the popup in relation the global width. If `nil`, autofits to the given text.

Note that if width is `nil`, the popup will only be autofit on creation and will
not change in size if the buffer is changed.

### height

**Type:** `AdvLength` or `Length`

The height of the popup in relation the global height. If `nil`, autofits to the given text.

Note that if height is `nil`, the popup will only be autofit on creation and will
not change in size if the buffer is changed.

### persistent

**Type:** `boolean?`

Whether or not the popup window should close upon exiting/changing buffers.

### verify_input

**Type:** `function(string) -> boolean` or `nil`

An optional function used to verify input before on_confirm may be called. The
string passed is the input recieved.

### on_confirm

**Type:** `function(string)`

The function used to process input. The string passed is the input recieved.

### on_close

**Type:** `function?`

The function to run after the popup is closed.

### close_bind

**Type:** `string[]` or `string` or `nil`

The keybinding or list of keybinds used to close the popup.

## Functions

### close()

Closes the popup.

### resize()

Resizes the popup to account for a change in screen or popup dimension.
Note that this is called automatically and not intended for external use.

### getText()

Gets the text of the popup as an array of strings where each element is a new line.

*return (`string[]`):* The text of the popup.

### setText(text)

Sets the text of the popup.

_parameters:_
- `Line[]` or `string[]` text: The new text for the popup.

### updateText()

Re-renders the text of the popup to its original value.

### winId()

Gets the window id of the popup.

*return (`integer`):* The window id of the popup.

### bufId()

Gets the buffer id of the popup.

*return (`integer`):* The buffer id of the popup.

### setModifiable(value)

Sets the modifiable buffer option to the given value.

_parameters:_
- `boolean` value: The value to set the modifiable buffer option to.

### getModifiable()

Returns the whether or not the buffer is modifiable.

*return (`boolean`):* whether or not the buffer is modifiable

### setKeymap(mode, lhs, rhs, opts)

Sets a buffer local keymap for the popup.

_parameters:_
- `string` mode: The vim mode the keymap applies to.
- `string` lhs: The keystring being mapped.
- `string` or `function` rhs: They keystring or callback to replace lhs with.
- `table` opts: See Neovim [Docs](https://neovim.io/doc/user/api.html#nvim_set_keymap()) (excluding callback field)


### getWidth()

Returns the width of the popup window.

*return (`integer`):* The width of the popup window.

### getHeight()

Returns the height of the popup window.

*return (`integer`):* The height of the popup window.
