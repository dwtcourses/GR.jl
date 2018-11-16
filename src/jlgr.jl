module jlgr

import GR

@static if VERSION >= v"0.7.0-DEV.3476"
    using Serialization
    using Sockets
end

const None = Union{}

@static if VERSION < v"0.7.0-DEV.3137"
    const Nothing = Void
end

@static if VERSION < v"0.7.0-DEV.3155"
    const popfirst! = shift!
end

@static if VERSION >= v"0.7.0-DEV.3272"
    function search(s::AbstractString, c::Char)
        result = findfirst(isequal(c), s)
        result != nothing ? result : 0
    end
end

@static if VERSION < v"0.7.0-DEV.4534"
    reverse(a::AbstractArray; dims=nothing) =
        dims===nothing ? Base.reverse(a) : Base.flipdim(a, dims)
end

@static if VERSION >= v"0.7.0-DEV.4804"
    signif(x, digits; base = 10) = round(x, sigdigits = digits, base = base)
end

macro _tuple(t)
    :( Tuple{$t} )
end

const PlotArg = Union{AbstractString, AbstractVector, AbstractMatrix, Function}

const gr3 = GR.gr3

const plot_kind = [:line, :scatter, :stem, :hist, :contour, :contourf, :hexbin, :heatmap, :wireframe, :surface, :plot3, :scatter3, :imshow, :isosurface, :polar, :trisurf, :tricont, :shade]

const arg_fmt = [:xys, :xyac, :xyzc]

const kw_args = [:accelerate, :alpha, :backgroundcolor, :color, :colormap, :figsize, :isovalue, :labels, :levels, :location, :nbins, :rotation, :size, :tilt, :title, :xflip, :xform, :xlabel, :xlim, :xlog, :yflip, :ylabel, :ylim, :ylog, :zflip, :zlabel, :zlim, :zlog]

const colors = [
    [0xffffff, 0x000000, 0xff0000, 0x00ff00, 0x0000ff, 0x00ffff, 0xffff00, 0xff00ff] [0x282c34, 0xd7dae0, 0xcb4e42, 0x99c27c, 0x85a9fc, 0x5ab6c1, 0xd09a6a, 0xc57bdb] [0xfdf6e3, 0x657b83, 0xdc322f, 0x859900, 0x268bd2, 0x2aa198, 0xb58900, 0xd33682] [0x002b36, 0x839496, 0xdc322f, 0x859900, 0x268bd2, 0x2aa198, 0xb58900, 0xd33682]
    ]

const distinct_cmap = [ 0, 1, 984, 987, 989, 983, 994, 988 ]

@static if VERSION > v"0.7-"
  function linspace(start, stop, length)
    range(start, stop=stop, length=length)
  end
  repmat(A::AbstractArray, m::Int, n::Int) = repeat(A::AbstractArray, m::Int, n::Int)
end

mutable struct PlotObject
  obj
  args
  kvs
end

function Figure(width=600, height=450)
    obj = Dict()
    args = @_tuple(Any)
    kvs = Dict()
    kvs[:size] = (width, height)
    kvs[:ax] = false
    kvs[:subplot] = [0, 1, 0, 1]
    kvs[:clear] = true
    kvs[:update] = true
    PlotObject(obj, args, kvs)
end

function gcf()
    plt.kvs
end

plt = Figure()
ctx = Dict()
scheme = 0
background = 0xffffff

isrowvec(x::AbstractArray) = ndims(x) == 2 && size(x, 1) == 1 && size(x, 2) > 1

isvector(x::AbstractVector) = true
isvector(x::AbstractMatrix) = size(x, 1) == 1

function set_viewport(kind, subplot)
    mwidth, mheight, width, height = GR.inqdspsize()
    if haskey(plt.kvs, :figsize)
        w = 0.0254 *  width * plt.kvs[:figsize][1] / mwidth
        h = 0.0254 * height * plt.kvs[:figsize][2] / mheight
    else
        dpi = width / mwidth * 0.0254
        if dpi > 200
            w, h = [x * dpi / 100 for x in plt.kvs[:size]]
        else
            w, h = plt.kvs[:size]
        end
    end
    viewport = zeros(4)
    vp = copy(float(subplot))
    if w > h
        ratio = float(h) / w
        msize = mwidth * w / width
        GR.setwsviewport(0, msize, 0, msize * ratio)
        GR.setwswindow(0, 1, 0, ratio)
        vp[3] *= ratio
        vp[4] *= ratio
    else
        ratio = float(w) / h
        msize = mheight * h / height
        GR.setwsviewport(0, msize * ratio, 0, msize)
        GR.setwswindow(0, ratio, 0, 1)
        vp[1] *= ratio
        vp[2] *= ratio
    end
    if kind in (:wireframe, :surface, :plot3, :scatter3, :trisurf)
        extent = min(vp[2] - vp[1], vp[4] - vp[3])
        vp1 = 0.5 * (vp[1] + vp[2] - extent)
        vp2 = 0.5 * (vp[1] + vp[2] + extent)
        vp3 = 0.5 * (vp[3] + vp[4] - extent)
        vp4 = 0.5 * (vp[3] + vp[4] + extent)
    else
        vp1, vp2, vp3, vp4 = vp
    end
    viewport[1] = vp1 + 0.125 * (vp2 - vp1)
    viewport[2] = vp1 + 0.925 * (vp2 - vp1)
    viewport[3] = vp3 + 0.125 * (vp4 - vp3)
    viewport[4] = vp3 + 0.925 * (vp4 - vp3)

    if kind in (:contour, :contourf, :hexbin, :heatmap, :surface, :trisurf)
        viewport[2] -= 0.1
    end
    GR.setviewport(viewport[1], viewport[2], viewport[3], viewport[4])

    plt.kvs[:viewport] = viewport
    plt.kvs[:vp] = vp
    plt.kvs[:ratio] = ratio

    if haskey(plt.kvs, :backgroundcolor)
        GR.savestate()
        GR.selntran(0)
        GR.setfillintstyle(GR.INTSTYLE_SOLID)
        GR.setfillcolorind(plt.kvs[:backgroundcolor])
        if w > h
          GR.fillrect(subplot[1], subplot[2],
                      ratio * subplot[3], ratio * subplot[4])
        else
          GR.fillrect(ratio * subplot[1], ratio * subplot[2],
                      subplot[3], subplot[4])
        end
        GR.selntran(1)
        GR.restorestate()
    end

    if kind == :polar
        xmin, xmax, ymin, ymax = viewport
        xcenter = 0.5 * (xmin + xmax)
        ycenter = 0.5 * (ymin + ymax)
        r = 0.5 * min(xmax - xmin, ymax - ymin)
        GR.setviewport(xcenter - r, xcenter + r, ycenter - r, ycenter + r)
    end
end

function fix_minmax(a, b)
    if a == b
        a -= a != 0 ? 0.1 * a : 0.1
        b += b != 0 ? 0.1 * b : 0.1
    end
    a, b
end

function given(a)
    a != Nothing && a != "Nothing"
end

function Extrema64(a)
    amin =  typemax(Float64)
    amax = -typemax(Float64)
    for el in a
        if !isnan(el)
            if el < amin
                amin = el
            elseif el > amax
                amax = el
            end
        end
    end
    amin, amax
end

function minmax()
    xmin = ymin = zmin =  typemax(Float64)
    xmax = ymax = zmax = -typemax(Float64)
    for (x, y, z, c, spec) in plt.args
        if given(x)
            x0, x1 = Extrema64(x)
            xmin = min(x0, xmin)
            xmax = max(x1, xmax)
        else
            xmin, xmax = 0, 1
        end
        if given(y)
            y0, y1 = Extrema64(y)
            ymin = min(y0, ymin)
            ymax = max(y1, ymax)
        else
            ymin, ymax = 0, 1
        end
        if given(z)
            z0, z1 = Extrema64(z)
            zmin = min(z0, zmin)
            zmax = max(z1, zmax)
        end
    end
    xmin, xmax = fix_minmax(xmin, xmax)
    ymin, ymax = fix_minmax(ymin, ymax)
    zmin, zmax = fix_minmax(zmin, zmax)
    if haskey(plt.kvs, :xlim)
        x0, x1 = plt.kvs[:xlim]
        if x0 === Nothing x0 = xmin end
        if x1 === Nothing x1 = xmax end
        plt.kvs[:xrange] = (x0, x1)
    else
        plt.kvs[:xrange] = xmin, xmax
    end
    if haskey(plt.kvs, :ylim)
        y0, y1 = plt.kvs[:ylim]
        if y0 === Nothing y0 = ymin end
        if y1 === Nothing y1 = ymax end
        plt.kvs[:yrange] = (y0, y1)
    else
        plt.kvs[:yrange] = ymin, ymax
    end
    if haskey(plt.kvs, :zlim)
        z0, z1 = plt.kvs[:zlim]
        if z0 === Nothing z0 = zmin end
        if z1 === Nothing z1 = zmax end
        plt.kvs[:zrange] = (z0, z1)
    else
        plt.kvs[:zrange] = zmin, zmax
    end
