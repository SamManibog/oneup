# Previewed Options Popup

A popup used to select from a set of elements called `PreviewedOptions`, providing a preview
for each option. Has two child popups, an options popup, and a preview popup (underlying regular popup).
Instantiated with PreviewedOptionsPopup:new(opts).

## PreviewedOptions

PreviewedOptions are tables with three important fields. They are used to hold data regarding an element and have
three special fields which are used internally.

### text

**Type:** `string`

The text to display on the option. New lines are not allowed (not enforced).

### is_title

**Type:** `boolean?`

If true, this option will serve as a separator for other given options. It cannot be selected via any
stock API.

### preview

**Type:** `string[]` or `Line[]` or `function(PreviewedOption) -> string[]` or `function(PreviewedOption) -> Line[]`

A function or "literal" value used to get the text to display on the preview window.

## Initialization Options

### preview_opts

Type: `table`

_fields:_
- `string?` title: the title to display on the preview popup.
- `AdvLength` or `length` width: the width of the preview popup.

A table describing basic settings for the preview window.

### options_opts

Type: `table`

_fields:_
- `string?` title: the title to display on the options popup.
- `AdvLength` or `length` width: the width of the options popup popup.

A table describing basic settings for the options window.

### options

**Type:** `PreviewedOptions[]`

A list of `PreviewedOptions` (see above section) listed by the menu.

### separator_align

**Type:** `Align` or `Integer` or `nil`

How to align the separator. Defaults to left.
If a non-negative integer, interpreted as the number of cells used as padding.
If a negative integer, interpreted as distance in cells from the right side of the screen popup window.

### border

**Type:** `boolean?`

Whether or not to display a border on the popup. Defaults to true.

### height

**Type:** `AdvLength` or `Length`

The height of the popup in relation the global height. If `nil`, autofits to the given text.

Note that if height is `nil`, the popup will only be autofit on creation and will
not change in size if the buffer is changed.

### persistent

**Type:** `boolean?`

Whether or not the popup window should close upon exiting/changing buffers.

### on_close

**Type:** `function?`

The function to run after the popup is closed.

### close_bind

**Type:** `string[]` or `string` or `nil`

The keybinding or list of keybinds used to close the popup.

### next_bind

**Type:** `string[]` or `string` or `nil`

The keybinding or list of keybinds used to select the next menu item.

### next_bind

**Type:** `string[]` or `string` or `nil`

The keybinding or list of keybinds used to select the previous menu item.

## Functions

### reloadPreview

Updates the preview to reflect the stored value.

### getOption()

Returns the currently selected option.

*return (`Option`):* The currently selected option.

### nextOption()

Iterates the selected option forward by 1.

### prevOption()

Iterates the selected option backward by 1.

### updateTitles()

An internal API used to recalculate and apply the padding for separator alignments.

### refreshText()

Makes the content of the popup reflect the stored options.

### close()

Closes the popup.

### resize()

Resizes the popup to account for a change in screen or popup dimension.
Note that this is called automatically and not intended for external use.

### getText()

Gets the text of the popup as an array of strings where each element is a new line.

*return (`string[]`):* The text of the popup.

### updateText()

Re-renders the text of the popup to its original value.

### winId()

Gets the window id of the popup.

*return (`integer`):* The window id of the popup.

### bufId()

Gets the buffer id of the popup.

*return (`integer`):* The buffer id of the popup.

### getModifiable()

Returns the whether or not the buffer is modifiable.

*return (`boolean`):* whether or not the buffer is modifiable

### setKeymap(mode, lhs, rhs, opts)

Sets a buffer local keymap for the popup.

_parameters:_
- `string` mode: The vim mode the keymap applies to.
- `string` lhs: The keystring being mapped.
- `string` or `function` rhs: They keystring or callback to replace lhs with.
- `table` opts: See [Neovim Docs](https://neovim.io/doc/user/api.html#nvim_set_keymap()) (excluding callback field)


### getWidth()

Returns the width of the popup window.

*return (`integer`):* The width of the popup window.

### getHeight()

Returns the height of the popup window.

*return (`integer`):* The height of the popup window.
