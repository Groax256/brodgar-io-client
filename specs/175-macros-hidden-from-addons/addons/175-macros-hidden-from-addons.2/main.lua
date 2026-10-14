-- 175.2 — a macro's identity is a token, and its name is no addon's. Self-checking suite.

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

-- A refusal naming both the rule and the string it was handed.
local function refusesNaming(what, fn, rule, named)
  local ok, err = pcall(fn)
  err = ok and "<no error>" or message(err)
  check((not ok) and err:find(rule, 1, true) ~= nil and err:find(named, 1, true) ~= nil, what, err)
end

local SIZE = 34
local WAIT = 3          -- seconds the ActionbarChanged fire is waited for

local window
local finished = false
local dropped = nil     -- the res the square's Drop was handed
local base = 0          -- the System log's length when the step was shown
local slot, changed, sub = nil, 0, nil

local function finish()
  if finished then return end
  finished = true
  if sub then sub:off(); sub = nil end
  if slot then pcall(function() slot:hold(nil) end) end
  manualCheck("look at the square after the drop, before Done", "the macro's wrench, drawn whole")
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

local function system()
  local session = hafen.session():current()
  return session and session:chat():find(function(channel) return channel:kind() == "chat.system" end)
end

-- Every System log line since the step was shown.
local function since()
  local log, lines = system(), {}
  if not log then return lines end
  for at = base + 1, log:message():count() do
    local line = log:message():get(at)
    lines[#lines + 1] = line and line:raw() or ""
  end
  return lines
end

-- Step 2: the slot is held from the token, and the refusals tell no miss from another.
local function settled()
  check(changed > 0, "ActionbarChanged fired for slot " .. slot:index() .. " as the macro took it", changed)
  refusesNaming("slot:hold('macro/1') raises 'no macro', naming macro/1",
    function() slot:hold("macro/1") end, "no macro", "macro/1")
  local zeros = "macro/" .. string.rep("0", 32)
  refusesNaming("slot:hold of a token no macro has raises 'no macro', naming it",
    function() slot:hold(zeros) end, "no macro", zeros)
  slot:hold(nil)
  check(slot:empty() and slot:res() == nil, "slot:hold(nil) gives slot " .. slot:index() .. " back empty",
    tostring(slot:empty()) .. " / " .. tostring(slot:res()))
  finish()
end

local function waitChanged(left)
  if changed > 0 or left <= 0 then return settled() end
  after(0.1, function() waitChanged(left - 0.1) end)
end

-- Step 1 is done: the square was handed the token, and Run has failed into the System log.
local function done()
  local res = dropped
  check(type(res) == "string" and res:match("^macro/%x+$") ~= nil and #res == 38 and not res:find("%u"),
    "the Drop's res is macro/ and 32 lowercase hex characters", res or "no Drop")
  local wanted = nil
  for _, line in ipairs(since()) do
    if line:match("^macro:%d+: .*t175") then wanted = line end
  end
  check(wanted ~= nil, "the System log reads 'macro:<line>: ...t175', with no name",
    #since() == 0 and "<no line>" or table.concat(since(), " | "))
  if not (type(res) == "string" and res:match("^macro/")) then return finish() end
  local session = hafen.session():current()
  slot = session:actionbar():find(function(candidate) return candidate:empty() end)
  if not slot then
    check(false, "the bar has an empty slot to hold", "all 144 occupied")
    return finish()
  end
  sub = hafen.event():on("ActionbarChanged", function(changedSlot)
    if changedSlot == slot then changed = changed + 1 end
  end)
  slot:hold(res)
  local info = slot:info()
  check(slot:res() == res and slot:name() == nil and info ~= nil and info.res == res and info.name == nil,
    "slot:hold(res) on slot " .. slot:index() .. ": res() is the token, name() and info().name are nil",
    tostring(slot:res()) .. " / " .. tostring(slot:name()) .. " / " .. tostring(info and info.name))
  waitChanged(WAIT)
end

-- The step: what to do, the square to drop on, and Done. The window hangs on the character's HUD: a drag ends
-- in the character's tree, so the square must stand there. Its Draw draws the token it was handed.
local function prompt()
  if window then window:destroy() end
  local log = system()
  base = log and log:message():count() or 0
  local hud = hafen.session():current():ui():match("@GameUI")
  window = hafen.ui():window():parent(hud):title("175.2"):size(640, 136):position(20, 80)
  local doneButton = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  hafen.ui():label():parent(window):position(8, 40)
    :text("Ctrl+O, Macros, New. Body: error(\"t175\"). Drag its icon onto the square, then press Run.")
  hafen.ui():label():parent(window):position(8, 60)
    :text("Look at the square: it draws the macro's icon. Then Done.")
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
  doneButton:on("Pressed", function() after(0, done) end)
end

local function run()
  finished, pass, fail, manual = false, 0, 0, 0
  dropped, slot, changed = nil, nil, 0
  if not hafen.session():current() or not system() then
    check(false, "a character is in the world, with a System log", "nil -- run :t175 logged in")
    return finish()
  end
  prompt()
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t175", function() after(0, run) end)
