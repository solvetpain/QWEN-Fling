--[[
    QWEN Terminal v10.3
    DELETE - toggle menu
    Right-click toggle = set bind
    Backspace = remove bind
]]

for _, gui in pairs(game.CoreGui:GetChildren()) do
    if gui.Name:find("QWEN") then pcall(function() gui:Destroy() end) end
end
if game:GetService("Lighting"):FindFirstChild("QWENBlur") then
    game:GetService("Lighting").QWENBlur:Destroy()
end

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RS = game:GetService("RunService")
local TS = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local Lighting = game:GetService("Lighting")

local LP = Players.LocalPlayer
local Mouse = LP:GetMouse()
local Camera = workspace.CurrentCamera

local Running = true
local MenuOpen = false
local bindPopupActive = false
local currentBindPopup = nil
local StartTime = os.time()
local blurEffect = nil
local settingsOpen = false

local State = {
    Speed=16,JumpPower=50,FlySpeed=50,
    TpTool=false,Noclip=false,Fly=false,
    ESP=false,FlingDuration=3,
}

local ToggleStateMap = {
    ["TP Tool"]="TpTool",["Noclip"]="Noclip",
    ["Fly"]="Fly",["ESP Players"]="ESP",
}

local SAVE_KEY = "QWENv10"
local Binds = {}
local bindLabels = {}
local allConnections = {}
local toggleCallbacks = {}
local toggleSetters = {}
local activeBindIndicators = {}

local noclipConnection = nil
local flyBV,flyBG,flyConnection = nil,nil,nil
local espHighlights = {}
local espBillboards = {}
local tpToolConnection = nil

local fpsValue = 60
local fpsFrameCount = 0
local fpsLastTime = tick()
local activeSliderDrag = nil

local FlingActive = false
local SelectedFlingTargets = {}
getgenv().OldPos = nil
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local voidActive = false
local voidConnection = nil
local voidYOffset = -150
local voidTargetY = nil
local voidSavedPos = nil

local function SaveSettings()
    local data={};for k,v in pairs(State) do data[k]=v end;data.Binds=Binds
    pcall(function() writefile(SAVE_KEY..".json",HttpService:JSONEncode(data)) end)
end

local function LoadSettings()
    local ok,r=pcall(function() if isfile and isfile(SAVE_KEY..".json") then return HttpService:JSONDecode(readfile(SAVE_KEY..".json")) end end)
    if ok and r then for k,v in pairs(r) do if k=="Binds" then if type(v)=="table" then Binds=v end elseif State[k]~=nil then State[k]=v end end end
end
LoadSettings()

local C = {
    bg=Color3.fromRGB(18,18,22),bgFloat=Color3.fromRGB(24,24,30),
    surface=Color3.fromRGB(30,30,38),surfaceHov=Color3.fromRGB(40,40,50),
    card=Color3.fromRGB(34,34,42),cardHov=Color3.fromRGB(44,44,54),
    cardActive=Color3.fromRGB(38,38,48),
    border=Color3.fromRGB(50,50,62),borderLight=Color3.fromRGB(65,65,78),
    text=Color3.fromRGB(235,235,242),textSec=Color3.fromRGB(160,160,178),
    textMuted=Color3.fromRGB(90,90,110),
    accent=Color3.fromRGB(120,160,255),accentDim=Color3.fromRGB(70,95,170),
    toggleOn=Color3.fromRGB(120,160,255),toggleOff=Color3.fromRGB(50,50,62),
    knobOn=Color3.fromRGB(18,18,22),knobOff=Color3.fromRGB(130,130,148),
    danger=Color3.fromRGB(255,75,75),dangerBg=Color3.fromRGB(50,22,26),
    success=Color3.fromRGB(75,220,120),successBg=Color3.fromRGB(22,45,32),
    warning=Color3.fromRGB(255,190,60),warningBg=Color3.fromRGB(50,42,18),
    shadow=Color3.fromRGB(0,0,0),
}

local function Corner(p,r) local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,r or 8);c.Parent=p;return c end
local function Stroke(p,col,t,trans) local s=Instance.new("UIStroke");s.Color=col or C.border;s.Thickness=t or 1;s.Transparency=trans or 0;s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;s.Parent=p;return s end
local function Tween(o,pr,d,style,dir) if not o or not o.Parent then return end;pcall(function() TS:Create(o,TweenInfo.new(d or 0.25,style or Enum.EasingStyle.Quint,dir or Enum.EasingDirection.Out),pr):Play() end) end
local function Smooth(o,pr,d) Tween(o,pr,d or 0.3,Enum.EasingStyle.Exponential,Enum.EasingDirection.Out) end
local function Bounce(o,pr,d) Tween(o,pr,d or 0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out) end
local function GetHRP() local c=LP.Character;return c and c:FindFirstChild("HumanoidRootPart") end
local function GetHum() local c=LP.Character;return c and c:FindFirstChildOfClass("Humanoid") end
local function FormatTime(s) return string.format("%02d:%02d:%02d",math.floor(s/3600),math.floor((s%3600)/60),s%60) end

local function SetBlur(size)
    if not blurEffect then blurEffect=Instance.new("BlurEffect");blurEffect.Name="QWENBlur";blurEffect.Size=0;blurEffect.Parent=Lighting end
    Tween(blurEffect,{Size=size},0.4)
end
local function RemoveBlur()
    if blurEffect then Tween(blurEffect,{Size=0},0.3);task.delay(0.3,function() if blurEffect then blurEffect:Destroy() end;blurEffect=nil end) end
end

table.insert(allConnections,RS.RenderStepped:Connect(function() fpsFrameCount+=1;local now=tick();if now-fpsLastTime>=1 then fpsValue=math.floor(fpsFrameCount/(now-fpsLastTime));fpsFrameCount=0;fpsLastTime=now end end))

local function Ripple(button,color)
    button.ClipsDescendants=true
    button.MouseButton1Click:Connect(function()
        local r=Instance.new("Frame");r.Size=UDim2.new(0,0,0,0);r.Position=UDim2.new(0.5,0,0.5,0);r.AnchorPoint=Vector2.new(0.5,0.5);r.BackgroundColor3=color or C.accent;r.BackgroundTransparency=0.7;r.BorderSizePixel=0;r.ZIndex=button.ZIndex+1;r.Parent=button;Corner(r,999)
        local ms=math.max(button.AbsoluteSize.X,button.AbsoluteSize.Y)*2.5
        Tween(r,{Size=UDim2.new(0,ms,0,ms),BackgroundTransparency=1},0.55,Enum.EasingStyle.Quad)
        task.delay(0.6,function() pcall(function() r:Destroy() end) end)
    end)
end

-- NOTIFICATIONS
local NotifSG=Instance.new("ScreenGui");NotifSG.Name="QWENNotif";NotifSG.Parent=game.CoreGui;NotifSG.ResetOnSpawn=false;NotifSG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local NotifContainer=Instance.new("Frame");NotifContainer.Size=UDim2.new(0,300,1,-20);NotifContainer.Position=UDim2.new(1,-316,0,10);NotifContainer.BackgroundTransparency=1;NotifContainer.Parent=NotifSG
local nLay=Instance.new("UIListLayout",NotifContainer);nLay.Padding=UDim.new(0,8);nLay.VerticalAlignment=Enum.VerticalAlignment.Bottom;nLay.SortOrder=Enum.SortOrder.LayoutOrder
Instance.new("UIPadding",NotifContainer).PaddingBottom=UDim.new(0,16)
local notifOrder=0

local function Notify(title,message,duration,nType)
    duration=duration or 3;nType=nType or "info";notifOrder+=1
    local cols={info={bar=C.accent,bg=C.bgFloat},success={bar=C.success,bg=C.successBg},error={bar=C.danger,bg=C.dangerBg},warning={bar=C.warning,bg=C.warningBg}}
    local col=cols[nType] or cols.info
    local notif=Instance.new("Frame");notif.Size=UDim2.new(1,0,0,0);notif.BackgroundColor3=col.bg;notif.BackgroundTransparency=0.05;notif.BorderSizePixel=0;notif.ClipsDescendants=true;notif.LayoutOrder=notifOrder;notif.Parent=NotifContainer;Corner(notif,10);Stroke(notif,C.border,1,0.5)
    local bar=Instance.new("Frame");bar.Size=UDim2.new(0,3,1,-16);bar.Position=UDim2.new(0,10,0,8);bar.BackgroundColor3=col.bar;bar.BorderSizePixel=0;bar.Parent=notif;Corner(bar,2)
    local tL=Instance.new("TextLabel");tL.Size=UDim2.new(1,-36,0,16);tL.Position=UDim2.new(0,22,0,10);tL.BackgroundTransparency=1;tL.Font=Enum.Font.GothamBold;tL.Text=title;tL.TextColor3=C.text;tL.TextSize=11;tL.TextXAlignment=Enum.TextXAlignment.Left;tL.Parent=notif
    local mL=Instance.new("TextLabel");mL.Size=UDim2.new(1,-36,0,16);mL.Position=UDim2.new(0,22,0,28);mL.BackgroundTransparency=1;mL.Font=Enum.Font.Gotham;mL.Text=message;mL.TextColor3=C.textSec;mL.TextSize=10;mL.TextXAlignment=Enum.TextXAlignment.Left;mL.TextWrapped=true;mL.Parent=notif
    local pBg=Instance.new("Frame");pBg.Size=UDim2.new(1,-28,0,2);pBg.Position=UDim2.new(0,14,1,-7);pBg.BackgroundColor3=C.toggleOff;pBg.BorderSizePixel=0;pBg.Parent=notif;Corner(pBg,1)
    local pFi=Instance.new("Frame");pFi.Size=UDim2.new(1,0,1,0);pFi.BackgroundColor3=col.bar;pFi.BorderSizePixel=0;pFi.Parent=pBg;Corner(pFi,1)
    notif.Position=UDim2.new(1,20,0,0)
    Bounce(notif,{Size=UDim2.new(1,0,0,56),Position=UDim2.new(0,0,0,0)},0.4)
    Tween(pFi,{Size=UDim2.new(0,0,1,0)},duration,Enum.EasingStyle.Linear)
    task.delay(duration,function() Smooth(notif,{Position=UDim2.new(1,20,0,0),BackgroundTransparency=1},0.3);task.delay(0.35,function() pcall(function() notif:Destroy() end) end) end)
end

