-- 176.1 — a native overlay answers its state bytes. Self-checking suite.

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

local KEY = "t176"
local GHOST_RES = "gfx/terobjs/arch/logcabin"

local window
local finished = false
local mine, ghost, playerGob = nil, nil, nil

local function finish()
  if finished then return end
  finished = true
  if playerGob then pcall(function() playerGob:overlay():remove(KEY) end) end
  if ghost then pcall(function() hafen.virtual():ghost():remove(ghost) end) end
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

local function sameMembers(left, right)
  if type(left) ~= "table" or type(right) ~= "table" or #left ~= #right then return false end
  for index = 1, #left do
    local one, two = left[index], right[index]
    if type(one) ~= "table" or type(two) ~= "table" or #one ~= #two then return false end
    for at = 1, #one do
      if one[at] ~= two[at] then return false end
    end
  end
  return true
end

-- Every native overlay on every gob in view.
local function natives(session)
  local out = {}
  for _, gob in ipairs(session:world():gob():list()) do
    for _, overlay in ipairs(gob:overlay():list()) do
      if overlay:native() then out[#out + 1] = overlay end
    end
  end
  return out
end

local function ownAndGhost()
  -- yours: a text, then a ghost anchored to the same gob, read back through the collection
  mine = playerGob:overlay():add(KEY):text(KEY)
  check(mine:sdt() == nil and mine:info() ~= nil and mine:info().sdt == nil,
    "an overlay of yours answers sdt() nil and its :info() carries no sdt",
    tostring(mine:sdt()) .. " / " .. tostring(mine:info() and mine:info().sdt))
  ghost = hafen.virtual():ghost():add(GHOST_RES, playerGob)
  local listed
  local function find()
    for _, overlay in ipairs(playerGob:overlay():list()) do
      if not overlay:native() and overlay:kind() == "ghost" then listed = overlay end
    end
    return listed ~= nil
  end
  waitFor(find, 2, function()
    check(listed ~= nil and listed:sdt() == nil and listed:info() ~= nil and listed:info().sdt == nil,
      "a ghost stood at the gob answers sdt() nil and its :info() carries no sdt",
      listed and (tostring(listed:sdt()) .. " / " .. tostring(listed:info() and listed:info().sdt))
        or "the ghost is not in gob:overlay():list()")
    playerGob:overlay():remove(KEY)
    check(mine:sdt() == nil and not mine:exists(), "the held handle answers sdt() nil after :remove",
      tostring(mine:sdt()))
    finish()
  end)
end

local function walk()
  local session = hafen.session():current()
  playerGob = session and session:player():gob()
  if not playerGob then
    check(false, "the character is in the world", "no player gob")
    return finish()
  end
  local overlays = natives(session)
  if #overlays == 0 then
    check(false, "a native overlay is in view", "no native overlay in view")
  else
    local lengthBad, memberBad = nil, nil
    for _, overlay in ipairs(overlays) do
      local members = overlay:sdt()
      local count = overlay:count()
      if type(members) ~= "table" or #members ~= count then
        lengthBad = lengthBad or (overlay:key() .. ": #sdt " .. (type(members) == "table" and #members or tostring(members))
          .. " vs count " .. tostring(count))
      else
        for index, member in ipairs(members) do
          local bad = badMember(member)
          if bad and not memberBad then memberBad = overlay:key() .. " member " .. index .. ": " .. bad end
        end
      end
    end
    check(lengthBad == nil, "#overlay:sdt() == overlay:count() on all " .. #overlays .. " native overlays", lengthBad)
    check(memberBad == nil, "every member is an array of whole numbers in 0..255", memberBad)

    local first = overlays[1]
    local live, snapshot = first:sdt(), first:info() and first:info().sdt
    check(sameMembers(snapshot, live), "overlay:info().sdt matches overlay:sdt() member by member on " .. first:key(),
      tostring(snapshot))
    check(first:sdt() ~= first:sdt() and snapshot ~= live, "two reads, and the snapshot, are three different tables",
      "a table shared")
    local ok, err = pcall(first.sdt, first, 1)
    err = ok and "<no error>" or message(err)
    check(not ok and err:find("overlay:sdt", 1, true) ~= nil and err:find("no arguments", 1, true) ~= nil,
      "overlay:sdt(1) is refused, naming overlay:sdt and no arguments", err)
  end
  ownAndGhost()
end

local function run()
  finished = false
  pass, fail, manual = 0, 0, 0
  if window then window:destroy() end
  local hud = hafen.session():current():ui():match("@GameUI")
  window = hafen.ui():window():parent(hud):title("176.1"):size(560, 100):position(20, 80)
  local doneButton = hafen.ui():button():parent(window):position(8, 8):size(100):text("Done")
  hafen.ui():label():parent(window):position(8, 40)
    :text("Stand where the game draws overlays (a lit fire, a mine), then Done.")
  doneButton:on("Pressed", function() after(0, walk) end)
end

-- The only way in: a suite does not start itself. A console line holds the character's tree, so the run
-- starts on the next step, where no tree is held.
hafen.console():on("t176", function() after(0, run) end)
