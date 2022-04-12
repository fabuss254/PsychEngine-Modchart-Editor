-- LIBS
local Vector2 = require("src/classes/Vector2")
local UDim2 = require("src/classes/UDim2")
local Color = require("src/classes/Color")
local Object = require("src/libs/Classic")

local UI = require("src/libs/UIEngine")
local ErrorMessage = require("src/libs/ErrorMessage")

-- CLASS
local class = Object:extend("Frame")
class.CurID = 1
class.AllowedEvents = {"Hover", "MouseClick", "Update"}

function class:new(x, y, w, h)
    -- UI Properties
    self.Name = self._type -- Only for debug purposes
    self.Position = UDim2(0, x, 0, y)
    self.Size = UDim2(0, w or 100, 0, h or 100)
    self.Anchor = Vector2(0, 0)
    self.Opacity = 0

    self.Color = Color(1, 1, 1)
    self.CornerRadius = 0
    self.ZIndex = 0
    self.LayoutOrder = 0

    self.ClipDescendants = false

    -- UI interactive properties
    self.Visible = true
    self._IsHovering = false
    self.ChildLayout = false

    -- Basic 1 time connections
    self._Connections = {}

    -- UI Ancestry
    self._Childs = {}
    self.Parent = false

    -- Others
    self.META = {}

    -- Identify this frame
    self.Id = class.CurID
    class.CurID = class.CurID + 1

    return self
end

-- METHODS
function class:DoReturnSelf(...)
    if self.META.ReturnSelf then
        return self, ...
    end
    return ...
end

function class:Get(Name)
    for _,v in ipairs(self:GetChildren()) do
        if v.Name == Name then
            return v
        end
    end
end

function class:GetDescendants(tbl)
    local o = tbl or {}
    for _,v in ipairs(self:GetChildren()) do
        table.insert(o, v)
        o = v:GetDescendants(o)
    end
    return o
end

function class:SetVisible(bool)
    if self.Visible == bool then return end

    if bool then
        UI.Refresh()
    elseif UI.DrawMap then
        local DescendantsIDs = {[self.Id] = true}
        for _,v in ipairs(self:GetDescendants()) do
            DescendantsIDs[v.Id] = true
        end

        while true do
            local Pass = true
            for i=1, #UI.DrawMap do
                local v = UI.DrawMap[i]
                if DescendantsIDs[v.Id] then
                    table.remove(UI.DrawMap, i)
                    Pass = false
                    break
                end
            end
            if Pass then break end
        end
    end

    self.Visible = bool
end

function class:Ratio(AspectRatio)
    rawset(self, "AspectRatio", AspectRatio)
end

function class:SetRatio(...)
    return self:Ratio(...)
end

function class:IsVisible()
    if self.Parent then
        return self.Visible and self.Parent:IsVisible()
    end
    return self.Visible
end

function class:SetLayout(newLayout)
    self.ChildLayout = newLayout()
end

function class:SetParent(Obj)
    table.insert(Obj._Childs, self)
    table.sort(Obj._Childs, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
    self.Parent = Obj

    if self.ZIndex == 0 then
        self.ZIndex = Obj.ZIndex + 1
    end

    UI.Refresh()
end

function class:GetChildren()
    return self._Childs
end

function class:GetDrawingCoordinates()

    local OffsetX, OffsetY, SizeOffsetX, SizeOffsetY = 0, 0, ScreenSize.X, ScreenSize.Y
    if self.Parent then
        if self.Parent.ChildLayout then
            -- Overwrite how to place the elements
            return self.Parent.ChildLayout:Execute(self)
        end

        OffsetX, OffsetY, SizeOffsetX, SizeOffsetY = self.Parent:GetDrawingCoordinates()
    end

    local ParentPos = Vector2(OffsetX, OffsetY)
    local ParentSize = Vector2(SizeOffsetX, SizeOffsetY)

    local Size = self.Size:ToVector2(ParentSize)
    local Pos = self.Position:ToVector2(ParentSize) + ParentPos

    if rawget(self, "AspectRatio") then
        local Min = math.min(Size.X, Size.Y)
        Size = Vector2(Min / self.AspectRatio, Min)
    end

    local PosX = Pos.X - Size.X*self.Anchor.X
    local PosY = Pos.Y - Size.Y*self.Anchor.Y
    local ScaleX = Size.X
    local ScaleY = Size.Y

    return math.floor(PosX), math.floor(PosY), math.floor(ScaleX), math.floor(ScaleY)
end

function class:Draw()
    if self.Opacity >= 1 then return end -- No need to draw if invisible
    local PosX, PosY, ScaleX, ScaleY = self:GetDrawingCoordinates()

    self.Color:Apply(1-self.Opacity)
    
    --love.graphics.translate(PosX - ScaleX, PosY - ScaleY)
    --love.graphics.rotate(self.Rotation)
    --love.graphics.translate(-ScaleX, -ScaleY)
    love.graphics.translate(PosX, PosY)
    love.graphics.rectangle("fill", 0, 0, ScaleX, ScaleY, self.CornerRadius)
    love.graphics.origin()
end

function class:IsHovering()
    local x = love.mouse.getX()
    local y = love.mouse.getY()
    local PosX, PosY, ScaleX, ScaleY = self:GetDrawingCoordinates()

    local HoveringX = PosX <= x and PosX + ScaleX > x
    local HoveringY = PosY <= y and PosY + ScaleY > y

    return HoveringX and HoveringY
end

function class:Update(dt)
    if self._Connections["Hover"] then
        local Hovering = self:IsHovering()
        if self._IsHovering ~= Hovering then
            self._IsHovering = Hovering
    
            self._Connections.Hover(self:DoReturnSelf(self._IsHovering))
        end
    end

    if self._Connections["Update"] then
        self._Connections.Update(self:DoReturnSelf(dt))
    end
end

function class:Connect(event, callback, returnSelf)
    if not table.find(class.AllowedEvents, event) then return error(("Attempt to connect instance '%s' to undefined event '%s'"):format(typeof(class), event)) end
    if self._Connections[event] then return error("Cannot connect to the same event twice") end

    if self.class[event] then self[event](self) end
    self.META.ReturnSelf = returnSelf
    self._Connections[event] = callback
end

function class:Destroy()
    if self.Parent then
        for i,v in pairs(self.Parent:GetChildren()) do
            if v.UIID == self.UIID then
                table.remove(self.Parent._Childs, i)
                break
            end
        end
    end

    self.Parent = nil
end

function class:ClearAllChildren()
    while #self._Childs > 0 do
        self._Childs[1]:Destroy()
    end
end

-- META METHODS
function class:__tostring()
    return self.Name
end

function class:__eq(Obj)
    if type(Obj) ~= "table" then return error(("Tried to compare '%s' with '%s'"):format(self._type, typeof(Obj))) end
    return Obj.Id == self.Id
end

function class:__newindex(index, value)
    if not rawget(self, "_initialised") then
        return rawset(self, index, value)
    end
    error(ErrorMessage.NewIndexLocked:format(index))
end

return class