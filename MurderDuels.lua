-- 1. Подключение фреймворка с GitHub
local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/TheBloxyScripts/BloxyScripts/main/main.lua"))()

-- 2. Создание главного окна хаба
local Window = Library:CreateWindow({
    Name = "BloxyScripts | Hub",
    LoadingTitle = "Загрузка модулей...",
    LoadingSubtitle = "by BloxyScripts (Telegram)",
    FolderName = "MurderDuels"
})

local Hub = Window or getgenv().CustomHub
if not Hub then
    warn("Ошибка: Главный фреймворк не инициализирован!")
    return
end

-- 3. Сервисы и переменные
local plrs = game:GetService("Players")
local r_service = game:GetService("RunService")
local u_input = game:GetService("UserInputService")
local l_plr = plrs.LocalPlayer
local cam = workspace.CurrentCamera

if _G.ext_loaded then
    if _G.unload_esp then _G.unload_esp() end
end
_G.ext_loaded = true

local state = {
    aim = false,
    esp_box = false,
    esp_hp = false,
    esp_dist = false,
    tracers = false,
    fov = 180,
    max_dist = 1000,
    active = true,
    fov_visible = false,
    wall_check = false,
    team_check = true,
    esp_3d_box = false
}

local cache = {}
local fov_ring = Drawing.new("Circle")
local current_target_player = nil

-- Тимчек (проверка команды)
local function is_enemy(player)
    if not state.team_check then return true end
    if player.Team and l_plr.Team then
        return player.Team ~= l_plr.Team
    end
    return true
end

_G.unload_esp = function()
    state.active = false
    for _, item in pairs(cache) do
        if item.line then item.line:Remove() end
        if item.box then item.box:Remove() end
        if item.hpText then item.hpText:Remove() end
        if item.distText then item.distText:Remove() end
        if item.box3d_lines then
            for _, l in ipairs(item.box3d_lines) do l:Remove() end
        end
    end
    table.clear(cache)
    if fov_ring then fov_ring:Remove() end
end

fov_ring.Visible = false
fov_ring.Thickness = 1.5
fov_ring.Color = Color3.fromRGB(255, 0, 0)
fov_ring.Filled = false

local function init_draw(p)
    if cache[p] then return end
    
    local box3d_lines = {}
    for i = 1, 12 do
        local l = Drawing.new("Line")
        l.Thickness = 1.5
        l.Visible = false
        table.insert(box3d_lines, l)
    end

    cache[p] = {
        line = Drawing.new("Line"), 
        box = Drawing.new("Square"),
        hpText = Drawing.new("Text"),
        distText = Drawing.new("Text"),
        box3d_lines = box3d_lines
    }
    cache[p].line.Thickness = 1.5
    cache[p].box.Thickness = 1.5
    cache[p].box.Filled = false
    
    for _, textObj in ipairs({cache[p].hpText, cache[p].distText}) do
        textObj.Size = 13
        textObj.Center = true
        textObj.Outline = true
        textObj.Color = Color3.fromRGB(255, 255, 255)
    end
    cache[p].hpText.Color = Color3.fromRGB(0, 255, 100)
end

local function get_screen_data(pos)
    local screen, visible = cam:WorldToViewportPoint(pos)
    if visible then return Vector2.new(screen.X, screen.Y), true end
    local mid = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local diff = (Vector2.new(screen.X, screen.Y) - mid)
    if diff.Magnitude == 0 then return mid, false end
    local scale = math.min((mid.X - 20) / math.abs(diff.X), (mid.Y - 20) / math.abs(diff.Y))
    return (screen.Z < 0) and (mid - (diff * scale)) or (mid + (diff * scale)), false
end

local function get_best_part(character)
    local parts = {"Head", "UpperTorso", "LowerTorso", "HumanoidRootPart"}
    local bestPart = nil
    local shortestDist = math.huge
    local mid = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    for _, partName in ipairs(parts) do
        local part = character:FindFirstChild(partName)
        if part then
            local screen, visible = cam:WorldToViewportPoint(part.Position)
            if visible then
                local dist = (Vector2.new(screen.X, screen.Y) - mid).Magnitude
                if dist < shortestDist then
                    shortestDist = dist
                    bestPart = part
                end
            end
        end
    end
    return bestPart
end

