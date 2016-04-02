function Initialize()
    point = {} -- array of points
    edge = tonumber(SKIN:GetVariable('Edge')) -- edge interpolation setting
    maxR = 0 -- max radius of model from origin
    xyScale = 0 -- scale of display and model
    dispR = tonumber(SKIN:GetVariable('DispR')) -- half of display width
    screenR = tonumber(SKIN:GetVariable('SCREENAREAWIDTH')) / 2 -- half of screen width
    theta = tonumber(SKIN:GetVariable('Theta')) -- pitch angle
    phi = tonumber(SKIN:GetVariable('Phi')) -- roll angle
    psi = tonumber(SKIN:GetVariable('Psi')) -- yaw angle
    omega = tonumber(SKIN:GetVariable('Omega')) -- delta of yaw angle (angular velocity)
    loadTCoeff = tonumber(SKIN:GetVariable('LoadTCoeff')) -- load time estimation coefficient
    perspective = tonumber(SKIN:GetVariable('Perspective'))
    moveFlag = false
    LoadFile()
    local update = SKIN:GetVariable('Update')
    SKIN:Bang('[!SetOption Edge'..(edge or 0)..'xSet SolidColor FF0000][!SetOption Edge'..(edge or 0)..'xSet MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!SetOption PerspectiveSlider X '..(101 + perspective * 90)..'][!SetOption Omega'..update..' SolidColor FF0000][!SetOption Omega'..update..' LeftMouseUpAction ""][!SetOption Omega'..update..' MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"]')
    if update == '-1' then
        omega = 0
        SKIN:Bang('[!SetOptionGroup Omega FontColor FFFFFF30][!SetOptionGroup Omega SolidColor 50505020][!SetOptionGroup Omega LeftMouseUpAction ""][!SetOptionGroup Omega MouseOverAction []][!SetOptionGroup Omega MouseLeaveAction []]')
    else
        SKIN:Bang('[!SetOption Omega'..omega..' SolidColor FF0000][!SetOption Omega'..omega..' MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"]')
    end
end

function Update()
    if moveFlag or omega ~= 0 then
        moveFlag, psi = false, (psi + omega) % 6.28
        local sinTheta, cosTheta, sinPhi, cosPhi, sinPsi, cosPsi = math.sin(theta), math.cos(theta), math.sin(phi), math.cos(phi), math.sin(psi), math.cos(psi)
        for i = 1, #coord.x do
            local zDepthScale = 1 - ((coord.z[i] * cosPhi - (coord.x[i] * cosPsi + coord.y[i] * sinPsi) * sinPhi) * -sinTheta + (coord.y[i] * cosPsi - coord.x[i] * sinPsi) * cosTheta) / maxR * perspective
            point[i]:SetX((coord.z[i] * sinPhi + (coord.x[i] * cosPsi + coord.y[i] * sinPsi) * cosPhi) * xyScale * zDepthScale + dispR)
            point[i]:SetY(((coord.z[i] * cosPhi - (coord.x[i] * cosPsi + coord.y[i] * sinPsi) * sinPhi) * cosTheta + (coord.y[i] * cosPsi - coord.x[i] * sinPsi) * sinTheta) * -xyScale * zDepthScale + dispR)
        end
        SKIN:Bang('!UpdateMeterGroup P')
    end
end

function Pitch(n)
    moveFlag, theta = true, math.floor((theta + n) % 6.3 * 10 + 0.5) * 0.1
    SKIN:Bang('[!WriteKeyValue Variables Theta '..theta..' "#@#Settings.inc"][!Update]')
end

function Roll(n)
    moveFlag, phi = true, math.floor((phi + n) % 6.3 * 10 + 0.5) * 0.1
    SKIN:Bang('[!WriteKeyValue Variables Phi '..phi..' "#@#Settings.inc"][!Update]')
end

function Yaw(n)
    moveFlag, psi = true, math.floor((psi + n) % 6.3 * 10 + 0.5) * 0.1
    SKIN:Bang('[!WriteKeyValue Variables Psi '..psi..' "#@#Settings.inc"][!Update]')
end

function Scale(n)
    if dispR + n >= 70 and dispR + n <= screenR then
        moveFlag, dispR = true, dispR + n
        xyScale = dispR / maxR
        SKIN:Bang('[!MoveMeter '..dispR..' '..dispR..' Handle][!SetOption Handle W '..(dispR * 2)..'][!SetOption Handle H '..(dispR * 2)..'][!SetOption Handle FontSize '..(dispR * 0.2)..'][!WriteKeyValue Variables DispR '..dispR..' "#@#Settings.inc"][!Update]')
    end
