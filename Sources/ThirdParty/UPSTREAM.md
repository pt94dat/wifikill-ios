# Vendored source

- Repository: https://github.com/mavris/MMLanScan
- Revision: `b93b4e4515dbb07eeb2d70e72fe9da106a5e02f3`, master, podspec3.0.0/iOS8.
- Files: `MMLanScan/External Libs/SimplePing/SimplePing.{h,m}`.
- Author/license: Apple DTS2010–2012 sample-code redistribution license retained in both files and Resources/Licenses/Apple-SimplePing.txt. Repository MIT notice also retained in Resources/Licenses/MMLanScan.txt.
- Adaptation: explicit TargetConditionals import and TARGET_OS_IPHONE condition in header for current SDKs. Implementation kept unchanged.
- Product uses numeric IPv4 hostAddress mode, bounded worker run loop and explicit stop/delegate teardown. No CFHost DNS dependency on the production path.
- MacFinder, PingOperation, OUI dataset, UI and APK code are not vendored. Their behavior does not establish usable third-party MACs on iOS12.