-- ══════════════════════════════════════
-- IMPROVED FLING ENGINE (handles fast players)
-- ══════════════════════════════════════
local function SkidFling(TargetPlayer, duration)
    if not Running or not FlingActive then return end
    duration = duration or State.FlingDuration or 3

    local Character = LP.Character
    if not Character then return end
    local Humanoid = Character:FindFirstChildOfClass("Humanoid")
    if not Humanoid then return end
    local RootPart = Humanoid.RootPart
    if not RootPart then return end

    local TCharacter = TargetPlayer.Character
    if not TCharacter then return end
    local THumanoid = TCharacter:FindFirstChildOfClass("Humanoid")
    local TRootPart = THumanoid and THumanoid.RootPart
    local THead = TCharacter:FindFirstChild("Head")
    local Accessory = TCharacter:FindFirstChildOfClass("Accessory")
    local Handle = Accessory and Accessory:FindFirstChild("Handle")

    if not TRootPart and not THead and not Handle then return end
    if THumanoid and THumanoid.Health <= 0 then return end
    if Humanoid.Health <= 0 then return end
    if THumanoid and THumanoid.Sit then return end

    local wasVoid = voidActive
    local savedCF = RootPart.CFrame

    if RootPart.Velocity.Magnitude < 50 then
        getgenv().OldPos = RootPart.CFrame
    end

    -- Pause void during fling
    if wasVoid and voidConnection then
        pcall(function() voidConnection:Disconnect() end)
        voidConnection = nil
    end

    if THead then workspace.CurrentCamera.CameraSubject = THead
    elseif Handle then workspace.CurrentCamera.CameraSubject = Handle
    elseif THumanoid then workspace.CurrentCamera.CameraSubject = THumanoid end

    -- Get the best target part to track
    local function GetTargetPart()
        if TRootPart and TRootPart.Parent then return TRootPart end
        if THead and THead.Parent then return THead end
        if Handle and Handle.Parent then return Handle end
        return nil
    end

    local function FPos(BP, Pos, Ang)
        if not RootPart or not RootPart.Parent then return end
        local cf = CFrame.new(BP.Position) * Pos * Ang
        RootPart.CFrame = cf
        pcall(function() Character:PivotTo(cf) end)
        RootPart.Velocity = Vector3.new(9e7, 9e7*10, 9e7)
        RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
    end

    local function SFBasePart(BP)
        if not BP or not BP.Parent then return end
        local startT = tick()
        local A = 0

        repeat
            if not Running or not FlingActive then break end
            if not RootPart or not RootPart.Parent then break end
            if not THumanoid or not THumanoid.Parent then break end
            if THumanoid.Health <= 0 then break end

            -- Re-acquire target part in case it changed
            local curBP = GetTargetPart()
            if not curBP or not curBP.Parent then break end

            local targetVel = curBP.Velocity.Magnitude
            local targetSpeed = THumanoid.WalkSpeed

            -- Predict where target will be
            local predictOffset = Vector3.zero
            if targetVel > 5 then
                predictOffset = curBP.Velocity.Unit * math.min(targetVel * 0.08, 10)
            end

            if targetVel < 50 then
                -- Slow target: spin attack
                A = A + 100
                local md = THumanoid.MoveDirection * targetVel / 1.25
                FPos(curBP, CFrame.new(predictOffset + Vector3.new(0,1.5,0) + md), CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset + Vector3.new(0,-1.5,0) + md), CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset + Vector3.new(0,1.5,0) + THumanoid.MoveDirection), CFrame.Angles(math.rad(A),0,0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset + Vector3.new(0,-1.5,0) + THumanoid.MoveDirection), CFrame.Angles(math.rad(A),0,0)); task.wait()
            else
                -- Fast target: aggressive chase with velocity matching
                A = A + 150
                local chaseDir = (curBP.Position - RootPart.Position)
                if chaseDir.Magnitude > 0.1 then
                    chaseDir = chaseDir.Unit
                else
                    chaseDir = THumanoid.MoveDirection
                end

                local speedBoost = math.max(targetSpeed, targetVel * 0.5)

                -- Teleport directly onto them with offset cycling
                FPos(curBP, CFrame.new(predictOffset + Vector3.new(0, 1.5, 0) + chaseDir * speedBoost * 0.03), CFrame.Angles(math.rad(A), 0, 0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset + Vector3.new(0, -1.5, 0) - chaseDir * speedBoost * 0.03), CFrame.Angles(math.rad(-A), 0, 0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset + Vector3.new(0, 0.5, 0)), CFrame.Angles(math.rad(A), math.rad(A), 0)); task.wait()
                FPos(curBP, CFrame.new(predictOffset + Vector3.new(0, -0.5, 0)), CFrame.Angles(0, 0, math.rad(A))); task.wait()

                -- Extra passes for very fast targets
                if targetVel > 100 then
                    FPos(curBP, CFrame.new(predictOffset + Vector3.new(1.5, 0, 0)), CFrame.Angles(math.rad(A*2), 0, 0)); task.wait()
                    FPos(curBP, CFrame.new(predictOffset + Vector3.new(-1.5, 0, 0)), CFrame.Angles(math.rad(-A*2), 0, 0)); task.wait()
                end
            end
        until tick() - startT >= duration or not FlingActive or not Running
    end

    pcall(function() workspace.FallenPartsDestroyHeight = 0/0 end)

    local BV = Instance.new("BodyVelocity")
    BV.Parent = RootPart; BV.Velocity = Vector3.zero; BV.MaxForce = Vector3.new(9e9,9e9,9e9)
    Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)

    local mainBP = GetTargetPart()
    if mainBP then SFBasePart(mainBP) end

    pcall(function() BV:Destroy() end)
    pcall(function() Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true) end)
    pcall(function() workspace.CurrentCamera.CameraSubject = Humanoid end)

    -- Return
    local returnCF = wasVoid and savedCF or getgenv().OldPos
    if returnCF and RootPart and RootPart.Parent then
        local att = 0
        repeat att+=1; pcall(function()
            RootPart.CFrame = returnCF * CFrame.new(0,.5,0)
            Character:PivotTo(returnCF * CFrame.new(0,.5,0))
            Humanoid:ChangeState("GettingUp")
            for _,p in pairs(Character:GetChildren()) do if p:IsA("BasePart") then p.Velocity=Vector3.zero;p.RotVelocity=Vector3.zero end end
        end); task.wait()
        until (RootPart.Position-returnCF.Position).Magnitude<25 or att>150
    end

    -- Restore void
    if wasVoid and voidActive then
        pcall(function() workspace.FallenPartsDestroyHeight=-1e9 end)
        voidConnection = RS.Heartbeat:Connect(function()
            if not voidActive or not Running then if voidConnection then voidConnection:Disconnect();voidConnection=nil end;return end
            local h=GetHRP(); if h then
                h.CFrame=CFrame.new(h.Position.X,voidTargetY,h.Position.Z)*CFrame.Angles(0,math.rad(h.Orientation.Y),0)
                h.Velocity=Vector3.new(h.Velocity.X*0.5,0,h.Velocity.Z*0.5);h.RotVelocity=Vector3.zero
                local ch=LP.Character;if ch then for _,p in pairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
            end
        end)
        table.insert(allConnections,voidConnection)
    else
        pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end)
    end
end

local function FlingAllPlayers()
    FlingActive=true
    for _,p in ipairs(Players:GetPlayers()) do
        if p~=LP and Running and FlingActive and p.Character and p.Character:FindFirstChildOfClass("Humanoid") then
            pcall(function() SkidFling(p,State.FlingDuration) end);task.wait(0.2)
        end
    end
    FlingActive=false
end

-- VOID
local function FindLowestY()
    local lowestY=math.huge
    pcall(function() for _,obj in pairs(workspace:GetDescendants()) do if obj:IsA("BasePart") and not obj:IsDescendantOf(LP.Character or Instance.new("Folder")) then local y=obj.Position.Y-obj.Size.Y/2;if y<lowestY then lowestY=y end end end end)
    if lowestY==math.huge then lowestY=0 end;return lowestY
end

local function StartVoid()
    if voidActive then return end
    local hrp=GetHRP();if not hrp then Notify("Void","No character",2,"error");return end
    voidSavedPos=hrp.CFrame;local lowestY=FindLowestY();voidTargetY=lowestY+voidYOffset
    pcall(function() workspace.FallenPartsDestroyHeight=-1e9 end)
    hrp.CFrame=CFrame.new(hrp.Position.X,voidTargetY,hrp.Position.Z);hrp.Velocity=Vector3.zero;voidActive=true
    if voidConnection then pcall(function() voidConnection:Disconnect() end) end
    voidConnection=RS.Heartbeat:Connect(function()
        if not voidActive or not Running then if voidConnection then voidConnection:Disconnect();voidConnection=nil end;return end
        local h=GetHRP();if h then
            h.CFrame=CFrame.new(h.Position.X,voidTargetY,h.Position.Z)*CFrame.Angles(0,math.rad(h.Orientation.Y),0)
            h.Velocity=Vector3.new(h.Velocity.X*0.5,0,h.Velocity.Z*0.5);h.RotVelocity=Vector3.zero
            local ch=LP.Character;if ch then for _,p in pairs(ch:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
        end
    end)
    table.insert(allConnections,voidConnection);ShowBindIndicator("Void");Notify("Void","Under map Y="..math.floor(voidTargetY),3,"info")
end

local function StopVoid()
    if not voidActive then return end;voidActive=false
    if voidConnection then pcall(function() voidConnection:Disconnect() end);voidConnection=nil end
    pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end)
    local hrp=GetHRP();if hrp then
        if voidSavedPos then hrp.CFrame=voidSavedPos;hrp.Velocity=Vector3.zero
        else local safeY=50;pcall(function() local ray=workspace:Raycast(Vector3.new(hrp.Position.X,5000,hrp.Position.Z),Vector3.new(0,-10000,0));if ray then safeY=ray.Position.Y+5 end end);hrp.CFrame=CFrame.new(hrp.Position.X,safeY,hrp.Position.Z);hrp.Velocity=Vector3.zero end
    end;voidSavedPos=nil;HideBindIndicator("Void");Notify("Void","Returned to surface",2,"success")
end

-- ESP
local function ClearESP()
    for _,h in pairs(espHighlights) do pcall(function() h:Destroy() end) end;espHighlights={}
    for _,b in pairs(espBillboards) do pcall(function() b:Destroy() end) end;espBillboards={}
end

local function UpdateESP()
    ClearESP();if not State.ESP then return end
    for _,player in pairs(Players:GetPlayers()) do if player~=LP and player.Character then
        local char=player.Character;local head=char:FindFirstChild("Head")
        local hl=Instance.new("Highlight");hl.Adornee=char;hl.FillColor=C.accent;hl.FillTransparency=0.75;hl.OutlineColor=C.accent;hl.OutlineTransparency=0;hl.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop;hl.Parent=char;table.insert(espHighlights,hl)
        if head then
            local bb=Instance.new("BillboardGui");bb.Name="QWEN_ESP";bb.Adornee=head;bb.Size=UDim2.new(0,200,0,40);bb.StudsOffset=Vector3.new(0,2.5,0);bb.AlwaysOnTop=true;bb.MaxDistance=1000;bb.Parent=head
            local nL=Instance.new("TextLabel");nL.Size=UDim2.new(1,0,0.5,0);nL.BackgroundTransparency=1;nL.Font=Enum.Font.GothamBold;nL.Text=player.DisplayName;nL.TextColor3=C.text;nL.TextSize=14;nL.TextStrokeColor3=C.shadow;nL.TextStrokeTransparency=0.3;nL.Parent=bb
            local uL=Instance.new("TextLabel");uL.Size=UDim2.new(1,0,0.5,0);uL.Position=UDim2.new(0,0,0.5,0);uL.BackgroundTransparency=1;uL.Font=Enum.Font.Gotham;uL.Text="@"..player.Name;uL.TextColor3=C.textSec;uL.TextSize=11;uL.TextStrokeColor3=C.shadow;uL.TextStrokeTransparency=0.4;uL.Parent=bb
            table.insert(espBillboards,bb)
        end
    end end
