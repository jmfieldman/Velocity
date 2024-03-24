# Swift Dependency Magnet

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

Swift Dependency Magnet lets you remove the 'remote' aspect of your SPM
dependencies from the perspective of your build tools.

You declare the top-level dependencies that your project uses. The magnet uses SPM
to resolve the graph and put all of your dependencies (and their sub-dependencies) in
a local directory. All of their Package.swift contents are relinked so that they 
refer to the local versions as well.   

Your package resolution latency issues will now be a thing of the past.

### How it Works

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

It is recommended that you add the following to `.gitignore`:

```
.dependency_magnet
Dependencies/Packages/
```

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

Or if you are using an Xcode-based project, you can select `File > Add Package Dependencies...` and then
select the `Add Local` button to choose your local top-level dependencies.

The package files in `Dependencies/Packages` are automatically updated to use sub-dependencies that
are also in the same directory.
