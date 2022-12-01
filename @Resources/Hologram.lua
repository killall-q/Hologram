function Initialize()
  point = {} -- array of points
  edge = tonumber(SKIN:GetVariable('Edge')) -- edge interpolation setting
  maxR = 0 -- max radius of model from origin
  xyScale = 0 -- scale of display and model
  dispR = tonumber(SKIN:GetVariable('DispR')) -- half of display width
  theta = tonumber(SKIN:GetVariable('Theta')) -- pitch angle
  phi = tonumber(SKIN:GetVariable('Phi')) -- roll angle
  psi = tonumber(SKIN:GetVariable('Psi')) -- yaw angle
  omega = tonumber(SKIN:GetVariable('Omega')) -- delta of yaw angle (angular velocity)
  loadTCoeff = tonumber(SKIN:GetVariable('LoadTCoeff')) -- load time estimation coefficient
  perspective = tonumber(SKIN:GetVariable('Perspective'))
  scroll = 0 -- file browser scroll position
  hasMoved = false
  local update = SKIN:GetVariable('Update')
  SKIN:Bang('[!SetOption Edge'..(edge or 0)..'xSet SolidColor FF0000][!SetOption Edge'..(edge or 0)..'xSet MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!SetOption PerspectiveSlider X '..(perspective * 90)..'r][!SetOption Omega'..update..' SolidColor FF0000][!ClearMouseAction Omega'..update..' LeftMouseUpAction][!SetOption Omega'..update..' MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!SetOption OmegaSlider X '..(45 + omega * 2250)..'r][!SetOption OmegaVal Text '..(omega * 250)..']')
  if update == '-1' then
    omega = 0
    SKIN:Bang('[!SetOption OmegaSlider SolidColor FFFFFF80][!SetOption OmegaVal FontColor FFFFFF80][!SetOption OmegaSet SolidColor 50505060][!ClearMouseAction OmegaSet LeftMouseUpAction][!ClearMouseAction OmegaSet MouseScrollUpAction][!ClearMouseAction OmegaSet MouseScrollDownAction][!DisableMouseAction OmegaSet MouseOverAction][!DisableMouseAction OmegaSet MouseLeaveAction]')
  end
  LoadFile(SKIN:ReplaceVariables(SKIN:GetVariable('Path')), SKIN:GetVariable('File'))
end

function Update()
  if not hasMoved and omega == 0 then return end
  hasMoved, psi = false, (psi + omega) % 6.28
  local sinTheta, cosTheta, sinPhi, cosPhi, sinPsi, cosPsi = math.sin(theta), math.cos(theta), math.sin(phi), math.cos(phi), math.sin(psi), math.cos(psi)
  for i = 1, #v.x do
    local zDepthScale = 1 - ((v.z[i] * cosPhi - (v.x[i] * cosPsi + v.y[i] * sinPsi) * sinPhi) * -sinTheta + (v.y[i] * cosPsi - v.x[i] * sinPsi) * cosTheta) / maxR * perspective
    point[i]:SetX((v.z[i] * sinPhi + (v.x[i] * cosPsi + v.y[i] * sinPsi) * cosPhi) * xyScale * zDepthScale + dispR)
    point[i]:SetY(((v.z[i] * cosPhi - (v.x[i] * cosPsi + v.y[i] * sinPsi) * sinPhi) * cosTheta + (v.y[i] * cosPsi - v.x[i] * sinPsi) * sinTheta) * -xyScale * zDepthScale + dispR)
  end
  SKIN:Bang('!UpdateMeterGroup P')
end

function Pitch(n, reset)
  hasMoved, theta = true, reset and 0 or math.floor((theta + n) % 6.3 * 10 + 0.5) * 0.1
  SKIN:Bang('[!SetOption Theta Text '..theta..'][!Update][!WriteKeyValue Variables Theta '..theta..' "#@#Settings.inc"]')
end

function Roll(n, reset)
  hasMoved, phi = true, reset and 0 or math.floor((phi + n) % 6.3 * 10 + 0.5) * 0.1
  SKIN:Bang('[!SetOption Phi Text '..phi..'][!Update][!WriteKeyValue Variables Phi '..phi..' "#@#Settings.inc"]')
end

function Yaw(n, reset)
  hasMoved, psi = true, reset and 0 or math.floor((psi + n) % 6.3 * 10 + 0.5) * 0.1
  SKIN:Bang('[!SetOption Psi Text '..psi..'][!Update][!WriteKeyValue Variables Psi '..psi..' "#@#Settings.inc"]')
end