end

function set_window(kind)
    scale = 0
    if kind != :polar
        get(plt.kvs, :xlog, false) && (scale |= GR.OPTION_X_LOG)
        get(plt.kvs, :ylog, false) && (scale |= GR.OPTION_Y_LOG)
        get(plt.kvs, :zlog, false) && (scale |= GR.OPTION_Z_LOG)
        get(plt.kvs, :xflip, false) && (scale |= GR.OPTION_FLIP_X)
        get(plt.kvs, :yflip, false) && (scale |= GR.OPTION_FLIP_Y)
        get(plt.kvs, :zflip, false) && (scale |= GR.OPTION_FLIP_Z)
    end

    minmax()

    if kind in (:wireframe, :surface, :plot3, :scatter3, :polar, :trisurf)
        major_count = 2
    else
        major_count = 5
    end

    xmin, xmax = plt.kvs[:xrange]
    if scale & GR.OPTION_X_LOG == 0
        if !haskey(plt.kvs, :xlim)
            xmin, xmax = GR.adjustlimits(xmin, xmax)
        end
        majorx = major_count
        xtick = GR.tick(xmin, xmax) / majorx
    else
        xtick = majorx = 1
    end
    if scale & GR.OPTION_FLIP_X == 0
        xorg = (xmin, xmax)
    else
        xorg = (xmax, xmin)
    end
    plt.kvs[:xaxis] = xtick, xorg, majorx

    ymin, ymax = plt.kvs[:yrange]
    if kind in (:stem, :hist) && !haskey(plt.kvs, :ylim)
        ymin = 0
    end
    if scale & GR.OPTION_Y_LOG == 0
        if !haskey(plt.kvs, :ylim)
            ymin, ymax = GR.adjustlimits(ymin, ymax)
        end
        majory = major_count
        ytick = GR.tick(ymin, ymax) / majory
    else
        ytick = majory = 1
    end
    if scale & GR.OPTION_FLIP_Y == 0
        yorg = (ymin, ymax)
    else
        yorg = (ymax, ymin)
    end
    plt.kvs[:yaxis] = ytick, yorg, majory

    if kind in (:wireframe, :surface, :plot3, :scatter3, :trisurf)
        zmin, zmax = plt.kvs[:zrange]
        if scale & GR.OPTION_Z_LOG == 0
            if !haskey(plt.kvs, :zlim)
                zmin, zmax = GR.adjustlimits(zmin, zmax)
            end
            majorz = major_count
            ztick = GR.tick(zmin, zmax) / majorz
        else
            ztick = majorz = 1
        end
        if scale & GR.OPTION_FLIP_Z == 0
            zorg = (zmin, zmax)
        else
            zorg = (zmax, zmin)
        end
        plt.kvs[:zaxis] = ztick, zorg, majorz
    end

    plt.kvs[:window] = xmin, xmax, ymin, ymax
    if kind != :polar
        GR.setwindow(xmin, xmax, ymin, ymax)
    else
        GR.setwindow(-1, 1, -1, 1)
    end
    if kind in (:wireframe, :surface, :plot3, :scatter3, :trisurf)
        rotation = get(plt.kvs, :rotation, 40)
        tilt = get(plt.kvs, :tilt, 70)
        GR.setspace(zmin, zmax, rotation, tilt)
    end

    plt.kvs[:scale] = scale
    GR.setscale(scale)
end

function draw_axes(kind, pass=1)
    viewport = plt.kvs[:viewport]
    vp = plt.kvs[:vp]
    ratio = plt.kvs[:ratio]
    xtick, xorg, majorx = plt.kvs[:xaxis]
    ytick, yorg, majory = plt.kvs[:yaxis]

    GR.setlinecolorind(1)
    diag = sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
    GR.setlinewidth(1)
    charheight = max(0.018 * diag, 0.012)
    GR.setcharheight(charheight)
    ticksize = 0.0075 * diag
    if kind in (:wireframe, :surface, :plot3, :scatter3, :trisurf)
        ztick, zorg, majorz = plt.kvs[:zaxis]
        if pass == 1
            GR.grid3d(xtick, 0, ztick, xorg[1], yorg[2], zorg[1], 2, 0, 2)
            GR.grid3d(0, ytick, 0, xorg[1], yorg[2], zorg[1], 0, 2, 0)
        else
            GR.axes3d(xtick, 0, ztick, xorg[1], yorg[1], zorg[1], majorx, 0, majorz, -ticksize)
            GR.axes3d(0, ytick, 0, xorg[2], yorg[1], zorg[1], 0, majory, 0, ticksize)
        end
    else
        if kind in (:heatmap, :shade)
            ticksize = -ticksize
        else
            GR.grid(xtick, ytick, 0, 0, majorx, majory)
        end
        GR.axes(xtick, ytick, xorg[1], yorg[1], majorx, majory, ticksize)
        GR.axes(xtick, ytick, xorg[2], yorg[2], -majorx, -majory, -ticksize)
    end

    if haskey(plt.kvs, :title)
        GR.savestate()
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
        text(0.5 * (viewport[1] + viewport[2]), vp[4], plt.kvs[:title])
        GR.restorestate()
    end
    if kind in (:wireframe, :surface, :plot3, :scatter3, :trisurf)
        xlabel = get(plt.kvs, :xlabel, "")
        ylabel = get(plt.kvs, :ylabel, "")
        zlabel = get(plt.kvs, :zlabel, "")
        GR.titles3d(xlabel, ylabel, zlabel)
    else
        if haskey(plt.kvs, :xlabel)
            GR.savestate()
            GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_BOTTOM)
            text(0.5 * (viewport[1] + viewport[2]), vp[3] + 0.5 * charheight, plt.kvs[:xlabel])
            GR.restorestate()
        end
        if haskey(plt.kvs, :ylabel)
            GR.savestate()
            GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
            GR.setcharup(-1, 0)
            text(vp[1] + 0.5 * charheight, 0.5 * (viewport[3] + viewport[4]), plt.kvs[:ylabel])
            GR.restorestate()
        end
    end
end

function draw_polar_axes()
    viewport = plt.kvs[:viewport]
    diag = sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
    charheight = max(0.018 * diag, 0.012)

    window = plt.kvs[:window]
    rmin, rmax = window[3], window[4]

    GR.savestate()
    GR.setcharheight(charheight)
    GR.setlinetype(GR.LINETYPE_SOLID)

    tick = 0.5 * GR.tick(rmin, rmax)
    n = round(Int, (rmax - rmin) / tick + 0.5)
    for i in 0:n
        r = float(i) / n
        if i % 2 == 0
            GR.setlinecolorind(88)
            if i > 0
                GR.drawarc(-r, r, -r, r, 0, 359)
            end
            GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
            x, y = GR.wctondc(0.05, r)
            GR.text(x, y, string(signif(rmin + i * tick, 12)))
        else
            GR.setlinecolorind(90)
            GR.drawarc(-r, r, -r, r, 0, 359)
        end
    end
    for alpha in 0:45:315
        a = alpha + 90
        sinf = sin(a * π / 180)
        cosf = cos(a * π / 180)
        GR.polyline([sinf, 0], [cosf, 0])
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_HALF)
        x, y = GR.wctondc(1.1 * sinf, 1.1 * cosf)
        GR.textext(x, y, string(alpha, "^o"))
    end
    GR.restorestate()
end

function inqtext(x, y, s)
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.inqmathtex(x, y, s[2:end-1])
    elseif search(s, '\\') != 0 || search(s, '_') != 0 || search(s, '^') != 0
        GR.inqtextext(x, y, s)
    else
        GR.inqtext(x, y, s)
    end
end

