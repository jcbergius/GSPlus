-- Gear Score Calculator - Calculate weighted gear scores

GearScoreCalculator = {}

-- Calculate raw stat budget (sum of all stats)
function GearScoreCalculator:CalculateRawStatBudget(stats)
    local budget = 0
    for statType, value in pairs(stats) do
        budget = budget + value
    end
    return budget
end

-- Calculate weighted gear score for an item based on class
function GearScoreCalculator:CalculateWeightedScore(stats, className)
    local score = 0
    
    for statType, value in pairs(stats) do
        local weight = GearScoreWeights:GetWeight(className, statType)
        score = score + (value * weight)
    end
    
    return score
end

-- Calculate gear score for a single item (returns both raw and weighted)
function GearScoreCalculator:CalculateItemScore(itemLink, className)
    if not itemLink or not className then
        return 0, 0
    end
    
    local stats = GearScoreItemParser:ParseItemStats(itemLink)
    local rawScore = self:CalculateRawStatBudget(stats)
    local weightedScore = self:CalculateWeightedScore(stats, className)
    
    return rawScore, weightedScore, stats
end

-- Calculate total gear score for all equipped items
function GearScoreCalculator:CalculateTotalGearScore(className)
    local equippedItems = GearScoreItemParser:GetEquippedItems()
    
    local totalRawScore = 0
    local totalWeightedScore = 0
    local itemScores = {}
    
    for slot, item in pairs(equippedItems) do
        local rawScore = self:CalculateRawStatBudget(item.stats)
        local weightedScore = self:CalculateWeightedScore(item.stats, className)
        
        totalRawScore = totalRawScore + rawScore
        totalWeightedScore = totalWeightedScore + weightedScore
        
        itemScores[slot] = {
            rawScore = rawScore,
            weightedScore = weightedScore,
            stats = item.stats,
            link = item.link,
        }
    end
    
    return {
        totalRawScore = totalRawScore,
        totalWeightedScore = totalWeightedScore,
        itemScores = itemScores,
    }
end

-- Get character class
function GearScoreCalculator:GetPlayerClass()
    local className = UnitClass("player")
    return className
end

-- Get current player's gear score
function GearScoreCalculator:GetPlayerGearScore()
    local className = self:GetPlayerClass()
    return self:CalculateTotalGearScore(className)
end
