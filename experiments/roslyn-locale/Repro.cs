using System;
using System.Collections.Generic;

namespace LocaleRepro;

// Two C# 12 collection expressions that make the compiler generate two
// top-level helper types, <>y__InlineArray2<T> and
// <>z__ReadOnlySingleElementList<T>. Roslyn 4.12 emits them in the order of a
// culture-sensitive sort of their names, and Estonian sorts z before y.
public static class Repro
{
    public static int SumOfTwo(int a, int b)
    {
        ReadOnlySpan<int> span = [a, b];
        return span[0] + span[1];
    }

    public static IEnumerable<int> One(int a) => [a];
}
