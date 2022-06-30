
Package.Require("Config.lua")

local HardBhop_BP = Blueprint(
    Vector(),
    Rotator(0, 0, 0),
    "hardbhop-assets::BP_HardBhop"
)

local DebugInfo = {}

local JustJumped = false

local HardBhop_Canvas = Canvas(
    true,
    Color.TRANSPARENT,
    0,
    true
)
HardBhop_Canvas:Subscribe("Update", function(self, width, height)
    local char = GetLocalCharacter()
    if not char then return end
    local vel = char:GetVelocity()
    local speed = math.floor(vel:Size() + 0.5)
    self:DrawText("Speed: " .. tostring(speed), Vector2D(5, Client.GetViewportSize().Y * 0.8), FontType.OpenSans, 16, Color.WHITE, 0, false, true, Color.TRANSPARENT, Vector2D(), false, Color.BLACK)
    if Bhop_Debug then
        local base_loc = Vector2D(5, Client.GetViewportSize().Y * 0.8 + 25)
        for k, v in pairs(DebugInfo) do
            self:DrawText(k .. ": " .. tostring(v), base_loc, FontType.OpenSans, 13, Color.WHITE, 0, false, true, Color.TRANSPARENT, Vector2D(), false, Color.BLACK)
            base_loc = base_loc + Vector2D(0, 25)
        end
    end
end)

local InBhop = false

function HandleCharacterSpawn(char)
    char:AddActorTag("hardbhopID" .. tostring(char:GetID()))
    HardBhop_BP:CallBlueprintEvent("CharacterSpawned", char:GetID())
end

Character.Subscribe("Spawn", HandleCharacterSpawn)
for k, v in pairs(Character.GetPairs()) do
    HandleCharacterSpawn(v)
end

Character.Subscribe("Destroy", function(char)
    HardBhop_BP:CallBlueprintEvent("CharacterDestroyed", char:GetID())
end)

function ApplyForceOnCharacter(vector)
    local char = GetLocalCharacter()
    if not char then return end
    HardBhop_BP:CallBlueprintEvent("ApplyForceOnChar", char:GetID(), vector.X, vector.Y, vector.Z)
end

function SetCharVelocity(vector)
    local char = GetLocalCharacter()
    if not char then return end
    HardBhop_BP:CallBlueprintEvent("SetVelocity", char:GetID(), vector.X, vector.Y, vector.Z)
end

function GetLocalCharacter()
    if Client.GetLocalPlayer() then
        return Client.GetLocalPlayer():GetControlledCharacter()
    end
end

function SetInBhop(bool)
    local local_char = GetLocalCharacter()
    --and not local_char:IsInRagdollMode()
    if ((bool and local_char  and not local_char:GetVehicle()) or not bool) then
        InBhop = bool
        JustJumped = false
        Events.Call("BhopModeChanged", bool)
    end
end

Input.Bind("Jump", InputEvent.Pressed, function()
    SetInBhop(true)
end)

Input.Bind("Jump", InputEvent.Released, function()
    SetInBhop(false)
end)

function DotProduct(vector1, vector2)
    return vector1.X * vector2.X + vector1.Y * vector2.Y + vector1.Z * vector2.Z
end

function CrossProduct(vector1, vector2)
    return Vector(
        vector1.Y * vector2.Z - vector1.Z * vector2.Y,
        vector1.Z * vector2.X - vector1.X * vector2.Z,
        vector1.X * vector2.Y - vector1.Y * vector2.X
    )
end

function Rotate_Move_Wish_To_Velocity(move_wish, dir)
    local move_wish_rotated = Rotator(0, 90, 0):RotateVector(move_wish)
    if DotProduct(move_wish_rotated, dir) > 0 then
        return move_wish_rotated
    else
        return Rotator(0, -90, 0):RotateVector(move_wish)
    end
end


