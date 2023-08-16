local PANEL = {}

function PANEL:Init()
	self.CategoryTable = {}

	self.HorizontalDivider = vgui.Create( "DHorizontalDivider", self )
	self.HorizontalDivider:Dock( FILL )
	self.HorizontalDivider:SetLeftWidth( 192 )
	self.HorizontalDivider:SetLeftMin( 100 )
	self.HorizontalDivider:SetRightMin( 100 )
	if ( ScrW() >= 1024 ) then self.HorizontalDivider:SetLeftMin( 192 ) self.HorizontalDivider:SetRightMin( 400 ) end
	self.HorizontalDivider:SetDividerWidth( 6 )
	self.HorizontalDivider:SetCookieName( "SpawnMenuCreationMenuDiv" )

	self.ContentNavBar = vgui.Create( "ContentSidebar", self.HorizontalDivider )
	self.HorizontalDivider:SetLeft( self.ContentNavBar )

    self:FillContent()
end

function PANEL:EnableModify()
	self.ContentNavBar:EnableModify()
end

function PANEL:EnableSearch( ... )
	self.ContentNavBar:EnableSearch( ... )
end

function PANEL:CallPopulateHook( HookName )
end

function PANEL:FillContent()
    local files = file.Find("particles/*.pcf", "GAME")

    for k, v in pairs(files) do
        local item = self.ContentNavBar.Tree:AddNode( v, "icon16/page.png" )
        item.DoPopulate = function( s )
            game.AddParticles("particles/" .. v)
            -- If we've already populated it - forget it.
			if ( s.PropPanel ) then return end

			-- Create the container panel
			s.PropPanel = vgui.Create( "ContentContainer", pnlContent )
			s.PropPanel:SetVisible( false )
			s.PropPanel:SetTriggerSpawnlistChange( false )

			for _, pp in pairs(util.GetParticleList( "particles/" .. v )) do
				spawnmenu.CreateContentIcon( "particles", s.PropPanel, {
					name = pp,
                    part = v,
				} )
			end

        end

        item.DoClick = function( s )

			s:DoPopulate()
			self:SwitchPanel( s.PropPanel )

		end
    end
end

function PANEL:SwitchPanel( panel )

	if ( IsValid( self.SelectedPanel ) ) then
		self.SelectedPanel:SetVisible( false )
		self.SelectedPanel = nil
	end

	self.SelectedPanel = panel

	if ( !IsValid( panel ) ) then return end

	self.HorizontalDivider:SetRight( self.SelectedPanel )
	self.HorizontalDivider:InvalidateLayout( true )

	self.SelectedPanel:SetVisible( true )
	self:InvalidateParent()

end

function PANEL:OnSizeChanged()
	self.HorizontalDivider:LoadCookies()
end

vgui.Register("DParticleViewer", PANEL, "EditablePanel")

spawnmenu.AddCreationTab( "Particles", function()
    local PViewer = vgui.Create( "DParticleViewer" )
    return PViewer
end, "icon16/fire.png", 96, "See all your particles" )