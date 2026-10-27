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

> [!NOTE]
>
> `cabal-install` will emit a warning about unknown fields.
> Issue [cabal#12480](https://github.com/haskell/cabal/issues/12480)
> proposes to make it ignore fields that start with `x-`.

### GitHub Action

This repository provides a GitHub Action. You can add it to a workflow like so:

```yaml
      - uses: scrive/cabal-source-repo-update@HEAD # Replace HEAD with the latest version
        with:
          project-file: path/to/my-cabal.project
```

<details>
<summary>Full example of a monthly scheduled source-repository-package update</summary>

> [!IMPORTANT]
>
> For this to work you should enable
> "Allow GitHub Actions to create and approve pull requests"
> under "Settings → Actions → General".

```yaml
name: Update source-repository-packages
on:
  workflow_dispatch: {}
  schedule:
    - cron: "0 0 1 * *"

permissions:
  contents: write
  pull-requests: write

jobs:
  source-repository-package-update:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v7
      - uses: scrive/cabal-source-repo-update@HEAD # Replace HEAD with the latest version
        with:
          project-file: cabal.project
      - name: Create PR
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          git checkout -b source-repository-package-update/${{ github.run_id }}
          git add cabal.project
          git config --global user.email "<>"
          git config --global user.name "cabal-source-repo-update bot"
          git commit -m "Update source-repository-packages"
          git push -u origin source-repository-package-update/${{ github.run_id }}
          gh pr create --fill
```

</details>

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
