-- 175.3 — running a macro needs the player's press on your addon. Self-checking suite.

local pass, fail, manual = 0, 0, 0

local function check(ok, what, got)
  if ok then
    pass = pass + 1
    hafen.log():write("[pass] " .. what)
  else
    fail = fail + 1
    hafen.log():write("[fail] " .. what .. " -- got: " .. tostring(got))
  end
end

local function message(err)
  return (tostring(err):gsub("^@?.-%.lua:%d+:?%s*", ""))
end

-- One slot:use(), caught: { ok = true } or { ok = false, err = <the message> }.
local function use(slot)
  local ok, err = pcall(function() slot:use() end)
  return { ok = ok, err = ok and "<no error>" or message(err) }
end

-- Did the call fail, saying `rule`?
local function refused(result, rule)
  return result ~= nil and not result.ok and result.err:find(rule, 1, true) ~= nil
end

local function said(result)
  return result and result.err or "<not called>"
end

local NO_PRESS = "only inside the player's press"
local SPENT = "one press runs one"
local SIZE = 34
local WAIT = 3          -- seconds a macro's run is waited for: from a handler, it runs at the next step

local window
local finished = false
local dropped = nil     -- the token the square's Drop was handed
local base = 0          -- the System log's length when the press step was shown
local actionbar, firstPage = nil, nil
local macroSlot, entrySlot, entry = nil, nil, nil
local entryPressed = 0
local mapSub = nil
local mapResult, pressResult = nil, nil

local function system()
  local session = hafen.session():current()
  return session and session:chat():find(function(channel) return channel:kind() == "chat.system" end)
end

-- How many System log lines since the press step read exactly "t175 ran": one per run of the macro.
local function runs()
  local log, count = system(), 0
  if not log then return 0 end
  for at = base + 1, log:message():count() do
    local line = log:message():get(at)
    if line and line:raw():match("^%s*t175 ran%s*$") then count = count + 1 end
  end
  return count
end

local function finish()
  if finished then return end
  finished = true
  if mapSub then pcall(function() mapSub:off() end); mapSub = nil end
  if macroSlot or entrySlot then
    local ok, err = pcall(function()
      if macroSlot then macroSlot:hold(nil) end
      if entrySlot then entrySlot:hold(nil) end
    end)
    check(ok and (not macroSlot or macroSlot:empty()) and (not entrySlot or entrySlot:empty()),
      "slot:hold(nil) gives both slots back empty", ok and "a slot still occupied" or message(err))
  end
  if entry then pcall(function() hafen.session():current():menugrid():remove(entry) end) end
  if actionbar and firstPage then pcall(function() actionbar:page(firstPage) end) end
  if window then pcall(function() window:destroy() end) end
  hafen.log():write(("[summary] %d pass, %d fail, %d manual"):format(pass, fail, manual))
end

local function guarded(fn)
  return function(...)
    local ok, err = pcall(fn, ...)
    if not ok then
      check(false, "the suite ran to its end", message(err))
      finish()
    end
  end
end

local function after(seconds, fn)
  hafen.timer():after(seconds, guarded(fn))
end

-- Poll `ready` every 0.1 s for at most `left` seconds, then go on with `next`.
local function waitFor(ready, left, next)
  if ready() or left <= 0 then return next() end
  after(0.1, function() waitFor(ready, left - 0.1, next) end)
end

-- One step's window, on the character's HUD: its lines, a Done button, and room below for more.
local function stepWindow(title, height, lines, onDone)
  if window then window:destroy() end
  local hud = hafen.session():current():ui():match("@GameUI")
  window = hafen.ui():window():parent(hud):title(title):size(640, height):position(20, 80)
  local doneButton = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  for at, text in ipairs(lines) do
    hafen.ui():label():parent(window):position(8, 20 + at * 20):text(text)
  end
  doneButton:on("Pressed", function() after(0, onDone) end)
  return window
end

-- Step 3 is done: the slot's own key on the bar ran the macro a second time.
local function keyed()
  waitFor(function() return runs() >= 2 end, WAIT, function()
    check(runs() == 2, "the slot's own key on the bar ran the macro: a second 't175 ran'", runs())
    finish()
  end)
end

-- Step 3: the player's own key on the client's bar, which no addon's press stands behind.
local function promptKey()
  local index = macroSlot:index()
  local page, button = math.floor((index - 1) / 12) + 1, ((index - 1) % 12) + 1
  actionbar:page(page)
  stepWindow("175.3 (3/3)", 96, {
    "Press the action bar's key for button " .. button .. " (page " .. page .. " is up): the macro's slot.",
    "Then Done.",
  }, keyed)
end

