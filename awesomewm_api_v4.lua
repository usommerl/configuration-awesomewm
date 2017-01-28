local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
local wibox = require("wibox")
local beautiful = require("beautiful")
local naughty = require("naughty")

-- {{{ Custom functions
function hideBordersIfNecessary(client)
   hideBordersIfMaximized(client)
   hideBordersIfOnlyOneClientVisible()
end

function hideBordersIfOnlyOneClientVisible()
  local visibleClients = awful.client.visible(mouse.screen)
  if #visibleClients == 1 then
      local client = visibleClients[1]
      hideBorders(client)
  end
end

function hideBordersIfMaximized(client)
  if client.maximized_vertical and client.maximized_horizontal then
      hideBorders(client)
  else
      client.border_color = theme.border_focus
  end
end

function hideBordersDelayed(client)
  local hideTimer = timer({ timeout = 0.5 })
  hideTimer:connect_signal("timeout",
    function()
      client.border_color = theme.border_normal
      hideTimer:stop()
    end)
  hideTimer:start()
end

function hideBorders(client)
  if lastScreen == client.screen then
      client.border_color = theme.border_normal
  else
      hideBordersDelayed(client)
  end
end

function menu_center_coords(numberOfMenuItems)
   local s_geometry = screen[mouse.screen].workarea
   local menu_height = numberOfMenuItems * theme.menu_height +  2 * theme.border_width
   local menu_x = (s_geometry.width - theme.menu_width) / 2 + s_geometry.x
   local menu_y = (s_geometry.height - menu_height ) / 2 + s_geometry.y - 100
   return {["x"] = menu_x, ["y"] = menu_y}
end

function minimized_clients_selector(clients)
  local menuItems = {}
  for _, c in pairs(clients) do
      table.insert(menuItems,
                   {c.name,
                    function()
                        if not client_tag_visible(c) then
                            awful.tag.viewonly(c:tags()[1])
                        end
                        client.focus = c
                        c:raise()
                        -- For a short period after client.focus the number
                        -- of visible clients is 0. Therefore the
                        -- hideBordersIfOnlyOneClientVisible()
                        -- method fails in this particular case.
                        if (#awful.client.visible(mouse.screen) == 0) then
                            hideBorders(c)
                        end
                    end
                   })
  end
  awful.menu(menuItems):show({coords = menu_center_coords(table_length(menuItems) - 1)})
end

function all_minimized_clients()
  local clients = {}
  for i, c in pairs(client.get(mouse.screen)) do
    if c.minimized then
      table.insert(clients,c)
    end
  end
  return clients
end

function client_tag_visible(client)
  for _, t1 in pairs(client:tags()) do
    for _, t2 in pairs(awful.tag.selectedlist(mouse.screen)) do
      if t1 == t2 then
        return true
      end
    end
  end
  return false
end

function show_all_minimized_clients()
  minimized_clients_selector(all_minimized_clients())
end

function show_minimized_clients_on_tag()
  local clients = {}
  for _, c in pairs(all_minimized_clients()) do
    if client_tag_visible(c) then
        table.insert(clients,c)
    end
  end
  minimized_clients_selector(clients)
end

function table_length(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
end

function run_prompt_execute_callback(command)
  if command:sub(1,1) == ":" then
    name,_  = command:sub(2):gsub("%s.*","")
    command = 'urxvt -name ' .. name .. ' -e zsh -i -c "' .. command:sub(2) .. '"'
  end
  awful.spawn(command)
end

function run_prompt_completion_callback(command, cur_pos, ncomp, shell)
  local term = false
  if command:sub(1,1) == ":" then
    term = true
    command = command:sub(2)
    cur_pos = cur_pos - 1
  end
  command, cur_pos =  awful.completion.shell(command, cur_pos, ncomp, shell)
  if term == true then
    command = ':' .. command
    cur_pos = cur_pos + 1
  end
  return command, cur_pos
end
-- }}}

-- {{{ Error handling
if awesome.startup_errors then
  naughty.notify({ preset = naughty.config.presets.critical,
                   title = "Oops, there were errors during startup!",
                   text = awesome.startup_errors })
end

do
  local in_error = false
  awesome.connect_signal("debug::error", function (err)
    if in_error then return end
    in_error = true

    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, an error happened!",
                     text = tostring(err) })
    in_error = false
  end)
end
-- }}}

