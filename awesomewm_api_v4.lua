-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup").widget


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
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
                     title = "Oops, there were errors during startup!",
                     text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
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
-- Themes define colours, icons, font and wallpapers.
beautiful.init(awful.util.getdir("config") .. "/themes/zenburn-mod/theme.lua")

-- This is used later as the default terminal and editor to run.
terminal = "urxvt"
editor = os.getenv("EDITOR") or "vim"
editor_cmd = terminal .. " -e " .. editor

-- Default modkey.
-- Usually, Mod4 is the key with a logo between Control and Alt.
-- If you do not like this or do not have such a key,
-- I suggest you to remap Mod4 to another key using xmodmap or other tools.
-- However, you can use another modifier like Mod1, but it may interact with others.
modkey = "Mod4"

-- Variable to recognize when we are switching screens
lastScreen = 1

-- Table of layouts to cover with awful.layout.inc, order matters.
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

-- {{{ Helper functions
local function client_menu_toggle_fn()
    local instance = nil

    return function ()
        if instance and instance.wibox.visible then
            instance:hide()
            instance = nil
        else
            instance = awful.menu.clients({ theme = { width = 250 } })
        end
    end
end
-- }}}

-- {{{ Menu
-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- {{{ Wibar
-- Create a textclock widget
mytextclock = wibox.widget.textclock("%Y-%m-%dT%H:%M:%S%z", 1)

-- Create a wibox for each screen and add it
local taglist_buttons = awful.util.table.join(
                    awful.button({ }, 1, function(t) t:view_only() end),
                    awful.button({ modkey }, 1, function(t)
                                              if client.focus then
                                                  client.focus:move_to_tag(t)
                                              end
                                          end),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, function(t)
                                              if client.focus then
                                                  client.focus:toggle_tag(t)
                                              end
                                          end),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(t.screen) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(t.screen) end)
                )

local tasklist_buttons = awful.util.table.join(
                     awful.button({ }, 1, function (c)
                                              if c == client.focus then
                                                  c.minimized = true
                                              else
                                                  -- Without this, the following
                                                  -- :isvisible() makes no sense
                                                  c.minimized = false
                                                  if not c:isvisible() and c.first_tag then
                                                      c.first_tag:view_only()
                                                  end
                                                  -- This will also un-minimize
                                                  -- the client, if needed
                                                  client.focus = c
                                                  c:raise()
                                              end
                                          end),
                     awful.button({ }, 3, client_menu_toggle_fn()),
                     awful.button({ }, 4, function ()
                                              awful.client.focus.byidx(1)
                                          end),
                     awful.button({ }, 5, function ()
                                              awful.client.focus.byidx(-1)
                                          end))

local function set_wallpaper(s)
    local pattern = gears.color.create_solid_pattern(theme.bg_normal)
    gears.wallpaper.set(pattern)
end

-- Re-set wallpaper when a screen's geometry changes (e.g. different resolution)
screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
    -- Wallpaper
    set_wallpaper(s)

    -- Each screen has its own tag table.
    for i = 1, 9 do
      awful.tag.add(tostring(i), {
        layout             = awful.layout.layouts[1],
        gap_single_client  = false,
        gap                = 2,
        screen             = s
      })
    end

    -- Create a promptbox for each screen
    s.mypromptbox = awful.widget.prompt()
    -- Create a taglist widget
    s.mytaglist = awful.widget.taglist(s, awful.widget.taglist.filter.all, taglist_buttons)

    -- Create the wibox
    s.mywibox = awful.wibar({ position = "top", screen = s })

    -- Add widgets to the wibox
    s.mywibox:setup {
        layout = wibox.layout.align.horizontal,
        { -- Left widgets
            layout = wibox.layout.fixed.horizontal,
            s.mytaglist,
            s.mypromptbox,
        },
        { -- Middle widgets
          layout = wibox.layout.fixed.horizontal
        },
        { -- Right widgets
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
-- Rules to apply to new clients (through the "manage" signal).
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

    -- Add titlebars to normal clients and dialogs
    { rule_any = {type = { "normal", "dialog" }
      }, properties = { titlebars_enabled = false }
    },
    { rule = { class = "URxvt" },
      properties = { size_hints_honor = false } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup and
      not c.size_hints.user_position
      and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
client.connect_signal("request::titlebars", function(c)
    -- buttons for the titlebar
    local buttons = awful.util.table.join(
        awful.button({ }, 1, function()
            client.focus = c
            c:raise()
            awful.mouse.client.move(c)
        end),
        awful.button({ }, 3, function()
            client.focus = c
            c:raise()
            awful.mouse.client.resize(c)
        end)
    )

    awful.titlebar(c) : setup {
        { -- Left
            awful.titlebar.widget.iconwidget(c),
            buttons = buttons,
            layout  = wibox.layout.fixed.horizontal
        },
        { -- Middle
            { -- Title
                align  = "center",
                widget = awful.titlebar.widget.titlewidget(c)
            },
            buttons = buttons,
            layout  = wibox.layout.flex.horizontal
        },
        { -- Right
            awful.titlebar.widget.floatingbutton (c),
            awful.titlebar.widget.maximizedbutton(c),
            awful.titlebar.widget.stickybutton   (c),
            awful.titlebar.widget.ontopbutton    (c),
            awful.titlebar.widget.closebutton    (c),
            layout = wibox.layout.fixed.horizontal()
        },
        layout = wibox.layout.align.horizontal
    }
end)

-- Enable sloppy focus, so that focus follows mouse.
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
