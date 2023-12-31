function Better_Coop_HUD.Heart.new(heart_type, is_half_heart, is_golden, has_eternal, is_empty)
    local self = setmetatable({}, Better_Coop_HUD.Heart)

    self.heart_type = heart_type
    self.is_half_heart = is_half_heart
    self.is_empty = is_empty
    self.is_golden = is_golden
    self.has_eternal = has_eternal
    self.sprite = self:getSprite()

    return self
end

function Better_Coop_HUD.Heart:updateSprite()
    self.sprite = self:getSprite()
end

function Better_Coop_HUD.Heart:getSprite()
    local sprite = {
        heart = Sprite(),
        golden = nil,
        eternal = nil,
    }
    sprite.heart:Load(Better_Coop_HUD.PATHS.ANIMATIONS.hearts, true)

    local half = 'Full'
    if self.is_half_heart then half = 'Half' end
    if self.is_empty then half = 'Empty' end

    if self.is_golden then
        sprite.golden = Sprite()
        sprite.golden:Load(Better_Coop_HUD.PATHS.ANIMATIONS.hearts, true)
        sprite.golden:SetFrame('GoldHeartOverlay', 0)
    end

    if self.has_eternal then
        sprite.eternal = Sprite()
        sprite.eternal:Load(Better_Coop_HUD.PATHS.ANIMATIONS.hearts, true)
        sprite.eternal:SetFrame('WhiteHeartOverlay', 0)
    end

    sprite.heart:SetFrame(self.heart_type..'Heart'..half, 0)

    if self.heart_type == 'empty' then
        sprite.heart:SetFrame('EmptyHeart', 0)
    end

    if self.heart_type == 'empty_coin' then
        sprite.heart:SetFrame('CoinEmpty', 0)
    end

    if self.heart_type == 'curse' then
        sprite.heart:SetFrame('CurseHeart', 0)
    end

    if self.heart_type == 'holy_mantle' then
        sprite.heart:SetFrame('HolyMantle', 0)
    end

    return sprite
end

function Better_Coop_HUD.Heart:render(pos)
    self.sprite.heart:Render(pos)
    if self.sprite.golden then self.sprite.golden:Render(pos) end
    if self.sprite.eternal then self.sprite.eternal:Render(pos) end
end

function Better_Coop_HUD.Health.new(player_entity)
    local self = setmetatable({}, Better_Coop_HUD.Health)
    self.player_entity = player_entity

    -- given in half-heart units
    self.max_red = player_entity:GetMaxHearts()
    self.effective_max = self.player_entity:GetEffectiveMaxHearts()
    self.red = self.player_entity:GetHearts()
    self.soul = self.player_entity:GetSoulHearts()

    -- given in binary, replaces soul heart sprites
    self.black = self.player_entity:GetBlackHearts()

    -- given in whole-heart units, replaces red heart sprite
    self.bone = self.player_entity:GetBoneHearts()
    self.golden = self.player_entity:GetGoldenHearts()
    self.rotten = self.player_entity:GetRottenHearts()
    self.broken = self.player_entity:GetBrokenHearts()

    -- TODO give to last red heart not last heart, if no red give to first heart
    self.eternal = self.player_entity:GetEternalHearts()

    -- not a heart sprite
    self.extra_lives = self.player_entity:GetExtraLives()

    self.total_hearts = math.ceil((self.max_red + self.soul) / 2)
    self.hearts = self:getHearts()
    return self
end

function Better_Coop_HUD.Health:_getHeartsHelper(
    iterations,
    heart_type,
    is_half_heart,
    is_golden,
    has_eternal,
    is_empty,
    bitmask,
    bitmask_heart_type
)
    local hearts = {}
    local bit = 1
    local type = heart_type
    for i = 1, iterations, 1 do
        type = heart_type

        if bitmask and bitmask_heart_type and ((bitmask & bit) == bit) then
            type = bitmask_heart_type
        end

        local heart = Better_Coop_HUD.Heart.new(type, is_half_heart, is_golden, has_eternal, is_empty)
        table.insert(hearts, heart)

        bit = bit * 2
    end
    return hearts
end

