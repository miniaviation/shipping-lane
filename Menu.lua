local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")

local antiAfkEnabled = true
LocalPlayer.Idled:Connect(function()
    if antiAfkEnabled then
        pcall(function()
            VirtualUser:Button2Down(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
            task.wait(1)
            VirtualUser:Button2Up(Vector2.new(0, 0), Workspace.CurrentCamera.CFrame)
        end)
    end
end)

_G.test = false
_G.ship = nil
_G.tweenSpeed = 10
_G.cargoType = "Bulk" -- Default cargo type
local dockPosition = Vector3.new(276.64, 263.81, 6697.39) -- Port A (Newport)
local playerCoordinates = { Vector3.new(6955.26, 264.64, 13283.02) } -- Port B (Stanley Harbor)

local function orientShip(part, targetPos)
end

local function getShip()
    pcall(function()
        if not LocalPlayer.CurrentShip or not LocalPlayer.CurrentShip.Value then
            warn("No ship found in LocalPlayer.CurrentShip")
            return
        else
            _G.ship = LocalPlayer.CurrentShip.Value
            warn("Ship set to: " .. tostring(_G.ship.Name))
            if not _G.ship.PrimaryPart then
                local seat = _G.ship:FindFirstChild("ControlPanel") and _G.ship.ControlPanel:FindFirstChild("VehicleSeat")
                if seat then
                    _G.ship.PrimaryPart = seat
                    warn("PrimaryPart set to VehicleSeat")
                else
                    local basePart = _G.ship:FindFirstChildOfClass("BasePart")
                    if basePart then
                        _G.ship.PrimaryPart = basePart
                        warn("PrimaryPart set to BasePart: " .. basePart.Name)
                    else
                        warn("No PrimaryPart found for ship")
                    end
                end
            end
            local baseVelocity = _G.ship.PrimaryPart:FindFirstChildOfClass("BodyVelocity")
            if not baseVelocity then
                warn("No BodyVelocity found in PrimaryPart")
                return
            end
            if _G.ship.ControlPanel and _G.ship.ControlPanel.VehicleSeat and LocalPlayer.Character and LocalPlayer.Character.Humanoid then
                _G.ship.ControlPanel.VehicleSeat:Sit(LocalPlayer.Character.Humanoid)
                warn("Player seated in ship")
            else
                warn("Failed to seat player: ControlPanel or VehicleSeat missing")
            end
        end
    end)
end

local function disableCollisions()
    pcall(function()
        if _G.ship then
            for _, v in pairs(_G.ship:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
        if LocalPlayer.Character then
            for _, v in pairs(LocalPlayer.Character:GetDescendants()) do
                if v:IsA("BasePart") then
                    v.CanCollide = false
                end
            end
        end
    end)
end

local function tweenToDock(targetPosition)
    pcall(function()
        if not _G.ship or not _G.ship.PrimaryPart then
            warn("No ship or PrimaryPart for tweenToDock")
            return
        end
        local base = _G.ship.PrimaryPart
        base.Anchored = false
        disableCollisions()
        local dist = (base.Position - targetPosition).Magnitude
        local time = dist / _G.tweenSpeed
        local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
        local tweenValue = Instance.new("CFrameValue")
        tweenValue.Value = _G.ship:GetPrimaryPartCFrame()
        tweenValue.Changed:Connect(function()
            if _G.ship then
                local currentCFrame = _G.ship:GetPrimaryPartCFrame()
                _G.ship:SetPrimaryPartCFrame(CFrame.new(tweenValue.Value.Position) * CFrame.Angles(currentCFrame:ToEulerAnglesXYZ()))
            end
        end)
        local success, err = pcall(function()
            local tween = TweenService:Create(tweenValue, tweenInfo, {Value = CFrame.new(targetPosition)})
            tween:Play()
            tween.Completed:Wait()
        end)
        if not success then
            warn("tweenToDock failed: " .. tostring(err))
            return
        end
        local finalDist = (_G.ship.PrimaryPart.Position - targetPosition).Magnitude
        if finalDist > 10 then
            warn("Ship not close enough to dock: " .. finalDist)
        end
        task.wait(0.5)
    end)
end

local function tweenToCoordinate(targetPosition)
    pcall(function()
        if not _G.ship or not _G.ship.PrimaryPart then
            warn("No ship or PrimaryPart for tweenToCoordinate")
            return
        end
        local base = _G.ship.PrimaryPart
        local baseVelocity = base:FindFirstChildOfClass("BodyVelocity")
        if not baseVelocity then
            warn("No BodyVelocity for tweenToCoordinate")
            return
        end
        local storage = _G.ship:FindFirstChild("Storage")
        if not storage or not storage:FindFirstChild("RemoteEvent") then
            warn("No Storage or RemoteEvent for tweenToCoordinate")
            return
        end
        base.Anchored = false
        disableCollisions()
        local argsGo = { "SetThrottle", _G.tweenSpeed }
        _G.ship.Storage.RemoteEvent:FireServer(unpack(argsGo))
        local dist = (base.Position - targetPosition).Magnitude
        local time = dist / _G.tweenSpeed
        local tweenInfo = TweenInfo.new(time, Enum.EasingStyle.Linear)
        local tweenValue = Instance.new("CFrameValue")
        tweenValue.Value = _G.ship:GetPrimaryPartCFrame()
        tweenValue.Changed:Connect(function()
            if _G.ship then
                local currentCFrame = _G.ship:GetPrimaryPartCFrame()
                _G.ship:SetPrimaryPartCFrame(CFrame.new(tweenValue.Value.Position) * CFrame.Angles(currentCFrame:ToEulerAnglesXYZ()))
            end
        end)
        local success, err = pcall(function()
            local tween = TweenService:Create(tweenValue, tweenInfo, {Value = CFrame.new(targetPosition)})
            tween:Play()
            spawn(function()
                local speed = _G.tweenSpeed / 3
                while tween.PlaybackState == Enum.PlaybackState.Playing do
                    local distance = (_G.ship.PrimaryPart.Position - targetPosition).Magnitude
                    if distance < 100 * speed then
                        local argsStop = { "SetThrottle", 0 }
                        _G.ship.Storage.RemoteEvent:FireServer(unpack(argsStop))
                        break
                    end
                    task.wait(0.1)
                end
            end)
            tween.Completed:Wait()
        end)
        if not success then
            warn("tweenToCoordinate failed: " .. tostring(err))
            local argsStop = { "SetThrottle", 0 }
            _G.ship.Storage.RemoteEvent:FireServer(unpack(argsStop))
            return
        end
        local argsStop = { "SetThrottle", 0 }
        _G.ship.Storage.RemoteEvent:FireServer(unpack(argsStop))
        task.wait(0.5)
        local maxWaitTime = 10
        local elapsed = 0
        repeat
            task.wait(0.1)
            elapsed = elapsed + 0.1
            local distance = (targetPosition - base.Position).Magnitude
            local velocityMag = baseVelocity.Velocity.Magnitude
        until (distance < 5 and velocityMag < 0.1) or elapsed >= maxWaitTime or not _G.test
        if elapsed >= maxWaitTime then
            warn("tweenToCoordinate timed out")
        end
        local finalDist = (_G.ship.PrimaryPart.Position - targetPosition).Magnitude
        if finalDist > 10 then
            warn("Ship not close enough to coordinate: " .. finalDist)
        end
    end)
end

local function dockShip()
    local success, err = pcall(function()
        local args = { [1] = "DockShip" }
        if _G.ship and _G.ship:FindFirstChild("Storage") and _G.ship.Storage:FindFirstChild("RemoteFunction") then
            _G.ship.Storage.RemoteFunction:InvokeServer(unpack(args))
        else
            error("No Storage or RemoteFunction for dockShip")
        end
    end)
    if not success then
        warn("dockShip failed: " .. tostring(err))
        return false
    end
    return true
end

local function undockShip()
    local success, err = pcall(function()
        local args = { [1] = "Undock" }
        if _G.ship and _G.ship:FindFirstChild("Storage") and _G.ship.Storage:FindFirstChild("RemoteEvent") then
            _G.ship.Storage.RemoteEvent:FireServer(unpack(args))
        else
            error("No Storage or RemoteEvent for undockShip")
        end
    end)
    if not success then
        warn("undockShip failed: " .. tostring(err))
        return false
    end
    return true
end

-- Bulk cargo functions (using correct repository)
local function loadBulkPortA()
    local success, err = pcall(function()
        local scriptContent = game:HttpGet("https://raw.githubusercontent.com/miniaviation/bulk/refs/heads/main/load%20in%20newport.lua")
        local scriptFunc, loadErr = loadstring(scriptContent)
        if not scriptFunc then
            error("loadstring failed: " .. tostring(loadErr))
        end
        scriptFunc()
    end)
    if not success then
        warn("Failed to load bulk at Port A: " .. tostring(err))
        return false
    end
    return true
end

local function loadBulkPortB()
    local success, err = pcall(function()
        local scriptContent = game:HttpGet("https://raw.githubusercontent.com/miniaviation/bulk/refs/heads/main/load%20in%20stanley")
        local scriptFunc, loadErr = loadstring(scriptContent)
        if not scriptFunc then
            error("loadstring failed: " .. tostring(loadErr))
        end
        scriptFunc()
    end)
    if not success then
        warn("Failed to load bulk at Port B: " .. tostring(err))
        return false
    end
    return true
end

local function unloadBulkAnyPort()
    local success, err = pcall(function()
        local scriptContent = game:HttpGet("https://raw.githubusercontent.com/miniaviation/bulk/refs/heads/main/unload.lua")
        local scriptFunc, loadErr = loadstring(scriptContent)
        if not scriptFunc then
            error("loadstring failed: " .. tostring(loadErr))
        end
        scriptFunc()
    end)
    if not success then
        warn("Failed to unload bulk: " .. tostring(err))
        return false
    end
    return true
end

-- Container cargo functions
local function loadContainerPortA()
    local success, err = pcall(function()
        local scriptContent = game:HttpGet("https://raw.githubusercontent.com/miniaviation/shipping-lane/refs/heads/main/load%20in%20newport.lua")
        local scriptFunc, loadErr = loadstring(scriptContent)
        if not scriptFunc then
            error("loadstring failed: " .. tostring(loadErr))
        end
        scriptFunc()
    end)
    if not success then
        warn("Failed to load container at Port A: " .. tostring(err))
        return false
    end
    return true
end

local function loadContainerPortB()
    local success, err = pcall(function()
        local scriptContent = game:HttpGet("https://raw.githubusercontent.com/miniaviation/shipping-lane/refs/heads/main/load%20in%20stanley%20habor.lua")
        local scriptFunc, loadErr = loadstring(scriptContent)
        if not scriptFunc then
            error("loadstring failed: " .. tostring(loadErr))
        end
        scriptFunc()
    end)
    if not success then
        warn("Failed to load container at Port B: " .. tostring(err))
        return false
    end
    return true
end

local function unloadContainerAnyPort()
    local success, err = pcall(function()
        local scriptContent = game:HttpGet("https://raw.githubusercontent.com/miniaviation/shipping-lane/refs/heads/main/unload.lua")
        local scriptFunc, loadErr = loadstring(scriptContent)
        if not scriptFunc then
            error("loadstring failed: " .. tostring(loadErr))
        end
        scriptFunc()
    end)
    if not success then
        warn("Failed to unload container: " .. tostring(err))
        return false
    end
    return true
end

-- Updated autofarm loop to handle both cargo types
spawn(function()
    while task.wait() do
        if _G.test then
            pcall(function()
                disableCollisions()
                getShip()
                repeat task.wait() until LocalPlayer.Character and LocalPlayer.Character.Humanoid.SeatPart or not _G.test
                task.wait(5)
                while _G.test do
                    warn("Starting cycle for cargo type: " .. _G.cargoType)
                    tweenToDock(dockPosition)
                    task.wait(2)
                    if not dockShip() then
                        warn("Failed to dock ship at Port A")
                    end
                    task.wait(2)
                    if _G.cargoType == "Bulk" then
                        if not loadBulkPortA() then
                            warn("Failed to load bulk at Port A")
                        else
                            warn("Successfully loaded bulk at Port A")
                        end
                    else
                        if not loadContainerPortA() then
                            warn("Failed to load container at Port A")
                        else
                            warn("Successfully loaded container at Port A")
                        end
                    end
                    task.wait(2)
                    if not undockShip() then
                        warn("Failed to undock ship at Port A")
                    end
                    task.wait(5)
                    for visit = 1, 4 do
                        for i, coord in ipairs(playerCoordinates) do
                            tweenToCoordinate(coord)
                            task.wait(1)
                            task.wait(5)
                        end
                    end
                    for i, coord in ipairs(playerCoordinates) do
                        tweenToCoordinate(coord)
                        task.wait(1)
                        tweenToDock(coord)
                        task.wait(2)
                        if not dockShip() then
                            warn("Failed to dock ship at Port B")
                        else
                            task.wait(2)
                            if _G.cargoType == "Bulk" then
                                if not unloadBulkAnyPort() then
                                    warn("Failed to unload bulk at Port B")
                                end
                                task.wait(60)
                                if not loadBulkPortB() then
                                    warn("Failed to load bulk at Port B")
                                end
                            else
                                if not unloadContainerAnyPort() then
                                    warn("Failed to unload container at Port B")
                                end
                                task.wait(60)
                                if not loadContainerPortB() then
                                    warn("Failed to load container at Port B")
                                end
                            end
                            task.wait(2)
                        end
                        if not undockShip() then
                            warn("Failed to undock ship at Port B")
                        end
                        task.wait(5)
                    end
                    tweenToCoordinate(dockPosition)
                    task.wait(1)
                    tweenToDock(dockPosition)
                    task.wait(2)
                    if not dockShip() then
                        warn("Failed to dock ship at Port A (return)")
                    else
                        task.wait(2)
                        if _G.cargoType == "Bulk" then
                            if not unloadBulkAnyPort() then
                                warn("Failed to unload bulk at Port A (return)")
                            end
                            task.wait(60)
                            if not loadBulkPortA() then
                                warn("Failed to load bulk at Port A (return)")
                            end
                        else
                            if not unloadContainerAnyPort() then
                                warn("Failed to unload container at Port A (return)")
                            end
                            task.wait(60)
                            if not loadContainerPortA() then
                                warn("Failed to load container at Port A (return)")
                            end
                        end
                        task.wait(2)
                    end
                    if not undockShip() then
                        warn("Failed to undock ship at Port A (return)")
                    end
                    task.wait(5)
                end
            end)
        end
    end
end)

-- Updated GUI with cargo type selection
local function createKeyGui()
    local KeyGui = Instance.new("ScreenGui")
    KeyGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    KeyGui.Name = "KeySystemGui"
    KeyGui.ResetOnSpawn = false

    local KeyFrame = Instance.new("Frame")
    KeyFrame.Size = UDim2.new(0, 320, 0, 240)
    KeyFrame.Position = UDim2.new(0.5, -160, 0.5, -120)
    KeyFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
    KeyFrame.BorderSizePixel = 0
    KeyFrame.Active = true
    KeyFrame.Draggable = true
    KeyFrame.Parent = KeyGui

    local KeyCorner = Instance.new("UICorner")
    KeyCorner.CornerRadius = UDim.new(0, 12)
    KeyCorner.Parent = KeyFrame

    local KeyStroke = Instance.new("UIStroke")
    KeyStroke.Thickness = 2
    KeyStroke.Color = Color3.fromRGB(50, 50, 50)
    KeyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    KeyStroke.Parent = KeyFrame

    local KeyTitle = Instance.new("TextLabel")
    KeyTitle.Size = UDim2.new(1, 0, 0, 40)
    KeyTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    KeyTitle.Text = "🔑 Key System"
    KeyTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
    KeyTitle.TextSize = 18
    KeyTitle.Font = Enum.Font.GothamBold
    KeyTitle.TextXAlignment = Enum.TextXAlignment.Center
    KeyTitle.Parent = KeyFrame

    local TitleCorner = Instance.new("UICorner")
    TitleCorner.CornerRadius = UDim.new(0, 12)
    TitleCorner.Parent = KeyTitle

    local KeyInput = Instance.new("TextBox")
    KeyInput.Size = UDim2.new(1, -20, 0, 40)
    KeyInput.Position = UDim2.new(0, 10, 0, 50)
    KeyInput.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
    KeyInput.PlaceholderText = "Enter your key here"
    KeyInput.Text = ""
    KeyInput.TextColor3 = Color3.fromRGB(200, 200, 200)
    KeyInput.TextSize = 14
    KeyInput.Font = Enum.Font.Gotham
    KeyInput.Parent = KeyFrame

    local InputCorner = Instance.new("UICorner")
    InputCorner.CornerRadius = UDim.new(0, 8)
    InputCorner.Parent = KeyInput

    local InputStroke = Instance.new("UIStroke")
    InputStroke.Thickness = 1
    InputStroke.Color = Color3.fromRGB(60, 60, 60)
    InputStroke.Parent = KeyInput

    local SubmitButton = Instance.new("TextButton")
    SubmitButton.Size = UDim2.new(0.48, -15, 0, 40)
    SubmitButton.Position = UDim2.new(0, 10, 0, 100)
    SubmitButton.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
    SubmitButton.Text = "Submit Key"
    SubmitButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SubmitButton.TextSize = 16
    SubmitButton.Font = Enum.Font.GothamBold
    SubmitButton.Parent = KeyFrame

    local SubmitCorner = Instance.new("UICorner")
    SubmitCorner.CornerRadius = UDim.new(0, 8)
    SubmitCorner.Parent = SubmitButton

    local SubmitStroke = Instance.new("UIStroke")
    SubmitStroke.Thickness = 1
    SubmitStroke.Color = Color3.fromRGB(0, 150, 0)
    SubmitStroke.Parent = SubmitButton

    local GetKeyButton = Instance.new("TextButton")
    GetKeyButton.Size = UDim2.new(0.48, -15, 0, 40)
    GetKeyButton.Position = UDim2.new(0.52, 5, 0, 100)
    GetKeyButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    GetKeyButton.Text = "Get Key"
    GetKeyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    GetKeyButton.TextSize = 16
    GetKeyButton.Font = Enum.Font.GothamBold
    GetKeyButton.Parent = KeyFrame

    local GetKeyCorner = Instance.new("UICorner")
    GetKeyCorner.CornerRadius = UDim.new(0, 8)
    GetKeyCorner.Parent = GetKeyButton

    local GetKeyStroke = Instance.new("UIStroke")
    GetKeyStroke.Thickness = 1
    GetKeyStroke.Color = Color3.fromRGB(0, 120, 200)
    GetKeyStroke.Parent = GetKeyButton

    local StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -20, 0, 40)
    StatusLabel.Position = UDim2.new(0, 10, 0, 150)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "Get a key from the link and paste it above"
    StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    StatusLabel.TextSize = 12
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextWrapped = true
    StatusLabel.Parent = KeyFrame

local function validateKey(token)
    local success, response = pcall(function()
        local url = "https://work.ink/_api/v2/token/isValid/" .. token
        local responseStr = game:HttpGet(url)
        return HttpService:JSONDecode(responseStr)
    end)
    if success and response and response.valid then
        return true
    else
        return false
    end
end

    local function loadMainMenu()
        KeyGui:Destroy()
        local ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        ScreenGui.ResetOnSpawn = false

        local Frame = Instance.new("Frame")
        Frame.Size = UDim2.new(0, 240, 0, 280)
        Frame.Position = UDim2.new(0.5, -120, 0.5, -140)
        Frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        Frame.BorderSizePixel = 0
        Frame.Active = true
        Frame.Draggable = true
        Frame.Parent = ScreenGui

        local FrameCorner = Instance.new("UICorner")
        FrameCorner.CornerRadius = UDim.new(0, 12)
        FrameCorner.Parent = Frame

        local FrameStroke = Instance.new("UIStroke")
        FrameStroke.Thickness = 2
        FrameStroke.Color = Color3.fromRGB(50, 50, 50)
        FrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        FrameStroke.Parent = Frame

        local Title = Instance.new("TextLabel")
        Title.Size = UDim2.new(1, 0, 0, 40)
        Title.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        Title.Text = "🚢 Shipping Lane"
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.TextSize = 18
        Title.Font = Enum.Font.GothamBold
        Title.TextXAlignment = Enum.TextXAlignment.Center
        Title.Parent = Frame

        local TitleCorner = Instance.new("UICorner")
        TitleCorner.CornerRadius = UDim.new(0, 12)
        TitleCorner.Parent = Title

        local ToggleButton = Instance.new("TextButton")
        ToggleButton.Size = UDim2.new(1, -20, 0, 40)
        ToggleButton.Position = UDim2.new(0, 10, 0, 50)
        ToggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        ToggleButton.Text = "AUTO: OFF"
        ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        ToggleButton.TextSize = 16
        ToggleButton.Font = Enum.Font.GothamBold
        ToggleButton.Parent = Frame

        local ToggleCorner = Instance.new("UICorner")
        ToggleCorner.CornerRadius = UDim.new(0, 8)
        ToggleCorner.Parent = ToggleButton

        local ToggleStroke = Instance.new("UIStroke")
        ToggleStroke.Thickness = 1
        ToggleStroke.Color = Color3.fromRGB(60, 60, 60)
        ToggleStroke.Parent = ToggleButton

        ToggleButton.MouseButton1Click:Connect(function()
            _G.test = not _G.test
            ToggleButton.Text = "AUTO: " .. (_G.test and "ON" or "OFF")
            ToggleButton.BackgroundColor3 = _G.test and Color3.fromRGB(0, 120, 0) or Color3.fromRGB(50, 50, 50)
        end)

        local HelpButton = Instance.new("TextButton")
        HelpButton.Size = UDim2.new(0, 40, 0, 40)
        HelpButton.Position = UDim2.new(1, -50, 0, 10)
        HelpButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        HelpButton.Text = "?"
        HelpButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        HelpButton.TextSize = 20
        HelpButton.Font = Enum.Font.GothamBold
        HelpButton.Parent = Frame

        local HelpCorner = Instance.new("UICorner")
        HelpCorner.CornerRadius = UDim.new(0, 8)
        HelpCorner.Parent = HelpButton

        local HelpStroke = Instance.new("UIStroke")
        HelpStroke.Thickness = 1
        HelpStroke.Color = Color3.fromRGB(120, 120, 120)
        HelpStroke.Parent = HelpButton

        local SpeedLabel = Instance.new("TextLabel")
        SpeedLabel.Size = UDim2.new(1, -20, 0, 20)
        SpeedLabel.Position = UDim2.new(0, 10, 0, 100)
        SpeedLabel.BackgroundTransparency = 1
        SpeedLabel.Text = "Speed: 10"
        SpeedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        SpeedLabel.TextSize = 14
        SpeedLabel.Font = Enum.Font.Gotham
        SpeedLabel.Parent = Frame

        local SpeedSlider = Instance.new("TextButton")
        SpeedSlider.Size = UDim2.new(1, -20, 0, 20)
        SpeedSlider.Position = UDim2.new(0, 10, 0, 120)
        SpeedSlider.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        SpeedSlider.Text = ""
        SpeedSlider.Parent = Frame

        local SliderCorner = Instance.new("UICorner")
        SliderCorner.CornerRadius = UDim.new(0, 8)
        SliderCorner.Parent = SpeedSlider

        local SliderStroke = Instance.new("UIStroke")
        SliderStroke.Thickness = 1
        SliderStroke.Color = Color3.fromRGB(70, 70, 70)
        SliderStroke.Parent = SpeedSlider

        local SliderFill = Instance.new("Frame")
        SliderFill.Size = UDim2.new(0.2, 0, 1, 0)
        SliderFill.BackgroundColor3 = Color3.fromRGB(0, 120, 200)
        SliderFill.Parent = SpeedSlider

        local FillCorner = Instance.new("UICorner")
        FillCorner.CornerRadius = UDim.new(0, 8)
        FillCorner.Parent = SliderFill

        local SliderValue = 10
        local function updateSpeed(value)
            SliderValue = value
            _G.tweenSpeed = SliderValue
            SpeedLabel.Text = "Speed: " .. SliderValue
            SliderFill.Size = UDim2.new((value - 5) / 45, 0, 1, 0)
        end

        SpeedSlider.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                local connection
                connection = UserInputService.InputChanged:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
                        local relativeX = math.clamp((input.Position.X - SpeedSlider.AbsolutePosition.X) / SpeedSlider.AbsoluteSize.X, 0, 1)
                        local newValue = math.floor(5 + relativeX * 45)
                        updateSpeed(newValue)
                    end
                end)
                UserInputService.InputEnded:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        connection:Disconnect()
                    end
                end)
            end
        end)

        updateSpeed(10)

        -- Dropdown Menu for Cargo Type
        local DropdownLabel = Instance.new("TextLabel")
        DropdownLabel.Size = UDim2.new(1, -20, 0, 20)
        DropdownLabel.Position = UDim2.new(0, 10, 0, 150)
        DropdownLabel.BackgroundTransparency = 1
        DropdownLabel.Text = "Cargo Type: Bulk"
        DropdownLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        DropdownLabel.TextSize = 14
        DropdownLabel.Font = Enum.Font.Gotham
        DropdownLabel.Parent = Frame

        local DropdownButton = Instance.new("TextButton")
        DropdownButton.Size = UDim2.new(1, -20, 0, 40)
        DropdownButton.Position = UDim2.new(0, 10, 0, 170)
        DropdownButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        DropdownButton.Text = "Select Cargo Type"
        DropdownButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        DropdownButton.TextSize = 16
        DropdownButton.Font = Enum.Font.GothamBold
        DropdownButton.Parent = Frame

        local DropdownCorner = Instance.new("UICorner")
        DropdownCorner.CornerRadius = UDim.new(0, 8)
        DropdownCorner.Parent = DropdownButton

        local DropdownStroke = Instance.new("UIStroke")
        DropdownStroke.Thickness = 1
        DropdownStroke.Color = Color3.fromRGB(60, 60, 60)
        DropdownStroke.Parent = DropdownButton

        local DropdownList = Instance.new("Frame")
        DropdownList.Size = UDim2.new(1, -20, 0, 80)
        DropdownList.Position = UDim2.new(0, 10, 0, 210)
        DropdownList.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        DropdownList.Visible = false
        DropdownList.Parent = Frame

        local ListCorner = Instance.new("UICorner")
        ListCorner.CornerRadius = UDim.new(0, 8)
        ListCorner.Parent = DropdownList

        local ListStroke = Instance.new("UIStroke")
        ListStroke.Thickness = 1
        ListStroke.Color = Color3.fromRGB(60, 60, 60)
        ListStroke.Parent = DropdownList

        local BulkOption = Instance.new("TextButton")
        BulkOption.Size = UDim2.new(1, -10, 0, 35)
        BulkOption.Position = UDim2.new(0, 5, 0, 5)
        BulkOption.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        BulkOption.Text = "Bulk"
        BulkOption.TextColor3 = Color3.fromRGB(255, 255, 255)
        BulkOption.TextSize = 14
        BulkOption.Font = Enum.Font.Gotham
        BulkOption.Parent = DropdownList

        local BulkCorner = Instance.new("UICorner")
        BulkCorner.CornerRadius = UDim.new(0, 6)
        BulkCorner.Parent = BulkOption

        local ContainerOption = Instance.new("TextButton")
        ContainerOption.Size = UDim2.new(1, -10, 0, 35)
        ContainerOption.Position = UDim2.new(0, 5, 0, 40)
        ContainerOption.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        ContainerOption.Text = "Container"
        ContainerOption.TextColor3 = Color3.fromRGB(255, 255, 255)
        ContainerOption.TextSize = 14
        ContainerOption.Font = Enum.Font.Gotham
        ContainerOption.Parent = DropdownList

        local ContainerCorner = Instance.new("UICorner")
        ContainerCorner.CornerRadius = UDim.new(0, 6)
        ContainerCorner.Parent = ContainerOption

        local Status = Instance.new("TextLabel")
        Status.Size = UDim2.new(1, -20, 0, 40)
        Status.Position = UDim2.new(0, 10, 0, 230)
        Status.BackgroundTransparency = 1
        Status.Text = "Status: Ready (Small " .. _G.cargoType .. " Carrier)"
        Status.TextColor3 = Color3.fromRGB(0, 255, 0)
        Status.TextSize = 12
        Status.Font = Enum.Font.Gotham
        Status.TextWrapped = true
        Status.Parent = Frame

        -- Dropdown logic
        local function toggleDropdown()
            DropdownList.Visible = not DropdownList.Visible
            DropdownButton.Text = DropdownList.Visible and "Close" or "Select Cargo Type"
        end

        local function selectCargoType(cargoType)
            _G.cargoType = cargoType
            DropdownLabel.Text = "Cargo Type: " .. cargoType
            DropdownList.Visible = false
            DropdownButton.Text = "Select Cargo Type"
            Status.Text = _G.test and "Status: Running Autofarm Cycle..." or "Status: Ready (Small " .. cargoType .. " Carrier)"
        end

        DropdownButton.MouseButton1Click:Connect(toggleDropdown)
        BulkOption.MouseButton1Click:Connect(function() selectCargoType("Bulk") end)
        ContainerOption.MouseButton1Click:Connect(function() selectCargoType("Container") end)

        local function createHelpGui()
            local HelpGui = Instance.new("ScreenGui")
            HelpGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
            HelpGui.Name = "HelpGui"
            HelpGui.ResetOnSpawn = false

            local HelpFrame = Instance.new("Frame")
            HelpFrame.Size = UDim2.new(0, 300, 0, 200)
            HelpFrame.Position = UDim2.new(0.5, -150, 0.5, -100)
            HelpFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
            HelpFrame.BorderSizePixel = 0
            HelpFrame.Active = true
            HelpFrame.Parent = HelpGui

            local HelpFrameCorner = Instance.new("UICorner")
            HelpFrameCorner.CornerRadius = UDim.new(0, 12)
            HelpFrameCorner.Parent = HelpFrame

            local HelpFrameStroke = Instance.new("UIStroke")
            HelpFrameStroke.Thickness = 2
            HelpFrameStroke.Color = Color3.fromRGB(50, 50, 50)
            HelpFrameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            HelpFrameStroke.Parent = HelpFrame

            local HelpTitle = Instance.new("TextLabel")
            HelpTitle.Size = UDim2.new(1, 0, 0, 40)
            HelpTitle.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
            HelpTitle.Text = "📖 Help"
            HelpTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
            HelpTitle.TextSize = 18
            HelpTitle.Font = Enum.Font.GothamBold
            HelpTitle.TextXAlignment = Enum.TextXAlignment.Center
            HelpTitle.Parent = HelpFrame

            local HelpTitleCorner = Instance.new("UICorner")
            HelpTitleCorner.CornerRadius = UDim.new(0, 12)
            HelpTitleCorner.Parent = HelpTitle

            local CloseButton = Instance.new("TextButton")
            CloseButton.Size = UDim2.new(0, 30, 0, 30)
            CloseButton.Position = UDim2.new(1, -35, 0, 5)
            CloseButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
            CloseButton.Text = "X"
            CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            CloseButton.TextSize = 16
            CloseButton.Font = Enum.Font.GothamBold
            CloseButton.Parent = HelpFrame

            local CloseCorner = Instance.new("UICorner")
            CloseCorner.CornerRadius = UDim.new(0, 8)
            CloseCorner.Parent = CloseButton

            local CloseStroke = Instance.new("UIStroke")
            CloseStroke.Thickness = 1
            CloseStroke.Color = Color3.fromRGB(220, 0, 0)
            CloseStroke.Parent = CloseButton

            local HelpText = Instance.new("TextLabel")
            HelpText.Size = UDim2.new(1, -20, 0, 80)
            HelpText.Position = UDim2.new(0, 10, 0, 50)
            HelpText.BackgroundTransparency = 1
            HelpText.Text = "Spawn at Stanley Harbor, select cargo type, set speed, and let the script handle the rest."
            HelpText.TextColor3 = Color3.fromRGB(200, 200, 200)
            HelpText.TextSize = 14
            HelpText.Font = Enum.Font.Gotham
            HelpText.TextWrapped = true
            HelpText.TextXAlignment = Enum.TextXAlignment.Center
            HelpText.Parent = HelpFrame

            local DiscordButton = Instance.new("TextButton")
            DiscordButton.Size = UDim2.new(1, -20, 0, 40)
            DiscordButton.Position = UDim2.new(0, 10, 0, 140)
            DiscordButton.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
            DiscordButton.Text = "Join Discord"
            DiscordButton.TextColor3 = Color3.fromRGB(255, 255, 255)
            DiscordButton.TextSize = 16
            DiscordButton.Font = Enum.Font.GothamBold
            DiscordButton.Parent = HelpFrame

            local DiscordCorner = Instance.new("UICorner")
            DiscordCorner.CornerRadius = UDim.new(0, 8)
            DiscordCorner.Parent = DiscordButton

            local DiscordStroke = Instance.new("UIStroke")
            DiscordStroke.Thickness = 1
            DiscordStroke.Color = Color3.fromRGB(100, 115, 255)
            DiscordStroke.Parent = DiscordButton

            local HelpStatus = Instance.new("TextLabel")
            HelpStatus.Size = UDim2.new(1, -20, 0, 20)
            HelpStatus.Position = UDim2.new(0, 10, 0, 185)
            HelpStatus.BackgroundTransparency = 1
            HelpStatus.Text = "Support or report bugs in Discord"
            HelpStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
            HelpStatus.TextSize = 12
            HelpStatus.Font = Enum.Font.Gotham
            HelpStatus.TextWrapped = true
            HelpStatus.Parent = HelpFrame

            CloseButton.MouseButton1Click:Connect(function()
                HelpGui:Destroy()
            end)

            DiscordButton.MouseButton1Click:Connect(function()
                pcall(function()
                    setclipboard("https://discord.gg/yvtdKjuanU")
                    HelpStatus.Text = "Link copied!"
                    HelpStatus.TextColor3 = Color3.fromRGB(0, 255, 0)
                    task.wait(2)
                    HelpStatus.Text = "Support or report bugs in Discord"
                    HelpStatus.TextColor3 = Color3.fromRGB(200, 200, 200)
                end)
            end)

            local function addHoverEffect(button)
                local originalColor = button.BackgroundColor3
                button.MouseEnter:Connect(function()
                    button.BackgroundColor3 = Color3.fromRGB(
                        math.min(originalColor.R * 255 + 20, 255),
                        math.min(originalColor.G * 255 + 20, 255),
                        math.min(originalColor.B * 255 + 20, 255)
                    )
                end)
                button.MouseLeave:Connect(function()
                    button.BackgroundColor3 = originalColor
                end)
            end

            addHoverEffect(CloseButton)
            addHoverEffect(DiscordButton)
        end

        HelpButton.MouseButton1Click:Connect(createHelpGui)

        spawn(function()
            while task.wait(1) do
                if _G.test then
                    Status.Text = "Status: Running Autofarm Cycle..."
                    Status.TextColor3 = Color3.fromRGB(255, 255, 0)
                else
                    Status.Text = "Status: Ready (Small " .. _G.cargoType .. " Carrier)"
                    Status.TextColor3 = Color3.fromRGB(0, 255, 0)
                end
            end
        end)

        local function addHoverEffect(button)
            local originalColor = button.BackgroundColor3
            button.MouseEnter:Connect(function()
                button.BackgroundColor3 = Color3.fromRGB(
                    math.min(originalColor.R * 255 + 20, 255),
                    math.min(originalColor.G * 255 + 20, 255),
                    math.min(originalColor.B * 255 + 20, 255)
                )
            end)
            button.MouseLeave:Connect(function()
                button.BackgroundColor3 = originalColor
            end)
        end

        addHoverEffect(ToggleButton)
        addHoverEffect(HelpButton)
        addHoverEffect(DropdownButton)
        addHoverEffect(BulkOption)
        addHoverEffect(ContainerOption)
    end

    local function addHoverEffect(button)
        local originalColor = button.BackgroundColor3
        button.MouseEnter:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(
                math.min(originalColor.R * 255 + 20, 255),
                math.min(originalColor.G * 255 + 20, 255),
                math.min(originalColor.B * 255 + 20, 255)
            )
        end)
        button.MouseLeave:Connect(function()
            button.BackgroundColor3 = originalColor
        end)
    end

    addHoverEffect(SubmitButton)
    addHoverEffect(GetKeyButton)

    SubmitButton.MouseButton1Click:Connect(function()
        local token = KeyInput.Text
        if token == "" then
            StatusLabel.Text = "Please enter a key"
            StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            return
        end
        StatusLabel.Text = "Validating key..."
        StatusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
        task.wait(0.5)
        local isValid = validateKey(token)
        if isValid then
            StatusLabel.Text = "Key valid! Loading menu..."
            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            task.wait(1)
            loadMainMenu()
        else
            StatusLabel.Text = "Invalid key. Try again."
            StatusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            KeyInput.Text = ""
        end
    end)

    GetKeyButton.MouseButton1Click:Connect(function()
        pcall(function()
            setclipboard("workink.net/27bz/vo553m9s")
            StatusLabel.Text = "Link copied! Paste it in your browser."
            StatusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            task.wait(2)
            StatusLabel.Text = "Get a key from the link and paste it above"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        end)
    end)
end

createKeyGui()