end
task.spawn(function() while Running do if State.ESP then pcall(UpdateESP) end;task.wait(3) end end)

-- GAME FUNCTIONS
local function StartNoclip()
    if noclipConnection then noclipConnection:Disconnect() end
    noclipConnection=RS.Stepped:Connect(function() local c=LP.Character;if c then for _,p in pairs(c:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end end)
    table.insert(allConnections,noclipConnection)
end
local function StopNoclip() if noclipConnection then noclipConnection:Disconnect();noclipConnection=nil end end

local function StartFly()
    local c=LP.Character;if not c then return end;local hrp=c:FindFirstChild("HumanoidRootPart");if not hrp then return end
    if not State.Noclip then StartNoclip() end
    if flyBV then pcall(function() flyBV:Destroy() end) end;if flyBG then pcall(function() flyBG:Destroy() end) end;if flyConnection then pcall(function() flyConnection:Disconnect() end) end
    flyBV=Instance.new("BodyVelocity");flyBV.MaxForce=Vector3.new(math.huge,math.huge,math.huge);flyBV.Velocity=Vector3.zero;flyBV.Parent=hrp
    flyBG=Instance.new("BodyGyro");flyBG.MaxTorque=Vector3.new(math.huge,math.huge,math.huge);flyBG.D=200;flyBG.P=10000;flyBG.Parent=hrp
    flyConnection=RS.RenderStepped:Connect(function()
        if not State.Fly or not hrp or not hrp.Parent then if flyConnection then flyConnection:Disconnect();flyConnection=nil end;return end
        flyBG.CFrame=Camera.CFrame;local dir=Vector3.zero
        if UIS:IsKeyDown(Enum.KeyCode.W) then dir+=Camera.CFrame.LookVector end;if UIS:IsKeyDown(Enum.KeyCode.S) then dir-=Camera.CFrame.LookVector end
        if UIS:IsKeyDown(Enum.KeyCode.A) then dir-=Camera.CFrame.RightVector end;if UIS:IsKeyDown(Enum.KeyCode.D) then dir+=Camera.CFrame.RightVector end
        if UIS:IsKeyDown(Enum.KeyCode.Space) then dir+=Vector3.new(0,1,0) end;if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then dir-=Vector3.new(0,1,0) end
        if dir.Magnitude>0 then dir=dir.Unit end;flyBV.Velocity=dir*State.FlySpeed
    end)
    table.insert(allConnections,flyConnection)
end
local function StopFly()
    if flyBV then pcall(function() flyBV:Destroy() end);flyBV=nil end;if flyBG then pcall(function() flyBG:Destroy() end);flyBG=nil end
    if flyConnection then pcall(function() flyConnection:Disconnect() end);flyConnection=nil end;if not State.Noclip then StopNoclip() end
end

-- ══════════════════════════
-- GUI
-- ══════════════════════════
local WIN_W,WIN_H=560,420
local HEADER_H,SIDEBAR_W,STATUSBAR_H=48,130,28
local CONTENT_H=WIN_H-HEADER_H-STATUSBAR_H

local SG=Instance.new("ScreenGui");SG.Name="QWENGui";SG.Parent=game.CoreGui;SG.ResetOnSpawn=false;SG.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;SG.Enabled=false
local Main=Instance.new("Frame");Main.Name="Main";Main.Size=UDim2.new(0,WIN_W,0,WIN_H);Main.Position=UDim2.new(0.5,-WIN_W/2,0.5,-WIN_H/2);Main.BackgroundColor3=C.bg;Main.BorderSizePixel=0;Main.ClipsDescendants=true;Main.Parent=SG;Corner(Main,12);Stroke(Main,C.border,1,0.4)

local Header=Instance.new("Frame");Header.Size=UDim2.new(1,0,0,HEADER_H);Header.BackgroundColor3=C.bgFloat;Header.BorderSizePixel=0;Header.ZIndex=10;Header.Parent=Main;Corner(Header,12)
local HdrMask=Instance.new("Frame");HdrMask.Size=UDim2.new(1,0,0,14);HdrMask.Position=UDim2.new(0,0,1,-14);HdrMask.BackgroundColor3=C.bgFloat;HdrMask.BorderSizePixel=0;HdrMask.ZIndex=10;HdrMask.Parent=Header
local HdrLine=Instance.new("Frame");HdrLine.Size=UDim2.new(1,-32,0,1);HdrLine.Position=UDim2.new(0,16,1,0);HdrLine.BackgroundColor3=C.border;HdrLine.BackgroundTransparency=0.5;HdrLine.BorderSizePixel=0;HdrLine.ZIndex=11;HdrLine.Parent=Header

local mainDrag=false;local mainDragStart,mainStartPos
Header.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then mainDrag=true;mainDragStart=i.Position;mainStartPos=Main.Position end end)
Header.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then mainDrag=false end end)
table.insert(allConnections,UIS.InputChanged:Connect(function(i) if mainDrag and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-mainDragStart;Main.Position=UDim2.new(mainStartPos.X.Scale,mainStartPos.X.Offset+d.X,mainStartPos.Y.Scale,mainStartPos.Y.Offset+d.Y) end end))

local AccDot=Instance.new("Frame");AccDot.Size=UDim2.new(0,6,0,6);AccDot.Position=UDim2.new(0,16,0.5,-3);AccDot.BackgroundColor3=C.accent;AccDot.BorderSizePixel=0;AccDot.ZIndex=12;AccDot.Parent=Header;Corner(AccDot,3)
local TitleL=Instance.new("TextLabel");TitleL.Size=UDim2.new(0,250,0,HEADER_H);TitleL.Position=UDim2.new(0,28,0,0);TitleL.BackgroundTransparency=1;TitleL.Font=Enum.Font.GothamBlack;TitleL.Text="QWEN";TitleL.TextColor3=C.text;TitleL.TextSize=16;TitleL.TextXAlignment=Enum.TextXAlignment.Left;TitleL.ZIndex=12;TitleL.Parent=Header
local VerL=Instance.new("TextLabel");VerL.Size=UDim2.new(0,80,0,HEADER_H);VerL.Position=UDim2.new(0,78,0,0);VerL.BackgroundTransparency=1;VerL.Font=Enum.Font.Gotham;VerL.Text="v10.3";VerL.TextColor3=C.textMuted;VerL.TextSize=11;VerL.TextXAlignment=Enum.TextXAlignment.Left;VerL.ZIndex=12;VerL.Parent=Header

local function MakeHeaderBtn(icon,posX,bg,tc) local b=Instance.new("TextButton");b.Size=UDim2.new(0,30,0,30);b.Position=UDim2.new(1,posX,0.5,-15);b.BackgroundColor3=bg;b.BackgroundTransparency=1;b.Font=Enum.Font.GothamBold;b.Text=icon;b.TextColor3=tc;b.TextSize=14;b.AutoButtonColor=false;b.ZIndex=12;b.Parent=Header;Corner(b,8);b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=0.2,BackgroundColor3=bg},0.15) end);b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=1},0.15) end);Ripple(b,tc);return b end
local SettingsBtn=MakeHeaderBtn("S",-42,C.surface,C.textSec)

local Sidebar=Instance.new("Frame");Sidebar.Size=UDim2.new(0,SIDEBAR_W,0,CONTENT_H);Sidebar.Position=UDim2.new(0,0,0,HEADER_H);Sidebar.BackgroundTransparency=1;Sidebar.BorderSizePixel=0;Sidebar.ZIndex=5;Sidebar.Parent=Main
local SL=Instance.new("UIListLayout",Sidebar);SL.Padding=UDim.new(0,2);SL.SortOrder=Enum.SortOrder.LayoutOrder
local SP2=Instance.new("UIPadding",Sidebar);SP2.PaddingTop=UDim.new(0,10);SP2.PaddingLeft=UDim.new(0,10);SP2.PaddingRight=UDim.new(0,10)
local SideDiv=Instance.new("Frame");SideDiv.Size=UDim2.new(0,1,0,CONTENT_H);SideDiv.Position=UDim2.new(0,SIDEBAR_W,0,HEADER_H);SideDiv.BackgroundColor3=C.border;SideDiv.BackgroundTransparency=0.6;SideDiv.BorderSizePixel=0;SideDiv.ZIndex=6;SideDiv.Parent=Main
local ContentArea=Instance.new("Frame");ContentArea.Size=UDim2.new(0,WIN_W-SIDEBAR_W,0,CONTENT_H);ContentArea.Position=UDim2.new(0,SIDEBAR_W,0,HEADER_H);ContentArea.BackgroundTransparency=1;ContentArea.ClipsDescendants=true;ContentArea.ZIndex=5;ContentArea.Parent=Main

local StatusBar=Instance.new("Frame");StatusBar.Size=UDim2.new(1,0,0,STATUSBAR_H);StatusBar.Position=UDim2.new(0,0,1,-STATUSBAR_H);StatusBar.BackgroundColor3=C.bgFloat;StatusBar.BorderSizePixel=0;StatusBar.ZIndex=10;StatusBar.Parent=Main;Corner(StatusBar,12)
local SBMask=Instance.new("Frame");SBMask.Size=UDim2.new(1,0,0,14);SBMask.BackgroundColor3=C.bgFloat;SBMask.BorderSizePixel=0;SBMask.ZIndex=10;SBMask.Parent=StatusBar
local SBLine=Instance.new("Frame");SBLine.Size=UDim2.new(1,-32,0,1);SBLine.Position=UDim2.new(0,16,0,0);SBLine.BackgroundColor3=C.border;SBLine.BackgroundTransparency=0.6;SBLine.BorderSizePixel=0;SBLine.ZIndex=11;SBLine.Parent=StatusBar
local StatusDot=Instance.new("Frame");StatusDot.Size=UDim2.new(0,6,0,6);StatusDot.Position=UDim2.new(0,14,0.5,-3);StatusDot.BackgroundColor3=C.success;StatusDot.BorderSizePixel=0;StatusDot.ZIndex=12;StatusDot.Parent=StatusBar;Corner(StatusDot,3)
task.spawn(function() while Running do Smooth(StatusDot,{BackgroundTransparency=0.5},0.8);task.wait(0.8);Smooth(StatusDot,{BackgroundTransparency=0},0.8);task.wait(0.8) end end)
local StatusText=Instance.new("TextLabel");StatusText.Size=UDim2.new(0.55,-30,1,0);StatusText.Position=UDim2.new(0,26,0,0);StatusText.BackgroundTransparency=1;StatusText.Font=Enum.Font.Gotham;StatusText.Text="Ready";StatusText.TextColor3=C.textMuted;StatusText.TextSize=10;StatusText.TextXAlignment=Enum.TextXAlignment.Left;StatusText.ZIndex=12;StatusText.Parent=StatusBar
local StatusActiveL=Instance.new("TextLabel");StatusActiveL.Size=UDim2.new(0,80,1,0);StatusActiveL.Position=UDim2.new(1,-94,0,0);StatusActiveL.BackgroundTransparency=1;StatusActiveL.Font=Enum.Font.Gotham;StatusActiveL.TextColor3=C.textMuted;StatusActiveL.TextSize=9;StatusActiveL.TextXAlignment=Enum.TextXAlignment.Right;StatusActiveL.Text="0 active";StatusActiveL.ZIndex=12;StatusActiveL.Parent=StatusBar

