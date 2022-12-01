function Initialize()
  maxR = 0 -- max radius of model from origin
  xyScale = 0 -- scale of display and model
  dispR = tonumber(SKIN:GetVariable('DispR')) -- half of display width
  theta = tonumber(SKIN:GetVariable('Theta')) -- pitch angle
  phi = tonumber(SKIN:GetVariable('Phi')) -- roll angle
  psi = tonumber(SKIN:GetVariable('Psi')) -- yaw angle
  omega = tonumber(SKIN:GetVariable('Omega')) -- delta of yaw angle (angular velocity)
  perspective = tonumber(SKIN:GetVariable('Perspective'))
  viewMode = tonumber(SKIN:GetVariable('ViewMode'))
  scroll = 0 -- file browser scroll position
  hasMoved = false
  hasRendered = false
  isRenderFast = false
  local update = SKIN:GetVariable('Update')
  SKIN:Bang('[!SetOption PerspectiveSlider X '..(perspective * 90)..'r][!SetOption Omega'..update..' SolidColor FF0000][!ClearMouseAction Omega'..update..' LeftMouseUpAction][!SetOption Omega'..update..' MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!SetOption OmegaSlider X '..(45 + omega * 2250)..'r][!SetOption OmegaVal Text '..(omega * 250)..']')
  if update == '-1' then
    omega = 0
    SKIN:Bang('[!SetOption OmegaSlider SolidColor FFFFFF80][!SetOption OmegaVal FontColor FFFFFF80][!SetOption OmegaSet SolidColor 50505060][!ClearMouseAction OmegaSet LeftMouseUpAction][!ClearMouseAction OmegaSet MouseScrollUpAction][!ClearMouseAction OmegaSet MouseScrollDownAction][!DisableMouseAction OmegaSet MouseOverAction][!DisableMouseAction OmegaSet MouseLeaveAction]')
  end
  LoadFile(SKIN:ReplaceVariables(SKIN:GetVariable('Path')), SKIN:GetVariable('File'))
  SetView(viewMode)
  Render()
end

function Update()
  if not hasMoved and omega == 0 then return end
  hasMoved, hasRendered, psi = false, false, (psi + omega) % 6.28
  if isRenderFast then
    Render()
    return
  end
  -- Render simple axial plane circles for responsive interaction
  local trigFuncs, c1, c2, c3 = { math.sin(theta), math.cos(theta), math.sin(phi), math.cos(phi), math.sin(psi), math.cos(psi) }, '', '', ''
  for i = 1, 72 do
    local cx1, cy1 = GetScreenCoords(c.x[i], c.y[i], 0, unpack(trigFuncs))
    local cx2, cy2 = GetScreenCoords(c.x[i], 0, c.y[i], unpack(trigFuncs))
    local cx3, cy3 = GetScreenCoords(0, c.x[i], c.y[i], unpack(trigFuncs))
    c1 = c1..(i ~= 1 and '|LineTo ' or '')..cx1..','..cy1
    c2 = c2..(i ~= 1 and '|LineTo ' or '')..cx2..','..cy2
    c3 = c3..(i ~= 1 and '|LineTo ' or '')..cx3..','..cy3
  end
  SKIN:Bang('[!SetOption Render Shape2 "Path Path2|Stroke Color 0070FF|Extend Circle"][!SetOption Render Path2 "'..c1..'|ClosePath 1"][!SetOption Render Shape3 "Path Path3|Stroke Color 00FF00|Extend Circle"][!SetOption Render Path3 "'..c2..'|ClosePath 1"][!SetOption Render Shape4 "Path Path4|Stroke Color FF0000|Extend Circle"][!SetOption Render Path4 "'..c3..'|ClosePath 1"][!SetOption Render Shape5 ""][!UpdateMeter Render][!SetOption Handle Text "CLICK TO RENDER"][!UpdateMeter Handle][!Redraw]')
end

