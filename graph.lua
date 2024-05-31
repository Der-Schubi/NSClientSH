-- This is a lua script for use in Conky.
require 'cairo'

function conky_main ()
    if conky_window == nil then
        return
    end
    local cs = cairo_xlib_surface_create (conky_window.display,
                                         conky_window.drawable,
                                         conky_window.visual,
                                         conky_window.width,
                                         conky_window.height)
    cr = cairo_create (cs)

    local x_origin = 5
    local y_origin = 235
    local width = 200
    local height = 50

    local BG_cutoff = 60
    local x_scale = 5.65
    local y_scale = 4

    local saveLastXValues = 36

    local glucoseValues = {}

    local handle = io.popen('/etc/conky/entries.sh')
    local output = handle:read('*a')
    local result = output:gsub('[\n\r]', ' ')
    handle:close()

    local output = {}
    for match in result:gmatch("([%d%.%+%-]+),?") do
      glucoseValues[#glucoseValues + 1] = tonumber(match)
    end


    -- Range markings 70..180 / 3.9..10.0
    local y_70 = (y_origin + height) - 1 - ((70 - BG_cutoff) / y_scale)
    local y_180 = (y_origin + height) - 1 - ((180 - BG_cutoff) / y_scale)

    cairo_move_to(cr, x_origin, y_70)
    cairo_line_to(cr, x_origin + width, y_70)

    cairo_move_to(cr, x_origin, y_180)
    cairo_line_to(cr, x_origin + width, y_180)

    cairo_set_line_width(cr, 1.5)
    cairo_set_source_rgb (cr, .3, .3, .3);
    cairo_stroke(cr)

    for i = 1, saveLastXValues - 1, 1 
    do 
      BG_this = (glucoseValues[saveLastXValues - i] - BG_cutoff) / y_scale
      BG_last = (glucoseValues[saveLastXValues - i + 1] - BG_cutoff) / y_scale
      x1 = ((i - 1) * x_scale) + x_origin
      x2 = (i * x_scale) + x_origin
      y1 = y_origin + height - 1 - BG_last
      y2 = y_origin + height - 1 - BG_this

      cairo_move_to(cr, x1, y1)
      cairo_line_to(cr, x2, y2)
    end

    cairo_set_line_width(cr, 1.5)
    cairo_set_source_rgb (cr, 1, 1, 1);
    cairo_stroke(cr)

    cairo_destroy (cr)
    cairo_surface_destroy (cs)
    cr = nil
end