function text(x, y, s)
    if length(s) >= 2 && s[1] == '$' && s[end] == '$'
        GR.mathtex(x, y, s[2:end-1])
    elseif search(s, '\\') != 0 || search(s, '_') != 0 || search(s, '^') != 0
        GR.textext(x, y, s)
    else
        GR.text(x, y, s)
    end
end

function draw_legend()
    viewport = plt.kvs[:viewport]
    location = get(plt.kvs, :location, 1)
    num_labels = length(plt.kvs[:labels])
    GR.savestate()
    GR.selntran(0)
    GR.setscale(0)
    w = 0
    h = 0
    for label in plt.kvs[:labels]
        tbx, tby = inqtext(0, 0, label)
        w  = max(w, tbx[3])
        h += max(tby[3] - tby[1], 0.03)
    end
    if location in (8, 9, 10)
        px = 0.5 * (viewport[1] + viewport[2] - w)
    elseif location in (2, 3, 6)
        px = viewport[1] + 0.11
    else
        px = viewport[2] - 0.05 - w
    end
    if location in (5, 6, 7, 10)
        py = 0.5 * (viewport[3] + viewport[4] + h) - 0.03
    elseif location in (3, 4, 8)
        py = viewport[3] + h
    else
        py = viewport[4] - 0.06
    end
    GR.setfillintstyle(GR.INTSTYLE_SOLID)
    GR.setfillcolorind(0)
    GR.fillrect(px - 0.08, px + w + 0.02, py + 0.03, py - h)
    GR.setlinetype(GR.LINETYPE_SOLID)
    GR.setlinecolorind(1)
    GR.setlinewidth(1)
    GR.drawrect(px - 0.08, px + w + 0.02, py + 0.03, py - h)
    i = 1
    GR.uselinespec(" ")
    for (x, y, z, c, spec) in plt.args
        if i <= num_labels
            label = plt.kvs[:labels][i]
            tbx, tby = inqtext(0, 0, label)
            dy = max((tby[3] - tby[1]) - 0.03, 0)
            py -= 0.5 * dy
        end
        GR.savestate()
        mask = GR.uselinespec(spec)
        mask in (0, 1, 3, 4, 5) && GR.polyline([px - 0.07, px - 0.01], [py, py])
        mask & 0x02 != 0 && GR.polymarker([px - 0.06, px - 0.02], [py, py])
        GR.restorestate()
        GR.settextalign(GR.TEXT_HALIGN_LEFT, GR.TEXT_VALIGN_HALF)
        if i <= num_labels
            text(px, py, label)
            py -= 0.5 * dy
            i += 1
        end
        py -= 0.03
    end
    GR.selntran(1)
    GR.restorestate()
end

function colorbar(off=0, colors=256)
    GR.savestate()
    viewport = plt.kvs[:viewport]
    zmin, zmax = plt.kvs[:zrange]
    if get(plt.kvs, :zflip, false)
        options = (GR.inqscale() | GR.OPTION_FLIP_Y) & ~GR.OPTION_FLIP_X
        GR.setscale(options)
    elseif get(plt.kvs, :yflip, false)
        options = GR.inqscale() & ~GR.OPTION_FLIP_Y & ~GR.OPTION_FLIP_X
        GR.setscale(options)
    else
        options = GR.inqscale() & ~GR.OPTION_FLIP_X
        GR.setscale(options)
    end
    GR.setwindow(0, 1, zmin, zmax)
    GR.setviewport(viewport[2] + 0.02 + off, viewport[2] + 0.05 + off,
                   viewport[3], viewport[4])
    l = zeros(Int32, 1, colors)
    l[1,:] = Int[round(Int, _i) for _i in linspace(1000, 1255, colors)]
    GR.cellarray(0, 1, zmax, zmin, 1, colors, l)
    GR.setlinecolorind(1)
    diag = sqrt((viewport[2] - viewport[1])^2 + (viewport[4] - viewport[3])^2)
    charheight = max(0.016 * diag, 0.012)
    GR.setcharheight(charheight)
    if plt.kvs[:scale] & GR.OPTION_Z_LOG == 0
        ztick = 0.5 * GR.tick(zmin, zmax)
        GR.axes(0, ztick, 1, zmin, 0, 1, 0.005)
    else
        GR.setscale(GR.OPTION_Y_LOG)
        GR.axes(0, 2, 1, zmin, 0, 1, 0.005)
    end
    GR.restorestate()
end

function colormap()
    rgb = zeros(256, 3)
    for colorind in 1:256
        color = GR.inqcolor(999 + colorind)
        rgb[colorind, 1] = float( color        & 0xff) / 255.0
        rgb[colorind, 2] = float((color >> 8)  & 0xff) / 255.0
        rgb[colorind, 3] = float((color >> 16) & 0xff) / 255.0
    end
    rgb
end

function to_rgba(value, cmap)
    if !isnan(value)
        r, g, b = cmap[round(Int, value * 255 + 1), :]
        a = 1.0
    else
        r, g, b, a = zeros(4)
    end
    round(UInt32, a * 255) << 24 + round(UInt32, b * 255) << 16 +
    round(UInt32, g * 255) << 8  + round(UInt32, r * 255)
end

function create_context(kind, dict)
    plt.kvs[:kind] = kind
    plt.obj = copy(plt.kvs)
    for (k, v) in dict
        if ! (k in kw_args)
            println("Invalid keyword: $k")
        end
    end
    merge!(plt.kvs, dict)
end

function restore_context()
    global ctx
    ctx = copy(plt.kvs)
    plt.kvs = copy(plt.obj)
end

"""
Create a new figure with the given settings.

Settings like the current colormap, title or axis limits as stored in the
current figure. This function creates a new figure, restores the default
settings and applies any settings passed to the function as keyword
arguments.

**Usage examples:**

.. code-block:: julia

    julia> # Restore all default settings
    julia> figure()
    julia> # Restore all default settings and set the title
    julia> figure(title="Example Figure")
"""
function figure(; kv...)
    global plt
    plt = Figure()
    merge!(plt.kvs, Dict(kv))
    plt
end

"""
Set the hold flag for combining multiple plots.

The hold flag prevents drawing of axes and clearing of previous plots, so
that the next plot will be drawn on top of the previous one.

:param flag: the value of the hold flag

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> x = LinRange(0, 1, 100)
    julia> # Draw the first plot
    julia> plot(x, x.^2)
    julia> # Set the hold flag
    julia> hold(true)
    julia> # Draw additional plots
    julia> plot(x, x.^4)
    julia> plot(x, x.^8)
    julia> # Reset the hold flag
    julia> hold(false)
"""
function hold(flag)
    global ctx
    if plt.args != @_tuple(Any)
        plt.kvs[:ax] = flag
        plt.kvs[:clear] = !flag
        for k in (:window, :scale, :xaxis, :yaxis, :zaxis)
            if haskey(ctx, k)
                plt.kvs[k] = ctx[k]
            end
        end
    else
        println("Invalid hold state")
    end
    flag
end

function usecolorscheme(index)
    global scheme
    if 1 <= index <= 4
        scheme = index
    else
        println("Invalid color sheme")
    end
end

"""
Set current subplot index.

By default, the current plot will cover the whole window. To display more
than one plot, the window can be split into a number of rows and columns,
with the current plot covering one or more cells in the resulting grid.

Subplot indices are one-based and start at the upper left corner, with a
new row starting after every **num_columns** subplots.

:param num_rows: the number of subplot rows
:param num_columns: the number of subplot columns
:param subplot_indices:
	- the subplot index to be used by the current plot
	- a pair of subplot indices, setting which subplots should be covered
	  by the current plot

**Usage examples:**

.. code-block:: julia

    julia> # Set the current plot to the second subplot in a 2x3 grid
    julia> subplot(2, 3, 2)
    julia> # Set the current plot to cover the first two rows of a 4x2 grid
    julia> subplot(4, 2, (1, 4))
    julia> # Use the full window for the current plot
    julia> subplot(1, 1, 1)
"""
function subplot(nr, nc, p)
    xmin, xmax, ymin, ymax = 1, 0, 1, 0
    for i in collect(p)
        r = nr - div(i-1, nc)
        c = (i-1) % nc + 1
        xmin = min(xmin, (c-1)/nc)
        xmax = max(xmax, c/nc)
        ymin = min(ymin, (r-1)/nr)
        ymax = max(ymax, r/nr)
    end
    plt.kvs[:subplot] = [xmin, xmax, ymin, ymax]
    plt.kvs[:clear] = collect(p)[1] == 1
    plt.kvs[:update] = collect(p)[end] == nr * nc