end

function ScanFile()
    local file, p = io.open(SKIN:ReplaceVariables(SKIN:GetVariable('FileSet')), 'r'), 0
    if not file then
        Invalid('PATH')
        return
    end
    SKIN:Bang('!SetOption FileSet Text #*FileSet*#')
    for line in file:lines() do
        if line:sub(1, 2) == 'v ' then
            p = p + 1
        elseif edge and line:sub(1, 2) == 'f ' then
            p = p + edge * 1.5
        end
    end
    file:close()
    if p == 0 then
        Invalid('FILE')
    elseif p <= #point then
        -- Load without refreshing
        SKIN:Bang('[!SetVariable File """#FileSet#"""][!WriteKeyValue Variables File """#FileSet#""" "#@#Settings.inc"][!SetVariable Edge '..(edge or '""')..'][!WriteKeyValue Variables Edge '..(edge or '""')..' "#@#Settings.inc"][!SetOption Handle MouseLeaveAction "[!HideMeterGroup Control][!HideMeterGroup Set][!SetOption Handle SolidColor 00000001][!UpdateMeter Handle][!Redraw]"][!UpdateMeter Handle][!HideMeterGroup Est]')
        LoadFile()
    else
        EstimateLoadTime(p)
    end
end

function Invalid(s)
    SKIN:Bang('[!SetOption FileSet Text "INVALID '..s..'"][!SetOption Handle MouseLeaveAction "[!HideMeterGroup Control][!HideMeterGroup Set][!SetOption Handle SolidColor 00000001][!UpdateMeter Handle][!Redraw]"][!UpdateMeter FileSet][!UpdateMeter Handle][!HideMeterGroup Est][!Redraw]')
end

function EstimateLoadTime(p)
    points = p
    local estT = loadTCoeff * p^2
    SKIN:Bang('[!SetOption FileSet Text #*FileSet*#][!SetOption EstTime Postfix '..string.format('%s.%03u', os.date('!%H:%M:%S', estT), math.fmod(estT, 1) * 1000)..'][!SetOption EstPoints Postfix '..p..'][!SetOption Handle MouseLeaveAction ""][!UpdateMeter FileSet][!UpdateMeter Handle][!UpdateMeterGroup Est][!ShowMeterGroup Est][!Redraw]')
end