function Better_Coop_HUD.Health:getHearts()
    local hearts = {}

    if (Game():GetLevel():GetCurses() & 8) == 8 and not Better_Coop_HUD.config.health.ignore_curse then
        local curse_heart = Better_Coop_HUD.Heart.new('curse', false, false, false, false)
        table.insert(hearts, curse_heart)
        return hearts
    end

    -- if player is (Tainted) Keeper, use coins instead of hearts
    local red = 'Red'
    local empty = 'empty'
    local broken = 'Broken'

    local player_type = self.player_entity:GetPlayerType()
    if player_type == PlayerType.PLAYER_KEEPER or player_type == PlayerType.PLAYER_KEEPER_B then
        red = 'Coin'
        empty = 'empty_coin'
        broken = 'BrokenCoin'
    end

    -- red hearts
    local red_hearts_count = (self.red < self.max_red) and math.floor(self.red / 2) or math.floor(self.max_red / 2)
    local red_hearts = self:_getHeartsHelper(red_hearts_count, red, false, false, false, false, nil, '')
    if self.red % 2 == 1 then
        local half_heart = Better_Coop_HUD.Heart.new(red, true, false, false, false)
        table.insert(red_hearts, half_heart)
    end

    -- empty red heart containers
    local empty_hearts_count = math.floor((self.max_red - self.red) / 2)
    local empty_hearts = self:_getHeartsHelper(empty_hearts_count, empty, false, false, false, false, nil, '')

    -- soul / black hearts
    local soul_hearts_count = math.ceil(self.soul / 2)
    local soul_hearts = self:_getHeartsHelper(soul_hearts_count, 'Blue', false, false, false, false, self.black, 'Black')
    if self.soul % 2 == 1 then
        soul_hearts[#soul_hearts].is_half_heart = (self.soul % 2 == 1)
        soul_hearts[#soul_hearts]:updateSprite()
    end

    -- broken hearts
    local broken_hearts = self:_getHeartsHelper(self.broken, broken, false, false, false, false, nil, '')

    -- bone hearts
    local remaining_reds = self.red - self.max_red
    for i = 1, self.bone + soul_hearts_count, 1 do
        if self.player_entity:IsBoneHeart(i-1) then
            table.insert(soul_hearts, i, Better_Coop_HUD.Heart.new('Bone', remaining_reds == 1, false, false, remaining_reds <= 0))
            remaining_reds = remaining_reds - 2
        end
    end

    -- eternal heart
    if self.eternal == 1 then
        local eternal_table = soul_hearts
        if #red_hearts ~= 0 then
            eternal_table = red_hearts
        end

        eternal_table[#eternal_table].has_eternal = true
        eternal_table[#eternal_table]:updateSprite()
    end

    -- rotten hearts
    local type2 = ''
    for i = 0, self.rotten - 1, 1 do
        type2 = red_hearts[#red_hearts - i].heart_type
        if type2 == 'Red' then type2 = '' end
        red_hearts[#red_hearts - i].heart_type = 'Rotten' .. type2
        red_hearts[#red_hearts - i]:updateSprite()
    end

    for i = 1, #red_hearts, 1 do table.insert(hearts, red_hearts[i]) end
    for i = 1, #empty_hearts, 1 do table.insert(hearts, empty_hearts[i]) end
    for i = 1, #soul_hearts, 1 do table.insert(hearts, soul_hearts[i]) end

    -- golden hearts
    for i = 0, self.golden - 1, 1 do
        hearts[#hearts - i].is_golden = true
        hearts[#hearts - i]:updateSprite()
    end

    for i = 1, #broken_hearts, 1 do table.insert(hearts, broken_hearts[i]) end

    -- TODO holy card & holy mantle

    return hearts
end

function Better_Coop_HUD.Health:render(edge_indexed, edge_multipliers)
    local pos = Vector(0, 0)
    local offset = Vector(0, 0)
    local edge = edge_indexed + (Better_Coop_HUD.config.health.pos * edge_multipliers)

    local row = 0
    for i = 0, #self.hearts-1, 1 do
        if i % Better_Coop_HUD.config.health.hearts_per_row == 0 and i ~= 0 then
            row = row + 1
            offset.X = 0
            offset.Y = offset.Y + Better_Coop_HUD.config.health.space_between_rows
        end

        pos = edge + (offset * edge_multipliers)

        self.hearts[i+1]:render(pos)

        offset.X = offset.X + Better_Coop_HUD.config.health.space_between_hearts
    end

    -- TODO extra lives
end