local function find_best_target()
    local target_hit = nil
    local near = state.fov
    local mid = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local best_player = nil

    for _, p in pairs(plrs:GetPlayers()) do
        if p ~= l_plr and is_enemy(p) and p.Character then
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 then
                local hitPart = get_best_part(p.Character)
                if hitPart then
                    if state.wall_check then
                        local obscuring = cam:GetPartsObscuringTarget({hitPart.Position}, p.Character:GetDescendants())
                        if #obscuring > 0 then continue end
                    end

                    local screen = cam:WorldToViewportPoint(hitPart.Position)
                    local dist = (Vector2.new(screen.X, screen.Y) - mid).Magnitude
                    if dist < near then
                        near = dist
                        target_hit = hitPart
                        best_player = p
                    end
                end
            end
        end
    end
    current_target_player = best_player
    return target_hit
end

local function is_valid_target(player)
    if not player or not player.Character or not is_enemy(player) then return false end
    local char = player.Character
    local humanoid = char:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then return false end

    local hitPart = get_best_part(char)
    if not hitPart then return false end

    if state.wall_check then
        local obscuring = cam:GetPartsObscuringTarget({hitPart.Position}, char:GetDescendants())
        if #obscuring > 0 then return false end
    end

    local screen = cam:WorldToViewportPoint(hitPart.Position)
    local mid = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local dist = (Vector2.new(screen.X, screen.Y) - mid).Magnitude

    return dist <= state.fov, hitPart
end

local loop
loop = r_service.RenderStepped:Connect(function()
    if not state.active then 
        loop:Disconnect()
        return 
    end

    local mid = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    fov_ring.Position = mid
    fov_ring.Radius = state.fov
    fov_ring.Visible = state.aim and state.fov_visible

    if state.aim then
        local lock = nil
        local valid, hit_part = is_valid_target(current_target_player)
        if valid then
            lock = hit_part
            fov_ring.Color = Color3.fromRGB(255, 70, 70)
        else
            current_target_player = nil
            lock = find_best_target()
            fov_ring.Color = Color3.fromRGB(255, 255, 255)
        end

        if lock then 
            cam.CFrame = CFrame.new(cam.CFrame.Position, lock.Position)
        end
    else
        current_target_player = nil
        fov_ring.Color = Color3.fromRGB(255, 255, 255)
    end

    for _, p in pairs(plrs:GetPlayers()) do
        if p ~= l_plr then
            local char = p.Character
            if char and char:FindFirstChild("HumanoidRootPart") and char:FindFirstChild("Humanoid") and char.Humanoid.Health > 0 then
                init_draw(p)
                local data = cache[p]
                local root = char.HumanoidRootPart
                local head = char:FindFirstChild("Head") or root
                local s_pos, is_on_screen = get_screen_data(root.Position)
                local distance = (cam.CFrame.Position - root.Position).Magnitude
                local color = Color3.fromHSV(math.clamp(distance / state.max_dist, 0, 0.33), 1, 1)

                data.line.From = mid
                data.line.To = s_pos
                data.line.Color = color
                data.line.Visible = state.tracers and is_enemy(p)

                if is_on_screen and is_enemy(p) then
                    local headPos = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 0.5, 0))
                    local legPos = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3, 0))
                    local height = math.abs(headPos.Y - legPos.Y)
                    local width = height / 2
                    local boxPos = Vector2.new(s_pos.X - width / 2, headPos.Y)

                    if state.esp_box then
                        data.box.Size = Vector2.new(width, height)
                        data.box.Position = boxPos
                        data.box.Color = color
                        data.box.Visible = true
                    else
                        data.box.Visible = false
                    end

                    if state.esp_3d_box then
                        local cf = root.CFrame
                        local size = Vector3.new(3, 4.5, 3)
                        local corners = {
                            cf * CFrame.new(-size.X, size.Y, -size.Z),
                            cf * CFrame.new(size.X, size.Y, -size.Z),
                            cf * CFrame.new(size.X, size.Y, size.Z),
                            cf * CFrame.new(-size.X, size.Y, size.Z),
                            cf * CFrame.new(-size.X, -size.Y, -size.Z),
                            cf * CFrame.new(size.X, -size.Y, -size.Z),
                            cf * CFrame.new(size.X, -size.Y, size.Z),
                            cf * CFrame.new(-size.X, -size.Y, size.Z)
                        }
                        local screen_corners = {}
                        local all_visible = true
                        for _, cor in ipairs(corners) do
                            local scr, vis = cam:WorldToViewportPoint(cor.Position)
                            if not vis then all_visible = false end
                            table.insert(screen_corners, Vector2.new(scr.X, scr.Y))
                        end

                        local connections = {
                            {1,2}, {2,3}, {3,4}, {4,1},
                            {5,6}, {6,7}, {7,8}, {8,5},
                            {1,5}, {2,6}, {3,7}, {4,8}
                        }

                        for i, conn in ipairs(connections) do
                            local l = data.box3d_lines[i]
                            if all_visible then
                                l.From = screen_corners[conn[1]]
                                l.To = screen_corners[conn[2]]
                                l.Color = color
                                l.Visible = true
                            else
                                l.Visible = false
                            end
                        end
                    else
                        for _, l in ipairs(data.box3d_lines) do l.Visible = false end
                    end

                    if state.esp_hp then
                        data.hpText.Text = "HP: " .. math.floor(char.Humanoid.Health)
                        data.hpText.Position = Vector2.new(s_pos.X, boxPos.Y - 15)
                        data.hpText.Visible = true
                    else
                        data.hpText.Visible = false
                    end

                    if state.esp_dist then
                        data.distText.Text = math.floor(distance) .. "m"
                        data.distText.Position = Vector2.new(s_pos.X, boxPos.Y + height + 2)
                        data.distText.Visible = true
                    else
                        data.distText.Visible = false
                    end
                else 
                    data.box.Visible = false 
                    for _, l in ipairs(data.box3d_lines) do l.Visible = false end
                    data.hpText.Visible = false
                    data.distText.Visible = false
                    data.line.Visible = false
                end
            elseif cache[p] then
                cache[p].line.Visible = false
                cache[p].box.Visible = false
                for _, l in ipairs(cache[p].box3d_lines) do l.Visible = false end
                cache[p].hpText.Visible = false
                cache[p].distText.Visible = false
            end
        end
    end