local function UpdateActiveCount() local ct=0;for _,k in pairs({"TpTool","Noclip","Fly","ESP"}) do if State[k] then ct+=1 end end;if voidActive then ct+=1 end;if FlingActive then ct+=1 end;StatusActiveL.Text=ct.." active" end

-- SETTINGS
local SettingsPanel=Instance.new("Frame");SettingsPanel.Size=UDim2.new(1,0,1,0);SettingsPanel.Position=UDim2.new(1,10,0,0);SettingsPanel.BackgroundColor3=C.bg;SettingsPanel.BorderSizePixel=0;SettingsPanel.ZIndex=30;SettingsPanel.Visible=false;SettingsPanel.Parent=Main;Corner(SettingsPanel,12);Stroke(SettingsPanel,C.border,1,0.4)
local SPT=Instance.new("TextLabel");SPT.Size=UDim2.new(1,-20,0,48);SPT.Position=UDim2.new(0,20,0,0);SPT.BackgroundTransparency=1;SPT.Font=Enum.Font.GothamBlack;SPT.Text="Settings";SPT.TextColor3=C.text;SPT.TextSize=15;SPT.TextXAlignment=Enum.TextXAlignment.Left;SPT.ZIndex=31;SPT.Parent=SettingsPanel
local SPScroll=Instance.new("ScrollingFrame");SPScroll.Size=UDim2.new(1,-40,1,-60);SPScroll.Position=UDim2.new(0,20,0,52);SPScroll.BackgroundTransparency=1;SPScroll.ScrollBarThickness=2;SPScroll.ScrollBarImageColor3=C.border;SPScroll.CanvasSize=UDim2.new(0,0,0,0);SPScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y;SPScroll.BorderSizePixel=0;SPScroll.ZIndex=31;SPScroll.Parent=SettingsPanel;Instance.new("UIListLayout",SPScroll).Padding=UDim.new(0,6)

local function MakeSettingsBtn2(parent,name,desc,tc,callback)
    local f=Instance.new("Frame");f.Size=UDim2.new(1,0,0,50);f.BackgroundColor3=C.card;f.BackgroundTransparency=0.3;f.BorderSizePixel=0;f.ZIndex=32;f.Parent=parent;Corner(f,10);Stroke(f,C.border,1,0.6)
    Instance.new("TextLabel",f).Size=UDim2.new(0.55,0,0,18);f:GetChildren()[#f:GetChildren()].Position=UDim2.new(0,14,0,8);f:GetChildren()[#f:GetChildren()].BackgroundTransparency=1;f:GetChildren()[#f:GetChildren()].Font=Enum.Font.GothamMedium;f:GetChildren()[#f:GetChildren()].Text=name;f:GetChildren()[#f:GetChildren()].TextColor3=tc or C.text;f:GetChildren()[#f:GetChildren()].TextSize=11;f:GetChildren()[#f:GetChildren()].TextXAlignment=Enum.TextXAlignment.Left;f:GetChildren()[#f:GetChildren()].ZIndex=33
    Instance.new("TextLabel",f).Size=UDim2.new(0.55,0,0,12);f:GetChildren()[#f:GetChildren()].Position=UDim2.new(0,14,0,28);f:GetChildren()[#f:GetChildren()].BackgroundTransparency=1;f:GetChildren()[#f:GetChildren()].Font=Enum.Font.Gotham;f:GetChildren()[#f:GetChildren()].Text=desc;f:GetChildren()[#f:GetChildren()].TextColor3=C.textMuted;f:GetChildren()[#f:GetChildren()].TextSize=9;f:GetChildren()[#f:GetChildren()].TextXAlignment=Enum.TextXAlignment.Left;f:GetChildren()[#f:GetChildren()].ZIndex=33
    local b=Instance.new("TextButton");b.Size=UDim2.new(0,70,0,26);b.Position=UDim2.new(1,-84,0.5,-13);b.BackgroundColor3=tc or C.accent;b.BackgroundTransparency=0.1;b.Font=Enum.Font.GothamBold;b.Text="RUN";b.TextColor3=C.bg;b.TextSize=9;b.AutoButtonColor=false;b.ZIndex=34;b.Parent=f;Corner(b,8);Ripple(b,C.bg);b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=0},0.1) end);b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=0.1},0.1) end);b.MouseButton1Click:Connect(callback)
end

MakeSettingsBtn2(SPScroll,"Unload Script","Remove completely",C.danger,function()
    Running=false;FlingActive=false;voidActive=false;StopNoclip();StopFly();ClearESP()
    if voidConnection then pcall(function() voidConnection:Disconnect() end) end
    for _,cn in pairs(allConnections) do pcall(function() cn:Disconnect() end) end
    local h=GetHum();if h then h.WalkSpeed=16;h.JumpPower=50 end
    for _,item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end
    if LP.Character then for _,item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end
    pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end);RemoveBlur();Notify("QWEN","Unloaded",2,"error")
    task.delay(0.5,function() for _,g in pairs(game.CoreGui:GetChildren()) do if g.Name:find("QWEN") then pcall(function() g:Destroy() end) end end end)
end)

local function OpenSettings() settingsOpen=true;SettingsPanel.Visible=true;SettingsPanel.Position=UDim2.new(1,10,0,0);Smooth(SettingsPanel,{Position=UDim2.new(0,0,0,0)},0.35) end
local function CloseSettings() settingsOpen=false;Smooth(SettingsPanel,{Position=UDim2.new(1,10,0,0)},0.3);task.delay(0.32,function() if not settingsOpen then SettingsPanel.Visible=false end end) end
SettingsBtn.MouseButton1Click:Connect(function() if settingsOpen then CloseSettings() else OpenSettings() end end)

-- TABS
local tabs={"Player","Fling","Void"}
local TabPages,TabBtns={},{}
local ActiveTab="Player"

local function MakePage()
    local page=Instance.new("ScrollingFrame");page.Size=UDim2.new(1,0,1,0);page.BackgroundTransparency=1;page.ScrollBarThickness=2;page.ScrollBarImageColor3=C.border;page.ScrollBarImageTransparency=0.3;page.CanvasSize=UDim2.new(0,0,0,0);page.AutomaticCanvasSize=Enum.AutomaticSize.Y;page.BorderSizePixel=0;page.Visible=false;page.ZIndex=5;page.Parent=ContentArea
    local pad=Instance.new("UIPadding",page);pad.PaddingTop=UDim.new(0,12);pad.PaddingLeft=UDim.new(0,14);pad.PaddingRight=UDim.new(0,14);pad.PaddingBottom=UDim.new(0,14);Instance.new("UIListLayout",page).Padding=UDim.new(0,6);return page
end
for _,name in ipairs(tabs) do TabPages[name]=MakePage() end

local ActiveInd=Instance.new("Frame");ActiveInd.Size=UDim2.new(0,3,0,16);ActiveInd.BackgroundColor3=C.accent;ActiveInd.BorderSizePixel=0;ActiveInd.ZIndex=7;ActiveInd.Parent=Sidebar;ActiveInd.Position=UDim2.new(0,-2,0,17);Corner(ActiveInd,2)

local function SetTab(name)
    local nw=TabPages[name];if not nw or name==ActiveTab then return end;if TabPages[ActiveTab] then TabPages[ActiveTab].Visible=false end
    nw.Position=UDim2.new(0,0,0,6);nw.Visible=true;Smooth(nw,{Position=UDim2.new(0,0,0,0)},0.25)
    for _,tN in ipairs(tabs) do local btn=TabBtns[tN];if btn then local lbl=btn:FindFirstChild("Lbl")
        if tN==name then Smooth(btn,{BackgroundColor3=C.surface,BackgroundTransparency=0},0.2);if lbl then Smooth(lbl,{TextColor3=C.text},0.2) end;local yP=btn.AbsolutePosition.Y-Sidebar.AbsolutePosition.Y+btn.AbsoluteSize.Y/2-8;Smooth(ActiveInd,{Position=UDim2.new(0,-2,0,yP)},0.3)
        else Smooth(btn,{BackgroundTransparency=1},0.2);if lbl then Smooth(lbl,{TextColor3=C.textMuted},0.2) end end
    end end;ActiveTab=name
end

for i,name in ipairs(tabs) do
    local btn=Instance.new("TextButton");btn.Name=name;btn.Size=UDim2.new(1,0,0,34);btn.BackgroundColor3=C.surface;btn.BackgroundTransparency=i==1 and 0 or 1;btn.Text="";btn.AutoButtonColor=false;btn.ZIndex=6;btn.LayoutOrder=i;btn.Parent=Sidebar;Corner(btn,8)
    local lbl=Instance.new("TextLabel");lbl.Name="Lbl";lbl.Size=UDim2.new(1,-16,1,0);lbl.Position=UDim2.new(0,14,0,0);lbl.BackgroundTransparency=1;lbl.Font=Enum.Font.GothamMedium;lbl.Text=name;lbl.TextColor3=i==1 and C.text or C.textMuted;lbl.TextSize=11;lbl.TextXAlignment=Enum.TextXAlignment.Left;lbl.ZIndex=7;lbl.Parent=btn
    TabBtns[name]=btn
    btn.MouseEnter:Connect(function() if ActiveTab~=name then Smooth(btn,{BackgroundTransparency=0.5,BackgroundColor3=C.surfaceHov},0.15) end end)
    btn.MouseLeave:Connect(function() if ActiveTab~=name then Smooth(btn,{BackgroundTransparency=1},0.15) end end)
    btn.MouseButton1Click:Connect(function() SetTab(name) end)
end
TabPages.Player.Visible=true