end

function plot_img(I)
    viewport = plt.kvs[:vp][:]
    if haskey(plt.kvs, :title)
        viewport[4] -= 0.05
    end
    vp = plt.kvs[:vp]

    if isa(I, AbstractString)
        width, height, data = GR.readimage(I)
    else
        width, height = size(I)
        data = (float(I) .- minimum(I)) ./ (maximum(I) .- minimum(I))
        data = Int32[round(Int32, 1000 + _i * 255) for _i in data]
    end

    if width  * (viewport[4] - viewport[3]) <
        height * (viewport[2] - viewport[1])
        w = float(width) / height * (viewport[4] - viewport[3])
        xmin = max(0.5 * (viewport[1] + viewport[2] - w), viewport[1])
        xmax = min(0.5 * (viewport[1] + viewport[2] + w), viewport[2])
        ymin = viewport[3]
        ymax = viewport[4]
    else
        h = float(height) / width * (viewport[2] - viewport[1])
        xmin = viewport[1]
        xmax = viewport[2]
        ymin = max(0.5 * (viewport[4] + viewport[3] - h), viewport[3])
        ymax = min(0.5 * (viewport[4] + viewport[3] + h), viewport[4])
    end

    GR.selntran(0)
    GR.setscale(0)
    if get(plt.kvs, :xflip, false)
        tmp = xmax; xmax = xmin; xmin = tmp;
    end
    if get(plt.kvs, :yflip, false)
        tmp = ymax; ymax = ymin; ymin = tmp;
    end
    if isa(I, AbstractString)
        GR.drawimage(xmin, xmax, ymin, ymax, width, height, data)
    else
        GR.cellarray(xmin, xmax, ymin, ymax, width, height, data)
    end

    if haskey(plt.kvs, :title)
        GR.savestate()
        GR.settextalign(GR.TEXT_HALIGN_CENTER, GR.TEXT_VALIGN_TOP)
        text(0.5 * (viewport[1] + viewport[2]), vp[4], plt.kvs[:title])
        GR.restorestate()
    end
    GR.selntran(1)
end

function plot_iso(V)
    viewport = plt.kvs[:viewport]

    if viewport[4] - viewport[3] < viewport[2] - viewport[1]
        width = viewport[4] - viewport[3]
        centerx = 0.5 * (viewport[1] + viewport[2])
        xmin = max(centerx - 0.5 * width, viewport[1])
        xmax = min(centerx + 0.5 * width, viewport[2])
        ymin = viewport[3]
        ymax = viewport[4]
    else
        height = viewport[2] - viewport[1]
        centery = 0.5 * (viewport[3] + viewport[4])
        xmin = viewport[1]
        xmax = viewport[2]
        ymin = max(centery - 0.5 * height, viewport[3])
        ymax = min(centery + 0.5 * height, viewport[4])
    end

    GR.selntran(0)
    values = round.(UInt16, (V .- minimum(V)) ./ (maximum(V) .- minimum(V)) .* (2^16-1))
    nx, ny, nz = size(V)
    isovalue = (get(plt.kvs, :isovalue, 0.5) - minimum(V)) / (maximum(V) - minimum(V))
    rotation = get(plt.kvs, :rotation, 40) * π / 180.0
    tilt = get(plt.kvs, :tilt, 70) * π / 180.0
    r = 2.5
    gr3.clear()
    mesh = gr3.createisosurfacemesh(values, (2/(nx-1), 2/(ny-1), 2/(nz-1)),
                                    (-1., -1., -1.),
                                    round(Int64, isovalue * (2^16-1)))
    if haskey(plt.kvs, :color)
        color = plt.kvs[:color]
    else
        color = (0.0, 0.5, 0.8)
    end
    gr3.setbackgroundcolor(1, 1, 1, 0)
    gr3.drawmesh(mesh, 1, (0, 0, 0), (0, 0, 1), (0, 1, 0), color, (1, 1, 1))
    gr3.cameralookat(r*sin(tilt)*sin(rotation), r*cos(tilt), r*sin(tilt)*cos(rotation), 0, 0, 0, 0, 1, 0)
    gr3.drawimage(xmin, xmax, ymin, ymax, 500, 500, gr3.DRAWABLE_GKS)
    gr3.deletemesh(mesh)
    GR.selntran(1)
end

function plot_polar(θ, ρ)
    window = plt.kvs[:window]
    rmin, rmax = window[3], window[4]
    ρ = (ρ .- rmin) ./ (rmax .- rmin)
    n = length(ρ)
    x, y = zeros(n), zeros(n)
    for i in 1:n
        x[i] = ρ[i] * cos(θ[i])
        y[i] = ρ[i] * sin(θ[i])
    end
    GR.polyline(x, y)
end

function RGB(color)
    rgb = zeros(3)
    rgb[1] = float((color >> 16) & 0xff) / 255.0
    rgb[2] = float((color >> 8)  & 0xff) / 255.0
    rgb[3] = float( color        & 0xff) / 255.0
    rgb
end

to_double(a) = Float64[float(el) for el in a]
to_int(a) = Int32[el for el in a]

function send_meta(target)
    handle = GR.openmeta(target)
    if handle != C_NULL
        GR.sendmeta(handle, "o(")
        for (k, v) in plt.kvs
            GR.sendmetaref(handle, string(k), 's', string(v))
        end
        for (x, y, z, c, spec) in plt.args
            given(x) && GR.sendmetaref(handle, "x", 'D', to_double(x))
            given(y) && GR.sendmetaref(handle, "y", 'D', to_double(y))
            given(z) && GR.sendmetaref(handle, "z", 'D', to_double(z))
            given(c) && GR.sendmetaref(handle, "c", 'I', to_int(c))
            given(spec) && GR.sendmetaref(handle, "spec", 's', spec)
        end
        GR.sendmeta(handle, ")")
        GR.closemeta(handle)
    end
end

function send_serialized(target)
    handle = connect(target, 8001)
    io = IOBuffer()
    serialize(io, Dict("kvs" => plt.kvs, "args" => plt.args))
    write(handle, io.data)
    close(handle)
end

function contains_NaN(a)
    for el in a
        if el === NaN
            return true
        end
    end
    false
end

