# dumbbell 的 test case ( @makechart/viewer 的 mctest )
# 每份資料用自己的種子, 跟產生的先後順序無關
mk = (n, pairs = 2, seed = n) ->
  rnd = mctest.random seed
  raw: [0 til n].map (i) ->
    ret = {name: "N#i"}
    for j from 0 til pairs => ret <<< {"a#j": Math.round(rnd! * 100) / 100, "b#j": Math.round(rnd! * 100) / 100}
    ret
  binding:
    name: {key: \name}
    y1: [{key: "a#j"} for j from 0 til pairs]
    y2: [{key: "b#j"} for j from 0 til pairs]

mctest.suite do
  size: [480, 320]
  data:
    two: mk 10, 2
    one: mk 6, 1
    three: mk 8, 3, 5
  cases:
    * name: "two", data: \two
    * name: "one", data: \one
    * name: "three", data: \three
    * name: "palette", data: \two, config: {palette: {colors: <[#f00 #0a0 #00f]>}}
    * name: "update", data: \two, steps: (c) -> d = mk 5, 3, 9; c.set-raw d.raw, d.binding
