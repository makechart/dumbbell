module.exports =
  pkg:
    name: 'dumbbell', version: '0.0.1'
    # lite: 不帶 d3 的 base. 補間走 chart.anim, 可以逐格錄影 ( 見 @plotdb/chart utils/anim )
    extend: {name: "@makechart/base", path: "lite/index.html"}
    dependencies: []
    i18n:
      "zh-TW":
        # dimension
        "name": "名稱"
        "start": "起點"
        "end": "終點"
        # legend / tooltip
        "increase": "增加"
        "decrease": "減少"
        "difference": "差距"
        # config: 區塊
        "orientation": "方向"
        "sort": "排序"
        "dot": "端點"
        "line": "連接線"
        "label": "數值標籤"
        "delta": "差值標籤"
        "row": "列"
        "grid": "格線"
        "valueAxis": "數值軸"
        "categoryAxis": "類別軸"
        "animation": "動畫"
        # config: 項目
        "field": "依據"
        "dir": "方向"
        "size": "大小"
        "style": "樣式"
        "startColor": "起點顏色"
        "endColor": "終點顏色"
        "stroke": "描邊顏色"
        "strokeWidth": "描邊粗細"
        "width": "粗細"
        "mode": "顏色模式"
        "color": "顏色"
        "opacity": "透明度"
        "show": "顯示"
        "format": "格式"
        "position": "位置"
        "font": "字型"
        "padding": "列間距"
        "stripe": "斑馬紋"
        "value": "數值軸格線"
        "category": "每列導引線"
        "dash": "虛線長度"
        "increaseColor": "增加的顏色"
        "decreaseColor": "減少的顏色"
        "includeZero": "包含 0"
        "maxLabelWidth": "標籤最大寬度 (%)"
        "enabled": "啟用"
        "duration": "時間長度 (ms)"
        "stagger": "逐列延遲 (ms)"
        # config: 選項
        "horizontal": "水平"
        "vertical": "垂直"
        "none": "原順序"
        "diff": "差值"
        "abs": "差值絕對值"
        "asc": "升冪"
        "desc": "降冪"
        "fill": "填滿"
        "hollow": "空心"
        "single": "單色"
        "gradient": "漸層"
        "outside": "外側"
        "side": "側邊"
        "middle": "連接線旁"
        "column": "獨立一欄"
        "auto": "自動"
  init: ({root, context, t, pubsub}) ->
    pubsub.fire \init, mod: mod {context, t}

