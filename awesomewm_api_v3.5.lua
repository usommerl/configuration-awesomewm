-- {{{ Import libraries
-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
awful.rules = require("awful.rules")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
-- vicious widgets
local vicious = require("vicious")
--- }}}

-- {{{ Custom functions

function debug(message)
   naughty.notify({ preset = naughty.config.presets.critical,
   title = "Debug",
   timeout = 10,
   text = tostring(message)})
end

function run_once(cmd)
  findme = cmd
  firstspace = cmd:find(" ")
  if firstspace then
    findme = cmd:sub(0, firstspace-1)
  end
  awful.util.spawn_with_shell("pgrep -u $USER -x " .. findme .. " > /dev/null || (" .. cmd .. ")")
end

-- starts a terminal in the current working directory
-- update the working directory in your zsh precmd hook
function startTerminal()
    local home = os.getenv("HOME")
    local file = io.open(home .. "/.urxvt/start_directory", "r")
    if file then
        local directory = file:read()
        if directory then
            awful.util.spawn(terminal .. " -cd " .. directory)
            return
        end
    end
    awful.util.spawn(terminal)
end

-- resets the terminal working directory at awesome startup
function resetTerminalStartDirectory()
    awful.util.spawn_with_shell("cat $HOME > $HOME/.urxvt/start_directory")
end

function logEffectivePowerConsumption(effectivePower)
   local file = io.open("/var/log/effective_power_consumption.log", "a")
   local date = os.date("%Y-%m-%dT%H:%M:%S%z", os.time())
   file:write(date .. "   " .. effectivePower .. "\n")
   file:close()
end

function tableLength(table)
  local count = 0
  for _ in pairs(table) do count = count + 1 end
  return count
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

function menu_center_coords(numberOfMenuItems)
   local s_geometry = screen[mouse.screen].workarea
   local menu_height = numberOfMenuItems * theme.menu_height +  2 * theme.border_width
   local menu_x = (s_geometry.width - theme.menu_width) / 2 + s_geometry.x
   local menu_y = (s_geometry.height - menu_height ) / 2 + s_geometry.y - 100
   return {["x"] = menu_x, ["y"] = menu_y}
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
    awful.menu(menuItems):show({coords = menu_center_coords(tableLength(menuItems) - 1)})
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

function run_prompt_execute_callback(command)
   if command:sub(1,1) == ":" then
      name,_  = command:sub(2):gsub("%s.*","")
      command = 'urxvt -name ' .. name .. ' -e zsh -i -c "' .. command:sub(2) .. '"'
   end
   awful.util.spawn(command)
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

function effectivePower()
    local rate
    local power_nowFile = io.open("/sys/class/power_supply/BAT0/power_now", "rb")
    if power_nowFile then
        rate = power_nowFile:read() / 10^6
        power_nowFile:close()
    else
        local current_nowFile = io.open("/sys/class/power_supply/BAT0/current_now", "rb")
        local voltage_nowFile = io.open("/sys/class/power_supply/BAT0/voltage_now", "rb")
        local current_now = current_nowFile:read()
        current_nowFile:close()
        local voltage_now = voltage_nowFile:read()
        voltage_nowFile:close()
        rate = (voltage_now * current_now) / 10^12
    end
    return rate
end

function table.val_to_str ( v )
  if "string" == type( v ) then
    v = string.gsub( v, "\n", "\\n" )
    if string.match( string.gsub(v,"[^'\"]",""), '^"+$' ) then
      return "'" .. v .. "'"
    end
    return '"' .. string.gsub(v,'"', '\\"' ) .. '"'
  else
    return "table" == type( v ) and table.tostring( v ) or
      tostring( v )
  end
end

function table.key_to_str ( k )
  if "string" == type( k ) and string.match( k, "^[_%a][_%a%d]*$" ) then
    return k
  else
    return "[" .. table.val_to_str( k ) .. "]"
  end
end

function table.tostring( tbl )
  local result, done = {}, {}
  for k, v in ipairs( tbl ) do
    table.insert( result, table.val_to_str( v ) )
    done[ k ] = true
  end
  for k, v in pairs( tbl ) do
    if not done[ k ] then
      table.insert( result,
        table.key_to_str( k ) .. "=" .. table.val_to_str( v ) )
    end
  end
  return "{" .. table.concat( result, "\n" ) .. "}"
end

math.round = function(number, precision)
    precision = precision or 0

    local decimal = string.find(tostring(number), ".", nil, true);

    if ( decimal ) then
        local power = 10 ^ precision;

        if ( number >= 0 ) then
            number = math.floor(number * power + 0.5) / power;
        else
            number = math.ceil(number * power - 0.5) / power;
        end

        -- convert number to string for formatting
        number = tostring(number);

        -- set cutoff
        local cutoff = number:sub(decimal + 1 + precision);

        -- delete everything after the cutoff
        number = number:gsub(cutoff, "");
    else
        -- number is an integer
        if ( precision > 0 ) then
            number = tostring(number);

            number = number .. ".";

            for i = 1,precision
            do
                number = number .. "0";
            end
        end
    end
    return number;
end

function isRGB(string)
    local matchShort = string.match(string, '#[a-zA-z0-9][a-zA-z0-9][a-zA-z0-9]')
    local matchLong = string.match(string, '#[a-zA-z0-9][a-zA-z0-9][a-zA-z0-9][a-zA-z0-9][a-zA-z0-9][a-zA-z0-9]')
    return ( matchShort ~= nil or matchLong ~= nil )
end

function setBorderColor(theme)
    local pipe = io.popen('appres URxvt')
    local result = pipe:read("*a")
    pipe:close()
    local bgColor = string.gsub(result, ".*\n%*background:%s*",""):gsub("%s*\n.*","")
    local cursorColor = string.gsub(result, ".*\nURxvt.cursorColor:%s*",""):gsub("%s*\n.*","")
    if string.match(cursorColor, '%d+') then
      cursorColor = string.gsub(result,".*\n%*color" .. cursorColor ..":%s*",""):gsub("%s*\n.*","")
    end
    if (isRGB(cursorColor)) then
        theme.border_focus = cursorColor
    end
    if (isRGB(bgColor)) then
        theme.border_normal = bgColor
    end
end
--- }}}

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
                         text = err })
        in_error = false
    end)
