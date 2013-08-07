local awful = require("awful")

theme = dofile("/usr/share/awesome/themes/zenburn/theme.lua")

theme.font      = "Ubuntu Mono 10"

theme.fg_normal = "#CCCCCC"
theme.fg_focus  = "#EEEEEE"
theme.bg_normal = "#222222"
theme.bg_focus  = "#444444"
theme.bg_urgent = "#CC0000"

theme.border_normal = "#000000"
theme.border_focus  = "#FCE94F"
theme.border_width  = "1"

theme.taglist_squares_sel   = awful.util.getdir("config") .. "/themes/zenburn-mod/taglist/squarefz.png"
theme.taglist_squares_unsel = awful.util.getdir("config") .. "/themes/zenburn-mod/taglist/squarez.png"

theme.menu_width  = 650

return theme