-- BIND INDICATOR
local BindGui=Instance.new("ScreenGui");BindGui.Name="QWENBind";BindGui.ResetOnSpawn=false;BindGui.Parent=game.CoreGui
local BindBox=Instance.new("Frame");BindBox.Size=UDim2.new(0,170,0,28);BindBox.Position=UDim2.new(1,-186,0.5,-50);BindBox.BackgroundColor3=C.bg;BindBox.BackgroundTransparency=0.06;BindBox.BorderSizePixel=0;BindBox.AutomaticSize=Enum.AutomaticSize.Y;BindBox.Active=true;BindBox.Parent=BindGui;Corner(BindBox,10);Stroke(BindBox,C.border,1,0.5)
local bD=false;local bDS,bSP
BindBox.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then bD=true;bDS=i.Position;bSP=BindBox.Position end end)
BindBox.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then bD=false end end)
table.insert(allConnections,UIS.InputChanged:Connect(function(i) if bD and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-bDS;BindBox.Position=UDim2.new(bSP.X.Scale,bSP.X.Offset+d.X,bSP.Y.Scale,bSP.Y.Offset+d.Y) end end))
Instance.new("TextLabel",BindBox).Size=UDim2.new(1,0,0,24);BindBox:GetChildren()[#BindBox:GetChildren()].BackgroundTransparency=1;BindBox:GetChildren()[#BindBox:GetChildren()].Font=Enum.Font.GothamBold;BindBox:GetChildren()[#BindBox:GetChildren()].Text="ACTIVE";BindBox:GetChildren()[#BindBox:GetChildren()].TextColor3=C.textMuted;BindBox:GetChildren()[#BindBox:GetChildren()].TextSize=8;BindBox:GetChildren()[#BindBox:GetChildren()].ZIndex=2
local BindI=Instance.new("Frame");BindI.Size=UDim2.new(1,0,0,0);BindI.Position=UDim2.new(0,0,0,24);BindI.BackgroundTransparency=1;BindI.AutomaticSize=Enum.AutomaticSize.Y;BindI.Parent=BindBox;Instance.new("UIListLayout",BindI).Padding=UDim.new(0,2);local bPa=Instance.new("UIPadding",BindI);bPa.PaddingLeft=UDim.new(0,8);bPa.PaddingRight=UDim.new(0,8);bPa.PaddingBottom=UDim.new(0,6)

local function UpdateBindVis() local ct=0;for _ in pairs(activeBindIndicators) do ct+=1 end;BindBox.Visible=ct>0 end
local function ShowBindIndicator(name)
    if activeBindIndicators[name] then return end
    local f=Instance.new("Frame");f.Size=UDim2.new(1,0,0,22);f.BackgroundColor3=C.surface;f.BackgroundTransparency=1;f.BorderSizePixel=0;f.Parent=BindI;Corner(f,6)
    local dot=Instance.new("Frame");dot.Size=UDim2.new(0,4,0,4);dot.Position=UDim2.new(0,5,0.5,-2);dot.BackgroundColor3=C.accent;dot.BorderSizePixel=0;dot.Parent=f;Corner(dot,2)
    local lbl=Instance.new("TextLabel");lbl.Size=UDim2.new(1,-16,1,0);lbl.Position=UDim2.new(0,14,0,0);lbl.BackgroundTransparency=1;lbl.Font=Enum.Font.GothamMedium;lbl.Text=name;lbl.TextColor3=C.text;lbl.TextSize=10;lbl.TextTransparency=1;lbl.TextXAlignment=Enum.TextXAlignment.Left;lbl.Parent=f
    activeBindIndicators[name]=f;Smooth(f,{BackgroundTransparency=0.4},0.3);Smooth(lbl,{TextTransparency=0},0.3);UpdateBindVis()
end
local function HideBindIndicator(name)
    local f=activeBindIndicators[name];if not f then return end;activeBindIndicators[name]=nil;local lbl=f:FindFirstChildOfClass("TextLabel");Smooth(f,{BackgroundTransparency=1},0.2);if lbl then Smooth(lbl,{TextTransparency=1},0.2) end;task.delay(0.25,function() pcall(function() f:Destroy() end) end);UpdateBindVis()
end

table.insert(allConnections,UIS.InputBegan:Connect(function(input,gp) if not Running or gp or bindPopupActive then return end;if input.UserInputType~=Enum.UserInputType.Keyboard then return end;local kn=tostring(input.KeyCode):gsub("Enum.KeyCode.","");for fn,bk in pairs(Binds) do if bk==kn then local cb=toggleCallbacks[fn];if cb then cb() end end end end))

-- UI COMPONENTS
local function SectionLabel(parent,text) local f=Instance.new("Frame");f.Size=UDim2.new(1,0,0,24);f.BackgroundTransparency=1;f.Parent=parent;local ln=Instance.new("Frame");ln.Size=UDim2.new(1,0,0,1);ln.Position=UDim2.new(0,0,1,-1);ln.BackgroundColor3=C.border;ln.BackgroundTransparency=0.7;ln.BorderSizePixel=0;ln.Parent=f;local lbl=Instance.new("TextLabel");lbl.Size=UDim2.new(1,0,1,-4);lbl.BackgroundTransparency=1;lbl.Font=Enum.Font.GothamBold;lbl.Text=text;lbl.TextColor3=C.textMuted;lbl.TextSize=9;lbl.TextXAlignment=Enum.TextXAlignment.Left;lbl.Parent=f end
local function CloseBindPopup() if currentBindPopup then pcall(function() currentBindPopup.frame:Destroy() end);if currentBindPopup.conn then pcall(function() currentBindPopup.conn:Disconnect() end) end;currentBindPopup=nil;bindPopupActive=false end end

local function Toggle(parent,name,desc,callback)
    local frame=Instance.new("Frame");frame.Size=UDim2.new(1,0,0,52);frame.BackgroundColor3=C.card;frame.BackgroundTransparency=0.3;frame.BorderSizePixel=0;frame.Parent=parent;Corner(frame,10);Stroke(frame,C.border,1,0.65)
    local nameL=Instance.new("TextLabel");nameL.Size=UDim2.new(1,-100,0,18);nameL.Position=UDim2.new(0,14,0,8);nameL.BackgroundTransparency=1;nameL.Font=Enum.Font.GothamMedium;nameL.Text=name;nameL.TextColor3=C.text;nameL.TextSize=11;nameL.TextXAlignment=Enum.TextXAlignment.Left;nameL.Parent=frame
    local descL=Instance.new("TextLabel");descL.Size=UDim2.new(1,-100,0,12);descL.Position=UDim2.new(0,14,0,28);descL.BackgroundTransparency=1;descL.Font=Enum.Font.Gotham;descL.Text=desc;descL.TextColor3=C.textMuted;descL.TextSize=9;descL.TextXAlignment=Enum.TextXAlignment.Left;descL.Parent=frame
    local togBg=Instance.new("Frame");togBg.Size=UDim2.new(0,40,0,20);togBg.Position=UDim2.new(1,-54,0.5,-10);togBg.BackgroundColor3=C.toggleOff;togBg.BorderSizePixel=0;togBg.Parent=frame;Corner(togBg,10)
    local knob=Instance.new("Frame");knob.Size=UDim2.new(0,14,0,14);knob.Position=UDim2.new(0,3,0.5,-7);knob.BackgroundColor3=C.knobOff;knob.BorderSizePixel=0;knob.Parent=togBg;Corner(knob,7)
    local enabled=false;local stateKey=ToggleStateMap[name]
    if stateKey and State[stateKey] then enabled=true;togBg.BackgroundColor3=C.toggleOn;knob.Position=UDim2.new(1,-17,0.5,-7);knob.BackgroundColor3=C.knobOn;frame.BackgroundTransparency=0.15 end
    local bindL=Instance.new("TextLabel");bindL.Size=UDim2.new(0,70,0,14);bindL.Position=UDim2.new(1,-130,0.5,-7);bindL.BackgroundTransparency=1;bindL.Font=Enum.Font.GothamMedium;bindL.TextColor3=C.accentDim;bindL.TextSize=9;bindL.TextXAlignment=Enum.TextXAlignment.Right;bindL.Text=Binds[name] and ("["..Binds[name].."]") or "";bindL.Parent=frame;bindLabels[name]=bindL
    local btn=Instance.new("TextButton");btn.Size=UDim2.new(1,0,1,0);btn.BackgroundTransparency=1;btn.Text="";btn.Parent=frame
    local function setEnabled(val)
        enabled=val;if stateKey then State[stateKey]=val end
        if enabled then Smooth(togBg,{BackgroundColor3=C.toggleOn},0.2);Bounce(knob,{Position=UDim2.new(1,-17,0.5,-7)},0.3);Smooth(knob,{BackgroundColor3=C.knobOn},0.2);Smooth(frame,{BackgroundTransparency=0.15},0.2)
        else Smooth(togBg,{BackgroundColor3=C.toggleOff},0.2);Bounce(knob,{Position=UDim2.new(0,3,0.5,-7)},0.3);Smooth(knob,{BackgroundColor3=C.knobOff},0.2);Smooth(frame,{BackgroundTransparency=0.3},0.2) end
        task.spawn(function() Tween(knob,{Size=UDim2.new(0,18,0,14)},0.08);task.wait(0.1);Tween(knob,{Size=UDim2.new(0,14,0,14)},0.12) end)
        callback(enabled);SaveSettings();UpdateActiveCount()
    end
    toggleSetters[name]=setEnabled
    btn.MouseButton1Click:Connect(function() if bindPopupActive then return end;setEnabled(not enabled) end)
    btn.MouseButton2Click:Connect(function()
        CloseBindPopup();bindPopupActive=true
        local popup=Instance.new("Frame");popup.Size=UDim2.new(0,240,0,80);popup.Position=UDim2.new(0.5,-130,0.5,-45);popup.BackgroundColor3=C.bg;popup.BackgroundTransparency=0.3;popup.BorderSizePixel=0;popup.ZIndex=50;popup.Parent=Main;Corner(popup,12);Stroke(popup,C.accent,1,0.4);Bounce(popup,{Size=UDim2.new(0,260,0,90),BackgroundTransparency=0.02},0.35)
        local pt=Instance.new("TextLabel");pt.Size=UDim2.new(1,0,0,26);pt.Position=UDim2.new(0,0,0,12);pt.BackgroundTransparency=1;pt.Font=Enum.Font.GothamBold;pt.Text="Bind: "..name;pt.TextColor3=C.text;pt.TextSize=12;pt.ZIndex=51;pt.Parent=popup
        local ps=Instance.new("TextLabel");ps.Size=UDim2.new(1,0,0,16);ps.Position=UDim2.new(0,0,0,40);ps.BackgroundTransparency=1;ps.Font=Enum.Font.Gotham;ps.Text="Press key | Backspace = remove | Esc = cancel";ps.TextColor3=C.textMuted;ps.TextSize=9;ps.ZIndex=51;ps.Parent=popup
        local conn;conn=UIS.InputBegan:Connect(function(i2,gp2) if gp2 then return end;if i2.UserInputType==Enum.UserInputType.Keyboard then
            if i2.KeyCode==Enum.KeyCode.Backspace then Binds[name]=nil;bindL.Text="";CloseBindPopup();SaveSettings();Notify("Keybind","Removed",2,"info");return end
            if i2.KeyCode==Enum.KeyCode.Delete then return end;if i2.KeyCode==Enum.KeyCode.Escape then CloseBindPopup();return end
            local kn2=tostring(i2.KeyCode):gsub("Enum.KeyCode.","");Binds[name]=kn2;bindL.Text="["..kn2.."]";CloseBindPopup();SaveSettings();Notify("Keybind",name.." -> ["..kn2.."]",2,"success")
        end end);currentBindPopup={frame=popup,conn=conn}
    end)
    btn.MouseEnter:Connect(function() Smooth(frame,{BackgroundColor3=C.cardHov},0.12) end);btn.MouseLeave:Connect(function() Smooth(frame,{BackgroundColor3=C.card},0.12) end)
    return setEnabled
end

table.insert(allConnections,UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 and activeSliderDrag then Smooth(activeSliderDrag.knob,{Size=UDim2.new(0,14,0,14)},0.15);activeSliderDrag=nil end end))
table.insert(allConnections,UIS.InputChanged:Connect(function(i) if activeSliderDrag and i.UserInputType==Enum.UserInputType.MouseMovement then activeSliderDrag.update(i) end end))

