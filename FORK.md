# Fork of Alice 2.0.0 for FlutterFlow projects

This is an unmodified copy of [alice 2.0.0](https://pub.dev/packages/alice)
(Apache License 2.0, see `LICENSE`; original source
https://github.com/jhomlala/alice) with one change: the dependency ranges in
`pubspec.yaml` are widened so Alice resolves next to the versions FlutterFlow
pins, which a FlutterFlow project cannot override.

| Dependency | alice 2.0.0 | This fork |
|---|---|---|
| rxdart | ^0.28.0 | >=0.27.7 <0.29.0 |
| xml | ^7.0.0 | >=6.5.0 <8.0.0 |
| equatable | ^3.0.0 | >=2.0.5 <4.0.0 |
| share_plus | ^13.3.0 | >=12.0.0 <14.0.0 |
| open_file | ^4.0.0 | >=3.5.10 <5.0.0 |
| permission_handler | ^13.0.2 | >=12.0.1 <14.0.0 |
| package_info_plus | ^10.2.1 | >=9.0.0 <11.0.0 |
| sensors_plus | ^7.1.0 | >=6.1.0 <8.0.0 |

`version` is `2.0.0+pbb.1` and `publish_to: none`. No Dart code is changed.
Checked on Flutter 3.50.1 (iOS simulator build) with rxdart 0.27.7, xml 6.6.1,
equatable 2.1.0, share_plus 12.0.2, open_file 3.5.10, permission_handler
12.0.3, package_info_plus 9.0.1, sensors_plus 6.1.2/7.1.1.

Use it as a git dependency pinned to a commit:

```yaml
alice:
  git:
    url: <this repository>
    ref: <commit sha>
```

`alice_http` cannot be combined with a git-sourced Alice (it depends on Alice
from pub.dev), so copy its `AliceHttpAdapter` (Apache 2.0) into the app.
