module.exports =
  pkg:
    name: 'dumbbell', version: '0.0.1'
    # lite: 不帶 d3 的 base ( 見 @plotdb/chart utils )
    extend: {name: "@makechart/base", path: "lite/index.html"}
    dependencies: []
  init: ({root, context, pubsub}) ->
    pubsub.fire \init, mod: mod {context}

mod = ({context}) ->
  {chart,ldcolor} = context
  {scale: Scale, anim: {join}} = chart.utils
  # 同 d3.min / d3.max: 略過 null 與 NaN, 沒有值時是 undefined
  vals = (list) -> (list or []).filter -> it? and +it >= +it
  min = (list) -> if (vs = vals list).length => vs.reduce (a, b) -> if b < a => b else a
  max = (list) -> if (vs = vals list).length => vs.reduce (a, b) -> if b > a => b else a
  sample: ->
    raw: [0 to 10].map (val) ~> 
      val1: Math.random! * 0.5 + 0.4
      val2: Math.random! * 0.5 + 0.4
      val3: Math.random! * 0.6 + 0.1
      val4: Math.random! * 0.6 + 0.1
      name: val
    binding:
      name: {key: \name}
      y1: [{key: \val1}, {key: \val2}]
      y2: [{key: \val3}, {key: \val4}]
  config: {}
  dimension:
    y1: {type: \R, multiple: true, name: "y pos"}
    y2: {type: \R, multiple: true, name: "y pos"}
    name: {type: \N, name: "dumbbell name"}
  init: ->
    @tint = tint = new chart.utils.tint!

  parse: ->
    @parsed = []
    @parsed = @data.map (d,i) ~>
      dumbbell = d.y1.map (e,j) ~>
        {y1: (d.y1[j] or 0), y2: (d.y2[j] or 0), name: [@binding.y1[j].key, @binding.y2[j].key]}
      {name: d.name, dumbbell}
    @names = @data.map -> it.name


  resize: ->
    [w,h] = [@box.width, @box.height]
    @extent =
      y: [
        min(@data.map (d,i) -> min([min(d.y1), min(d.y2)])),
        max(@data.map (d,i) -> max([max(d.y1), max(d.y2)]))
      ]
    @scale =
      x: Scale.band!domain(@names).range [0,w] .paddingInner 0.3
      y: Scale.linear!domain([0,@extent.y.1]).range [0,h]
    if @cfg.palette => @tint.set(@cfg.palette.colors.map -> ldcolor.web(it.value or it))

  render: ->
    {scale,tint} = @
    dj = join root: @svg, tag: \g, cls: \data, data: @parsed
    dj.exit.map -> it.remove!
    bw = scale.x.bandwidth!
    dj.nodes.map (n) ->
      e = n.__data__
      bj = join root: n, tag: \g, cls: \dumbbell, data: e.dumbbell
      bj.exit.map -> it.remove!
      bj.nodes.map (m) ->
        f = m.__data__
        cj = join root: m, tag: \circle, data: [1,2]
        cj.exit.map -> it.remove!
        lj = join root: m, tag: \line, data: [0]
        lj.exit.map -> it.remove!
        cj.nodes.map (c, i) ->
          d = c.__data__
          c.setAttribute \cx, scale.x(e.name) + bw * i
          c.setAttribute \cy, scale.y f["y#d"]
          c.setAttribute \r, 2
          c.setAttribute \fill, tint.get(f.name.0)
        lj.nodes.map (l) ->
          l.setAttribute \x1, scale.x(e.name)
          l.setAttribute \x2, scale.x(e.name) + bw
          l.setAttribute \y1, scale.y f.y1
          l.setAttribute \y2, scale.y f.y2
          l.setAttribute \stroke, tint.get(f.name.0)
          l.setAttribute \stroke-width, 1