local function Slider(parent,name,minV,maxV,def,callback)
    local frame=Instance.new("Frame");frame.Size=UDim2.new(1,0,0,62);frame.BackgroundColor3=C.card;frame.BackgroundTransparency=0.3;frame.BorderSizePixel=0;frame.Parent=parent;Corner(frame,10);Stroke(frame,C.border,1,0.65)
    local nameL=Instance.new("TextLabel");nameL.Size=UDim2.new(0.5,0,0,18);nameL.Position=UDim2.new(0,14,0,10);nameL.BackgroundTransparency=1;nameL.Font=Enum.Font.GothamMedium;nameL.Text=name;nameL.TextColor3=C.text;nameL.TextSize=11;nameL.TextXAlignment=Enum.TextXAlignment.Left;nameL.Parent=frame
    local inp=Instance.new("TextBox");inp.Size=UDim2.new(0,50,0,22);inp.Position=UDim2.new(1,-64,0,7);inp.BackgroundColor3=C.surface;inp.BackgroundTransparency=0.3;inp.Font=Enum.Font.GothamMedium;inp.Text=tostring(def);inp.TextColor3=C.text;inp.TextSize=10;inp.ClearTextOnFocus=true;inp.BorderSizePixel=0;inp.Parent=frame;Corner(inp,6);Stroke(inp,C.border,1,0.5)
    local track=Instance.new("Frame");track.Size=UDim2.new(1,-28,0,4);track.Position=UDim2.new(0,14,0,44);track.BackgroundColor3=C.toggleOff;track.BorderSizePixel=0;track.Parent=frame;Corner(track,2)
    local fill=Instance.new("Frame");fill.Size=UDim2.new(math.clamp((def-minV)/(maxV-minV),0,1),0,1,0);fill.BackgroundColor3=C.accent;fill.BorderSizePixel=0;fill.Parent=track;Corner(fill,2)
    local sk=Instance.new("Frame");sk.Size=UDim2.new(0,14,0,14);sk.AnchorPoint=Vector2.new(0.5,0.5);sk.Position=UDim2.new(math.clamp((def-minV)/(maxV-minV),0,1),0,0.5,0);sk.BackgroundColor3=C.accent;sk.BorderSizePixel=0;sk.ZIndex=6;sk.Parent=track;Corner(sk,7);Stroke(sk,C.bg,2,0.3)
    local dragBtn=Instance.new("TextButton");dragBtn.Size=UDim2.new(1,0,5,0);dragBtn.Position=UDim2.new(0,0,-2,0);dragBtn.BackgroundTransparency=1;dragBtn.Text="";dragBtn.Parent=track
    local curVal=def
    local function apply(v) v=math.clamp(math.floor(v+0.5),minV,maxV);curVal=v;local pct=(v-minV)/(maxV-minV);Smooth(fill,{Size=UDim2.new(pct,0,1,0)},0.06);Smooth(sk,{Position=UDim2.new(pct,0,0.5,0)},0.06);inp.Text=tostring(v);callback(v);SaveSettings() end
    inp.FocusLost:Connect(function() local n=tonumber(inp.Text);if n then apply(n) else inp.Text=tostring(curVal) end end)
    dragBtn.MouseButton1Down:Connect(function() Smooth(sk,{Size=UDim2.new(0,16,0,16)},0.08);activeSliderDrag={knob=sk,update=function(input) local aP,aS=track.AbsolutePosition.X,track.AbsoluteSize.X;if aS>0 then apply(minV+(maxV-minV)*math.clamp((input.Position.X-aP)/aS,0,1)) end end} end)
    frame.MouseEnter:Connect(function() Smooth(frame,{BackgroundColor3=C.cardHov},0.12) end);frame.MouseLeave:Connect(function() Smooth(frame,{BackgroundColor3=C.card},0.12) end)
end

local function FluentBtn(parent,text,bg,tc,w) local b=Instance.new("TextButton");b.Size=UDim2.new(0,w or 100,0,34);b.BackgroundColor3=bg;b.BackgroundTransparency=0.1;b.Font=Enum.Font.GothamBold;b.Text=text;b.TextColor3=tc;b.TextSize=11;b.AutoButtonColor=false;b.Parent=parent;Corner(b,8);Stroke(b,C.border,1,0.5);Ripple(b,tc);b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=0},0.12) end);b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=0.1},0.12) end);return b end
local function Action(parent,name,desc,callback) local f=Instance.new("Frame");f.Size=UDim2.new(1,0,0,48);f.BackgroundColor3=C.card;f.BackgroundTransparency=0.3;f.BorderSizePixel=0;f.Parent=parent;Corner(f,10);Stroke(f,C.border,1,0.65);local nL=Instance.new("TextLabel");nL.Size=UDim2.new(0.6,0,0,16);nL.Position=UDim2.new(0,14,0,8);nL.BackgroundTransparency=1;nL.Font=Enum.Font.GothamMedium;nL.Text=name;nL.TextColor3=C.text;nL.TextSize=11;nL.TextXAlignment=Enum.TextXAlignment.Left;nL.Parent=f;local dL=Instance.new("TextLabel");dL.Size=UDim2.new(0.6,0,0,12);dL.Position=UDim2.new(0,14,0,26);dL.BackgroundTransparency=1;dL.Font=Enum.Font.Gotham;dL.Text=desc;dL.TextColor3=C.textMuted;dL.TextSize=9;dL.TextXAlignment=Enum.TextXAlignment.Left;dL.Parent=f;local b=Instance.new("TextButton");b.Size=UDim2.new(0,64,0,26);b.Position=UDim2.new(1,-78,0.5,-13);b.BackgroundColor3=C.accent;b.BackgroundTransparency=0.1;b.Font=Enum.Font.GothamBold;b.Text="RUN";b.TextColor3=C.bg;b.TextSize=9;b.AutoButtonColor=false;b.Parent=f;Corner(b,8);Ripple(b,C.bg);b.MouseEnter:Connect(function() Smooth(b,{BackgroundTransparency=0},0.1) end);b.MouseLeave:Connect(function() Smooth(b,{BackgroundTransparency=0.1},0.1) end);b.MouseButton1Click:Connect(callback);f.MouseEnter:Connect(function() Smooth(f,{BackgroundColor3=C.cardHov},0.12) end);f.MouseLeave:Connect(function() Smooth(f,{BackgroundColor3=C.card},0.12) end) end

-- ══════ TAB: PLAYER ══════
local PP=TabPages.Player
SectionLabel(PP,"MOVEMENT")
Slider(PP,"Walk Speed",16,200,State.Speed,function(v) State.Speed=v;local h=GetHum();if h then h.WalkSpeed=v end end)
Slider(PP,"Jump Power",50,350,State.JumpPower,function(v) State.JumpPower=v;local h=GetHum();if h then h.JumpPower=v end end)
Toggle(PP,"Noclip","Walk through walls",function(s) State.Noclip=s;if s then StartNoclip();ShowBindIndicator("Noclip");Notify("Noclip","Enabled",2,"success") else if not State.Fly then StopNoclip() end;HideBindIndicator("Noclip");Notify("Noclip","Disabled",2,"info") end end)
toggleCallbacks["Noclip"]=function() if toggleSetters["Noclip"] then toggleSetters["Noclip"](not State.Noclip) end end
Toggle(PP,"Fly","WASD + Space/Shift",function(s) State.Fly=s;if s then StartFly();ShowBindIndicator("Fly");Notify("Fly","Enabled",2,"success") else StopFly();HideBindIndicator("Fly");Notify("Fly","Disabled",2,"info") end end)
toggleCallbacks["Fly"]=function() if toggleSetters["Fly"] then toggleSetters["Fly"](not State.Fly) end end
Slider(PP,"Fly Speed",10,200,State.FlySpeed,function(v) State.FlySpeed=v end)
SectionLabel(PP,"TOOLS")
Toggle(PP,"TP Tool","Click to teleport to cursor",function(s) State.TpTool=s;if s then if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end) end;for _,item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end;if LP.Character then for _,item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end;local tool=Instance.new("Tool");tool.Name="TP_Tool";tool.RequiresHandle=false;tool.Parent=LP.Backpack;tpToolConnection=tool.Activated:Connect(function() local c=LP.Character;if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame=CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end end);ShowBindIndicator("TP Tool");Notify("TP Tool","Created, equip it",2,"success") else if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end);tpToolConnection=nil end;for _,item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end;if LP.Character then for _,item in pairs(LP.Character:GetChildren()) do if item.Name=="TP_Tool" then item:Destroy() end end end;HideBindIndicator("TP Tool");Notify("TP Tool","Removed",2,"info") end end)
toggleCallbacks["TP Tool"]=function() if toggleSetters["TP Tool"] then toggleSetters["TP Tool"](not State.TpTool) end end
SectionLabel(PP,"VISUALS")
Toggle(PP,"ESP Players","Highlight + names through walls",function(s) State.ESP=s;if s then pcall(UpdateESP);ShowBindIndicator("ESP Players");Notify("ESP","Enabled",2,"success") else ClearESP();HideBindIndicator("ESP Players");Notify("ESP","Disabled",2,"info") end end)
toggleCallbacks["ESP Players"]=function() if toggleSetters["ESP Players"] then toggleSetters["ESP Players"](not State.ESP) end end

