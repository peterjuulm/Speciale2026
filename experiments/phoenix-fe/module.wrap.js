// next.config.js for the module-order experiment (W51), 12 October 2026.
// module-lab.sh renames the commit's own config to next.config.orig.js and
// puts this file in its place. It keeps every setting of the original, runs
// the original's webpack hook first (which sorts the client's entries, W47),
// and adds ModuleOrderPlugin to every compiler.
const base = require('./next.config.orig.js');
const ModuleOrderPlugin = require('./module-order-plugin.js');

module.exports = {
  ...base,
  webpack: (config, ctx) => {
    if (base.webpack) config = base.webpack(config, ctx);
    config.plugins.push(new ModuleOrderPlugin(ctx.isServer ? ctx.nextRuntime || 'server' : 'client'));
    return config;
  },
};
