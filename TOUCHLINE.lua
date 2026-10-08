-- VARIÁVEIS PRINCIPAIS --
local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ScoredEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Game"):WaitForChild("Information"):WaitForChild("Scored")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

-- CONFIGURAÇÃO DA HITBOX --
local BALL_NAME = "Ball"
local currentMultiplier = 1
local trackedBalls = {}
local heartbeatConnection = nil
local tamanhoChao = 3

local nomeDoJogo = "Unknown"
pcall(function()
    local info = MarketplaceService:GetProductInfo(game.PlaceId)
    if info and info.Name then
        nomeDoJogo = info.Name
    end
end)

--------------------------------------------------------------------------------
-- FUNÇÕES
--------------------------------------------------------------------------------

local floorPart = nil
local floorConnection = nil

local function removeFloor()
    if floorConnection then
        floorConnection:Disconnect()
        floorConnection = nil
    end
    if floorPart then
        floorPart:Destroy()
        floorPart = nil
    end
end

local function ServerHop()
    local placeId = game.PlaceId
    local servers = {}
    local req = request or http_request or (http and http.request) or syn.request
    
    if req then
        local api = "https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100"
        local success, result = pcall(function()
            return HttpService:JSONDecode(req({Url = api}).Body)
        end)
        
        if success and result and result.data then
            for _, server in ipairs(result.data) do
                if server.id ~= game.JobId and server.playing < server.maxPlayers and server.playing > 0 then
                    table.insert(servers, server.id)
                end
            end
        end
    end
    
    if #servers > 0 then
        TeleportService:TeleportToPlaceInstance(placeId, servers[math.random(1, #servers)], LocalPlayer)
    else
        -- Fallback se não achar servidores via API
        TeleportService:Teleport(placeId, LocalPlayer)
    end
end

-- Função para achar a bola mais próxima do LocalPlayer
local function getClosestBall()
    local char = LocalPlayer.Character
    if not char then return nil end
    
    local hrp = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if not hrp then return nil end
    
    local closestBall = nil
    local shortestDistance = math.huge
    
    for part, _ in pairs(trackedBalls) do
        if part and part.Parent then
            local distance = (part.Position - hrp.Position).Magnitude
            if distance < shortestDistance then
                shortestDistance = distance
                closestBall = part
            end
        end
    end
    
    return closestBall
end

local function createFloor()
    -- Garante que limpa algum chão antigo antes de criar outro
    removeFloor()
    
    -- Cria a Part do chão
    floorPart = Instance.new("Part")
    floorPart.Name = "BallFloor_FogoHub"
    floorPart.Anchored = true
    floorPart.CanCollide = true
    floorPart.Material = Enum.Material.SmoothPlastic
    floorPart.Color = Color3.fromRGB(0, 240, 255) -- Cor Cyan neon do tema
    floorPart.Transparency = 0.7
    floorPart.Size = Vector3.new(tamanhoChao, 0.3, tamanhoChao)
    floorPart.Parent = Workspace

    -- Loop de acompanhamento em tempo real
    floorConnection = RunService.RenderStepped:Connect(function()
        if not Fluent.Options.FloorHitbox.Value then
            removeFloor()
            return
        end
        
        -- Pega a bola MAIS PRÓXIMA do jogador
        local activeBall = getClosestBall()

        if activeBall and floorPart then
            -- Atualiza o tamanho com base na variável tamanhoChao do slider
            floorPart.Size = Vector3.new(tamanhoChao, 1.5, tamanhoChao)
            
            -- Posiciona o chão exatamente abaixo da bola mais próxima
            local ballPos = activeBall.Position
            local ballRadius = activeBall.Size.Y / 2
            local floorY = ballPos.Y - ballRadius - (floorPart.Size.Y / 2)
            
            floorPart.CFrame = CFrame.new(ballPos.X, floorY, ballPos.Z)
        else
            -- Esconde o chão temporariamente se não houver bola perto/no mapa
            if floorPart then
                floorPart.Position = Vector3.new(0, -500, 0)
            end
        end
    end)
end

local function addBall(part)
    if part:IsA("BasePart") and not trackedBalls[part] then
        -- Salva as propriedades ORIGINAIS da bola
        trackedBalls[part] = {
            Size = part.Size,
            Transparency = part.Transparency,
            CanCollide = part.CanCollide,
            Material = part.Material
        }
        
        part.AncestryChanged:Connect(function()
            if part.Parent == nil then
                trackedBalls[part] = nil
            end
        end)
    end
end

-- Rastrear bolas existentes e novas
Workspace.DescendantAdded:Connect(function(descendant)
    if descendant.Name == BALL_NAME then
        addBall(descendant)
    end
end)

for _, descendant in pairs(Workspace:GetDescendants()) do
    if descendant.Name == BALL_NAME then
        addBall(descendant)
    end
end

-- Restaura as bolas para o tamanho original exato
local function restoreBalls()
    for part, originalProps in pairs(trackedBalls) do
        if part and part.Parent then
            part.Size = originalProps.Size
            part.Transparency = originalProps.Transparency
            part.CanCollide = originalProps.CanCollide
            part.Material = originalProps.Material
        end
    end
end

-- Atualiza o tamanho com base no tamanho original salvo
local function startHitboxLoop()
    if heartbeatConnection then heartbeatConnection:Disconnect() end
    
    heartbeatConnection = RunService.Heartbeat:Connect(function()
        if not Fluent.Options.HitboxExpand.Value then return end
        
        for part, originalProps in pairs(trackedBalls) do
            if part and part.Parent then
                -- Aplica o multiplicador em cima do tamanho original (1x = tamanho original)
                local targetSize = originalProps.Size * currentMultiplier
                
                if part.Size ~= targetSize then
                    part.Size = targetSize
                end
                if part.Transparency ~= 0.6 then
                    part.Transparency = 0.6
                end
                if part.CanCollide ~= false then
                    part.CanCollide = false
                end
            end
        end
    end)
end

local selectedCelebration = 1
local isCelebrating = false

local function celebrar(celebracao)
    local Event = game:GetService("ReplicatedStorage").Remotes.Game.Celebrate

    Event:FireServer(
        celebracao
    )
end

local function stopHitboxLoop()
    if heartbeatConnection then
        heartbeatConnection:Disconnect()
        heartbeatConnection = nil
    end
    restoreBalls()
end

local speedThread = nil
local originalSpeed = 22 -- Velocidade padrão do Roblox

local function startSpeedLoop()
	-- Para qualquer loop anterior se já estiver rodando
	if speedThread then
		task.cancel(speedThread)
		speedThread = nil
	end

	speedThread = task.spawn(function()
		while true do
			local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
			local hum = char:FindFirstChildOfClass("Humanoid") or char:WaitForChild("Humanoid")
			
			if hum then
				hum.WalkSpeed = 37
			end
			task.wait(0.4)

			if not speedThread then break end

			if hum then
				hum.WalkSpeed = originalSpeed
			end
			task.wait(0.5)
		end
	end)
end

local function stopSpeedLoop()
	if speedThread then
		task.cancel(speedThread)
		speedThread = nil
	end

	local char = LocalPlayer.Character
	if char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.WalkSpeed = originalSpeed
		end
	end
end

local function optimizeGame()
    for g,v in ipairs(workspace:GetChildren()) do
        if v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") then
            v:Destroy()
        end
    end

    settings().Rendering.QualityLevel = Enum.QualityLevel.Level01

    pcall(function()
        UserSettings():GetService("UserGameSettings").SavedQualityLevel = Enum.SavedQualityLevel.Level1
    end)

    local Lighting = game:GetService("Lighting")
    Lighting.GlobalShadows = false
    Lighting.FogEnd = 9e9

    for _, v in pairs(workspace:GetDescendants()) do
        if v:IsA("BasePart") then
            v.Material = Enum.Material.SmoothPlastic
            v.Reflectance = 0
        end
    end

    local j = Instance.new("ColorCorrectionEffect", Lighting)
    j.Saturation = 0.06
    j.Contrast = 0.05
    j.Brightness = -0.04

    workspace.Stadium.Fields["1"].Hitboxes.Barriers.Floor.BrickColor = BrickColor.new("Parsley green")
end

--------------------------------------------------------------------------------
-- INTERFACE (FLUENT WINDOW)
--------------------------------------------------------------------------------

local Window = Fluent:CreateWindow({
    Title = "Fogo Hub - " .. nomeDoJogo,
    SubTitle = "by KiBen",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Theme = "Dark",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- ABAS --
local Tabs = {
    Credits = Window:AddTab({ Title = "Créditos", Icon = "newspaper" }),
    Hitbox = Window:AddTab({ Title = "Hitbox", Icon = "box" }),
    Player = Window:AddTab({ Title = "Jogador", Icon = "user"}),
--    Pontos = Window:AddTab({ Title = "Pontos", Icon = "circle"}),
    Celebr = Window:AddTab({ Title = "Celebrações", Icon = "circle-question-mark"})
}

--------------------------------------------------------------------------------
-- ABA "CRÉDITOS"
--------------------------------------------------------------------------------

Tabs.Credits:AddParagraph({
    Title = "Fogo Hub",
    Content = "Esse hub está em desenvolvimento.\nEspere bugs."
})

Tabs.Credits:AddParagraph({
    Title = "Programadores",
    Content = "Programadores: @KiBenBlox"
})

Tabs.Credits:AddParagraph({
    Title = "Versão",
    Content = "v1.0.2"
})

--------------------------------------------------------------------------------
-- ABA "HITBOX"
--------------------------------------------------------------------------------

local HitboxToggle = Tabs.Hitbox:AddToggle("HitboxExpand", {
    Title = "Ativar expansão de hitbox",
    Default = false
})

HitboxToggle:OnChanged(function(Value)
    if Value then
        startHitboxLoop()
    else
        stopHitboxLoop()
    end
end)

local HitboxSlider = Tabs.Hitbox:AddSlider("MultiHitboxSlider", {
    Title = "Tamanho da hitbox",
    Description = "Multiplica o tamanho da hitbox",
    Default = 1,
    Min = 1,
    Max = 10,
    Rounding = 1.5,
    Callback = function(Value)
        currentMultiplier = Value
    end
})

local floorToggle = Tabs.Hitbox:AddToggle("FloorHitbox", {
    Title = "Chão abaixo da bola",
    Default = false
})

floorToggle:OnChanged(function(Value)
    if Value then
        createFloor()
    else
        removeFloor()
    end
end)

local floorSize = Tabs.Hitbox:AddSlider("FloorSize", {
    Title = "Tamanho do chão",
    Description = "Tamanho do chão abaixo da bola",
    Default = 1,
    Min = 1,
    Max = 30,
    Rounding = 1,
    Callback = function(Value)
        tamanhoChao = Value
    end
})

--------------------------------------------------------------------------------
-- ABA "JOGADOR"
--------------------------------------------------------------------------------

local SpeedTgl = Tabs.Player:AddToggle("SpeedToggle", {
    Title = "Velocidade (CONGELA DEPOIS DE UM TEMPO)",
    Default = false
})

SpeedTgl:OnChanged(function(Value)
    if Value then
        startSpeedLoop()
    else
        stopSpeedLoop()
    end
end)

local OptimizeBtn = Tabs.Player:AddButton({
    Title = "Deixar jogo leve",
    Description = "Otimiza o jogo",
    Callback = function()
        optimizeGame()
    end
})

--------------------------------------------------------------------------------
-- ABA "Pontos"
--------------------------------------------------------------------------------

--[[local autoRejoinEnabled = false
local scoredConnection = nil

local ARG = Tabs.Pontos:AddToggle("ARGTgl", {
    Title = "Auto rejoin quando fazer gol",
    Default = false
})

ARG:OnChanged(function(Value)
    autoRejoinEnabled = Value
end)

-- Conecta no evento do Remote
scoredConnection = ScoredEvent.OnClientEvent:Connect(function(data)
    if not autoRejoinEnabled then return end
    
    if type(data) == "table" and data.Scorer then
        -- Compara se quem fez o gol é a sua conta
        if data.Scorer == LocalPlayer.Name or data.Scorer == LocalPlayer.DisplayName then
            Fluent:Notify({
                Title = "Auto Rejoin",
                Content = "Gol detectado! Reconectando...",
                Duration = 3
            })
            
            task.wait(0.5) -- Pausa rápida para dar tempo de exibir a notificação
            
            ServerHop()
        end
    end
end)]]--

--------------------------------------------------------------------------------
-- ABA "Celebrações"
--------------------------------------------------------------------------------

local Dropdown = Tabs.Celebr:AddDropdown("CelebDropdown", {
    Title = "Selecionar celebração",
    Values = {"1", "2", "3", "4", "5", "6"},
    Default = "1",
    Callback = function(Value)
        selectedCelebration = tonumber(Value)
    end
})

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local Toggle = Tabs.Celebr:AddToggle("CelebToggle", {
    Title = "Celebrar",
    Default = false,
    Callback = function(Value)
        isCelebrating = Value
        
        if isCelebrating then
            task.spawn(function()
                local executedWhileStopped = false

                while isCelebrating do
                    local character = LocalPlayer.Character
                    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
                    
                    if humanoid and humanoid.Health > 0 then
                        local isMoving = humanoid.MoveDirection.Magnitude > 0
                        
                        if isMoving then
                            -- Se tá andando: roda em loop continuo e reseta a trava do parado
                            celebrar(selectedCelebration)
                            executedWhileStopped = false
                            task.wait(0.2)
                        else
                            -- Se tá parado: dispara UMA VEZ só
                            if not executedWhileStopped then
                                celebrar(selectedCelebration)
                                executedWhileStopped = true
                            end
                            task.wait(0.05) -- Checa rapidamente se começou a andar
                        end
                    else
                        task.wait(0.2)
                    end
                end
            end)
        end
    end
})

Window:SelectTab(1)
