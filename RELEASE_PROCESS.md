# Release process

1. Update the version in [`cabal-source-repo-update`](./cabal-source-repo-update).
2. Add a changelog entry to [`CHANGELOG.md`](./CHANGELOG.md).
3. `git commit -m "Release A.B.C.D"`.
4. `git tag vA.B.C.D --annotate`, copy the changelog entry in the editor.
5. `git push && git push --tags`.
6. Check that the [release workflow](https://github.com/scrive/cabal-source-repo-update/actions/workflows/release.yml) succeeds.
