nginx-iocp 1.31.5 for Windows x64.

Updated in place on 2026-09-07 with the reviewed fixes. This build replaces
the previous v1.31.5 package built from
`89e65c287fa8516aa15482c5dfbf5ca5afb69970`.

- Fix an IOCP UDP worker crash during graceful reload by moving ordinary
  UDP flows off workers whose listeners have closed. Preserve QUIC routing
  to graceful workers that keep their listeners open.
- Fix TLS `Expect: 100-continue` responses being sent as plaintext on an
  IOCP connection, while preserving plaintext HTTP behavior.
- Add targeted regressions and strengthen reload, benchmark, configure,
  and test-resource checks in CI.

Built exclusively by GitHub Actions from
`c4e9c65fe556da4ef575344df2dc2a59bf3efd08`.
Release and Debug builds, the Windows RC matrix, integration, smoke,
feature, code-quality, and extended benchmark checks passed on this commit.
[Release build and package checks](https://github.com/pwin32/nginx-iocp/actions/runs/34135765662)
also passed before publishing these assets.

The archive carries a Sigstore build provenance attestation; verify it with:

```sh
gh attestation verify nginx-iocp-1.31.5-win64.zip --repo pwin32/nginx-iocp
```

SHA256 checksums are in `nginx-iocp-1.31.5-win64.zip.sha256`.

[Changes in this replacement](https://github.com/pwin32/nginx-iocp/compare/89e65c287fa8516aa15482c5dfbf5ca5afb69970...c4e9c65fe556da4ef575344df2dc2a59bf3efd08)