function plot_data(flag=true)
    global scheme, background

    if plt.args == @_tuple(Any)
        return
    end

    target = GR.displayname()
    if flag && target != None
        if target == "meta"
            send_meta(GR.TARGET_SOCKET)
        elseif target == "jsterm"
            send_meta(GR.TARGET_JUPYTER)
        else
            send_serialized()
        end
        return
    end

    kind = get(plt.kvs, :kind, :line)

    plt.kvs[:clear] && GR.clearws()

    if scheme != 0
        for colorind in 1:8
            color = colors[colorind, scheme]
            if colorind == 1
                background = color
            end
            r, g, b = RGB(color)
            GR.setcolorrep(colorind - 1, r, g, b)
            if scheme != 1
                GR.setcolorrep(distinct_cmap[colorind], r, g, b)
            end
        end
        r, g, b = RGB(colors[1, scheme])
        rdiff, gdiff, bdiff = RGB(colors[2, scheme]) - [r, g, b]
        for colorind in 1:12
            f = (colorind - 1) / 11.0
            GR.setcolorrep(92 - colorind, r + f*rdiff, g + f*gdiff, b + f*bdiff)
        end
    end

    set_viewport(kind, plt.kvs[:subplot])
    if !plt.kvs[:ax]
        set_window(kind)
        if kind == :polar
            draw_polar_axes()
        elseif kind != :imshow && kind != :isosurface
            draw_axes(kind)
        end
    end

    if haskey(plt.kvs, :colormap)
        GR.setcolormap(plt.kvs[:colormap])
    else
        GR.setcolormap(GR.COLORMAP_VIRIDIS)
    end

    GR.uselinespec(" ")
    for (x, y, z, c, spec) in plt.args
        GR.savestate()
        if haskey(plt.kvs, :alpha)
            GR.settransparency(plt.kvs[:alpha])
        end
        if kind == :line
            mask = GR.uselinespec(spec)
            mask in (0, 1, 3, 4, 5) && GR.polyline(x, y)
            mask & 0x02 != 0 && GR.polymarker(x, y)
        elseif kind == :scatter
            GR.setmarkertype(GR.MARKERTYPE_SOLID_CIRCLE)
            if given(z) || given(c)
                if given(c)
                    c = (c .- minimum(c)) ./ (maximum(c) .- minimum(c))
                    cind = Int[round(Int, 1000 + _i * 255) for _i in c]
                end
                for i in 1:length(x)
                    given(z) && GR.setmarkersize(z[i] / 100.0)
                    given(c) && GR.setmarkercolorind(cind[i])
                    GR.polymarker([x[i]], [y[i]])
                end
            else
                GR.polymarker(x, y)
            end
        elseif kind == :stem
            GR.setlinecolorind(1)
            GR.polyline([plt.kvs[:window][1]; plt.kvs[:window][2]], [0; 0])
            GR.setmarkertype(GR.MARKERTYPE_SOLID_CIRCLE)
            GR.uselinespec(spec)
            for i = 1:length(y)
                GR.polyline([x[i]; x[i]], [0; y[i]])
                GR.polymarker([x[i]], [y[i]])
            end
        elseif kind == :hist
            ymin = plt.kvs[:window][3]
            for i = 1:length(y)
                GR.setfillcolorind(989)
                GR.setfillintstyle(GR.INTSTYLE_SOLID)
                GR.fillrect(x[i], x[i+1], ymin, y[i])
                GR.setfillcolorind(1)
                GR.setfillintstyle(GR.INTSTYLE_HOLLOW)
                GR.fillrect(x[i], x[i+1], ymin, y[i])
            end
        elseif kind == :contour
            zmin, zmax = plt.kvs[:zrange]
            GR.setspace(zmin, zmax, 0, 90)
            levels = get(plt.kvs, :levels, 20)
            if typeof(levels) <: Int
                h = linspace(zmin, zmax, levels)
            else
                h = float(levels)
            end
            if length(x) == length(y) == length(z)
                x, y, z = GR.gridit(x, y, z, 200, 200)
            end
            GR.contour(x, y, h, z, 1000)
            colorbar(0, 20)
        elseif kind == :contourf
            zmin, zmax = plt.kvs[:zrange]
            GR.setspace(zmin, zmax, 0, 90)
            levels = get(plt.kvs, :levels, 20)
            if typeof(levels) <: Int
                h = linspace(zmin, zmax, levels)
            else
                h = float(levels)
            end
            if length(x) == length(y) == length(z)
                x, y, z = GR.gridit(x, y, z, 200, 200)
            end
            GR.contourf(x, y, h, z, 1000)
            colorbar(0, 20)
        elseif kind == :hexbin
            nbins = get(plt.kvs, :nbins, 40)
            cntmax = GR.hexbin(x, y, nbins)
            if cntmax > 0
                plt.kvs[:zrange] = 0, cntmax
                colorbar()
            end
        elseif kind == :heatmap
            w, h = size(z)
            cmap = colormap()
            data = (float(z) .- minimum(z)) ./ (maximum(z) .- minimum(z))
            if get(plt.kvs, :xflip, false)
                data = reverse(data, dims=1)
            end
            if get(plt.kvs, :yflip, false)
                data = reverse(data, dims=2)
            end
            rgba = [to_rgba(value, cmap) for value = data]
            GR.drawimage(0.5, w + 0.5, h + 0.5, 0.5, w, h, rgba)
            colorbar()
        elseif kind == :wireframe
            if length(x) == length(y) == length(z)
                x, y, z = GR.gridit(x, y, z, 50, 50)
            end
            GR.setfillcolorind(0)
            GR.surface(x, y, z, GR.OPTION_FILLED_MESH)
            draw_axes(kind, 2)
        elseif kind == :surface
            if length(x) == length(y) == length(z)
                x, y, z = GR.gridit(x, y, z, 200, 200)
            end
            if get(plt.kvs, :accelerate, true)
                gr3.clear()
                GR.gr3.surface(x, y, z, GR.OPTION_COLORED_MESH)
            else
                GR.surface(x, y, z, GR.OPTION_COLORED_MESH)
            end
            draw_axes(kind, 2)
            colorbar(0.05)
        elseif kind == :plot3
            GR.polyline3d(x, y, z)
            draw_axes(kind, 2)
        elseif kind == :scatter3
            GR.setmarkertype(GR.MARKERTYPE_SOLID_CIRCLE)
            if given(c)
                c = (c .- minimum(c)) ./ (maximum(c) .- minimum(c))
                cind = Int[round(Int, 1000 + _i * 255) for _i in c]
                for i in 1:length(x)
                    GR.setmarkercolorind(cind[i])
                    GR.polymarker3d([x[i]], [y[i]], [z[i]])
                end
            else
                GR.polymarker3d(x, y, z)
            end
            draw_axes(kind, 2)
        elseif kind == :imshow
            plot_img(z)
        elseif kind == :isosurface
            plot_iso(z)
        elseif kind == :polar
            GR.uselinespec(spec)
            plot_polar(x, y)
        elseif kind == :trisurf
            GR.trisurface(x, y, z)
            draw_axes(kind, 2)
            colorbar(0.05)
        elseif kind == :tricont
            zmin, zmax = plt.kvs[:zrange]
            levels = linspace(zmin, zmax, 20)
            GR.tricontour(x, y, z, levels)
        elseif kind == :shade
            xform = get(plt.kvs, :xform, 5)
            if contains_NaN(x)
                GR.shadelines(x, y, xform=xform)
            else
                GR.shadepoints(x, y, xform=xform)
            end
        end
        GR.restorestate()
    end

    if kind in (:line, :scatter, :stem) && haskey(plt.kvs, :labels)
        draw_legend()
    end

    if plt.kvs[:update]
        GR.updatews()
        if GR.isinline()
            restore_context()
            return GR.show()
        end
    end

    flag && restore_context()
    return
end

