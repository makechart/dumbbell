# dumbbell 的 test case ( @makechart/viewer 的 mctest )
# 資料都由固定種子產生, 跟產生的先後順序無關
binding = {name: {key: \name}, start: {key: \y2020, name: "2020"}, end: {key: \y2024, name: "2024"}}

mk = (n, seed = n, opt = {}) ->
  rnd = mctest.random seed
  raw: [0 til n].map (i) ->
    a = Math.round(20 + rnd! * 60)
    {name: (opt.prefix or "Item ") + (i + 1), y2020: a, y2024: Math.round(a + (rnd! - 0.4) * 30)}
  binding: binding

rows = (list, b = binding) ->
  raw: list.map -> {name: it.0, y2020: it.1, y2024: it.2}
  binding: b

data =
  base: mk 9
  many: mk 60, 3
  small: mk 6, 4
  longname: rows [
    ["National Taiwan University of Science and Technology", 62, 71]
    ["International Institute for Applied Systems Analysis", 48, 44]
    ["短", 30, 55]
    ["Massachusetts Institute of Technology", 81, 88]
    ["國立臺灣大學醫學院附設醫院新竹臺大分院生醫醫院竹東分院", 57, 63]
    ["University of California, Los Angeles", 40, 52]
  ]
  # 缺一端 / 兩端都缺 / 全空白列
  missing: rows [
    ["Both", 20, 60], ["No start", '', 45], ["No end", 70, '']
    ["Nothing", '', ''], ["Bad", 'n/a', 30], ['', '', ''], ["Zero", 0, 15]
  ]
  equal: rows [["A", 40, 40], ["B", 20, 50], ["C", 65, 65.4], ["D", 55, 30]]
  negative: rows [["A", -40, 20], ["B", -10, -35], ["C", 5, 30], ["D", 0, -15], ["E", 12, 12]]
  # 全部同一個值: domain 不能是零寬
  flat: rows [["A", 50, 50], ["B", 50, 50]]
  # 同名的列不能疊在一起; 數字型的名字不能被當數值格式化
  dup: rows [["A", 10, 20], ["A", 30, 45], [2024, 22, 18], [1000, 5, 8]]
  single: rows [["Only", 12, 34]]
  empty: {raw: [], binding: binding}
  # 只綁一端
  oneside: {raw: (mk 5, 8).raw, binding: {name: binding.name, end: binding.end}}
  # 有單位
  unit: {
    raw: (mk 6, 6).raw
    binding: {name: binding.name, start: ({} <<< binding.start <<< {unit: \%}), end: ({} <<< binding.end <<< {unit: \%})}
  }
  ratio: rows [["A", 0.12, 0.34], ["B", 0.5, 0.42], ["C", 0.08, 0.87]]
  medium: mk 20, 12
  big: rows [["A", 1200000, 3400000], ["B", 900000, 1500000], ["C", 4100000, 2800000]]

vertical = {orientation: \vertical}
both = (name, d, cfg = {}, extra = {}) -> [
  {name: "h:#name", data: d, config: cfg} <<< extra
  {name: "v:#name", data: d, config: ({} <<< cfg <<< vertical)} <<< extra
]

cases = []
cases ++= both \base, \base
# 內建的 sample ( mod.sample )
use-sample = (c) -> d = c.mod.sample!; c.set-raw d.raw, d.binding
cases ++= [{name: "h:sample", data: \small, steps: use-sample}, {name: "v:sample", data: \small, config: vertical, steps: use-sample}]
cases ++= both \many, \many
cases ++= both \longname, \longname
cases ++= both \missing, \missing
cases ++= both \equal, \equal
cases ++= both \negative, \negative
cases ++= both \negative-zero, \negative, {value-axis: {include-zero: true}}
cases ++= both \flat, \flat
cases ++= both \dup, \dup
cases ++= both \single, \single
cases ++= both \empty, \empty
cases ++= both \oneside, \oneside
cases ++= both \unit, \unit
cases ++= both \big, \big
cases ++= both \small, \small, {}, {size: [300, 300]}
cases ++= both \small-many, \many, {}, {size: [300, 300]}
cases ++= both \small-labels, \small, {delta: {show: true}}, {size: [300, 300]}
cases ++= both \ratio, \ratio, {delta: {show: true}}
cases ++= both \medium, \medium
cases ++= both \zero, \base, {value-axis: {include-zero: true}}
cases ++= both \delta-middle, \base, {delta: {show: true}}
cases ++= both \delta-column, \base, {delta: {show: true, position: \column}}
cases ++= both \label-side, \base, {label: {position: \side}}
cases ++= both \line-delta, \base, {line: {mode: \delta}}
cases ++= both \line-gradient, \base, {line: {mode: \gradient, width: 4, opacity: 1}}
cases ++= both \hollow, \base, {dot: {style: \hollow, size: 7}}