-- {{{ Variable definitions
beautiful.init(awful.util.getdir("config") .. "/themes/zenburn-mod/theme.lua")
terminal = "urxvt"
modkey = "Mod4"
lastScreen = 1

awful.layout.layouts = {
  -- awful.layout.suit.floating,
  awful.layout.suit.tile,
  awful.layout.suit.tile.left,
  awful.layout.suit.tile.bottom,
  awful.layout.suit.tile.top,
  awful.layout.suit.fair,
  awful.layout.suit.fair.horizontal,
  -- awful.layout.suit.spiral,
  -- awful.layout.suit.spiral.dwindle,
  -- awful.layout.suit.max,
  -- awful.layout.suit.max.fullscreen,
  -- awful.layout.suit.magnifier,
  awful.layout.suit.corner.nw,
  -- awful.layout.suit.corner.ne,
  -- awful.layout.suit.corner.sw,
  -- awful.layout.suit.corner.se,
}
-- }}}

-- {{{ Wibar
mytextclock = wibox.widget.textclock("%Y-%m-%dT%H:%M:%S%z", 1)

local taglist_buttons = awful.util.table.join(
  awful.button({        }, 1, function(t) t:view_only() end),
  awful.button({ modkey }, 1, function(t)
                                if client.focus then
                                    client.focus:move_to_tag(t)
                                end
                              end),
  awful.button({        }, 3, awful.tag.viewtoggle),
  awful.button({ modkey }, 3, function(t)
                                if client.focus then
                                    client.focus:toggle_tag(t)
                                end
                              end),
  awful.button({        }, 4, function(t) awful.tag.viewnext(t.screen) end),
  awful.button({        }, 5, function(t) awful.tag.viewprev(t.screen) end)
)

local function set_wallpaper(s)
  local pattern = gears.color.create_solid_pattern(theme.bg_normal)
  gears.wallpaper.set(pattern)
end

screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
  set_wallpaper(s)

  awful.tag({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }, s, awful.layout.layouts[1])

  s.mypromptbox = awful.widget.prompt()
  s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons)
  s.mywibox = awful.wibar({ position = "top", screen = s })

  s.mywibox:setup {
      layout = wibox.layout.align.horizontal,
      {
        layout = wibox.layout.fixed.horizontal,
        s.mytaglist,
        s.mypromptbox,
      },
      {
        layout = wibox.layout.fixed.horizontal
      },
      {
        layout = wibox.layout.fixed.horizontal,
        wibox.widget.systray(),
        mytextclock,
      },
  }

  s.mywibox.visible = false
  s.mywibox.ontop = true
end)
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
  awful.button({ }, 4, awful.tag.viewnext),
  awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings
globalkeys = awful.util.table.join(
  awful.key({ modkey, "Control"              }, "r",          awesome.restart),
  awful.key({ modkey, "Shift"                }, "q",          awesome.quit),
  awful.key({ modkey,                        }, "Escape",     awful.tag.history.restore),
  awful.key({ modkey,                        }, "u",          awful.client.urgent.jumpto),
  awful.key({ modkey, "Control"              }, "n",          show_minimized_clients_on_tag),
  awful.key({ modkey, "Control", "Mod1"      }, "n",          show_all_minimized_clients),
  awful.key({ modkey,                        }, "Return",     function () awful.spawn(terminal)                                              end),
  awful.key({ modkey,                        }, "j",          function () awful.client.focus.byidx( 1)                                       end),
  awful.key({ modkey,                        }, "k",          function () awful.client.focus.byidx(-1)                                       end),
  awful.key({ modkey, "Shift"                }, "j",          function () awful.client.swap.byidx(  1)                                       end),
  awful.key({ modkey, "Shift"                }, "k",          function () awful.client.swap.byidx( -1)                                       end),
  awful.key({ modkey, "Control"              }, "j",          function () awful.screen.focus_relative( 1)                                    end),
  awful.key({ modkey, "Control"              }, "k",          function () awful.screen.focus_relative(-1)                                    end),
  awful.key({ modkey,                        }, "l",          function () awful.tag.incmwfact( 0.05)                                         end),
  awful.key({ modkey,                        }, "h",          function () awful.tag.incmwfact(-0.05)                                         end),
  awful.key({ modkey, "Shift"                }, "h",          function () awful.tag.incnmaster( 1, nil, true)                                end),
  awful.key({ modkey, "Shift"                }, "l",          function () awful.tag.incnmaster(-1, nil, true)                                end),
  awful.key({ modkey, "Control"              }, "h",          function () awful.tag.incncol( 1, nil, true)                                   end),
  awful.key({ modkey, "Control"              }, "l",          function () awful.tag.incncol(-1, nil, true)                                   end),
  awful.key({ modkey,                        }, "space",      function () awful.layout.inc( 1)                                               end),
  awful.key({ modkey, "Shift"                }, "space",      function () awful.layout.inc(-1)                                               end),
  awful.key({                                }, "#122",       function () awful.spawn.with_shell("amixer --quiet set Master 1%-")            end),
  awful.key({ modkey                         }, "-",          function () awful.spawn.with_shell("amixer --quiet set Master 1%-")            end),
  awful.key({                                }, "#123",       function () awful.spawn.with_shell("amixer --quiet set Master 1%+")            end),
  awful.key({ modkey                         }, "+",          function () awful.spawn.with_shell("amixer --quiet set Master 1%+")            end),
  awful.key({ modkey                         }, "b",          function () mouse.screen.mywibox.visible = not mouse.screen.mywibox.visible    end),
  awful.key({ modkey                         }, "F7",         function () awful.spawn.with_shell("sleep 1; xset s activate")                 end),
  awful.key({ modkey                         }, "Pause",      function () awful.spawn.with_shell("i3lock -c 000000")                         end),
  awful.key({ modkey                         }, "p",          function () awful.spawn.with_shell("ncmpcpp toggle")                           end),
  awful.key({ modkey, "Shift", "Control"     }, "s",          function () awful.spawn.with_shell("poweroff")                                 end),
  awful.key({ modkey,                        }, "r",          function ()
                                                                  local wiboxVisibleBeforeExecution = mouse.screen.mywibox.visible
                                                                  mouse.screen.mywibox.visible = true
                                                                  awful.prompt.run({prompt="┃"},
                                                                      mouse.screen.mypromptbox.widget,
                                                                      run_prompt_execute_callback,
                                                                      run_prompt_completion_callback,
                                                                      awful.util.getdir("cache") .. "/history",
                                                                      500,
                                                                      function () mouse.screen.mywibox.visible = wiboxVisibleBeforeExecution end,
                                                                      nil,
                                                                      nil
                                                                  )
                                                              end)
)

clientkeys = awful.util.table.join(
  awful.key({ modkey, "Control"              }, "space",      awful.client.floating.toggle),
  awful.key({ modkey, "Shift"                }, "c",          function (c) c:kill()                                                          end),
  awful.key({ modkey, "Control"              }, "Return",     function (c) c:swap(awful.client.getmaster())                                  end),
  awful.key({ modkey,                        }, "o",          function (c) c:move_to_screen()                                                end),
  awful.key({ modkey,                        }, "t",          function (c) c.ontop = not c.ontop                                             end),
  awful.key({ modkey,                        }, "n",          function (c) c.minimized = true                                                end),
  awful.key({ modkey,                        }, "m",          function (c)
                                                                  c.maximized = not c.maximized
                                                                  c:raise()
                                                              end),
  awful.key({ modkey,                        }, "f",          function (c)
                                                               c.fullscreen = not c.fullscreen
                                                               c:raise()
                                                              end)
)

for i = 1, 9 do
  globalkeys = awful.util.table.join(globalkeys,
      -- View tag only.
      awful.key({ modkey                     }, "#" .. i + 9, function ()
                                                                    local screen = awful.screen.focused()
                                                                    local tag = screen.tags[i]
                                                                    if tag then
                                                                       tag:view_only()
                                                                    end
                                                              end),
      -- Toggle tag display.
      awful.key({ modkey, "Control"          }, "#" .. i + 9, function ()
                                                                  local screen = awful.screen.focused()
                                                                  local tag = screen.tags[i]
                                                                  if tag then
                                                                     awful.tag.viewtoggle(tag)
                                                                  end
                                                              end),
      -- Move client to tag.
      awful.key({ modkey, "Shift"            }, "#" .. i + 9, function ()
                                                                  if client.focus then
                                                                      local tag = client.focus.screen.tags[i]
                                                                      if tag then
                                                                          client.focus:move_to_tag(tag)
                                                                      end
                                                                 end
                                                              end),
      -- Toggle tag on focused client.
      awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9, function ()
                                                                  if client.focus then
                                                                      local tag = client.focus.screen.tags[i]
                                                                      if tag then
                                                                          client.focus:toggle_tag(tag)
                                                                      end
                                                                  end
                                                              end)
  )
