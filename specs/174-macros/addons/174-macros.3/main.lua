-- 174.3 — macros stand on the action bar. Self-checking suite.

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

local function manualCheck(step, expect)
  manual = manual + 1
  hafen.log():write("[manual] " .. step .. " -- expect: " .. expect)
end

local function message(err)
  return (tostring(err):gsub("^@?.-%.lua:%d+:?%s*", ""))
end

local NAME, RENAMED = "t174 bar", "t174 bar2"
local BODY = 'print("t174 pressed")'

local window
local finished = false
local base = 0          -- the System log's line count when the step was shown
local changed = {}      -- every ActionbarChanged since the run began: { index = n, res = res }
local dropped = nil     -- what the suite's own Drop widget was handed
local slot, id = nil, nil
local sub

local function finish()
  if finished then return end
  finished = true
  manualCheck("make a macro, drag it to a slot, log out to the character list and back in", "it stands in that slot")
  manualCheck("with that macro on its slot, type :reload", "it still stands in that slot")
  if window then pcall(function() window:destroy() end) end
  if sub then sub:off() end
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

local function system()
  local session = hafen.session():current()
  return session and session:chat():find(function(channel) return channel:kind() == "chat.system" end)
end

local function count()
  local log = system()
  return log and log:message():count() or 0
end

local function seen(want)
  local log = system()
  if not log then return nil end
  for i = base + 1, log:message():count() do
    local line = log:message():get(i)
    if line and line:raw() == want then return true end
  end
end

-- One step: what to do, and Done when it is done. The window hangs on the character's HUD: a drag ends in
-- the character's tree, so the square to drop on, under the text when the step asks for it, must stand there.
local function prompt(text, onDone, withSquare)
  if window then window:destroy() end
  base = count()
  local hud = hafen.session():current():ui():match("@GameUI")
  window = hafen.ui():window():parent(hud):title("174.3"):size(600, withSquare and 124 or 68):position(20, 80)
  local done = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  hafen.ui():label():parent(window):position(8, 40):text(text)
  if withSquare then
    local square = hafen.ui():widget():parent(window):position(8, 72):size(200, 44)
    hafen.ui():label():parent(square):position(60, 14):text("drop here")
    square:on("Draw", function(draw_event)
      local graphics = draw_event:g()
      graphics:color(255, 255, 255, 48)
      graphics:frect(0, 0, 200, 44)
      graphics:color()
      graphics:rect(0, 0, 200, 44)
    end)
    square:on("Drop", function(drop_event)
      dropped = drop_event:thing()
      drop_event:preventDefault()
    end)
  end
  done:on("Pressed", function() after(0, onDone) end)
end

local function page()
  local session = hafen.session():current()
  return session and session:ui():match("@MacroPanel")
end

