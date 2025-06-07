local PANEL = {}
PANEL.Zoom = 100
DEFINE_BASECLASS( "ContentIcon")

local savedZooms = util.JSONToTable(file.Read("gparticles_zoom.txt", "DATA") or "{}")

function PANEL:Init()
    self:SetPaintBackground( false )
	self:SetSize( 128, 128 )
	self:SetText( "" )
end

function PANEL:Setup(name, part)
    self.partName = name
    self:SetName(self.partName)

    self.Owner = ClientsideModel("models/hunter/blocks/cube025x025x025.mdl")
    if not IsValid(self.Owner) then return end

    PrecacheParticleSystem(self.partName)
    self.Particle = CreateParticleSystem(self.Owner, self.partName, PATTACH_ABSORIGIN_FOLLOW, 0, Vector(0, 0, 0))
    if not self.Particle then
        self:SetName("-Invalid particle system-")
        return
    end

    self.Zoom = savedZooms[self.partName] or 100
    self.Particle:SetShouldDraw(false)
    print(self.Particle:GetHighestControlPoint())
end

PANEL.WasValid = false
function PANEL:Paint(w, h)
    baseclass.Get("ContentIcon").Paint(self, w, h)
    if not self.Particle then return end
    if self.Particle:IsValid() then
        for k = 1, self.Particle:GetHighestControlPoint() do
            self.Particle:SetControlPoint(k, Vector(0, 0, k * 4))
        end
        self.Particle:SetControlPointEntity(0, LocalPlayer())
        self.WasValid = true
        local x, y = self:LocalToScreen(0, 0)
        local origin = Vector(45, 45, self.Zoom / 40)
        local ang = origin:Angle()
        ang:RotateAroundAxis(ang:Up(), 90)
        cam.Start3D(origin, -ang, self.Zoom, x + 8, y + 8, w - 16, h - 16, 0, 1024)
        self.Owner:DrawModel()
        self.Particle:Render()
        cam.End3D()
    elseif not self.Particle:IsValid() and self.WasValid and IsValid(self.Owner) then
        self.Particle = CreateParticleSystem(self.Owner, self.partName, PATTACH_ABSORIGIN_FOLLOW, 1, Vector(0, 0, 0))
        self.Particle:SetShouldDraw(false)
    end
end

function PANEL:OnMousePressed(m)
    if m == MOUSE_RIGHT then
        local menu = DermaMenu()
        menu:AddOption("Spawn Particle", function()
            RunConsoleCommand("gparticles_particle", self.partName)
            spawnmenu.ActivateTool( "gparticles" )
        end):SetIcon("icon16/fire.png")
        menu:AddOption("+Zoom", function()
            self.Zoom = self.Zoom - self.Zoom / 4
            savedZooms[self.partName] = self.Zoom
            file.Write("gparticles_zoom.txt", util.TableToJSON(savedZooms))
        end):SetIcon("icon16/add.png")
        menu:AddOption("-Zoom", function()
            self.Zoom = self.Zoom + self.Zoom / 4
            savedZooms[self.partName] = self.Zoom
            file.Write("gparticles_zoom.txt", util.TableToJSON(savedZooms))
        end):SetIcon("icon16/delete.png")
        menu:AddOption("Copy name", function()
            SetClipboardText(self.partName)
        end):SetIcon("icon16/help.png")
        menu:AddOption("Copy path", function()
            SetClipboardText("game.AddParticles(\"particles/" .. self.partName .. ".pcf\")")
        end):SetIcon("icon16/house_link.png")
        menu:AddOption("Cancel")
        menu:Open()
        return
    elseif m == MOUSE_LEFT then
        RunConsoleCommand("gparticles_particle", self.partName)
    end

    self:DoClick()
end

function PANEL:OnRemove()
    SafeRemoveEntity(self.Owner)
    if self.Particle and self.Particle:IsValid() then
        self.Particle:StopEmissionAndDestroyImmediately()
    end
end

vgui.Register("ParticleControllerUI", PANEL, "ContentIcon")

spawnmenu.AddContentType( "particles", function( container, obj )

	if ( !obj.name ) then return end
	if ( !obj.part ) then return end

	local icon = vgui.Create( "ParticleControllerUI", container )
	icon:Setup( obj.name, obj.part )

	container:Add( icon )

end )
