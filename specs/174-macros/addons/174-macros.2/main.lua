-- 174.2 — a macro runs like :lua. Self-checking suite.

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

local NAME = "t174 two"
local RUN = table.concat({
  'print("t174 seed " .. tostring(t174_seed))',
  'print("t174 slot " .. tostring(hafen.session():current():actionbar():get(1):empty()))',
  'hafen.ui():window():title("T174Macro"):size(240, 60):position(20, 360)',
  'print("t174 window")',
  'return 5',
}, "\n")
local BOOM = 'local x = 1\nerror("boom")'

local window
local finished = false
local base = 0          -- the System log's line count when the step was shown

local function finish()
  if finished then return end
  finished = true
  manualCheck("type :reload", "the window titled 'T174Macro' is gone")
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

local function count()
  local log = system()
  return log and log:message():count() or 0
end

-- Every System log line since the step was shown.
local function since()
  local log, lines = system(), {}
  if not log then return lines end
  for i = base + 1, log:message():count() do
    local line = log:message():get(i)
    lines[#lines + 1] = line and line:raw() or ""
  end
  return lines
end

local function seen(want)
  for _, line in ipairs(since()) do
    if line == want then return line end
  end
end

local function shown()
  local lines = since()
  return #lines == 0 and "<no line>" or table.concat(lines, " | ")
end

-- One step: what to do, and Done when it is done. The System log is read from here on.
local function prompt(text, onDone)
  if window then window:destroy() end
  base = count()
  window = hafen.ui():window():title("174.2"):size(560, 68):position(20, 80)
  local done = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  hafen.ui():label():parent(window):position(8, 40):text(text)
  done:on("Pressed", function() after(0, onDone) end)
end

local function page()
  local session = hafen.session():current()
  return session and session:ui():match("@MacroPanel")
end

local function hasRow(macroPanel, name)
  for _, label in ipairs(macroPanel:matchAll("@MacroRow label")) do
    if label:text() == name then return true end
  end
  return false
end

local function deleted()
  local macroPanel = page()
  check(macroPanel ~= nil and not hasRow(macroPanel, NAME), "after Delete and Yes no row reads '" .. NAME .. "'",
    macroPanel and "a row still reads it" or "no @MacroPanel open")
  finish()
end

local function failed()
  local want = "macro:" .. NAME .. ":2: boom"
  check(seen(want) ~= nil, "an error reads '" .. want .. "' in the System log, alone on its line", shown())
  local macroPanel = page()
  check(macroPanel ~= nil and hasRow(macroPanel, NAME), "Run saved the macro first: a row reads '" .. NAME .. "'",
    macroPanel and "no such row" or "no @MacroPanel open")
  prompt("Press Delete, then Yes in the window that asks. Leave 'T174Macro' up. Then Done.", deleted)
end

local function ran()
  check(seen("t174 seed 7") ~= nil, "a macro reads the :lua console's globals, printing where :lua does", shown())
  check(seen("t174 slot true") or seen("t174 slot false"), "a macro reaches the verbs an addon calls", shown())
  check(seen("t174 window") ~= nil, "a macro run from Run builds a window of the addon layer", shown())
  local value
  for _, line in ipairs(since()) do
    if line:find("lua=", 1, true) then value = line end
  end
  check(value == nil, "a macro's value is not shown: no lua= line within 2 s", value)
  page():match("@CodeArea"):value(BOOM)
  prompt("Press Run once more. Then Done.", failed)
end

local function filled()
  local macroPanel = page()
  local name = macroPanel and macroPanel:match("@TextEntry")
  local editor = macroPanel and macroPanel:match("@CodeArea")
  local fresh = name ~= nil and editor ~= nil and name:value() == "New macro" and editor:value() == ""
  check(fresh, "the page shows a new macro: 'New macro', empty body",
    macroPanel and (name and name:value() or "no name field") or "no @MacroPanel -- Ctrl+O, Macros")
  if not fresh then return finish() end
  hafen.session():current():console():run("lua t174_seed = 7")
  name:value(NAME)
  editor:value(RUN)
  check(editor:value() == RUN and editor:text() == RUN, "the editor holds what :value(v) wrote, read by :value()",
    tostring(editor:value()):gsub("\n", "\\n"))
  local ok, err = pcall(editor.value, editor, string.rep("x", 65537))
  err = ok and "<no error>" or message(err)
  check(not ok and err:find("at most 65536", 1, true) ~= nil, "a body past 65536 characters is refused, saying so",
    err)
  prompt("Press Run. Then Done.", function() after(2, ran) end)
end

local function run()
  finished, pass, fail, manual = false, 0, 0, 0
  if not hafen.session():current() or not system() then
    check(false, "a character is in the world, with its System log", "nil -- run :t174 logged in")
    return finish()
  end
  prompt("Ctrl+O, Macros, press New. Then Done.", filled)
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t174", function() after(0, run) end)
