function SWEP:GetPresetBase()
    return self.SaveBase or self:GetClass()
end

function SWEP:GetPresets()
    local path = ARC9.PresetPath .. self:GetPresetBase() .. "/*.txt"

    local files = file.Find(path, "DATA")

    for i, k in pairs(files) do
        files[i] = string.sub(k, 1, string.len(k) - 4)
    end

    return files
end

function SWEP:WriteAttachmentTree(tree)
    if tree and tree.Installed then
        local tbl = {
            Installed = tree.Installed,
            ToggleNum = tree.ToggleNum or 1
        }

        local atttbl = ARC9.GetAttTable(tree.Installed)

        if atttbl.Attachments then
            tbl.SubAttachments = {}

            for i, k in pairs(atttbl.Attachments) do
                tbl.SubAttachments[i] = self:WriteAttachmentTree(tree.SubAttachments[i])
            end
        end

        return tbl
    else
        return {}
    end
end

function SWEP:DeletePreset(filename)
    if LocalPlayer() != self:GetOwner() then return end

    filename = ARC9.PresetPath .. self:GetPresetBase() .. "/" .. filename

    if file.Exists(filename .. ".txt", "DATA") then
        file.Delete(filename .. ".txt")
    end

    if file.Exists(filename .. "." .. ARC9.PresetIconFormat, "DATA") then
        file.Delete(filename .. "." .. ARC9.PresetIconFormat)
    end
end

function SWEP:StripWeapon()
    for slot, slottbl in ipairs(self.Attachments) do
        slottbl.Installed = nil
        slottbl.SubAttachments = nil
    end

    self:PostModify()
end

function SWEP:ClearPreset()
    -- for slot, slottbl in ipairs(self.Attachments) do
    --     slottbl.Installed = nil
    --     slottbl.SubAttachments = nil
    -- end

    -- self:BuildSubAttachments(self.DefaultAttachments)

    -- self:PostModify()
    self:LoadPreset("default")
end

function SWEP:LoadPresetFromTable(tbl)
    self.Attachments = baseclass.Get(self:GetClass()).Attachments

    for slot, slottbl in ipairs(self.Attachments) do
        slottbl.Installed = nil
        slottbl.SubAttachments = nil
    end

    self:PruneAttachments()

    self:BuildSubAttachments(tbl)
    self:PostModify()
end

function SWEP:LoadPresetFromCode(str)
    local tbl = self:ImportPresetCode(str)

    if !tbl then return false end

    self:LoadPresetFromTable(tbl)

    surface.PlaySound("arc9/preset_install.ogg")
    
    return true
end

function SWEP:LoadPreset(filename)
    if LocalPlayer() != self:GetOwner() then return end

    filename = filename or "autosave"

    if filename == "autosave" then
        if !GetConVar("arc9_autosave"):GetBool() then return end
    end

    filename = ARC9.PresetPath .. self:GetPresetBase() .. "/" .. filename .. ".txt"

    if !file.Exists(filename, "DATA") then return end

    local f = file.Open(filename, "r", "DATA")
    if !f then return end

    local str = f:Read()

    if str[1] == "{" then
        self:LoadPresetFromTable(util.JSONToTable(str))
    else
        self:LoadPresetFromTable(self:ImportPresetCode(str))
    end

    if self.CustomizeHUD and self.CustomizeHUD.lowerpanel then
        timer.Simple(0, function()
            if !IsValid(self) then return end
            self:CreateHUD_Bottom()
        end)
    end

    f:Close()
end

local ratio = ScrW() / ScrH()
local pr_h = 256
local pr_w = 256 * ratio
local cammat = GetRenderTarget("arc9_cammat", pr_w, pr_h, false)

SWEP.PresetCapture = nil

function SWEP:SavePreset(presetname)
    presetname = presetname or "autosave"

    local str = self:GeneratePresetExportCode()

    local filename =  ARC9.PresetPath .. self:GetPresetBase() .. "/" .. presetname

    file.CreateDir(ARC9.PresetPath .. self:GetPresetBase())
    file.Write(filename .. ".txt", str)

    if presetname != "autosave" and presetname != "default" then
        self:DoPresetCapture(filename)
    end
end

