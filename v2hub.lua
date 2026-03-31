--[[
    AIM ASSIST - GUI ESTILO SYREXGENESIS
    Funcionalidades:
    - Aimbot (head, pescoço, peito, pernas) com Team Check
    - ESP wallhack (nome, distância, linhas, alcance)
    - FOV circular que segue o mouse (tamanho e transparência ajustáveis)
    - GUI arrastável, redimensionável, com botão LOAD que fecha a interface
--]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Mouse = LocalPlayer:GetMouse()

-- ==================== CONFIGURAÇÕES ====================
local AIMBOT_ENABLED = false
local ESP_ENABLED = false
local SHOW_NAME = true
local SHOW_DISTANCE = true
local ESPLINE_ENABLED = false
local FOV_ENABLED = false
local TEAMCHECK_ENABLED = false
local HOLDING_AIM = false

local AIMBOT_TARGET = "head"          -- "head", "pescoço", "peito", "pernas"
local FOV_RADIUS = 150                -- tamanho do círculo do FOV
local FOV_TRANSPARENCY = 0.5          -- 0 = invisível, 1 = opaco
local ESP_DISTANCE = 200              -- distância máxima do ESP

-- ==================== DRAWING OBJECTS ====================
local fovCircle
do
    local success, circle = pcall(function() return Drawing.new("Circle") end)
    if success and circle then
        fovCircle = circle
        fovCircle.Visible = false
        fovCircle.Radius = FOV_RADIUS
        fovCircle.Thickness = 2
        fovCircle.Color = Color3.fromRGB(255, 255, 255)
        fovCircle.Filled = false
        fovCircle.Transparency = FOV_TRANSPARENCY
    else
        fovCircle = nil
        warn("FOV Circle não suportado pelo executor")
    end
end

local ESPs = {}

local function createESP(plr)
    if not plr or plr == LocalPlayer then return end
    if ESPs[plr] then return end

    ESPs[plr] = {
        Box = Drawing.new("Square"),
        Line = Drawing.new("Line"),
        Name = Drawing.new("Text"),
        Distance = Drawing.new("Text")
    }

    local e = ESPs[plr]
    e.Box.Thickness = 1.5
    e.Box.Filled = false
    e.Line.Thickness = 1
    e.Name.Size = 14
    e.Name.Center = true
    e.Name.Outline = true
    e.Distance.Size = 13
    e.Distance.Center = true
    e.Distance.Outline = true
end

for _, p in ipairs(Players:GetPlayers()) do createESP(p) end
Players.PlayerAdded:Connect(createESP)
Players.PlayerRemoving:Connect(function(plr)
    if ESPs[plr] then
        for _, d in pairs(ESPs[plr]) do d:Remove() end
        ESPs[plr] = nil
    end
end)

-- ==================== UTILITÁRIOS ====================
local function isVisible(part)
    if not part then return false end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    if dir.Magnitude == 0 then return true end
    local ray = Ray.new(origin, dir.Unit * math.clamp(dir.Magnitude, 1, 1000))
    local hit = Workspace:FindPartOnRay(ray, LocalPlayer.Character, false, true)
    return hit and hit:IsDescendantOf(part.Parent)
end

local BLOCKED_TEAMS = {"pm", "pmerj", "bope", "choque", "prf", "pf", "pc", "gcm", "eb", "exército", "polícia militar", "polícia federal", "polícia civil"}

local function isBlocked(plr)
    if not plr then return false end
    if plr.Team == LocalPlayer.Team then return true end
    local leaderstats = plr:FindFirstChild("leaderstats")
    if leaderstats then
        for _, stat in ipairs(leaderstats:GetChildren()) do
            if (stat.Name:lower():find("fac") or stat.Name:lower():find("job") or stat.Name:lower():find("fação")) then
                local val = tostring(stat.Value):lower()
                for _, kw in ipairs(BLOCKED_TEAMS) do
                    if val:find(kw) then return true end
                end
            end
        end
    end
    if plr.Team then
        local teamName = tostring(plr.Team):lower()
        for _, kw in ipairs(BLOCKED_TEAMS) do
            if teamName:find(kw) then return true end
        end
    end
    return false
end

local function getTargetPart(character)
    if AIMBOT_TARGET == "head" then
        return character:FindFirstChild("Head")
    elseif AIMBOT_TARGET == "pescoço" then
        return character:FindFirstChild("Neck") or character:FindFirstChild("UpperTorso")
    elseif AIMBOT_TARGET == "peito" then
        return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
    elseif AIMBOT_TARGET == "pernas" then
        return character:FindFirstChild("LowerTorso") or character:FindFirstChild("HumanoidRootPart")
    end
    return character:FindFirstChild("Head")
end

local function getClosestToMouseFOV()
    if not HOLDING_AIM or not AIMBOT_ENABLED then return nil end
    local mousePos = UserInputService:GetMouseLocation()
    local closest, bestDist = nil, math.huge
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if TEAMCHECK_ENABLED and isBlocked(plr) then continue end
            local targetPart = getTargetPart(plr.Character)
            if targetPart then
                local vec, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
                if onScreen then
                    local distToMouse = (Vector2.new(vec.X, vec.Y) - mousePos).Magnitude
                    if distToMouse < FOV_RADIUS and distToMouse < bestDist and isVisible(targetPart) then
                        closest = targetPart
                        bestDist = distToMouse
                    end
                end
            end
        end
    end
    return closest
end

-- ==================== GUI ESTILO SYREXGENESIS ====================
local ScreenGui, MainFrame, TitleBar
local selectedCard = nil
local aimbotTab, espTab, fovTab
local currentSize = {Width = 878, Height = 550}

-- Cores do tema (baseadas no Z3US/Syrex)
local bgColor = Color3.fromRGB(17, 18, 20)
local cardColor = Color3.fromRGB(27, 29, 37)
local accentColor = Color3.fromRGB(140, 155, 208)
local strokeColor = Color3.fromRGB(26, 29, 37)
local textColor = Color3.fromRGB(255, 255, 255)

local function createCorner(instance, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius)
    corner.Parent = instance
    return corner
end

local function createStroke(instance, thickness, color)
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = thickness
    stroke.Color = color or strokeColor
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = instance
    return stroke
end

-- Cria um card lateral (exatamente como no Syrex)
local function createCard(parent, name, yPos, callback)
    local card = Instance.new("Frame")
    card.Size = UDim2.new(0, 330, 0, 65)
    card.Position = UDim2.new(0.03, 0, yPos, 0)
    card.BackgroundColor3 = cardColor
    card.BackgroundTransparency = 0.9
    card.BorderSizePixel = 0
    card.Parent = parent
    createCorner(card, 25)
    createStroke(card, 1.9)

    local text = Instance.new("TextLabel")
    text.Size = UDim2.new(1, -20, 1, 0)
    text.Position = UDim2.new(0.1, 0, 0, 0)
    text.BackgroundTransparency = 1
    text.Text = name
    text.TextColor3 = textColor
    text.Font = Enum.Font.GothamBold
    text.TextSize = 62
    text.TextScaled = true
    text.TextWrapped = true
    text.TextXAlignment = Enum.TextXAlignment.Left
    text.Parent = card

    card.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            if selectedCard then
                selectedCard:FindFirstChildOfClass("UIStroke").Color = strokeColor
            end
            card:FindFirstChildOfClass("UIStroke").Color = accentColor
            selectedCard = card
            callback()
        end
    end)

    return card
