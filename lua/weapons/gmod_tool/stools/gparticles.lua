TOOL.Category = "Render"
TOOL.Name = "Particles"
TOOL.ClientConVar["key"] = "37"
TOOL.ClientConVar["particle"] = "medicgun_beam_red_invun"
TOOL.ClientConVar["cps"] = "0"
TOOL.ClientConVar["att"] = "0"
TOOL.ClientConVar["autokill"] = "0"
TOOL.Information = {
	{ name = "left", stage = 0 },
	{ name = "right", stage = 0 },
	{ name = "right_1", stage = 1 },
}

if CLIENT then
	language.Add("tool.gparticles.name", "Particle Spawner")
	language.Add("tool.gparticles.desc", "Spawn silly particles")
	language.Add("tool.gparticles.left", "Click to spawn a particle you moron")
	language.Add("tool.gparticles.right", "Select a particle controller to attach to")
	language.Add("tool.gparticles.right_1", "Select on what entity do you want to attach to")
end

cleanup.Register("particles")
CreateConVar("sbox_maxparticles", "5", FCVAR_ARCHIVE)
local function CheckLimit(ply, key)
	-- TODO: Clientside prediction
	if CLIENT then return true end
	local found = false
	for id, particle in ipairs(ents.FindByClass("sent_particle_def")) do
		if not particle.controlkey or particle.controlkey ~= key then continue end
		if IsValid(particle:GetPlayer()) and ply ~= particle:GetPlayer() then continue end
		found = true
		break
	end

	if not found and not ply:CheckLimit("particles") then return false end

	return true
end

local function MakeParticle(ply, key, particle, cps, autokill, Data)
	if IsValid(ply) and not CheckLimit(ply, key) then return false end
	local ent = ents.Create("sent_particle_def")
	if not IsValid(ent) then return false end
	duplicator.DoGeneric(ent, {
		particle = particle,
		cps = cps,
		autokill = autokill,
		Data = Data
	})

	ent.particle = particle
	ent.cps = cps
	ent.autokill = autokill

	ent:SetPlayer(ply)
	ent:SetPos(ply:GetEyeTrace().HitPos)
	ent:Spawn()
	ent:SetControlPoints(cps or 0)
	ent:SetAutoKill((autokill or 0) == 1)
	ent:SetParticleName(particle)

	timer.Simple(.1, function()
		net.Start("GPart.Restart")
		net.WriteEntity(ent)
		net.SendPVS(ent:GetPos())
	end)

	DoPropSpawnedEffect(ent)
	numpad.OnDown(ply, key, "Particle_Toggle", ent)
	if IsValid(ply) then
		ply:AddCleanup("particles", ent)
		ply:AddCount("particles", ent)
	end

	return ent
end

duplicator.RegisterEntityClass("sent_particle_def", function(ply, data)
	local ent = MakeParticle(ply, data.controlkey, data.particle, data.cps, data.autokill, data.Data)
	return ent
end, "Data")

function TOOL:LeftClick(trace)
	local ply = self:GetOwner()
	local key = self:GetClientNumber("key")
	if key == -1 then return false end
	if not CheckLimit(ply, key) then return false end
	if CLIENT then return true end

	if self:GetStage() == 1 then
		self:RightClick(trace)
		self:SetStage(0)
		return true
	end
	local autokill = self:GetClientNumber("autokill")
	local cps = self:GetClientNumber("cps")
	local particle = self:GetClientInfo("particle")
	local ent = MakeParticle(
		ply,
		key,
		particle,
		cps,
		autokill,
		{
			Pos = trace.StartPos,
			Angle = ply:EyeAngles()
		}
	)

	if not IsValid(ent) then return false end
	undo.Create("Particle")
	undo.AddEntity(ent)
	undo.SetPlayer(ply)
	undo.Finish()

	return true, ent
end

function TOOL:RightClick(trace)
	local ent = trace.Entity

	if self:GetStage() == 1 then
		if not IsValid(ent) then return end

		local obj = self:GetEnt(1)
		if IsValid(obj) then
			obj.lastPlace = obj:GetPos()
			obj:SetMoveType(MOVETYPE_NONE)
			obj:SetParent(ent, self:GetClientNumber("att"))
			obj:SetLocalPos(Vector(0, 0, 0))
			obj:SetAttachmentSelected(self:GetClientNumber("att"))

			if SERVER then
				undo.Create("Particle Attach")
				undo.AddFunction(function()
					if IsValid(obj) then
						obj:SetParent(nil)
						obj:SetMoveType(MOVETYPE_VPHYSICS)
						obj:SetPos(obj.lastPlace)
						obj:GetPhysicsObject():EnableGravity(false)
					end
				end)
				undo.SetPlayer(self:GetOwner())
				undo.Finish("Removed Particle Attachment")
			end
		end

		self:SetStage(0)
		return true
	end
	if ent:GetClass() != "sent_particle_def" then
		return false
	end

	self:SetObject(1, ent, trace.HitPos, ent:GetPhysicsObject(), 0, trace.HitNormal)
	self:SetStage(1)
	return true
end

local ConVarsDefault = TOOL:BuildConVarList()
function TOOL.BuildCPanel(CPanel)
	CPanel:AddControl(
		"ComboBox",
		{
			MenuButton = 1,
			Folder = "camera",
			Options = {
				["#preset.default"] = ConVarsDefault
			},
			CVars = table.GetKeys(ConVarsDefault)
		}
	)

	CPanel:AddControl(
		"Numpad",
		{
			Label = "Particle Enable Key",
			Command = "gparticles_key"
		}
	)

	CPanel:AddControl(
		"textbox",
		{
			Label = "Particle Name",
			Command = "gparticles_particle"
		}
	)

	CPanel:AddControl(
		"CheckBox",
		{
			Label = "Destroy particle after done",
			Command = "gparticles_autokill"
		}
	)

	CPanel:AddControl(
		"slider",
		{
			Label = "Control Points",
			Command = "gparticles_cps",
			Min = 0,
			Max = 32
		}
	)

	CPanel:AddControl(
		"slider",
		{
			Label = "Attachment",
			Command = "gparticles_att",
			Min = 0,
			Max = 16
		}
	)
end