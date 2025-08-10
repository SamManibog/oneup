# Oneup

Oneup is a simple popup gui library that originated from within my Neovim config.

## Usage

```lua
-- Include the module needed for your desired popup type
local Line = require("oneup.line") -- More advanced buffer lines (also see text module)
local Popup = require("oneup.popup")

-- Create popups (of any kind) using the new function
Popup:new(
    -- Specify popup options
    {
        title = "Welcome",
        text = { -- Provide text as either a list of strings or Lines
            Line("Welcome to Oneup!", { align = "center", hl_group = "Title" }),
            "",
            "    Please see module README files for more",
            "advanced documentation. Also see StructTypes.md for",
            "documentation of the struct-like tables used in this",
            "plugin.",
            "",
            Line("- Sam", { align = "right" }),
        },
        width = { -- An AdvLength table see StructTypes.md for more info
            min = 50,       -- Minimum 50 columns wide
            max = 70,       -- Maximum 70 columns wide
            value = "40%",  -- 60% of global screen width
        },
        height = 8, -- Exactly 8 lines tall
        persistent = true, -- Keep popup open when focus is lost
        close_bind = { "<C-c>", "q" } -- Bindings to close the popup
    },

    -- Pass true or nil to mount the popup upon creation
    true
)
```

*See module README.md files and StructTypes.md for more advanced documentation*