end

-- Botão de toggle (ON/OFF) estilo Syrex
local function createToggleButton(parent, text, yOffset, initialState, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 50)
    frame.Position = UDim2.new(0.5, -140, 0, yOffset)
    frame.BackgroundColor3 = cardColor
    frame.BackgroundTransparency = 0.9
    frame.BorderSizePixel = 0
    frame.Parent = parent
    createCorner(frame, 25)
    createStroke(frame, 1.9)

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0, 160, 1, 0)
    label.Position = UDim2.new(0.05, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = textColor
    label.Font = Enum.Font.Gotham
    label.TextSize = 18
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 80, 0, 35)
    btn.Position = UDim2.new(0.65, 0, 0.15, 0)
    btn.Text = initialState and "ON" or "OFF"
    btn.BackgroundColor3 = initialState and accentColor or Color3.fromRGB(60, 60, 60)
    btn.TextColor3 = textColor
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 16
    btn.BorderSizePixel = 0
    btn.Parent = frame
    createCorner(btn, 20)

    btn.MouseButton1Click:Connect(function()
        local newState = btn.Text ~= "ON"
        btn.Text = newState and "ON" or "OFF"
        btn.BackgroundColor3 = newState and accentColor or Color3.fromRGB(60, 60, 60)
        callback(newState)
    end)

    return frame
end

