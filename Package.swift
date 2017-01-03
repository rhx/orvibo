import PackageDescription

let package = Package(
    name: "orvibo",
    dependencies: [
    	.Package(url: "https://github.com/rhx/COrvibo.git", majorVersion: 1),
    ]
)