function Scale(n)
  if dispR + n < 70 or SKIN:GetVariable('SCREENAREAWIDTH') / 2 < dispR + n then return end
  hasMoved, dispR = true, dispR + n
  xyScale = dispR / maxR
  SKIN:Bang('[!MoveMeter '..dispR..' '..dispR..' Handle][!SetOption Handle W '..(dispR * 2)..'][!SetOption Handle H '..(dispR * 2)..'][!SetOption Handle FontSize '..(dispR * 0.2)..'][!Update][!WriteKeyValue Variables DispR '..dispR..' "#@#Settings.inc"]')
end

function InitScroll()
  itemCount = SKIN:GetMeasure('mFolderCount'):GetValue() + SKIN:GetMeasure('mFileCount'):GetValue()
  SKIN:Bang('[!SetOption FileScroll Y 2r][!SetOption FileScroll H '..math.min(186, 1900 / itemCount - 4)..'][!UpdateMeter FileScroll]')
  HighlightSelected()
end

function ScrollList(n, m)
  if m then
    local n = m * 0.01 > (scroll + 5) / itemCount and 1 or -1
    for i = 1, 3 do
      ScrollList(n)
    end
  elseif 0 <= scroll + n and scroll + n + 10 <= itemCount then
    scroll = scroll + n
    SKIN:Bang('[!SetOption FileScroll Y '..(190 / (itemCount - 10) * (1 - 10 / itemCount) * scroll + 2)..'r][!UpdateMeter FileScroll][!CommandMeasure mPath Index'..(n > 0 and 'Down' or 'Up')..'][!UpdateMeasure mPath]')
    HighlightSelected()
  end
end

function HighlightSelected()
  local name = tempName or SKIN:GetVariable('File')
  SKIN:Bang('[!SetOptionGroup File SolidColor 505050E0][!SetOptionGroup File MouseLeaveAction ""]')
  for i = 1, 10 do
    if name == SKIN:GetMeasure('mFile'..i):GetStringValue() then
      SKIN:Bang('[!SetOption File'..i..' SolidColor FF0000][!SetOption File'..i..' MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#]"]')
      break
    end
  end
  SKIN:Bang('!UpdateMeterGroup File')
end

function SelectFile(n)
  local name = SKIN:GetMeasure('mFile'..n):GetStringValue()
  local ext = name:sub(-4):lower()
  if name == '' then return end
  if ext ~= '.stl' and ext ~= '.obj' then
    SKIN:Bang('[!CommandMeasure mFile'..n..' FollowPath][!UpdateMeasure mPath]')
  else
    local path = SKIN:GetMeasure('mPath'):GetStringValue()
    tempName = name
    HighlightSelected()
    LoadFile(path, name, true)
  end
end

function FileContext(n)
  if SKIN:GetMeasure('mFile'..n):GetStringValue() == '' then return end
  SKIN:Bang('!CommandMeasure mFile'..n..' ContextMenu')
end