end

clientbuttons = awful.util.table.join(
  awful.button({                            }, 1,             function (c) client.focus = c; c:raise() end),
  awful.button({ modkey                     }, 1,             awful.mouse.client.move),
  awful.button({ modkey                     }, 3,             awful.mouse.client.resize)
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
  -- All clients will match this rule.
  { rule = { },
    properties = { border_width = beautiful.border_width,
                   border_color = beautiful.border_normal,
                   focus = awful.client.focus.filter,
                   raise = true,
                   keys = clientkeys,
                   buttons = clientbuttons,
                   screen = awful.screen.preferred,
                   placement = awful.placement.no_overlap+awful.placement.no_offscreen
   }
  },

  -- Floating clients.
  { rule_any = {
      instance = {
        "DTA",  -- Firefox addon DownThemAll.
        "copyq",  -- Includes session name in class.
      },
      class = {
        "Arandr",
        "Gpick",
        "Kruler",
        "MessageWin",  -- kalarm.
        "Sxiv",
        "Wpa_gui",
        "pinentry",
        "veromix",
        "xtightvncviewer"},

      name = {
        "Event Tester",  -- xev.
      },
      role = {
        "AlarmWindow",  -- Thunderbird's calendar.
        "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
      }
    }, properties = { floating = true }},

  { rule_any = {type = { "normal", "dialog" }
    }, properties = { titlebars_enabled = false }
  },
  { rule = { class = "URxvt" },
    properties = { size_hints_honor = false } },
}
-- }}}

-- {{{ Signals
client.connect_signal("manage", function (c)
  if awesome.startup and
    not c.size_hints.user_position and
    not c.size_hints.program_position then
      awful.placement.no_offscreen(c)
  end
end)

client.connect_signal("mouse::enter", function(c)
    if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
        and awful.client.focus.filter(c) then
        client.focus = c
    end
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)

client.connect_signal("focus", function(c)
                                  hideBordersIfNecessary(c)
                               end)
client.connect_signal("unfocus", function(c)
                                 lastScreen = c.screen
                                 c.border_color = beautiful.border_normal
                               end)
client.connect_signal("property::maximized_horizontal", function(c)
                                                          hideBordersIfNecessary(c)
                                                        end)
client.connect_signal("property::maximized_vertical", function(c)
                                                        hideBordersIfNecessary(c)
                                                      end)
-- }}}
