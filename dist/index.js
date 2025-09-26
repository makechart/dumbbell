(function(){
  var mod;
  module.exports = {
    pkg: {
      name: 'dumbbell',
      version: '0.0.1',
      extend: {
        name: "base",
        version: "0.0.1"
      },
      dependencies: []
    },
    init: function(arg$){
      var root, context, pubsub;
      root = arg$.root, context = arg$.context, pubsub = arg$.pubsub;
      return pubsub.fire('init', {
        mod: mod({
          context: context
        })
      });
    }
  };
  mod = function(arg$){
    var context, chart, d3, ldcolor, debounce;
    context = arg$.context;
    chart = context.chart, d3 = context.d3, ldcolor = context.ldcolor, debounce = context.debounce;
    return {
      sample: function(){
        return {
          raw: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10].map(function(val){
            return {
              val1: Math.random() * 0.5 + 0.4,
              val2: Math.random() * 0.5 + 0.4,
              val3: Math.random() * 0.6 + 0.1,
              val4: Math.random() * 0.6 + 0.1,
              name: val
            };
          }),
          binding: {
            name: {
              key: 'name'
            },
            y1: [
              {
                key: 'val1'
              }, {
                key: 'val2'
              }
            ],
            y2: [
              {
                key: 'val3'
              }, {
                key: 'val4'
              }
            ]
          }
        };
      },
      config: {},
      dimension: {
        y1: {
          type: 'R',
          multiple: true,
          name: "y pos"
        },
        y2: {
          type: 'R',
          multiple: true,
          name: "y pos"
        },
        name: {
          type: 'N',
          name: "dumbbell name"
        }
      },
      init: function(){
        var tint;
        return this.tint = tint = new chart.utils.tint();
      },
      parse: function(){
        var this$ = this;
        this.parsed = [];
        this.parsed = this.data.map(function(d, i){
          var dumbbell;
          dumbbell = d.y1.map(function(e, j){
            return {
              y1: d.y1[j] || 0,
              y2: d.y2[j] || 0,
              name: [this$.binding.y1[j].key, this$.binding.y2[j].key]
            };
          });
          return {
            name: d.name,
            dumbbell: dumbbell
          };
        });
        return this.names = this.data.map(function(it){
          return it.name;
        });
      },
      resize: function(){
        var ref$, w, h;
        ref$ = [this.box.width, this.box.height], w = ref$[0], h = ref$[1];
        this.extent = {
          y: [
            d3.min(this.data.map(function(d, i){
              return d3.min([d3.min(d.y1), d3.min(d.y2)]);
            })), d3.max(this.data.map(function(d, i){
              return d3.max([d3.max(d.y1), d3.max(d.y2)]);
            }))
          ]
        };
        this.scale = {
          x: d3.scaleBand().domain(this.names).range([0, w]).paddingInner(0.3),
          y: d3.scaleLinear().domain([0, this.extent.y[1]]).range([0, h]),
          c: d3.scaleOrdinal(d3.schemeCategory10)
        };
        if (this.cfg.palette) {
          this.scale.c = d3.scaleOrdinal(this.cfg.palette.colors.map(function(it){
            return ldcolor.web(it.value || it);
          }));
        }
        if (this.cfg.palette) {
          return this.tint.set(this.cfg.palette.colors.map(function(it){
            return ldcolor.web(it.value || it);
          }));
        }
      },
      render: function(){
        var scale, tint, svg, x$;
        scale = this.scale, tint = this.tint;
        svg = d3.select(this.svg);
        x$ = svg.selectAll('g.data').data(this.parsed);
        x$.exit().remove();
        x$.enter().append('g').attr('class', 'data');
        return svg.selectAll('g.data').each(function(e, j){
          var bw, n, x$;
          bw = scale.x.bandwidth();
          n = d3.select(this);
          x$ = n.selectAll('g.dumbbell').data(e.dumbbell);
          x$.exit().remove();
          x$.enter().append('g').attr('class', 'dumbbell');
          return n.selectAll('g.dumbbell').each(function(f, k){
            var m, x$, y$;
            m = d3.select(this);
            x$ = m.selectAll('circle').data([1, 2]);
            x$.exit().remove();
            x$.enter().append('circle');
            y$ = m.selectAll('line').data([0]);
            y$.exit().remove();
            y$.enter().append('line');
            m.selectAll('circle').attr('cx', function(d, i){
              return scale.x(e.name) + bw * i;
            }).attr('cy', function(d, i){
              return scale.y(f["y" + d]);
            }).attr('r', 2).attr('fill', function(){
              return tint.get(f.name[0]);
            });
            return m.selectAll('line').attr('x1', function(d, i){
              return scale.x(e.name);
            }).attr('x2', function(d, i){
              return scale.x(e.name) + bw;
            }).attr('y1', function(d, i){
              return scale.y(f.y1);
            }).attr('y2', function(d, i){
              return scale.y(f.y2);
            }).attr('stroke', function(){
              return tint.get(f.name[0]);
            }).attr('stroke-width', 1);
          });
        });
      }
    };
  };
}).call(this);
