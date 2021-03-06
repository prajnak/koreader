--[[--
Widget that presents a multi-page to show key value pairs.

Example:

    local Foo = KeyValuePage:new{
        title = "Statistics",
        kv_pairs = {
            {"Current period", "00:00:00"},
            -- single or more "-" will generate a solid line
            "----------------------------",
            {"Page to read", "5"},
            {"Time to read", "00:01:00"},
            {"Press me", "will invoke the callback",
             callback = function() print("hello") end },
        },
    }
    UIManager:show(Foo)

]]

local InputContainer = require("ui/widget/container/inputcontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local VerticalGroup = require("ui/widget/verticalgroup")
local VerticalSpan = require("ui/widget/verticalspan")
local OverlapGroup = require("ui/widget/overlapgroup")
local LeftContainer = require("ui/widget/container/leftcontainer")
local RightContainer = require("ui/widget/container/rightcontainer")
local LineWidget = require("ui/widget/linewidget")
local Blitbuffer = require("ffi/blitbuffer")
local CloseButton = require("ui/widget/closebutton")
local UIManager = require("ui/uimanager")
local TextWidget = require("ui/widget/textwidget")
local GestureRange = require("ui/gesturerange")
local RenderText = require("ui/rendertext")
local Geom = require("ui/geometry")
local Font = require("ui/font")
local Device = require("device")
local Screen = Device.screen


local ellipsis, space = "…", "  "
local ellipsis_width, space_width
local function truncateTextByWidth(text, face, max_width, prepend_space)
    if not ellipsis_width then
        ellipsis_width = RenderText:sizeUtf8Text(0, max_width, face, ellipsis).x
    end
    if not space_width then
        space_width = RenderText:sizeUtf8Text(0, max_width, face, space).x
    end
    local new_txt_width = max_width - ellipsis_width - space_width
    local sub_txt = RenderText:getSubTextByWidth(text, face, new_txt_width)
    if prepend_space then
        return space.. sub_txt .. ellipsis
    else
        return sub_txt .. ellipsis .. space
    end
end


local KeyValueTitle = VerticalGroup:new{
    kv_page = nil,
    title = "",
    tface = Font:getFace("tfont"),
    align = "left",
}

function KeyValueTitle:init()
    self.close_button = CloseButton:new{ window = self }
    local btn_width = self.close_button:getSize().w
    local title_txt_width = RenderText:sizeUtf8Text(
                                0, self.width, self.tface, self.title).x
    local show_title_txt
    if self.width < (title_txt_width + btn_width) then
        show_title_txt = truncateTextByWidth(
                            self.title, self.tface, self.width-btn_width)
    else
        show_title_txt = self.title
    end
    -- title and close button
    table.insert(self, OverlapGroup:new{
        dimen = { w = self.width },
        TextWidget:new{
            text = show_title_txt,
            face = self.tface,
        },
        self.close_button,
    })
    -- page count and separation line
    self.page_cnt = FrameContainer:new{
        padding = 4,
        margin = 0,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        -- overlap offset x will be updated in setPageCount method
        overlap_offset = {0, -15},
        TextWidget:new{
            text = "",  -- page count
            fgcolor = Blitbuffer.COLOR_GREY,
            face = Font:getFace("ffont", 16),
        },
    }
    self.title_bottom = OverlapGroup:new{
        dimen = { w = self.width, h = Screen:scaleBySize(2) },
        LineWidget:new{
            dimen = Geom:new{ w = self.width, h = Screen:scaleBySize(2) },
            background = Blitbuffer.COLOR_GREY,
            style = "solid",
        },
        self.page_cnt,
    }
    table.insert(self, self.title_bottom)
    table.insert(self, VerticalSpan:new{ width = Screen:scaleBySize(5) })
end

function KeyValueTitle:setPageCount(curr, total)
    if total == 1 then
        -- remove page count if there is only one page
        table.remove(self.title_bottom, 2)
        return
    end
    self.page_cnt[1]:setText(curr .. "/" .. total)
    self.page_cnt.overlap_offset[1] = (self.width - self.page_cnt:getSize().w - 10)
    self.title_bottom[2] = self.page_cnt
end

function KeyValueTitle:onClose()
    self.kv_page:onClose()
    return true
end


local KeyValueItem = InputContainer:new{
    key = nil,
    value = nil,
    cface = Font:getFace("cfont"),
    width = nil,
    height = nil,
}

function KeyValueItem:init()
    self.dimen = Geom:new{w = self.width, h = self.height}

    if self.callback and Device:isTouchDevice() then
        self.ges_events.Tap = {
            GestureRange:new{
                ges = "tap",
                range = self.dimen,
            }
        }
    end

    local key_w = RenderText:sizeUtf8Text(0, self.width, self.cface, self.key).x
    local value_w = RenderText:sizeUtf8Text(0, self.width, self.cface, self.value).x
    if key_w + value_w > self.width then
        -- truncate key or value so they fits in one row
        if key_w >= value_w then
            self.show_key = truncateTextByWidth(self.key, self.cface, self.width-value_w)
            self.show_value = self.value
        else
            self.show_value = truncateTextByWidth(self.value, self.cface, self.width-key_w, true)
            self.show_key = self.key
        end
    else
        self.show_key = self.key
        self.show_value = self.value
    end

    self[1] = FrameContainer:new{
        padding = 0,
        bordersize = 0,
        OverlapGroup:new{
            dimen = self.dimen:copy(),
            LeftContainer:new{
                dimen = self.dimen:copy(),
                TextWidget:new{
                    text = self.show_key,
                    face = self.cface,
                }
            },
            RightContainer:new{
                dimen = self.dimen:copy(),
                TextWidget:new{
                    text = self.show_value,
                    face = self.cface,
                }
            }
        }
    }
end

function KeyValueItem:onTap()
    self.callback()
    return true
end


local KeyValuePage = InputContainer:new{
    title = "",
    width = nil,
    height = nil,
    -- index for the first item to show
    show_page = 1,
}

function KeyValuePage:init()
    self.dimen = Geom:new{
        w = self.width or Screen:getWidth(),
        h = self.height or Screen:getHeight(),
    }

    if Device:isTouchDevice() then
        self.ges_events.Swipe = {
            GestureRange:new{
                ges = "swipe",
                range = self.dimen,
            }
        }
    end

    local padding = Screen:scaleBySize(10)
    self.item_width = self.dimen.w - 2 * padding
    self.item_height = Screen:scaleBySize(30)
    -- setup title bar
    self.title_bar = KeyValueTitle:new{
        title = self.title,
        width = self.item_width,
        height = self.item_height,
        kv_page = self,
    }
    -- setup main content
    self.item_margin = self.item_height / 4
    local line_height = self.item_height + 2 * self.item_margin
    local content_height = self.dimen.h - self.title_bar:getSize().h
    self.items_per_page = math.floor(content_height / line_height)
    self.pages = math.ceil(#self.kv_pairs / self.items_per_page)
    self.main_content = VerticalGroup:new{}
    self:_populateItems()
    -- assemble page
    self[1] = FrameContainer:new{
        height = self.dimen.h,
        padding = padding,
        bordersize = 0,
        background = Blitbuffer.COLOR_WHITE,
        VerticalGroup:new{
            self.title_bar,
            self.main_content,
        },
    }
end

function KeyValuePage:nextPage()
    local new_page = math.min(self.show_page+1, self.pages)
    if new_page > self.show_page then
        self.show_page = new_page
        self:_populateItems()
    end
end

function KeyValuePage:prevPage()
    local new_page = math.max(self.show_page-1, 1)
    if new_page < self.show_page then
        self.show_page = new_page
        self:_populateItems()
    end
end

-- make sure self.item_margin and self.item_height are set before calling this
function KeyValuePage:_populateItems()
    self.main_content:clear()
    local idx_offset = (self.show_page - 1) * self.items_per_page
    for idx = 1, self.items_per_page do
        local entry = self.kv_pairs[idx_offset + idx]
        if entry == nil then break end

        table.insert(self.main_content,
                     VerticalSpan:new{ width = self.item_margin })
        if type(entry) == "table" then
            table.insert(
                self.main_content,
                KeyValueItem:new{
                    height = self.item_height,
                    width = self.item_width,
                    key = entry[1],
                    value = entry[2],
                    callback = entry.callback,
                }
            )
        elseif type(entry) == "string" then
            local c = string.sub(entry, 1, 1)
            if c == "-" then
                table.insert(self.main_content, LineWidget:new{
                    background = Blitbuffer.COLOR_LIGHT_GREY,
                    dimen = Geom:new{
                        w = self.item_width,
                        h = Screen:scaleBySize(2)
                    },
                    style = "solid",
                })
            end
        end
        table.insert(self.main_content,
                     VerticalSpan:new{ width = self.item_margin })
    end
    self.title_bar:setPageCount(self.show_page, self.pages)
    UIManager:setDirty(self, function()
        return "ui", self.dimen
    end)
end

function KeyValuePage:onSwipe(arg, ges_ev)
    if ges_ev.direction == "west" then
        self:nextPage()
        return true
    elseif ges_ev.direction == "east" then
        self:prevPage()
        return true
    end
end

function KeyValuePage:onClose()
    UIManager:close(self)
    return true
end

return KeyValuePage
