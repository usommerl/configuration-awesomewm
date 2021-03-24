local awful = require("awful")

theme = dofile("/usr/share/awesome/themes/zenburn/theme.lua")

theme.font      = "JetBrains Mono 9"

theme.fg_normal = "#CCCCCC"
theme.fg_focus  = "#EEEEEE"
theme.bg_normal = "#222222"
theme.bg_focus  = "#444444"
theme.bg_urgent = "#CC0000"

theme.border_normal = "#000000"
theme.border_focus  = "#80a8dc"
theme.border_width  = "1"

theme.taglist_squares_sel   = awful.util.getdir("config") .. "/themes/zenburn-mod/taglist/squarefz.png"
theme.taglist_squares_unsel = awful.util.getdir("config") .. "/themes/zenburn-mod/taglist/squarez.png"

theme.menu_width  = 650
theme.tooltip_border_width = 0

return theme