Client.Subscribe("Tick", function(delta_time)
    local char = GetLocalCharacter()
    if char then
        if JustJumped then
            JustJumped = false

            local vel = char:GetVelocity()
            local vel_only_xy = Vector(vel.X, vel.Y, 0)

            ApplyForceOnCharacter(vel_only_xy * After_Jump_Speed_Mult)
        end

        local ply = Client.GetLocalPlayer()
        local vel = char:GetVelocity()
        local vel_only_xy = Vector(vel.X, vel.Y, 0)

        -- Draw an arrow indicating the direction of the velocity
        local dir = vel_only_xy:GetSafeNormal()
        local speed_xy = vel_only_xy:Size()
        if Bhop_Debug then
            Client.DrawDebugLine(char:GetLocation(), char:GetLocation() + dir * 100, Color.GREEN, delta_time * Debug_Line_Time_Mult, 1)
        end

        local keys_down = {
            forward = Client.IsKeyDown("Z"),
            left = Client.IsKeyDown("Q"),
            right = Client.IsKeyDown("D"),
            back = Client.IsKeyDown("S")
        }
        for k, v in pairs(keys_down) do
            if v then
                keys_down[k] = 1
            else
                keys_down[k] = 0
            end
        end
        local cam_rot = ply:GetCameraRotation()
        cam_rot = Rotator(0, cam_rot.Yaw, 0)
        local cam_forward = cam_rot:GetForwardVector()
        local cam_right = cam_rot:GetRightVector()
        cam_forward = Vector(cam_forward.X, cam_forward.Y, 0)
        cam_right = Vector(cam_right.X, cam_right.Y, 0)

        local move_wish = Vector(cam_forward.X * keys_down.forward + cam_right.X * keys_down.right - cam_right.X * keys_down.left - cam_forward.X * keys_down.back, cam_forward.Y * keys_down.forward + cam_right.Y * keys_down.right - cam_right.Y * keys_down.left - cam_forward.Y * keys_down.back, 0):GetSafeNormal()
        if Bhop_Debug then
            Client.DrawDebugLine(char:GetLocation() + Vector(0, 0, 20), char:GetLocation() + Vector(0, 0, 20) + move_wish * 100, Color.RED, delta_time * Debug_Line_Time_Mult, 1)
        end

        DebugInfo.InBhop = tostring(InBhop)

        local dot_product_move_vel = DotProduct(move_wish, dir)
        DebugInfo.Dot_Product = tostring(dot_product_move_vel)

        DebugInfo.SpeedXY = tostring(math.floor(speed_xy + 0.5))

        if InBhop then
            -- if the character moves in opposite direction of the velocity, then we reset his X, Y velocity
            if dot_product_move_vel < Reset_Velocity_At_Dot_Product then
                SetCharVelocity(Vector(vel.X * Opposite_Movement_Set_Velocity_Mult, vel.Y * Opposite_Movement_Set_Velocity_Mult, vel.Z))
                return
            end

            local dot_product_gain_speed_calculated = Bhop_Dot_Product_To_Gain_Speed + speed_xy * Speed_Dot_Product_Gain_Linear_Added
            local dot_product_max_gain_speed_calculated = dot_product_gain_speed_calculated / 2

            local VelToSet = Vector(0, 0, 0)
            local rotated_move_wish = Rotate_Move_Wish_To_Velocity(move_wish, dir)
            if Bhop_Debug then
                Client.DrawDebugLine(char:GetLocation() + Vector(0, 0, -20), char:GetLocation() + Vector(0, 0, -20) + rotated_move_wish * 100, Color.BLUE, delta_time * Debug_Line_Time_Mult, 1)
            end

            if speed_xy < Max_Speed then
                if (dot_product_move_vel > -dot_product_gain_speed_calculated and dot_product_move_vel < dot_product_gain_speed_calculated) then
                    if dot_product_move_vel < 0 then
                        -- The closer the dot product is from the max gain speed dot product, the faster it will be accelerated
                        local abs_dot = math.abs(dot_product_move_vel)
                        local distance_to_max_gain = dot_product_max_gain_speed_calculated - abs_dot
                        if distance_to_max_gain <= 0 then
                            distance_to_max_gain = dot_product_max_gain_speed_calculated + distance_to_max_gain
                        elseif distance_to_max_gain > 0 then
                            distance_to_max_gain = abs_dot
                        end

                        --local distance_to_center_speed_gain = math.abs(dot_product_move_vel)

                        VelToSet = rotated_move_wish * Gain_Speed_Mult * delta_time * distance_to_max_gain
                    end
                end
            end

            if dot_product_move_vel < 0 then
                VelToSet = VelToSet + (speed_xy * rotated_move_wish * Old_Speed_Kept) + (speed_xy * dir * (1-Old_Speed_Kept))
                SetCharVelocity(Vector(VelToSet.X, VelToSet.Y, vel.Z))
            end
        end
    end
end)

Character.Subscribe("FallingModeChanged", function(char, old_state, new_state)
    if char == GetLocalCharacter() then
        if InBhop then
            if new_state == FallingMode.None then
                Client.InputKey("SpaceBar", InputEvent.Pressed, 1)
                JustJumped = true
            end
        end
    end
end)