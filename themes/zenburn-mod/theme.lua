theme = dofile("/usr/share/awesome/themes/zenburn/theme.lua")

theme.font      = "Ubuntu Mono 10"

theme.fg_normal = "#CCCCCC"
theme.fg_focus  = "#EEEEEE"
theme.bg_normal = "#222222"
theme.bg_focus  = "#444444"

theme.border_width  = "1"

for line in io.lines("/home/uwe/.config/awesome/themes/borderNormal.gen") do
    theme.border_normal = line
end

for line in io.lines("/home/uwe/.config/awesome/themes/borderFocus.gen") do
    theme.border_focus = line
end

-- Simply use the files from zenburn and desaturate the colors
theme.taglist_squares_sel   = "/home/uwe/.config/awesome/themes/zenburn-mod/taglist/squarefz.png"
theme.taglist_squares_unsel = "/home/uwe/.config/awesome/themes/zenburn-mod/taglist/squarez.png"

return theme
