local itemConfig = require 'config.server.item'
local config = require 'config.laptop'
if not itemConfig.item then return end

local utils = require 'utils.server'
local ox_inventory = exports.ox_inventory
local MIN_PASSWORD_LENGTH = 4

---@type table<string, true>
local registeredStashes = {}

---@param password any
---@return string | nil
local function normalizePassword(password)
    if type(password) ~= 'string' then
        return nil
    end

    local normalized = password:match('^%s*(.-)%s*$')

    if normalized == '' then
        return nil
    end

    return normalized
end

---@param src number
---@param laptopId string
---@return number | nil, table | nil
local function getLaptopSlotById(src, laptopId)
    if not laptopId then return nil, nil end

    local slots = ox_inventory:Search(src, 'slots', itemConfig.item, {
        id = laptopId
    })

    if type(slots) ~= 'table' then
        return nil, nil
    end

    for _, slotData in pairs(slots) do
        if slotData.metadata?.id == laptopId then
            return slotData.slot, slotData.metadata
        end
    end

    return nil, nil
end

ox_inventory:registerHook('createItem', function(payload)
    local metadata = payload.metadata or {}

    -- Set metadata to include the recipe name
    if not metadata or not metadata.id then
        metadata = { id = utils.uuid() }
    end
    return metadata
end, {
    print = config.debug,
    itemFilter = {
        [itemConfig.item] = true
    }
})

ox_inventory:registerHook('swapItems', function(payload)
    if not string.find(payload.toInventory, 'fd_laptop_') then return true end
    if not payload.fromSlot then return false end
    if not payload.fromSlot.metadata then return false end
    if not payload.fromSlot.metadata?.deviceId then return false end
    if not payload.fromSlot.metadata?.deviceLabel then return false end

    if payload.fromSlot.metadata.noDuplicate then
        local count = ox_inventory:Search(payload.toInventory, 'count', payload.fromSlot.name, {
            deviceId = payload.fromSlot.metadata?.deviceId
        })

        if count > 0 then
            return false
        end
    end
end, {
    print = config.debug,
    inventoryFilter = {
        '^fd_laptop_[%w+]'
    }
})

local function registerStash(id)
    if not registeredStashes[id] then
        ox_inventory:RegisterStash(('fd_laptop_%s'):format(id), locale('laptop_stash_label'),
            itemConfig.slots,
            itemConfig.weight)
        registeredStashes[id] = true
    end
end

RegisterNetEvent('fd_laptop:server:openLaptopStorage', function(slot)
    local src = source

    local item = ox_inventory:GetSlot(src, slot)
    if not item then return end
    if not item.metadata?.id then return end

    if not registeredStashes[item.metadata.id] then
        registerStash(item.metadata.id)
    end

    ox_inventory:forceOpenInventory(src, 'stash', {
        id = ('fd_laptop_%s'):format(item.metadata.id)
    })
end)

exports('useLaptop', function(event, _, inventory, slot, _)
    if event == 'usingItem' then
        CreateThread(function()
            local item = ox_inventory:GetSlot(inventory.id, slot)
            if not item then return false end
            if not item.metadata?.id then return false end

            if not registeredStashes[item.metadata.id] then
                registerStash(item.metadata.id)
            end

            local items = exports.ox_inventory:GetInventoryItems(('fd_laptop_%s'):format(item.metadata.id)) or {}

            local devices = {}

            for _, item in pairs(items) do
                if item.metadata?.deviceId then
                    devices[#devices + 1] = {
                        slot = item.slot,
                        metadata = item.metadata
                    }
                end
            end

            local hasPassword = type(item.metadata?.password) == 'string' and item.metadata.password ~= ''

            TriggerEvent('fd_laptop:server:useLaptop', inventory.id, item.metadata?.id, devices, hasPassword)
        end)

        return false
    end
end)

lib.callback.register('fd_laptop:server:saveLaptopPassword', function(source, laptopId, password)
    local slot, metadata = getLaptopSlotById(source, laptopId)

    if not slot or not metadata then
        return false, locale('something_went_wrong'), false
    end

    local normalizedPassword = normalizePassword(password)

    if normalizedPassword and #normalizedPassword < MIN_PASSWORD_LENGTH then
        local hasPassword = type(metadata.password) == 'string' and metadata.password ~= ''

        return false, locale('laptop_password_too_short'), hasPassword
    end

    metadata.password = normalizedPassword
    ox_inventory:SetMetadata(source, slot, metadata)

    return true, nil, normalizedPassword ~= nil
end)

lib.callback.register('fd_laptop:server:validateLaptopPassword', function(source, laptopId, password)
    local _, metadata = getLaptopSlotById(source, laptopId)

    if not metadata then
        return false
    end

    local savedPassword = metadata.password

    if type(savedPassword) ~= 'string' or savedPassword == '' then
        return true
    end

    return type(password) == 'string' and savedPassword == password
end)