-- Dropdown estilo Syrex
local function createDropdown(parent, text, yOffset, options, currentValue, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 70)
    frame.Position = UDim2.new(0.5, -140, 0, yOffset)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = textColor
    label.Font = Enum.Font.Gotham
    label.TextSize = 16
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local dropdownBtn = Instance.new("TextButton")
    dropdownBtn.Size = UDim2.new(1, 0, 0, 38)
    dropdownBtn.Position = UDim2.new(0, 0, 0, 30)
    dropdownBtn.Text = currentValue:upper()
    dropdownBtn.BackgroundColor3 = cardColor
    dropdownBtn.BackgroundTransparency = 0.9
    dropdownBtn.TextColor3 = textColor
    dropdownBtn.Font = Enum.Font.GothamBold
    dropdownBtn.TextSize = 14
    dropdownBtn.BorderSizePixel = 0
    dropdownBtn.Parent = frame
    createCorner(dropdownBtn, 20)
    createStroke(dropdownBtn, 1.5)

    local expanded = false
    local dropdownList = nil

    dropdownBtn.MouseButton1Click:Connect(function()
        if expanded then
            if dropdownList then dropdownList:Destroy() end
            expanded = false
        else
            dropdownList = Instance.new("Frame")
            dropdownList.Size = UDim2.new(1, 0, 0, #options * 36)
            dropdownList.Position = UDim2.new(0, 0, 0, 68)
            dropdownList.BackgroundColor3 = bgColor
            dropdownList.BorderSizePixel = 0
            dropdownList.Parent = frame
            createCorner(dropdownList, 16)
            createStroke(dropdownList, 1.5)

            for i, opt in ipairs(options) do
                local optBtn = Instance.new("TextButton")
                optBtn.Size = UDim2.new(1, 0, 0, 36)
                optBtn.Position = UDim2.new(0, 0, 0, (i-1)*36)
                optBtn.Text = opt:upper()
                optBtn.BackgroundColor3 = cardColor
                optBtn.BackgroundTransparency = 0.9
                optBtn.TextColor3 = textColor
                optBtn.Font = Enum.Font.Gotham
                optBtn.TextSize = 13
                optBtn.BorderSizePixel = 0
                optBtn.Parent = dropdownList

                optBtn.MouseButton1Click:Connect(function()
                    callback(opt)
                    dropdownBtn.Text = opt:upper()
                    dropdownList:Destroy()
                    expanded = false
                end)
            end
            expanded = true
        end
    end)

    return frame
end

-- Slider (tamanho e transparência)
local function createSlider(parent, text, yOffset, minVal, maxVal, currentVal, callback, isFloat)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 280, 0, 55)
    frame.Position = UDim2.new(0.5, -140, 0, yOffset)
    frame.BackgroundTransparency = 1
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 0, 22)
    label.Position = UDim2.new(0, 0, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = text .. ": " .. (isFloat and string.format("%.2f", currentVal) or currentVal)
    label.TextColor3 = textColor
    label.Font = Enum.Font.Gotham
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, 0, 0, 4)
    sliderBg.Position = UDim2.new(0, 0, 0, 32)
    sliderBg.BackgroundColor3 = strokeColor
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = frame
    createCorner(sliderBg, 4)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.new((currentVal - minVal) / (maxVal - minVal), 0, 1, 0)
    fill.BackgroundColor3 = accentColor
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    createCorner(fill, 4)

    local handle = Instance.new("Frame")
    handle.Size = UDim2.new(0, 14, 0, 14)
    handle.Position = UDim2.new((currentVal - minVal) / (maxVal - minVal), -7, -5, 0)
    handle.BackgroundColor3 = accentColor
    handle.BorderSizePixel = 0
    handle.Parent = sliderBg
    createCorner(handle, 7)

    local dragging = false

    local function updateSliderFromMouse(mousePos)
        if not sliderBg or not sliderBg.Parent then return end
        local relX = math.clamp(mousePos.X - sliderBg.AbsolutePosition.X, 0, sliderBg.AbsoluteSize.X)
        local newVal = minVal + (relX / sliderBg.AbsoluteSize.X) * (maxVal - minVal)
        if not isFloat then newVal = math.floor(newVal) else newVal = math.round(newVal * 100) / 100 end
        callback(newVal)
        label.Text = text .. ": " .. (isFloat and string.format("%.2f", newVal) or newVal)
        fill.Size = UDim2.new((newVal - minVal) / (maxVal - minVal), 0, 1, 0)
        handle.Position = UDim2.new((newVal - minVal) / (maxVal - minVal), -7, -5, 0)
    end

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSliderFromMouse(input.Position)
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            updateSliderFromMouse(input.Position)
        end
    end)

    RunService.RenderStepped:Connect(function()
        if dragging then
            local mousePos = UserInputService:GetMouseLocation()
            updateSliderFromMouse(mousePos)
        end
    end)

    return frame
