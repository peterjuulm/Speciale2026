// Fill in `resolved` and `integrity` for lock entries that lack them (W41).
//
//   node fill-lock.js <package-lock.json>
//
// npm 10.8.2 cannot do this itself: reify fetches name@version for an entry
// without `resolved` but never writes the URL or hash back
// (@npmcli/arborist reify.js #extractOrLink), and it only re-fetches metadata
// for lockfileVersion < 2 (build-ideal-tree.js #inflateAncientLockfile).
//
// For each entry without `resolved`, this asks `npm view <name>@<version>` -
// the npm first on PATH, so run it with ~/rb1-node/bin first - for exactly
// the version already in the lock. No range is resolved, so no version can
// change. It checks that the registry answers with that same version, and as
// a control it asks for 20 entries that already have both fields and checks
// they match. It writes the file in place only if every lookup and every
// control passes; otherwise it writes nothing. Run it from the project folder
// so the project's .npmrc applies.

const fs = require('fs')
const { execFile } = require('child_process')

const file = process.argv[2]
if (!file) {
  console.error('usage: node fill-lock.js <package-lock.json>')
  process.exit(1)
}
const raw = fs.readFileSync(file, 'utf8')
const lock = JSON.parse(raw)
// npm writes JSON.stringify(lock, null, 2) plus a newline. If this does not
// give back the same bytes, the diff would carry more than the two fields.
if (JSON.stringify(lock, null, 2) + '\n' !== raw) {
  console.error('the file does not round-trip byte for byte; stopping')
  process.exit(2)
}

const nameOf = (path, v) => v.name || path.slice(path.lastIndexOf('node_modules/') + 13)
const entries = Object.entries(lock.packages).filter(([k, v]) => k && !v.link)
const missing = entries.filter(([, v]) => !v.resolved || !v.integrity)
const control = entries.filter(([, v]) => v.resolved && v.integrity)
  .filter((_, i, all) => i % Math.floor(all.length / 20) === 0).slice(0, 20)

const view = spec => new Promise((ok, fail) =>
  execFile('npm', ['view', spec, 'version', 'dist.tarball', 'dist.integrity', '--json'],
    { maxBuffer: 1 << 20 }, (err, out) => {
      if (err) return fail(new Error(`${spec}: ${err.message.split('\n')[0]}`))
      ok(JSON.parse(out))
    }))

async function lookAll (list) {
  const out = new Map()
  let next = 0
  const worker = async () => {
    while (next < list.length) {
      const [path, v] = list[next++]
      out.set(path, await view(`${nameOf(path, v)}@${v.version}`))
    }
  }
  await Promise.all(Array.from({ length: 8 }, worker))
  return out
}

async function main () {
  console.log(`npm ${(await new Promise(ok => execFile('npm', ['--version'], (e, o) => ok(o.trim()))))}, node ${process.version}`)
  console.log(`${entries.length} entries, ${missing.length} to fill, ${control.length} controls`)

  const ctl = await lookAll(control)
  const ctlBad = control.filter(([p, v]) => ctl.get(p)['dist.tarball'] !== v.resolved ||
    ctl.get(p)['dist.integrity'] !== v.integrity)
  console.log(`controls matching the lock: ${control.length - ctlBad.length} of ${control.length}`)

  const got = await lookAll(missing)
  const bad = missing.filter(([p, v]) => {
    const m = got.get(p)
    return m.version !== v.version || !m['dist.tarball'] || !m['dist.integrity']
  })
  for (const [p, v] of [...ctlBad, ...bad]) console.log(`  problem: ${p} ${v.version}`)
  if (ctlBad.length || bad.length) {
    console.error('not written')
    process.exit(3)
  }

  // Same key order as npm: version, resolved, integrity, then the rest.
  for (const [path, v] of missing) {
    const m = got.get(path)
    const entry = {}
    for (const [k, val] of Object.entries(v)) {
      if (k === 'resolved' || k === 'integrity') continue
      entry[k] = val
      if (k === 'version') {
        entry.resolved = m['dist.tarball']
        entry.integrity = m['dist.integrity']
      }
    }
    lock.packages[path] = entry
  }
  fs.writeFileSync(file, JSON.stringify(lock, null, 2) + '\n')
  console.log(`filled ${missing.length}; written to ${file}`)
}

main().catch(e => {
  console.error(e.message)
  console.error('not written')
  process.exit(4)
})
