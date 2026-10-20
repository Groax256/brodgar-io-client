-- 176.2 — GobOverlaySdtChanged. Self-checking suite.

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

-- A near miss must be refused, naming both state-byte keys.
local function refusesNearMiss(key)
  local ok, err = pcall(function() hafen.event():on(key, function() end) end)
  err = ok and "<no error>" or message(err)
  check(not ok and err:find("GobSdtChanged", 1, true) ~= nil and err:find("GobOverlaySdtChanged", 1, true) ~= nil,
    "\"" .. key .. "\" is refused, naming GobSdtChanged and GobOverlaySdtChanged", err)
end

-- One member: an array of whole numbers in 0..255, or a description of what is wrong with it.
local function badMember(member)
  if type(member) ~= "table" then return "a " .. type(member) end
  for index = 1, #member do
    local byte = member[index]
    if type(byte) ~= "number" or byte ~= math.floor(byte) or byte < 0 or byte > 255 then
      return "entry " .. index .. " = " .. tostring(byte)
    end
  end
  return nil
end

local window, subscription
local seen, badKey, deadGob, badSdt, cavewarn
local nBadKey, nDeadGob, nBadSdt = 0, 0, 0

local function onChange(event)
  seen = seen + 1
  local key = event:key()
  if type(key) ~= "string" then nBadKey = nBadKey + 1 badKey = badKey or tostring(key) end
  local gob = event:gob()
  if not gob:exists() then
    nDeadGob = nDeadGob + 1
    deadGob = deadGob or (tostring(key) .. " on " .. tostring(gob:id()))
  end
  local members, wrong = event:sdt(), nil
  if type(members) ~= "table" or #members == 0 then
    wrong = tostring(key) .. ": " .. (type(members) == "table" and "{}" or tostring(members))
  else
    for index, member in ipairs(members) do
      local bad = badMember(member)
      if bad and not wrong then wrong = tostring(key) .. " member " .. index .. ": " .. bad end
    end
    if key == "gfx/fx/cavewarn" then
      local newest = members[#members]
      cavewarn = { members = #members, byte = type(newest) == "table" and newest[1] or nil }
    end
  end
  if wrong then
    nBadSdt = nBadSdt + 1
    badSdt = badSdt or wrong
  end
end

-- "n of seen failed, first: ..." -- every firing is scored, not just the first bad one.
local function failures(count, first)
  if seen == 0 then return "no firing" end
  return count .. " of " .. seen .. " failed, first: " .. tostring(first)
end

local function report()
  if window then pcall(function() window:destroy() end) end
  window = nil
  local ended = subscription:off()
  check(ended == subscription, "subscription:off() ends it and hands it back", ended)
  check(seen > 0, "GobOverlaySdtChanged fired (" .. seen .. " firing(s))", "no firing")
  check(seen > 0 and badKey == nil, "every firing's event:key() is a string (" .. seen .. ")", failures(nBadKey, badKey))
  check(seen > 0 and deadGob == nil, "every firing's event:gob():exists() is true (" .. seen .. ")", failures(nDeadGob, deadGob))
  check(seen > 0 and badSdt == nil, "every firing's event:sdt() is non-empty arrays of whole 0..255 (" .. seen .. ")",
    failures(nBadSdt, badSdt))
  check(cavewarn ~= nil, cavewarn and ("gfx/fx/cavewarn fired: " .. cavewarn.members
    .. " member(s), newest first byte " .. tostring(cavewarn.byte)) or "gfx/fx/cavewarn fired",
    "no gfx/fx/cavewarn firing")
  manualCheck("dust fell on screen while you mined", "yes")
  hafen.log():write(("[summary] %d pass, %d fail, %d manual"):format(pass, fail, manual))
end

local function run()
  pass, fail, manual = 0, 0, 0
  seen, badKey, deadGob, badSdt, cavewarn = 0, nil, nil, nil, nil
  nBadKey, nDeadGob, nBadSdt = 0, 0, 0
  if subscription then pcall(function() subscription:off() end) end
  if window then pcall(function() window:destroy() end) end
  refusesNearMiss("GobOverlaySdt")
  refusesNearMiss("OverlaySdtChanged")
  subscription = hafen.event():on("GobOverlaySdtChanged", onChange)
  check(subscription ~= nil, "hafen.event():on(\"GobOverlaySdtChanged\", fn) subscribes", subscription)
  local hud = hafen.session():current():ui():match("@GameUI")
  window = hafen.ui():window():parent(hud):title("176.2"):size(560, 100):position(20, 80)
  local doneButton = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  hafen.ui():label():parent(window):position(8, 40)
    :text("Mine until cave-in dust falls on screen, then Done.")
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
hafen.console():on("t176", function() hafen.timer():after(0, run) end)