end)

plrs.PlayerRemoving:Connect(function(p)
    if cache[p] then
        cache[p].line:Remove()
        cache[p].box:Remove()
        cache[p].hpText:Remove()
        cache[p].distText:Remove()
        if cache[p].box3d_lines then
            for _, l in ipairs(cache[p].box3d_lines) do l:Remove() end
        end
        cache[p] = nil
    end
    if current_target_player == p then
        current_target_player = nil
    end
end)

---------------------------------------------------------
-- 4. СОЗДАНИЕ ИНТЕРФЕЙСА (С мультиязычностью EN/RU)
---------------------------------------------------------

-- Вкладка ESP
local EspTab = Hub:CreateTab({EN = "ESP", RU = "ESP"})
EspTab:AddSection({EN = "Visual Features", RU = "Визуальные функции"})

EspTab:AddToggle({EN = "Box ESP", RU = "Боксы (Box ESP)"}, "EspBox", false, function(s) 
    state.esp_box = s 
end)

EspTab:AddToggle({EN = "3D Box ESP", RU = "3D Боксы (3D Box)"}, "Esp3DBox", false, function(s) 
    state.esp_3d_box = s 
end)

EspTab:AddToggle({EN = "Health (HP)", RU = "Здоровье (HP)"}, "EspHp", false, function(s) 
    state.esp_hp = s 
end)

EspTab:AddToggle({EN = "Distance", RU = "Дистанция (Distance)"}, "EspDist", false, function(s) 
    state.esp_dist = s 
end)

EspTab:AddToggle({EN = "Tracers (Lines)", RU = "Трейсеры (Линии)"}, "EspTracers", false, function(s) 
    state.tracers = s 
end)

-- Вкладка Aimbot
local AimTab = Hub:CreateTab({EN = "Aimbot", RU = "Аимбот"})
AimTab:AddSection({EN = "Auto-Lock Settings", RU = "Настройки Auto-Lock"})

AimTab:AddToggle({EN = "Enable Aimbot", RU = "Включить Aimbot"}, "AimActive", false, function(s) 
    state.aim = s 
end)

AimTab:AddToggle({EN = "Team Check", RU = "Тимчек (Team Check)"}, "TeamCheck", true, function(s) 
    state.team_check = s 
end)

AimTab:AddToggle({EN = "Wall Check", RU = "Проверка стен (WallCheck)"}, "AimWallCheck", false, function(s) 
    state.wall_check = s 
end)

AimTab:AddToggle({EN = "Show FOV", RU = "Показывать FOV"}, "AimFovVis", false, function(s) 
    state.fov_visible = s 
end)

AimTab:AddSlider({EN = "FOV Radius", RU = "Радиус FOV"}, "AimFovRad", 50, 400, 180, function(val) 
    state.fov = val 
end)