-- Every slot of the bar on screen reading a macro's identity.
local function macroSlots()
  local out = {}
  for _, each in ipairs(hafen.session():current():actionbar():list()) do
    local res = each:res()
    if res and res:match("^macro/%d+$") then out[#out + 1] = each end
  end
  return out
end

local function changedFor(res, from)
  for i = from or 1, #changed do
    if changed[i].res == res then return true end
  end
  return false
end

local function deleted()
  local still = 0
  for _, each in ipairs(macroSlots()) do
    if each:res() == id then still = still + 1 end
  end
  check(still == 0, "after Delete and Yes no slot reads " .. tostring(id), still .. " slot(s)")
  finish()
end

local released
local function droppedOnWidget()
  -- Which half missed: the page's field, the stored list (Save), or the slot's read of it.
  local macroPanel = page()
  local field = macroPanel and macroPanel:match("@TextEntry")
  local stored = false
  for _, label in ipairs(macroPanel and macroPanel:matchAll("@MacroRow label") or {}) do
    if label:text() == RENAMED then stored = true end
  end
  check(slot:name() == RENAMED, "a rename on the page reaches the slot: name() '" .. RENAMED .. "'",
    tostring(slot:name()) .. " (field: " .. tostring(field and field:value()) .. ", a row reads it: "
    .. tostring(stored) .. ")")
  check(dropped ~= nil and dropped.kind == "pagina" and dropped.res == id,
    "a macro dropped on a widget reads { kind = 'pagina', res = '" .. tostring(id) .. "' }",
    dropped and (tostring(dropped.kind) .. " " .. tostring(dropped.res)) or "no Drop")
  slot:hold(nil)
  check(slot:res() ~= id, "slot:hold(nil) releases the macro: res() no longer " .. tostring(id), slot:res())
  released = #changed + 1
  prompt("Drag the icon onto a slot of the client's own bar again, then Delete, Yes. Then Done.", function()
    check(changedFor(id, released), "dragging it back fires ActionbarChanged naming " .. tostring(id),
      #changed - released + 1 .. " change(s), none of it")
    deleted()
  end)
end

local function pressed()
  check(seen("t174 pressed"), "the slot's key over the map runs the macro: 't174 pressed' in the System log",
    "no such line")
  local macroPanel = page()
  if not macroPanel then
    check(false, "the Macros page is open", "no @MacroPanel -- Ctrl+O, Macros")
    return finish()
  end
  macroPanel:match("@TextEntry"):value(RENAMED)
  prompt("The name now reads 't174 bar2': press Save FIRST, then drag the wrench onto 'drop here' below. Done.",
    droppedOnWidget, true)
end

local function placed()
  local named = {}
  for _, each in ipairs(macroSlots()) do
    if each:name() == NAME then named[#named + 1] = each end
  end
  check(#named == 1, "exactly one slot holds the macro: res() 'macro/<id>', name() '" .. NAME .. "'", #named)
  if #named ~= 1 then return finish() end
  slot, id = named[1], named[1]:res()
  check(not slot:empty() and slot:hold() == nil, "that slot is not empty() and its hold() is nil",
    tostring(slot:empty()) .. " " .. tostring(slot:hold()))
  check(changedFor(id), "ActionbarChanged named the slot as " .. id, #changed .. " change(s), none of it")
  local ok, err = pcall(slot.res, slot, id)
  err = ok and "<no error>" or message(err)
  check(not ok and err:find("Macros page", 1, true) ~= nil, "slot:res('" .. id .. "') is refused naming the Macros page",
    err)
  local position = (slot:index() - 1) % 12 + 1
  prompt("Close the menu. Pointer over the map, press the key of slot " .. slot:index() .. " (button " .. position
    .. "). Then Ctrl+O, Macros. Done.", function() after(1, pressed) end)
end

local function filled()
  local macroPanel = page()
  local name = macroPanel and macroPanel:match("@TextEntry")
  local editor = macroPanel and macroPanel:match("@CodeArea")
  if not (name and editor and name:value() == "New macro") then
    check(false, "the page shows a new macro", macroPanel and "not 'New macro'" or "no @MacroPanel -- Ctrl+O, Macros")
    return finish()
  end
  name:value(NAME)
  editor:value(BODY)
  prompt("Press Save, then drag the wrench onto a slot of the CLIENT'S OWN bar (no addon bar). Then Done.", placed)
end

local function run()
  finished, pass, fail, manual = false, 0, 0, 0
  changed, dropped, slot, id, released = {}, nil, nil, nil, nil
  if not hafen.session():current() or not system() then
    check(false, "a character is in the world, with its System log", "nil -- run :t174 logged in")
    return finish()
  end
  if sub then sub:off() end
  sub = hafen.event():on("ActionbarChanged", function(changed_slot)
    changed[#changed + 1] = { index = changed_slot:index(), res = changed_slot:res() }
  end)
  prompt("Ctrl+O, Macros, press New. Then Done.", filled)
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t174", function() after(0, run) end)
