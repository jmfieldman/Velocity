# SwiftDependencyMagnet

### The Problem

Have you ever thought to youself:

> I really want to love the Swift Package Manager. But it's so annoying
> when Xcode is constantly "Resolving Package Graph" and interrupting my
> workflow.

[Yes](https://forums.swift.org/t/swiftpm-how-to-prevent-resolve-packages-from-stymying-developer-productivity-local-packages/63363), 
it [can](https://www.reddit.com/r/iOSProgramming/comments/sdgw5i/resolving_package_graph_takes_ages/) 
be [annoying](https://stackoverflow.com/questions/77180553/xcode-15-checking-out-package-is-taking-forever). 
On a project with a moderate amount of SPM
dependencies, Xcode seems to randomly re-resolve the package graph
for 15-30 seconds (or more) any time a mote of dust hits your project the wrong way.

Assuming that most of your dependencies are hosted on remote git repos,
a fair bit of this time is spent dealing with the latency of checking the
state of those remote repos.

### The Solution

SwiftDependencyMagnet lets you remove the 'remote' aspect of your SPM
dependencies from the perspective of your build tools.

You declare the top-level dependencies that your project uses. The magnet uses SPM
to resolve the graph and put all of your dependencies (and their sub-dependencies) in
a local directory. All of their Package.swift contents are relinked so that they 
refer to the local versions as well.   

You now have full control over when package/version resolution occurs.

### Installation

##### Using Package.swift

Add SwiftDependencyMagnet to your Package.swift file:

```swift
.package(url: "https://github.com/jmfieldman/SwiftDependencyMagnet.git", from: "<version>")
```

Swift PM will automatically detect the executable target, so you can now run the executable through your own package:

```bash
$ swift run dependency_magnet <params>
```

##### Standalone (Mint)

If you want a more streamlined execution experience, try installing SwiftDependencyMagnet 
using the very nice [Mint Package Manager](https://github.com/yonaskolb/Mint).

Mint builds each Swift executable in its own environment, tracks versions, and supports 
localized version-pegging through a Mintfile. This avoids continuous, unnecessary 
rebuild-checks when your own project's Package.swift changes.

```bash
# Install mint on your system, e.g.
$ brew install mint

# Install SwiftDependencyMagnet
$ mint install jmfieldman/SwiftDependencyMagnet

# Run SwiftDependencyMagnet using Mint. This is the recommended method if you plan
# on using a Mintfile for version-pegging
$ mint run dependency_magnet <..>

# Or run it directly if you have the Mint bin directory in your path
$ dependency_magnet <..>
```

### Using SwiftDependencyMagnet

Create the top-level folder `Dependencies` and put your `dependencies.yml` configuration inside it:

```
Dependencies
    +--- dependencies.yml # contains a list of your dependencies
```

Your `dependencies.yml` file will look something like:

```yml
dependencies:
  - url: https://github.com/apple/swift-argument-parser
    exact: 1.3.1
  - url: https://github.com/jpsim/Yams.git
    from: 5.0.6    
    
# Each dependency must have a URL and one qualifier.
# Valid qualifiers are: exact, from, range, closedRange, branch, revision
```

Run the pull command:

```shell
$ swift run dependency_magnet pull
<SwiftPM resolution>
🧲 Importing [swift-argument-parser @ 1.3.1]
🧲 Importing [Yams @ 5.1.0]
```

At which point you will now have the following new files in your directory:

```bash
.dependency_magnet        # This is the shadow workspace; safe to .gitignore
    |
    +--- Package.resolved # The Package.resolved file in the shadow workspace
    |                     # This file is pulled from the source-controlled version
    |                     # before every sync.
    |
    +--- Package.swift    # The Package.swift file in the shadow workspace, which
    |                     # is auto-generated based on your dependencies.
    |
    +--- .build           # Where SwiftPM has pulled remote dependencies
    
Dependencies
    +--- dependencies.yml # Your dependencies configuration.
    |
    +--- Package.resolved # A source-controllable location for Package.resolved
    |                     # Make sure this is checked in to ensure that all
    |                     # users get the same versions of your dependencies.
    |
    +--- Packages         # This is where your locally-configured dependencies
         |                # live, and where you will point your Package.swift to.
         |                # Add this to your .gitignore to avoid recommitting all
         |                # of your dependencies to your main repo.
         |
         +--- swift-argument-parser
         +--- Yams
         +--- ...
```

> The package files in `Dependencies/Packages` are automatically updated to use sub-dependencies that
> are also in the same directory.

#### Updating .gitignore

It is recommended that you add the following to `.gitignore`:

```
.dependency_magnet
Dependencies/Packages/
```

#### Using Package.swift

If are using your own `Package.swift` file, you can now reference your locally-based dependencies like so:

```swift
let package = Package(
  ...
  products: [...],
  dependencies: [
    .package(path: "Dependencies/Package/swift-argument-parser"),
    .package(path: "Dependencies/Package/Yams"),
  ],
  targets: [...]
)

```

#### Using Xcode

If you are using an Xcode-based project, you can select `File > Add Package Dependencies...` and then
select the `Add Local` button to choose your local top-level dependencies.

#### Using Xcodegen

if you are using the wonderful [Xcodegen](https://github.com/yonaskolb/XcodeGen) utility, you can 
use the [packages](https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md#swift-package) directive 
to point to your new local paths:

```yml
packages:
  Yams:
    path: Dependencies/Package/Yams
  MyCoolLibrary:
    path: Dependencies/Package/MyCoolLibrary
```
