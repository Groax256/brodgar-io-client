-- 177.2 — the Overlay reads refuse a surplus argument. Self-checking suite.

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

local VERBS = { "key", "gob", "native", "res", "kind", "count", "exists", "info" }

local window

-- Every verb called with one argument must fail, naming itself and saying it takes no arguments.
local function surplus(label, ol)
  local missed = {}
  for _, verb in ipairs(VERBS) do
    local ok, err = pcall(ol[verb], ol, 1)
    local text = ok and "<no error>" or message(err)
    if ok or not text:find("overlay:" .. verb, 1, true) or not text:find("no arguments", 1, true) then
      missed[#missed + 1] = verb .. " (" .. text .. ")"
    end
  end
  check(#missed == 0, label .. ": all eight reads refuse a surplus argument", table.concat(missed, "; "))
end

-- The bare reads still answer: the first expectation that does not hold, or nil.
local function firstDiffering(expectations)
  for _, e in ipairs(expectations) do
    local ok, got = pcall(e[2])
    if not ok then return e[1] .. " raised: " .. message(got) end
    if not got then return e[1] end
  end
  return nil
end

local function firstNative(world)
  for _, gob in ipairs(world:gob():list()) do
    for _, ol in ipairs(gob:overlay():list()) do
      if ol:native() then return ol end
    end
  end
  return nil
end

local function report()
  if window then pcall(function() window:destroy() end) end
  window = nil
  local session = hafen.session():current()
  local native = firstNative(session:world())
  local me = session:player():gob()
  local mine = me:overlay():add("t177"):text("t177")

  if native then
    surplus("native " .. native:key(), native)
    local bad = firstDiffering({
      { ":key() is a string",        function() return type(native:key()) == "string" end },
      { ":gob():exists()",           function() return native:gob():exists() end },
      { ":native() == true",         function() return native:native() == true end },
      { ":res() == :key()",          function() return native:res() == native:key() end },
      { ":kind() == nil",            function() return native:kind() == nil end },
      { ":count() >= 1",             function() return (native:count() or 0) >= 1 end },
      { ":exists()",                 function() return native:exists() end },
      { "type(:info()) == 'table'",  function() return type(native:info()) == "table" end },
    })
    check(bad == nil, "native " .. native:key() .. ": every bare read answers", bad)
  else
    check(false, "a native overlay to test", "no native overlay in view")
  end

  surplus("yours t177", mine)
  local bad = firstDiffering({
    { ":key() == 't177'",          function() return mine:key() == "t177" end },
    { ":native() == false",        function() return mine:native() == false end },
    { ":res() == nil",             function() return mine:res() == nil end },
    { ":kind() == 'text'",         function() return mine:kind() == "text" end },
    { ":count() == 1",             function() return mine:count() == 1 end },
    { ":exists()",                 function() return mine:exists() end },
    { ":info().kind == 'text'",    function() return mine:info().kind == "text" end },
  })
  check(bad == nil, "yours t177: every bare read answers", bad)

  me:overlay():remove("t177")
  hafen.log():write(("[summary] %d pass, %d fail, %d manual"):format(pass, fail, manual))
end

local function run()
  pass, fail, manual = 0, 0, 0
  if window then pcall(function() window:destroy() end) end
  local hud = hafen.session():current():ui():match("@GameUI")
  window = hafen.ui():window():parent(hud):title("177.2"):size(560, 100):position(20, 80)
  local doneButton = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  hafen.ui():label():parent(window):position(8, 40)
    :text("Stand where the game draws overlays (a lit fire, a mine); then Done.")
  doneButton:on("Pressed", function()
    hafen.timer():after(0, function()
      local ok, err = pcall(report)
      if not ok then
        check(false, "the suite ran to its end", message(err))
        pcall(function() hafen.session():current():player():gob():overlay():remove("t177") end)
        hafen.log():write(("[summary] %d pass, %d fail, %d manual"):format(pass, fail, manual))
      end
    end)
  end)
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t177", function() hafen.timer():after(0, run) end)
