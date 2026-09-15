# Reproducible Builds in a Regulated Domain: A Case Study of an Emissions-Monitoring System

Leo Sakharov <leos@itu.dk> — Peter Juul Møller <pemoe@itu.dk>
Course code: KISPECI1SE (30 ECTS) — Group: V26KISPECI1SE743

Trusting a released binary means trusting not only its source code, but also
the process that produced it, as build- and supply-chain attacks such as
SolarWinds have shown. For software that reports a power plant's emissions to
the authorities, that trust today rests on a version string the vendor
declares. Nothing ties that string to the binary.

WS.PEMS, made by the Danish engineering company Weel-Sandvig, is such a system.
It predicts a plant's emissions from process data such as load, temperature and
fuel flow, replacing the physical analysers the standards were written for, and
it runs in several versions at customers' plants and on servers Weel-Sandvig
hosts itself. What runs is a binary, and a binary can be changed anywhere
between source and site: on the build server, in a dependency, or in transit.
Code signing proves who built it, not what it was built from. Neither
Weel-Sandvig nor the authorities can show that what runs at a site was built
from the source it claims to come from.

Reproducible builds could replace the version string with a check anyone can
repeat: rebuild from source and compare bit-for-bit. Published studies measure
reproducibility one package ecosystem at a time, and the systems that have been
made reproducible end to end, such as Tor Browser and Bitcoin Core, are
open-source projects with communities behind them. We know of no study of a
vendor's closed-source system, built in one step from several ecosystems, in a
regulated setting. WS.PEMS is such a system.

This thesis makes that attempt. We adjust the WS.PEMS build to make its release
reproducible and follow the release into its dependencies, mapping what can be
reproduced bit-for-bit, what can only be pinned by hash, and what lies outside
vendor control. Where the literature has measured an ecosystem, we build on it;
where it has not, we measure with Benedetti et al.'s methodology,[^1] using
WS.PEMS's own dependency tree as the sample. We expect the .NET part to need
this most, since no study has measured NuGet, but that is a result to
establish, not an assumption. The outcome is a map of how much of a real
system's release can be independently verified against its source, what stands
in the way, and what that asks of standards, vendors, plant operators and
package maintainers.

The thesis runs two linked experiments: making the WS.PEMS build reproducible,
and testing its dependencies for reproducibility. It delivers a thesis
document, a public repository to reproduce the experiments, and recommendations
for vendors of software in regulated domains, for the plant operators who run
it, for those who write and enforce the standards, and for the maintainers of
the toolchains and packages it is built from.

[^1]: TODO: citation for Benedetti et al.
