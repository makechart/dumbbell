module.exports =
  pkg:
    name: 'dumbbell', version: '0.0.1'
    extend: {name: "base", version: "0.0.1"}
    dependencies: []
  init: ({root, context, pubsub}) ->
    pubsub.fire \init, mod: mod {context}

mod = ({context}) ->
  {chart,d3,ldcolor,debounce} = context
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
        d3.min(@data.map (d,i) -> d3.min([d3.min(d.y1), d3.min(d.y2)])),
        d3.max(@data.map (d,i) -> d3.max([d3.max(d.y1), d3.max(d.y2)]))
      ]
    @scale =
      x: d3.scaleBand!domain(@names).range [0,w] .paddingInner 0.3
      y: d3.scaleLinear!domain([0,@extent.y.1]).range [0,h]
      c: d3.scaleOrdinal(d3.schemeCategory10)
    if @cfg.palette => @scale.c = d3.scaleOrdinal(@cfg.palette.colors.map -> ldcolor.web(it.value or it))
    if @cfg.palette => @tint.set(@cfg.palette.colors.map -> ldcolor.web(it.value or it))

  render: ->
    {scale,tint} = @
    svg = d3.select @svg
    svg.selectAll \g.data .data @parsed
      ..exit!remove!
      ..enter!append \g .attr \class, \data
    svg.selectAll \g.data
      .each (e,j) ->
        bw = scale.x.bandwidth!
        n = d3.select(@)
        n.selectAll \g.dumbbell .data e.dumbbell
          ..exit!remove!
          ..enter!append \g .attr \class, \dumbbell
        n.selectAll \g.dumbbell
          .each (f,k) ->
            m = d3.select(@)
            m.selectAll \circle .data [1,2]
              ..exit!remove!
              ..enter!append \circle
            m.selectAll \line .data [0]
              ..exit!remove!
              ..enter!append \line
            m.selectAll \circle
              .attr \cx, (d,i) -> scale.x(e.name) + bw * i
              .attr \cy, (d,i) -> scale.y f["y#d"]
              .attr \r, 2
              .attr \fill, -> tint.get(f.name.0)
            m.selectAll \line
              .attr \x1, (d,i) -> scale.x(e.name)
              .attr \x2, (d,i) -> scale.x(e.name) + bw
              .attr \y1, (d,i) -> scale.y f.y1
              .attr \y2, (d,i) -> scale.y f.y2
              .attr \stroke, -> tint.get(f.name.0)
              .attr \stroke-width, 1