end

-- Botões de redimensionamento
local function createResizeButtons(parent)
    local btnSize = 30
    local btnPlus = Instance.new("TextButton")
    btnPlus.Size = UDim2.new(0, btnSize, 0, btnSize)
    btnPlus.Position = UDim2.new(1, -btnSize - 50, 0, 10)
    btnPlus.Text = "+"
    btnPlus.BackgroundColor3 = cardColor
    btnPlus.TextColor3 = textColor
    btnPlus.Font = Enum.Font.GothamBold
    btnPlus.TextSize = 20
    btnPlus.BorderSizePixel = 0
    btnPlus.Parent = parent
    createCorner(btnPlus, 8)

    local btnMinus = Instance.new("TextButton")
    btnMinus.Size = UDim2.new(0, btnSize, 0, btnSize)
    btnMinus.Position = UDim2.new(1, -btnSize - 15, 0, 10)
    btnMinus.Text = "-"
    btnMinus.BackgroundColor3 = cardColor
    btnMinus.TextColor3 = textColor
    btnMinus.Font = Enum.Font.GothamBold
    btnMinus.TextSize = 20
    btnMinus.BorderSizePixel = 0
    btnMinus.Parent = parent
    createCorner(btnMinus, 8)

    local step = 50
    btnPlus.MouseButton1Click:Connect(function()
        currentSize.Width = currentSize.Width + step
        currentSize.Height = currentSize.Height + step
        MainFrame.Size = UDim2.new(0, currentSize.Width, 0, currentSize.Height)
        local pos = MainFrame.Position
        if pos.X.Offset + currentSize.Width > Camera.ViewportSize.X then
            MainFrame.Position = UDim2.new(0, math.max(0, Camera.ViewportSize.X - currentSize.Width), pos.Y.Scale, pos.Y.Offset)
        end
        if pos.Y.Offset + currentSize.Height > Camera.ViewportSize.Y then
            MainFrame.Position = UDim2.new(pos.X.Scale, pos.X.Offset, 0, math.max(0, Camera.ViewportSize.Y - currentSize.Height))
        end
    end)

    btnMinus.MouseButton1Click:Connect(function()
        currentSize.Width = math.max(500, currentSize.Width - step)
        currentSize.Height = math.max(400, currentSize.Height - step)
        MainFrame.Size = UDim2.new(0, currentSize.Width, 0, currentSize.Height)
    end)
end