end
-- }}}

-- {{{ Variable definitions
-- Themes define colours, icons, and wallpapers
beautiful.init(awful.util.getdir("config") .. "/themes/zenburn-mod/theme.lua")
-- Reset border colors according to current URxvt colorscheme
setBorderColor(theme)

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
local layouts =
{
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
    -- awful.layout.suit.magnifier
}
-- }}}

-- {{{ Wallpaper
local pattern = gears.color.create_linear_pattern("0,0:0,1080:0.1,#000000:1.0,#505050")
gears.wallpaper.set(pattern)
-- }}}

-- {{{ Tags
-- Define a tag table which hold all screen tags.

function tagNames(numberOfTags)
   result = {}
   for i=1, numberOfTags do
     result[i] = i
   end
   return result
end

tags = {}
for s = 1, screen.count() do
    -- Each screen has its own tag table.
    tags[s] = awful.tag(tagNames(7), s, awful.layout.suit.tile)
end
-- }}}

-- {{{ Menu

-- Menubar configuration
menubar.utils.terminal = terminal -- Set the terminal for applications that require it
-- }}}

-- {{{ Wibox
-- Create a textclock widget
mytextclock = awful.widget.textclock("%Y-%m-%dT%H:%M:%S%z",1)

-- Create a wibox for each screen and add it
mywibox = {}
mypromptbox = {}
mytaglist = {}
mytaglist.buttons = awful.util.table.join(
                    awful.button({ }, 1, awful.tag.viewonly),
                    awful.button({ modkey }, 1, awful.client.movetotag),
                    awful.button({ }, 3, awful.tag.viewtoggle),
                    awful.button({ modkey }, 3, awful.client.toggletag),
                    awful.button({ }, 4, function(t) awful.tag.viewnext(awful.tag.getscreen(t)) end),
                    awful.button({ }, 5, function(t) awful.tag.viewprev(awful.tag.getscreen(t)) end)
                    )

-- Spacer
local spacer    = awful.widget.progressbar()
spacer:set_width(2)
spacer:set_background_color(theme.bg_normal)
spacer:set_border_color(nil)

local widthProgressBar = 7
local ticksSize = 1

-- Battery widget
function batteryWidgetFormatter(widget, data)
    if data[2] >= 40 and data[2] <= 100 then
        widget:set_color(theme.bg_focus)
    elseif data[2] >= 15 and data[2] < 40   then
        widget:set_color("#FFCC00")
    elseif data[2] >= 0  and data[2] < 15   then
        widget:set_color("#CC0000")
        if data[2] <= 3 and data[1] == "−" then
            local pipe = io.popen('echo -n $(acpi -b | sed "s/Battery 0: //")')
            local acpiResult = pipe:read("*a")
            pipe:close()
            naughty.notify({ preset = naughty.config.presets.critical,
            title = "Battery critical",
            timeout = 10,
            text =  acpiResult })
        end
    end

    if data[1] == "+" then
        widget:set_border_color("#004000")
    else
        widget:set_border_color(nil)
    end
    return data[2]
end


local batteryWidget = awful.widget.progressbar()
batteryWidget:set_width(widthProgressBar)
batteryWidget:set_ticks(true)
batteryWidget:set_ticks_size(ticksSize)
batteryWidget:set_vertical(true)
batteryWidget:set_background_color(theme.bg_normal)
batteryWidget:set_color(theme.bg_focus)
vicious.register(batteryWidget, vicious.widgets.bat, batteryWidgetFormatter , 60, "BAT0")

batteryWidgetTooltip = awful.tooltip({
    objects = { batteryWidget },
    timer_function =
        function()
            local pipe = io.popen('echo -n "$(acpi -a -b -i)"')
            local acpiResult = pipe:read("*a")
            pipe:close()
            if string.find(acpiResult,"Adapter 0: off") ~= nil then
                return "Battery 0: effective power consumption " .. math.round(effectivePower(), 1) .. " W\n" .. acpiResult
            end
            return acpiResult
        end,
})

-- Wifi widget
local wifiWidget = awful.widget.progressbar()
wifiWidget:set_width(widthProgressBar)
wifiWidget:set_ticks(true)
wifiWidget:set_ticks_size(ticksSize)
wifiWidget:set_vertical(true)
wifiWidget:set_background_color(theme.bg_normal)
wifiWidget:set_border_color(nil)
wifiWidget:set_color(theme.bg_focus)
vicious.register(wifiWidget, vicious.widgets.wifi, '${linp}', 15, "wlan0")

wifiWidgetTooltip = awful.tooltip({
    objects = { wifiWidget },
    timer_function =
        function()
            local pipe = io.popen('echo -n "$(connectionStatus.sh)"')
            local value = pipe:read("*a")
            pipe:close()
            return value
        end,
})

-- Thermal widget
function thermalWidgetFormatter(widget, data)
    local temperature = data[1]
    if temperature >= 60 and temperature < 80 then
      thermalWidget:set_color("#FFCC00")
    elseif temperature >= 80 then
      thermalWidget:set_color("#CCCC00")
    else
      thermalWidget:set_color(theme.bg_normal)
    end
    return 100
end

thermalWidget = awful.widget.progressbar()
thermalWidget:set_width(widthProgressBar)
thermalWidget:set_ticks(true)
thermalWidget:set_ticks_size(ticksSize)
thermalWidget:set_vertical(true)
thermalWidget:set_background_color(theme.bg_normal)
thermalWidget:set_border_color(nil)
thermalWidget:set_color(theme.bg_focus)
vicious.register(thermalWidget, vicious.widgets.thermal, thermalWidgetFormatter, 60, "thermal_zone0")

thermalWidgetTooltip = awful.tooltip({
    objects = { thermalWidget },
    timer_function =
        function()
            local pipe = io.popen('echo -n "$(sensors)"')
            local value = pipe:read("*a")
            pipe:close()
            return value
        end,
})

for s = 1, screen.count() do
    -- Create a promptbox for each screen
    mypromptbox[s] = awful.widget.prompt()
    -- Create a taglist widget
    mytaglist[s] = awful.widget.taglist(s, awful.widget.taglist.filter.all, mytaglist.buttons)

    -- Create the wibox
    mywibox[s] = awful.wibox({ position = "top", screen = s })

    -- Widgets that are aligned to the left
    local left_layout = wibox.layout.fixed.horizontal()
    left_layout:add(batteryWidget)
    left_layout:add(spacer)
    left_layout:add(wifiWidget)
    left_layout:add(spacer)
    left_layout:add(mytaglist[s])
    left_layout:add(mypromptbox[s])

    -- Widgets that are aligned to the right
    local right_layout = wibox.layout.fixed.horizontal()
    -- if s == 1 then right_layout:add(wibox.widget.systray()) end
    right_layout:add(thermalWidget)
    right_layout:add(spacer)
    right_layout:add(mytextclock)

    -- Now bring it all together (with the tasklist in the middle)
    local layout = wibox.layout.align.horizontal()
    layout:set_left(left_layout)
    -- layout:set_middle(mytasklist[s])
    layout:set_right(right_layout)

    mywibox[s]:set_widget(layout)
    -- hide wibox
    mywibox[s].visible = false
    mywibox[s].ontop = true
end
-- }}}