function SWEP:DoPresetCapture(filename, foricon)
    render.PushRenderTarget(cammat)

    render.SetColorMaterial()
    render.DrawScreenQuad()
    render.Clear(0, 0, 0, 0, true, true)

    local ref = 64

    render.UpdateScreenEffectTexture()
    render.ClearStencil()
    render.SetStencilEnable(true)
    render.SetStencilCompareFunction(STENCIL_ALWAYS)
    render.SetStencilPassOperation(STENCIL_REPLACE)
    render.SetStencilFailOperation(STENCIL_KEEP)
    render.SetStencilZFailOperation(STENCIL_KEEP)
    render.SetStencilWriteMask(255)
    render.SetStencilTestMask(255)

    render.SetStencilReferenceValue(ref)

    render.SetWriteDepthToDestAlpha(false)
    render.OverrideAlphaWriteEnable(true, true)

    ARC9.PresetCam = true

    -- local ppos, pang = EyePos(), EyeAngles()
    local campos, camang = Vector(0, 0, 0), Angle(0, 0, 0)
    local custpos, custang = self:GetProcessedValue("CustomizePos"), self:GetProcessedValue("CustomizeAng")
    custpos = custpos + self.CustomizeSnapshotPos
    custang = custang + self.CustomizeSnapshotAng
    local pos, ang = Vector(0, 0, 0), Angle(0, 0, 0)

    pos = pos + (camang:Right() * custpos[1])
    pos = pos + (camang:Forward() * custpos[2])
    pos = pos + (camang:Up() * custpos[3])

    ang:RotateAroundAxis(camang:Up(), custang[1])
    ang:RotateAroundAxis(camang:Right(), custang[2])
    ang:RotateAroundAxis(camang:Forward(), custang[3])

    -- camang = self.LastViewModelAng or EyeAngles()
    -- campos = self.LastViewModelPos or EyePos()

    -- camang:RotateAroundAxis(camang:Up(), -custang.p)
    -- camang:RotateAroundAxis(camang:Right(), -custang.y)
    -- camang:RotateAroundAxis(camang:Forward(), -custang.r)

    -- campos = campos + camang:Right() * -custpos.x
    -- campos = campos + camang:Forward() * -custpos.y
    -- campos = campos + camang:Up() * -custpos.z

    cam.Start3D(campos, camang, self:GetProcessedValue("CustomizeSnapshotFOV"), 0, 0, ScrW(), ScrH(), 1, 1024)

    render.ClearDepth()

    render.SuppressEngineLighting(true)
    -- render.SetWriteDepthToDestAlpha(false)

    self:SetupModel(true, 0, true)

    -- local mdl = self.CModel[1]

    -- local anim = self:TranslateAnimation("idle")
    -- local ae = self:GetAnimationEntry(anim)
    -- local seq = mdl:LookupSequence(self:RandomChoice(ae.Source))

    -- mdl:ResetSequence(seq)
    -- mdl:SetPoseParameter("sights", 1)

    -- mdl:SetupBones()
    -- mdl:InvalidateBoneCache()

    render.SetBlend(1)
    render.SetColorModulation(1, 1, 1)

    render.MaterialOverride(Material("models/shiny"))
    render.OverrideColorWriteEnable(true, false)
    -- self:GetVM():DrawModel()
    self:DrawCustomModel(true, pos, ang)
    render.OverrideColorWriteEnable(false, false)

    render.BlurRenderTarget(cammat, 10, 10, 1)

    render.MaterialOverride(Material("models/shiny"))
    self:DrawCustomModel(true, pos, ang)
    render.MaterialOverride()

    render.SuppressEngineLighting(false)

    self:KillModel(true)

    cam.End3D()

    ARC9.PresetCam = false

    render.SetStencilEnable(false)

    -- render.RenderView({
    --     x = 0,
    --     y = 0,
    --     w = preset_res,
    --     h = preset_res,
    --     origin = EyePos(),
    --     angles = EyeAngles(),
    --     fov = 90,
    --     dopostprocess = false,
    --     drawhud = false,
    --     drawmonitors = false,
    --     drawviewmodel = true
    -- })

    local x = (pr_w - 256) / 2

    local data = render.Capture( {
        // format = ARC9.PresetIconFormat,
        format = "png",
        x = x,
        y = 0,
        w = 256,
        h = 256
    } )

    file.CreateDir(ARC9.PresetPath .. self:GetPresetBase())
    file.Write(filename .. "." .. ARC9.PresetIconFormat, data)
    -- file.Write(ARC9.PresetPath .. self:GetPresetBase() .. "/icon.png", "DATA")

    render.PopRenderTarget()

    self.AutoSelectIcon = Material("data/" .. filename .. "." .. ARC9.PresetIconFormat, "smooth")
    self.InvalidateSelectIcon = false
end

function SWEP:PruneUnnecessaryAttachmentDataRecursive(tbl)
    for i, k in pairs(tbl) do
        if i == "Installed" then
            tbl["i"] = k
            tbl["Installed"] = nil
        elseif i == "SubAttachments" then
            tbl["s"] = k
            tbl["SubAttachments"] = nil
        elseif i == "ToggleNum" then
            tbl["t"] = k
            tbl["ToggleNum"] = nil
        else
            tbl[i] = nil
        end
    end

    for i, k in pairs(tbl) do
        if i != "i" and i != "s" and i != "t" then
            tbl[i] = nil
        end
    end

    if table.Count(tbl.s or {}) > 0 then
        for i, k in pairs(tbl.s) do
            self:PruneUnnecessaryAttachmentDataRecursive(k)
        end
    end
end

function SWEP:DecompressTableRecursive(tbl)
    for i, k in pairs(tbl) do
        if i == "i" then
            tbl["i"] = nil
            tbl["Installed"] = k
        elseif i == "s" then
            tbl["s"] = nil
            tbl["SubAttachments"] = k
        elseif i == "t" then
            tbl["t"] = nil
            tbl["ToggleNum"] = k
        end
    end

    if table.Count(tbl.SubAttachments or {}) > 0 then
        for i, k in pairs(tbl.SubAttachments) do
            self:DecompressTableRecursive(k)
        end
    end
end

function SWEP:GetPresetJSON()
    local newtbl = {}

    newtbl = table.Copy(self.Attachments)

    for i, k in pairs(newtbl) do
        self:PruneUnnecessaryAttachmentDataRecursive(k)
    end

    return util.TableToJSON(newtbl)
end

function SWEP:GeneratePresetExportCode()
    local str = self:GetPresetJSON()

    str = util.Compress(str)
    str = util.Base64Encode(str, true)

    return str
end

function SWEP:ImportPresetCode(str)
    str = util.Base64Decode(str)
    str = util.Decompress(str)

    if !str then return end

    local tbl = util.JSONToTable(str)

    if tbl then
        for i, k in pairs(tbl) do
            self:DecompressTableRecursive(k)
        end
    end

    return tbl
end