-- Construção da GUI
local function buildGUI()
    if ScreenGui and ScreenGui.Parent then
        if MainFrame then MainFrame.Visible = true end
        return
    end

    local parentGui = CoreGui or PlayerGui
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "AimAssist"
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = parentGui
    ScreenGui.ResetOnSpawn = false
    ScreenGui.DisplayOrder = 999999
    ScreenGui.IgnoreGuiInset = true

    MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, currentSize.Width, 0, currentSize.Height)
    MainFrame.Position = UDim2.new(0.0883, 0, 0.11, 0)
    MainFrame.BackgroundColor3 = bgColor
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
    createCorner(MainFrame, 25)
    createStroke(MainFrame, 2)

    -- Barra de título arrastável
    TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 50)
    TitleBar.BackgroundTransparency = 1
    TitleBar.Parent = MainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(0.5, 0, 1, 0)
    titleLabel.Position = UDim2.new(0.05, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "CONFIGURAÇÕES"
    titleLabel.TextColor3 = accentColor
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 22
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = TitleBar

    -- Botões de redimensionamento
    createResizeButtons(TitleBar)

    -- Cards laterais
    local cardsContainer = Instance.new("Frame")
    cardsContainer.Size = UDim2.new(0, 330, 1, 0)
    cardsContainer.Position = UDim2.new(0.03, 0, 0, 0)
    cardsContainer.BackgroundTransparency = 1
    cardsContainer.Parent = MainFrame

    local function selectAimbot()
        aimbotTab.Visible = true
        espTab.Visible = false
        fovTab.Visible = false
    end

    local function selectESP()
        aimbotTab.Visible = false
        espTab.Visible = true
        fovTab.Visible = false
    end

    local function selectFOV()
        aimbotTab.Visible = false
        espTab.Visible = false
        fovTab.Visible = true
    end

    local aimbotCard = createCard(cardsContainer, "AIMBOT", 0.0415, selectAimbot)
    local espCard = createCard(cardsContainer, "ESP", 0.17786, selectESP)
    local fovCard = createCard(cardsContainer, "FOV", 0.31422, selectFOV)

    -- Área de configurações (direita)
    local settingsArea = Instance.new("Frame")
    settingsArea.Size = UDim2.new(0, 450, 1, 0)
    settingsArea.Position = UDim2.new(0.5, 0, 0, 0)
    settingsArea.BackgroundTransparency = 1
    settingsArea.Parent = MainFrame

    -- Abas internas
    aimbotTab = Instance.new("Frame")
    aimbotTab.Size = UDim2.new(1, 0, 1, 0)
    aimbotTab.BackgroundTransparency = 1
    aimbotTab.Parent = settingsArea

    espTab = Instance.new("Frame")
    espTab.Size = UDim2.new(1, 0, 1, 0)
    espTab.BackgroundTransparency = 1
    espTab.Visible = false
    espTab.Parent = settingsArea

    fovTab = Instance.new("Frame")
    fovTab.Size = UDim2.new(1, 0, 1, 0)
    fovTab.BackgroundTransparency = 1
    fovTab.Visible = false
    fovTab.Parent = settingsArea

    -- Populate AIMBOT tab
    createToggleButton(aimbotTab, "Aimbot", 30, AIMBOT_ENABLED, function(state)
        AIMBOT_ENABLED = state
    end)

    createToggleButton(aimbotTab, "Team Check", 100, TEAMCHECK_ENABLED, function(state)
        TEAMCHECK_ENABLED = state
    end)

    createDropdown(aimbotTab, "Puxar para:", 170, {"head", "pescoço", "peito", "pernas"}, AIMBOT_TARGET, function(val)
        AIMBOT_TARGET = val
    end)

    -- Populate ESP tab
    createToggleButton(espTab, "ESP", 30, ESP_ENABLED, function(state)
        ESP_ENABLED = state
    end)

    createToggleButton(espTab, "Nome", 100, SHOW_NAME, function(state)
        SHOW_NAME = state
    end)

    createToggleButton(espTab, "Distância", 170, SHOW_DISTANCE, function(state)
        SHOW_DISTANCE = state
    end)

    createToggleButton(espTab, "Linhas", 240, ESPLINE_ENABLED, function(state)
        ESPLINE_ENABLED = state
    end)

    createSlider(espTab, "Distância ESP", 310, 50, 500, ESP_DISTANCE, function(val)
        ESP_DISTANCE = val
    end)

    -- Populate FOV tab
    createToggleButton(fovTab, "FOV", 30, FOV_ENABLED, function(state)
        FOV_ENABLED = state
        if fovCircle then fovCircle.Visible = state end
    end)

    createSlider(fovTab, "Tamanho do FOV", 100, 50, 300, FOV_RADIUS, function(val)
        FOV_RADIUS = val
        if fovCircle then fovCircle.Radius = val end
    end)

    createSlider(fovTab, "Transparência", 170, 0, 1, FOV_TRANSPARENCY, function(val)
        FOV_TRANSPARENCY = val
        if fovCircle then fovCircle.Transparency = val end
    end, true)

    -- Botão LOAD (fecha a GUI)
    local loadBtn = Instance.new("TextButton")
    loadBtn.Size = UDim2.new(0, 405, 0, 62)
    loadBtn.Position = UDim2.new(0.527, 0, 0.656, 0)
    loadBtn.Text = "LOAD"
    loadBtn.BackgroundColor3 = cardColor
    loadBtn.TextColor3 = textColor
    loadBtn.Font = Enum.Font.GothamBold
    loadBtn.TextSize = 30
    loadBtn.TextScaled = true
    loadBtn.BorderSizePixel = 0
    loadBtn.Parent = MainFrame
    createCorner(loadBtn, 25)
    createStroke(loadBtn, 2)

    loadBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    -- Botão fechar (X)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 44, 0, 41)
    closeBtn.Position = UDim2.new(1, -50, 0, 5)
    closeBtn.Text = "X"
    closeBtn.BackgroundTransparency = 1
    closeBtn.TextColor3 = Color3.fromRGB(58, 67, 98)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 30
    closeBtn.TextScaled = true
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = TitleBar
    closeBtn.MouseButton1Click:Connect(function()
        MainFrame.Visible = false
    end)

    -- Texto informativo (semelhante ao Syrex)
    local infoText = Instance.new("TextLabel")
    infoText.Size = UDim2.new(0, 200, 0, 50)
    infoText.Position = UDim2.new(0.645, 0, 0.447, 0)
    infoText.BackgroundTransparency = 1
    infoText.Text = "Aim Assist"
    infoText.TextColor3 = textColor
    infoText.Font = Enum.Font.Gotham
    infoText.TextSize = 34
    infoText.Parent = MainFrame

    local credits = Instance.new("TextLabel")
    credits.Size = UDim2.new(0, 200, 0, 50)
    credits.Position = UDim2.new(0.628, 0, 0.821, 0)
    credits.BackgroundTransparency = 1
    credits.Text = "Aim Assist v2.0"
    credits.TextColor3 = Color3.fromRGB(40, 58, 85)
    credits.Font = Enum.Font.Gotham
    credits.TextSize = 34
    credits.Parent = MainFrame

    -- Ativar card inicial
    aimbotCard:FindFirstChildOfClass("UIStroke").Color = accentColor
    selectedCard = aimbotCard
    selectAimbot()

    -- Sistema de arrasto
    local dragging = false
    local dragStart, frameStart

    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            frameStart = MainFrame.Position
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                frameStart.X.Scale,
                frameStart.X.Offset + delta.X,
                frameStart.Y.Scale,
                frameStart.Y.Offset + delta.Y
            )
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
end

