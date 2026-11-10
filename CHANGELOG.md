# Change Logs

## v0.0.3

 - rewrite as a real dumbbell chart: one category axis, one value axis, two points per row joined by a connector.
   The previous slope-style drawing is gone
 - BREAKING: dimensions changed. `y1` / `y2` ( multiple ) are replaced by `name` + `start` + `end` ( single values );
   existing bindings must be redone
 - add `orientation` config: `horizontal` ( default, categories on the left ) or `vertical` ( categories at the bottom )
 - add config: sort, dot, line ( single / delta / gradient ), value labels, difference labels, row spacing, grid,
   value / category axis ( axis preset + `includeZero`, `maxLabelWidth` ), legend, tooltip, animation
 - handle missing values, equal values, negative values, duplicated names, very long names and dense rows
 - add zh-TW i18n
 - rewrite test cases; old snapshots are replaced


## v0.0.2

 - extend the lite base ( `@makechart/base` `lite/index.html`, no d3 ): needs `@makechart/base` >= 0.2.0
   and `@plotdb/chart` >= 3.7.0
 - remove unused `scaleOrdinal` / `schemeCategory10`
 - add test cases ( `test/index.ls`, run with `npm test` via `@makechart/viewer` )


## v0.0.1

init release
