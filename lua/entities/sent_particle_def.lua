AddCSLuaFile()
ENT.Base = "base_anim"
ENT.PrintName = "Particle Controller"
ENT.Category = "Other"
ENT.Spawnable = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Editable = true
ENT.Points = {}
function ENT:SetupDataTables()
    self:NetworkVar(
        "String",
        0,
        "ParticleName",
        {
            KeyName = "particle_name",
            Edit = {
                title = "Particle Name",
                type = "String",
                order = 0
            }
        }
    )

    self:NetworkVar(
        "Int",
        0,
        "ControlPoints",
        {
            KeyName = "control_points",
            Edit = {
                title = "Control Points",
                type = "Int",
                min = 0,
                max = 32,
                order = 1
            }
        }
    )

    self:NetworkVar("Int", 1, "CP")
    self:NetworkVar("Int", 2, "Key")
    self:NetworkVar("Bool", 0, "IsChildren")
    self:NetworkVar("Bool", 1, "AutoKill")
    self:NetworkVar("Bool", 2, "IsOn")
    self:NetworkVar("Entity", 0, "Main")
    self:NetworkVar("Entity", 1, "Player")
    self:SetIsOn(true)
    self:NetworkVarNotify("ParticleName", self.OnParticleNameChanged)
    self:NetworkVarNotify("ControlPoints", self.OnControlPointsChanged)
end

if SERVER then
    util.AddNetworkString("GPart.Restart")
    util.AddNetworkString("GPart.NotifyDead")
end

function ENT:Initialize()
    if SERVER then
        self:SetModel("models/maxofs2d/hover_basic.mdl")
        --self:SetSolid(SOLID_NONE)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        self:Activate()
        self:SetSkin(self:GetIsChildren() and 1 or 3)
        self:SetUseType(SIMPLE_USE)
        self:GetPhysicsObject():EnableGravity(false)
    else
        self:SetRenderBounds(Vector(-128, -128, -128) * 2, Vector(128, 128, 128) * 2)
    end

    self:DrawShadow(false)
end

function ENT:Use(act)
    if self:GetIsChildren() then return end
    net.Start("GPart.Restart")
    net.WriteEntity(self)
    net.SendPVS(self:GetPos())
end

function ENT:OnParticleNameChanged(name, old, new)
    if self:GetIsChildren() then return end
    if CLIENT then
        if self.Particle and self.Particle:IsValid() then
            self.Particle:StopEmissionAndDestroyImmediately()
        end

        self.Particle = CreateParticleSystem(self, new, PATTACH_ABSORIGIN_FOLLOW, 0)
        self.Particle:SetShouldDraw(false)
        self.DidCreate = true
    end
end

function ENT:OnControlPointsChanged(name, old, new)
    if self:GetIsChildren() then return end
    if CLIENT then return end
    for k, v in pairs(self.Points) do
        SafeRemoveEntity(v)
    end

    self.Points = {}
    local val = new or old
    if val <= 0 then return end
    for k = 1, new or old do
        local ent = ents.Create(self:GetClass())
        ent:SetPos(self:GetPos() + Vector(0, 0, 32) * k)
        ent:SetIsChildren(true)
        ent:SetMain(self)
        ent:SetCP(k)
        ent:Spawn()
        self:DeleteOnRemove(ent)
        table.insert(self.Points, ent)
    end
end

function ENT:Think()
end

function ENT:OnRemove()
    if CLIENT and self.Particle and self.Particle:IsValid() then
        self.Particle:StopEmissionAndDestroyImmediately()
    end
end

if SERVER then
    numpad.Register(
        "Particle_Toggle",
        function(pl, ent)
            if not IsValid(ent) then return false end
            if not IsValid(pl) then return false end
            ent:SetIsOn(not ent:GetIsOn())
            if ent:GetIsOn() then
                net.Start("GPart.Restart")
                net.WriteEntity(ent)
                net.SendPVS(ent:GetPos())
            end
        end
    )
end

local allowed = {
    weapon_physgun = true,
    weapon_physcannon = true,
    gmod_tool = true
}

function ENT:DrawTranslucent()
    local wep = LocalPlayer():GetActiveWeapon()
    if not self:GetAutoKill() and IsValid(wep) and allowed[wep:GetClass()] then
        render.SuppressEngineLighting(true)
        render.SetBlend(.5)
        self:DrawModel()
        render.SetBlend(1)
        render.SuppressEngineLighting(false)
    end

    if self:GetIsChildren() then
        local main = self:GetMain()
        if not IsValid(main) then return end
        if main.Particle and main.Particle:IsValid() then
            main.Particle:SetControlPoint(self:GetCP(), self:GetPos())
        end

        return
    end

    if self.Particle and self.Particle:IsValid() then
        if not self:GetIsOn() then return end
        self.Particle:Render()
    elseif self:GetParticleName() ~= "" then
        if self:GetAutoKill() and self.DidCreate and not self.Notified then
            self.Notified = true
            net.Start("GPart.NotifyDead")
            net.WriteEntity(self)
            net.SendToServer()
        end

        if self:GetAutoKill() then return end
        self:OnParticleNameChanged("", "", self:GetParticleName())
    end
end

net.Receive(
    "GPart.NotifyDead",
    function(l, ply)
        local target = net.ReadEntity()
        if target:GetClass() == "sent_particle_def" then
            SafeRemoveEntity(target)
        end
    end
)

net.Receive(
    "GPart.Restart",
    function()
        local target = net.ReadEntity()
        if target:GetClass() == "sent_particle_def" then
            target:OnParticleNameChanged("ParticleName", "", target:GetParticleName())
        end
    end
)