buildGUI()

-- ==================== INPUT ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.RightShift then
        if MainFrame then
            MainFrame.Visible = not MainFrame.Visible
        else
            buildGUI()
        end
    elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
        HOLDING_AIM = true
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        HOLDING_AIM = false
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.25)
    Camera = Workspace.CurrentCamera
end)

-- ==================== LOOP PRINCIPAL ====================
RunService.RenderStepped:Connect(function()
    -- Atualizar FOV seguindo o mouse
    if fovCircle then
        local mousePos = UserInputService:GetMouseLocation()
        fovCircle.Position = mousePos
        fovCircle.Radius = FOV_RADIUS
        fovCircle.Visible = FOV_ENABLED
        fovCircle.Transparency = FOV_TRANSPARENCY
    end

    -- ESP (wallhack)
    for plr, esp in pairs(ESPs) do
        local char = plr.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local hrp = char.HumanoidRootPart
            local dist = (Camera.CFrame.Position - hrp.Position).Magnitude

            if dist <= ESP_DISTANCE then
                local vec, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                if onScreen and vec.Z > 0 then
                    local top = Camera:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3.5, 0))
                    local bottom = Camera:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.5, 0))
                    local height = math.abs(top.Y - bottom.Y)
                    local width = height * 0.6

                    local color = (TEAMCHECK_ENABLED and isBlocked(plr)) and Color3.fromRGB(0, 255, 120) or Color3.fromRGB(255, 60, 60)

                    esp.Box.Size = Vector2.new(width, height)
                    esp.Box.Position = Vector2.new(vec.X - width/2, vec.Y - height/2)
                    esp.Box.Color = color
                    esp.Box.Visible = ESP_ENABLED

                    esp.Line.From = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
                    esp.Line.To = Vector2.new(vec.X, vec.Y)
                    esp.Line.Color = color
                    esp.Line.Visible = ESPLINE_ENABLED

                    esp.Name.Text = SHOW_NAME and plr.Name or ""
                    esp.Name.Position = Vector2.new(vec.X, vec.Y - height/2 - 25)
                    esp.Name.Color = color
                    esp.Name.Visible = ESP_ENABLED and SHOW_NAME

                    esp.Distance.Text = SHOW_DISTANCE and (math.floor(dist) .. "m") or ""
                    esp.Distance.Position = Vector2.new(vec.X, vec.Y - height/2 - 8)
                    esp.Distance.Color = color
                    esp.Distance.Visible = ESP_ENABLED and SHOW_DISTANCE
                else
                    for _, obj in pairs(esp) do obj.Visible = false end
                end
            else
                for _, obj in pairs(esp) do obj.Visible = false end
            end
        else
            for _, obj in pairs(esp) do obj.Visible = false end
        end
    end

    -- Aimbot com FOV baseado no mouse
    local target = getClosestToMouseFOV()
    if target then
        Camera.CFrame = CFrame.lookAt(Camera.CFrame.Position, target.Position)
    end
end)

print("Aim Assist carregado. Pressione SHIFT DIREITO para abrir a GUI.")