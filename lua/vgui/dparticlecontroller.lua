local PANEL = {}
local knownDictionaries = util.JSONToTable(file.Read("gparticles_info.txt", "DATA") or "{}")
function PANEL:Init()
	self.CategoryTable = {}
	self.HorizontalDivider = vgui.Create("DHorizontalDivider", self)
	self.HorizontalDivider:Dock(FILL)
	self.HorizontalDivider:SetLeftMin(250)
	self.HorizontalDivider:SetLeftWidth(192)
	self.HorizontalDivider:SetRightMin(100)
	if ScrW() >= 1024 then
		self.HorizontalDivider:SetLeftMin(192)
		self.HorizontalDivider:SetRightMin(400)
	end

	self.HorizontalDivider:SetDividerWidth(6)
	self.HorizontalDivider:SetCookieName("SpawnMenuCreationMenuDiv")
	self.ContentNavBar = vgui.Create("ContentSidebar", self.HorizontalDivider)
	self.HorizontalDivider:SetLeft(self.ContentNavBar)
	self:EnableSearch("Particles", "PopulateParticles")

	self.ContentPanel = self.SelectedPanel

	self:FillContent()
end

function PANEL:EnableModify()
	self.ContentNavBar:EnableModify()
end

function PANEL:EnableSearch(...)
	self.ContentNavBar:EnableSearch(...)
	self.ContentNavBar.Search.ContentPanel = self
	self.ContentNavBar.Search.RefreshResults = function(s)
		local str = s.Search:GetText()
		self:DoSearch(s, str)
	end
end

function PANEL:DoSearch(pnl, str)
	pnl.PropPanel:Clear()
	local Header = pnl:Add( "ContentHeader" )
	local results = {}

	for k, v in pairs(knownDictionaries) do
		if v.State == 0 then continue end
		local parts = v.Particles or {}
		for _, name in pairs(parts) do
			if string.find(string.lower(name), string.lower(str)) then
				table.insert(results, {k, name})
			end
		end
	end

	Header:SetText( table.Count(results) .. " Results for \"" .. str .. "\"" )
	pnl.PropPanel:Add( Header )

	for _, pp in pairs(results) do
		spawnmenu.CreateContentIcon("particles", pnl.PropPanel, {
			name = pp[2],
			part = pp[1],
		})
	end
end

function PANEL:CallPopulateHook(HookName)
end

local function rebuildCache(name, item, cb)
	game.AddParticles("particles/" .. name)
	knownDictionaries[name] = knownDictionaries[name] or {}
	knownDictionaries[name].State = 3
	knownDictionaries[name].Particles = util.GetParticleList("particles/" .. name)
	timer.Simple(0.1, function()
		knownDictionaries[name].State = table.IsEmpty(knownDictionaries[name].Particles) and 3 or 1
		if IsValid(item) then
			item:SetIcon("icon16/fire.png")
		end
		file.Write("gparticles_info.txt", util.TableToJSON(knownDictionaries, true))
		if cb then
			cb()
		end
	end)
end

local states = {
	[0] = "asterisk_orange",
	[1] = "fire",
	[2] = "bug",
	[3] = "bin_empty",
	[4] = "star"
}

local function spawnItems(name, panel)
	local parts = knownDictionaries[name].Particles
	for _, pp in pairs(parts) do
		spawnmenu.CreateContentIcon("particles", panel, {
			name = pp,
			part = name,
		})
	end
end

function PANEL:CreateItem(k, v)
	local icon = (knownDictionaries[v] and knownDictionaries[v].State) or 0
	local item = self.ContentNavBar.Tree:AddNode(v, "icon16/" .. states[icon] .. ".png")
	item.DoRightClick = function(s, m)
		icon = (knownDictionaries[v] and knownDictionaries[v].State) or 0

		local menu = DermaMenu()
		menu:AddOption(icon == 4 and "Remove from Favorites" or "Add Favorite", function()
			if icon == 4 then
				knownDictionaries[v].Favorite = nil
				rebuildCache(v, item)
				self:FillContent()
			else
				rebuildCache(v, item, function()
					knownDictionaries[v].Favorite = true
					knownDictionaries[v].State = 4
					file.Write("gparticles_info.txt", util.TableToJSON(knownDictionaries, true))
					item:SetIcon("icon16/star.png")
					self:FillContent()
				end)
			end
		end):SetIcon("icon16/" .. (icon == 4 and "cancel" or "star") .. ".png")
		menu:AddOption("Rebuild cache", function()
			rebuildCache(v, item)
		end):SetIcon("icon16/arrow_refresh.png")
		menu:AddOption("Mark as buggy", function()
			knownDictionaries[v] = knownDictionaries[v] or {}
			knownDictionaries[v].State = 2
			file.Write("gparticles_info.txt", util.TableToJSON(knownDictionaries, true))
			item:SetIcon("icon16/bug.png")
		end):SetIcon("icon16/bug.png")

		menu:AddOption("Cancel")
		menu:Open()
	end

	item.DoPopulate = function(s)
		if icon == 2 then
			Derma_Message("This particle is marked as buggy and will not be loaded (You can right click and rebuild cache).", "Warning", "OK")
			return
		end
		-- If we've already populated it - forget it.
		if s.PropPanel then return end
		-- Create the container panel
		s.PropPanel = vgui.Create("ContentContainer", pnlContent)
		s.PropPanel:SetVisible(false)
		s.PropPanel:SetTriggerSpawnlistChange(false)

		if knownDictionaries[v] and knownDictionaries[v].State == 1 then
			spawnItems(v, s.PropPanel)
		else
			rebuildCache(v, item, function()
				spawnItems(v, s.PropPanel)
			end)
		end
	end

	item.DoClick = function(s)
		s:DoPopulate()
		self:SwitchPanel(s.PropPanel)
	end
end

function PANEL:FillContent()

	self.ContentNavBar.Tree:Clear()

	local files = file.Find("particles/*.pcf", "GAME")
	local normal, fav = {}, {}
	for k, v in pairs(files) do
		if knownDictionaries[v] and knownDictionaries[v].Favorite then
			fav[v] = v
		else
			normal[v] = v
		end
	end
	
	for k, v in SortedPairs(fav, sortFunc) do
		self:CreateItem(k, v)
	end

	for k, v in SortedPairs(normal, sortFunc) do
		self:CreateItem(k, v)
	end
end

function PANEL:SwitchPanel(panel)
	if IsValid(self.SelectedPanel) then
		self.SelectedPanel:SetVisible(false)
		self.SelectedPanel = nil
	end

	self.SelectedPanel = panel
	if not IsValid(panel) then return end
	self.HorizontalDivider:SetRight(self.SelectedPanel)
	self.HorizontalDivider:InvalidateLayout(true)
	self.SelectedPanel:SetVisible(true)
	self:InvalidateParent()
end

function PANEL:OnSizeChanged()
	self.HorizontalDivider:LoadCookies()
end

vgui.Register("DParticleViewer", PANEL, "EditablePanel")
spawnmenu.AddCreationTab("Particles", function()
	local PViewer = vgui.Create("DParticleViewer")
	return PViewer
end, "icon16/fire.png", 96, "See all your particles")