-- Step 2 is done: the map click was refused, the Press button ran one macro and refused the second.
local function pressed()
  if mapSub then mapSub:off(); mapSub = nil end
  check(refused(mapResult, NO_PRESS),
    "slot:use() in a MouseDown handler on @MapView raises '" .. NO_PRESS .. "'", said(mapResult))
  check(pressResult ~= nil and pressResult.first.ok,
    "in the Press button's handler, the first slot:use() runs", pressResult and said(pressResult.first))
  check(pressResult ~= nil and refused(pressResult.second, SPENT),
    "in the same handler, the second slot:use() raises '" .. SPENT .. "'", pressResult and said(pressResult.second))
  waitFor(function() return runs() >= 1 end, WAIT, function()
    check(runs() == 1, "within " .. WAIT .. " s the System log holds exactly one 't175 ran'", runs())
    promptKey()
  end)
end

-- Step 2: a click on the world, which is no press on this addon, then the Press button, which is.
local function promptPress()
  local log = system()
  base = log and log:message():count() or 0
  local session = hafen.session():current()
  mapSub = session:ui():match("@MapView"):on("MouseDown", function()
    if not mapResult then mapResult = use(macroSlot) end
  end)
  stepWindow("175.3 (2/3)", 152, {
    "1. Click once on the ground.",
    "2. Press the Press button below, once.",
    "3. Done.",
  }, pressed)
  local pressButton = hafen.ui():button():parent(window):position(8, 108):size(100):text("Press")
  pressButton:on("Pressed", function()
    if pressResult then return end
    local first = use(macroSlot)
    pressResult = { first = first, second = use(macroSlot) }
  end)
end

-- Step 1 is done: hold the macro, refuse it from a timer, and run the suite's own entry from one.
local function held()
  check(type(dropped) == "string" and dropped:match("^macro/%x+$") ~= nil,
    "the square was handed a macro's token", dropped or "no Drop")
  if not (type(dropped) == "string" and dropped:match("^macro/")) then return finish() end
  local session = hafen.session():current()
  actionbar = session:actionbar()
  firstPage = actionbar:page()
  macroSlot = actionbar:find(function(candidate) return candidate:empty() end)
  if not macroSlot then
    check(false, "the bar has two empty slots to hold", "all 144 occupied")
    return finish()
  end
  macroSlot:hold(dropped)
  local fromTimer = use(macroSlot)
  check(refused(fromTimer, NO_PRESS),
    "slot:use() on the macro's slot from a timer raises '" .. NO_PRESS .. "'", said(fromTimer))
  entry = session:menugrid():add("t175"):name("175.3")
  entry:on("Pressed", function() entryPressed = entryPressed + 1 end)
  entrySlot = actionbar:find(function(candidate) return candidate:empty() end)
  if not entrySlot then
    check(false, "the bar has two empty slots to hold", "only one empty")
    return finish()
  end
  entrySlot:hold(entry)
  local entryUse = use(entrySlot)
  waitFor(function() return entryPressed > 0 end, 1, function()
    check(entryUse.ok and entryPressed == 1,
      "slot:use() on the entry's slot from a timer runs, and fires its Pressed once",
      said(entryUse) .. ", Pressed x" .. entryPressed)
    promptPress()
  end)
end

-- Step 1: the macro, made by hand and dragged onto the square.
local function prompt()
  stepWindow("175.3 (1/3)", 136, {
    "Ctrl+O, Macros, New. Body: print(\"t175 ran\"). Do not press Run.",
    "Drag its icon onto the square, close the Options window, then Done.",
  }, held)
  local square = hafen.ui():widget():parent(window):position(8, 88):size(SIZE, SIZE)
  hafen.ui():label():parent(window):position(SIZE + 16, 96):text("<- drop the macro here")
  square:on("Draw", function(draw_event)
    local graphics = draw_event:g()
    graphics:color(255, 255, 255, 48)
    graphics:frect(0, 0, SIZE, SIZE)
    graphics:color()
    graphics:rect(0, 0, SIZE, SIZE)
    if dropped then graphics:resource(dropped, 1, 1, SIZE - 2, SIZE - 2) end
  end)
  square:on("Drop", function(drop_event)
    local thing = drop_event:thing()
    drop_event:preventDefault()
    dropped = thing and thing.res
  end)
end

local function run()
  finished, pass, fail, manual = false, 0, 0, 0
  dropped, base, actionbar, firstPage = nil, 0, nil, nil
  macroSlot, entrySlot, entry, entryPressed = nil, nil, nil, 0
  mapSub, mapResult, pressResult = nil, nil, nil
  local session = hafen.session():current()
  if not session or not system() then
    check(false, "a character is in the world, with a System log", "nil -- run :t175 logged in")
    return finish()
  end
  pcall(function() session:menugrid():remove("t175") end)   -- a run cut short left its entry: inert if gone
  prompt()
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t175", function() after(0, run) end)
