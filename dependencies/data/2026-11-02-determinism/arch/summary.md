# Determinism experiment, summary (224 packages)

## 1. Population

| outcome | packages |
|---|---|
| built under the fixed SDK | 127 |
| did not build (first error logged) | 97 |

Did not build, by first error:

- 50: The shared framework must be built before the local targeting pack can
- 10: NETSDK1226
- 7: MSB4019
- 6: CS0234
- 4: CS7035
- 2: MSB4018
- 2: CS8625
- 2: NU1301
- 2: SDK version  is below the minimum required version of 10. The .NET Run
- 2: IDE0055
- 1: MSB3073
- 1: IDE0370
- 1: NETSDK1085
- 1: CS9336
- 1: NETSDK1147
- 1: API compatibility errors between 'lib/net20/Newtonsoft.Json.dll' (left
- 1: git -C /private/tmp/nupkg-determinism/src/sixlabors.imagesharp-1.0.4 -
- 1: CS0246
- 1: NETSDK1100
- 1: CS1929

Did not build, per package:

- AutoMapper 13.0.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/automapper-13.0.1/src/AutoMapper/AutoMapper.csproj(49,5): error MSB3073: The command ""/private/tmp/nupkg
- Dapper 2.0.123: pack failed (exit 1); /private/tmp/nupkg-determinism/nuget/nerdbank.gitversioning/3.3.37/build/Nerdbank.GitVersioning.Inner.targets(17,5): error MSB4018: The "Ner
- DocumentFormat.OpenXml 3.1.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/documentformat.openxml-3.1.1/src/DocumentFormat.OpenXml.Framework/XmlPath.cs(112,30): error CS8625: Canno
- DocumentFormat.OpenXml.Framework 3.1.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/documentformat.openxml.framework-3.1.1/src/DocumentFormat.OpenXml.Framework/XmlPath.cs(112,30): error CS8
- Microsoft.AspNetCore.Authentication.JwtBearer 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.AspNetCore.Authentication.JwtBearer 9.0.0: restore failed; /private/tmp/nupkg-determinism/src/microsoft.aspnetcore.authentication.jwtbearer-9.0.0/src/DataProtection/Abstractions/src/Microsoft.AspNetC
- Microsoft.AspNetCore.Authentication.OpenIdConnect 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.aspnetcore.authentication.openidconnect-9.0.0/Directory.Build.props(261,3): error MSB4019: The 
- Microsoft.AspNetCore.Cryptography.Internal 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.AspNetCore.Cryptography.KeyDerivation 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.AspNetCore.DataProtection 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.aspnetcore.dataprotection-9.0.0/Directory.Build.props(261,3): error MSB4019: The imported proje
- Microsoft.AspNetCore.DataProtection.Abstractions 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.aspnetcore.dataprotection.abstractions-9.0.0/Directory.Build.props(261,3): error MSB4019: The i
- Microsoft.AspNetCore.Diagnostics.EntityFrameworkCore 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.AspNetCore.Identity.EntityFrameworkCore 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.AspNetCore.Identity.UI 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.AspNetCore.Razor.Language 6.0.24: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.aspnetcore.razor.language-6.0.24/Directory.Build.props(239,3): error MSB4019: The imported proj
- Microsoft.AspNetCore.SpaProxy 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.Bcl.Cryptography 10.0.2: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.bcl.cryptography-10.0.2/src/runtime/eng/targetingpacks.targets(106,5): error : The shared frame
- Microsoft.Bcl.TimeProvider 8.0.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.bcl.timeprovider-8.0.1/eng/targetingpacks.targets(132,5): error : The shared framework must be 
- Microsoft.Build 17.11.48: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.build-17.11.48/src/StringTools/SpanBasedStringBuilder.cs(161,33): error IDE0370: Suppression is
- Microsoft.CodeAnalysis.Razor 6.0.24: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.codeanalysis.razor-6.0.24/Directory.Build.props(239,3): error MSB4019: The imported project "/p
- Microsoft.CodeAnalysis.Workspaces.MSBuild 5.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.targets(262,5): error NETSDK1085: The 'NoBu
- Microsoft.Extensions.Caching.Abstractions 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.caching.abstractions-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : 
- Microsoft.Extensions.Caching.Memory 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.caching.memory-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The sh
- Microsoft.Extensions.Configuration 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.configuration-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The sha
- Microsoft.Extensions.Configuration.Abstractions 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.configuration.abstractions-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): er
- Microsoft.Extensions.Configuration.Binder 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.configuration.binder-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : 
- Microsoft.Extensions.Configuration.CommandLine 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.configuration.commandline-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): err
- Microsoft.Extensions.Configuration.EnvironmentVariables 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.configuration.environmentvariables-10.0.12/src/runtime/eng/targetingpacks.targets(10
- Microsoft.Extensions.Configuration.FileExtensions 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.configuration.fileextensions-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): 
- Microsoft.Extensions.Configuration.Json 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.configuration.json-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : Th
- Microsoft.Extensions.Configuration.UserSecrets 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.configuration.usersecrets-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): err
- Microsoft.Extensions.DependencyInjection 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.dependencyinjection-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : T
- Microsoft.Extensions.DependencyInjection.Abstractions 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.dependencyinjection.abstractions-10.0.12/src/runtime/eng/targetingpacks.targets(106,
- Microsoft.Extensions.DependencyInjection.Abstractions 2.1.0: restore failed; /private/tmp/nupkg-determinism/src/microsoft.extensions.dependencyinjection.abstractions-2.1.0/src/DI.Abstractions/DI.Abstractions.csproj : 
- Microsoft.Extensions.DependencyModel 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.dependencymodel-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The s
- Microsoft.Extensions.DependencyModel 8.0.2: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.dependencymodel-8.0.2/eng/targetingpacks.targets(136,5): error : The shared framewor
- Microsoft.Extensions.Diagnostics 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.diagnostics-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The share
- Microsoft.Extensions.Diagnostics.Abstractions 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.diagnostics.abstractions-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): erro
- Microsoft.Extensions.Diagnostics.HealthChecks 8.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.diagnostics.healthchecks-8.0.0/Directory.Build.props(236,3): error MSB4019: The impo
- Microsoft.Extensions.Diagnostics.HealthChecks.Abstractions 8.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.diagnostics.healthchecks.abstractions-8.0.0/Directory.Build.props(236,3): error MSB4
- Microsoft.Extensions.FileProviders.Abstractions 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.fileproviders.abstractions-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): er
- Microsoft.Extensions.FileProviders.Abstractions 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.fileproviders.abstractions-9.0.0/eng/targetingpacks.targets(129,5): error : The shar
- Microsoft.Extensions.FileProviders.Embedded 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.Extensions.FileProviders.Physical 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.fileproviders.physical-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error 
- Microsoft.Extensions.FileSystemGlobbing 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.filesystemglobbing-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : Th
- Microsoft.Extensions.Hosting 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.hosting-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The shared fr
- Microsoft.Extensions.Hosting.Abstractions 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.hosting.abstractions-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : 
- Microsoft.Extensions.Hosting.Abstractions 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.hosting.abstractions-9.0.0/eng/targetingpacks.targets(129,5): error : The shared fra
- Microsoft.Extensions.Hosting.WindowsServices 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.hosting.windowsservices-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error
- Microsoft.Extensions.Http 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.http-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The shared frame
- Microsoft.Extensions.Identity.Core 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.Extensions.Identity.Stores 10.0.12: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(66,5):
- Microsoft.Extensions.Logging 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.logging-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The shared fr
- Microsoft.Extensions.Logging.Abstractions 10.0.12: pack failed (exit 1); MSBUILD : error : SDK version  is below the minimum required version of 10. The .NET Runtime Task Host is supported only when using .NET SDK
- Microsoft.Extensions.Logging.Configuration 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.logging.configuration-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error :
- Microsoft.Extensions.Logging.Console 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.logging.console-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The s
- Microsoft.Extensions.Logging.Debug 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.logging.debug-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The sha
- Microsoft.Extensions.Logging.EventLog 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.logging.eventlog-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The 
- Microsoft.Extensions.Logging.EventSource 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.logging.eventsource-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : T
- Microsoft.Extensions.Options 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.options-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The shared fr
- Microsoft.Extensions.Options.ConfigurationExtensions 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.options.configurationextensions-10.0.12/src/runtime/eng/targetingpacks.targets(106,5
- Microsoft.Extensions.Primitives 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.extensions.primitives-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The shared
- Microsoft.Identity.Client.Extensions.Msal 4.78.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.identity.client.extensions.msal-4.78.0/src/client/Microsoft.Identity.Client/ManagedIdentity/Abs
- Microsoft.IdentityModel.LoggingExtensions 8.7.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.identitymodel.loggingextensions-8.7.0/src/Microsoft.IdentityModel.Abstractions/obj/Release/nets
- Microsoft.IdentityModel.Protocols 8.7.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.identitymodel.protocols-8.7.0/src/Microsoft.IdentityModel.Abstractions/obj/Release/netstandard2
- Microsoft.IdentityModel.Protocols.OpenIdConnect 8.7.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.identitymodel.protocols.openidconnect-8.7.0/src/Microsoft.IdentityModel.Abstractions/obj/Releas
- Microsoft.IdentityModel.Validators 8.7.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/microsoft.identitymodel.validators-8.7.0/src/Microsoft.IdentityModel.Abstractions/obj/Release/netstandard
- Microsoft.ML.OnnxRuntime.Managed 1.20.1: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.ImportWorkloads.targets(38,5): error NETSDK
- Newtonsoft.Json 13.0.3: pack failed (exit 1); /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.ApiCompat.ValidatePackage.targets(39,5): error 
- NuGet.DependencyResolver.Core 6.12.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/nuget.dependencyresolver.core-6.12.1/src/NuGet.Core/NuGet.DependencyResolver.Core/GraphModel/GraphOperati
- NuGet.ProjectModel 6.12.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/nuget.projectmodel-6.12.1/src/NuGet.Core/NuGet.DependencyResolver.Core/GraphModel/GraphOperations.cs(871,
- SixLabors.ImageSharp 1.0.4: clone failed; git -C /private/tmp/nupkg-determinism/src/sixlabors.imagesharp-1.0.4 -c advice.detachedHead=false checkout -q 5321ca862acc48343de60b2c06f78b
- Svg.Animation 5.1.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/svg.animation-5.1.1/src/Svg.Custom/Animation/SvgAnimationElement.cs(3,11): error CS0234: The type or name
- Svg.Custom 5.1.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/svg.custom-5.1.1/src/Svg.Custom/Animation/SvgAnimationElement.cs(3,11): error CS0234: The type or namespa
- Svg.Model 5.1.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/svg.model-5.1.1/src/Svg.Custom/Animation/SvgAnimationElement.cs(3,11): error CS0234: The type or namespac
- Svg.SceneGraph 5.1.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/svg.scenegraph-5.1.1/src/Svg.Custom/Animation/SvgAnimationElement.cs(3,11): error CS0234: The type or nam
- Svg.Skia 5.1.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/svg.skia-5.1.1/src/Svg.Custom/Animation/SvgAnimationElement.cs(3,11): error CS0234: The type or namespace
- System.CodeDom 6.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.codedom-6.0.0/src/libraries/System.CodeDom/src/System/CodeDom/Compiler/Executor.cs(60,31): error C
- System.Composition.AttributedModel 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.composition.attributedmodel-9.0.0/eng/targetingpacks.targets(129,5): error : The shared framework 
- System.Composition.Convention 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.composition.convention-9.0.0/eng/targetingpacks.targets(129,5): error : The shared framework must 
- System.Composition.Hosting 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.composition.hosting-9.0.0/eng/targetingpacks.targets(129,5): error : The shared framework must be 
- System.Composition.Runtime 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.composition.runtime-9.0.0/eng/targetingpacks.targets(129,5): error : The shared framework must be 
- System.Composition.TypedParts 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.composition.typedparts-9.0.0/eng/targetingpacks.targets(129,5): error : The shared framework must 
- System.Configuration.ConfigurationManager 9.0.11: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.configuration.configurationmanager-9.0.11/eng/targetingpacks.targets(129,5): error : The shared fr
- System.Diagnostics.EventLog 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.diagnostics.eventlog-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : The shared fra
- System.Diagnostics.EventLog 9.0.11: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.diagnostics.eventlog-9.0.11/eng/targetingpacks.targets(129,5): error : The shared framework must b
- System.IO.Hashing 6.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.io.hashing-6.0.0/artifacts/obj/System.IO.Hashing/net6.0-Release/.NETCoreApp,Version=v6.0.AssemblyA
- System.IO.Hashing 7.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/nuget/microsoft.dotnet.apicompat.task/7.0.100-rc.1.22402.1/build/Microsoft.NET.ApiCompat.ValidatePackage.targ
- System.IO.Packaging 8.0.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.io.packaging-8.0.1/eng/targetingpacks.targets(136,5): error : The shared framework must be built b
- System.Memory.Data 8.0.1: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.memory.data-8.0.1/eng/targetingpacks.targets(136,5): error : The shared framework must be built be
- System.Reactive 5.0.0: restore failed; /private/tmp/nupkg-determinism/sdk/sdk/10.0.403/Sdks/Microsoft.NET.Sdk/targets/Microsoft.NET.Sdk.FrameworkReferenceResolution.targets(120,5)
- System.Reflection.MetadataLoadContext 8.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.reflection.metadataloadcontext-8.0.0/src/libraries/System.Collections.Immutable/src/System/Linq/Im
- System.Security.Cryptography.Pkcs 9.0.11: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.security.cryptography.pkcs-9.0.11/eng/targetingpacks.targets(129,5): error : The shared framework 
- System.Security.Cryptography.ProtectedData 9.0.11: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.security.cryptography.protecteddata-9.0.11/eng/targetingpacks.targets(129,5): error : The shared f
- System.Security.Cryptography.Xml 9.0.0: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.security.cryptography.xml-9.0.0/eng/targetingpacks.targets(129,5): error : The shared framework mu
- System.ServiceProcess.ServiceController 10.0.12: pack failed (exit 1); /private/tmp/nupkg-determinism/src/system.serviceprocess.servicecontroller-10.0.12/src/runtime/eng/targetingpacks.targets(106,5): error : Th
- System.Text.Json 10.0.12: pack failed (exit 1); MSBUILD : error : SDK version  is below the minimum required version of 10. The .NET Runtime Task Host is supported only when using .NET SDK

## 2. Per axis, default build: packages that differ

| axis | runs | differs at 1 (whole file) | differs at 2 (content) | differs at 3 (DLL) | build failed |
|---|---|---|---|---|---|
| build_path | 127 | 127 | 123 | 123 | 0 |
| environment | 127 | 127 | 5 | 5 | 0 |
| locales | 127 | 127 | 5 | 5 | 0 |
| exec_path | 127 | 127 | 5 | 5 | 0 |
| time | 127 | 125 | 18 | 18 | 2 |
| timezone | 127 | 127 | 5 | 5 | 0 |
| umask | 127 | 127 | 5 | 5 | 0 |
| fileordering | 127 | 127 | 5 | 5 | 0 |
| all eight at once | 85 | 85 | 81 | 81 | 0 |

## 3. Per package category, by level

| level | as is | with configuration | unreproducible | not reached |
|---|---|---|---|---|
| 1 whole file | 0 | 102 | 25 | 0 |
| 2 content | 4 | 98 | 25 | 0 |
| 3 DLLs | 4 | 98 | 25 | 0 |

## 4. Not fixed by the configuration (level 3, DLLs)

- Azure.Communication.Email 1.0.1: time: differs (Azure.Communication.Email.1.0.1-alpha.20261101.1.nupkg:lib/netstandard2.0/Azure.Communication.Email.dll)
- Azure.Core 1.50.0: time: differs (Azure.Core.1.50.0-alpha.20261101.1.nupkg:lib/netstandard2.0/Azure.Core.dll)
- Azure.Identity 1.17.1: time: differs (Azure.Identity.1.17.1-alpha.20261101.1.nupkg:lib/netstandard2.0/Azure.Identity.dll)
- Azure.Security.KeyVault.Certificates 4.6.0: time: differs (Azure.Security.KeyVault.Certificates.4.6.0-alpha.20261101.1.nupkg:lib/netstandard2.0/Azure.Security.KeyVault.Certificates.dll)
- Azure.Security.KeyVault.Secrets 4.6.0: time: differs (Azure.Security.KeyVault.Secrets.4.6.0-alpha.20261101.1.nupkg:lib/netstandard2.0/Azure.Security.KeyVault.Secrets.dll)
- Azure.Storage.Blobs 12.20.0: time: differs (Azure.Storage.Blobs.12.20.0-alpha.20261101.1.nupkg:lib/netstandard2.1/Azure.Storage.Blobs.dll)
- Azure.Storage.Common 12.19.0: time: differs (Azure.Storage.Common.12.19.0-alpha.20261101.1.nupkg:lib/netstandard2.0/Azure.Storage.Common.dll)
- ClosedXML 0.104.2: build_path: differs (ClosedXML.0.104.2.nupkg:lib/netstandard2.1/ClosedXML.dll)
- Microsoft.Build.Framework 18.0.2: time: differs (Microsoft.Build.Framework.18.0.2.nupkg:ref/netstandard2.0/Microsoft.Build.Framework.dll)
- Microsoft.IdentityModel.Abstractions 8.23.0: build_path: differs (Microsoft.IdentityModel.Abstractions.8.22.1-preview-71101143955.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll); environment: differs (Microsoft.IdentityModel.Abstractions.8.22.1-preview-71101144054.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll); locales: differs (Microsoft.IdentityModel.Abstractions.8.22.1-preview-71101144208.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll); exec_path: differs (Microsoft.IdentityModel.Abstractions.8.22.1-preview-71101144313.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll); time: differs (Microsoft.IdentityModel.Abstractions.8.22.1-preview-71101144429.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll); timezone: differs (Microsoft.IdentityModel.Abstractions.8.22.1-preview-71101144520.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll); umask: differs (Microsoft.IdentityModel.Abstractions.8.22.1-preview-71101144625.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll); fileordering: differs (Microsoft.IdentityModel.Abstractions.8.22.1-preview-71101144717.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Abstractions.dll)
- Microsoft.IdentityModel.JsonWebTokens 8.23.0: build_path: differs (Microsoft.IdentityModel.JsonWebTokens.8.22.1-preview-71101194626.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.JsonWebTokens.dll); environment: differs (Microsoft.IdentityModel.JsonWebTokens.8.22.1-preview-71101195235.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.JsonWebTokens.dll); locales: differs (Microsoft.IdentityModel.JsonWebTokens.8.22.1-preview-71101200222.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.JsonWebTokens.dll); exec_path: differs (Microsoft.IdentityModel.JsonWebTokens.8.22.1-preview-71101200822.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.JsonWebTokens.dll); time: differs (Microsoft.IdentityModel.JsonWebTokens.8.22.1-preview-71101201540.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.JsonWebTokens.dll); timezone: differs (Microsoft.IdentityModel.JsonWebTokens.8.22.1-preview-71101202340.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.JsonWebTokens.dll); umask: differs (Microsoft.IdentityModel.JsonWebTokens.8.22.1-preview-71101203000.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.JsonWebTokens.dll); fileordering: differs (Microsoft.IdentityModel.JsonWebTokens.8.22.1-preview-71101203933.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.JsonWebTokens.dll)
- Microsoft.IdentityModel.Logging 8.23.0: build_path: differs (Microsoft.IdentityModel.Logging.8.22.1-preview-71101160714.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Logging.dll); environment: differs (Microsoft.IdentityModel.Logging.8.22.1-preview-71101160918.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Logging.dll); locales: differs (Microsoft.IdentityModel.Logging.8.22.1-preview-71101161155.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Logging.dll); exec_path: differs (Microsoft.IdentityModel.Logging.8.22.1-preview-71101161354.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Logging.dll); time: differs (Microsoft.IdentityModel.Logging.8.22.1-preview-71101161541.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Logging.dll); timezone: differs (Microsoft.IdentityModel.Logging.8.22.1-preview-71101161825.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Logging.dll); umask: differs (Microsoft.IdentityModel.Logging.8.22.1-preview-71101162146.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Logging.dll); fileordering: differs (Microsoft.IdentityModel.Logging.8.22.1-preview-71101162334.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Logging.dll)
- Microsoft.IdentityModel.Tokens 8.23.0: build_path: differs (Microsoft.IdentityModel.Tokens.8.22.1-preview-71101193257.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Tokens.dll); environment: differs (Microsoft.IdentityModel.Tokens.8.22.1-preview-71101194037.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Tokens.dll); locales: differs (Microsoft.IdentityModel.Tokens.8.22.1-preview-71101194544.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Tokens.dll); exec_path: differs (Microsoft.IdentityModel.Tokens.8.22.1-preview-71101195133.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Tokens.dll); time: differs (Microsoft.IdentityModel.Tokens.8.22.1-preview-71101195621.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Tokens.dll); timezone: differs (Microsoft.IdentityModel.Tokens.8.22.1-preview-71101200058.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Tokens.dll); umask: differs (Microsoft.IdentityModel.Tokens.8.22.1-preview-71101200742.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Tokens.dll); fileordering: differs (Microsoft.IdentityModel.Tokens.8.22.1-preview-71101201328.nupkg:lib/netstandard2.0/Microsoft.IdentityModel.Tokens.dll)
- Quartz 3.13.1: build_path: differs (Quartz.3.13.1.nupkg:lib/netstandard2.0/Quartz.dll)
- Quartz.AspNetCore 3.13.1: build_path: differs (Quartz.AspNetCore.3.13.1.nupkg:lib/netstandard2.0/Quartz.AspNetCore.dll)
- Quartz.Extensions.DependencyInjection 3.13.1: build_path: differs (Quartz.Extensions.DependencyInjection.3.13.1.nupkg:lib/netstandard2.0/Quartz.Extensions.DependencyInjection.dll)
- Quartz.Extensions.Hosting 3.13.1: build_path: differs (Quartz.Extensions.Hosting.3.13.1.nupkg:lib/netstandard2.0/Quartz.Extensions.Hosting.dll)
- Stateless 5.16.0: time: differs (Stateless.5.16.0.nupkg:lib/netstandard2.0/Stateless.dll)
- Swashbuckle.AspNetCore.Annotations 7.2.0: time: differs (Swashbuckle.AspNetCore.Annotations.7.2.0.nupkg:lib/netstandard2.0/Swashbuckle.AspNetCore.Annotations.dll)
- Swashbuckle.AspNetCore.ReDoc 7.2.0: time: failed [/tmp/reprotest.rIuYQz/const_build_path/src/Swashbuckle.AspNetCore.ReDoc/Swashbuc]
- Swashbuckle.AspNetCore.Swagger 7.2.0: time: differs (Swashbuckle.AspNetCore.Swagger.7.2.0.nupkg:lib/netstandard2.0/Swashbuckle.AspNetCore.Swagger.dll)
- Swashbuckle.AspNetCore.SwaggerGen 7.2.0: time: differs (Swashbuckle.AspNetCore.SwaggerGen.7.2.0.nupkg:lib/netstandard2.0/Swashbuckle.AspNetCore.SwaggerGen.dll)
- Swashbuckle.AspNetCore.SwaggerUI 7.2.0: time: failed [/tmp/reprotest.KpYNCE/const_build_path/src/Swashbuckle.AspNetCore.SwaggerUI/Swas]
- System.ClientModel 1.8.0: time: differs (System.ClientModel.1.8.0-alpha.20261101.1.nupkg:lib/netstandard2.0/System.ClientModel.dll)
- System.IdentityModel.Tokens.Jwt 8.23.0: build_path: differs (System.IdentityModel.Tokens.Jwt.8.22.1-preview-71101212635.nupkg:lib/netstandard2.0/System.IdentityModel.Tokens.Jwt.dll); environment: differs (System.IdentityModel.Tokens.Jwt.8.22.1-preview-71101213316.nupkg:lib/netstandard2.0/System.IdentityModel.Tokens.Jwt.dll); locales: differs (System.IdentityModel.Tokens.Jwt.8.22.1-preview-71101214035.nupkg:lib/netstandard2.0/System.IdentityModel.Tokens.Jwt.dll); exec_path: differs (System.IdentityModel.Tokens.Jwt.8.22.1-preview-71101214721.nupkg:lib/netstandard2.0/System.IdentityModel.Tokens.Jwt.dll); time: differs (System.IdentityModel.Tokens.Jwt.8.22.1-preview-71101215404.nupkg:lib/netstandard2.0/System.IdentityModel.Tokens.Jwt.dll); timezone: differs (System.IdentityModel.Tokens.Jwt.8.22.1-preview-71101220049.nupkg:lib/netstandard2.0/System.IdentityModel.Tokens.Jwt.dll); umask: differs (System.IdentityModel.Tokens.Jwt.8.22.1-preview-71101220731.nupkg:lib/netstandard2.0/System.IdentityModel.Tokens.Jwt.dll); fileordering: differs (System.IdentityModel.Tokens.Jwt.8.22.1-preview-71101221412.nupkg:lib/netstandard2.0/System.IdentityModel.Tokens.Jwt.dll)

## 5. Identical DLLs under every axis with the default build (level 3 "as is")

- CsvHelper 33.1.0
- FluentValidation 11.11.0
- FluentValidation.DependencyInjectionExtensions 11.11.0
- ScottPlot 5.1.57