-- ══════ TAB: FLING ══════
local FP=TabPages.Fling
local flingStatusF=Instance.new("Frame");flingStatusF.Size=UDim2.new(1,0,0,38);flingStatusF.BackgroundColor3=C.card;flingStatusF.BackgroundTransparency=0.15;flingStatusF.BorderSizePixel=0;flingStatusF.Parent=FP;Corner(flingStatusF,10);Stroke(flingStatusF,C.border,1,0.5)
local flingDot=Instance.new("Frame");flingDot.Size=UDim2.new(0,8,0,8);flingDot.Position=UDim2.new(0,12,0.5,-4);flingDot.BackgroundColor3=C.textMuted;flingDot.BorderSizePixel=0;flingDot.Parent=flingStatusF;Corner(flingDot,4)
local flingStatusL=Instance.new("TextLabel");flingStatusL.Size=UDim2.new(1,-30,1,0);flingStatusL.Position=UDim2.new(0,26,0,0);flingStatusL.BackgroundTransparency=1;flingStatusL.Font=Enum.Font.GothamMedium;flingStatusL.Text="Select targets to fling";flingStatusL.TextColor3=C.textMuted;flingStatusL.TextSize=11;flingStatusL.TextXAlignment=Enum.TextXAlignment.Left;flingStatusL.Parent=flingStatusF

local function UpdateFlingStatus() local cnt=0;for _ in pairs(SelectedFlingTargets) do cnt+=1 end;if FlingActive then flingStatusL.Text="Flinging "..cnt.." player(s)...";flingStatusL.TextColor3=C.accent;Smooth(flingDot,{BackgroundColor3=C.accent},0.2) elseif cnt>0 then flingStatusL.Text="Selected: "..cnt;flingStatusL.TextColor3=C.text;Smooth(flingDot,{BackgroundColor3=C.accent},0.2) else flingStatusL.Text="Select targets to fling";flingStatusL.TextColor3=C.textMuted;Smooth(flingDot,{BackgroundColor3=C.textMuted},0.2) end;UpdateActiveCount() end

SectionLabel(FP,"DURATION")
Slider(FP,"Duration (sec)",1,10,State.FlingDuration,function(v) State.FlingDuration=v end)

SectionLabel(FP,"CONTROLS")
local fBtnRow=Instance.new("Frame");fBtnRow.Size=UDim2.new(1,0,0,34);fBtnRow.BackgroundTransparency=1;fBtnRow.Parent=FP
local fBtnLay=Instance.new("UIListLayout");fBtnLay.FillDirection=Enum.FillDirection.Horizontal;fBtnLay.Padding=UDim.new(0,6);fBtnLay.Parent=fBtnRow
local StartFBtn=FluentBtn(fBtnRow,"START",C.accent,C.bg,100)
local StopFBtn=FluentBtn(fBtnRow,"STOP",C.dangerBg,C.danger,90)
local FlingAllBtn=FluentBtn(fBtnRow,"FLING ALL",C.card,C.text,110)

local selRow=Instance.new("Frame");selRow.Size=UDim2.new(1,0,0,28);selRow.BackgroundTransparency=1;selRow.Parent=FP
local selRowLay=Instance.new("UIListLayout");selRowLay.FillDirection=Enum.FillDirection.Horizontal;selRowLay.Padding=UDim.new(0,6);selRowLay.Parent=selRow
local selAllBtn=FluentBtn(selRow,"Select All",C.card,C.textSec,120)
local deselAllBtn=FluentBtn(selRow,"Deselect All",C.card,C.textSec,120)

SectionLabel(FP,"PLAYERS")
local flingPlrCont=Instance.new("Frame");flingPlrCont.Size=UDim2.new(1,0,0,0);flingPlrCont.AutomaticSize=Enum.AutomaticSize.Y;flingPlrCont.BackgroundTransparency=1;flingPlrCont.Parent=FP;Instance.new("UIListLayout",flingPlrCont).Padding=UDim.new(0,4)
local flingPlayerBtns={}

local function RefreshFlingList()
    for _,b in pairs(flingPlayerBtns) do pcall(function() b:Destroy() end) end;flingPlayerBtns={}
    local plrs=Players:GetPlayers();table.sort(plrs,function(a,b2) return a.Name:lower()<b2.Name:lower() end)
    for _,plr in ipairs(plrs) do if plr~=LP then
        local isSel=SelectedFlingTargets[plr.Name]~=nil
        local pF=Instance.new("Frame");pF.Size=UDim2.new(1,0,0,42);pF.BackgroundColor3=isSel and C.cardActive or C.card;pF.BackgroundTransparency=0.2;pF.BorderSizePixel=0;pF.Parent=flingPlrCont;Corner(pF,8);Stroke(pF,isSel and C.accent or C.border,1,isSel and 0.3 or 0.6)
        local av=Instance.new("Frame");av.Size=UDim2.new(0,28,0,28);av.Position=UDim2.new(0,8,0.5,-14);av.BackgroundColor3=Color3.fromHSV((plr.UserId%100)/100,0.3,0.55);av.BorderSizePixel=0;av.Parent=pF;Corner(av,14)
        Instance.new("TextLabel",av).Size=UDim2.new(1,0,1,0);av:GetChildren()[#av:GetChildren()].BackgroundTransparency=1;av:GetChildren()[#av:GetChildren()].Font=Enum.Font.GothamBlack;av:GetChildren()[#av:GetChildren()].Text=plr.Name:sub(1,1):upper();av:GetChildren()[#av:GetChildren()].TextColor3=C.text;av:GetChildren()[#av:GetChildren()].TextSize=12
        local nL=Instance.new("TextLabel");nL.Size=UDim2.new(1,-100,0,16);nL.Position=UDim2.new(0,44,0,6);nL.BackgroundTransparency=1;nL.Font=Enum.Font.GothamMedium;nL.Text=plr.DisplayName;nL.TextColor3=C.text;nL.TextSize=11;nL.TextXAlignment=Enum.TextXAlignment.Left;nL.Parent=pF
        local uL=Instance.new("TextLabel");uL.Size=UDim2.new(1,-100,0,12);uL.Position=UDim2.new(0,44,0,24);uL.BackgroundTransparency=1;uL.Font=Enum.Font.Gotham;uL.Text="@"..plr.Name;uL.TextColor3=C.textMuted;uL.TextSize=9;uL.TextXAlignment=Enum.TextXAlignment.Left;uL.Parent=pF
        local chk=Instance.new("Frame");chk.Size=UDim2.new(0,22,0,22);chk.Position=UDim2.new(1,-34,0.5,-11);chk.BackgroundColor3=isSel and C.accent or C.surface;chk.BackgroundTransparency=isSel and 0 or 0.3;chk.BorderSizePixel=0;chk.Parent=pF;Corner(chk,6)
        local chkL=Instance.new("TextLabel");chkL.Size=UDim2.new(1,0,1,0);chkL.BackgroundTransparency=1;chkL.Font=Enum.Font.GothamBold;chkL.Text=isSel and "+" or "";chkL.TextColor3=C.bg;chkL.TextSize=14;chkL.Parent=chk
        local clickArea=Instance.new("TextButton");clickArea.Size=UDim2.new(1,0,1,0);clickArea.BackgroundTransparency=1;clickArea.Text="";clickArea.Parent=pF
        local cp=plr
        clickArea.MouseButton1Click:Connect(function()
            if SelectedFlingTargets[cp.Name] then SelectedFlingTargets[cp.Name]=nil;Smooth(pF,{BackgroundColor3=C.card},0.15);Smooth(chk,{BackgroundColor3=C.surface,BackgroundTransparency=0.3},0.15);chkL.Text="";local str=pF:FindFirstChildWhichIsA("UIStroke");if str then Smooth(str,{Color=C.border,Transparency=0.6},0.15) end
            else SelectedFlingTargets[cp.Name]=cp;Smooth(pF,{BackgroundColor3=C.cardActive},0.15);Smooth(chk,{BackgroundColor3=C.accent,BackgroundTransparency=0},0.15);chkL.Text="+";local str=pF:FindFirstChildWhichIsA("UIStroke");if str then Smooth(str,{Color=C.accent,Transparency=0.3},0.15) end end;UpdateFlingStatus()
        end)
        clickArea.MouseEnter:Connect(function() Smooth(pF,{BackgroundTransparency=0.05},0.1) end);clickArea.MouseLeave:Connect(function() Smooth(pF,{BackgroundTransparency=0.2},0.1) end)
        table.insert(flingPlayerBtns,pF)
    end end
    if #flingPlayerBtns==0 then local eL=Instance.new("TextLabel");eL.Size=UDim2.new(1,0,0,30);eL.BackgroundTransparency=1;eL.Font=Enum.Font.Gotham;eL.Text="No other players";eL.TextColor3=C.textMuted;eL.TextSize=11;eL.Parent=flingPlrCont;table.insert(flingPlayerBtns,eL) end
end

local refreshFBtn=FluentBtn(FP,"Refresh List",C.card,C.textSec,0);refreshFBtn.Size=UDim2.new(1,0,0,28)

StartFBtn.MouseButton1Click:Connect(function()
    local cnt=0;for _ in pairs(SelectedFlingTargets) do cnt+=1 end
    if cnt==0 then Notify("Fling","Select targets first!",2,"warning");return end
    FlingActive=true;UpdateFlingStatus();ShowBindIndicator("Fling");Notify("Fling","Flinging "..cnt.." player(s)",2,"info")
    task.spawn(function()
        while FlingActive and Running do
            for n2,pl in pairs(SelectedFlingTargets) do if not pl or not pl.Parent then SelectedFlingTargets[n2]=nil end end
            local c2=0;for _ in pairs(SelectedFlingTargets) do c2+=1 end;if c2==0 then FlingActive=false;break end;UpdateFlingStatus()
            for _,pl in pairs(SelectedFlingTargets) do if FlingActive and Running and pl and pl.Parent then pcall(function() SkidFling(pl,State.FlingDuration) end);task.wait(0.15) end end;task.wait(0.2)
        end;FlingActive=false;UpdateFlingStatus();HideBindIndicator("Fling")
    end)
end)
StopFBtn.MouseButton1Click:Connect(function() FlingActive=false;UpdateFlingStatus();HideBindIndicator("Fling");Notify("Fling","Stopped",2,"info") end)
FlingAllBtn.MouseButton1Click:Connect(function() Notify("Fling","Flinging ALL",2,"info");ShowBindIndicator("Fling All");task.spawn(function() FlingAllPlayers();HideBindIndicator("Fling All");Notify("Fling","Done",2,"success") end) end)
selAllBtn.MouseButton1Click:Connect(function() for _,p in ipairs(Players:GetPlayers()) do if p~=LP then SelectedFlingTargets[p.Name]=p end end;UpdateFlingStatus();RefreshFlingList() end)
deselAllBtn.MouseButton1Click:Connect(function() SelectedFlingTargets={};UpdateFlingStatus();RefreshFlingList() end)
refreshFBtn.MouseButton1Click:Connect(RefreshFlingList)

-- ══════ TAB: VOID ══════
local VP=TabPages.Void
local voidStatusF=Instance.new("Frame");voidStatusF.Size=UDim2.new(1,0,0,38);voidStatusF.BackgroundColor3=C.card;voidStatusF.BackgroundTransparency=0.15;voidStatusF.BorderSizePixel=0;voidStatusF.Parent=VP;Corner(voidStatusF,10);Stroke(voidStatusF,C.border,1,0.5)
local voidStatusDot=Instance.new("Frame");voidStatusDot.Size=UDim2.new(0,8,0,8);voidStatusDot.Position=UDim2.new(0,12,0.5,-4);voidStatusDot.BackgroundColor3=C.textMuted;voidStatusDot.BorderSizePixel=0;voidStatusDot.Parent=voidStatusF;Corner(voidStatusDot,4)
local voidStatusL=Instance.new("TextLabel");voidStatusL.Size=UDim2.new(1,-30,1,0);voidStatusL.Position=UDim2.new(0,26,0,0);voidStatusL.BackgroundTransparency=1;voidStatusL.Font=Enum.Font.GothamMedium;voidStatusL.Text="Above ground";voidStatusL.TextColor3=C.textMuted;voidStatusL.TextSize=11;voidStatusL.TextXAlignment=Enum.TextXAlignment.Left;voidStatusL.Parent=voidStatusF
local function UpdateVoidStatus() if voidActive then voidStatusL.Text="Under map (Y: "..math.floor(voidTargetY or 0)..")";voidStatusL.TextColor3=C.accent;Smooth(voidStatusDot,{BackgroundColor3=C.accent},0.2) else voidStatusL.Text="Above ground";voidStatusL.TextColor3=C.textMuted;Smooth(voidStatusDot,{BackgroundColor3=C.textMuted},0.2) end;UpdateActiveCount() end

SectionLabel(VP,"DEPTH")
Slider(VP,"Y Offset",-500,-10,voidYOffset,function(v) voidYOffset=v;if voidActive then local ly=FindLowestY();voidTargetY=ly+voidYOffset end end)
SectionLabel(VP,"CONTROLS")
local voidBtnRow=Instance.new("Frame");voidBtnRow.Size=UDim2.new(1,0,0,38);voidBtnRow.BackgroundTransparency=1;voidBtnRow.Parent=VP
local voidBtnLay=Instance.new("UIListLayout");voidBtnLay.FillDirection=Enum.FillDirection.Horizontal;voidBtnLay.Padding=UDim.new(0,8);voidBtnLay.Parent=voidBtnRow
local voidGoBtn=FluentBtn(voidBtnRow,"GO UNDER",C.accent,C.bg,140)
local voidBackBtn=FluentBtn(voidBtnRow,"RETURN",C.card,C.text,120)
voidGoBtn.MouseButton1Click:Connect(function() if voidActive then Notify("Void","Already under map",2,"warning");return end;StartVoid();UpdateVoidStatus() end)
voidBackBtn.MouseButton1Click:Connect(function() if not voidActive then Notify("Void","Not under map",2,"info");return end;StopVoid();UpdateVoidStatus() end)
SectionLabel(VP,"NAVIGATION")
Action(VP,"TP to Nearest Player","Move under closest player",function() local c=LP.Character;if not c or not c:FindFirstChild("HumanoidRootPart") then return end;local hrp=c.HumanoidRootPart;local nearest,dist=nil,math.huge;for _,p in pairs(Players:GetPlayers()) do if p~=LP and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then local d2=(Vector3.new(p.Character.HumanoidRootPart.Position.X,0,p.Character.HumanoidRootPart.Position.Z)-Vector3.new(hrp.Position.X,0,hrp.Position.Z)).Magnitude;if d2<dist then nearest=p;dist=d2 end end end;if nearest and nearest.Character then local tp=nearest.Character.HumanoidRootPart.Position;hrp.CFrame=CFrame.new(tp.X,hrp.Position.Y,tp.Z);Notify("Void","Moved under "..nearest.DisplayName,2,"success") else Notify("Void","No players found",2,"error") end end)

-- HUD
local HUDSG=Instance.new("ScreenGui");HUDSG.Name="QWENHUD";HUDSG.Parent=game.CoreGui;HUDSG.ResetOnSpawn=false
local HUD=Instance.new("Frame");HUD.Size=UDim2.new(0,160,0,68);HUD.Position=UDim2.new(0,14,0,14);HUD.BackgroundColor3=C.bg;HUD.BackgroundTransparency=0.06;HUD.BorderSizePixel=0;HUD.Active=true;HUD.Draggable=true;HUD.Parent=HUDSG;Corner(HUD,10);Stroke(HUD,C.border,1,0.5)
local hDot=Instance.new("Frame");hDot.Size=UDim2.new(0,4,0,4);hDot.Position=UDim2.new(0,10,0,10);hDot.BackgroundColor3=C.accent;hDot.BorderSizePixel=0;hDot.ZIndex=2;hDot.Parent=HUD;Corner(hDot,2)
local hTitle=Instance.new("TextLabel");hTitle.Size=UDim2.new(1,-20,0,16);hTitle.Position=UDim2.new(0,20,0,5);hTitle.BackgroundTransparency=1;hTitle.Font=Enum.Font.GothamBlack;hTitle.Text="QWEN v10.3";hTitle.TextColor3=C.text;hTitle.TextSize=10;hTitle.TextXAlignment=Enum.TextXAlignment.Left;hTitle.ZIndex=2;hTitle.Parent=HUD
local hLine=Instance.new("Frame");hLine.Size=UDim2.new(1,-18,0,1);hLine.Position=UDim2.new(0,9,0,23);hLine.BackgroundColor3=C.border;hLine.BackgroundTransparency=0.5;hLine.BorderSizePixel=0;hLine.ZIndex=2;hLine.Parent=HUD
local hFPS=Instance.new("TextLabel");hFPS.Size=UDim2.new(0.5,-9,0,12);hFPS.Position=UDim2.new(0,9,0,28);hFPS.BackgroundTransparency=1;hFPS.Font=Enum.Font.GothamBold;hFPS.TextColor3=C.text;hFPS.TextSize=9;hFPS.TextXAlignment=Enum.TextXAlignment.Left;hFPS.ZIndex=2;hFPS.Parent=HUD
local hPing=Instance.new("TextLabel");hPing.Size=UDim2.new(0.5,-9,0,12);hPing.Position=UDim2.new(0.5,0,0,28);hPing.BackgroundTransparency=1;hPing.Font=Enum.Font.Gotham;hPing.TextColor3=C.textMuted;hPing.TextSize=9;hPing.TextXAlignment=Enum.TextXAlignment.Right;hPing.ZIndex=2;hPing.Parent=HUD
local hSession=Instance.new("TextLabel");hSession.Size=UDim2.new(1,-18,0,12);hSession.Position=UDim2.new(0,9,0,44);hSession.BackgroundTransparency=1;hSession.Font=Enum.Font.Gotham;hSession.TextColor3=C.textMuted;hSession.TextSize=9;hSession.TextXAlignment=Enum.TextXAlignment.Left;hSession.ZIndex=2;hSession.Parent=HUD
task.spawn(function() while Running do hFPS.Text="FPS: "..tostring(fpsValue);if fpsValue>=50 then hFPS.TextColor3=C.text elseif fpsValue>=30 then hFPS.TextColor3=C.warning else hFPS.TextColor3=C.danger end;local ping=0;pcall(function() ping=math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()) end);hPing.Text=ping.."ms";hSession.Text="Session: "..FormatTime(os.time()-StartTime);UpdateActiveCount();task.wait(0.5) end end)