function plot_args(args; fmt=:xys)
    args = Any[args...]
    parsed_args = Any[]

    while length(args) > 0
        local x, y, z, c
        a = popfirst!(args)
        if isa(a, AbstractVecOrMat) || isa(a, Function)
            elt = eltype(a)
            if elt <: Complex
                x = real(a)
                y = imag(a)
                z = Nothing
                c = Nothing
            elseif elt <: Real || isa(a, Function)
                if fmt == :xys
                    if length(args) >= 1 &&
                       (isa(args[1], AbstractVecOrMat) && eltype(args[1]) <: Real || isa(args[1], Function))
                        x = a
                        y = popfirst!(args)
                        z = Nothing
                        c = Nothing
                    else
                        y = a
                        n = isrowvec(y) ? size(y, 2) : size(y, 1)
                        if haskey(plt.kvs, :xlim)
                            xmin, xmax = plt.kvs[:xlim]
                            x = linspace(xmin, xmax, n)
                        else
                            x = linspace(1, n, n)
                        end
                        z = Nothing
                        c = Nothing
                    end
                elseif fmt == :xyac || fmt == :xyzc
                    if length(args) >= 3 &&
                        isa(args[1], AbstractVecOrMat) && eltype(args[1]) <: Real &&
                       (isa(args[2], AbstractVecOrMat) && eltype(args[2]) <: Real || isa(args[2], Function)) &&
                       (isa(args[3], AbstractVecOrMat) && eltype(args[3]) <: Real || isa(args[3], Function))
                        x = a
                        y = popfirst!(args)
                        z = popfirst!(args)
                        c = popfirst!(args)
                    elseif length(args) >= 2 &&
                        isa(args[1], AbstractVecOrMat) && eltype(args[1]) <: Real &&
                       (isa(args[2], AbstractVecOrMat) && eltype(args[2]) <: Real || isa(args[2], Function))
                        x = a
                        y = popfirst!(args)
                        z = popfirst!(args)
                        c = Nothing
                    elseif fmt == :xyac && length(args) >= 1 &&
                       (isa(args[1], AbstractVecOrMat) && eltype(args[1]) <: Real || isa(args[1], Function))
                        x = a
                        y = popfirst!(args)
                        z = Nothing
                        c = Nothing
                    elseif fmt == :xyzc && length(args) == 0
                        z = a
                        nx, ny = size(z)
                        if haskey(plt.kvs, :xlim)
                            xmin, xmax = plt.kvs[:xlim]
                            x = linspace(xmin, xmax, nx)
                        else
                            x = linspace(1, nx, nx)
                        end
                        if haskey(plt.kvs, :ylim)
                            ymin, ymax = plt.kvs[:ylim]
                            y = linspace(ymin, ymax, ny)
                        else
                            y = linspace(1, ny, ny)
                        end
                        c = Nothing
                    end
                end
            else
                error("expected Real or Complex")
            end
        else
            error("expected array or function")
        end
        if isa(y, Function)
            f = y
            y = Float64[f(a) for a in x]
        end
        if isa(z, Function)
            f = z
            z = Float64[f(a,b) for b in y, a in x]
        end
        spec = ""
        if fmt == :xys && length(args) > 0 && isa(args[1], AbstractString)
            spec = popfirst!(args)
        end
        push!(parsed_args, (x, y, z, c, spec))
    end

    pltargs = Any[]

    for arg in parsed_args
        x, y, z, c, spec = arg

        isa(x, UnitRange) && (x = collect(x))
        isa(y, UnitRange) && (y = collect(y))
        isa(z, UnitRange) && (z = collect(z))
        isa(c, UnitRange) && (c = collect(c))

        isvector(x) && (x = vec(x))

        if typeof(y) == Function
            y = [y(a) for a in x]
        else
            isvector(y) && (y = vec(y))
        end
        if given(z)
            if fmt == :xyzc && typeof(z) == Function
                z = [z(a,b) for a in x, b in y]
            else
                isvector(z) && (z = vec(z))
            end
        end
        if given(c)
            isvector(c) && (c = vec(c))
        end

        local xyzc
        if !given(z)
            if isa(x, AbstractVector) && isa(y, AbstractVector)
                xyzc = [ (x, y, z, c) ]
            elseif isa(x, AbstractVector)
                xyzc = length(x) == size(y, 1) ?
                       [ (x, view(y,:,j), z, c) for j = 1:size(y, 2) ] :
                       [ (x, view(y,i,:), z, c) for i = 1:size(y, 1) ]
            elseif isa(y, AbstractVector)
                xyzc = size(x, 1) == length(y) ?
                       [ (view(x,:,j), y, z, c) for j = 1:size(x, 2) ] :
                       [ (view(x,i,:), y, z, c) for i = 1:size(x, 1) ]
            else
                @assert size(x) == size(y)
                xyzc = [ (view(x,:,j), view(y,:,j), z, c) for j = 1:size(y, 2) ]
            end
        elseif isa(x, AbstractVector) && isa(y, AbstractVector) &&
               (isa(z, AbstractVector) || typeof(z) == Array{Float64,2} ||
                typeof(z) == Array{Int32,2} || typeof(z) == Array{Any,2})
            xyzc = [ (x, y, z, c) ]
        else
            xyzc = [ (vec(float(x)), vec(float(y)), vec(float(z)), c) ]
        end
        for (x, y, z, c) in xyzc
            push!(pltargs, (x, y, z, c, spec))
        end
    end

    pltargs
end

"""
Draw one or more line plots.

This function can receive one or more of the following:

- x values and y values, or
- x values and a callable to determine y values, or
- y values only, with their indices as x values

:param args: the data to plot

**Usage examples:**

.. code-block:: julia-repl

    julia> # Create example data
    julia> x = LinRange(-2, 2, 40)
    julia> y = 2 .* x .+ 4
    julia> # Plot x and y
    julia> plot(x, y)
    julia> # Plot x and a callable
    julia> plot(x, t -> t^3 + t^2 + t)
    julia> # Plot y, using its indices for the x values
    julia> plot(y)

"""
function plot(args::PlotArg...; kv...)
    create_context(:line, Dict(kv))

    if plt.kvs[:ax]
        plt.args = append!(plt.args, plot_args(args))
    else
        plt.args = plot_args(args)
    end

    plot_data()
end

"""
Draw one or more line plots over another plot.

This function can receive one or more of the following:

- x values and y values, or
- x values and a callable to determine y values, or
- y values only, with their indices as x values

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> x = LinRange(-2, 2, 40)
    julia> y = 2 .* x .+ 4
    julia> # Draw the first plot
    julia> plot(x, y)
    julia> # Plot graph over it
    julia> oplot(x, x.^3 .+ x.^2 .+ x)
"""
function oplot(args::PlotArg...; kv...)
    create_context(:line, Dict(kv))

    plt.args = append!(plt.args, plot_args(args))

    plot_data()
end

"""
Draw one or more scatter plots.

This function can receive one or more of the following:

- x values and y values, or
- x values and a callable to determine y values, or
- y values only, with their indices as x values

Additional to x and y values, you can provide values for the markers'
size and color. Size values will determine the marker size in percent of
the regular size, and color values will be used in combination with the
current colormap.

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> x = LinRange(-2, 2, 40)
    julia> y = 0.2 .* x .+ 0.4
    julia> # Plot x and y
    julia> scatter(x, y)
    julia> # Plot x and a callable
    julia> scatter(x, 0.2 .* x .+ 0.4)
    julia> # Plot y, using its indices for the x values
    julia> scatter(y)
    julia> # Plot a diagonal with increasing size and color
    julia> x = LinRange(0, 1, 11)
    julia> y = LinRange(0, 1, 11)
    julia> s = LinRange(50, 400, 11)
    julia> c = LinRange(0, 255, 11)
    julia> scatter(x, y, s, c)
"""
function scatter(args...; kv...)
    create_context(:scatter, Dict(kv))

    plt.args = plot_args(args, fmt=:xyac)

    plot_data()
end

"""
Draw a stem plot.

This function can receive one or more of the following:

- x values and y values, or
- x values and a callable to determine y values, or
- y values only, with their indices as x values

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> x = LinRange(-2, 2, 40)
    julia> y = 0.2 .* x .+ 0.4
    julia> # Plot x and y
    julia> stem(x, y)
    julia> # Plot x and a callable
    julia> stem(x, x.^3 .+ x.^2 .+ x .+ 6)
    julia> # Plot y, using its indices for the x values
    julia> stem(y)
"""
function stem(args...; kv...)
    create_context(:stem, Dict(kv))

    plt.args = plot_args(args)

    plot_data()
end

function hist(x, nbins::Integer=0)
    if nbins <= 1
        nbins = round(Int, 3.3 * log10(length(x))) + 1
    end

    xmin, xmax = extrema(x)
    edges = linspace(xmin, xmax, nbins + 1)
    counts = zeros(nbins)
    buckets = Int[max(2, min(searchsortedfirst(edges, xᵢ), length(edges)))-1 for xᵢ in x]
    for b in buckets
        counts[b] += 1
    end
    collect(edges), counts
end

"""
Draw a histogram.

If **nbins** is **Nothing** or 0, this function computes the number of
bins as 3.3 * log10(n) + 1,  with n as the number of elements in x,
otherwise the given number of bins is used for the histogram.

:param x: the values to draw as histogram
:param num_bins: the number of bins in the histogram

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> x = 2 .* rand(100) .- 1
    julia> # Draw the histogram
    julia> histogram(x)
    julia> # Draw the histogram with 19 bins
    julia> histogram(x, nbins=19)
"""
function histogram(x; kv...)
    create_context(:hist, Dict(kv))

    nbins = get(plt.kvs, :nbins, 0)
    x, y = hist(x, nbins)
    plt.args = [(x, y, Nothing, Nothing, "")]

    plot_data()
end

"""
Draw a contour plot.

This function uses the current colormap to display a either a series of
points or a two-dimensional array as a contour plot. It can receive one
or more of the following:

- x values, y values and z values, or
- N x values, M y values and z values on a NxM grid, or
- N x values, M y values and a callable to determine z values

If a series of points is passed to this function, their values will be
interpolated on a grid. For grid points outside the convex hull of the
provided points, a value of 0 will be used.

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example point data
    julia> x = 8 .* rand(100) .- 4
    julia> y = 8 .* rand(100) .- 4
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the contour plot
    julia> contour(x, y, z)
    julia> # Create example grid data
    julia> X = LinRange(-2, 2, 40)
    julia> Y = LinRange(0, pi, 20)
    julia> x, y = meshgrid(X, Y)
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the contour plot
    julia> contour(x, y, z)
    julia> # Draw the contour plot using a callable
    julia> contour(x, y, sin.(x) .+ cos.(y))
"""
function contour(args...; kv...)
    create_context(:contour, Dict(kv))

    plt.args = plot_args(args, fmt=:xyzc)

    plot_data()