function LoadFile()
    coord = {x={}, y={}, z={}} -- array of coordinates
    local file, face, minX, maxX, minY, maxY, minZ, maxZ = io.open(SKIN:ReplaceVariables(SKIN:GetVariable('File')), 'r'), {}, 0, 0, 0, 0, 0, 0
    if not file then
        SKIN:Bang('!SetOption Handle Text "INVALID FILE"')
        if SKIN:GetVariable('File') == '' then
            SKIN:Bang('!SetOption FileSet Text "NO PATH DEFINED"')
        end
        Scale(0)
        return
    end
    for line in file:lines() do
        if line:sub(1, 2) == 'v ' then
            local x, y, z = line:match('v%s-([%d%.%-]-)%s-([%d%.%-]-)%s-([%d%.%-]-)$')
            x, y, z = tonumber(x) or 0, tonumber(y) or 0, tonumber(z) or 0
            coord.x[#coord.x + 1], coord.y[#coord.y + 1], coord.z[#coord.z + 1] = x, y, z
            minX = x < minX and x or minX
            maxX = x > maxX and x or maxX
            minY = y < minY and y or minY
            maxY = y > maxY and y or maxY
            minZ = z < minZ and z or minZ
            maxZ = z > maxZ and z or maxZ
        elseif edge and line:sub(1, 2) == 'f ' then
            local v1, v2, v3 = line:match('f%s-(%d-)%s-(%d-)%s-(%d-)$')
            face[#face + 1] = {tonumber(v1), tonumber(v2), tonumber(v3)}
        end
    end
    file:close()
    -- Edge interpolation
    if edge then
        for f = 1, #face do
            for v = 1, 3 do
                local vNext = v ~= 3 and v + 1 or 1
                for e = 1, edge, 2 do
                    coord.x[#coord.x + 1] = coord.x[face[f][v]] + (coord.x[face[f][vNext]] - coord.x[face[f][v]]) * e / (edge + 1)
                    coord.y[#coord.y + 1] = coord.y[face[f][v]] + (coord.y[face[f][vNext]] - coord.y[face[f][v]]) * e / (edge + 1)
                    coord.z[#coord.z + 1] = coord.z[face[f][v]] + (coord.z[face[f][vNext]] - coord.z[face[f][v]]) * e / (edge + 1)
                end
            end
        end
    end
    -- Generate meters
    if not SKIN:GetMeter(1) or #point ~= 0 and #coord.x > #point then
        GenMeters(#coord.x)
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
    for i = #coord.x + 1, #point do
        point[i]:SetX(0)
        point[i]:SetY(-1)
    end
    -- Fit and center model
    local offsetX, offsetY, offsetZ = (minX + maxX) / 2, (minY + maxY) / 2, (minZ + maxZ) / 2
    maxR = ((maxX - offsetX)^2 + (maxY - offsetY)^2 + (maxZ - offsetZ)^2)^0.5
    for i = 1, #coord.x do
        coord.x[i], coord.y[i], coord.z[i] = coord.x[i] - offsetX, coord.y[i] - offsetY, coord.z[i] - offsetZ
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
        print('Hologram: '..#coord.x..' points')
    end
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
    SKIN:Bang('[!WriteKeyValue Variables Theta 0.5 "#@#Settings.inc"][!WriteKeyValue Variables Phi 0 "#@#Settings.inc"][!WriteKeyValue Variables Psi 0.5 "#@#Settings.inc"][!WriteKeyValue Variables File """#FileSet#""" "#@#Settings.inc"][!WriteKeyValue Variables Edge '..(edge or '""')..' "#@#Settings.inc"][!WriteKeyValue Variables BenchT '..os.clock()..' "#@#Settings.inc"]')
    GenMeters(points)
end

function Cancel()
    SetEdge(tonumber(SKIN:GetVariable('Edge')))
    SKIN:Bang('[!SetOption FileSet Text #*FileSet*#][!HideMeterGroup Est][!SetOption Handle MouseLeaveAction "[!HideMeterGroup Control][!HideMeterGroup Set][!SetOption Handle SolidColor 00000001][!UpdateMeter Handle][!Redraw]"][!UpdateMeter Handle][!Redraw]')
end

function Preload()
    SKIN:Bang('!SetVariable FileSet """#File#"""')
    EstimateLoadTime(tonumber(SKIN:GetVariable('PreloadSet')))
end

function SetEdge(n)
    SKIN:Bang('[!SetOption Edge'..(edge or 0)..'xSet SolidColor 505050E0][!SetOption Edge'..(edge or 0)..'xSet MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor 505050E0][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!SetOption Edge'..(n or 0)..'xSet SolidColor FF0000][!SetOption Edge'..(n or 0)..'xSet MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!WriteKeyValue Variables Edge '..(n or '""')..' "#@#Settings.inc"][!UpdateMeterGroup Edge]')
    edge = tonumber(n)
    ScanFile()
end

function SetPerspective(n, m)
    if m then
        moveFlag, perspective = true, math.floor(m * 0.11) * 0.1
    elseif perspective + n >= 0 and perspective + n <= 1 then
        moveFlag, perspective = true, math.floor((perspective + n) * 10 + 0.5) * 0.1
    else return end
    SKIN:GetMeter('PerspectiveSlider'):SetX(101 + perspective * 90)
    SKIN:Bang('[!SetOption PerspectiveVal Text '..perspective..'][!WriteKeyValue Variables Perspective '..perspective..' "#@#Settings.inc"][!Update]')
end

function SetColor()
    if SKIN:GetVariable('ColorSet') ~= '' then
        SKIN:Bang('[!SetOptionGroup P SolidColor "#ColorSet#"][!SetOption ColorSet Text "#ColorSet#"][!SetVariable Color "#ColorSet#"][!WriteKeyValue Variables Color "#ColorSet#" "#@#Settings.inc"][!SetOption Handle MouseLeaveAction "[!HideMeterGroup Control][!HideMeterGroup Set][!SetOption Handle SolidColor 00000001][!UpdateMeter Handle][!Redraw]"][!UpdateMeter *][!Redraw]')
    end
end

function SetOmega(n)
    -- Set angular velocity
    SKIN:Bang('[!SetOption Omega'..omega..' SolidColor 505050E0][!SetOption Omega'..omega..' MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor 505050E0][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!SetOption Omega'..n..' MouseLeaveAction "[!SetOption #*CURRENTSECTION*# SolidColor FF0000][!UpdateMeter #*CURRENTSECTION*#][!Redraw]"][!WriteKeyValue Variables Omega '..n..' "#@#Settings.inc"][!UpdateMeterGroup Set][!Redraw]')
    omega = tonumber(n)
end