-- RESPAWN
table.insert(allConnections,LP.CharacterAdded:Connect(function(char)
    if not Running then return end;local hum=char:WaitForChild("Humanoid");task.wait(0.1);pcall(function() hum.WalkSpeed=State.Speed;hum.JumpPower=State.JumpPower end)
    if State.TpTool then task.wait(0.5);local exists=false;for _,item in pairs(LP.Backpack:GetChildren()) do if item.Name=="TP_Tool" then exists=true;break end end;if not exists then if tpToolConnection then pcall(function() tpToolConnection:Disconnect() end) end;local tool=Instance.new("Tool");tool.Name="TP_Tool";tool.RequiresHandle=false;tool.Parent=LP.Backpack;tpToolConnection=tool.Activated:Connect(function() local c=LP.Character;if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame=CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end end) end end
    if State.Noclip then task.delay(0.3,StartNoclip) end;if State.Fly then task.delay(0.5,StartFly) end;if State.ESP then task.delay(0.5,function() pcall(UpdateESP) end) end
    if voidActive then voidActive=false;if voidConnection then pcall(function() voidConnection:Disconnect() end);voidConnection=nil end;pcall(function() workspace.FallenPartsDestroyHeight=getgenv().FPDH end);UpdateVoidStatus();HideBindIndicator("Void") end
end))

-- MENU TOGGLE
table.insert(allConnections,UIS.InputBegan:Connect(function(input,gp)
    if gp or not Running or bindPopupActive then return end
    if input.KeyCode==Enum.KeyCode.Delete then
        if not MenuOpen then MenuOpen=true;SG.Enabled=true;Main.Size=UDim2.new(0,WIN_W,0,0);Tween(Main,{Size=UDim2.new(0,WIN_W,0,WIN_H)},0.4,Enum.EasingStyle.Back,Enum.EasingDirection.Out);SetBlur(8)
        else CloseBindPopup();if settingsOpen then CloseSettings() end;Tween(Main,{Size=UDim2.new(0,WIN_W,0,0)},0.3,Enum.EasingStyle.Back,Enum.EasingDirection.In);RemoveBlur();task.delay(0.28,function() SG.Enabled=false;MenuOpen=false;Main.Size=UDim2.new(0,WIN_W,0,WIN_H) end) end
    end
end))

table.insert(allConnections,Players.PlayerAdded:Connect(function() if Running then task.wait(0.5);RefreshFlingList() end end))
table.insert(allConnections,Players.PlayerRemoving:Connect(function(plr) if not Running then return end;SelectedFlingTargets[plr.Name]=nil;UpdateFlingStatus();RefreshFlingList() end))

-- STARTUP
task.wait(0.3)
pcall(function() local h=GetHum();if h then h.WalkSpeed=State.Speed;h.JumpPower=State.JumpPower end end)
if State.Noclip then StartNoclip();ShowBindIndicator("Noclip") end;if State.Fly then StartFly();ShowBindIndicator("Fly") end
if State.ESP then pcall(UpdateESP);ShowBindIndicator("ESP Players") end
if State.TpTool then local tool=Instance.new("Tool");tool.Name="TP_Tool";tool.RequiresHandle=false;tool.Parent=LP.Backpack;tpToolConnection=tool.Activated:Connect(function() local c=LP.Character;if c and c:FindFirstChild("HumanoidRootPart") then c.HumanoidRootPart.CFrame=CFrame.new(Mouse.Hit.p+Vector3.new(0,3,0)) end end);ShowBindIndicator("TP Tool") end
RefreshFlingList();UpdateActiveCount();SG.Enabled=true;MenuOpen=true;SetBlur(8)
Notify("QWEN","v10.3 loaded, DELETE to toggle menu",4,"success")
print("[QWEN v10.3] Loaded | DELETE = menu")