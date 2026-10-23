# cabal-source-repo-update

**Update your cabal.project's source-repository-packages**

## Usage

First, annotate the `source-repository-package`s you want to be updated with `x-update: true`:

```cabal
source-repository-package
    location: https://example.com/repo.git
    tag: 0000000000000000000000000000000000000000
    x-update: true
```

then update it by running `cabal-source-repo-update`.
The `tag` field will be replaced with the latest `HEAD`.

## Configuration

You can configure the tool's behavior by setting the following `x-` fields
in the corresponding `source-repository-package` stanza:

| Field | Accepted values | Example | Description |
| - | - | - | - |
| `x-tag-pattern` | Pattern as described in `git-ls-remote(1)` | `refs/tags/v*` | Instead of updating to `HEAD`, update to the latest ref (by version sort) matching the pattern |

## Limitations

* Only top-level `source-repository-package`s are supported.
  Ones inside an import or a conditional won't be detected.
* Only git repos are supported for now.