function LoadFile(path, name, isScan)
  v = { x={}, y={}, z={} } -- array of vertices
  local file, ext, f, vHash, vIdx, numV, minX, maxX, minY, maxY, minZ, maxZ = io.open(path..name), name:sub(-4):lower(), { {}, {}, {} }, {}, {}, 0, math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
  if not file then
    SKIN:Bang('!SetOption Handle Text "INVALID FILE"')
    Scale(0)
    return
  end
  -- Build index of unique vertices
  local GetVIdx = function (x, y, z)
    local hash = x..y..z
    if not vHash[hash] then
      v.x[#v.x + 1], v.y[#v.y + 1], v.z[#v.z + 1] = x, y, z
      minX, maxX = x < minX and x or minX, maxX < x and x or maxX
      minY, maxY = y < minY and y or minY, maxY < y and y or maxY
      minZ, maxZ = z < minZ and z or minZ, maxZ < z and z or maxZ
      vHash[hash] = #v.x
      numV = numV + 1
    end
    vIdx[#vIdx + 1] = vHash[hash]
    return vHash[hash]
  end
  if ext == '.stl' then
    local data = file:read('*a')
    if data:find('^%s*solid.-facet.*endsolid') then
      -- ASCII STL
      for facet in data:gmatch('facet.-outer loop(.-)endloop.-endfacet') do
        local i = 1
        numV = numV + (edge or 0) * 1.5
        for x, y, z in facet:gmatch('vertex%s+(%S+)%s+(%S+)%s+(%S+)') do
          f[i][#f[i] + 1] = GetVIdx(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
          i = i + 1
        end
      end
    else
      -- Binary STL
      -- Convert little endian byte to 32-bit float
      local BinToFloat32 = function (bin)
        local sig = bin:byte(3) % 0x80 * 0x10000 + bin:byte(2) * 0x100 + bin:byte(1)
        local exp = bin:byte(4) % 0x80 * 2 + math.floor(bin:byte(3) / 0x80) - 0x7F
        if exp == 0x7F then return 0 end
        return math.ldexp(math.ldexp(sig, -23) + 1, exp) * (bin:byte(4) < 0x80 and 1 or -1)
      end

      file:close()
      file = io.open(path..name, 'rb')
      file:seek('set', 84)
      while true do
        local facet = file:read(50)
        if not facet then break end
        numV = numV + (edge or 0) * 1.5
        for i = 1, 3 do
          local pos = i * 12
          f[i][#f[i] + 1] = GetVIdx(BinToFloat32(facet:sub(pos + 1, pos + 4)), BinToFloat32(facet:sub(pos + 5, pos + 8)), BinToFloat32(facet:sub(pos + 9, pos + 12)))
        end
      end
    end
  elseif ext == '.obj' then
    -- ASCII OBJ
    for line in file:lines() do
      if line:sub(1, 2) == 'v ' then
        local x, y, z = line:match('v%s+(%S+)%s+(%S+)%s+(%S+)')
        GetVIdx(tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0)
      elseif edge and line:sub(1, 2) == 'f ' then
        local v1, v2, v3 = line:match('f%s+(%d+)%s+(%d+)%s+(%d+)')
        f[1][#f[1] + 1], f[2][#f[2] + 1], f[3][#f[3] + 1] = vIdx[tonumber(v1)], vIdx[tonumber(v2)], vIdx[tonumber(v3)]
        numV = numV + edge * 1.5
      end
    end
  end
  file:close()
  if isScan then
    if numV <= #point then
      -- Load without refreshing
      SKIN:Bang('[!SetVariable Edge '..(edge or '""')..'][!WriteKeyValue Variables Edge '..(edge or '""')..' "#@#Settings.inc"][!EnableMouseAction Handle MouseLeaveAction][!HideMeterGroup Est][!WriteKeyValue Variables Path "'..path..'" "#@#Settings.inc"][!SetVariable File "'..name..'"][!WriteKeyValue Variables File "'..name..'" "#@#Settings.inc"]')
    else
      EstimateLoadTime(numV)
      return
    end
  end
  -- Edge interpolation
  if edge then
    for i = 1, #f[1] do
      for j = 1, 3 do
        local jNext = j ~= 3 and j + 1 or 1
        for e = 1, edge, 2 do
          v.x[#v.x + 1] = v.x[f[j][i]] + (v.x[f[jNext][i]] - v.x[f[j][i]]) * e / (edge + 1)
          v.y[#v.y + 1] = v.y[f[j][i]] + (v.y[f[jNext][i]] - v.y[f[j][i]]) * e / (edge + 1)
          v.z[#v.z + 1] = v.z[f[j][i]] + (v.z[f[jNext][i]] - v.z[f[j][i]]) * e / (edge + 1)
        end
      end
    end
  end
  -- Generate meters
  if not SKIN:GetMeter(1) or #point ~= 0 and #v.x > #point then
    GenMeters(#v.x)
    return
  end
  -- Load meters into Lua memory
  if #point == 0 then
    while true do
      local meter = SKIN:GetMeter(#point + 1)
      if meter then
        point[#point + 1] = meter
      else break end
    end
    os.remove(SKIN:GetVariable('@')..'Meters.inc')
    SKIN:Bang('[!SetVariable Points '..#point..'][!SetOption PreloadSet Text '..#point..']')
  end
  -- Hide unused points
  for i = #v.x + 1, #point do
    point[i]:SetX(0)
    point[i]:SetY(-99)
  end
  -- Fit and center model
  local offsetX, offsetY, offsetZ = (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2
  maxR = ((maxX - offsetX)^2 + (maxY - offsetY)^2 + (maxZ - offsetZ)^2)^0.5
  for i = 1, #v.x do
    v.x[i], v.y[i], v.z[i] = v.x[i] - offsetX, v.y[i] - offsetY, v.z[i] - offsetZ
  end
  Scale(0)
  -- Clock load
  local benchT = tonumber(SKIN:GetVariable('BenchT'))
  if benchT and #point ~= 0 then
    local elapsedT = math.abs(os.clock() - benchT)
    -- Use logarithmic function to dampen change in coefficient
    loadTCoeff = (0.2 * math.log(elapsedT / (#point)^2 / loadTCoeff) + 1) * loadTCoeff
    SKIN:Bang('[!SetVariable BenchT ""][!WriteKeyValue Variables BenchT "" "#@#Settings.inc"][!WriteKeyValue Variables LoadTCoeff '..loadTCoeff..' "#@#Settings.inc"]')
    print('Hologram: loaded '..#point..' points in '..string.format('%s.%03u', os.date('!%H:%M:%S', elapsedT), math.fmod(elapsedT, 1) * 1000))
  else
    print('Hologram: '..#v.x..' points')
  end
end

function EstimateLoadTime(p)
  points = p
  local estT = loadTCoeff * p^2
  SKIN:Bang('[!SetOption EstTime Postfix '..string.format('%s.%03u', os.date('!%H:%M:%S', estT), math.fmod(estT, 1) * 1000)..'][!SetOption EstPoints Postfix '..p..'][!ClearMouseAction Handle MouseLeaveAction][!UpdateMeter Handle][!UpdateMeterGroup Est][!ShowMeterGroup Est][!Redraw]')
end

function GenMeters(p)
  local file = io.open(SKIN:GetVariable('@')..'Meters.inc', 'w')
  for i = 1, p do
    file:write('['..i..']\nMeter=Image\nMeterStyle=P\n')
  end
  file:close()
  SKIN:Bang('!Refresh')
end

function StartLoad()
  local name = tempName or SKIN:GetVariable('File')
  SKIN:Bang('[!WriteKeyValue Variables Theta 0.5 "#@#Settings.inc"][!WriteKeyValue Variables Phi 0 "#@#Settings.inc"][!WriteKeyValue Variables Psi 0.5 "#@#Settings.inc"][!WriteKeyValue Variables Path "'..SKIN:GetMeasure('mPath'):GetStringValue()..'" "#@#Settings.inc"][!SetVariable File "'..name..'"][!WriteKeyValue Variables File "'..name..'" "#@#Settings.inc"][!WriteKeyValue Variables Edge '..(edge or '""')..' "#@#Settings.inc"][!WriteKeyValue Variables BenchT '..os.clock()..' "#@#Settings.inc"]')
  GenMeters(points)
end

function Cancel()
  tempName = nil
  HighlightSelected()
  SetEdge(tonumber(SKIN:GetVariable('Edge')), true)
  SKIN:Bang('[!HideMeterGroup Est][!EnableMouseAction Handle MouseLeaveAction][!Redraw]')
end

function Preload()
  EstimateLoadTime(tonumber(SKIN:GetVariable('Set')))
end

function SetPixS()
  local pixS = tonumber(SKIN:GetVariable('Set'))
  if not pixS or pixS <= 0 then return end
  SKIN:Bang('[!SetOptionGroup P W "#Set#"][!SetOptionGroup P H "#Set#"][!SetOption PixSSet Text "#Set#"][!SetVariable PixS "#Set#"][!WriteKeyValue Variables PixS "#Set#" "#@#Settings.inc"][!EnableMouseAction Handle MouseLeaveAction][!UpdateMeter *][!Redraw]')
end

function SetEdge(n, isCancel)
  SKIN:Bang('[!SetOption Edge'..(edge or 0)..'xSet SolidColor 505050E0][!SetOption Edge'..(edge or 0)..'xSet MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor 505050E0][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!SetOption Edge'..(n or 0)..'xSet SolidColor FF0000][!SetOption Edge'..(n or 0)..'xSet MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!WriteKeyValue Variables Edge '..(n or '""')..' "#@#Settings.inc"][!UpdateMeterGroup Edge]')
  edge = tonumber(n)
  if isCancel then return end
  LoadFile(SKIN:ReplaceVariables(SKIN:GetVariable('Path')), SKIN:GetVariable('File'), true)
end

function SetPerspective(n, m)
  if m then
    hasMoved, perspective = true, math.floor(m * 0.11) * 0.1
  elseif 0 <= perspective + n and perspective + n <= 1 then
    hasMoved, perspective = true, math.floor((perspective + n) * 10 + 0.5) * 0.1
  else return end
  SKIN:Bang('[!SetOption PerspectiveSlider X '..(perspective * 90)..'r][!SetOption PerspectiveVal Text '..perspective..'][!Update][!WriteKeyValue Variables Perspective '..perspective..' "#@#Settings.inc"]')
end

function SetColor()
  if SKIN:GetVariable('Set') == '' then return end
  SKIN:Bang('[!SetOptionGroup P SolidColor "#Set#"][!SetOption ColorSet Text "#Set#"][!SetVariable Color "#Set#"][!WriteKeyValue Variables Color "#Set#" "#@#Settings.inc"][!EnableMouseAction Handle MouseLeaveAction][!UpdateMeter *][!Redraw]')
end

function SetOmega(n, m)
  -- Set angular velocity
  if m then
    omega = math.floor(m * 0.11) * 0.004 - 0.02
  elseif -0.02 <= omega + n and omega + n <= 0.02 then
    omega = math.floor((omega + n) * 250 + 0.5) * 0.004
  else return end
  SKIN:Bang('[!SetOption OmegaSlider X '..(45 + omega * 2250)..'r][!SetOption OmegaVal Text '..(omega * 250)..'][!WriteKeyValue Variables Omega '..omega..' "#@#Settings.inc"]')
end