-- {{{ Mouse bindings
root.buttons(awful.util.table.join(
    awful.button({ }, 4, awful.tag.viewnext),
    awful.button({ }, 5, awful.tag.viewprev)
))
-- }}}

-- {{{ Key bindings

awful.menu.menu_keys.down = {"j", "Down"}
awful.menu.menu_keys.up   = {"k", "Up"}

globalkeys = awful.util.table.join(
    awful.key({ modkey,           }, "Escape", awful.tag.history.restore),
    awful.key({ modkey            }, "Pause",  function () awful.util.spawn_with_shell("i3lock -c 000000") end),
    awful.key({ modkey            }, "F7",  function () awful.util.spawn_with_shell("sleep 1;xset s activate") end),
    awful.key({},                    "#122",   function () awful.util.spawn_with_shell("amixer --quiet set Master 1%-") end),
    awful.key({ modkey},             "-",      function () awful.util.spawn_with_shell("amixer --quiet set Master 1%-") end),
    awful.key({},                    "#123",   function () awful.util.spawn_with_shell("amixer --quiet set Master 1%+") end),
    awful.key({ modkey},             "+",      function () awful.util.spawn_with_shell("amixer --quiet set Master 1%+") end),
    awful.key({ modkey            }, "p",      function () awful.util.spawn_with_shell("ncmpcpp toggle") end),
    awful.key({ modkey            }, "b",      function () mywibox[mouse.screen].visible = not mywibox[mouse.screen].visible end),
    awful.key({ modkey, "Shift", "Control" }, "s", function () awful.util.spawn_with_shell("poweroff") end),

    awful.key({ modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
            if client.focus then client.focus:raise() end
        end),
    awful.key({ modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
            if client.focus then client.focus:raise() end
        end),

    -- Layout manipulation
    awful.key({ modkey, "Shift"   }, "j", function () awful.client.swap.byidx(  1)    end),
    awful.key({ modkey, "Shift"   }, "k", function () awful.client.swap.byidx( -1)    end),
    awful.key({ modkey, "Control" }, "j", function () awful.screen.focus_relative( 1) end),
    awful.key({ modkey, "Control" }, "k", function () awful.screen.focus_relative(-1) end),
    awful.key({ modkey,           }, "u", awful.client.urgent.jumpto),
    awful.key({ modkey,           }, "Tab",
        function ()
            awful.client.focus.history.previous()
            if client.focus then
                client.focus:raise()
            end
        end),

    -- Dynamic tags 
    awful.key({ modkey, "Control" }, "a",
        function ()
            props = {selected = true, layout = awful.layout.suit.tile}
            index = #tags[mouse.screen]+1
            t = awful.tag.add(index, props)
            tags[mouse.screen][index]=t
            awful.tag.viewonly(t)
        end),
    awful.key({ modkey, "Control" }, "d",
        function ()
            t = awful.tag.selected(mouse.screen)
            if awful.tag.delete(t) then
                -- This will only work if tag names are numbers!
                table.remove(tags[mouse.screen], t.name)
                for i = t.name, #tags[mouse.screen] do
                    tags[mouse.screen][i].name = i
                end
            end
        end),

    -- Standard program
    awful.key({ modkey,           }, "Return", startTerminal),
    awful.key({ modkey, "Control" }, "r", awesome.restart),
    awful.key({ modkey, "Shift"   }, "q", awesome.quit),

    awful.key({ modkey,           }, "l",     function () awful.tag.incmwfact( 0.05)    end),
    awful.key({ modkey,           }, "h",     function () awful.tag.incmwfact(-0.05)    end),
    awful.key({ modkey, "Shift"   }, "h",     function () awful.tag.incnmaster( 1)      end),
    awful.key({ modkey, "Shift"   }, "l",     function () awful.tag.incnmaster(-1)      end),
    awful.key({ modkey, "Control" }, "h",     function () awful.tag.incncol( 1)         end),
    awful.key({ modkey, "Control" }, "l",     function () awful.tag.incncol(-1)         end),
    awful.key({ modkey,           }, "space", function () awful.layout.inc(layouts,  1) end),
    awful.key({ modkey, "Shift"   }, "space", function () awful.layout.inc(layouts, -1) end),

    awful.key({ modkey, "Control" }, "n", show_minimized_clients_on_tag),
    awful.key({ modkey, "Control", "Mod1" }, "n", show_all_minimized_clients),
    --awful.key({ modkey, "Control", "Shift" }, "n", awful.client.restore),

    -- Prompt
    awful.key({ modkey,           }, "r",
              function ()
                  local wiboxVisibleBeforeExecution = mywibox[mouse.screen].visible
                  mywibox[mouse.screen].visible = true
                  awful.prompt.run({prompt="┃"},
                      mypromptbox[mouse.screen].widget,
                      run_prompt_execute_callback,
                      run_prompt_completion_callback,
                      awful.util.getdir("cache") .. "/history",
                      500,
                      function () mywibox[mouse.screen].visible = wiboxVisibleBeforeExecution end,
                      nil,
                      nil
                  )
              end),

    awful.key({ modkey }, "x",
              function ()
                  local wiboxVisibleBeforeExecution = mywibox[mouse.screen].visible
                  mywibox[mouse.screen].visible = true
                  awful.prompt.run({ prompt = "Run Lua code:" },
                      mypromptbox[mouse.screen].widget,
                      awful.util.eval,
                      nil,
                      awful.util.getdir("cache") .. "/history_eval",
                      500,
                      function () mywibox[mouse.screen].visible = wiboxVisibleBeforeExecution end,
                      nil,
                      nil
                  )
              end)
)

clientkeys = awful.util.table.join(
    awful.key({ modkey,           }, "f",      function (c) c.fullscreen = not c.fullscreen  end),
    awful.key({ modkey, "Shift"   }, "c",      function (c) c:kill()                         end),
    awful.key({ modkey, "Control" }, "space",  awful.client.floating.toggle                     ),
    awful.key({ modkey, "Control" }, "Return", function (c) c:swap(awful.client.getmaster()) end),
    awful.key({ modkey,           }, "o",      awful.client.movetoscreen                        ),
    awful.key({ modkey,           }, "t",      function (c) c.ontop = not c.ontop            end),
    awful.key({ modkey,           }, "s",      function (c) c.sticky = not c.sticky          end),
    awful.key({ modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end),
    awful.key({ modkey,           }, "m",
        function (c)
            c.maximized_horizontal = not c.maximized_horizontal
            c.maximized_vertical   = not c.maximized_vertical
        end)
)

-- Bind all key numbers to tags.
-- Be careful: we use keycodes to make it works on any keyboard layout.
-- This should map on the top row of your keyboard, usually 1 to 9.
for i = 1, 9 do
    globalkeys = awful.util.table.join(globalkeys,
        awful.key({ modkey }, "#" .. i + 9,
                  function ()
                        local screen = mouse.screen
                        if tags[screen][i] then
                            awful.tag.viewonly(tags[screen][i])
                        end
                  end),
        awful.key({ modkey, "Control" }, "#" .. i + 9,
                  function ()
                      local screen = mouse.screen
                      if tags[screen][i] then
                          awful.tag.viewtoggle(tags[screen][i])
                      end
                  end),
        awful.key({ modkey, "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.movetotag(tags[client.focus.screen][i])
                      end
                  end),
        awful.key({ modkey, "Control", "Shift" }, "#" .. i + 9,
                  function ()
                      if client.focus and tags[client.focus.screen][i] then
                          awful.client.toggletag(tags[client.focus.screen][i])
                      end
                  end))
end

clientbuttons = awful.util.table.join(
    awful.button({ }, 1, function (c) client.focus = c; c:raise() end),
    awful.button({ modkey }, 1, awful.mouse.client.move),
    awful.button({ modkey }, 3, awful.mouse.client.resize))

-- Set keys
root.keys(globalkeys)
-- }}}

-- {{{ Rules
awful.rules.rules = {
    -- All clients will match this rule.
    { rule = { },
      properties = { border_width = beautiful.border_width,
                     border_color = beautiful.border_normal,
                     floating = false,
                     focus = awful.client.focus.filter,
                     keys = clientkeys,
                     buttons = clientbuttons } },
    { rule = { properties = { maximized_horizontal, maximized_vertical } },
      properties = { border_width = 0 } },
    { rule = { class = "URxvt" },
      properties = { size_hints_honor = false } },
    { rule = { class = "rdesktop" },
      properties = { size_hints_honor = false, floating = false } },
    { rule = { class = "Soffice" },
      properties = { floating = false } },
    { rule = { instance = "ncmpcpp", class = "URxvt" },
      properties = { tag = tags[1][4] } },
    { rule = { instance = "alsamixer", class = "URxvt" },
      properties = { tag = tags[1][4] } },
    { rule = { class = "Vlc" },
      properties = { tag = tags[1][4], switchtotag = true } },
    { rule = { class = "mpv" },
      properties = { tag = tags[1][4], switchtotag = true } },
    { rule = { class = "mplayer2" },
      properties = { tag = tags[1][4], switchtotag = true } },
    { rule = { class = "MPlayer" },
      properties = { tag = tags[1][4], switchtotag = true } },
    { rule = { instance = "weechat", class = "URxvt" },
      properties = { tag = tags[1][7], switchtotag = false } },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c, startup)
    -- Enable sloppy focus
    c:connect_signal("mouse::enter", function(c)
        if awful.layout.get(c.screen) ~= awful.layout.suit.magnifier
            and awful.client.focus.filter(c) then
            client.focus = c
        end
    end)

    if not startup then
        -- Set the windows at the slave,
        -- i.e. put it at the end of others instead of setting it master.
        -- awful.client.setslave(c)

        -- Put windows in a smart way, only if they does not set an initial position.
        if not c.size_hints.user_position and not c.size_hints.program_position then
            awful.placement.no_overlap(c)
            awful.placement.no_offscreen(c)
        end
    end

    local titlebars_enabled = false
    if titlebars_enabled and (c.type == "normal" or c.type == "dialog") then
        -- Widgets that are aligned to the left
        local left_layout = wibox.layout.fixed.horizontal()
        left_layout:add(awful.titlebar.widget.iconwidget(c))

        -- Widgets that are aligned to the right
        local right_layout = wibox.layout.fixed.horizontal()
        right_layout:add(awful.titlebar.widget.floatingbutton(c))
        right_layout:add(awful.titlebar.widget.maximizedbutton(c))
        right_layout:add(awful.titlebar.widget.stickybutton(c))
        right_layout:add(awful.titlebar.widget.ontopbutton(c))
        right_layout:add(awful.titlebar.widget.closebutton(c))

        -- The title goes in the middle
        local title = awful.titlebar.widget.titlewidget(c)
        title:buttons(awful.util.table.join(
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
                ))

        -- Now bring it all together
        local layout = wibox.layout.align.horizontal()
        layout:set_left(left_layout)
        layout:set_right(right_layout)
        layout:set_middle(title)

        awful.titlebar(c):set_widget(layout)
    end
end)

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

-- {{{ Timer
effectivePowerConsumptionTimer = timer({ timeout = 60 })
effectivePowerConsumptionTimer:connect_signal("timeout",
    function()
        local file = io.open("/sys/class/power_supply/AC/online", "rb")
        local acStatus = file:read()
        file:close()
        if acStatus == '0' then
            local effectivePower = effectivePower()
            logEffectivePowerConsumption(effectivePower)
            if effectivePower > 25 then
                naughty.notify({ preset = naughty.config.presets.critical,
                title = "effective power consumption critical",
                timeout = 3,
                text = math.round(effectivePower,1) .. " W" })
            end
        end
    end)
effectivePowerConsumptionTimer:start()
-- }}}

-- {{{ Autostart
awful.util.spawn_with_shell("xbacklight -set 80")
resetTerminalStartDirectory()
-- }}}
