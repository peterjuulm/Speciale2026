// next.config.js for the entry-order experiment (W47), 12 October 2026.
// entry-lab.sh renames the commit's own config to next.config.orig.js and
// puts this file in its place. It keeps every setting of the original, runs
// the original's webpack hook first, and adds EntryOrderPlugin to every
// compiler. The original already has a webpack hook, so Next's build worker
// stays off, as in the real build.
const base = require('./next.config.orig.js');
const EntryOrderPlugin = require('./entry-order-plugin.js');

module.exports = {
  ...base,
  webpack: (config, ctx) => {
    if (base.webpack) config = base.webpack(config, ctx);
    config.plugins.push(new EntryOrderPlugin(ctx.isServer ? ctx.nextRuntime || 'server' : 'client'));
    return config;
  },
};