function Render()
  if hasRendered then return end
  hasRendered = true
  if not isRenderFast then
    SKIN:Bang('[!SetOption Handle Text "RENDERING..."][!UpdateMeter Handle][!Redraw]')
  end
  local trigFuncs, s, startT = { math.sin(theta), math.cos(theta), math.sin(phi), math.cos(phi), math.sin(psi), math.cos(psi) }, { x={}, y={} }, os.clock()
  if viewMode == 0 then
    -- Render vertices
    for i = 1, #v.x do
      s.x[1], s.y[1] = GetScreenCoords(v.x[i], v.y[i], v.z[i], unpack(trigFuncs))
      SKIN:Bang('!SetOption', 'Render', 'Shape'..(i + 1), 'Ellipse '..s.x[1]..','..s.y[1]..',#EdgeThick#|Extend Attr')
    end
    SKIN:Bang('!SetOption Render Shape'..(#v.x + 2)..' ""')
  else
    -- Render edges and/or faces
    for i = 1, #f[1] do
      for j = 1, 3 do
        s.x[j], s.y[j] = GetScreenCoords(v.x[f[j][i]], v.y[f[j][i]], v.z[f[j][i]], unpack(trigFuncs))
      end
      SKIN:Bang('[!SetOption Render Shape'..(i + 1)..' "Path Path'..(i + 1)..'|Extend Attr"][!SetOption Render Path'..(i + 1)..' "'..s.x[1]..','..s.y[1]..'|LineTo '..s.x[2]..','..s.y[2]..'|LineTo '..s.x[3]..','..s.y[3]..'|ClosePath 1"]')
    end
    SKIN:Bang('!SetOption Render Shape'..(#f[1] + 2)..' ""')
  end
  SKIN:Bang('[!UpdateMeter Render][!SetOption Handle Text ""][!UpdateMeter Handle][!Redraw]')
  local elapsedT = os.clock() - startT
  isRenderFast = elapsedT < 0.5
  if isRenderFast then return end
  print('Hologram: rendered '..(viewMode == 0 and #v.x..' vertices' or #f[1]..' faces')..' in '..('%.3f'):format(elapsedT)..' seconds')
end

function GetScreenCoords(x, y, z, sinTheta, cosTheta, sinPhi, cosPhi, sinPsi, cosPsi)
  local szScale = 1 - ((z * cosPhi - (x * cosPsi + y * sinPsi) * sinPhi) * -sinTheta + (y * cosPsi - x * sinPsi) * cosTheta) / maxR * perspective
  local sx = (z * sinPhi + (x * cosPsi + y * sinPsi) * cosPhi) * xyScale * szScale + dispR
  local sy = ((z * cosPhi - (x * cosPsi + y * sinPsi) * sinPhi) * cosTheta + (y * cosPsi - x * sinPsi) * sinTheta) * -xyScale * szScale + dispR
  return sx, sy
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
  SKIN:Bang('[!MoveMeter '..dispR..' '..dispR..' Handle][!SetOptionGroup Render W '..(dispR * 2)..'][!SetOptionGroup Render H '..(dispR * 2)..'][!SetOption Handle FontSize '..(dispR * 0.1)..'][!SetOption Render Shape "Rectangle 0,0,'..(dispR * 2)..','..(dispR * 2)..'|Fill Color 00000000|StrokeWidth 0"][!Update][!WriteKeyValue Variables DispR '..dispR..' "#@#Settings.inc"]')
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
  local name = SKIN:GetVariable('File')
  SKIN:Bang('[!SetOptionGroup File SolidColor 505050E0][!SetOptionGroup File MouseLeaveAction ""]')
  for i = 1, 10 do
    if name == SKIN:GetMeasure('mFile'..i):GetStringValue() then
      SKIN:Bang('[!SetOption File'..i..' SolidColor FF0000][!SetOption File'..i..' MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#]"]')
      break
    end
  end
end

function SelectFile(n)
  local name = SKIN:GetMeasure('mFile'..n):GetStringValue()
  local ext = name:sub(-4):lower()
  if name == '' then return end
  if ext ~= '.stl' and ext ~= '.obj' then
    SKIN:Bang('[!CommandMeasure mFile'..n..' FollowPath][!UpdateMeasure mPath]')
  else
    local path = SKIN:GetMeasure('mPath'):GetStringValue()
    SKIN:Bang('[!WriteKeyValue Variables Path "'..path..'" "#@#Settings.inc"][!SetVariable File "'..name..'"][!WriteKeyValue Variables File "'..name..'" "#@#Settings.inc"]')
    HighlightSelected()
    LoadFile(path, name)
  end
end

function FileContext(n)
  if SKIN:GetMeasure('mFile'..n):GetStringValue() == '' then return end
  SKIN:Bang('!CommandMeasure mFile'..n..' ContextMenu')
end

function LoadFile(path, name)
  v, f, c = { x={}, y={}, z={} }, { {}, {}, {} }, { x={}, y={} } -- arrays of vertices, faces, circumcircle vertices
  local file, ext, vHash, vIdx, minX, maxX, minY, maxY, minZ, maxZ = io.open(path..name), name:sub(-4):lower(), {}, {}, math.huge, -math.huge, math.huge, -math.huge, math.huge, -math.huge
  if not file then
    SKIN:Bang('[!SetOption Handle Text "INVALID FILE"][!UpdateMeter Handle][!Redraw]')
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
      elseif line:sub(1, 2) == 'f ' then
        local v1, v2, v3 = line:match('f%s+(%d+)%s+(%d+)%s+(%d+)')
        f[1][#f[1] + 1], f[2][#f[2] + 1], f[3][#f[3] + 1] = vIdx[tonumber(v1)], vIdx[tonumber(v2)], vIdx[tonumber(v3)]
      end
    end
  end
  file:close()
  -- Fit and center model
  local offsetX, offsetY, offsetZ = (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2
  maxR = ((maxX - offsetX)^2 + (maxY - offsetY)^2 + (maxZ - offsetZ)^2)^0.5
  for i = 1, #v.x do
    v.x[i], v.y[i], v.z[i] = v.x[i] - offsetX, v.y[i] - offsetY, v.z[i] - offsetZ
  end
  -- Generate axial plane circles
  for i = 1, 72 do
    c.x[i], c.y[i] = math.sin(i * 6.28 / 72) * maxR, math.cos(i * 6.28 / 72) * maxR
  end
  Scale(0)
end

function SetPerspective(n, m)
  if m then
    hasMoved, perspective = true, math.floor(m * 0.11) * 0.1
  elseif 0 <= perspective + n and perspective + n <= 1 then
    hasMoved, perspective = true, math.floor((perspective + n) * 10 + 0.5) * 0.1
  else return end
  SKIN:Bang('[!SetOption PerspectiveSlider X '..(perspective * 90)..'r][!SetOption PerspectiveVal Text '..perspective..'][!Update][!WriteKeyValue Variables Perspective '..perspective..' "#@#Settings.inc"]')
end

function SetView(n)
  SKIN:Bang('[!SetOption Render Attr "Fill Color '..(1 < n and '#FaceColor#' or '00000000')..'|Stroke Color #EdgeColor#|StrokeWidth '..(n ~= 2 and '#EdgeThick#' or 0)..'|StrokeLineJoin Round"][!UpdateMeter Render][!SetOptionGroup View MeterStyle sSet|sSetVar][!SetOptionGroup View SolidColor 505050E0][!EnableMouseActionGroup LeftMouseUpAction View][!SetOption View'..n..' MeterStyle sSet|sSetVar|sSetSel][!SetOption View'..n..' SolidColor FF0000][!ClearMouseAction View'..n..' LeftMouseUpAction][!UpdateMeterGroup View][!Redraw][!WriteKeyValue Variables ViewMode '..n..' "#@#Settings.inc"]')
  if viewMode == 0 or n == 0 then
    hasMoved = true
  end
  viewMode = n
  Update()
end

function SetVar(name)
  if (function(set) return set == '' or tonumber(set) and tonumber(set) <= 0 end)(SKIN:GetVariable('Set')) then return end
  SKIN:Bang('[!SetVariable '..name..' "#Set#"][!SetOption Render Attr "Fill Color '..(1 < viewMode and '#FaceColor#' or '00000000')..'|Stroke Color #EdgeColor#|StrokeWidth '..(viewMode ~= 2 and '#EdgeThick#' or 0)..'|StrokeLineJoin Round"][!UpdateMeter Render][!SetOption '..name..'Set Text "#Set#"][!EnableMouseAction Handle MouseLeaveAction][!Update][!WriteKeyValue Variables '..name..' "#Set#" "#@#Settings.inc"]')
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
