-- 174.4 — an addon's own bar takes a macro. Self-checking suite.

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

-- A refusal is a check: the call must fail, and fail SAYING why.
local function refuses(what, fn, wantMsg)
  local ok, err = pcall(fn)
  err = ok and "<no error>" or message(err)
  check((not ok) and (err:find(wantMsg, 1, true) ~= nil), what, err)
end

local NAME = "t174 four"
local SLOT = 144        -- the last page's last slot: the square stands for it, whatever the server has there

local window
local finished = false
local dropped = nil     -- the res the square's Drop was handed
local holdError = nil   -- what the square's slot:hold(res) raised, if it did
local slot, id = nil, nil

local function finish()
  if finished then return end
  finished = true
  manualCheck("with actionbars enabled, drag a macro onto its bar, press that button's key over the map, then"
    .. " right-click the button", "the wrench drawn, the macro run, then the server's action back in the button")
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

-- One step: what to do, and Done when it is done. The window hangs on the character's HUD: a drag ends in
-- the character's tree, so the square standing for the bar slot must stand there. The square is an addon's
-- bar in miniature: its Drop holds the slot with slot:hold(res), its Draw draws the slot's res with g:resource.
local function prompt(text, onDone)
  if window then window:destroy() end
  local hud = hafen.session():current():ui():match("@GameUI")
  window = hafen.ui():window():parent(hud):title("174.4"):size(600, 128):position(20, 80)
  local done = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  hafen.ui():label():parent(window):position(8, 40):text(text)
  local square = hafen.ui():widget():parent(window):position(8, 72):size(48, 48)
  hafen.ui():label():parent(window):position(64, 86):text("<- drop here (slot " .. SLOT .. ")")
  square:on("Draw", function(draw_event)
    local graphics = draw_event:g()
    graphics:color(255, 255, 255, 48)
    graphics:frect(0, 0, 48, 48)
    graphics:color()
    graphics:rect(0, 0, 48, 48)
    local res = slot and slot:res()
    if res and res:sub(1, 6) == "macro/" then
      graphics:resource(res, 4, 4, 40, 40)
    end
  end)
  square:on("Drop", function(drop_event)
    local thing = drop_event:thing()
    drop_event:preventDefault()
    dropped = thing and thing.res
    if dropped and dropped:sub(1, 6) == "macro/" then
      local ok, err = pcall(slot.hold, slot, dropped)
      holdError = (not ok) and message(err) or nil
    end
  end)
  done:on("Pressed", function() after(0, onDone) end)
end

local function page()
  local session = hafen.session():current()
  return session and session:ui():match("@MacroPanel")
end

local function deleted()
  local macroPanel = page()
  local still = false
  for _, label in ipairs(macroPanel and macroPanel:matchAll("@MacroRow label") or {}) do
    if label:text() == NAME then still = true end
  end
  check(macroPanel ~= nil and not still, "after Delete and Yes no row reads '" .. NAME .. "'",
    macroPanel and "a row still reads it" or "no @MacroPanel")
  refuses("slot:hold('" .. id .. "') of the deleted macro is refused naming it",
    function() slot:hold(id) end, id)
  finish()
end

local function looked()
  refuses("slot:hold('macro/999999') is refused naming that id",
    function() slot:hold("macro/999999") end, "macro/999999")
  refuses("slot:hold('dig') is still refused, expecting a Pagina",
    function() slot:hold("dig") end, "expected a Pagina")
  slot:hold(nil)
  check(slot:res() ~= id, "slot:hold(nil) releases the macro: res() no longer " .. id, slot:res())
  prompt("Select '" .. NAME .. "' on the Macros page, press Delete, then Yes. Then Done.", deleted)
end

local function placed()
  check(dropped ~= nil and dropped:match("^macro/%d+$") ~= nil,
    "the square's Drop is handed a macro's res, macro/<id>", dropped or "no Drop")
  if not (dropped and dropped:match("^macro/%d+$")) then return finish() end
  id = dropped
  check(holdError == nil and slot:res() == id and slot:name() == NAME and slot:hold() == nil,
    "the Drop's slot:hold(res) holds slot " .. SLOT .. ": res() " .. id .. ", name() '" .. NAME .. "', hold() nil",
    holdError or (tostring(slot:res()) .. ", " .. tostring(slot:name()) .. ", " .. tostring(slot:hold())))
  manualCheck("look at the square after the drop", "the wrench drawn inside it")
  prompt("Look at the square: it should draw the macro's icon. Then Done.", looked)
end

local function filled()
  local macroPanel = page()
  local name = macroPanel and macroPanel:match("@TextEntry")
  if not (name and name:value() == "New macro") then
    check(false, "the page shows a new macro", macroPanel and "not 'New macro'" or "no @MacroPanel -- Ctrl+O, Macros")
    return finish()
  end
  name:value(NAME)
  prompt("Press Save, then drag the wrench onto the square below. Then Done.", placed)
end

local function run()
  finished, pass, fail, manual = false, 0, 0, 0
  dropped, holdError, id = nil, nil, nil
  local session = hafen.session():current()
  if not session then
    check(false, "a character is in the world", "nil -- run :t174 logged in")
    return finish()
  end
  slot = session:actionbar():get(SLOT)
  prompt("Ctrl+O, Macros, press New. Then Done.", filled)
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t174", function() after(0, run) end)
