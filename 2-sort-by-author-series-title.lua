-- Custom sorting algorithm for KOReader file browser
-- Place this file in {data_dir}/patches/sort-by-author-series-title.lua

local BookList = require("ui/widget/booklist")
local ffiUtil = require("ffi/util")
local _ = require("gettext")

-- Add our custom sorting algorithm to BookList.collates
BookList.collates.author_series_title = {
    text = _("author - series - title"),
    menu_order = 140, -- Position after existing sorting methods
    can_collate_mixed = false, -- Keep folders separate from files

    -- This function prepares the items for sorting by loading metadata
    item_func = function(item, ui)
        -- Get document properties (metadata)
        local doc_props = ui.bookinfo:getDocProps(item.path or item.file)

        -- Ensure we have values for all fields we need to sort by
        doc_props.authors = doc_props.authors or "\u{FFFF}" -- Sort unknown authors last
        doc_props.series = doc_props.series or "\u{FFFF}" -- Sort books without series last
        doc_props.display_title = doc_props.display_title or item.text -- Use filename if no title

        -- Store the properties in the item for use in the sorting function
        item.doc_props = doc_props
    end,

    -- This function returns the actual sorting function
    init_sort_func = function()
        return function(a, b)
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

            -- Finally, sort by title
            return ffiUtil.strcoll(a.doc_props.display_title, b.doc_props.display_title)
        end
    end,

    -- This function displays additional information in the file list
    mandatory_func = function(item)
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
            end
        end
        return info
    end,
}

return BookList.collates
