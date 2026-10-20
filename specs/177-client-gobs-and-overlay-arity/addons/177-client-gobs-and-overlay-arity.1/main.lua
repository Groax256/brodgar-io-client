-- 177.1 — the client's own gobs leave the world surface. Self-checking suite.

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

local function manualCheck(step, expect)
  manual = manual + 1
  hafen.log():write("[manual] " .. step .. " -- expect: " .. expect)
end

local KEYS = { "GobAdded", "GobRemoved", "GobOverlayAdded", "GobOverlayRemoved" }

local window, subscriptions
local counts, negative          -- per event key: firings, and the first negative id seen
local samples, listNegative     -- per Update: lists sampled, and the first negative id in one
local positiveAdded, positiveNative

local function idOf(key, payload)
  -- GobAdded/GobRemoved hand the Gob itself; the overlay events hand an event carrying :gob().
  if key == "GobAdded" or key == "GobRemoved" then return payload:id() end
  return payload:gob():id()
end

local function handler(key)
  return function(payload)
    counts[key] = counts[key] + 1
    local id = idOf(key, payload)
    if type(id) == "number" and id < 0 and negative[key] == nil then
      negative[key] = id .. (key:find("Overlay", 1, true) and (" (" .. tostring(payload:key()) .. ")") or "")
    end
    if key == "GobAdded" and type(id) == "number" and id > 0 then positiveAdded = true end
    if key == "GobOverlayAdded" and payload:native() and type(id) == "number" and id > 0 then
      positiveNative = positiveNative or (id .. " " .. tostring(payload:key()))
    end
  end
end

local function sample()
  samples = samples + 1
  if listNegative ~= nil then return end
  for _, gob in ipairs(hafen.session():current():world():gob():list()) do
    if gob:id() < 0 then
      listNegative = gob:id() .. " " .. tostring(gob:name())
      return
    end
  end
end

local function report()
  if window then pcall(function() window:destroy() end) end
  window = nil
  for _, subscription in ipairs(subscriptions) do subscription:off() end
  subscriptions = {}
  for _, key in ipairs(KEYS) do
    check(counts[key] > 0 and negative[key] == nil, key .. ": no negative id among " .. counts[key],
      negative[key] and ("first negative id " .. negative[key]) or "no firing")
  end
  check(samples > 0 and listNegative == nil, "world():gob():list(): no negative id in " .. samples .. " samples",
    listNegative and ("first negative id " .. listNegative) or "no sample")
  local ghost = hafen.session():current():world():gob():get(-1)
  check(ghost:exists() == false, "world():gob():get(-1):exists() is false", ghost:exists())
  check(positiveAdded == true, "a GobAdded with a positive id came", "no GobAdded with a positive id")
  check(positiveNative ~= nil, "a native GobOverlayAdded with a positive id came"
    .. (positiveNative and (": " .. positiveNative) or ""), "no native GobOverlayAdded with a positive id")
  manualCheck("footsteps were heard while you walked", "yes")
  hafen.log():write(("[summary] %d pass, %d fail, %d manual"):format(pass, fail, manual))
end

local function run()
  pass, fail, manual = 0, 0, 0
  counts, negative = {}, {}
  for _, key in ipairs(KEYS) do counts[key] = 0 end
  samples, listNegative, positiveAdded, positiveNative = 0, nil, false, nil
  if subscriptions then for _, subscription in ipairs(subscriptions) do pcall(function() subscription:off() end) end end
  if window then pcall(function() window:destroy() end) end
  subscriptions = {}
  for _, key in ipairs(KEYS) do
    subscriptions[#subscriptions + 1] = hafen.event():on(key, handler(key))
  end
  subscriptions[#subscriptions + 1] = hafen.event():on("Update", sample)
  local hud = hafen.session():current():ui():match("@GameUI")
  window = hafen.ui():window():parent(hud):title("177.1"):size(560, 100):position(20, 80)
  local doneButton = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  hafen.ui():label():parent(window):position(8, 40)
    :text("Walk somewhere new for ~20 s, past a lit fire, animals, a mine; then Done.")
  doneButton:on("Pressed", function()
    hafen.timer():after(0, function()
      local ok, err = pcall(report)
      if not ok then
        check(false, "the suite ran to its end", message(err))
        hafen.log():write(("[summary] %d pass, %d fail, %d manual"):format(pass, fail, manual))
      end
    end)
  end)
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t177", function() hafen.timer():after(0, run) end)
