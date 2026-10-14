-- 174.1 — the Macros page keeps the player's macros. Self-checking suite.

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

local NAME = "t174 one"
local BODY = { "-- t174 one", "local count = 1", "count = count + 1" }
local BODY_TEXT = table.concat(BODY, "\n")

local window
local finished = false

local function finish()
  if finished then return end
  finished = true
  manualCheck("in a macro's body, caret at the start of a line: Shift+Down twice, Ctrl+X, then Ctrl+V at the"
    .. " start of a later line", "those two lines moved there, nothing else changed")
  manualCheck("make a macro, restart the client and open Macros", "that macro, its name and body unchanged")
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
  window = hafen.ui():window():title("174.1"):size(600, 48 + 20 * #lines):position(20, 80)
  local done = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  for at, line in ipairs(lines) do
    hafen.ui():label():parent(window):position(8, 20 + 20 * at):text(line)
  end
  done:on("Pressed", function() after(0, onDone) end)
end

local function page()
  local session = hafen.session():current()
  return session and session:ui():match("@MacroPanel")
end

local function rows(macroPanel)
  local names = {}
  for _, label in ipairs(macroPanel:matchAll("@MacroRow label")) do
    names[#names + 1] = label:text()
  end
  return names
end

local function hasRow(macroPanel, name)
  for _, text in ipairs(rows(macroPanel)) do
    if text == name then return true end
  end
  return false
end

local function body(macroPanel)
  local editor = macroPanel:match("@CodeArea")
  return editor and editor:text()
end

-- The status line: the page's own label, the one that is not inside a row.
local function status(macroPanel)
  for _, label in ipairs(macroPanel:matchAll("label")) do
    if label:parent() == macroPanel then return label:text() end
  end
end

local function needPage(what)
  local macroPanel = page()
  if not macroPanel then
    check(false, what, "no @MacroPanel -- open Ctrl+O, Macros, logged in")
    finish()
  end
  return macroPanel
end

local function deleted()
  local macroPanel = needPage("after Delete and Yes no row reads '" .. NAME .. "'")
  if not macroPanel then return end
  check(not hasRow(macroPanel, NAME), "after Delete and Yes no row reads '" .. NAME .. "'",
    table.concat(rows(macroPanel), ", "))
  finish()
end

local function switched()
  local macroPanel = needPage("another row and back keeps the edit")
  if not macroPanel then return end
  local want = BODY_TEXT .. "\n-- edited"
  local got = body(macroPanel)
  check(got == want, "another row and back keeps the edit: the editor reads the four lines",
    tostring(got):gsub("\n", "\\n"))
  check(hasRow(macroPanel, NAME), "leaving with the name field empty keeps the stored name '" .. NAME .. "'",
    table.concat(rows(macroPanel), ", "))
  prompt({
    "Press Delete, then Yes in the window that asks.",
    "Delete the extra 'New macro' too if you made one for this run. Then Done.",
  }, deleted)
end

local function refused()
  local macroPanel = needPage("Save with an empty name is refused")
  if not macroPanel then return end
  local said = status(macroPanel) or "<no status line>"
  check(said:find("name", 1, true) ~= nil, "Save with an empty name is refused on the status line, naming the name",
    said)
  check(hasRow(macroPanel, NAME), "the row still reads '" .. NAME .. "' after the refused Save",
    table.concat(rows(macroPanel), ", "))
  prompt({
    "Leave the name empty. At the end of the body press Enter and type:   -- edited",
    "Click another macro in the list (press New first if '" .. NAME .. "' is the only one),",
    "then click '" .. NAME .. "' again. Then Done.",
  }, switched)
end

local function saved()
  local macroPanel = page()
  check(macroPanel ~= nil, "the Macros page is in the tree (@MacroPanel)", "nil -- open Ctrl+O, Macros")
  if not macroPanel then return finish() end
  check(hasRow(macroPanel, NAME), "a row of the list reads '" .. NAME .. "'", table.concat(rows(macroPanel), ", "))
  local got = body(macroPanel)
  check(got == BODY_TEXT, "the editor (@CodeArea) reads the three lines exactly", tostring(got):gsub("\n", "\\n"))
  prompt({ "Clear the name field, press Save, then Done." }, refused)
end

local function run()
  finished, pass, fail, manual = false, 0, 0, 0
  if not hafen.session():current() then
    check(false, "a character is in the world", "nil -- run :t174 logged in")
    return finish()
  end
  local lines = { "Ctrl+O, Macros, New. Name it:   " .. NAME,
                  "Type these three lines into the editor, no Enter after the last:" }
  for _, line in ipairs(BODY) do lines[#lines + 1] = "        " .. line end
  lines[#lines + 1] = "Press Save. Then Done."
  prompt(lines, saved)
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t174", function() after(0, run) end)