svgns = "http://www.w3.org/2000/svg"
# 沒指定 palette 時的兩端配色: 起點低調、終點醒目, 讀的時候眼睛會先落在「現在」
default-colors = <[#a9b4c2 #2f6fde]>
# 標籤與端點之間的距離 ( px )
GAP = 3

num = (v) -> if typeof(v) == \number and isFinite(v) => v else null
clean = (v) -> +v.toPrecision(12)
# konfig 把 false / 0 的預設值丟掉 ( 見 @plotdb/chart 的 default-config ), 沒設定時要自己補
on-off = (v, def) -> if v? => !!v else def
# konfig 的 color widget 會用 ldcolor.web 轉預設值, `auto` 會變成 `transparent`, 兩者都算自動
is-auto = (c) -> !c or c in <[auto transparent]>

# 字太長就從尾巴截掉, 補上刪節號. 以字元 ( 不是 UTF-16 code unit ) 為單位才不會切壞 emoji
ellipsis = (text, max, width) ->
  if width(text) <= max => return text
  cs = Array.from text
  [lo, hi] = [0, cs.length]
  while lo < hi
    m = Math.ceil((lo + hi) / 2)
    if width(cs.slice(0, m).join('').trimEnd! + '…') <= max => lo = m else hi = m - 1
  cs.slice(0, lo).join('').trimEnd! + '…'

# 預設的 SI 格式遇到小於 1 的數會變成 200m, 比例型的資料很難讀, 這種時候改用有效位數.
# 使用者自己指定格式就照他的
smart-format = (format, fmt, def) ->
  f = format.from(fmt or def)
  if fmt and fmt != def => return f
  g = format.from def.replace(/s$/, \r)
  (v) -> if v and Math.abs(v) < 1 => g(v) else f(v)

# 兩端的刻度取整, 軸的頭尾才會落在漂亮的數字上
nice-domain = (lo, hi, count, ticks) ->
  if lo == hi =>
    if lo == 0 => hi = 1
    else
      d = Math.abs(lo) * 0.1
      [lo, hi] = [lo - d, hi + d]
  ts = ticks lo, hi, count
  if ts.length < 2 => return [lo, hi]
  step = ts.1 - ts.0
  [clean(Math.floor(lo / step) * step), clean(Math.ceil(hi / step) * step)]

mod = ({context, t}) ->
  {chart} = context
  {scale: Scale, format, anim: {join}} = chart.utils

  # ---------------------------------------------------------------- 版面
  # 標籤沿著數值軸往外佔多少 [低側, 高側]. R 是端點半徑 ( 含描邊 )
  extent-of = (e, R) ->
    if !e.side => return [e.along >? R, e.along >? R]
    if e.side < 0 => [R + GAP + e.along, R] else [R, R + GAP + e.along]

  # 數值軸的 range 要讓最外側的標籤放得下, 而 range 又決定端點落在哪:
  # 互相影響, 所以反覆逼近幾次. 只有真的靠邊的標籤才會撐開, 中間的不必留白
  fit = (c) ->
    box = c.layout.get-box \view
    hz = c.horizontal
    [L, C] = if hz => [box.width, box.height] else [box.height, box.width]
    p = (c.cfg.row.padding ? 0.3) >? 0 <? 0.9
    c.scale.c.padding-inner(p).padding-outer(p / 2).range [0, C]
    bw = c.scale.c.bandwidth!
    dot = c.cfg.dot
    r = ((dot.size or 6) <? (bw / 2)) >? 1
    sw = if dot.style == \hollow => (dot.stroke-width or 2) else (dot.stroke-width or 0)
    R = r + sw / 2
    # 端點被列高壓小時線也要跟著細, 不然線比點還搶眼
    lw = (c.cfg.line.width ? 2) <? (if r < (dot.size or 6) => r * 0.7 else r * 2)
    c.mark = {r, sw, R, lw, bw, step: c.scale.c.step!}
    # 列太密時標籤一定擠在一起, 留一半不如全部不放
    step = c.scale.c.step!
    c.dense = if hz => step < (c.label-h * 0.95) else step < c.label-w
    specs = if c.dense => [] else c.specs
    col = if c.dense or !c.delta-column => 0 else c.delta-column
    base = R + 1
    [a, b] = [base, base + col]
    s = c.scale.v
    apply = -> s.range(if hz => [a, L - b] else [L - a, b])
    u = (v) -> if hz => s(v) else L - s(v)
    for i from 0 til 3
      apply!
      [na, nb] = [base, base + col]
      for e in specs
        pos = u e.v
        [lo, hi] = extent-of e, R
        # 多留一點, 字才不會貼著軸或差值欄
        na >?= lo + 4 - (pos - a)
        nb >?= col + hi + 4 - (L - b - pos)
      [a, b] = [na <? (L * 0.35), nb <? (L * 0.45)]
    apply!
    c.box-view = box

  # ---------------------------------------------------------------- 軸
  # 軸的字級: 格子的字級, 再套 config 指定的大小. 跟 chart.utils.axis 畫字時的算法一致
  axis-font = (c, name, cfg) ->
    base = parseFloat(getComputedStyle(c.layout.get-node name).fontSize) or 12
    m = /^\s*([\d.]+)\s*(em|px)?/.exec("#{(cfg.label.font or {}).size or ''}")
    if !m => return base
    if m.2 == \px => +m.1 else base * +m.1

  # 餵給 chart.utils.axis 的 tick. 軸在 ticks() 裡有個「一個 tick 至少 25px」的安全閥,
  # 列比 25px 密就會先抽掉一半, 根本輪不到它自己依實際字高挑選的 adjust.
  # 啞鈴圖每一列都有名字要讀, 所以這裡讓安全閥不作用, 交給 adjust
  set-ticks = (axis, ticks) ->
    n = axis._n.layout
    n.getBoundingClientRect = -> {width: 1e6, height: 1e6}
    axis.ticks ticks
    delete n.getBoundingClientRect

  # 軸設定. 一樣是 false / 0 的預設值被丟掉的問題 - 軸自己的 fallback 是 inner = 8
  axis-config = (cfg, inner) ->
    ret = {} <<< cfg
    ret.tick = {} <<< cfg.tick
    ret.tick.inner = cfg.tick.inner ? inner
    ret.tick.boundary-offset = cfg.tick.boundary-offset ? false
    ret

  setup-axes = (c) ->
    cfg = c.cfg
    hz = c.horizontal
    [vname, cname] = if hz => <[xaxis yaxis]> else <[yaxis xaxis]>
    [vaxis, caxis] = [c[vname], c[cname]]
    vcfg = axis-config cfg.value-axis, 4
    ccfg = axis-config cfg.category-axis, 0
    vaxis.config vcfg
    # 垂直時名字是橫向排列, 字跟字之間至少要留半個字寬才分得開
    if !hz => ccfg.label = {} <<< ccfg.label <<< {gap: (ccfg.label.gap ? 0.1) >? 0.5}
    caxis.config ccfg

    # 數值軸
    box = c.layout.get-box \view
    L = if hz => box.width else box.height
    maxtick = Math.ceil(L / (if hz => 80 else 40)) >? 2
    count = (cfg.value-axis.tick.count or 4) <? maxtick
    vs = c.items.reduce ((a, item) -> a ++ item.pts.map (.v)), []
    [lo, hi] = if vs.length => [Math.min.apply(Math, vs), Math.max.apply(Math, vs)] else [0, 1]
    if cfg.value-axis.include-zero => [lo, hi] = [lo <? 0, hi >? 0]
    c.scale.v.domain nice-domain(lo, hi, count, Scale.ticks)
    # 沒有資料就別畫出一條 0 ~ 1 的假軸
    c.vticks = if vs.length => c.scale.v.ticks(count) else []
    vfmt = smart-format format, cfg.value-axis.label.format, \.3~s
    # 兩個軸會因方向切換互換, 沿用同一個 tick 物件時殘留的 t 不能留著, 所以一律給 t
    set-ticks vaxis, c.vticks.map -> {v: it, t: vfmt(it)}
    vaxis.scale c.scale.v
    units = <[start end]>.map(-> (c.binding[it] or {}).unit or '').filter -> it
    vaxis.caption(if units.length and units.every(-> it == units.0) => units.0 else '')

    # 類別軸. band 的 domain 用排序後的序號: 同名的列才不會疊在一起, 數字型的名字也不會被當數值格式化
    c.scale.c.domain [0 til c.items.length]
    node = c.layout.get-group cname
    size = axis-font c, cname, ccfg
    probe = document.createElementNS svgns, \text
    probe.style.fontSize = "#{size}px"
    probe.setAttribute \class, ((ccfg.label.font.family or {}).className or '')
    node.appendChild probe
    memo = new Map!
    width = (s) ->
      if !memo.has(s) =>
        probe.textContent = s
        memo.set s, probe.getComputedTextLength!
      memo.get s
    pct = (ccfg.max-label-width or 30) / 100
    max = if hz => box.width * pct
    else if ccfg.label.direction == \vertical => box.height * pct
    else
      # 橫放在下方: 放不下就交給軸抽著顯示, 但也別讓單一個名字長到佔掉半張圖
      step = box.width / (c.items.length or 1)
      (step - size * 0.5) >? (size * 5) <? (box.width * pct)
    set-ticks caxis, c.items.map (item) -> {v: item.pos, t: ellipsis(item.name, max, width)}
    probe.parentNode.removeChild probe
    caxis.scale c.scale.c
    b = c.binding.name or {}
    caxis.caption(if ccfg.caption.show => (b.name or b.key or '') else '')

  # ---------------------------------------------------------------- 標籤文字
  # 量字用的探針. 掛在標籤自己的 group 裡, 字型才會跟實際畫出來的一樣
  text-metric = (group) ->
    probe = document.createElementNS svgns, \text
    group.appendChild probe
    memo = new Map!
    h = parseFloat(getComputedStyle(group).fontSize) or 12
    {
      h
      w: (s) ->
        if !memo.has(s) =>
          probe.textContent = s
          memo.set s, probe.getComputedTextLength!
        memo.get s
      done: -> if probe.parentNode => probe.parentNode.removeChild probe
    }

  # 字級的基準跟軸的文字相同 ( 1em = 軸的字級 )
  set-font = (c, group, font = {}, cls) ->
    group.style.fontSize = "#{axis-font c, \xaxis, {label: {font}}}px"
    group.setAttribute \class, "#cls #{(font.family or {}).className or ''}".trim!

  # 每一列的標籤內容 ( 位置要等數值軸定下來才算 )
  build-labels = (c) ->
    cfg = c.cfg
    hz = c.horizontal
    set-font c, c.g.label, cfg.label.font, \labels
    set-font c, c.g.delta, cfg.delta.font, \deltas
    ml = text-metric c.g.label
    md = text-metric c.g.delta
    fl = smart-format format, cfg.label.format, \.3~s
    fd = smart-format format, cfg.delta.format, \+.3~s
    outside = cfg.label.position != \side
    c.label-h = ml.h
    c.specs = []
    c.label-w = 0
    c.delta-column = 0
    c.items.map (item) ->
      item.labels = []
      item.delta-label = null
      pts = item.pts
      if on-off(cfg.label.show, true) and pts.length =>
        # 一樣的值只留一個; 另一端在低側, 這一端在高側, 兩個字才不會對撞
        list = if pts.length == 2 and pts.0.v != pts.1.v =>
          [lo, hi] = if pts.0.v < pts.1.v => pts else [pts.1, pts.0]
          [{pt: lo, side: -1}, {pt: hi, side: 1}]
        else [{pt: pts[* - 1], side: 1}]
        list.map ({pt, side}) ->
          text = fl pt.v
          w = ml.w text
          # along: 沿著數值軸的長度. 側邊模式下字是置中在端點上的, 只算一半
          along = if outside => (if hz => w else ml.h) else (if hz => w / 2 else ml.h / 2)
          e = {id: "#{item.key}:#{pt.k}", item, pt, text, w, h: ml.h, v: pt.v, side: (if outside => side else 0), along}
          item.labels.push e
          c.specs.push e
          c.label-w >?= w
      if on-off(cfg.delta.show, false) and pts.length == 2 and item.delta != 0 =>
        text = fd item.delta
        w = md.w text
        item.delta-label = {id: item.key, item, text, w, h: md.h}
        c.label-w >?= w
        if cfg.delta.position == \column =>
          c.delta-column >?= (if hz => w + GAP * 3 else md.h + GAP * 2)
    ml.done!
    md.done!

  # ---------------------------------------------------------------- mod
  sample: ->
    # department survey: satisfaction score, 2023 vs 2024
    raw: [
      ["Engineering", 68, 79], ["Design", 74, 81], ["Marketing", 71, 65]
      ["Sales", 58, 66], ["Finance", 63, 70], ["Operations", 55, 52]
      ["Support", 49, 61], ["Legal", 66, 69], ["Research", 77, 84]
    ].map -> {department: it.0, "2023": it.1, "2024": it.2}
    binding:
      name: {key: \department}
      start: {key: "2023"}
      end: {key: "2024"}

  config: do ->
    c = chart.utils.config.from {
      preset: \default, legend: \legend, tip: \tip
      valueAxis: \axis, categoryAxis: \axis
    }
    auto = (def = \auto) -> {
      type: \color, default: def, presets: <[auto]>
      i18n: {en: {auto: "Auto"}, "zh-TW": {auto: "自動"}}
    }
    font = -> JSON.parse(JSON.stringify chart.utils.config.preset.font)
    c.tip.format.default = \.3~s
    # 只有兩項 ( 起點 / 終點 ), 放右邊太浪費寬度, 也沒有「全選 / 全不選」的必要
    c.legend.position.default = \bottom
    c.legend.selectable.default = false
    c.legend.sort.mode.default = \none

    c.value-axis.label.format.default = \.3~s
    c.value-axis.tick.boundary-offset.default = false
    c.value-axis.tick.inner.default = 4
    c.value-axis.baseline.show.default = false
    c.value-axis <<<
      # 點的位置才是編碼, 不像長條的長度必須從 0 算起, 所以預設不含 0
      include-zero: type: \boolean, default: false
    # 水平時一列一個名字, 字高剛好放得下就該顯示, 不要因為留白被抽掉
    c.category-axis.label.gap.default = 0.1
    c.category-axis.tick.inner.default = 0
    c.category-axis.baseline.show.default = false
    c.category-axis.caption.show.default = false
    c.category-axis <<<
      max-label-width: type: \number, default: 30, min: 5, max: 80, step: 1

    c <<<
      orientation: type: \choice, values: <[horizontal vertical]>, default: \horizontal
      sort:
        field: type: \choice, values: <[none start end diff abs name]>, default: \none
        dir: type: \choice, values: <[asc desc]>, default: \desc
      dot:
        size: type: \number, default: 6, min: 1, max: 30, step: 0.5
        style: type: \choice, values: <[fill hollow]>, default: \fill
        start-color: auto!
        end-color: auto!
        stroke: auto!
        stroke-width: type: \number, default: 0, min: 0, max: 10, step: 0.5
      line:
        width: type: \number, default: 2, min: 0.5, max: 20, step: 0.5
        mode: type: \choice, values: <[single delta gradient]>, default: \single
        color: type: \color, default: \#8c96a3
        increase-color: type: \color, default: \#1480d8
        decrease-color: type: \color, default: \#e8760a
        opacity: type: \number, default: 0.7, min: 0, max: 1, step: 0.05
      label:
        show: type: \boolean, default: true
        format: type: \format, default: \.3~s
        position: type: \choice, values: <[outside side]>, default: \outside
        color: auto \currentColor
        font: font!
      delta:
        show: type: \boolean, default: false
        format: type: \format, default: \+.3~s
        position: type: \choice, values: <[middle column]>, default: \middle
        color: auto!
        font: font!
      row:
        padding: type: \number, default: 0.3, min: 0, max: 0.9, step: 0.05
        stripe: type: \boolean, default: false
      grid:
        value: type: \boolean, default: true
        category: type: \boolean, default: false
        color: type: \color, default: \currentColor
        opacity: type: \number, default: 0.12, min: 0, max: 1, step: 0.01
        dash: type: \number, default: 0, min: 0, max: 20, step: 1
      animation:
        enabled: type: \boolean, default: true
        duration: type: \number, default: 350, min: 0, max: 3000, step: 50
        stagger: type: \number, default: 0, min: 0, max: 200, step: 5
    c

  dimension:
    start: {type: \R, name: "start"}
    end: {type: \R, name: "end"}
    name: {type: \NCO, name: "name"}

  init: ->
    self = @
    @tint = new chart.utils.tint!
    @g = view: @layout.get-group \view
    mk = (tag, cls) ~>
      n = document.createElementNS svgns, tag
      if cls => n.setAttribute \class, cls
      @g.view.appendChild n
    @g <<<
      defs: mk \defs
      grid: mk \g, \grid
      rows: mk \g, \rows
      label: mk \g, \labels
      delta: mk \g, \deltas
    # 漸層的 id 要在整頁唯一
    @uid = "dumbbell-#{Math.random!toString(36).substring(2)}"
    @gid = {map: {}, n: 0}
    @scale = {c: Scale.band!, v: Scale.linear!}
    @xaxis = new chart.utils.axis layout: @layout, name: \xaxis, direction: \bottom
    @yaxis = new chart.utils.axis layout: @layout, name: \yaxis, direction: \left
    @legend = new chart.utils.legend do
      layout: @layout
      name: \legend
      root: @root
      shape: (d) ->
        # 這裡的 @ 是 legend 的 circle
        col = (self.colors or {})[d.key]
        hollow = self.cfg.dot.style == \hollow and d.key in <[start end]>
        @setAttribute \fill, if hollow => \none else col
        @setAttribute \stroke, if hollow => col else \none
        @setAttribute \stroke-width, if hollow => 2 else 0
    @legend.on \select, ~> @resize!; @render!

    # tip 自己的預設版型只有一個值, 這裡要並排兩端與差距
    node = document.createElement \div
    row = (k) -> """
    <div style="display:flex;justify-content:space-between;gap:1em;white-space:nowrap">
      <span ld="#{k}-name"></span><span ld="#{k}-value" style="font-weight:bold"></span>
    </div>
    """
    node.innerHTML = """<div ld="title" style="font-size:.85em;margin-bottom:.2em"></div>
    #{row \start}#{row \end}#{row \diff}"""
    node.style <<<
      padding: '.4em .6em'
      background: \#13171a
      color: \#fff
      borderRadius: \3px
      boxShadow: '0 2px 4px rgba(0,0,0,.3)'
      lineHeight: \1.3em
      fontSize: \.85em
      maxWidth: \18em
    @root.appendChild node
    tx = (f) -> ({ctx}) -> if ctx => f(ctx) else ''
    @label-of = (k) ~>
      b = @binding[k] or {}
      b.name or b.key or t(k)
    @tip = new chart.utils.tip {
      root: @root
      node: node
      view:
        title: tx (.title)
        "start-name": tx (.start-name)
        "start-value": tx (.start-value)
        "end-name": tx (.end-name)
        "end-value": tx (.end-value)
        "diff-name": tx (.diff-name)
        "diff-value": tx (.diff-value)
      accessor: ({evt}) ~>
        d = evt.target and evt.target.__data__
        item = if d and d.item => d.item else if d and d.pts => d else null
        if !item => return null
        f = smart-format format, @cfg.tip.format, \.3~s
        u = (k) ~> (@binding[k] or {}).unit or ''
        v = (x, k) -> if x? => "#{f x}#{u k}" else '-'
        delta = '-'
        if item.delta? =>
          sign = if item.delta > 0 => '+' else ''
          rate = if item.start => " (#{sign}#{(item.delta / Math.abs(item.start) * 100).toFixed(1)}%)" else ''
          delta = "#{sign}#{f item.delta}#{u \end}#rate"
        return {
          title: item.name
          start-name: @label-of(\start), start-value: v(item.start, \start)
          end-name: @label-of(\end), end-value: v(item.end, \end)
          diff-name: t(\difference), diff-value: delta
        }
      range: ~> @layout.get-node \view .getBoundingClientRect!
    }

  destroy: ->
    if @tip => @tip.destroy!
    if @legend => @legend.destroy!

  parse: ->
    seen = new Map!
    has-name = !!@binding.name
    @rows = []
    @data.map (d, i) ~>
      [start, end] = [num(d.start), num(d.end)]
      name = if !has-name => "#{i + 1}" else if d.name? => "#{d.name}".trim! else ''
      # 試算表尾巴的空白列
      if !(start? or end?) and !name => return
      # join 的 key: 同名的列補序號, 換資料時才對得上
      n = (seen.get(name) or 0) + 1
      seen.set name, n
      delta = if start? and end? => end - start else null
      dir = if !(delta?) => null else if delta > 0 => \up else if delta < 0 => \down else \flat
      key = if n > 1 => "#name\u0000#n" else name
      @rows.push {key, name, start, end, delta, dir, idx: i, _raw: d._raw}

  resize: ->
    cfg = @cfg
    @horizontal = cfg.orientation != \vertical
    @root.querySelector('.pdl-layout').classList.toggle \legend-bottom, cfg.legend.position == \bottom
    @tip.toggle(if cfg.tip.enabled? => cfg.tip.enabled else true)
    @tint.set(cfg.palette or {colors: default-colors})

    # 起點一定要先取色, 才會是 palette 的第一個顏色
    colors = <[start end]>.map ~> @tint.get it
    pick = (c, fallback) -> if is-auto(c) => fallback else c
    @colors =
      start: pick cfg.dot.start-color, colors.0
      end: pick cfg.dot.end-color, colors.1
      up: cfg.line.increase-color
      down: cfg.line.decrease-color

    list = <[start end]>.filter(~> @binding[it]).map (k) ~> {key: k, text: @label-of(k), value: 0}
    delta-mode = cfg.line.mode == \delta
    if delta-mode =>
      dirs = @rows.map (.dir)
      if \up in dirs => list.push {key: \up, text: t(\increase), value: 0}
      if \down in dirs => list.push {key: \down, text: t(\decrease), value: 0}
    @legend.config cfg.legend
    @legend.data list
    @layout.update false

    # 排序: 缺值的一律排最後, 不受升降冪影響
    key = switch cfg.sort.field
    | \start => (.start)
    | \end => (.end)
    | \diff => (.delta)
    | \abs => ((r) -> if r.delta? => Math.abs(r.delta) else null)
    | \name => (.name)
    | otherwise => null
    rows = @rows.slice!
    if key =>
      dir = if cfg.sort.dir == \asc => 1 else -1
      val = (r) ->
        v = key r
        if typeof(v) == \string and v != '' and !isNaN(+v) => +v else v
      rows.sort (a, b) ->
        [va, vb] = [val(a), val(b)]
        if !(va?) or !(vb?) => return ((if va? => 0 else 1) - (if vb? => 0 else 1)) or (a.idx - b.idx)
        (dir * (if va > vb => 1 else if va < vb => -1 else 0)) or (a.idx - b.idx)

    vis = (k) ~> @legend.is-visible k
    sel = (k) ~> @legend.is-selected k
    @items = rows.map (r, pos) ->
      trend = delta-mode and r.dir in <[up down]>
      item = {} <<< r <<< {pos, dim: (trend and !sel(r.dir))}
      keys = if trend and !vis(r.dir) => [] else <[start end]>
      item.pts = keys.filter((k) -> r[k]? and vis(k)).map (k) -> {k, v: r[k], item, dim: !sel(k), _raw: r._raw}
      item

    setup-axes @
    build-labels @
    # 軸的寬高會影響繪圖區, 繪圖區又影響軸, 多跑幾次直到穩定
    for i from 0 til 3
      @layout.update false
      fit @
      @xaxis.render!
      @yaxis.render!
    @layout.update false
    fit @

  render: ->
    {cfg, items, scale, g, colors, mark, dense, box-view: box, horizontal: hz, legend} = @
    {r, sw, R, lw, bw} = mark
    ani = cfg.animation
    dur = if on-off(ani.enabled, true) => (ani.duration ? 350) else 0
    stagger = ani.stagger or 0
    tween = (n, attrs, opt = {}) ~> @anim.tween n, attrs, ({duration: dur} <<< opt)
    fade-out = (n) -> tween n, {opacity: 0}, {remove: true}

    at = (item, v) ->
      c = scale.c(item.pos) + bw / 2
      if hz => {x: scale.v(v), y: c} else {x: c, y: scale.v(v)}
    # 連接線兩端的座標. 實心的端點蓋得住線頭, 空心的要停在圈外
    trim = if cfg.dot.style == \hollow => R else r * 0.5
    seg = (item) ->
      [a, b] = [at(item, item.pts.0.v), at(item, item.pts.1.v)]
      d = Math.abs(a.x - b.x) + Math.abs(a.y - b.y)
      if d <= trim * 2 =>
        [mx, my] = [(a.x + b.x) / 2, (a.y + b.y) / 2]
        return {x1: mx, y1: my, x2: mx, y2: my}
      [ux, uy] = [(b.x - a.x) / d, (b.y - a.y) / d]
      {x1: a.x + ux * trim, y1: a.y + uy * trim, x2: b.x - ux * trim, y2: b.y - uy * trim}
    middle = (item) ->
      [a, b] = [at(item, item.pts.0.v), at(item, item.pts[* - 1].v)]
      {x: (a.x + b.x) / 2, y: (a.y + b.y) / 2}
    # 新來的從中間長出來 ( 只有一端的就地長出 )
    origin = (pt) -> if pt.item.pts.length == 2 => middle(pt.item) else at(pt.item, pt.v)

    color = (k) -> colors[k]
    gid = (item) ~> "#{@uid}-#{@gid.map[item.key] ?= @gid.n++}"
    line-color = (item) ->
      switch cfg.line.mode
      | \delta => (if item.dir in <[up down]> => colors[item.dir] else cfg.line.color)
      | \gradient => "url(\##{gid item})"
      | otherwise => cfg.line.color

    # ---- 格線
    grid = []
    gc = cfg.grid
    [L, C] = if hz => [box.width, box.height] else [box.height, box.width]
    if on-off(gc.value, true) => @vticks.map (v) -> grid.push {key: "v#v", v, zero: v == 0}
    if on-off(gc.category, false) => items.map (item) -> grid.push {key: "c#{item.pos}", item}
    gj = join root: g.grid, tag: \line, data: grid, key: (.key)
    gj.exit.map -> it.parentNode.removeChild it
    gj.nodes.map (n) ->
      d = n.__data__
      if d.item =>
        c = scale.c(d.item.pos) + bw / 2
        a = if hz => {x1: 0, x2: L, y1: c, y2: c} else {x1: c, x2: c, y1: 0, y2: C}
      else
        p = scale.v d.v
        a = if hz => {x1: p, x2: p, y1: 0, y2: C} else {x1: 0, x2: C, y1: p, y2: p}
      for k, v of a => n.setAttribute k, v
      n.setAttribute \stroke, gc.color or \currentColor
      # 橫跨 0 的時候, 0 那條要比其它格線明顯
      n.setAttribute \stroke-opacity, (gc.opacity ? 0.12) * (if d.zero and scale.v.domain!0 < 0 => 3 else 1)
      n.setAttribute \stroke-width, 1
      if gc.dash => n.setAttribute \stroke-dasharray, "#{gc.dash} #{gc.dash}"
      else n.removeAttribute \stroke-dasharray

    # ---- 漸層 ( line.mode = gradient )
    grads = if cfg.line.mode == \gradient => items.filter(-> it.pts.length == 2) else []
    dj = join root: g.defs, tag: \linearGradient, data: grads, key: (.key)
    dj.exit.map -> it.parentNode.removeChild it
    dj.nodes.map (n) ->
      item = n.__data__
      n.setAttribute \id, gid(item)
      n.setAttribute \gradientUnits, \userSpaceOnUse
      if !n.childNodes.length => [0 1].map (i) ->
        s = n.appendChild document.createElementNS(svgns, \stop)
        s.setAttribute \offset, "#{i * 100}%"
      [item.pts.0, item.pts.1].map (p, i) -> tween n.childNodes[i], {"stop-color": color(p.k)}
      tween n, seg(item)

    # ---- 每一列
    rj = join root: g.rows, tag: \g, cls: \row, data: items, key: (.key)
    rj.exit.map fade-out
    rj.enter.map (n) -> n.setAttribute \opacity, 0
    hollow = cfg.dot.style == \hollow
    stripe-on = on-off cfg.row.stripe, false
    rj.nodes.map (n, i) ->
      item = n.__data__
      opt = {delay: i * stagger}
      tween n, {opacity: (if item.dim => legend.opacity! else 1)}, opt

      c0 = scale.c item.pos
      step = mark.step
      # 斑馬紋 / hover 底色. 粗細跟著列間距走
      band = if hz => {x: 0, y: c0, width: L, height: bw} else {x: c0, y: 0, width: bw, height: L}
      sj = join root: n, tag: \rect, cls: \stripe, data: [item]
      sj.enter.map (m) ->
        for k, v of band => m.setAttribute k, v
        m.setAttribute \fill, \currentColor
        m.setAttribute \pointer-events, \none
      sj.nodes.map (m) ->
        m.setAttribute \fill-opacity, if stripe-on and (item.pos % 2) => 0.05 else 0
        tween m, band, opt
      # 感應區佔滿整列, 不必剛好指到端點
      hit-box = if hz => {x: 0, y: c0 - (step - bw) / 2, width: L, height: step}
      else {x: c0 - (step - bw) / 2, y: 0, width: step, height: L}
      hj = join root: n, tag: \rect, cls: \hit, data: [item]
      hj.nodes.map (m) ->
        for k, v of hit-box => m.setAttribute k, v
        m.setAttribute \fill, \transparent
        m.setAttribute \pointer-events, \all

      lj = join root: n, tag: \line, cls: \conn, data: (if item.pts.length == 2 => [item] else [])
      lj.exit.map (m) -> m.parentNode.removeChild m
      lj.enter.map (m) ->
        p = middle item
        m.setAttribute \x1, p.x
        m.setAttribute \x2, p.x
        m.setAttribute \y1, p.y
        m.setAttribute \y2, p.y
      lj.nodes.map (m) ->
        s = line-color item
        attrs = {} <<< seg(item) <<<
          "stroke-width": lw
          "stroke-opacity": cfg.line.opacity ? 0.7
        # 漸層不能補間, 直接換
        if cfg.line.mode == \gradient => m.setAttribute \stroke, s
        else attrs.stroke = s
        tween m, attrs, opt

      cj = join root: n, tag: \circle, cls: \dot, data: item.pts, key: (.k)
      cj.exit.map (m) -> tween m, {r: 0}, {remove: true}
      cj.enter.map (m) ->
        d = m.__data__
        p = origin d
        m.setAttribute \cx, p.x
        m.setAttribute \cy, p.y
        m.setAttribute \r, 0
        m.setAttribute \fill, if hollow => \none else color(d.k)
        m.setAttribute \stroke, color(d.k)
      cj.nodes.map (m) ->
        d = m.__data__
        p = at item, d.v
        col = color d.k
        stroke = if hollow or is-auto(cfg.dot.stroke) => col else cfg.dot.stroke
        if hollow => m.setAttribute \pointer-events, \all else m.removeAttribute \pointer-events
        op = if d.dim => legend.opacity! else 1
        tween m, {
          cx: p.x, cy: p.y, r: r
          fill: (if hollow => \none else col)
          stroke, "stroke-width": sw
          "fill-opacity": op, "stroke-opacity": op
        }, opt

    # ---- 標籤避讓: 端點與連接線是障礙物, 數值標籤先放, 差值標籤放剩下的空位
    obstacles = []
    placed = []
    items.map (item) ->
      item.pts.map (p) ->
        a = at item, p.v
        obstacles.push {x0: a.x - R, x1: a.x + R, y0: a.y - R, y1: a.y + R}
      if item.pts.length == 2 =>
        [a, b] = [at(item, item.pts.0.v), at(item, item.pts.1.v)]
        obstacles.push do
          x0: Math.min(a.x, b.x) - lw / 2, x1: Math.max(a.x, b.x) + lw / 2
          y0: Math.min(a.y, b.y) - lw / 2, y1: Math.max(a.y, b.y) + lw / 2
    hit = (b, list) ->
      for o in list
        if b.x0 < o.x1 - 0.5 and b.x1 > o.x0 + 0.5 and b.y0 < o.y1 - 0.5 and b.y1 > o.y0 + 0.5 => return true
      false
    # 繪圖區外還有 0.5em 的留白, 差一點點超出去沒關係
    [W, H] = [box.width, box.height]
    place = (cands, w, h) ->
      for c in cands
        b = {x0: c.x - w / 2, x1: c.x + w / 2, y0: c.y - h / 2, y1: c.y + h / 2}
        if b.x0 < -4 or b.x1 > W + 4 or b.y0 < -2 or b.y1 > H + 2 => continue
        if hit(b, obstacles) or hit(b, placed) => continue
        placed.push b
        return c
      null
    # 新進場的直接放在終點, 只淡入 ( 沒設 x / y 的話會從左上角滑進來 )
    init-text = (n) ->
      e = n.__data__
      n.setAttribute \x, e.pos.x
      n.setAttribute \y, e.pos.y
      n.setAttribute \opacity, 0
      n.setAttribute \text-anchor, \middle
      n.setAttribute \dy, \.35em
      n.setAttribute \pointer-events, \none
    move-text = (n) ->
      e = n.__data__
      tween n, {x: e.pos.x, y: e.pos.y, opacity: (if e.shown => 1 else 0)}

    label-color = cfg.label.color or \currentColor
    labels = []
    items.map (item) ->
      item.labels.map (e) ->
        p = at item, e.v
        d = R + GAP
        cands = if e.side =>
          if hz => [{x: p.x + e.side * (d + e.w / 2), y: p.y}]
          else [{x: p.x, y: p.y - e.side * (d + e.h / 2)}]
        else if hz => [{x: p.x, y: p.y - d - e.h / 2}, {x: p.x, y: p.y + d + e.h / 2}]
        else [{x: p.x + d + e.w / 2, y: p.y}, {x: p.x - d - e.w / 2, y: p.y}]
        c = if dense => null else place cands, e.w, e.h
        labels.push (e <<< {pos: (c or cands.0), shown: !!c})
    tj = join root: g.label, tag: \text, data: labels, key: (.id)
    tj.exit.map fade-out
    tj.enter.map init-text
    tj.nodes.map (n) ->
      e = n.__data__
      n.textContent = e.text
      n.setAttribute \fill, if is-auto(label-color) => color(e.pt.k) else label-color
      move-text n

    # 差值標籤
    delta-color = cfg.delta.color or \auto
    deltas = []
    items.map (item) ->
      if !(e = item.delta-label) => return
      c0 = scale.c(item.pos) + bw / 2
      cands = if cfg.delta.position == \column =>
        if hz => [{x: L - e.w / 2, y: c0}] else [{x: c0, y: e.h / 2}]
      else
        m = middle item
        h2 = e.h / 2
        w2 = e.w / 2
        if hz => [{x: m.x, y: m.y - lw / 2 - GAP / 2 - h2}, {x: m.x, y: m.y - R - GAP / 2 - h2}, {x: m.x, y: m.y + R + GAP / 2 + h2}]
        else [{x: m.x + lw / 2 + GAP + w2, y: m.y}, {x: m.x - lw / 2 - GAP - w2, y: m.y}]
      c = if dense => null else place cands, e.w, e.h
      deltas.push (e <<< {pos: (c or cands.0), shown: !!c})
    ej = join root: g.delta, tag: \text, data: deltas, key: (.id)
    ej.exit.map fade-out
    ej.enter.map init-text
    ej.nodes.map (n) ->
      e = n.__data__
      n.textContent = e.text
      n.setAttribute \fill, if is-auto(delta-color) => colors[e.item.dir] else delta-color
      move-text n

    legend.render!
    @yaxis.render!
    @xaxis.render!