for key in <[start end diff abs name]> =>
  cases.push {name: "sort:#key", data: \base, config: {sort: {field: key, dir: \desc}}}
cases ++= [
  * name: "sort:asc", data: \base, config: {sort: {field: \diff, dir: \asc}}
  * name: "sort:missing-last", data: \missing, config: {sort: {field: \end, dir: \asc}}
  * name: "dot:big-stroke", data: \base, config: {dot: {size: 9, stroke: \#ffffff, stroke-width: 2}}
  * name: "dot:colors", data: \base, config: {dot: {start-color: \#cc3355, end-color: \#118866}}
  * name: "palette", data: \base, config: {palette: {colors: <[#f00 #0a0 #00f]>}}
  * name: "label:off", data: \base, config: {label: {show: false}}
  * name: "label:format", data: \base, config: {label: {format: \.1f}, delta: {show: true, format: \+.1f}}
  * name: "label:color-auto", data: \base, config: {label: {color: \auto}}
  * name: "row:padding", data: \base, config: {row: {padding: 0.7}}
  * name: "row:stripe", data: \base, config: {row: {stripe: true}}
  * name: "grid:off", data: \base, config: {grid: {value: false}}
  * name: "grid:category", data: \base, config: {grid: {category: true, dash: 2, opacity: 0.25}}
  * name: "axis:off", data: \base, config: {value-axis: {enabled: false}, category-axis: {enabled: false}}
  * name: "axis:caption", data: \unit, config: {category-axis: {caption: {show: true}}}
  * name: "axis:vertical-label", data: \longname, config: {orientation: \vertical, category-axis: {label: {direction: \vertical}}}
  * name: "legend:right", data: \base, config: {legend: {position: \right}}
  * name: "legend:off", data: \base, config: {legend: {enabled: false}}
  * name: "legend:selectable", data: \base, config: {legend: {selectable: true}}
    steps: (c) ->
      c.legend.select <[end]>
      c.resize!; c.render!
  * name: "legend:dim", data: \base, config: {legend: {subset: {mode: \dim}}}
    steps: (c) ->
      c.legend.select <[end]>
      c.resize!; c.render!

  * name: "tip", data: \base
    steps: (c, ctx) ->
      n = ctx.root.querySelector 'rect.hit'
      b = n.getBoundingClientRect!
      n.dispatchEvent new MouseEvent \mousemove, {bubbles: true, clientX: b.x + b.width / 2, clientY: b.y + b.height / 2}
      txt = c.tip.tip.textContent
      if !(/2020/.exec(txt) and /2024/.exec(txt) and /−9/.exec(txt)) => throw new Error("tip content: #txt")
      c.tip.tip.style.opacity = 0

  # 換資料: 項目增加 / 減少 / 重排
  * name: "update:grow", data: \small, steps: (c) -> d = mk 12, 21; c.set-raw d.raw, d.binding
  * name: "update:shrink", data: \base, steps: (c) -> d = mk 3, 22; c.set-raw d.raw, d.binding
  * name: "update:empty", data: \base, steps: (c) -> c.set-raw [], binding
  * name: "update:orientation", data: \base
    steps: (c) ->
      c.config vertical
      c.parse!; c.bind!; c.resize!; c.render!
  * name: "update:sort", data: \base
    steps: (c) ->
      c.config {sort: {field: \end, dir: \desc}}
      c.parse!; c.bind!; c.resize!; c.render!
  # 動畫逐格 ( 用真的時鐘, 不是 flush 到終點 )
  * name: "anim:frames", data: \small
    steps:
      * (c, ctx) ->
          d = mk 9, 31
          c.set-raw d.raw, d.binding
          for i from 1 to 5
            c.anim.step 70
            ctx.capture "t#{i * 70}"
  * name: "anim:off", data: \small, config: {animation: {enabled: false}}
    steps: [(c) -> d = mk 9, 31; c.set-raw d.raw, d.binding]
]

mctest.suite {
  data, cases, size: [560, 360]
  # 漸層 id 每次都不同
  normalize: [[/dumbbell-[a-z0-9]+/g, 'dumbbell-ID']]
}
