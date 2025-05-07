-- Custom sorting algorithms for KOReader file browser
-- Place this file in {data_dir}/patches/

local BookList = require("ui/widget/booklist")
local ffiUtil = require("ffi/util")
local _ = require("gettext")

-- Common helper functions for our custom sorting algorithms
local CustomSorting = {
    -- Common item preparation function
    prepareItem = function(item, ui)
        -- Get document properties (metadata)
        local doc_props = ui.bookinfo:getDocProps(item.path or item.file)

        -- Ensure we have values for all fields we need to sort by
        doc_props.authors = doc_props.authors or "\u{FFFF}" -- Sort unknown authors last
        doc_props.series = doc_props.series or "\u{FFFF}" -- Sort books without series last
        doc_props.display_title = doc_props.display_title or item.text -- Use filename if no title
        doc_props.date = doc_props.date or "\u{FFFF}" -- Sort books without date last

        -- Store the properties in the item for use in the sorting function
        item.doc_props = doc_props
    end,

    -- Common function to format display information
    formatInfo = function(item)
        local info = ""
        if item.doc_props then
            if item.doc_props.authors and item.doc_props.authors ~= "\u{FFFF}" then
                info = item.doc_props.authors

                -- Add series information if available
                if item.doc_props.series and item.doc_props.series ~= "\u{FFFF}" then
                    if item.doc_props.series_index then
                        info = info .. " • " .. item.doc_props.series .. " #" .. item.doc_props.series_index
                    else
                        info = info .. " • " .. item.doc_props.series
                    end
                end

                -- Add published date if available
                if item.doc_props.date and item.doc_props.date ~= "\u{FFFF}" then
                    info = info .. " • " .. item.doc_props.date
                end
            end
        end
        return info
    end,

    -- Common comparison function for author and series
    compareAuthorSeries = function(a, b)
        -- First sort by author
        if a.doc_props.authors ~= b.doc_props.authors then
            return ffiUtil.strcoll(a.doc_props.authors, b.doc_props.authors)
        end

        -- If authors are the same, sort by series
        if a.doc_props.series ~= b.doc_props.series then
            return ffiUtil.strcoll(a.doc_props.series, b.doc_props.series)
        end

        -- If in the same series, sort by series index if available
        if a.doc_props.series_index and b.doc_props.series_index and
           a.doc_props.series ~= "\u{FFFF}" then -- Only if they're actually in a series
            return a.doc_props.series_index < b.doc_props.series_index
        end

        return nil -- No decision made, continue with specific comparison
    end
}

-- First sorting option: Author, Series, Title
BookList.collates.author_series_title = {
    text = _("author - series - title"),
    menu_order = 5, -- Position at the beginning of sorting methods
    can_collate_mixed = false, -- Keep folders separate from files

    -- Item preparation function
    item_func = function(item, ui)
        CustomSorting.prepareItem(item, ui)
    end,

    -- Sorting function
    init_sort_func = function()
        return function(a, b)
            -- Use common comparison for author and series
            local result = CustomSorting.compareAuthorSeries(a, b)
            if result ~= nil then
                return result
            end

            -- Finally, sort by title
            return ffiUtil.strcoll(a.doc_props.display_title, b.doc_props.display_title)
        end
    end,

    -- Display function
    mandatory_func = function(item)
        return CustomSorting.formatInfo(item)
    end,
}

-- Second sorting option: Author, Series, Published Date
BookList.collates.author_series_date = {
    text = _("author - series - published date"),
    menu_order = 6, -- Position right after the first custom sorting method
    can_collate_mixed = false, -- Keep folders separate from files

    -- Item preparation function
    item_func = function(item, ui)
        CustomSorting.prepareItem(item, ui)
    end,

    -- Sorting function
    init_sort_func = function()
        return function(a, b)
            -- Use common comparison for author and series
            local result = CustomSorting.compareAuthorSeries(a, b)
            if result ~= nil then
                return result
            end

            -- If no series index or same series index, sort by published date
            if a.doc_props.date ~= b.doc_props.date then
                return ffiUtil.strcoll(a.doc_props.date, b.doc_props.date)
            end

            -- If everything else is the same, sort by title as a fallback
            return ffiUtil.strcoll(a.doc_props.display_title, b.doc_props.display_title)
        end
    end,

    -- Display function
    mandatory_func = function(item)
        return CustomSorting.formatInfo(item)
    end,
}

return BookList.collates