end

"""
Draw a filled contour plot.

This function uses the current colormap to display a either a series of
points or a two-dimensional array as a filled contour plot. It can
receive one or more of the following:

- x values, y values and z values, or
- N x values, M y values and z values on a NxM grid, or
- N x values, M y values and a callable to determine z values

If a series of points is passed to this function, their values will be
interpolated on a grid. For grid points outside the convex hull of the
provided points, a value of 0 will be used.

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example point data
    julia> x = 8 .* rand(100) .- 4
    julia> y = 8 .* rand(100) .- 4
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the contour plot
    julia> contourf(x, y, z)
    julia> # Create example grid data
    julia> X = LinRange(-2, 2, 40)
    julia> Y = LinRange(0, pi, 20)
    julia> x, y = meshgrid(X, Y)
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the contour plot
    julia> contourf(x, y, z)
    julia> # Draw the contour plot using a callable
    julia> contourf(x, y, sin.(x) .+ cos.(y))
"""
function contourf(args...; kv...)
    create_context(:contourf, Dict(kv))

    plt.args = plot_args(args, fmt=:xyzc)

    plot_data()
end

"""
Draw a hexagon binning plot.

This function uses hexagonal binning and the the current colormap to
display a series of points. It  can receive one or more of the following:

- x values and y values, or
- x values and a callable to determine y values, or
- y values only, with their indices as x values

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> x = randn(100000)
    julia> y = randn(100000)
    julia> # Draw the hexbin plot
    julia> hexbin(x, y)
"""
function hexbin(args...; kv...)
    create_context(:hexbin, Dict(kv))

    plt.args = plot_args(args)

    plot_data()
end

"""
Draw a heatmap.

This function uses the current colormap to display a two-dimensional
array as a heatmap. The array is drawn with its first value in the upper
left corner, so in some cases it may be neccessary to flip the columns
(see the example below).

By default the function will use the row and column indices for the x- and
y-axes, so setting the axis limits is recommended. Also note that the
values in the array must lie within the current z-axis limits so it may
be neccessary to adjust these limits or clip the range of array values.

:param data: the heatmap data

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> X = LinRange(-2, 2, 40)
    julia> Y = LinRange(0, pi, 20)
    julia> x, y = meshgrid(X, Y)
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the heatmap
    julia> heatmap(z)
"""
function heatmap(D; kv...)
    create_context(:heatmap, Dict(kv))

    if ndims(D) == 2
        z = D'
        width, height = size(z)
        if !haskey(plt.kvs, :xlim) plt.kvs[:xlim] = (0.5, width + 0.5) end
        if !haskey(plt.kvs, :ylim) plt.kvs[:ylim] = (0.5, height + 0.5) end

        plt.args = [(1:width, 1:height, z, Nothing, "")]

        plot_data()
    else
        error("expected 2-D array")
    end
end

"""
Draw a three-dimensional wireframe plot.

This function uses the current colormap to display a either a series of
points or a two-dimensional array as a wireframe plot. It can receive one
or more of the following:

- x values, y values and z values, or
- N x values, M y values and z values on a NxM grid, or
- N x values, M y values and a callable to determine z values

If a series of points is passed to this function, their values will be
interpolated on a grid. For grid points outside the convex hull of the
provided points, a value of 0 will be used.

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example point data
    julia> x = 8 .* rand(100) .- 4
    julia> y = 8 .* rand(100) .- 4
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the wireframe plot
    julia> wireframe(x, y, z)
    julia> # Create example grid data
    julia> X = LinRange(-2, 2, 40)
    julia> Y = LinRange(0, pi, 20)
    julia> x, y = meshgrid(X, Y)
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the wireframe plot
    julia> wireframe(x, y, z)
    julia> # Draw the wireframe plot using a callable
    julia> wireframe(x, y, sin.(x) .+ cos.(y))
"""
function wireframe(args...; kv...)
    create_context(:wireframe, Dict(kv))

    plt.args = plot_args(args, fmt=:xyzc)

    plot_data()
end

"""
Draw a three-dimensional surface plot.

This function uses the current colormap to display a either a series of
points or a two-dimensional array as a surface plot. It can receive one or
more of the following:

- x values, y values and z values, or
- N x values, M y values and z values on a NxM grid, or
- N x values, M y values and a callable to determine z values

If a series of points is passed to this function, their values will be
interpolated on a grid. For grid points outside the convex hull of the
provided points, a value of 0 will be used.

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example point data
    julia> x = 8 .* rand(100) .- 4
    julia> y = 8 .* rand(100) .- 4
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the surface plot
    julia> surface(x, y, z)
    julia> # Create example grid data
    julia> X = LinRange(-2, 2, 40)
    julia> Y = LinRange(0, pi, 20)
    julia> x, y = meshgrid(X, Y)
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the surface plot
    julia> surface(x, y, z)
    julia> # Draw the surface plot using a callable
    julia> surface(x, y, sin.(x) .+ cos.(y))
"""
function surface(args...; kv...)
    create_context(:surface, Dict(kv))

    plt.args = plot_args(args, fmt=:xyzc)

    plot_data()
end

"""
Draw one or more three-dimensional line plots.

:param x: the x coordinates to plot
:param y: the y coordinates to plot
:param z: the z coordinates to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> x = LinRange(0, 30, 1000)
    julia> y = cos.(x) .* x
    julia> z = sin.(x) .* x
    julia> # Plot the points
    julia> plot3(x, y, z)
"""
function plot3(args...; kv...)
    create_context(:plot3, Dict(kv))

    plt.args = plot_args(args, fmt=:xyzc)

    plot_data()
end

"""
Draw one or more three-dimensional scatter plots.

Additional to x, y and z values, you can provide values for the markers'
color. Color values will be used in combination with the current colormap.

:param x: the x coordinates to plot
:param y: the y coordinates to plot
:param z: the z coordinates to plot
:param c: the optional color values to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> x = 2 .* rand(100) .- 1
    julia> y = 2 .* rand(100) .- 1
    julia> z = 2 .* rand(100) .- 1
    julia> c = 999 .* rand(100) .+ 1
    julia> # Plot the points
    julia> scatter3(x, y, z)
    julia> # Plot the points with colors
    julia> scatter3(x, y, z, c)
"""
function scatter3(args...; kv...)
    create_context(:scatter3, Dict(kv))

    plt.args = plot_args(args, fmt=:xyzc)

    plot_data()
end

"""
Set the plot title.

The plot title is drawn using the extended text function GR.textext.
You can use a subset of LaTeX math syntax, but will need to escape
certain characters, e.g. parentheses. For more information see the
documentation of GR.textext.

:param title: the plot title

**Usage examples:**

.. code-block:: julia

    julia> # Set the plot title to "Example Plot"
    julia> title("Example Plot")
    julia> # Clear the plot title
    julia> title("")
"""
function title(s)
    if s != ""
        plt.kvs[:title] = s
    else
        delete!(plt.kvs, :title)
    end
    s
end

"""
Set the x-axis label.

The axis labels are drawn using the extended text function GR.textext.
You can use a subset of LaTeX math syntax, but will need to escape
certain characters, e.g. parentheses. For more information see the
documentation of GR.textext.

:param x_label: the x-axis label

**Usage examples:**

.. code-block:: julia

    julia> # Set the x-axis label to "x"
    julia> xlabel("x")
    julia> # Clear the x-axis label
    julia> xlabel("")
"""
function xlabel(s)
    if s != ""
        plt.kvs[:xlabel] = s
    else
        delete!(plt.kvs, :xlabel)
    end
    s
end

"""
Set the y-axis label.

The axis labels are drawn using the extended text function GR.textext.
You can use a subset of LaTeX math syntax, but will need to escape
certain characters, e.g. parentheses. For more information see the
documentation of GR.textext.

:param y_label: the y-axis label
"""
function ylabel(s)
    if s != ""
        plt.kvs[:ylabel] = s
    else
        delete!(plt.kvs, :ylabel)
    end
    s
end

function legend(args::AbstractString...; kv...)
    plt.kvs[:labels] = args
end

