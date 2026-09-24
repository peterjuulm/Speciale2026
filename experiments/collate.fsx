// Compare the two names Roslyn 4.12 sorts first, under several cultures.
// Run: dotnet fsi --quiet --exec collate.fsx
// Written 24 September 2026 for phoenix-layer2-reprotest.
open System.Globalization
let a, b = "<>y__InlineArray4`1", "<>z__ReadOnlySingleElementList`1"
for c in [""; "da-DK"; "en-US"; "et-EE"; "lt-LT"; "sv-SE"; "fi-FI"; "lv-LV"; "hu-HU"; "cs-CZ"; "tr-TR"] do
    let ci = if c = "" then CultureInfo.InvariantCulture else CultureInfo(c)
    let r = ci.CompareInfo.Compare(a, b)
    printfn "%-10s %s" (if c = "" then "invariant" else c) (if r < 0 then "<>y__ first" else "<>z__ first")
printfn "ordinal    %s" (if System.String.CompareOrdinal(a, b) < 0 then "<>y__ first" else "<>z__ first")
