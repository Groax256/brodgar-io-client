-- 175.1 — the Macros page does not exist for addons. Self-checking suite.

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

-- The two hotkeys, declared at load as a hotkey must be. Their keys are assigned for the run and put back.
local keybindings = hafen.client():options():keybindings()
local fires = { f9 = 0, j = 0 }
keybindings:on("t175-f9", function() fires.f9 = fires.f9 + 1 end)
keybindings:on("t175-j", function() fires.j = fires.j + 1 end)
local f9Binding = keybindings:binding():get("t175-f9")
local jBinding = keybindings:binding():get("t175-j")

local SELECTORS = { "@MacroPanel", "@MacroRow", "@CodeArea", "window[title=Delete macro]" }
local NAME = "New macro"

local window, sampler
local subs = {}
local saved = {}
local finished = false
local seen                       -- what the polls saw while the page was up

local function restoreKeys()
  for _, entry in ipairs(saved) do
    pcall(function() entry.binding:key(entry.key) end)   -- a nil key is the client's default: unbound
  end
  saved = {}
end

local function finish()
  if finished then return end
  finished = true
  if sampler then sampler:off(); sampler = nil end
  for _, sub in ipairs(subs) do sub:off() end
  subs = {}
  restoreKeys()
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

-- One step: what to do, and Done when it is done.
local function prompt(lines, onDone)
  if window then window:destroy() end
  window = hafen.ui():window():title("175.1"):size(620, 48 + 20 * #lines):position(20, 80)
  local done = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  for at, line in ipairs(lines) do
    hafen.ui():label():parent(window):position(8, 20 + 20 * at):text(line)
  end
  done:on("Pressed", function() after(0, onDone) end)
end

local function optionsWindow(session)
  return session:ui():matchAll("@OptWnd")[1]
end

-- Every widget the Options window's walk reaches, and whether a Label among them reads the macro's name.
local function walkOptions(options)
  local count, named = 0, false
  options:walk(function(node)
    count = count + 1
    if node:type() == "Label" and node:text() == NAME then named = true end
  end)
  return count, named
end

local function poll(session)
  seen.frames = seen.frames + 1
  for _, selector in ipairs(SELECTORS) do
    local found = #session:ui():matchAll(selector)
    seen.matched[selector] = math.max(seen.matched[selector], found)
  end
  seen.down = seen.down or jBinding:down()
  local options = optionsWindow(session)
  if options and seen.frames % 10 == 0 then
    local count, named = walkOptions(options)
    if seen.baseline == nil then seen.baseline = count end
    seen.walked = math.max(seen.walked, count)
    seen.named = seen.named or named
  end
end

-- Step 2: the control, with the menu closed.
local function controlled()
  sampler:off(); sampler = nil
  check(fires.f9 == 1, "control: F9 with the menu closed fires the hotkey once (1)", fires.f9)
  check(seen.down, "control: binding:down() on J reads true while J is held over the map", seen.down)
  finish()
end

-- Step 1 is done: the page is still up, and the window's centre is over it.
local function paged()
  local session = hafen.session():current()
  sampler:off(); sampler = nil
  for _, selector in ipairs(SELECTORS) do
    check(seen.matched[selector] == 0, ("%s matched nothing on %d frames"):format(selector, seen.frames),
      seen.matched[selector])
  end
  check(not seen.named, "no Label in the Options window's walk reads '" .. NAME .. "'", seen.named)
  check(seen.baseline ~= nil and seen.walked <= seen.baseline,
    "the Options window's walk reaches no more widgets than before the page opened (" .. tostring(seen.baseline) .. ")",
    seen.walked)
  local options = optionsWindow(session)
  local hit, tip = "<no Options window>", "<no Options window>"
  if options and options:visible() then
    local at, frame = options:rootPos(), options:chrome().frame
    local x, y = math.floor(at.x + frame.w / 2), math.floor(at.y + frame.h / 2)
    hit, tip = hafen.ui():hit(x, y), hafen.ui():tipAt(x, y)
  end
  check(options ~= nil and hit == options and tip == nil,
    "over the page, hit() is the Options window and tipAt() is nil", tostring(hit) .. " / " .. tostring(tip))
  check(seen.watched == 0, "the selector watches on the page and its question never fired", seen.watched)
  check(fires.f9 == 0 and fires.j == 0, "no hotkey of the suite fired while the page held the focus (F9 0, J 0)",
    "F9 " .. fires.f9 .. ", J " .. fires.j)
  check(not seen.down, "binding:down() on J never read true while the page held the focus", seen.down)
  fires.f9, fires.j, seen.down = 0, 0, false
  sampler = hafen.event():on("Update", guarded(function() seen.down = seen.down or jBinding:down() end))
  prompt({
    "Close the Options window. With the pointer over the map, press F9 once,",
    "then hold J for a second. Then Done.",
  }, controlled)
end

local function assign(binding, key)
  saved[#saved + 1] = { binding = binding, key = binding:assigned() and (binding:key() or "None") or nil }
  binding:key(key)
end

-- A key the user assigned to anything else would lose it for good: refuse rather than take it.
local function taken(key, mine)
  for _, binding in ipairs(keybindings:binding():list()) do
    if binding ~= mine and binding:assigned() and binding:key() == key then return binding:id() end
  end
end

local function run()
  finished, pass, fail, manual = false, 0, 0, 0
  fires.f9, fires.j = 0, 0
  local session = hafen.session():current()
  if not session then
    check(false, "a character is in the world", "nil -- run :t175 logged in")
    return finish()
  end
  local clash = taken("F9", f9Binding) or taken("J", jBinding)
  if clash then
    check(false, "F9 and J are free to assign for the run", clash .. " holds one: unbind it, or rerun later")
    return finish()
  end
  assign(f9Binding, "F9")
  assign(jBinding, "J")
  seen = { frames = 0, matched = {}, walked = 0, watched = 0, down = false }
  for _, selector in ipairs(SELECTORS) do seen.matched[selector] = 0 end
  local options = optionsWindow(session)
  if options then seen.baseline = walkOptions(options) end
  local function watched() seen.watched = seen.watched + 1 end
  for _, selector in ipairs({ "@MacroPanel", "window[title=Delete macro]" }) do
    subs[#subs + 1] = session:ui():on(selector, "Added", watched)
    subs[#subs + 1] = session:ui():on(selector, "Removed", watched)
  end
  sampler = hafen.event():on("Update", guarded(function() poll(session) end))
  prompt({
    "Ctrl+O, Macros, New. Click into the code editor. Hold J for a second, then press F9.",
    "Press Delete, then Yes in the window that asks. Leave the Macros page open,",
    "the Options window where it opened, and press Done.",
  }, paged)
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t175", function() after(0, run) end)