"""
Set the limits for the x-axis.

The x-axis limits can either be passed as individual arguments or as a
tuple of (**x_min**, **x_max**). Setting either limit to **Nothing** will
cause it to be automatically determined based on the data, which is the
default behavior.

:param x_min:
	- the x-axis lower limit, or
	- **Nothing** to use an automatic lower limit, or
	- a tuple of both x-axis limits
:param x_max:
	- the x-axis upper limit, or
	- **Nothing** to use an automatic upper limit, or
	- **Nothing** if both x-axis limits were passed as first argument
:param adjust: whether or not the limits may be adjusted

**Usage examples:**

.. code-block:: julia

    julia> # Set the x-axis limits to -1 and 1
    julia> xlim((-1, 1))
    julia> # Reset the x-axis limits to be determined automatically
    julia> xlim()
    julia> # Reset the x-axis upper limit and set the lower limit to 0
    julia> xlim((0, Nothing))
    julia> # Reset the x-axis lower limit and set the upper limit to 1
    julia> xlim((Nothing, 1))
"""
function xlim(a)
    plt.kvs[:xlim] = a
end

"""
Set the limits for the y-axis.

The y-axis limits can either be passed as individual arguments or as a
tuple of (**y_min**, **y_max**). Setting either limit to **Nothing** will
cause it to be automatically determined based on the data, which is the
default behavior.

:param y_min:
	- the y-axis lower limit, or
	- **Nothing** to use an automatic lower limit, or
	- a tuple of both y-axis limits
:param y_max:
	- the y-axis upper limit, or
	- **Nothing** to use an automatic upper limit, or
	- **Nothing** if both y-axis limits were passed as first argument
:param adjust: whether or not the limits may be adjusted

**Usage examples:**

.. code-block:: julia

    julia> # Set the y-axis limits to -1 and 1
    julia> ylim((-1, 1))
    julia> # Reset the y-axis limits to be determined automatically
    julia> ylim()
    julia> # Reset the y-axis upper limit and set the lower limit to 0
    julia> ylim((0, Nothing))
    julia> # Reset the y-axis lower limit and set the upper limit to 1
    julia> ylim((Nothing, 1))
"""
function ylim(a)
    plt.kvs[:ylim] = a
end

"""
Save the current figure to a file.

This function draw the current figure using one of GR's workstation types
to create a file of the given name. Which file types are supported depends
on the installed workstation types, but GR usually is built with support
for .png, .jpg, .pdf, .ps, .gif and various other file formats.

:param filename: the filename the figure should be saved to

**Usage examples:**

.. code-block:: julia

    julia> # Create a simple plot
    julia> x = 1:100
    julia> plot(x, 1 ./ (x .+ 1))
    julia> # Save the figure to a file
    julia> savefig("example.png")
"""
function savefig(filename)
    GR.beginprint(filename)
    plot_data(false)
    GR.endprint()
end

function meshgrid(vx, vy)
    m, n = length(vy), length(vx)
    vx = reshape(vx, 1, n)
    vy = reshape(vy, m, 1)
    (repmat(vx, m, 1), repmat(vy, 1, n))
end

function meshgrid(vx, vy, vz)
    m, n, o = length(vy), length(vx), length(vz)
    vx = reshape(vx, 1, n, 1)
    vy = reshape(vy, m, 1, 1)
    vz = reshape(vz, 1, 1, o)
    om = ones(Int, m)
    on = ones(Int, n)
    oo = ones(Int, o)
    (vx[om, :, oo], vy[:, on, oo], vz[om, on, :])
end

function peaks(n=49)
    x = LinRange(-2.5, 2.5, n)
    y = x
    x, y = meshgrid(x, y)
    3 * (1 .- x).^2 .* exp.(-(x.^2) .- (y.+1).^2) .- 10*(x/5 .- x.^3 .- y.^5) .* exp.(-x.^2 .- y.^2) .- 1/3 * exp.(-(x.+1).^2 .- y.^2)
end

"""
Draw an image.

This function can draw an image either from reading a file or using a
two-dimensional array and the current colormap.

:param image: an image file name or two-dimensional array

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> X = LinRange(-2, 2, 40)
    julia> Y = LinRange(0, pi, 20)
    julia> x, y = meshgrid(X, Y)
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw an image from a 2d array
    julia> imshow(z)
    julia> # Draw an image from a file
    julia> imshow("example.png")
"""
function imshow(I; kv...)
    create_context(:imshow, Dict(kv))

    plt.args = [(Nothing, Nothing, I, Nothing, "")]

    plot_data()
end

"""
Draw an isosurface.

This function can draw an image either from reading a file or using a
two-dimensional array and the current colormap. Values greater than the
isovalue will be seen as outside the isosurface, while values less than
the isovalue will be seen as inside the isosurface.

:param v: the volume data
:param isovalue: the isovalue

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> s = LinRange(-1, 1, 40)
    julia> x, y, z = meshgrid(s, s, s)
    julia> v = 1 .- (x .^ 2 .+ y .^ 2 .+ z .^ 2) .^ 0.5
    julia> # Draw an image from a 2d array
    julia> isosurface(v, isovalue=0.2)
"""
function isosurface(V; kv...)
    create_context(:isosurface, Dict(kv))

    plt.args = [(Nothing, Nothing, V, Nothing, "")]

    plot_data()
end

function cart2sph(x, y, z)
    azimuth = atan2.(y, x)
    elevation = atan2.(z, sqrt.(x.^2 + y.^2))
    r = sqrt.(x.^2 + y.^2 + z.^2)
    azimuth, elevation, r
end

function sph2cart(azimuth, elevation, r)
    x = r .* cos.(elevation) .* cos.(azimuth)
    y = r .* cos.(elevation) .* sin.(azimuth)
    z = r .* sin.(elevation)
    x, y, z
end

"""
Draw one or more polar plots.

This function can receive one or more of the following:

- angle values and radius values, or
- angle values and a callable to determine radius values

:param args: the data to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example data
    julia> angles = LinRange(0, 2pi, 40)
    julia> radii = LinRange(0, 2, 40)
    julia> # Plot angles and radii
    julia> polar(angles, radii)
    julia> # Plot angles and a callable
    julia> polar(angles, cos.(radii) .^ 2)
"""
function polar(args...; kv...)
    create_context(:polar, Dict(kv))

    plt.args = plot_args(args)

    plot_data()
end

"""
Draw a triangular surface plot.

This function uses the current colormap to display a series of points
as a triangular surface plot. It will use a Delaunay triangulation to
interpolate the z values between x and y values. If the series of points
is concave, this can lead to interpolation artifacts on the edges of the
plot, as the interpolation may occur in very acute triangles.

:param x: the x coordinates to plot
:param y: the y coordinates to plot
:param z: the z coordinates to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example point data
    julia> x = 8 .* rand(100) .- 4
    julia> y = 8 .* rand(100) .- 4
    julia> z = sin.(x) .+ cos.(y)
    julia> # Draw the triangular surface plot
    julia> trisurf(x, y, z)
"""
function trisurf(args...; kv...)
    create_context(:trisurf, Dict(kv))

    plt.args = plot_args(args, fmt=:xyzc)

    plot_data()
end

"""
Draw a triangular contour plot.

This function uses the current colormap to display a series of points
as a triangular contour plot. It will use a Delaunay triangulation to
interpolate the z values between x and y values. If the series of points
is concave, this can lead to interpolation artifacts on the edges of the
plot, as the interpolation may occur in very acute triangles.

:param x: the x coordinates to plot
:param y: the y coordinates to plot
:param z: the z coordinates to plot

**Usage examples:**

.. code-block:: julia

    julia> # Create example point data
    julia> x = 8 .* rand(100) .- 4
    julia> y = 8 .* rand(100) .- 4
    julia> z = sin.(x) + cos.(y)
    julia> # Draw the triangular contour plot
    julia> tricont(x, y, z)
"""
function tricont(args...; kv...)
    create_context(:tricont, Dict(kv))

    plt.args = plot_args(args, fmt=:xyzc)

    plot_data()
end

function shade(args...; kv...)
    create_context(:shade, Dict(kv))

    plt.args = plot_args(args, fmt=:xys)

    plot_data()
end

function mainloop()
    server = listen(8001)
    try
        while true
            sock = accept(server)
            while isopen(sock)
                io = IOBuffer()
                write(io, read(sock))
                seekstart(io)

                obj = deserialize(io)
                merge!(plt.kvs, obj["kvs"])
                plt.args = obj["args"]

                plot_data(false)
            end
        end
    catch
        true
    end
end

end # module
